-- GymQuest — notifications push réelles : stocke les abonnements
-- navigateur (Web Push) par utilisateur. L'envoi effectif se fait depuis
-- une fonction Supabase Edge séparée (supabase/functions/send-push),
-- déclenchée par des Database Webhooks sur gym_messages/duels — pas de
-- secret exposé côté base de données.

create table push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  endpoint text not null unique,
  p256dh text not null,
  auth_key text not null,
  created_at timestamptz not null default now()
);

alter table push_subscriptions enable row level security;

create policy "push_subscriptions_select_own" on push_subscriptions for select
  using (auth.uid() = user_id);
create policy "push_subscriptions_insert_own" on push_subscriptions for insert
  with check (auth.uid() = user_id);
create policy "push_subscriptions_delete_own" on push_subscriptions for delete
  using (auth.uid() = user_id);
