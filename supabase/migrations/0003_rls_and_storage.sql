-- GymQuest — Row Level Security, bucket de stockage des preuves, RPC niveau 2 & 3

-- Bucket privé pour les photos/vidéos de preuve (accès via URL signée, purge automatique).
insert into storage.buckets (id, name, public)
values ('proof-media', 'proof-media', false)
on conflict (id) do nothing;

alter table users enable row level security;
alter table gyms enable row level security;
alter table machines enable row level security;
alter table friendships enable row level security;
alter table performances enable row level security;
alter table gym_staff enable row level security;
alter table qr_validation_tokens enable row level security;
alter table peer_jury_votes enable row level security;
alter table rewards enable row level security;
alter table reward_redemptions enable row level security;

create policy "users_select_all" on users for select using (true);
create policy "users_update_self" on users for update using (auth.uid() = id);

create policy "gyms_select_all" on gyms for select using (true);
create policy "machines_select_all" on machines for select using (true);
create policy "rewards_select_all" on rewards for select using (true);

create policy "friendships_select_own" on friendships for select
  using (auth.uid() = user_id_1 or auth.uid() = user_id_2);
create policy "friendships_insert_own" on friendships for insert
  with check (auth.uid() = user_id_1);
create policy "friendships_update_own" on friendships for update
  using (auth.uid() = user_id_1 or auth.uid() = user_id_2);

create policy "performances_select_public" on performances for select using (true);
create policy "performances_insert_own" on performances for insert
  with check (auth.uid() = user_id);

create policy "performances_staff_update" on performances for update
  using (
    exists (
      select 1 from machines m
        join gym_staff gs on gs.gym_id = m.gym_id
      where m.id = performances.machine_id and gs.user_id = auth.uid()
    )
  );

create policy "qr_tokens_select_own_or_target" on qr_validation_tokens for select
  using (auth.uid() = issuer_user_id or used_by is null);
create policy "qr_tokens_insert_own" on qr_validation_tokens for insert
  with check (auth.uid() = issuer_user_id);

create policy "peer_jury_votes_select_all" on peer_jury_votes for select using (true);
create policy "peer_jury_votes_insert_own" on peer_jury_votes for insert
  with check (auth.uid() = voter_id);

create policy "reward_redemptions_select_own" on reward_redemptions for select
  using (auth.uid() = user_id);
create policy "reward_redemptions_insert_own" on reward_redemptions for insert
  with check (auth.uid() = user_id);

-- Niveau 2 : preuve photo. La photo est déposée dans le bucket `proof-media` par le
-- client puis référencée ici ; un job planifié (Edge Function `purge-proof-media`,
-- non fournie ici) supprime les fichiers du bucket après 24h pour rester "éphémère".
create or replace function log_performance_level2_photo(
  p_machine_id uuid,
  p_weight_kg numeric,
  p_reps integer,
  p_proof_photo_path text
) returns performances as $$
declare
  v_performance performances;
begin
  insert into performances (
    user_id, machine_id, weight_kg, reps, validation_level, validation_status, proof_photo_path
  )
  values (auth.uid(), p_machine_id, p_weight_kg, p_reps, '2', 'VALIDATED', p_proof_photo_path)
  returning * into v_performance;

  update users set total_points = total_points + greatest(1, p_reps) * 2 where id = auth.uid();

  return v_performance;
end;
$$ language plpgsql security definer;

-- Niveau 2 (variante QR ami) : crée la performance en attente, avant génération du
-- QR temporaire que l'ami va scanner pour la faire passer à VALIDATED.
create or replace function log_performance_level2_pending(
  p_machine_id uuid,
  p_weight_kg numeric,
  p_reps integer
) returns performances as $$
declare
  v_performance performances;
begin
  insert into performances (user_id, machine_id, weight_kg, reps, validation_level, validation_status)
  values (auth.uid(), p_machine_id, p_weight_kg, p_reps, '2', 'PENDING')
  returning * into v_performance;

  return v_performance;
end;
$$ language plpgsql security definer;

-- Niveau 2 : un ami génère un token, l'auteur de la perf le scanne (ou inversement) ;
-- le token expire après 2 minutes et n'est utilisable qu'une fois.
create or replace function request_friend_validation_token(
  p_performance_id uuid
) returns qr_validation_tokens as $$
declare
  v_token qr_validation_tokens;
begin
  insert into qr_validation_tokens (performance_id, issuer_user_id, token, expires_at)
  values (p_performance_id, auth.uid(), encode(gen_random_bytes(16), 'hex'), now() + interval '2 minutes')
  returning * into v_token;

  return v_token;
end;
$$ language plpgsql security definer;

create or replace function redeem_friend_validation_token(
  p_token text
) returns performances as $$
declare
  v_token_row qr_validation_tokens;
  v_performance performances;
begin
  select * into v_token_row from qr_validation_tokens
    where token = p_token and not used and expires_at > now()
    for update;

  if v_token_row is null then
    raise exception 'QR code invalide ou expiré';
  end if;

  if v_token_row.issuer_user_id = auth.uid() then
    raise exception 'Un ami doit scanner le QR code, pas vous-même';
  end if;

  update qr_validation_tokens set used = true, used_by = auth.uid()
    where id = v_token_row.id;

  update performances
    set validation_status = 'VALIDATED', friend_validator_id = auth.uid()
    where id = v_token_row.performance_id
    returning * into v_performance;

  update users set total_points = total_points + greatest(1, v_performance.reps) * 2
    where id = v_performance.user_id;

  return v_performance;
end;
$$ language plpgsql security definer;

-- Niveau 3 : soumission pour validation staff (compte "Staff" du gérant/coach) ou
-- vote asynchrone de la communauté ("Tribunal des Pairs"), selon `p_mode`.
create or replace function log_performance_level3(
  p_machine_id uuid,
  p_weight_kg numeric,
  p_reps integer,
  p_proof_video_path text default null
) returns performances as $$
declare
  v_performance performances;
begin
  insert into performances (
    user_id, machine_id, weight_kg, reps, validation_level, validation_status, proof_video_path
  )
  values (auth.uid(), p_machine_id, p_weight_kg, p_reps, '3', 'PENDING', p_proof_video_path)
  returning * into v_performance;

  return v_performance;
end;
$$ language plpgsql security definer;

create or replace function staff_validate_performance(
  p_performance_id uuid,
  p_approve boolean
) returns performances as $$
declare
  v_performance performances;
  v_is_staff boolean;
begin
  select exists (
    select 1 from performances p
      join machines m on m.id = p.machine_id
      join gym_staff gs on gs.gym_id = m.gym_id
    where p.id = p_performance_id and gs.user_id = auth.uid()
  ) into v_is_staff;

  if not v_is_staff then
    raise exception 'Seul le staff de la salle peut valider cette performance';
  end if;

  update performances
    set validation_status = case when p_approve then 'VALIDATED' else 'REJECTED' end,
        validated_by = auth.uid()
    where id = p_performance_id
    returning * into v_performance;

  if p_approve then
    update users set total_points = total_points + greatest(1, v_performance.reps) * 5
      where id = v_performance.user_id;
  end if;

  return v_performance;
end;
$$ language plpgsql security definer;
