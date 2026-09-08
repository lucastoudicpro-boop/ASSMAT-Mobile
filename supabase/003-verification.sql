-- AssMat+ partagé — contrôles
-- À exécuter après 001 et 002. Chaque requête doit renvoyer ce qui est annoncé.
-- Je n'ai pas pu exécuter le schéma moi-même : ces contrôles remplacent le test
-- que je n'ai pas pu faire.

-- ------------------------------------------------------------
-- 1. Les onze tables existent
-- Attendu : 11 lignes
-- ------------------------------------------------------------
select tablename
  from pg_tables
 where schemaname = 'public'
   and tablename in ('profils','contrats','invitations','jours','mois','messages',
                     'consentements','support','espaces','membres_espace','annonces')
 order by tablename;

-- ------------------------------------------------------------
-- 2. La protection au niveau ligne est active partout
-- Attendu : aucune ligne. Toute ligne renvoyée est une table exposée.
-- ------------------------------------------------------------
select relname as table_sans_protection
  from pg_class
 where relnamespace = 'public'::regnamespace
   and relkind = 'r'
   and not relrowsecurity
 order by relname;

-- ------------------------------------------------------------
-- 3. Nombre de règles par table
-- Attendu : invitations en a 2, toutes les autres au moins 2.
-- ------------------------------------------------------------
select tablename, count(*) as regles
  from pg_policies
 where schemaname = 'public'
 group by tablename
 order by tablename;

-- ------------------------------------------------------------
-- 4. La table invitations n'est jamais lisible
-- Attendu : aucune ligne. Une règle de lecture ici serait une faille :
-- un compte pourrait lister les codes et rejoindre un contrat au hasard.
-- ------------------------------------------------------------
select policyname
  from pg_policies
 where schemaname = 'public' and tablename = 'invitations' and cmd = 'SELECT';

-- ------------------------------------------------------------
-- 5. Les fonctions sensibles ont un chemin de recherche figé
-- Attendu : les quatre fonctions, chacune avec search_path=public.
-- Sans cela, une fonction en security definer est une porte d'entrée.
-- ------------------------------------------------------------
select p.proname,
       p.prosecdef as security_definer,
       coalesce(array_to_string(p.proconfig, ', '), 'AUCUN') as reglages
  from pg_proc p
 where p.pronamespace = 'public'::regnamespace
   and p.proname in ('est_membre','est_membre_espace','rejoindre','proprietaire_jour')
 order by p.proname;

-- ------------------------------------------------------------
-- 6. Le déclencheur de propriété des colonnes est en place
-- Attendu : une ligne, jours_proprietaire sur la table jours.
-- ------------------------------------------------------------
select tgname, tgrelid::regclass as porte_sur
  from pg_trigger
 where not tgisinternal
   and tgrelid = 'jours'::regclass;

-- ------------------------------------------------------------
-- 7. Le rôle anonyme n'a plus aucun droit
-- Attendu : aucune ligne.
-- ------------------------------------------------------------
select table_name, privilege_type
  from information_schema.role_table_grants
 where grantee = 'anon'
   and table_schema = 'public'
 order by table_name;
