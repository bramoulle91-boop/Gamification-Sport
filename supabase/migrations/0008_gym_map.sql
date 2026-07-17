-- GymQuest — carte des salles : choisir sa salle habituelle parmi les
-- salles partenaires affichées sur une carte.

alter table users add column home_gym_id uuid references gyms (id);

-- La policy "users_update_self" existante (auth.uid() = id) couvre déjà
-- la mise à jour de cette nouvelle colonne, aucune policy additionnelle
-- n'est nécessaire.

-- Quelques salles de démonstration supplémentaires, réparties autour de
-- Paris, pour que la carte ne montre pas un point unique.
insert into gyms (id, name, gps_coordinates, geofencing_radius_m) values
  ('00000000-0000-4000-9000-000000000002', 'Basic-Fit République', point(48.8674, 2.3632), 20000000),
  ('00000000-0000-4000-9000-000000000003', 'Fitness Park Bastille', point(48.8532, 2.3695), 20000000),
  ('00000000-0000-4000-9000-000000000004', 'Neoness Montparnasse', point(48.8422, 2.3219), 20000000)
on conflict (id) do nothing;
