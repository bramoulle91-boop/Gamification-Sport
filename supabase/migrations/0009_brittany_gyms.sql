-- GymQuest — recentre les données de démo sur la vraie zone de test : la
-- Bretagne (Quimper, Brest, Rennes) plutôt que des salles parisiennes
-- fictives.

-- La salle de démo existante devient la vraie salle de l'utilisateur
-- pilote : Basic-Fit Quimper (15 Boulevard Amiral de Kerguelen).
update gyms
set name = 'Basic-Fit Quimper', gps_coordinates = point(47.9950, -4.0980)
where id = '00000000-0000-4000-9000-000000000001';

insert into gyms (id, name, gps_coordinates, geofencing_radius_m) values
  ('00000000-0000-4000-9000-000000000005', 'Basic-Fit Brest', point(48.3900, -4.4860), 20000000),
  ('00000000-0000-4000-9000-000000000006', 'Basic-Fit Rennes', point(48.1050, -1.6700), 20000000)
on conflict (id) do nothing;

-- Mêmes 4 machines de démo, dupliquées pour Brest et Rennes, avec des QR
-- codes propres à chaque salle — pour que le frère à Brest et les potes à
-- Rennes puissent aussi tester le scan chez eux.
insert into machines (id, name, targeted_muscle, gym_id, qr_code_hash) values
  ('00000000-0000-4000-9000-000000000021', 'Développé couché', 'Pectoraux', '00000000-0000-4000-9000-000000000005', 'BREST-DC-001'),
  ('00000000-0000-4000-9000-000000000022', 'Presse à cuisses', 'Quadriceps', '00000000-0000-4000-9000-000000000005', 'BREST-PC-001'),
  ('00000000-0000-4000-9000-000000000023', 'Tirage vertical', 'Dos', '00000000-0000-4000-9000-000000000005', 'BREST-TV-001'),
  ('00000000-0000-4000-9000-000000000024', 'Développé militaire', 'Épaules', '00000000-0000-4000-9000-000000000005', 'BREST-DM-001'),
  ('00000000-0000-4000-9000-000000000031', 'Développé couché', 'Pectoraux', '00000000-0000-4000-9000-000000000006', 'RENNES-DC-001'),
  ('00000000-0000-4000-9000-000000000032', 'Presse à cuisses', 'Quadriceps', '00000000-0000-4000-9000-000000000006', 'RENNES-PC-001'),
  ('00000000-0000-4000-9000-000000000033', 'Tirage vertical', 'Dos', '00000000-0000-4000-9000-000000000006', 'RENNES-TV-001'),
  ('00000000-0000-4000-9000-000000000034', 'Développé militaire', 'Épaules', '00000000-0000-4000-9000-000000000006', 'RENNES-DM-001')
on conflict (id) do nothing;
