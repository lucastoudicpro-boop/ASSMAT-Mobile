-- Cocon — évolution 006
-- Le journal de la journée : elle écrit, les parents lisent.
-- À exécuter après 005. Ce fichier ajoute, il ne supprime rien.

create table if not exists journal (
  contrat_id    uuid not null references contrats(id) on delete cascade,
  jour          date not null,
  repas         text check (repas in ('bien', 'moyen', 'peu', 'refus')),
  sieste_debut  time,
  sieste_fin    time,
  humeur        text check (humeur in ('joyeux', 'calme', 'fatigue', 'grognon', 'souffrant')),
  couches       smallint check (couches between 0 and 20),
  mot           text check (coalesce(length(mot), 0) <= 2000),
  maj_le        timestamptz not null default now(),
  primary key (contrat_id, jour)
);

create index if not exists journal_contrat on journal (contrat_id, jour desc);

alter table journal enable row level security;
revoke all on journal from anon;

drop policy if exists journal_lecture on journal;
drop policy if exists journal_ecriture on journal;
drop policy if exists journal_maj on journal;
drop policy if exists journal_suppression on journal;

-- Les deux parties lisent. Seule la salariée écrit : le parent ne peut pas
-- réécrire ce qu'elle a noté, et c'est bien l'intérêt d'une transmission.
create policy journal_lecture on journal for select to authenticated
  using (est_membre(contrat_id));

create policy journal_ecriture on journal for insert to authenticated
  with check (
    exists (select 1 from contrats
             where id = journal.contrat_id and salariee_id = auth.uid())
  );

create policy journal_maj on journal for update to authenticated
  using (
    exists (select 1 from contrats
             where id = journal.contrat_id and salariee_id = auth.uid())
  )
  with check (
    exists (select 1 from contrats
             where id = journal.contrat_id and salariee_id = auth.uid())
  );

create policy journal_suppression on journal for delete to authenticated
  using (
    exists (select 1 from contrats
             where id = journal.contrat_id and salariee_id = auth.uid())
  );

drop trigger if exists journal_horodate on journal;
create trigger journal_horodate
  before insert or update on journal
  for each row execute function horodater();

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. La table existe et est protégée. Attendu : journal, true.
select relname, relrowsecurity
  from pg_class
 where relnamespace = 'public'::regnamespace and relname = 'journal';

-- 2. Quatre règles, dont une seule de lecture. Attendu : 4 lignes.
select policyname, cmd from pg_policies
 where schemaname = 'public' and tablename = 'journal' order by policyname;

-- 3. Le parent ne doit pas pouvoir écrire : les trois règles d'écriture
--    exigent d'être la salariée du contrat. Attendu : 3 lignes contenant
--    salariee_id.
select policyname
  from pg_policies
 where schemaname = 'public' and tablename = 'journal'
   and cmd <> 'SELECT'
   and coalesce(qual, '') || coalesce(with_check, '') like '%salariee_id%';
