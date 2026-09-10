-- Compare la base a chaque fichier de migration.
-- Une ligne MANQUANTE = un fichier a executer, dans l'ordre.
  select '001-schema.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='annonces') then 'passée' else 'MANQUANTE' end as etat
union all
  select '002-politiques.sql' as migration, case when exists (select 1 from pg_policies where tablename='profils' and policyname='profils_lecture') then 'passée' else 'MANQUANTE' end as etat
union all
  select '004-planning-messages-photos.sql' as migration, case when exists (select 1 from information_schema.columns where table_schema='public' and table_name='messages' and column_name='piece') then 'passée' else 'MANQUANTE' end as etat
union all
  select '005-notifications-fermetures.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='fermetures') then 'passée' else 'MANQUANTE' end as etat
union all
  select '006-journal.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='journal') then 'passée' else 'MANQUANTE' end as etat
union all
  select '007-urgence-galerie.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='photos_contrats') then 'passée' else 'MANQUANTE' end as etat
union all
  select '008-invitation-par-la-nounou.sql' as migration, case when exists (select 1 from pg_proc where pronamespace='public'::regnamespace and proname='rejoindre') then 'passée' else 'MANQUANTE' end as etat
union all
  select '009-coparent-demandes-retards.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='demandes') then 'passée' else 'MANQUANTE' end as etat
union all
  select '010-pointage.sql' as migration, case when exists (select 1 from information_schema.columns where table_schema='public' and table_name='jours' and column_name='depart') then 'passée' else 'MANQUANTE' end as etat
union all
  select '011-accuse-lecture.sql' as migration, case when exists (select 1 from pg_proc where pronamespace='public'::regnamespace and proname='figer_message') then 'passée' else 'MANQUANTE' end as etat
union all
  select '012-quitter-contrat.sql' as migration, case when exists (select 1 from pg_proc where pronamespace='public'::regnamespace and proname='quitter_contrat') then 'passée' else 'MANQUANTE' end as etat
union all
  select '013-mode-silencieux.sql' as migration, case when exists (select 1 from information_schema.columns where table_schema='public' and table_name='profils' and column_name='silence_au') then 'passée' else 'MANQUANTE' end as etat
union all
  select '014-contacts-siestes-portraits.sql' as migration, case when exists (select 1 from information_schema.columns where table_schema='public' and table_name='contrats' and column_name='enfant_photo') then 'passée' else 'MANQUANTE' end as etat
union all
  select '015-absences.sql' as migration, case when exists (select 1 from information_schema.columns where table_schema='public' and table_name='fermetures' and column_name='vu_le') then 'passée' else 'MANQUANTE' end as etat
union all
  select '016-remplacement-adaptation-reprise.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='reprises') then 'passée' else 'MANQUANTE' end as etat
union all
  select '017-profil-pro.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='profils_pro') then 'passée' else 'MANQUANTE' end as etat
union all
  select '018-recherche.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='demandes_accueil') then 'passée' else 'MANQUANTE' end as etat
union all
  select '019-relation.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='premieres_fois') then 'passée' else 'MANQUANTE' end as etat
union all
  select '020-sujets-dates.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='sujets_reponses') then 'passée' else 'MANQUANTE' end as etat
union all
  select '021-securite.sql' as migration, case when exists (select 1 from pg_proc where pronamespace='public'::regnamespace and proname='supprimer_mon_compte') then 'passée' else 'MANQUANTE' end as etat
union all
  select '022-suppression-differee.sql' as migration, case when exists (select 1 from information_schema.columns where table_schema='public' and table_name='profils' and column_name='suppression_prevue_le') then 'passée' else 'MANQUANTE' end as etat
union all
  select '023-justificatifs.sql' as migration, case when exists (select 1 from pg_proc where pronamespace='public'::regnamespace and proname='justificatif_visible') then 'passée' else 'MANQUANTE' end as etat
union all
  select '024-sauvegarde.sql' as migration, case when exists (select 1 from information_schema.tables where table_schema='public' and table_name='sauvegardes') then 'passée' else 'MANQUANTE' end as etat;
