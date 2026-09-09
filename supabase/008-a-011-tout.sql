-- Cocon — evolutions 008 a 011, en un seul fichier. Rejouable.
-- A executer apres 004-a-007-tout.sql.

-- ====================================================================
-- INVITATION DANS LES DEUX SENS
-- ====================================================================

-- Cocon — évolution 008
-- L'assistante maternelle crée l'accueil et invite la famille.
-- À exécuter après 004-a-007. Rejouable.

-- ============================================================
-- Le contrat peut naître sans employeur : elle le crée, la famille le rejoint
-- ============================================================
alter table contrats alter column employeur_id drop not null;

-- Au moins une des deux parties doit être présente.
alter table contrats drop constraint if exists contrats_une_partie;
alter table contrats add constraint contrats_une_partie
  check (employeur_id is not null or salariee_id is not null);

-- ============================================================
-- Règles : chacun peut créer, le créateur gère jusqu'à l'arrivée de l'autre,
-- puis l'employeur gère les termes du contrat.
-- ============================================================
drop policy if exists contrats_creation on contrats;
create policy contrats_creation on contrats for insert to authenticated
  with check (employeur_id = auth.uid() or salariee_id = auth.uid());

drop policy if exists contrats_modification on contrats;
create policy contrats_modification on contrats for update to authenticated
  using (
    employeur_id = auth.uid()
    or (salariee_id = auth.uid() and employeur_id is null)
  )
  with check (
    employeur_id = auth.uid()
    or (salariee_id = auth.uid() and employeur_id is null)
  );

drop policy if exists contrats_suppression on contrats;
create policy contrats_suppression on contrats for delete to authenticated
  using (
    employeur_id = auth.uid()
    or (salariee_id = auth.uid() and employeur_id is null)
  );

-- Les invitations sont créées par l'une ou l'autre partie du contrat.
drop policy if exists invitations_creation on invitations;
create policy invitations_creation on invitations for insert to authenticated
  with check (est_membre(contrat_id));

drop policy if exists invitations_suppression on invitations;
create policy invitations_suppression on invitations for delete to authenticated
  using (est_membre(contrat_id));

-- ============================================================
-- Rejoindre : la place libre est prise selon le rôle de l'appelant
-- ============================================================
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
  select * into inv
    from invitations
   where code = upper(trim(p_code))
     and utilisee_le is null
     and expire_le > now();
  if not found then
    raise exception 'Code invalide ou expiré';
  end if;

  select role into role_appelant from profils where id = auth.uid();
  if role_appelant is null then
    raise exception 'Profil introuvable';
  end if;

  select * into c from contrats where id = inv.contrat_id;

  if role_appelant = 'employeur' then
    if c.employeur_id is not null and c.employeur_id <> auth.uid() then
      raise exception 'Ce contrat a déjà une famille';
    end if;
    if c.salariee_id = auth.uid() then
      raise exception 'Impossible de rejoindre son propre contrat';
    end if;
    update contrats set employeur_id = auth.uid(), statut = 'actif' where id = c.id;

  elsif role_appelant = 'salariee' then
    if c.salariee_id is not null and c.salariee_id <> auth.uid() then
      raise exception 'Ce contrat a déjà une salariée';
    end if;
    if c.employeur_id = auth.uid() then
      raise exception 'Impossible de rejoindre son propre contrat';
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

-- ====================================================================
-- CO-PARENT, DEMANDES, RETARDS
-- ====================================================================

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

-- ====================================================================
-- POINTAGE ARRIVEE / DEPART
-- ====================================================================

-- Cocon — évolution 010
-- Heures d'arrivée et de départ réelles, tapées par la nounou en un geste.
-- À exécuter après 008-a-009. Rejouable.

alter table jours add column if not exists arrivee time;
alter table jours add column if not exists depart  time;

