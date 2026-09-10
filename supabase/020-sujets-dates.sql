-- Cocon — évolution 020
-- Les sujets difficiles, les dates qui comptent.
-- À exécuter après 019. Rejouable.

-- ============================================================
-- Les sujets difficiles
--
-- Une morsure, un retard de paiement, un desaccord sur le sommeil. C'est la
-- que les relations se cassent, et rien n'aide a en parler. Une conversation
-- ordinaire ne convient pas : on ecrit a chaud, l'autre lit a chaud.
--
-- Ici le sujet est pose, l'autre a le temps de le lire avant de repondre, et
-- les deux marquent quand c'est reglé.
-- ============================================================
create table if not exists sujets (
  id          uuid primary key default gen_random_uuid(),
  contrat_id  uuid not null references contrats(id) on delete cascade,
  auteur_id   uuid not null references profils(id) on delete cascade,
  theme       text not null,
  titre       text not null check (length(titre) between 1 and 140),
  corps       text check (coalesce(length(corps), 0) <= 2000),
  etat        text not null default 'ouvert' check (etat in ('ouvert', 'lu', 'regle')),
  lu_le       timestamptz,
  regle_le    timestamptz,
  regle_par   uuid references profils(id) on delete set null,
  cree_le     timestamptz not null default now()
);

create index if not exists sujets_contrat on sujets (contrat_id, cree_le desc);

alter table sujets enable row level security;
revoke all on sujets from anon;

drop policy if exists suj_lecture on sujets;
drop policy if exists suj_creation on sujets;
drop policy if exists suj_maj on sujets;
drop policy if exists suj_suppression on sujets;

create policy suj_lecture on sujets for select to authenticated
  using (est_membre(contrat_id));
create policy suj_creation on sujets for insert to authenticated
  with check (auteur_id = auth.uid() and est_membre(contrat_id));
create policy suj_maj on sujets for update to authenticated
  using (est_membre(contrat_id)) with check (est_membre(contrat_id));
create policy suj_suppression on sujets for delete to authenticated
  using (auteur_id = auth.uid() and etat = 'ouvert');

-- Le fond appartient a son auteur ; l'autre accuse et marque regle.
create or replace function proteger_sujet()
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
    new.theme := old.theme;
    new.titre := old.titre;
    new.corps := old.corps;
    if old.lu_le is null and new.lu_le is null then new.lu_le := now(); end if;
  end if;
  if new.etat = 'regle' and old.etat <> 'regle' then
    new.regle_le := now();
    new.regle_par := auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists sujet_protege on sujets;
create trigger sujet_protege
  before update on sujets
  for each row execute function proteger_sujet();

-- ============================================================
-- Les reponses a un sujet
-- Separees du sujet : chacun garde ce qu'il a ecrit.
-- ============================================================
create table if not exists sujets_reponses (
  id        uuid primary key default gen_random_uuid(),
  sujet_id  uuid not null references sujets(id) on delete cascade,
  auteur_id uuid not null references profils(id) on delete cascade,
  texte     text not null check (length(texte) between 1 and 2000),
  cree_le   timestamptz not null default now()
);

create index if not exists sujets_reponses_sujet on sujets_reponses (sujet_id, cree_le);

alter table sujets_reponses enable row level security;
revoke all on sujets_reponses from anon;

create or replace function membre_du_sujet(s uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (select 1 from sujets where id = s and est_membre(contrat_id));
$$;

drop policy if exists sr_lecture on sujets_reponses;
drop policy if exists sr_creation on sujets_reponses;

create policy sr_lecture on sujets_reponses for select to authenticated
  using (membre_du_sujet(sujet_id));
create policy sr_creation on sujets_reponses for insert to authenticated
  with check (auteur_id = auth.uid() and membre_du_sujet(sujet_id));

-- Une reponse ecrite ne se reecrit pas : on n'efface pas ce qu'on a dit.
create or replace function figer_reponse()
returns trigger
language plpgsql
as $$
begin
  raise exception 'Une réponse ne peut pas être modifiée';
end;
$$;

drop trigger if exists reponse_figee on sujets_reponses;
create trigger reponse_figee
  before update on sujets_reponses
  for each row execute function figer_reponse();

-- ============================================================
-- Les dates qui comptent
-- L'anniversaire de l'enfant, et celui du premier jour ensemble.
-- Les deux se deduisent : rien a saisir.
-- ============================================================
create or replace function dates_marquantes(c uuid)
returns table (quoi text, jour date, annees integer)
language sql
security definer
set search_path = public
stable
as $$
  with base as (
    select ct.enfant_naissance as naissance,
           ct.enfant_prenom as prenom,
           (select min(jour) from journal where contrat_id = ct.id) as premier_jour,
           ct.cree_le::date as depuis
      from contrats ct
     where ct.id = c and est_membre(ct.id)
  )
  select 'anniversaire'::text,
         make_date(extract(year from current_date)::int
                   + case when to_char(naissance, 'MM-DD') < to_char(current_date, 'MM-DD') then 1 else 0 end,
                   extract(month from naissance)::int, extract(day from naissance)::int),
         extract(year from age(current_date, naissance))::int + 1
    from base where naissance is not null
  union all
  select 'rencontre'::text,
         make_date(extract(year from current_date)::int
                   + case when to_char(coalesce(premier_jour, depuis), 'MM-DD') < to_char(current_date, 'MM-DD') then 1 else 0 end,
                   extract(month from coalesce(premier_jour, depuis))::int,
                   extract(day from coalesce(premier_jour, depuis))::int),
         extract(year from age(current_date, coalesce(premier_jour, depuis)))::int + 1
    from base where coalesce(premier_jour, depuis) is not null;
$$;
revoke all on function dates_marquantes(uuid) from anon;

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : sujets et sujets_reponses, protégées.
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace
   and relname in ('sujets', 'sujets_reponses')
 order by relname;

-- 2. Attendu : trois fonctions.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace
   and proname in ('proteger_sujet', 'membre_du_sujet', 'dates_marquantes')
 order by proname;

-- 3. Attendu : aucune table sans protection.
select relname from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity;
