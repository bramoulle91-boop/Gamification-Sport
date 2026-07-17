-- GymQuest — corrige la création du profil utilisateur.
--
-- Bug : la table `users` n'avait aucune policy RLS d'insertion, et la
-- création du profil se faisait côté client juste après l'inscription
-- (avant confirmation email, donc sans session valide). Résultat : le
-- compte existe dans auth.users mais jamais dans public.users, et toute
-- lecture du profil échoue avec "cannot coerce the result to a single
-- JSON object" (0 ligne trouvée par .single()).
--
-- Correctif : un trigger côté serveur crée systématiquement la ligne
-- public.users dès la création du compte auth.users, indépendamment de
-- l'état de la session côté client.

create or replace function public.handle_new_user() returns trigger as $$
begin
  insert into public.users (id, pseudo, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'pseudo', split_part(new.email, '@', 1)),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer set search_path = public;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Garde-fou : autorise aussi la création cliente d'un profil pour son
-- propre compte (au cas où on en ait besoin ailleurs plus tard).
create policy "users_insert_own" on users for insert
  with check (auth.uid() = id);

-- Rattrape les comptes déjà créés avant ce correctif (dont le tien).
insert into public.users (id, pseudo, email)
select au.id, split_part(au.email, '@', 1), au.email
from auth.users au
left join public.users pu on pu.id = au.id
where pu.id is null;
