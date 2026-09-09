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

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : une règle de modification.
select policyname from pg_policies
 where schemaname = 'public' and tablename = 'messages' and cmd = 'UPDATE';

-- 2. Attendu : messages_figes.
select tgname from pg_trigger
 where not tgisinternal and tgrelid = 'messages'::regclass;

-- 3. Aucune table sans protection. Attendu : aucune ligne.
select relname from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity;
