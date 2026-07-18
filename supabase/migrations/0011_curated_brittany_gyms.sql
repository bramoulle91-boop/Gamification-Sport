-- GymQuest — nettoie les salles ajoutées par erreur depuis la carte (mode
-- "Ajouter une salle") et les 3 anciennes salles de démo parisiennes
-- devenues obsolètes, puis les remplace par les grandes enseignes de sport
-- réellement présentes en Bretagne (Basic-Fit, Fitness Park, Keepcool,
-- L'Orange Bleue). Les 3 salles pilotes Basic-Fit Quimper/Brest/Rennes
-- (avec leurs machines de démo et QR codes) sont conservées telles quelles.

-- 1. Détache les utilisateurs qui avaient choisi une salle sur le point
-- d'être supprimée comme salle habituelle, sinon la suppression échoue
-- (contrainte de clé étrangère sur users.home_gym_id).
update users set home_gym_id = null
where home_gym_id in (
  select id from gyms
  where created_by is not null
     or id in (
       '00000000-0000-4000-9000-000000000002', -- Basic-Fit République (Paris, démo obsolète)
       '00000000-0000-4000-9000-000000000003', -- Fitness Park Bastille (Paris, démo obsolète)
       '00000000-0000-4000-9000-000000000004'  -- Neoness Montparnasse (Paris, démo obsolète)
     )
);

-- 2. Supprime les salles ajoutées via la carte par les utilisateurs (et
-- leurs machines / performances éventuelles, en cascade), ainsi que les
-- 3 salles de démo parisiennes.
delete from gyms
where created_by is not null
   or id in (
     '00000000-0000-4000-9000-000000000002',
     '00000000-0000-4000-9000-000000000003',
     '00000000-0000-4000-9000-000000000004'
   );

-- 3. Ajoute les grandes enseignes bretonnes (adresses réelles), en plus
-- des 3 salles Basic-Fit pilotes déjà présentes à Quimper/Brest/Rennes.
insert into gyms (id, name, gps_coordinates, geofencing_radius_m) values
  ('00000000-0000-4000-9000-000000000040', 'Basic-Fit Lorient', point(47.7480, -3.3650), 150),
  ('00000000-0000-4000-9000-000000000041', 'Basic-Fit Vannes', point(47.6600, -2.7550), 150),
  ('00000000-0000-4000-9000-000000000042', 'Fitness Park Rennes', point(48.0930, -1.7030), 150),
  ('00000000-0000-4000-9000-000000000043', 'Fitness Park Quimper', point(47.9960, -4.0970), 150),
  ('00000000-0000-4000-9000-000000000044', 'Fitness Park Lanester (Lorient)', point(47.7700, -3.3550), 150),
  ('00000000-0000-4000-9000-000000000045', 'Keepcool Brest Port', point(48.3850, -4.4950), 150),
  ('00000000-0000-4000-9000-000000000046', 'Keepcool Plérin (Saint-Brieuc)', point(48.5300, -2.7550), 150),
  ('00000000-0000-4000-9000-000000000047', 'Keepcool Quimper', point(47.9870, -4.0930), 150),
  ('00000000-0000-4000-9000-000000000048', 'Keepcool Rennes', point(48.1020, -1.6750), 150),
  ('00000000-0000-4000-9000-000000000049', 'L''Orange Bleue Vannes', point(47.6350, -2.7500), 150),
  ('00000000-0000-4000-9000-000000000050', 'L''Orange Bleue Lorient', point(47.7450, -3.3600), 150),
  ('00000000-0000-4000-9000-000000000051', 'L''Orange Bleue Bain-de-Bretagne', point(47.8380, -1.6900), 150),
  ('00000000-0000-4000-9000-000000000052', 'L''Orange Bleue Montauban-de-Bretagne', point(48.1850, -1.9970), 150)
on conflict (id) do nothing;
