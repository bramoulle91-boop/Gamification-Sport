-- GymQuest — carte des salles complète : ajout libre de salles, et
-- filtrage du classement / King of the Machine par salle.

alter table gyms add column created_by uuid references users (id);

create policy "gyms_insert_authenticated" on gyms for insert
  with check (auth.uid() is not null);
