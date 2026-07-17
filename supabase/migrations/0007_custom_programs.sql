-- GymQuest — programmes personnalisés : chacun peut créer son propre
-- programme au lieu d'être limité au "Programme Découverte" prédéfini.

alter table programs add column created_by uuid references users (id);

create policy "programs_insert_own" on programs for insert
  with check (auth.uid() = created_by);
create policy "programs_update_own" on programs for update
  using (auth.uid() = created_by);
create policy "programs_delete_own" on programs for delete
  using (auth.uid() = created_by);

create policy "program_exercises_insert_own" on program_exercises for insert
  with check (
    exists (
      select 1 from programs p
      where p.id = program_exercises.program_id and p.created_by = auth.uid()
    )
  );
create policy "program_exercises_update_own" on program_exercises for update
  using (
    exists (
      select 1 from programs p
      where p.id = program_exercises.program_id and p.created_by = auth.uid()
    )
  );
create policy "program_exercises_delete_own" on program_exercises for delete
  using (
    exists (
      select 1 from programs p
      where p.id = program_exercises.program_id and p.created_by = auth.uid()
    )
  );

-- Bug de test : la "Salle Découverte" de démo est à Paris avec un rayon de
-- géofencing strict (150m). Quiconque teste hors de Paris se fait rejeter
-- en silence par le niveau 1 (l'app affichait "validée" à tort — corrigé
-- côté app séparément). En attendant une vraie salle pilote, on élargit le
-- rayon pour que les tests fonctionnent depuis n'importe où.
update gyms set geofencing_radius_m = 20000000
where id = '00000000-0000-4000-9000-000000000001';
