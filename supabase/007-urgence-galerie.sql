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

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Les trois tables existent et sont protegees. Attendu : 3 lignes, true.
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace
   and relname in ('fiche_urgence', 'photos', 'photos_contrats');

-- 2. Le parent seul ecrit la fiche d'urgence. Attendu : 2 lignes.
select policyname from pg_policies
 where schemaname = 'public' and tablename = 'fiche_urgence'
   and cmd <> 'SELECT'
   and coalesce(qual, '') || coalesce(with_check, '') like '%employeur_id%';

-- 3. Le declencheur d'autorisation est en place. Attendu : une ligne.
select tgname from pg_trigger
 where not tgisinternal and tgrelid = 'photos_contrats'::regclass;
