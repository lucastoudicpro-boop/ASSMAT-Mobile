-- Cocon — évolution 009
-- Co-parent, demandes de matériel, retards.
-- À exécuter après 008. Rejouable.

-- ============================================================
-- Co-parent : un second employeur sur le même contrat
-- ============================================================
alter table contrats add column if not exists coparent_id uuid references profils(id) on delete set null;

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
  );
$$;

create or replace function est_employeur(c uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from contrats
     where id = c and (employeur_id = auth.uid() or coparent_id = auth.uid())
  );
$$;

-- Les règles qui citaient l'employeur seul passent par est_employeur().
drop policy if exists contrats_lecture on contrats;
create policy contrats_lecture on contrats for select to authenticated
  using (employeur_id = auth.uid() or coparent_id = auth.uid() or salariee_id = auth.uid());

drop policy if exists contrats_modification on contrats;
create policy contrats_modification on contrats for update to authenticated
  using (employeur_id = auth.uid() or coparent_id = auth.uid()
         or (salariee_id = auth.uid() and employeur_id is null))
  with check (employeur_id = auth.uid() or coparent_id = auth.uid()
              or (salariee_id = auth.uid() and employeur_id is null));

drop policy if exists profils_lecture on profils;
create policy profils_lecture on profils for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from contrats c
       where (est_membre(c.id) and profils.id in (c.employeur_id, c.coparent_id, c.salariee_id))
    )
  );

drop policy if exists mois_ecriture on mois;
create policy mois_ecriture on mois for insert to authenticated
  with check (est_employeur(contrat_id));
drop policy if exists mois_modification on mois;
create policy mois_modification on mois for update to authenticated
  using (est_employeur(contrat_id)) with check (est_employeur(contrat_id));

drop policy if exists urgence_ecriture on fiche_urgence;
create policy urgence_ecriture on fiche_urgence for insert to authenticated
  with check (est_employeur(contrat_id));
drop policy if exists urgence_maj on fiche_urgence;
create policy urgence_maj on fiche_urgence for update to authenticated
  using (est_employeur(contrat_id)) with check (est_employeur(contrat_id));

-- Le déclencheur des jours : le co-parent écrit les mêmes colonnes que l'employeur.
create or replace function proprietaire_jour()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  emp uuid; cop uuid; sal uuid;
begin
  select employeur_id, coparent_id, salariee_id into emp, cop, sal
    from contrats where id = new.contrat_id;

  if auth.uid() = emp or auth.uid() = cop then
    if tg_op = 'UPDATE' then
      new.heures_reelles := old.heures_reelles;
      new.absence_salariee := old.absence_salariee;
    else
      new.heures_reelles := null;
      new.absence_salariee := false;
    end if;
  elsif auth.uid() = sal then
    if tg_op = 'UPDATE' then
      new.heures_prevues := old.heures_prevues;
      new.absence_enfant := old.absence_enfant;
    else
      new.heures_prevues := null;
      new.absence_enfant := false;
    end if;
  else
    raise exception 'Acces refuse a ce contrat';
  end if;
  new.maj_le := now();
  return new;
end;
$$;

-- Rejoindre : un second parent prend la place de co-parent.
create or replace function rejoindre(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inv  invitations;
  role_appelant text;
  c    contrats;
begin
  select * into inv from invitations
   where code = upper(trim(p_code)) and utilisee_le is null and expire_le > now();
  if not found then raise exception 'Code invalide ou expiré'; end if;

  select role into role_appelant from profils where id = auth.uid();
  if role_appelant is null then raise exception 'Profil introuvable'; end if;

  select * into c from contrats where id = inv.contrat_id;

  if role_appelant = 'employeur' then
    if c.salariee_id = auth.uid() then raise exception 'Impossible de rejoindre son propre contrat'; end if;
    if c.employeur_id is null then
      update contrats set employeur_id = auth.uid(), statut = 'actif' where id = c.id;
    elsif c.employeur_id = auth.uid() or c.coparent_id = auth.uid() then
      null; -- déjà membre
    elsif c.coparent_id is null then
      update contrats set coparent_id = auth.uid() where id = c.id;
    else
      raise exception 'Ce contrat a déjà deux parents';
    end if;
  elsif role_appelant = 'salariee' then
    if c.employeur_id = auth.uid() or c.coparent_id = auth.uid() then
      raise exception 'Impossible de rejoindre son propre contrat';
    end if;
    if c.salariee_id is not null and c.salariee_id <> auth.uid() then
      raise exception 'Ce contrat a déjà une salariée';
    end if;
    update contrats set salariee_id = auth.uid(), statut = 'actif' where id = c.id;
  else
    raise exception 'Rôle inconnu';
  end if;

  update invitations set utilisee_le = now() where code = inv.code;
  return c.id;
end;
$$;
revoke all on function rejoindre(text) from anon;

-- ============================================================
-- Demandes de matériel : elle demande, les parents tranchent
-- ============================================================
create table if not exists demandes (
  id          uuid primary key default gen_random_uuid(),
  contrat_id  uuid not null references contrats(id) on delete cascade,
  auteur_id   uuid not null references profils(id) on delete cascade,
  objet       text not null check (length(objet) between 1 and 200),
  detail      text check (coalesce(length(detail), 0) <= 1000),
  etat        text not null default 'attente' check (etat in ('attente', 'acceptee', 'refusee')),
  motif_refus text check (coalesce(length(motif_refus), 0) <= 500),
  decide_par  uuid references profils(id) on delete set null,
  decide_le   timestamptz,
  cree_le     timestamptz not null default now()
);

create index if not exists demandes_contrat on demandes (contrat_id, cree_le desc);

alter table demandes enable row level security;
revoke all on demandes from anon;

drop policy if exists demandes_lecture on demandes;
drop policy if exists demandes_creation on demandes;
drop policy if exists demandes_decision on demandes;
drop policy if exists demandes_suppression on demandes;

create policy demandes_lecture on demandes for select to authenticated
  using (est_membre(contrat_id));

-- La salariée seule formule une demande.
create policy demandes_creation on demandes for insert to authenticated
  with check (auteur_id = auth.uid()
              and exists (select 1 from contrats where id = demandes.contrat_id and salariee_id = auth.uid()));

-- Les parents seuls décident.
create policy demandes_decision on demandes for update to authenticated
  using (est_employeur(contrat_id)) with check (est_employeur(contrat_id));

create policy demandes_suppression on demandes for delete to authenticated
  using (auteur_id = auth.uid() and etat = 'attente');

-- ============================================================
-- Retards : un message d'une catégorie dédiée
-- ============================================================
alter table messages drop constraint if exists messages_categorie_valide;
alter table messages add constraint messages_categorie_valide
  check (categorie in ('info', 'besoin', 'photo', 'retard', 'humeur'));

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : coparent_id présent.
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'contrats' and column_name = 'coparent_id';
-- 2. Attendu : demandes, true.
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace and relname = 'demandes';
-- 3. Attendu : 4 règles.
select count(*) from pg_policies where schemaname = 'public' and tablename = 'demandes';
