-- GymQuest — corrige la position de plusieurs salles bretonnes ajoutées en
-- 0011 : les coordonnées avaient été estimées au niveau du quartier sans
-- vérification cartographique précise et étaient trop approximatives.
-- Recalées ici avec des repères plus fiables (centre-ville / quartier
-- confirmé par l'adresse réelle de chaque enseigne).

update gyms set gps_coordinates = point(47.7460, -3.3670) where id = '00000000-0000-4000-9000-000000000040'; -- Basic-Fit Lorient
update gyms set gps_coordinates = point(47.6570, -2.7580) where id = '00000000-0000-4000-9000-000000000041'; -- Basic-Fit Vannes
update gyms set gps_coordinates = point(48.0870, -1.6350) where id = '00000000-0000-4000-9000-000000000042'; -- Fitness Park Rennes (La Pommeraie, ZA Sud-Est)
update gyms set gps_coordinates = point(47.9930, -4.0940) where id = '00000000-0000-4000-9000-000000000043'; -- Fitness Park Quimper
update gyms set gps_coordinates = point(47.7717, -3.3564) where id = '00000000-0000-4000-9000-000000000044'; -- Fitness Park Lanester
update gyms set gps_coordinates = point(48.3830, -4.4930) where id = '00000000-0000-4000-9000-000000000045'; -- Keepcool Brest Port (quai de la Douane)
update gyms set gps_coordinates = point(48.5333, -2.7719) where id = '00000000-0000-4000-9000-000000000046'; -- Keepcool Plérin
update gyms set gps_coordinates = point(47.9920, -4.1000) where id = '00000000-0000-4000-9000-000000000047'; -- Keepcool Quimper
update gyms set gps_coordinates = point(48.1030, -1.6780) where id = '00000000-0000-4000-9000-000000000048'; -- Keepcool Rennes (Place du Colombier)
update gyms set gps_coordinates = point(47.6480, -2.7550) where id = '00000000-0000-4000-9000-000000000049'; -- L'Orange Bleue Vannes (Kerlann)
update gyms set gps_coordinates = point(47.7500, -3.3740) where id = '00000000-0000-4000-9000-000000000050'; -- L'Orange Bleue Lorient
update gyms set gps_coordinates = point(47.8378, -1.6836) where id = '00000000-0000-4000-9000-000000000051'; -- L'Orange Bleue Bain-de-Bretagne
update gyms set gps_coordinates = point(48.1833, -1.9917) where id = '00000000-0000-4000-9000-000000000052'; -- L'Orange Bleue Montauban-de-Bretagne
