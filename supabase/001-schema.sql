-- AssMat+ partagé — schéma
-- À exécuter dans l'éditeur SQL de Supabase, sur un projet neuf.
-- Le fichier est rejouable : il supprime et recrée l'ensemble.

-- ============================================================
-- Nettoyage
-- ============================================================
drop table if exists annonces cascade;
drop table if exists membres_espace cascade;
drop table if exists espaces cascade;
drop table if exists support cascade;
drop table if exists consentements cascade;
drop table if exists messages cascade;
drop table if exists mois cascade;
drop table if exists jours cascade;
drop table if exists invitations cascade;
drop table if exists contrats cascade;
drop table if exists profils cascade;

drop function if exists est_membre(uuid) cascade;
drop function if exists est_membre_espace(uuid) cascade;
drop function if exists rejoindre(text) cascade;
drop function if exists proprietaire_jour() cascade;
drop function if exists horodater() cascade;

-- ============================================================
-- Personnes
-- ============================================================
create table profils (
  id        uuid primary key references auth.users on delete cascade,
  role      text not null check (role in ('employeur', 'salariee')),
  prenom    text,
  nom       text,
  telephone text,
  cree_le   timestamptz not null default now()
);

comment on table profils is
  'Une ligne par compte. Ni IBAN, ni numero de securite sociale : ces donnees restent sur le telephone de l''employeur.';

-- ============================================================
-- Contrats : un par enfant accueilli
-- Une salariee peut en avoir plusieurs, chez des employeurs differents.
-- ============================================================
create table contrats (
  id               uuid primary key default gen_random_uuid(),
  employeur_id     uuid not null references profils(id) on delete cascade,
  salariee_id      uuid references profils(id) on delete set null,
  enfant_prenom    text not null,
  enfant_naissance date,
  statut           text not null default 'invitation'
                     check (statut in ('invitation', 'actif', 'termine')),
  cree_le          timestamptz not null default now()
);

create index contrats_employeur on contrats (employeur_id);
create index contrats_salariee   on contrats (salariee_id);

-- Appartenance a un contrat.
-- security definer : la fonction doit lire contrats sans repasser par ses
-- propres politiques, sinon les regles des autres tables tournent en rond.
create function est_membre(c uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from contrats
     where id = c
       and (employeur_id = auth.uid() or salariee_id = auth.uid())
  );
$$;

-- ============================================================
-- Invitations : la salariee rejoint un contrat par un code
-- La table n'est jamais lisible ; seul l'appel a rejoindre() y accede.
-- ============================================================
create table invitations (
  code        text primary key,
  contrat_id  uuid not null references contrats(id) on delete cascade,
  expire_le   timestamptz not null,
  utilisee_le timestamptz
);