-- La salariée seule écrit l'arrivée et le départ ; l'employeur seul écrit le
-- prévu. Chaque envoi de l'un préserve les colonnes de l'autre.
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
      new.heures_reelles   := old.heures_reelles;
      new.absence_salariee := old.absence_salariee;
      new.arrivee          := old.arrivee;
      new.depart           := old.depart;
    else
      new.heures_reelles   := null;
      new.absence_salariee := false;
      new.arrivee          := null;
      new.depart           := null;
    end if;

  elsif auth.uid() = sal then
    if tg_op = 'UPDATE' then
      new.heures_prevues := old.heures_prevues;
      new.absence_enfant := old.absence_enfant;
    else
      new.heures_prevues := null;
      new.absence_enfant := false;
    end if;
    -- les heures réelles se déduisent des deux pointages
    if new.arrivee is not null and new.depart is not null and new.depart > new.arrivee then
      new.heures_reelles := round(extract(epoch from (new.depart - new.arrivee)) / 3600.0, 2);
    end if;

  else
    raise exception 'Acces refuse a ce contrat';
  end if;

  new.maj_le := now();
  return new;
end;
$$;

-- ====================================================================
-- ACCUSE DE LECTURE DES MESSAGES
-- ====================================================================

-- Cocon — évolution 011
-- Accusé de lecture des messages.
-- À exécuter après 008-a-010. Rejouable.

-- ============================================================
-- Le problème
-- `messages` n'avait aucune règle de modification. L'application marquait les
-- messages comme lus, PostgREST ne mettait à jour aucune ligne, et n'en disait
-- rien : la pastille des non-lus revenait à chaque ouverture, indéfiniment.
--
-- On autorise la modification aux membres du contrat, mais un déclencheur
-- n'accepte que le champ `lu_le`. Personne ne peut réécrire le texte d'un
-- message reçu, ni changer son auteur.
-- ============================================================

drop policy if exists messages_lecture_marquee on messages;
create policy messages_lecture_marquee on messages for update to authenticated
  using (est_membre(contrat_id))
  with check (est_membre(contrat_id));

create or replace function figer_message()
returns trigger
language plpgsql
as $$
begin
  -- tout est restauré sauf l'accusé de lecture
  new.id         := old.id;
  new.contrat_id := old.contrat_id;
  new.auteur_id  := old.auteur_id;
  new.texte      := old.texte;
  new.categorie  := old.categorie;
  new.piece      := old.piece;
  new.cree_le    := old.cree_le;

  -- on ne marque comme lu que ce qu'on n'a pas écrit soi-même,
  -- et un accusé déjà posé ne se retire pas
  if old.auteur_id = auth.uid() then
    new.lu_le := old.lu_le;
  elsif old.lu_le is not null then
    new.lu_le := old.lu_le;
  end if;

  return new;
end;
$$;

drop trigger if exists messages_figes on messages;
create trigger messages_figes
  before update on messages
  for each row execute function figer_message();

-- ====================================================================
-- CONTROLES — chaque ligne doit se terminer par « correct »
-- ====================================================================
select 'coparent' as controle,
       case when count(*)=1 then 'colonne presente — correct' else 'ABSENTE' end as resultat
  from information_schema.columns where table_schema='public' and table_name='contrats' and column_name='coparent_id'
union all
select 'pointage',
       case when count(*)=2 then 'arrivee et depart — correct' else 'INCOMPLET' end
  from information_schema.columns where table_schema='public' and table_name='jours' and column_name in ('arrivee','depart')
union all
select 'demandes protegees',
       case when bool_and(relrowsecurity) then 'oui — correct' else 'NON' end
  from pg_class where relnamespace='public'::regnamespace and relname='demandes'
union all
select 'rejoindre par role',
       case when count(*)=1 then 'en place — correct' else 'ANCIENNE VERSION' end
  from pg_proc where pronamespace='public'::regnamespace and proname='rejoindre' and prosrc like '%coparent_id%'
union all
select 'declencheur des jours',
       case when count(*)=1 then 'preserve le pointage — correct' else 'ANCIENNE VERSION' end
  from pg_proc where pronamespace='public'::regnamespace and proname='proprietaire_jour' and prosrc like '%arrivee%'
union all
select 'accuse de lecture',
       case when count(*)=1 then 'regle presente — correct' else 'ABSENTE' end
  from pg_policies where schemaname='public' and tablename='messages' and cmd='UPDATE'
union all
select 'messages figes',
       case when count(*)=1 then 'declencheur present — correct' else 'ABSENT' end
  from pg_trigger where not tgisinternal and tgrelid='messages'::regclass
union all
select 'tables sans protection',
       coalesce(string_agg(relname, ', '), 'AUCUNE — correct')
  from pg_class where relnamespace='public'::regnamespace and relkind='r' and not relrowsecurity;
