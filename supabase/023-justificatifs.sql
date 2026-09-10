-- Cocon — évolution 023
-- Le justificatif d'absence, lisible par les familles concernées.
-- À exécuter après 022. Rejouable.

-- ============================================================
-- Un justificatif que personne ne pouvait lire
--
-- L'arrêt de travail est déposé dans le bucket des photos, mais sans lien
-- vers un contrat : la règle « photos lecture » s'appuie sur ces liens, elle
-- renvoyait donc toujours faux. Le bouton « Voir le justificatif » du parent
-- échouait sans rien dire.
--
-- Un employeur a le droit de recevoir l'arrêt de travail de sa salariée.
-- Chaque famille en est un. La lecture est donc ouverte aux familles ayant un
-- contrat actif avec elle — et à personne d'autre.
-- ============================================================
create or replace function justificatif_visible(chemin text)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from fermetures f
     where f.justificatif = chemin
       and (
         f.salariee_id = auth.uid()
         or exists (select 1 from contrats c
                     where c.salariee_id = f.salariee_id
                       and c.employeur_id = auth.uid()
                       and c.statut <> 'termine')
       )
  );
$$;

comment on function justificatif_visible(text) is
  'Vrai pour la salariee et pour les familles ayant un contrat actif avec elle.
   Une famille dont le contrat est termine ne lit plus ses justificatifs.';

drop policy if exists "justificatif lecture" on storage.objects;
create policy "justificatif lecture" on storage.objects for select to authenticated
  using (bucket_id = 'photos' and public.justificatif_visible(name));

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : la fonction et la règle.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace and proname = 'justificatif_visible';

select policyname from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and policyname = 'justificatif lecture';

-- 2. Attendu : chaque justificatif déposé est bien rattaché à une absence.
select count(*) as justificatifs from fermetures where justificatif is not null;
