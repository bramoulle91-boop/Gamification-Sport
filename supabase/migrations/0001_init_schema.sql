-- GymQuest — schéma de base de données (Supabase / PostgreSQL)
-- Référence : docs/ARCHITECTURE.md, section VI

create extension if not exists "pgcrypto";

-- Niveaux de validation d'une performance (voir section V)
create type validation_level as enum ('1', '2', '3');
create type validation_status as enum ('PENDING', 'VALIDATED', 'REJECTED');
create type friendship_status as enum ('PENDING', 'DEBLOCKED');

create table users (
  id uuid primary key default gen_random_uuid() references auth.users (id) on delete cascade,
  pseudo text not null unique,
  real_name text,
  email text not null unique,
  league_level integer not null default 1,
  total_points integer not null default 0,
  streak_history jsonb not null default '[]',
  created_at timestamptz not null default now()
);

create table gyms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  gps_coordinates point not null,
  geofencing_radius_m integer not null default 100,
  live_attendance_rate numeric,
  created_at timestamptz not null default now()
);

create table machines (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  targeted_muscle text,
  gym_id uuid not null references gyms (id) on delete cascade,
  qr_code_hash text not null unique,
  created_at timestamptz not null default now()
);

create table friendships (
  user_id_1 uuid not null references users (id) on delete cascade,
  user_id_2 uuid not null references users (id) on delete cascade,
  status friendship_status not null default 'PENDING',
  connected_at timestamptz not null default now(),
  primary key (user_id_1, user_id_2),
  check (user_id_1 <> user_id_2)
);

create table performances (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  machine_id uuid not null references machines (id) on delete cascade,
  weight_kg numeric not null,
  reps integer not null,
  performed_at timestamptz not null default now(),
  validation_level validation_level not null default '1',
  validation_status validation_status not null default 'PENDING',
  created_at timestamptz not null default now()
);

create index performances_user_id_idx on performances (user_id);
create index performances_machine_id_idx on performances (machine_id);
create index machines_gym_id_idx on machines (gym_id);
