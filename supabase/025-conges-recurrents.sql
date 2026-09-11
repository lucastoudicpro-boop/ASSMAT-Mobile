-- Cocon — évolution 025
-- Les congés qui reviennent chaque année.
-- À exécuter après 024. Rejouable.

-- ============================================================
-- Les mêmes semaines, tous les ans
--
-- Une assistante maternelle ferme souvent aux mêmes dates : trois semaines en
-- août, la semaine entre Noël et le jour de l'an, le vendredi de l'Ascension.
-- Les ressaisir chaque année est du travail pour rien, et un oubli prévient
-- les familles trop tard.
--
-- Une fermeture marquée « chaque année » sert de modèle : l'application
-- propose de la reconduire, la salariée confirme et ajuste les dates.
-- ============================================================
alter table fermetures add column if not exists chaque_annee boolean not null default false;
alter table fermetures add column if not exists modele_de uuid references fermetures(id) on delete set null;

comment on column fermetures.chaque_annee is
  'Cette fermeture revient : elle sera proposee a la reconduction l''an prochain.';
comment on column fermetures.modele_de is
  'La fermeture dont celle-ci a ete reconduite. Sert a ne pas proposer deux fois.';

create index if not exists fermetures_modele on fermetures (salariee_id, chaque_annee)
  where chaque_annee;

-- ============================================================
-- Ce qui reste à reconduire pour une année donnée
--
-- Renvoie les fermetures récurrentes des années passées dont l'équivalent
-- n'existe pas encore pour l'année demandée.
-- ============================================================
create or replace function fermetures_a_reconduire(annee integer)
returns table (id uuid, du date, au date, motif text, type text, annee_origine integer)
language sql
security definer
set search_path = public
stable
as $$
  select f.id, f.du, f.au, f.motif, f.type,
         extract(year from f.du)::int
    from fermetures f
   where f.salariee_id = auth.uid()
     and f.chaque_annee
     and extract(year from f.du)::int < annee
     and not exists (
       select 1 from fermetures g
        where g.salariee_id = auth.uid()
          and (g.modele_de = f.id
               or (extract(year from g.du)::int = annee
                   and to_char(g.du, 'MM-DD') = to_char(f.du, 'MM-DD')))
     )
   order by f.du desc;
$$;
revoke all on function fermetures_a_reconduire(integer) from anon;

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : les deux colonnes.
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'fermetures'
   and column_name in ('chaque_annee', 'modele_de')
 order by column_name;

-- 2. Attendu : la fonction.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace and proname = 'fermetures_a_reconduire';

-- 3. Attendu : aucune table sans protection.
select relname from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity;
