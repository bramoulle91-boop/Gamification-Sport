-- GymQuest — validation avancée (niveaux 2 & 3), staff, jury et récompenses

alter table performances
  add column proof_photo_path text,
  add column proof_video_path text,
  add column validated_by uuid references users (id),
  add column friend_validator_id uuid references users (id);

-- Comptes staff (gérant / coach) rattachés à une salle : habilités à valider le niveau 3.
create table gym_staff (
  gym_id uuid not null references gyms (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  role text not null default 'staff',
  primary key (gym_id, user_id)
);

-- QR codes temporaires générés côté "auteur" de la performance, scannés par un ami
-- géolocalisé à côté de lui (niveau 2) pour valider par preuve croisée.
create table qr_validation_tokens (
  id uuid primary key default gen_random_uuid(),
  performance_id uuid not null references performances (id) on delete cascade,
  issuer_user_id uuid not null references users (id) on delete cascade,
  token text not null unique,
  expires_at timestamptz not null,
  used boolean not null default false,
  used_by uuid references users (id),
  created_at timestamptz not null default now()
);

-- "Tribunal des Pairs" : vote asynchrone de la communauté sur une vidéo (niveau 3).
create table peer_jury_votes (
  id uuid primary key default gen_random_uuid(),
  performance_id uuid not null references performances (id) on delete cascade,
  voter_id uuid not null references users (id) on delete cascade,
  approve boolean not null,
  created_at timestamptz not null default now(),
  unique (performance_id, voter_id)
);

-- Boutique de récompenses (marques partenaires).
create table rewards (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  partner_name text,
  points_cost integer not null,
  stock integer not null default 0,
  created_at timestamptz not null default now()
);

create table reward_redemptions (
  id uuid primary key default gen_random_uuid(),
  reward_id uuid not null references rewards (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  redeemed_at timestamptz not null default now()
);

-- Nombre de votes du jury nécessaires pour trancher une performance niveau 3.
create or replace function tally_peer_jury_vote() returns trigger as $$
declare
  approve_count integer;
  reject_count integer;
  quorum constant integer := 5;
begin
  select count(*) filter (where approve), count(*) filter (where not approve)
    into approve_count, reject_count
    from peer_jury_votes
    where performance_id = new.performance_id;

  if approve_count + reject_count >= quorum then
    update performances
      set validation_status = case when approve_count > reject_count then 'VALIDATED' else 'REJECTED' end
      where id = new.performance_id and validation_status = 'PENDING';
  end if;

  return new;
end;
$$ language plpgsql security definer;

create trigger peer_jury_votes_tally
  after insert on peer_jury_votes
  for each row execute function tally_peer_jury_vote();

-- Niveau 1 : validation automatique par géofencing + cohérence temporelle.
-- Rejette si la dernière performance validée du user date de moins de 20s
-- (impossible de valider 5 machines en 2 minutes), ou si hors du périmètre de la salle.
create or replace function log_performance_level1(
  p_machine_id uuid,
  p_weight_kg numeric,
  p_reps integer,
  p_user_lat double precision,
  p_user_lon double precision
) returns performances as $$
declare
  v_gym record;
  v_last_timestamp timestamptz;
  v_distance_m double precision;
  v_min_interval_seconds constant integer := 20;
  v_status validation_status := 'VALIDATED';
  v_performance performances;
begin
  select g.id, (g.gps_coordinates)[0] as lat, (g.gps_coordinates)[1] as lon, g.geofencing_radius_m
    into v_gym
    from machines m join gyms g on g.id = m.gym_id
    where m.id = p_machine_id;

  if v_gym is null then
    raise exception 'Machine introuvable';
  end if;

  v_distance_m := 111320 * sqrt(
    power(v_gym.lat - p_user_lat, 2) + power((v_gym.lon - p_user_lon) * cos(radians(p_user_lat)), 2)
  );

  select max(performed_at) into v_last_timestamp
    from performances
    where user_id = auth.uid() and validation_status = 'VALIDATED';

  if v_distance_m > v_gym.geofencing_radius_m then
    v_status := 'REJECTED';
  elsif v_last_timestamp is not null
    and extract(epoch from (now() - v_last_timestamp)) < v_min_interval_seconds then
    v_status := 'REJECTED';
  end if;

  insert into performances (user_id, machine_id, weight_kg, reps, validation_level, validation_status)
  values (auth.uid(), p_machine_id, p_weight_kg, p_reps, '1', v_status)
  returning * into v_performance;

  if v_status = 'VALIDATED' then
    update users set total_points = total_points + greatest(1, p_reps) where id = auth.uid();
  end if;

  return v_performance;
end;
$$ language plpgsql security definer;
