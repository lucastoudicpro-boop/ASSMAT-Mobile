-- Cocon — evolutions 004 a 007, en un seul fichier.
-- A executer apres 001-schema.sql et 002-politiques.sql.
-- Rejouable : chaque objet est supprime avant d'etre recree.

-- ====================================================================
-- PLANNING EN HORAIRES, MESSAGES, PHOTOS
-- ====================================================================

-- Cocon — évolution 004
-- Planning en horaires, demandes de la salariée, photos.
-- À exécuter après 001 et 002, dans l'éditeur SQL de Supabase.
-- Ce fichier ne supprime rien : il ajoute.

-- ============================================================
-- Planning de base, porté par le contrat
-- Forme attendue, écrite par l'employeur :
--   {"d1":{"debut":"08:00","fin":"17:00"}, "d2":{...}, ...}
--   d1 = lundi … d0 = dimanche. Un jour absent signifie pas d'accueil.
-- ============================================================
alter table contrats add column if not exists planning jsonb not null default '{}'::jsonb;
alter table contrats add column if not exists lieu text;

comment on column contrats.planning is
  'Horaires habituels par jour de semaine. Les exceptions vivent dans la table jours.';

-- ============================================================
-- Messages : catégorie et pièce jointe
-- ============================================================
alter table messages add column if not exists categorie text not null default 'info';
alter table messages add column if not exists piece text;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'messages_categorie_valide') then
    alter table messages add constraint messages_categorie_valide
      check (categorie in ('info', 'besoin', 'photo'));
  end if;
end $$;

comment on column messages.piece is
  'Chemin de la photo dans le bucket photos, sous la forme contrat_id/fichier.jpg';

-- Le texte devient facultatif quand une photo tient lieu de message.
alter table messages alter column texte drop not null;
alter table messages drop constraint if exists messages_texte_check;
alter table messages drop constraint if exists messages_contenu_non_vide;
alter table messages add constraint messages_contenu_non_vide
  check (coalesce(length(texte), 0) between 0 and 4000
         and (coalesce(length(texte), 0) > 0 or piece is not null));

-- ============================================================
-- Photos : un bucket privé, rangé par contrat
-- ============================================================
insert into storage.buckets (id, name, public)
values ('photos', 'photos', false)
on conflict (id) do nothing;

-- Les regles d'acces au bucket sont posees plus bas, dans la section
-- « FICHE D'URGENCE ET GALERIE » : elles remplacent celles de l'evolution 004.

-- ====================================================================
-- NOTIFICATIONS ET FERMETURES
-- ====================================================================

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

-- ====================================================================
-- JOURNAL DE LA JOURNEE
-- ====================================================================

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

-- ====================================================================
-- FICHE D'URGENCE ET GALERIE
-- ====================================================================

-- Cocon — évolution 007
-- Fiche d'urgence, autorisations, galerie par enfant.
-- À exécuter après 006. Remplace les règles de stockage posées en 004.

-- ============================================================
-- Fiche d'urgence
-- Remplie par le parent, lue par la salariée. Elle doit pouvoir la consulter
-- le jour où ça compte : l'application en garde une copie hors connexion.
-- ============================================================
create table if not exists fiche_urgence (
  contrat_id      uuid primary key references contrats(id) on delete cascade,
  medecin_nom     text,
  medecin_tel     text,
  allergies       text,
  traitements     text,
  particularites  text,
  personnes       jsonb not null default '[]'::jsonb,
  autorisations   jsonb not null default '{}'::jsonb,
  signe_par       text,
  signe_le        timestamptz,
  maj_le          timestamptz not null default now()
);

comment on column fiche_urgence.personnes is
  'Personnes autorisees a recuperer l''enfant : [{"nom":"","lien":"","tel":""}]';
comment on column fiche_urgence.autorisations is
  'Cases cochees par le parent : sortie, transport, photo, photo_groupe, creme, medicament';

alter table fiche_urgence enable row level security;
revoke all on fiche_urgence from anon;

drop policy if exists urgence_lecture on fiche_urgence;
drop policy if exists urgence_ecriture on fiche_urgence;
drop policy if exists urgence_maj on fiche_urgence;

create policy urgence_lecture on fiche_urgence for select to authenticated
  using (est_membre(contrat_id));

create policy urgence_ecriture on fiche_urgence for insert to authenticated
  with check (exists (select 1 from contrats
                       where id = fiche_urgence.contrat_id and employeur_id = auth.uid()));

create policy urgence_maj on fiche_urgence for update to authenticated
  using (exists (select 1 from contrats
                  where id = fiche_urgence.contrat_id and employeur_id = auth.uid()))
  with check (exists (select 1 from contrats
                       where id = fiche_urgence.contrat_id and employeur_id = auth.uid()));

drop trigger if exists urgence_horodate on fiche_urgence;
create trigger urgence_horodate
  before insert or update on fiche_urgence
  for each row execute function horodater();

-- ============================================================
-- Galerie
-- Une photo peut concerner plusieurs enfants. Chaque famille concernée doit
-- l'avoir autorisée, sinon le lien est refusé par la base.
-- ============================================================
create table if not exists photos (
  id        uuid primary key default gen_random_uuid(),
  auteur_id uuid not null references profils(id) on delete cascade,
  chemin    text not null,
  legende   text,
  groupe    boolean not null default false,
  prise_le  timestamptz not null default now()
);

