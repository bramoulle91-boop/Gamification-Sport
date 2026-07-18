-- GymQuest — défis entre amis (duels) : qui progresse le plus sur un
-- exercice donné pendant une période fixée. Le score de chacun est calculé
-- à partir de ses vraies performances validées (scan machine) ET de ses
-- exercices de programme cochés avec poids, sur le même nom d'exercice —
-- pas une nouvelle source de données à saisir en plus.

create type duel_status as enum ('PENDING', 'ACTIVE', 'DECLINED', 'FINISHED');

create table duels (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references users (id) on delete cascade,
  opponent_id uuid not null references users (id) on delete cascade,
  exercise_name text not null,
  status duel_status not null default 'PENDING',
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  winner_id uuid references users (id),
  check (challenger_id <> opponent_id)
);

alter table duels enable row level security;

create policy "duels_select_participant" on duels for select
  using (auth.uid() = challenger_id or auth.uid() = opponent_id);
create policy "duels_insert_own" on duels for insert
  with check (auth.uid() = challenger_id);
-- Une mise à jour directe reste possible pour les deux participants (RLS),
-- mais en pratique seules les fonctions ci-dessous écrivent status/winner_id.
create policy "duels_update_participant" on duels for update
  using (auth.uid() = challenger_id or auth.uid() = opponent_id);

-- Meilleur poids d'un utilisateur sur un exercice (par nom, insensible à la
-- casse) pendant une période : le maximum entre ses performances validées
-- (scan machine) et ses exercices de programme cochés avec poids.
create or replace function duel_best_weight(
  p_user_id uuid, p_exercise_name text, p_since timestamptz, p_until timestamptz
) returns numeric as $$
  select greatest(
    coalesce((
      select max(p.weight_kg) from performances p
      join machines m on m.id = p.machine_id
      where p.user_id = p_user_id
        and lower(m.name) = lower(p_exercise_name)
        and p.validation_status = 'VALIDATED'
        and p.performed_at between p_since and p_until
    ), 0),
    coalesce((
      select max(c.weight_kg) from program_exercise_completions c
      join program_exercises pe on pe.id = c.program_exercise_id
      where c.user_id = p_user_id
        and lower(pe.exercise_name) = lower(p_exercise_name)
        and c.completed_at between p_since and p_until
    ), 0)
  );
$$ language sql stable;

-- Score en direct des deux participants (consultable même pendant un duel
-- actif, avant la fin).
create or replace function get_duel_scores(p_duel_id uuid)
returns table(challenger_best numeric, opponent_best numeric) as $$
  select
    duel_best_weight(d.challenger_id, d.exercise_name, d.created_at, d.ends_at),
    duel_best_weight(d.opponent_id, d.exercise_name, d.created_at, d.ends_at)
  from duels d where d.id = p_duel_id;
$$ language sql stable;

create or replace function respond_to_duel(p_duel_id uuid, p_accept boolean) returns duels as $$
declare
  v_duel duels;
begin
  update duels
  set status = case when p_accept then 'ACTIVE' else 'DECLINED' end
  where id = p_duel_id and opponent_id = auth.uid() and status = 'PENDING'
  returning * into v_duel;

  if v_duel.id is null then
    raise exception 'Défi introuvable ou déjà répondu';
  end if;

  return v_duel;
end;
$$ language plpgsql security definer;

-- Calcule le gagnant si la période est terminée et attribue un bonus de
-- points (une seule fois, au passage FINISHED). Appelée côté client à
-- l'affichage d'un duel actif dont la date de fin est dépassée.
create or replace function settle_duel(p_duel_id uuid) returns duels as $$
declare
  v_duel duels;
  v_challenger_best numeric;
  v_opponent_best numeric;
  v_winner uuid;
begin
  select * into v_duel from duels where id = p_duel_id;
  if v_duel.id is null then
    raise exception 'Défi introuvable';
  end if;
  if v_duel.status <> 'ACTIVE' or now() < v_duel.ends_at then
    return v_duel;
  end if;

  v_challenger_best := duel_best_weight(v_duel.challenger_id, v_duel.exercise_name, v_duel.created_at, v_duel.ends_at);
  v_opponent_best := duel_best_weight(v_duel.opponent_id, v_duel.exercise_name, v_duel.created_at, v_duel.ends_at);

  v_winner := case
    when v_challenger_best > v_opponent_best then v_duel.challenger_id
    when v_opponent_best > v_challenger_best then v_duel.opponent_id
    else null
  end;

  update duels set status = 'FINISHED', winner_id = v_winner
  where id = p_duel_id
  returning * into v_duel;

  if v_winner is not null then
    update users set total_points = total_points + 50 where id = v_winner;
  end if;

  return v_duel;
end;
$$ language plpgsql security definer;
