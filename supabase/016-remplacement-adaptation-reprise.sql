-- Cocon — évolution 016
-- Remplacement temporaire, adaptation, transmission de reprise.
-- À exécuter après 015. Rejouable.

-- ============================================================
-- Remplacement : un accès limité et daté
-- Une nounou malade, une collègue prend le relais. Lui donner le contrat
-- entier serait excessif ; ne rien lui donner la laisse aveugle.
-- ============================================================
create table if not exists remplacements (
  id           uuid primary key default gen_random_uuid(),
  contrat_id   uuid not null references contrats(id) on delete cascade,
  titulaire_id uuid not null references profils(id) on delete cascade,
  remplacant_id uuid references profils(id) on delete set null,
  code         text unique,
  du           date not null,
  au           date not null,
  motif        text,
  accepte_le   timestamptz,
  cree_le      timestamptz not null default now(),
  check (au >= du)
);

create index if not exists remplacements_contrat on remplacements (contrat_id, du);

alter table remplacements enable row level security;
revoke all on remplacements from anon;

-- Un remplacement est en cours aujourd'hui, et la personne l'a accepté.
create or replace function remplace_ce_contrat(c uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from remplacements r
     where r.contrat_id = c
       and r.remplacant_id = auth.uid()
       and r.accepte_le is not null
       and current_date between r.du and r.au
  );
$$;

drop policy if exists remplacements_lecture on remplacements;
drop policy if exists remplacements_creation on remplacements;
drop policy if exists remplacements_maj on remplacements;
drop policy if exists remplacements_suppression on remplacements;

create policy remplacements_lecture on remplacements for select to authenticated
  using (titulaire_id = auth.uid() or remplacant_id = auth.uid() or est_employeur(contrat_id));

-- La titulaire seule ouvre un remplacement sur ses propres contrats.
create policy remplacements_creation on remplacements for insert to authenticated
  with check (titulaire_id = auth.uid()
              and exists (select 1 from contrats where id = remplacements.contrat_id and salariee_id = auth.uid()));

create policy remplacements_maj on remplacements for update to authenticated
  using (titulaire_id = auth.uid() or remplacant_id is null)
  with check (titulaire_id = auth.uid() or remplacant_id = auth.uid());

create policy remplacements_suppression on remplacements for delete to authenticated
  using (titulaire_id = auth.uid());

