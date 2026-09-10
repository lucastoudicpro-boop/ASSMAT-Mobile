-- Cocon — évolution 022
-- Suppression différée : quinze jours pour changer d'avis.
-- À exécuter après 021. Rejouable.

-- ============================================================
-- Effacer tout de suite est brutal
--
-- Quelqu'un qui supprime son compte un soir de fatigue, ou qui oublie de
-- télécharger son archive, n'a aucun recours. Quinze jours de délai coûtent
-- peu et évitent l'irréparable.
--
-- Rien n'est visible pendant ce délai : le compte est immédiatement retiré de
-- la vue de l'autre partie. Seule la restauration reste possible.
-- ============================================================
alter table profils add column if not exists suppression_demandee_le timestamptz;
alter table profils add column if not exists suppression_prevue_le timestamptz;

comment on column profils.suppression_demandee_le is
  'Depart du delai de retractation. Null = compte actif.';

create index if not exists profils_suppression on profils (suppression_prevue_le)
  where suppression_prevue_le is not null;

-- ============================================================
-- Demander la suppression
-- ============================================================
create or replace function demander_suppression()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  moi uuid := auth.uid();
  prevue timestamptz := now() + interval '15 days';
begin
  if moi is null then raise exception 'Session invalide'; end if;

  update profils
     set suppression_demandee_le = now(),
         suppression_prevue_le = prevue
   where id = moi;

  -- On se retire tout de suite de ce que voit l'autre partie : le delai sert
  -- a se retracter, pas a continuer d'utiliser l'application.
  update contrats set salariee_id = null, statut = 'invitation' where salariee_id = moi;
  update contrats set coparent_id = null where coparent_id = moi;
  update profils_pro set visible_recherche = false where id = moi;
  delete from jetons_push where personne_id = moi;

  return jsonb_build_object(
    'prevue_le', prevue,
    'jours', 15);
end;
$$;
revoke all on function demander_suppression() from anon;

-- ============================================================
-- Se rétracter
-- ============================================================
create or replace function annuler_suppression()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare moi uuid := auth.uid();
begin
  if moi is null then raise exception 'Session invalide'; end if;
  update profils
     set suppression_demandee_le = null, suppression_prevue_le = null
   where id = moi and suppression_prevue_le > now();
  return found;
end;
$$;
revoke all on function annuler_suppression() from anon;

-- ============================================================
-- Purger ce qui a dépassé le délai
--
-- Appelée par une tâche planifiée, jamais par l'application : elle ne
-- consulte pas auth.uid() et efface tout compte arrivé à échéance.
-- ============================================================
create or replace function purger_comptes_expires()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  cible uuid;
  n int := 0;
begin
  for cible in
    select id from profils
     where suppression_prevue_le is not null and suppression_prevue_le <= now()
  loop
    delete from contrats where employeur_id = cible;
    delete from jetons_push where personne_id = cible;
    delete from profils_pro where id = cible;
    delete from profils where id = cible;
    n := n + 1;
  end loop;
  return jsonb_build_object('comptes_purges', n, 'le', now());
end;
$$;
revoke all on function purger_comptes_expires() from anon;
revoke all on function purger_comptes_expires() from authenticated;

-- ============================================================
-- La tâche quotidienne
-- pg_cron doit être activé : Database → Extensions → pg_cron
-- ============================================================
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('purge-cocon') where exists
      (select 1 from cron.job where jobname = 'purge-cocon');
    perform cron.schedule('purge-cocon', '30 3 * * *',
      'select public.purger_comptes_expires();');
    raise notice 'Tache quotidienne programmee a 3 h 30.';
  else
    raise warning 'pg_cron n''est pas active : la purge ne tournera pas toute seule. Database -> Extensions -> pg_cron.';
  end if;
end;
$$;

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : trois fonctions.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace
   and proname in ('demander_suppression', 'annuler_suppression', 'purger_comptes_expires')
 order by proname;

-- 2. Attendu : les deux colonnes.
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'profils'
   and column_name like 'suppression%';

-- 3. Attendu : aucun compte en attente pour l'instant.
select count(*) as en_attente from profils where suppression_prevue_le is not null;