create function rejoindre(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inv invitations;
begin
  select * into inv
    from invitations
   where code = upper(trim(p_code))
     and utilisee_le is null
     and expire_le > now();

  if not found then
    raise exception 'Code invalide ou expire';
  end if;

  update contrats
     set salariee_id = auth.uid(),
         statut = 'actif'
   where id = inv.contrat_id
     and salariee_id is null;

  if not found then
    raise exception 'Ce contrat a deja une salariee';
  end if;

  update invitations set utilisee_le = now() where code = inv.code;
  return inv.contrat_id;
end;
$$;

-- ============================================================
-- Horodatage automatique
-- ============================================================
create function horodater()
returns trigger
language plpgsql
as $$
begin
  new.maj_le := now();
  return new;
end;
$$;

-- ============================================================
-- Jours : le planning
-- Chaque colonne a un seul proprietaire, ce qui supprime les conflits.
-- ============================================================
create table jours (
  contrat_id       uuid not null references contrats(id) on delete cascade,
  jour             date not null,
  heures_prevues   numeric(5,2),
  heures_reelles   numeric(5,2),
  absence_enfant   boolean not null default false,
  absence_salariee boolean not null default false,
  maj_le           timestamptz not null default now(),
  primary key (contrat_id, jour)
);

create index jours_contrat_mois on jours (contrat_id, jour);

-- Un ecrivain ne peut modifier que ses propres colonnes.
-- Les colonnes des autres sont restaurees en silence plutot que rejetees :
-- une synchronisation ne doit jamais echouer en bloc sur un champ interdit.
create function proprietaire_jour()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  emp uuid;
  sal uuid;
begin
  select employeur_id, salariee_id into emp, sal
    from contrats where id = new.contrat_id;

  if auth.uid() = emp then
    if tg_op = 'UPDATE' then
      new.heures_reelles   := old.heures_reelles;
      new.absence_salariee := old.absence_salariee;
    else
      new.heures_reelles   := null;
      new.absence_salariee := false;
    end if;

  elsif auth.uid() = sal then
    if tg_op = 'UPDATE' then
      new.heures_prevues  := old.heures_prevues;
      new.absence_enfant  := old.absence_enfant;
    else
      new.heures_prevues  := null;
      new.absence_enfant  := false;
    end if;

  else
    raise exception 'Acces refuse a ce contrat';
  end if;

  new.maj_le := now();
  return new;
end;
$$;

create trigger jours_proprietaire
  before insert or update on jours
  for each row execute function proprietaire_jour();

-- ============================================================
-- Mois : etat de la fiche, ecrit par l'employeur seul
-- ============================================================
create table mois (
  contrat_id   uuid not null references contrats(id) on delete cascade,
  mois         text not null check (mois ~ '^[0-9]{4}-[0-9]{2}$'),
  heures_total numeric(6,2),
  etat_fiche   text not null default 'brouillon'
                 check (etat_fiche in ('brouillon', 'transmise', 'versee')),
  maj_le       timestamptz not null default now(),
  primary key (contrat_id, mois)
);

create trigger mois_horodate
  before insert or update on mois
  for each row execute function horodater();

-- ============================================================
-- Messages entre l'employeur et sa salariee
-- ============================================================
create table messages (
  id         uuid primary key default gen_random_uuid(),
  contrat_id uuid not null references contrats(id) on delete cascade,
  auteur_id  uuid not null references profils(id) on delete cascade,
  texte      text not null check (length(texte) between 1 and 4000),
  cree_le    timestamptz not null default now(),
  lu_le      timestamptz
);

create index messages_contrat on messages (contrat_id, cree_le desc);

-- ============================================================
-- Consentements : conserves tels que signes, jamais modifiables
-- Pas d'adresse IP : donnee personnelle de plus, sans utilite ici.
-- ============================================================
create table consentements (
  id             uuid primary key default gen_random_uuid(),
  contrat_id     uuid not null references contrats(id) on delete cascade,
  personne_id    uuid not null references profils(id) on delete cascade,
  version_texte  text not null,
  nom_saisi      text not null,
  signe_le       timestamptz not null default now(),
  unique (contrat_id, personne_id, version_texte)
);

-- ============================================================
-- Acces support : ouvert par l'utilisateur, temporaire, trace
-- ============================================================
create table support (
  id         uuid primary key default gen_random_uuid(),
  contrat_id uuid not null references contrats(id) on delete cascade,
  ouvert_par uuid not null references profils(id) on delete cascade,
  ouvert_le  timestamptz not null default now(),
  expire_le  timestamptz not null default now() + interval '24 hours'
);

-- ============================================================
-- Espace partage entre les familles d'une meme salariee
-- Rien n'y est publie automatiquement : uniquement des annonces ecrites.
-- ============================================================
create table espaces (
  id          uuid primary key default gen_random_uuid(),
  salariee_id uuid not null references profils(id) on delete cascade,
  nom         text not null,
  cree_le     timestamptz not null default now()
);

create table membres_espace (
  espace_id  uuid not null references espaces(id) on delete cascade,
  contrat_id uuid not null references contrats(id) on delete cascade,
  accepte_le timestamptz,
  quitte_le  timestamptz,
  primary key (espace_id, contrat_id)
);

create table annonces (
  id         uuid primary key default gen_random_uuid(),
  espace_id  uuid not null references espaces(id) on delete cascade,
  auteur_id  uuid not null references profils(id) on delete cascade,
  categorie  text not null check (categorie in ('maladie', 'absence', 'sortie', 'info')),
  texte      text not null check (length(texte) between 1 and 2000),
  cree_le    timestamptz not null default now()
);

create index annonces_espace on annonces (espace_id, cree_le desc);

create function est_membre_espace(e uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
      from membres_espace m
      join contrats c on c.id = m.contrat_id
     where m.espace_id = e
       and m.accepte_le is not null
       and m.quitte_le is null
       and (c.employeur_id = auth.uid() or c.salariee_id = auth.uid())
  )
  or exists (
    select 1 from espaces where id = e and salariee_id = auth.uid()
  );
$$;
