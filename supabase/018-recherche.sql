-- Cocon — évolution 018
-- Recherche d'une assistante maternelle et demandes d'accueil.
-- Fonctionnalité en préparation, cachée derrière le mode développeur.
-- À exécuter après 017. Rejouable.

-- ============================================================
-- Apparaître dans la recherche est un choix
-- Rien n'est visible tant que la salariée ne l'a pas demandé.
-- ============================================================
alter table profils_pro add column if not exists visible_recherche boolean not null default false;
alter table profils_pro add column if not exists commune text;
alter table profils_pro add column if not exists code_postal text;

comment on column profils_pro.visible_recherche is
  'Faux par defaut : la salariee decide d''apparaitre, personne ne l''y met.';

-- ============================================================
-- La disponibilité se calcule, elle ne se déclare pas
-- C'est tout l'interet : sur les annuaires, les disponibilites sont fausses
-- parce que personne ne les met a jour. Ici elles sont deduites des contrats.
-- ============================================================
create or replace function places_libres(sal uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select greatest(0, coalesce((select places from profils_pro where id = sal), 0)
                   - (select count(*) from contrats
                       where salariee_id = sal and statut = 'actif')::int);
$$;

comment on function places_libres(uuid) is
  'Places d''agrement moins contrats actifs. Aucune saisie, donc jamais perime.';

-- La date à laquelle cette information a bougé pour la dernière fois.
-- La table contrats ne porte que cree_le : c'est cette date, et celle du
-- profil, qui datent la disponibilité.
create or replace function dispo_maj_le(sal uuid)
returns timestamptz
language sql
security definer
set search_path = public
stable
as $$
  select greatest(
    coalesce((select maj_le from profils_pro where id = sal), 'epoch'::timestamptz),
    coalesce((select max(cree_le) from contrats where salariee_id = sal), 'epoch'::timestamptz)
  );
$$;

-- ============================================================
-- La recherche : une fonction, jamais une lecture directe de la table
-- Sans cela, un parent curieux lirait tous les profils du pays.
-- ============================================================
create or replace function rechercher_nounous(p_code_postal text, p_places integer default 1)
returns table (
  id uuid, nom text, photo text, commune text, code_postal text,
  places smallint, libres integer, depuis date,
  presentation text, diplomes jsonb, formations jsonb, langues jsonb, accueil jsonb,
  maj_le timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select p.id, pr.nom, p.photo, p.commune, p.code_postal,
         p.places, places_libres(p.id), p.depuis,
         left(coalesce(p.presentation, ''), 400),
         p.diplomes, p.formations, p.langues, p.accueil,
         dispo_maj_le(p.id)
    from profils_pro p
    join profils pr on pr.id = p.id
   where p.visible_recherche
     and (p_code_postal is null or p.code_postal like left(trim(p_code_postal), 2) || '%')
     and places_libres(p.id) >= greatest(1, coalesce(p_places, 1))
   order by places_libres(p.id) desc, dispo_maj_le(p.id) desc
   limit 40;
$$;
revoke all on function rechercher_nounous(text, integer) from anon;

-- ============================================================
-- Demandes d'accueil : le parent propose, la salariée dispose
-- ============================================================
create table if not exists demandes_accueil (
  id           uuid primary key default gen_random_uuid(),
  parent_id    uuid not null references profils(id) on delete cascade,
  salariee_id  uuid not null references profils(id) on delete cascade,
  enfant_prenom text,
  enfant_naissance date,
  debut_souhaite date,
  rythme       text,
  mot          text check (coalesce(length(mot), 0) <= 1000),
  etat         text not null default 'attente' check (etat in ('attente', 'acceptee', 'refusee', 'retiree')),
  motif_refus  text,
  cree_le      timestamptz not null default now(),
  repondu_le   timestamptz,
  unique (parent_id, salariee_id, enfant_prenom)
);

create index if not exists demandes_accueil_sal on demandes_accueil (salariee_id, etat, cree_le desc);

alter table demandes_accueil enable row level security;
revoke all on demandes_accueil from anon;

drop policy if exists da_lecture on demandes_accueil;
drop policy if exists da_creation on demandes_accueil;
drop policy if exists da_maj on demandes_accueil;
drop policy if exists da_suppression on demandes_accueil;

create policy da_lecture on demandes_accueil for select to authenticated
  using (parent_id = auth.uid() or salariee_id = auth.uid());

-- Un parent ne peut ecrire une demande qu'a une salariee qui s'est rendue visible.
create policy da_creation on demandes_accueil for insert to authenticated
  with check (parent_id = auth.uid()
              and exists (select 1 from profils_pro
                           where id = demandes_accueil.salariee_id and visible_recherche));

create policy da_maj on demandes_accueil for update to authenticated
  using (parent_id = auth.uid() or salariee_id = auth.uid())
  with check (parent_id = auth.uid() or salariee_id = auth.uid());

create policy da_suppression on demandes_accueil for delete to authenticated
  using (parent_id = auth.uid());

-- Chacun ne modifie que ce qui le concerne : le parent retire, la salariée répond.
create or replace function proteger_demande_accueil()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.parent_id := old.parent_id;
  new.salariee_id := old.salariee_id;
  new.cree_le := old.cree_le;

  if auth.uid() = old.salariee_id then
    -- elle repond, elle ne reecrit pas la demande
    new.enfant_prenom := old.enfant_prenom;
    new.enfant_naissance := old.enfant_naissance;
    new.debut_souhaite := old.debut_souhaite;
    new.rythme := old.rythme;
    new.mot := old.mot;
    if new.etat is distinct from old.etat then new.repondu_le := now(); end if;
    if new.etat = 'retiree' then new.etat := old.etat; end if;
  else
    -- le parent ne peut que retirer sa demande
    if new.etat is distinct from old.etat and new.etat <> 'retiree' then
      new.etat := old.etat;
    end if;
    new.motif_refus := old.motif_refus;
  end if;
  return new;
end;
$$;

drop trigger if exists demande_accueil_protegee on demandes_accueil;
create trigger demande_accueil_protegee
  before update on demandes_accueil
  for each row execute function proteger_demande_accueil();

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : demandes_accueil, protégée.
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace and relname = 'demandes_accueil';

-- 2. Attendu : trois fonctions.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace
   and proname in ('places_libres', 'dispo_maj_le', 'rechercher_nounous')
 order by proname;

-- 3. Attendu : visible_recherche à faux partout.
select count(*) filter (where visible_recherche) as visibles, count(*) as total
  from profils_pro;
