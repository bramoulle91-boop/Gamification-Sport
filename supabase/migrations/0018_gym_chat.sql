-- GymQuest — tchat de salle : une discussion en direct par salle, visible
-- par tout le monde (comme les autres fonctionnalités sociales de l'app),
-- pour ceux qui la fréquentent.

create table gym_messages (
  id uuid primary key default gen_random_uuid(),
  gym_id uuid not null references gyms (id) on delete cascade,
  user_id uuid not null references users (id) on delete cascade,
  pseudo text not null,
  message text not null check (char_length(message) between 1 and 500),
  created_at timestamptz not null default now()
);

create index gym_messages_gym_id_idx on gym_messages (gym_id, created_at);

alter table gym_messages enable row level security;

create policy "gym_messages_select_all" on gym_messages for select using (true);
create policy "gym_messages_insert_own" on gym_messages for insert
  with check (auth.uid() = user_id);

-- Nécessaire pour que les nouveaux messages arrivent en direct (Supabase
-- Realtime) plutôt que de devoir recharger l'écran.
alter publication supabase_realtime add table gym_messages;
