-- GymQuest — King of the Machine : qui détient le record actuel sur chaque
-- machine (le poids validé le plus élevé). Vue simple sur les performances
-- déjà validées, pas de nouvelle table de vérité à maintenir.

create view machine_kings as
select distinct on (p.machine_id)
  p.machine_id,
  p.user_id,
  u.pseudo,
  p.weight_kg,
  p.performed_at
from performances p
join users u on u.id = p.user_id
where p.validation_status = 'VALIDATED'
order by p.machine_id, p.weight_kg desc, p.performed_at asc;

-- Salle et machines de démonstration : de quoi scanner et tester tout de
-- suite le parcours de validation + King of the Machine, même sans salle
-- pilote réelle pour l'instant.
insert into gyms (id, name, gps_coordinates, geofencing_radius_m)
values ('00000000-0000-4000-9000-000000000001', 'Salle Découverte', point(48.8566, 2.3522), 150)
on conflict (id) do nothing;

insert into machines (id, name, targeted_muscle, gym_id, qr_code_hash) values
  ('00000000-0000-4000-9000-000000000011', 'Développé couché', 'Pectoraux', '00000000-0000-4000-9000-000000000001', 'DEMO-DC-001'),
  ('00000000-0000-4000-9000-000000000012', 'Presse à cuisses', 'Quadriceps', '00000000-0000-4000-9000-000000000001', 'DEMO-PC-001'),
  ('00000000-0000-4000-9000-000000000013', 'Tirage vertical', 'Dos', '00000000-0000-4000-9000-000000000001', 'DEMO-TV-001'),
  ('00000000-0000-4000-9000-000000000014', 'Développé militaire', 'Épaules', '00000000-0000-4000-9000-000000000001', 'DEMO-DM-001')
on conflict (id) do nothing;
