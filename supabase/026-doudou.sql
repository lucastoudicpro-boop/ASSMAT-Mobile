-- Cocon — évolution 026
-- Le doudou resté chez la nounou.
-- À exécuter après 025. Rejouable.

-- ============================================================
-- Un enfant parti sans son doudou, c'est une soirée difficile pour tout le
-- monde. La nounou le signale d'une case, le parent le voit sur son accueil
-- avant même d'ouvrir le journal.
-- ============================================================
alter table journal add column if not exists doudou boolean not null default false;

comment on column journal.doudou is
  'Le doudou est reste chez la salariee ce jour-la.';

-- Le déclencheur qui protège le journal doit laisser passer cette colonne
-- côté salariée, et la figer côté parent comme le reste de la journée.
create or replace function proteger_journal()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare sal uuid;
begin
  select salariee_id into sal from contrats where id = new.contrat_id;
  if auth.uid() is distinct from sal and not remplace_ce_contrat(new.contrat_id) then
    new.repas := old.repas;
    new.humeur := old.humeur;
    new.sieste_debut := old.sieste_debut;
    new.sieste_fin := old.sieste_fin;
    new.siestes := old.siestes;
    new.couches := old.couches;
    new.mot := old.mot;
    new.activites := old.activites;
    new.comptines := old.comptines;
    new.livres := old.livres;
    new.doudou := old.doudou;
    if new.reponse_parent is distinct from old.reponse_parent then new.repondu_le := now(); end if;
  else
    new.reponse_parent := old.reponse_parent;
    new.repondu_le := old.repondu_le;
    new.coeur := old.coeur;
  end if;
  return new;
end;
$$;

drop trigger if exists journal_protege on journal;
create trigger journal_protege
  before update on journal
  for each row execute function proteger_journal();

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : la colonne.
select column_name, data_type from information_schema.columns
 where table_schema = 'public' and table_name = 'journal' and column_name = 'doudou';

-- 2. Attendu : le déclencheur.
select tgname from pg_trigger
 where not tgisinternal and tgrelid = 'journal'::regclass and tgname = 'journal_protege';

-- 3. Attendu : aucune table sans protection.
select relname from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity;
