-- Cocon — évolution 024
-- La sauvegarde du dossier, et une règle qui bloquait l'espace commun.
-- À exécuter après 023. Rejouable.

-- ============================================================
-- 1. L'espace commun refusait de s'ouvrir
--
-- « new row violates row-level security policy for table espaces ».
--
-- La règle de lecture appelle est_membre_espace(id), une fonction « stable »
-- qui interroge la table espaces. Pendant l'insertion, la ligne nouvelle n'est
-- pas encore dans l'instantané de cette fonction : la relecture qui suit
-- l'écriture échouait, et l'erreur remontait comme un refus d'insertion.
--
-- On compare directement la colonne, sans passer par la fonction : une
-- comparaison sur la ligne elle-même voit la ligne en cours d'insertion.
-- ============================================================
drop policy if exists espaces_lecture on espaces;
create policy espaces_lecture on espaces for select to authenticated
  using (salariee_id = auth.uid() or est_membre_espace(id));

-- ============================================================
-- 2. Sauvegarder le dossier
--
-- Aujourd'hui, désinstaller l'application perd tout : contrat, taux horaire,
-- planning type, fiches déjà faites. Repartir de zéro après un changement de
-- téléphone est inacceptable.
--
-- Ce qui monte : ce qu'il faut pour reprendre là où on s'est arrêté.
-- Ce qui ne monte JAMAIS : le numéro de sécurité sociale, l'IBAN, l'adresse
-- précise. Ces trois-là restent sur l'appareil, et sont retirés côté
-- application avant l'envoi — la base ne les voit pas passer.
-- ============================================================
create table if not exists sauvegardes (
  id        uuid primary key references profils(id) on delete cascade,
  contenu   jsonb not null,
  version   text,
  appareil  text,
  taille    integer,
  maj_le    timestamptz not null default now()
);

comment on table sauvegardes is
  'Reprise apres reinstallation. Ni numero de securite sociale, ni IBAN, ni
   adresse precise : ceux-la restent sur le telephone.';

alter table sauvegardes enable row level security;
revoke all on sauvegardes from anon;

drop policy if exists sav_lecture on sauvegardes;
drop policy if exists sav_creation on sauvegardes;
drop policy if exists sav_maj on sauvegardes;
drop policy if exists sav_suppression on sauvegardes;

-- Personne d'autre que soi. Pas même la salariée du contrat.
create policy sav_lecture on sauvegardes for select to authenticated
  using (id = auth.uid());
create policy sav_creation on sauvegardes for insert to authenticated
  with check (id = auth.uid());
create policy sav_maj on sauvegardes for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
create policy sav_suppression on sauvegardes for delete to authenticated
  using (id = auth.uid());

-- Un filet contre l'erreur d'écriture : si l'un des trois interdits arrivait
-- malgré tout, la ligne est refusée plutôt qu'enregistrée.
create or replace function refuser_secrets()
returns trigger
language plpgsql
as $$
declare txt text := new.contenu::text;
begin
  if txt ~* '"(secu|iban|bic|nir)"\s*:\s*"[^"]{4,}"' then
    raise exception 'Cette sauvegarde contient des données qui ne doivent jamais quitter l''appareil';
  end if;
  new.taille := length(txt);
  new.maj_le := now();
  new.id := coalesce(old.id, new.id);
  return new;
end;
$$;

drop trigger if exists sauvegarde_sans_secrets on sauvegardes;
create trigger sauvegarde_sans_secrets
  before insert or update on sauvegardes
  for each row execute function refuser_secrets();

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : sauvegardes, protégée.
select relname, relrowsecurity from pg_class
 where relnamespace = 'public'::regnamespace and relname = 'sauvegardes';

-- 2. Attendu : la règle de lecture des espaces cite salariee_id.
select policyname, qual from pg_policies
 where schemaname = 'public' and tablename = 'espaces' and cmd = 'SELECT';

-- 3. Attendu : le filet refuse une sauvegarde contenant un numéro.
--    (à exécuter seul pour voir l'erreur, puis annuler)
-- insert into sauvegardes (id, contenu) values (auth.uid(), '{"secu":"1850344123456"}');
