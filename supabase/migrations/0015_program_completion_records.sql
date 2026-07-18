-- GymQuest — la case cochée devient un vrai signal de progression pour les
-- amis : on capture le poids/les reps réellement faits, on détecte un
-- nouveau record personnel sur cet exercice, et ça compte des points —
-- au lieu d'une simple case "fait/pas fait" sans donnée derrière.
-- Créer/personnaliser son propre programme reste totalement indépendant
-- de tout ça (aucun changement de ce côté).

alter table program_exercise_completions
  add column weight_kg numeric,
  add column reps integer,
  add column is_record boolean not null default false;

create or replace function complete_program_exercise(
  p_program_exercise_id uuid,
  p_gym_id uuid,
  p_user_lat double precision,
  p_user_lon double precision,
  p_weight_kg numeric default null,
  p_reps integer default null
) returns program_exercise_completions as $$
declare
  v_gym record;
  v_distance_m double precision;
  v_completion program_exercise_completions;
  v_already_checked_in boolean;
  v_previous_best numeric;
  v_is_record boolean := false;
begin
  select g.id, (g.gps_coordinates)[0] as lat, (g.gps_coordinates)[1] as lon, g.geofencing_radius_m
    into v_gym
    from gyms g
    where g.id = p_gym_id;

  if v_gym is null then
    raise exception 'Salle introuvable';
  end if;

  v_distance_m := 111320 * sqrt(
    power(v_gym.lat - p_user_lat, 2) + power((v_gym.lon - p_user_lon) * cos(radians(p_user_lat)), 2)
  );

  if v_distance_m > v_gym.geofencing_radius_m then
    raise exception 'Tu dois être dans la salle pour valider (tu es à %m).', round(v_distance_m::numeric);
  end if;

  if p_weight_kg is not null then
    select max(weight_kg) into v_previous_best
      from program_exercise_completions
      where user_id = auth.uid() and program_exercise_id = p_program_exercise_id;
    if v_previous_best is null or p_weight_kg > v_previous_best then
      v_is_record := true;
    end if;
  end if;

  insert into program_exercise_completions (user_id, program_exercise_id, gym_id, weight_kg, reps, is_record)
  values (auth.uid(), p_program_exercise_id, p_gym_id, p_weight_kg, p_reps, v_is_record)
  on conflict (user_id, program_exercise_id, completed_on) do nothing
  returning * into v_completion;

  if v_completion.id is null then
    -- Déjà coché aujourd'hui : on renvoie l'existant sans re-attribuer de points.
    select * into v_completion from program_exercise_completions
      where user_id = auth.uid() and program_exercise_id = p_program_exercise_id and completed_on = current_date;
  else
    if p_reps is not null then
      update users set total_points = total_points + greatest(1, p_reps) where id = auth.uid();
    end if;
  end if;

  select exists(
    select 1 from gym_checkins
    where user_id = auth.uid() and gym_id = p_gym_id and checked_in_at::date = current_date
  ) into v_already_checked_in;

  if not v_already_checked_in then
    insert into gym_checkins (user_id, gym_id) values (auth.uid(), p_gym_id);
  end if;

  return v_completion;
end;
$$ language plpgsql security definer;
