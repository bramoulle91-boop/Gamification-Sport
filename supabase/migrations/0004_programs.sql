-- GymQuest — programmes d'entraînement : séances structurées que l'utilisateur
-- suit jour après jour, reliées à la saisie de performances sur l'accueil.

create table programs (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  created_at timestamptz not null default now()
);

create table program_exercises (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references programs (id) on delete cascade,
  day_label text not null,
  order_index integer not null,
  exercise_name text not null,
  targeted_muscle text,
  target_sets integer not null default 3,
  target_reps integer not null default 10,
  target_weight_kg numeric,
  created_at timestamptz not null default now()
);

create index program_exercises_program_id_idx on program_exercises (program_id);

-- Un seul programme actif par utilisateur à la fois, avec le jour en cours.
create table user_programs (
  user_id uuid primary key references users (id) on delete cascade,
  program_id uuid not null references programs (id),
  current_day_label text not null,
  started_at timestamptz not null default now()
);

alter table programs enable row level security;
alter table program_exercises enable row level security;
alter table user_programs enable row level security;

create policy "programs_select_all" on programs for select using (true);
create policy "program_exercises_select_all" on program_exercises for select using (true);

create policy "user_programs_select_own" on user_programs for select
  using (auth.uid() = user_id);
create policy "user_programs_insert_own" on user_programs for insert
  with check (auth.uid() = user_id);
create policy "user_programs_update_own" on user_programs for update
  using (auth.uid() = user_id);

-- Fait avancer l'utilisateur au jour suivant de son programme (cycle sur les
-- day_label distincts du programme, dans l'ordre de leur premier order_index).
create or replace function advance_program_day() returns user_programs as $$
declare
  v_program_id uuid;
  v_days text[];
  v_current_index integer;
  v_next_label text;
  v_result user_programs;
begin
  select program_id into v_program_id from user_programs where user_id = auth.uid();
  if v_program_id is null then
    raise exception 'Aucun programme en cours';
  end if;

  select array_agg(day_label order by min_order) into v_days
    from (
      select day_label, min(order_index) as min_order
        from program_exercises
        where program_id = v_program_id
        group by day_label
    ) d;

  select array_position(v_days, current_day_label) into v_current_index
    from user_programs where user_id = auth.uid();

  v_next_label := v_days[(coalesce(v_current_index, 0) % array_length(v_days, 1)) + 1];

  update user_programs set current_day_label = v_next_label
    where user_id = auth.uid()
    returning * into v_result;

  return v_result;
end;
$$ language plpgsql security definer;

-- Programme de démonstration : Découverte GymQuest, 3 jours, 4 exercices/jour.
insert into programs (id, name, description) values
  ('00000000-0000-4000-8000-000000000001', 'Programme Découverte', 'Full-body en 3 séances, pensé pour débuter sur GymQuest.');

insert into program_exercises (program_id, day_label, order_index, exercise_name, targeted_muscle, target_sets, target_reps, target_weight_kg) values
  ('00000000-0000-4000-8000-000000000001', 'Jour 1 — Push', 1, 'Développé couché', 'Pectoraux', 4, 10, 40),
  ('00000000-0000-4000-8000-000000000001', 'Jour 1 — Push', 2, 'Développé militaire', 'Épaules', 3, 10, 20),
  ('00000000-0000-4000-8000-000000000001', 'Jour 1 — Push', 3, 'Dips', 'Triceps', 3, 12, 0),
  ('00000000-0000-4000-8000-000000000001', 'Jour 1 — Push', 4, 'Élévations latérales', 'Épaules', 3, 15, 8),
  ('00000000-0000-4000-8000-000000000001', 'Jour 2 — Pull', 1, 'Tractions', 'Dos', 4, 8, 0),
  ('00000000-0000-4000-8000-000000000001', 'Jour 2 — Pull', 2, 'Rowing barre', 'Dos', 4, 10, 40),
  ('00000000-0000-4000-8000-000000000001', 'Jour 2 — Pull', 3, 'Curl biceps', 'Biceps', 3, 12, 12),
  ('00000000-0000-4000-8000-000000000001', 'Jour 2 — Pull', 4, 'Face pull', 'Épaules', 3, 15, 15),
  ('00000000-0000-4000-8000-000000000001', 'Jour 3 — Legs', 1, 'Squat', 'Quadriceps', 4, 8, 60),
  ('00000000-0000-4000-8000-000000000001', 'Jour 3 — Legs', 2, 'Presse à cuisses', 'Quadriceps', 4, 12, 80),
  ('00000000-0000-4000-8000-000000000001', 'Jour 3 — Legs', 3, 'Leg curl', 'Ischio-jambiers', 3, 12, 30),
  ('00000000-0000-4000-8000-000000000001', 'Jour 3 — Legs', 4, 'Mollets debout', 'Mollets', 4, 15, 40);

-- Récompenses de démonstration pour la boutique.
insert into rewards (name, partner_name, points_cost, stock) values
  ('Bouteille GymQuest', 'GymQuest', 300, 50),
  ('Séance offerte', 'Ta salle partenaire', 800, 20),
  ('T-shirt technique', 'GymQuest', 1200, 30),
  ('Pack protéine découverte', 'NutriPartner', 1500, 15);
