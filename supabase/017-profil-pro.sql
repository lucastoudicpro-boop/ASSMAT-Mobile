-- Cocon — évolution 017
-- Profil professionnel de la salariée, visible des familles.
-- À exécuter après 016. Rejouable.

-- ============================================================
-- Ce qu'une assistante maternelle peut montrer
-- Ni salaire, ni numéro de sécurité sociale, ni adresse précise :
-- ce qui rassure une famille, et rien de plus.
-- ============================================================
create table if not exists profils_pro (
  id            uuid primary key references profils(id) on delete cascade,
  photo         text,
  presentation  text check (coalesce(length(presentation), 0) <= 1500),
  depuis        date,
  agrement_num  text,
  agrement_jusqu date,
  places        smallint check (places is null or places between 1 and 6),
  diplomes      jsonb not null default '[]'::jsonb,
  formations    jsonb not null default '[]'::jsonb,
  langues       jsonb not null default '[]'::jsonb,
  accueil       jsonb not null default '{}'::jsonb,
  maj_le        timestamptz not null default now()
);

comment on table profils_pro is
  'Profil professionnel montre aux familles. Jamais de numero de securite sociale ni de salaire.';
comment on column profils_pro.diplomes is
  'Liste : [{"type":"cap_aepe","intitule":"","annee":2019,"organisme":""}]';
comment on column profils_pro.formations is
  'Liste : [{"type":"psc1","intitule":"","annee":2024,"jusqu":"2027-06-01"}]';
comment on column profils_pro.accueil is
  'Cadre d''accueil : {"jardin":true,"animaux":"un chat","non_fumeur":true,"etage":0,"ascenseur":false}';

alter table profils_pro enable row level security;
revoke all on profils_pro from anon;

-- ============================================================
-- Qui peut lire ce profil
-- La salariée, et toute famille reliée à elle par un contrat. Une famille qui
-- a quitté le contrat ne le voit plus.
-- ============================================================
create or replace function relie_a_salariee(sal uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from contrats c
     where c.salariee_id = sal
       and c.statut <> 'termine'
       and (c.employeur_id = auth.uid() or c.coparent_id = auth.uid())
  );
$$;

drop policy if exists pro_lecture on profils_pro;
drop policy if exists pro_creation on profils_pro;
drop policy if exists pro_maj on profils_pro;
drop policy if exists pro_suppression on profils_pro;

create policy pro_lecture on profils_pro for select to authenticated
  using (id = auth.uid() or relie_a_salariee(id));

-- Seule la salariée écrit son propre profil.
create policy pro_creation on profils_pro for insert to authenticated
  with check (id = auth.uid());
create policy pro_maj on profils_pro for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy pro_suppression on profils_pro for delete to authenticated
  using (id = auth.uid());

-- L'horodatage se met à jour seul.
create or replace function toucher_profil_pro()
returns trigger
language plpgsql
as $$
begin
  new.maj_le := now();
  new.id := old.id;      -- on ne change pas de propriétaire
  return new;
end;
$$;

drop trigger if exists profil_pro_touche on profils_pro;
create trigger profil_pro_touche
  before update on profils_pro
  for each row execute function toucher_profil_pro();

-- ============================================================
-- La photo du profil suit le chemin des photos
-- ============================================================
-- Une photo de profil n'est rattachée à aucun contrat : on autorise sa lecture
-- aux familles reliées, via la table profils_pro.
drop policy if exists "photo profil lecture" on storage.objects;
create policy "photo profil lecture" on storage.objects for select to authenticated
  using (
    bucket_id = 'photos'
    and exists (
      select 1 from public.profils_pro p
       where p.photo = name
         and (p.id = auth.uid() or public.relie_a_salariee(p.id))
    )
  );

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : profils_pro, protégée.
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace and relname = 'profils_pro';

-- 2. Attendu : quatre règles.
select policyname, cmd from pg_policies
 where schemaname = 'public' and tablename = 'profils_pro'
 order by policyname;

-- 3. Attendu : relie_a_salariee.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace and proname = 'relie_a_salariee';
