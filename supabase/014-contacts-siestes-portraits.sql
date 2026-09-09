-- Cocon — évolution 014
-- Contacts des parents, siestes multiples, portrait de l'enfant.
-- À exécuter après 013. Rejouable.

-- ============================================================
-- Contacts d'urgence : le médecin ne suffit pas
-- On veut d'abord joindre les parents, puis les personnes autorisées.
-- ============================================================
alter table fiche_urgence add column if not exists contacts jsonb not null default '[]'::jsonb;

comment on column fiche_urgence.contacts is
  'Parents et proches a joindre, dans l''ordre : [{"role":"","nom":"","tel":"","note":""}]';

-- Le téléphone du profil sert enfin : la nounou voit celui de l'employeur.
comment on column profils.telephone is
  'Numero visible de l''autre partie du contrat, pour joindre sans passer par l''application.';

-- ============================================================
-- Siestes multiples
-- Un bébé en fait deux ou trois. Les deux anciennes colonnes restent pour ne
-- rien perdre ; la nouvelle les remplace.
-- ============================================================
alter table journal add column if not exists siestes jsonb not null default '[]'::jsonb;

comment on column journal.siestes is
  'Liste des siestes de la journee : [{"debut":"13:00","fin":"15:00"}]';

-- Reprise des journées déjà saisies avec une sieste unique.
update journal
   set siestes = jsonb_build_array(
         jsonb_build_object('debut', to_char(sieste_debut, 'HH24:MI'),
                            'fin',   to_char(sieste_fin, 'HH24:MI')))
 where siestes = '[]'::jsonb
   and sieste_debut is not null
   and sieste_fin is not null;

-- ============================================================
-- Portrait de l'enfant
-- Soit une frimousse dessinée, soit une vraie photo déposée dans le bucket.
-- ============================================================
alter table contrats add column if not exists enfant_frimousse text;
alter table contrats add column if not exists enfant_photo text;

comment on column contrats.enfant_frimousse is
  'Identifiant d''une frimousse dessinee, quand aucune photo n''est deposee.';
comment on column contrats.enfant_photo is
  'Chemin dans le bucket photos. Le dossier est un identifiant de la table photos.';

-- La salariée peut poser le portrait : c'est souvent elle qui prend la photo.
drop policy if exists contrats_portrait on contrats;
create policy contrats_portrait on contrats for update to authenticated
  using (salariee_id = auth.uid())
  with check (salariee_id = auth.uid());

-- Un déclencheur limite ce que la salariée peut changer : le portrait, rien d'autre.
create or replace function proteger_contrat()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() = old.salariee_id
     and auth.uid() is distinct from old.employeur_id
     and auth.uid() is distinct from old.coparent_id then
    -- elle ne touche qu'au portrait, et ne peut pas se retirer elle-même ici
    new.employeur_id    := old.employeur_id;
    new.coparent_id     := old.coparent_id;
    new.salariee_id     := old.salariee_id;
    new.enfant_prenom   := old.enfant_prenom;
    new.enfant_naissance := old.enfant_naissance;
    new.statut          := old.statut;
    new.planning        := old.planning;
    new.lieu            := old.lieu;
  end if;
  return new;
end;
$$;

drop trigger if exists contrat_protege on contrats;
create trigger contrat_protege
  before update on contrats
  for each row execute function proteger_contrat();

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : contacts, enfant_frimousse, enfant_photo, siestes.
select table_name, column_name from information_schema.columns
 where table_schema = 'public'
   and column_name in ('contacts', 'siestes', 'enfant_frimousse', 'enfant_photo')
 order by column_name;

-- 2. Attendu : contrat_protege.
select tgname from pg_trigger
 where not tgisinternal and tgrelid = 'contrats'::regclass and tgname = 'contrat_protege';
