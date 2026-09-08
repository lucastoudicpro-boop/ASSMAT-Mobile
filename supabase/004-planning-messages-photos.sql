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

drop policy if exists "photos lecture" on storage.objects;
drop policy if exists "photos envoi" on storage.objects;
drop policy if exists "photos suppression" on storage.objects;

-- Le premier segment du chemin est l'identifiant du contrat : on ne voit que
-- les photos des contrats auxquels on appartient. Une famille ne peut donc pas
-- voir les photos prises chez une autre.
create policy "photos lecture" on storage.objects for select to authenticated
  using (
    bucket_id = 'photos'
    and public.est_membre(((storage.foldername(name))[1])::uuid)
  );

create policy "photos envoi" on storage.objects for insert to authenticated
  with check (
    bucket_id = 'photos'
    and public.est_membre(((storage.foldername(name))[1])::uuid)
  );

-- Chacun ne retire que ses propres photos.
create policy "photos suppression" on storage.objects for delete to authenticated
  using (bucket_id = 'photos' and owner = auth.uid());

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Les colonnes sont là. Attendu : planning, lieu, categorie, piece.
select table_name, column_name
  from information_schema.columns
 where table_schema = 'public'
   and (table_name, column_name) in
       (('contrats','planning'), ('contrats','lieu'),
        ('messages','categorie'), ('messages','piece'))
 order by table_name, column_name;

-- 2. Le bucket existe et n'est pas public. Attendu : une ligne, public = false.
select id, public from storage.buckets where id = 'photos';

-- 3. Trois règles sur les photos. Attendu : trois lignes.
select policyname, cmd
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and policyname like 'photos%'
 order by policyname;
