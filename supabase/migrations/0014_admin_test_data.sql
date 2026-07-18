-- GymQuest — données de test pour vérifier TOUTES les fonctionnalités
-- depuis un seul compte, sans avoir à convaincre de vrais amis de
-- s'inscrire. Deux parties indépendantes, à exécuter séparément.

-- =====================================================================
-- PARTIE 1 — Devenir "staff" de Basic-Fit Quimper avec TON compte actuel.
-- Aucun compte supplémentaire nécessaire. Remplace 'Lokeii' si besoin.
-- Débloque l'écran Profil → "Espace staff".
-- =====================================================================
insert into gym_staff (gym_id, user_id)
select '00000000-0000-4000-9000-000000000001', id
from users
where pseudo = 'Lokeii'
on conflict do nothing;

-- =====================================================================
-- PARTIE 2 — À exécuter seulement après avoir créé un 2e compte de test
-- dans l'appli (voir les instructions données à côté de ce fichier).
-- Remplace 'Lokeii' et 'AmiTest' par les vrais pseudos si différents.
-- =====================================================================
do $$
declare
  v_me uuid;
  v_friend uuid;
  v_gym uuid := '00000000-0000-4000-9000-000000000001'; -- Basic-Fit Quimper
  v_machine_king uuid := '00000000-0000-4000-9000-000000000011'; -- Développé couché
  v_machine_staff uuid := '00000000-0000-4000-9000-000000000012'; -- Presse à cuisses
  v_exercise uuid;
begin
  select id into v_me from users where pseudo = 'Lokeii';
  select id into v_friend from users where pseudo = 'AmiTest';

  if v_me is null then
    raise exception 'Pseudo "Lokeii" introuvable — adapte le nom au tien.';
  end if;
  if v_friend is null then
    raise exception 'Pseudo "AmiTest" introuvable — crée d''abord ce 2e compte dans l''appli.';
  end if;

  -- Salle habituelle + un peu d'historique, pour un classement réaliste.
  update users
  set home_gym_id = v_gym,
      total_points = 850,
      streak_history = jsonb_build_array(
        jsonb_build_object('date', (current_date - 2)::text),
        jsonb_build_object('date', (current_date - 1)::text),
        jsonb_build_object('date', current_date::text)
      )
  where id = v_friend;

  -- Amitié directement débloquée (pas besoin de valider la demande).
  insert into friendships (user_id_1, user_id_2, status)
  values (v_me, v_friend, 'DEBLOCKED')
  on conflict (user_id_1, user_id_2) do update set status = 'DEBLOCKED';

  -- Un record validé -> AmiTest devient "Roi" du Développé couché à
  -- Basic-Fit Quimper (visible sur la carte + Classement).
  insert into performances (user_id, machine_id, weight_kg, reps, validation_level, validation_status)
  values (v_friend, v_machine_king, 85, 8, '1', 'VALIDATED');

  -- Une performance niveau 3 EN ATTENTE sur une autre machine -> à valider
  -- depuis "Espace staff" (partie 1 requise pour la voir).
  insert into performances (user_id, machine_id, weight_kg, reps, validation_level, validation_status)
  values (v_friend, v_machine_staff, 120, 5, '3', 'PENDING');

  -- Check-in du jour -> AmiTest apparaît comme "ami dans cette salle" sur
  -- la carte, et dans le fil d'activité de l'onglet Amis.
  insert into gym_checkins (user_id, gym_id) values (v_friend, v_gym);

  -- Un exercice du Programme Découverte coché -> deuxième ligne dans le
  -- fil d'activité ("AmiTest vient de terminer ... à Basic-Fit Quimper").
  select id into v_exercise
  from program_exercises
  where program_id = '00000000-0000-4000-8000-000000000001'
  order by order_index
  limit 1;

  if v_exercise is not null then
    insert into program_exercise_completions (user_id, program_exercise_id, gym_id)
    values (v_friend, v_exercise, v_gym)
    on conflict (user_id, program_exercise_id, completed_on) do nothing;
  end if;
end $$;
