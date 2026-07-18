-- GymQuest — calendrier hebdomadaire personnalisable : chaque jour de la
-- semaine (lundi..dimanche) peut être assigné à une séance différente du
-- programme (ou repos), modifiable à tout moment depuis l'app — au lieu
-- d'une rotation figée qui avançait jour après jour sans lien avec le
-- vrai calendrier.

create table program_weekly_schedule (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  weekday integer not null check (weekday between 1 and 7), -- 1 = lundi ... 7 = dimanche (ISO)
  day_label text, -- null = jour de repos
  unique (user_id, weekday)
);

alter table program_weekly_schedule enable row level security;

create policy "weekly_schedule_select_own" on program_weekly_schedule for select
  using (auth.uid() = user_id);
create policy "weekly_schedule_insert_own" on program_weekly_schedule for insert
  with check (auth.uid() = user_id);
create policy "weekly_schedule_update_own" on program_weekly_schedule for update
  using (auth.uid() = user_id);
create policy "weekly_schedule_delete_own" on program_weekly_schedule for delete
  using (auth.uid() = user_id);