create table if not exists photos_contrats (
  photo_id   uuid not null references photos(id) on delete cascade,
  contrat_id uuid not null references contrats(id) on delete cascade,
  primary key (photo_id, contrat_id)
);

create index if not exists photos_contrat on photos_contrats (contrat_id);

alter table photos enable row level security;
alter table photos_contrats enable row level security;
revoke all on photos, photos_contrats from anon;

-- Une photo est visible si l'un de ses enfants est le vôtre.
create or replace function photo_visible(p uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from photos_contrats pc
      join contrats c on c.id = pc.contrat_id
     where pc.photo_id = p
       and (c.employeur_id = auth.uid() or c.salariee_id = auth.uid())
  );
$$;

drop policy if exists photos_lecture on photos;
drop policy if exists photos_ecriture on photos;
drop policy if exists photos_maj on photos;
drop policy if exists photos_suppression on photos;
drop policy if exists liens_lecture on photos_contrats;
drop policy if exists liens_ecriture on photos_contrats;
drop policy if exists liens_suppression on photos_contrats;

create policy photos_lecture on photos for select to authenticated
  using (auteur_id = auth.uid() or photo_visible(id));

create policy photos_ecriture on photos for insert to authenticated
  with check (auteur_id = auth.uid());

create policy photos_maj on photos for update to authenticated
  using (auteur_id = auth.uid()) with check (auteur_id = auth.uid());

create policy photos_suppression on photos for delete to authenticated
  using (auteur_id = auth.uid());

create policy liens_lecture on photos_contrats for select to authenticated
  using (est_membre(contrat_id) or exists (select 1 from photos
                                            where id = photos_contrats.photo_id
                                              and auteur_id = auth.uid()));

create policy liens_ecriture on photos_contrats for insert to authenticated
  with check (exists (select 1 from photos
                       where id = photos_contrats.photo_id and auteur_id = auth.uid()));

create policy liens_suppression on photos_contrats for delete to authenticated
  using (exists (select 1 from photos
                  where id = photos_contrats.photo_id and auteur_id = auth.uid()));

-- ============================================================
-- Le consentement aux photos de groupe est verifie par la base
-- L'interface propose deja les bons enfants, mais une interface se trompe.
-- ============================================================
create or replace function verifier_autorisation_photo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  est_groupe boolean;
  autorise   boolean;
begin
  select groupe into est_groupe from photos where id = new.photo_id;

  select coalesce((autorisations ->> case when est_groupe then 'photo_groupe' else 'photo' end)::boolean, false)
    into autorise
    from fiche_urgence
   where contrat_id = new.contrat_id;

  if not coalesce(autorise, false) then
    raise exception 'Photo non autorisee par cette famille';
  end if;
  return new;
end;
$$;

drop trigger if exists photos_autorisation on photos_contrats;
create trigger photos_autorisation
  before insert on photos_contrats
  for each row execute function verifier_autorisation_photo();

-- ============================================================
-- Stockage : le dossier est desormais l'identifiant de la photo
-- ============================================================
drop policy if exists "photos lecture" on storage.objects;
drop policy if exists "photos envoi" on storage.objects;
drop policy if exists "photos suppression" on storage.objects;

create policy "photos lecture" on storage.objects for select to authenticated
  using (
    bucket_id = 'photos'
    and (
      public.photo_visible(((storage.foldername(name))[1])::uuid)
      or exists (select 1 from public.photos
                  where id = ((storage.foldername(name))[1])::uuid
                    and auteur_id = auth.uid())
    )
  );

-- On depose dans le dossier d'une photo qu'on a soi-meme creee.
create policy "photos envoi" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'photos'
    and exists (select 1 from public.photos
                 where id = ((storage.foldername(name))[1])::uuid
                   and auteur_id = auth.uid())
  );

create policy "photos suppression" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and owner = auth.uid());

-- ====================================================================
-- CONTROLES FINAUX — chaque ligne doit se terminer par « correct »
-- ====================================================================
select 'tables sans protection' as controle,
       coalesce(string_agg(relname, ', '), 'AUCUNE — correct') as resultat
  from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity
union all
select 'lecture des invitations',
       coalesce(string_agg(policyname, ', '), 'AUCUNE — correct')
  from pg_policies
 where schemaname = 'public' and tablename = 'invitations' and cmd = 'SELECT'
union all
select 'droits du role anon',
       coalesce(string_agg(distinct table_name, ', '), 'AUCUN — correct')
  from information_schema.role_table_grants
 where grantee = 'anon' and table_schema = 'public'
union all
select 'tables attendues',
       case when count(*) = 16 then '16 — correct' else count(*)::text || ' au lieu de 16' end
  from pg_tables where schemaname = 'public'
union all
select 'bucket photos prive',
       case when bool_and(not public) then 'prive — correct' else 'PUBLIC, a corriger' end
  from storage.buckets where id = 'photos'
union all
select 'declencheur autorisation photo',
       case when count(*) = 1 then 'present — correct' else 'ABSENT' end
  from pg_trigger where not tgisinternal and tgrelid = 'photos_contrats'::regclass;