-- Rejoindre un remplacement par son code, sans jamais lire la table.
create or replace function rejoindre_remplacement(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare r remplacements;
begin
  select * into r from remplacements
   where code = upper(trim(p_code)) and remplacant_id is null and au >= current_date;
  if not found then raise exception 'Code invalide, déjà utilisé ou expiré'; end if;
  if r.titulaire_id = auth.uid() then raise exception 'Impossible de se remplacer soi-même'; end if;

  update remplacements
     set remplacant_id = auth.uid(), accepte_le = now(), code = null
   where id = r.id;
  return r.contrat_id;
end;
$$;
revoke all on function rejoindre_remplacement(text) from anon;

-- ============================================================
-- Le remplaçant voit le nécessaire, et rien de plus
-- ============================================================
drop policy if exists contrats_lecture on contrats;
create policy contrats_lecture on contrats for select to authenticated
  using (employeur_id = auth.uid() or coparent_id = auth.uid() or salariee_id = auth.uid()
         or remplace_ce_contrat(id));

create or replace function est_membre(c uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from contrats
     where id = c
       and (employeur_id = auth.uid() or coparent_id = auth.uid() or salariee_id = auth.uid())
  ) or remplace_ce_contrat(c);
$$;

-- Le journal : il écrit pendant son remplacement, comme la titulaire.
drop policy if exists journal_ecriture on journal;
create policy journal_ecriture on journal for insert to authenticated
  with check (exists (select 1 from contrats where id = journal.contrat_id and salariee_id = auth.uid())
              or remplace_ce_contrat(journal.contrat_id));
drop policy if exists journal_maj on journal;
create policy journal_maj on journal for update to authenticated
  using (exists (select 1 from contrats where id = journal.contrat_id and salariee_id = auth.uid())
         or remplace_ce_contrat(journal.contrat_id))
  with check (exists (select 1 from contrats where id = journal.contrat_id and salariee_id = auth.uid())
              or remplace_ce_contrat(journal.contrat_id));

-- ============================================================
-- Adaptation : les paliers du premier jour
-- ============================================================
create table if not exists adaptation (
  id          uuid primary key default gen_random_uuid(),
  contrat_id  uuid not null references contrats(id) on delete cascade,
  jour        date not null,
  duree       text not null,
  etape       text not null check (etape in ('visite', 'heure', 'matinee', 'repas', 'sieste', 'journee')),
  ressenti_salariee text check (coalesce(length(ressenti_salariee), 0) <= 1000),
  ressenti_parent   text check (coalesce(length(ressenti_parent), 0) <= 1000),
  cree_le     timestamptz not null default now(),
  unique (contrat_id, jour)
);

create index if not exists adaptation_contrat on adaptation (contrat_id, jour);

alter table adaptation enable row level security;
revoke all on adaptation from anon;

drop policy if exists adaptation_lecture on adaptation;
drop policy if exists adaptation_creation on adaptation;
drop policy if exists adaptation_maj on adaptation;
drop policy if exists adaptation_suppression on adaptation;

create policy adaptation_lecture on adaptation for select to authenticated
  using (est_membre(contrat_id));
create policy adaptation_creation on adaptation for insert to authenticated
  with check (est_membre(contrat_id));
create policy adaptation_maj on adaptation for update to authenticated
  using (est_membre(contrat_id)) with check (est_membre(contrat_id));
create policy adaptation_suppression on adaptation for delete to authenticated
  using (est_employeur(contrat_id)
         or exists (select 1 from contrats where id = adaptation.contrat_id and salariee_id = auth.uid()));

-- Chacun n'écrit que son propre ressenti.
create or replace function proprietaire_adaptation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare sal uuid;
begin
  select salariee_id into sal from contrats where id = new.contrat_id;
  if auth.uid() = sal then
    if tg_op = 'UPDATE' then new.ressenti_parent := old.ressenti_parent;
    else new.ressenti_parent := null; end if;
  else
    if tg_op = 'UPDATE' then new.ressenti_salariee := old.ressenti_salariee;
    else new.ressenti_salariee := null; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists adaptation_proprietaire on adaptation;
create trigger adaptation_proprietaire
  before insert or update on adaptation
  for each row execute function proprietaire_adaptation();

-- ============================================================
-- Transmission de reprise : ce qui a change pendant l'absence
-- ============================================================
create table if not exists reprises (
  id         uuid primary key default gen_random_uuid(),
  contrat_id uuid not null references contrats(id) on delete cascade,
  auteur_id  uuid not null references profils(id) on delete cascade,
  depuis     date not null,
  texte      text not null check (length(texte) between 1 and 3000),
  lu_le      timestamptz,
  cree_le    timestamptz not null default now()
);

create index if not exists reprises_contrat on reprises (contrat_id, cree_le desc);

alter table reprises enable row level security;
revoke all on reprises from anon;

drop policy if exists reprises_lecture on reprises;
drop policy if exists reprises_creation on reprises;
drop policy if exists reprises_maj on reprises;

create policy reprises_lecture on reprises for select to authenticated
  using (est_membre(contrat_id));
create policy reprises_creation on reprises for insert to authenticated
  with check (auteur_id = auth.uid() and est_membre(contrat_id));
create policy reprises_maj on reprises for update to authenticated
  using (est_membre(contrat_id)) with check (est_membre(contrat_id));

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : adaptation, remplacements, reprises, toutes protégées.
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace
   and relname in ('remplacements', 'adaptation', 'reprises')
 order by relname;

-- 2. Attendu : deux fonctions.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace
   and proname in ('remplace_ce_contrat', 'rejoindre_remplacement')
 order by proname;

-- 3. Attendu : aucune table sans protection.
select relname from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity;
