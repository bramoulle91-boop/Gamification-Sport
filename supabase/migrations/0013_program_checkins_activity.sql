-- GymQuest — check-in léger + activité des amis, en attendant que toutes
-- les machines aient un QR code : cocher un exercice de son programme sert
-- de déclencheur de présence en salle, validé par géolocalisation côté
-- serveur (même principe que le niveau 1). Visible par les amis dans un
-- fil d'activité : "X vient de se connecter à Y" / "X vient de terminer Z".

create table gym_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  gym_id uuid not null references gyms (id) on delete cascade,
  checked_in_at timestamptz not null default now()
);

create table program_exercise_completions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  program_exercise_id uuid not null references program_exercises (id) on delete cascade,
  gym_id uuid references gyms (id),
  completed_on date not null default current_date,
  completed_at timestamptz not null default now(),
  unique (user_id, program_exercise_id, completed_on)
);

alter table gym_checkins enable row level security;
alter table program_exercise_completions enable row level security;

-- Visibles par tous (dont les amis) pour alimenter le fil d'activité ;
-- l'écriture d'un check-in/exercice validé ne passe que par la fonction
-- sécurisée ci-dessous, qui vérifie la position réelle côté serveur —
-- un simple insert client ne suffit pas à le déclarer.
create policy "gym_checkins_select_all" on gym_checkins for select using (true);
create policy "completions_select_all" on program_exercise_completions for select using (true);

-- Décocher reste une action libre côté utilisateur (retirer sa propre
-- déclaration ne présente pas de risque de triche).
create policy "completions_delete_own" on program_exercise_completions for delete
  using (auth.uid() = user_id);

-- Valide géographiquement qu'on est bien dans la salle (même formule
-- approximative que log_performance_level1), enregistre l'exercice coché
-- du jour, et déclenche un check-in si c'est la première validation du
-- jour dans cette salle.
create or replace function complete_program_exercise(
  p_program_exercise_id uuid,
  p_gym_id uuid,
  p_user_lat double precision,
  p_user_lon double precision
) returns program_exercise_completions as $$
declare
  v_gym record;
  v_distance_m double precision;
  v_completion program_exercise_completions;
  v_already_checked_in boolean;
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

  insert into program_exercise_completions (user_id, program_exercise_id, gym_id)
  values (auth.uid(), p_program_exercise_id, p_gym_id)
  on conflict (user_id, program_exercise_id, completed_on) do update set gym_id = excluded.gym_id
  returning * into v_completion;

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
