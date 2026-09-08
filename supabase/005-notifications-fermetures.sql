-- Cocon — évolution 005
-- Jetons de notification et absences de la salariée.
-- À exécuter après 004. Ce fichier ajoute, il ne supprime rien.

-- ============================================================
-- Jetons de notification
-- Un appareil, un jeton. Une personne peut en avoir plusieurs.
-- ============================================================
create table if not exists jetons_push (
  jeton      text primary key,
  personne_id uuid not null references profils(id) on delete cascade,
  application text not null check (application in ('parent', 'nounou')),
  maj_le     timestamptz not null default now()
);

create index if not exists jetons_personne on jetons_push (personne_id);

alter table jetons_push enable row level security;

revoke all on jetons_push from anon;

drop policy if exists jetons_lecture on jetons_push;
drop policy if exists jetons_ecriture on jetons_push;
drop policy if exists jetons_maj on jetons_push;
drop policy if exists jetons_suppression on jetons_push;

-- Chacun ne voit et ne gère que ses propres jetons. L'envoi des notifications
-- passe par la fonction serveur, qui utilise la clé de service.
create policy jetons_lecture on jetons_push for select to authenticated
  using (personne_id = auth.uid());

create policy jetons_ecriture on jetons_push for insert to authenticated
  with check (personne_id = auth.uid());

create policy jetons_maj on jetons_push for update to authenticated
  using (personne_id = auth.uid()) with check (personne_id = auth.uid());

create policy jetons_suppression on jetons_push for delete to authenticated
  using (personne_id = auth.uid());

-- ============================================================
-- Absences de la salariée
-- Ses congés et fermetures, visibles de toutes ses familles.
-- ============================================================
create table if not exists fermetures (
  id          uuid primary key default gen_random_uuid(),
  salariee_id uuid not null references profils(id) on delete cascade,
  du          date not null,
  au          date not null,
  motif       text,
  cree_le     timestamptz not null default now(),
  check (au >= du)
);

create index if not exists fermetures_salariee on fermetures (salariee_id, du);

alter table fermetures enable row level security;
revoke all on fermetures from anon;

drop policy if exists fermetures_lecture on fermetures;
drop policy if exists fermetures_ecriture on fermetures;
drop policy if exists fermetures_maj on fermetures;
drop policy if exists fermetures_suppression on fermetures;

-- La salariée gère les siennes. Les employeurs qui ont un contrat avec elle
-- les lisent : ils doivent pouvoir s'organiser.
create policy fermetures_lecture on fermetures for select to authenticated
  using (
    salariee_id = auth.uid()
    or exists (select 1 from contrats c
                where c.salariee_id = fermetures.salariee_id
                  and c.employeur_id = auth.uid()
                  and c.statut <> 'termine')
  );

create policy fermetures_ecriture on fermetures for insert to authenticated
  with check (salariee_id = auth.uid());

create policy fermetures_maj on fermetures for update to authenticated
  using (salariee_id = auth.uid()) with check (salariee_id = auth.uid());

create policy fermetures_suppression on fermetures for delete to authenticated
  using (salariee_id = auth.uid());

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Les deux tables existent et sont protégées. Attendu : deux lignes, true.
select relname, relrowsecurity
  from pg_class
 where relnamespace = 'public'::regnamespace
   and relname in ('jetons_push', 'fermetures');

-- 2. Quatre règles par table. Attendu : jetons_push 4, fermetures 4.
select tablename, count(*) as regles
  from pg_policies
 where schemaname = 'public' and tablename in ('jetons_push', 'fermetures')
 group by tablename;

-- 3. Le rôle anonyme n'a rien. Attendu : aucune ligne.
select table_name from information_schema.role_table_grants
 where grantee = 'anon' and table_schema = 'public'
   and table_name in ('jetons_push', 'fermetures');
