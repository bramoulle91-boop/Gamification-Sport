-- GymQuest — modération légère du tchat de salle : chacun peut supprimer
-- ses propres messages (regret, erreur, abus signalé...).

create policy "gym_messages_delete_own" on gym_messages for delete
  using (auth.uid() = user_id);
