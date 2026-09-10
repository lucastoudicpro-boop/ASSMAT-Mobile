-- Cocon — évolution 021
-- Suppression du compte, et deux fuites d'information corrigées.
-- À exécuter après 020. Rejouable.

-- ============================================================
-- 1. Deux fonctions renseignaient sur n'importe qui
--
-- places_libres et dispo_maj_le sont « security definer » : elles s'exécutent
-- avec les droits du propriétaire, donc contournent les règles d'accès.
-- Elles répondaient pour n'importe quel identifiant, y compris celui d'une
-- salariée qui n'a jamais demandé à figurer dans la recherche.
--
-- Elles ne répondent désormais que pour celles qui s'y sont inscrites, ou
-- pour soi-même.
-- ============================================================
create or replace function places_libres(sal uuid)
returns integer
language sql
security definer
set search_path = public
stable
as $$
  select case
    when sal = auth.uid()
      or exists (select 1 from profils_pro where id = sal and visible_recherche)
    then greatest(0, coalesce((select places from profils_pro where id = sal), 0)
                   - (select count(*) from contrats
                       where salariee_id = sal and statut = 'actif')::int)
    else null
  end;
$$;

create or replace function dispo_maj_le(sal uuid)
returns timestamptz
language sql
security definer
set search_path = public
stable
as $$
  select case
    when sal = auth.uid()
      or exists (select 1 from profils_pro where id = sal and visible_recherche)
    then greatest(
      coalesce((select maj_le from profils_pro where id = sal), 'epoch'::timestamptz),
      coalesce((select max(cree_le) from contrats where salariee_id = sal), 'epoch'::timestamptz))
    else null
  end;
$$;

-- ============================================================
-- 2. Supprimer son compte
--
-- Le RGPD donne un droit d'effacement, et la politique de confidentialité le
-- promet. Il n'existait pas.
--
-- Ce que la fonction efface : le profil, le profil professionnel, les jetons
-- d'appareil, les contrats dont on est l'employeur — et par cascade tout ce
-- qui en dépend. Ce qu'elle ne peut pas effacer : les contrats où l'on est la
-- salariée, car ils appartiennent à la famille ; on s'en retire seulement.
-- ============================================================
create or replace function supprimer_mon_compte()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  moi uuid := auth.uid();
  n_contrats int := 0;
  n_retraits int := 0;
begin
  if moi is null then raise exception 'Session invalide'; end if;

  -- On se retire des contrats où l'on est la salariée : ils restent à la
  -- famille, qui pourra inviter quelqu'un d'autre.
  update contrats set salariee_id = null, statut = 'invitation'
   where salariee_id = moi;
  get diagnostics n_retraits = row_count;

  -- On quitte les espaces communs.
  update membres_espace set quitte_le = now()
   where quitte_le is null
     and contrat_id in (select id from contrats where employeur_id = moi or coparent_id = moi);

  -- On se retire des contrats où l'on est co-parent.
  update contrats set coparent_id = null where coparent_id = moi;

  -- Les contrats dont on est l'employeur partent, et tout ce qui en dépend
  -- avec eux : journal, messages, photos, fiche d'urgence, absences.
  delete from contrats where employeur_id = moi;
  get diagnostics n_contrats = row_count;

  delete from jetons_push where personne_id = moi;
  delete from profils_pro where id = moi;
  delete from profils where id = moi;

  return jsonb_build_object(
    'contrats_supprimes', n_contrats,
    'contrats_quittes', n_retraits);
end;
$$;
revoke all on function supprimer_mon_compte() from anon;

comment on function supprimer_mon_compte() is
  'Efface le profil et les contrats dont on est l''employeur. Se retire des
   contrats ou l''on est salariee ou co-parent : ils appartiennent a la famille.
   Le compte d''authentification lui-meme se supprime depuis le tableau de bord
   ou par l''API admin, hors de portee d''une fonction cote base.';

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : les trois fonctions.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace
   and proname in ('places_libres', 'dispo_maj_le', 'supprimer_mon_compte')
 order by proname;

-- 2. Attendu : null pour une salariée non inscrite à la recherche.
select p.id, p.visible_recherche, places_libres(p.id) as places_vues
  from profils_pro p limit 5;

-- 3. Attendu : aucune table sans protection.
select relname from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity;
