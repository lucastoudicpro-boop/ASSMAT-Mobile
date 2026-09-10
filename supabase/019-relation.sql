-- Cocon — évolution 019
-- Les premières fois, ce qu'on a fait aujourd'hui, le mot du soir.
-- À exécuter après 018. Rejouable.

-- ============================================================
-- Les premières fois
--
-- Un premier pas chez la nounou, c'est le sujet le plus delicat du metier.
-- Beaucoup d'assistantes maternelles taisent l'evenement pour laisser aux
-- parents la joie de le decouvrir. D'autres racontent tout de suite. Aucune
-- des deux facons n'a raison : la table porte donc le choix.
-- ============================================================
create table if not exists premieres_fois (
  id          uuid primary key default gen_random_uuid(),
  contrat_id  uuid not null references contrats(id) on delete cascade,
  auteur_id   uuid not null references profils(id) on delete cascade,
  type        text not null,
  jour        date not null default current_date,
  mot         text check (coalesce(length(mot), 0) <= 800),
  photo       text,
  -- 'raconte'  : le detail est visible tout de suite
  -- 'devine'   : le parent est prevenu qu'il s'est passe quelque chose,
  --              le detail se decouvre quand il le demande
  facon       text not null default 'raconte' check (facon in ('raconte', 'devine')),
  devoile_le  timestamptz,
  vu_le       timestamptz,
  aussi_maison boolean,          -- le parent dit l'avoir vu a la maison aussi
  cree_le     timestamptz not null default now()
);

create index if not exists premieres_contrat on premieres_fois (contrat_id, jour desc);

alter table premieres_fois enable row level security;
revoke all on premieres_fois from anon;

drop policy if exists pf_lecture on premieres_fois;
drop policy if exists pf_creation on premieres_fois;
drop policy if exists pf_maj on premieres_fois;
drop policy if exists pf_suppression on premieres_fois;

create policy pf_lecture on premieres_fois for select to authenticated
  using (est_membre(contrat_id));
create policy pf_creation on premieres_fois for insert to authenticated
  with check (auteur_id = auth.uid() and est_membre(contrat_id));
create policy pf_maj on premieres_fois for update to authenticated
  using (est_membre(contrat_id)) with check (est_membre(contrat_id));
create policy pf_suppression on premieres_fois for delete to authenticated
  using (auteur_id = auth.uid());

-- L'auteur seul change le fond ; l'autre ne fait qu'accuser et devoiler.
create or replace function proteger_premiere()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.contrat_id := old.contrat_id;
  new.auteur_id := old.auteur_id;
  new.cree_le := old.cree_le;
  if auth.uid() is distinct from old.auteur_id then
    new.type := old.type;
    new.jour := old.jour;
    new.mot := old.mot;
    new.photo := old.photo;
    new.facon := old.facon;
  end if;
  return new;
end;
$$;

drop trigger if exists premiere_protegee on premieres_fois;
create trigger premiere_protegee
  before update on premieres_fois
  for each row execute function proteger_premiere();

-- ============================================================
-- Ce qu'on a fait aujourd'hui
--
-- Une comptine chantee chez la nounou et reprise le soir a la maison, c'est
-- un fil qui relie les deux endroits. Personne ne le transmet aujourd'hui.
-- ============================================================
alter table journal add column if not exists activites jsonb not null default '[]'::jsonb;
alter table journal add column if not exists comptines jsonb not null default '[]'::jsonb;
alter table journal add column if not exists livres jsonb not null default '[]'::jsonb;

comment on column journal.comptines is
  'Ce qui a ete chante : ["Une souris verte"]. Les parents peuvent reprendre le soir.';
comment on column journal.livres is
  'Ce qui a ete lu : [{"titre":"","auteur":""}]';

-- ============================================================
-- Le mot du soir
--
-- Le journal ne va que dans un sens : la nounou raconte, le parent lit. Une
-- reponse referme la boucle, et lui dit que c'est lu.
-- ============================================================
alter table journal add column if not exists reponse_parent text
  check (coalesce(length(reponse_parent), 0) <= 800);
alter table journal add column if not exists repondu_le timestamptz;
alter table journal add column if not exists coeur boolean not null default false;

comment on column journal.coeur is
  'Le parent a marque cette journee. Un geste bref, sans obligation d''ecrire.';

-- Le parent ecrit sa reponse ; il ne touche pas au reste de la journee.
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

-- Le parent doit pouvoir modifier la ligne pour y repondre.
drop policy if exists journal_reponse on journal;
create policy journal_reponse on journal for update to authenticated
  using (est_employeur(contrat_id)) with check (est_employeur(contrat_id));

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : premieres_fois, protégée.
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace and relname = 'premieres_fois';

-- 2. Attendu : activites, comptines, livres, reponse_parent, repondu_le, coeur.
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'journal'
   and column_name in ('activites', 'comptines', 'livres', 'reponse_parent', 'repondu_le', 'coeur')
 order by column_name;

-- 3. Attendu : deux déclencheurs.
select tgname from pg_trigger
 where not tgisinternal and tgrelid in ('journal'::regclass, 'premieres_fois'::regclass)
 order by tgname;
