-- Cocon — évolution 015
-- Absences de la salariée : type, délai de prévenance, justificatif.
-- À exécuter après 014. Rejouable.

-- ============================================================
-- La table fermetures devient le registre des absences
-- ============================================================
alter table fermetures add column if not exists type text not null default 'conges';
alter table fermetures add column if not exists justificatif text;
alter table fermetures add column if not exists depose_le timestamptz;

alter table fermetures drop constraint if exists fermetures_type_valide;
alter table fermetures add constraint fermetures_type_valide
  check (type in ('conges', 'formation', 'maladie', 'accident', 'maternite', 'urgence', 'ferie'));

comment on column fermetures.type is
  'conges et formation se previennent a l''avance ; maladie, accident, maternite et urgence surviennent.';
comment on column fermetures.justificatif is
  'Chemin dans le bucket photos : arret de travail, attestation. Depose apres coup.';

-- Le motif devient obligatoire pour ce qui n'est pas prévu de longue date.
alter table fermetures drop constraint if exists fermetures_motif_requis;
alter table fermetures add constraint fermetures_motif_requis
  check (type in ('conges', 'formation', 'ferie')
         or coalesce(length(trim(motif)), 0) > 0);

-- ============================================================
-- Le parent peut accuser reception, sans pouvoir modifier l'absence
-- ============================================================
alter table fermetures add column if not exists vu_le timestamptz;

drop policy if exists fermetures_accuse on fermetures;
create policy fermetures_accuse on fermetures for update to authenticated
  using (exists (select 1 from contrats c
                  where c.salariee_id = fermetures.salariee_id
                    and (c.employeur_id = auth.uid() or c.coparent_id = auth.uid())))
  with check (exists (select 1 from contrats c
                       where c.salariee_id = fermetures.salariee_id
                         and (c.employeur_id = auth.uid() or c.coparent_id = auth.uid())));

-- Un déclencheur limite le parent au seul accusé de réception.
create or replace function figer_fermeture()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is distinct from old.salariee_id then
    new.salariee_id  := old.salariee_id;
    new.du           := old.du;
    new.au           := old.au;
    new.motif        := old.motif;
    new.type         := old.type;
    new.justificatif := old.justificatif;
    new.depose_le    := old.depose_le;
    new.cree_le      := old.cree_le;
  end if;
  return new;
end;
$$;

drop trigger if exists fermeture_figee on fermetures;
create trigger fermeture_figee
  before update on fermetures
  for each row execute function figer_fermeture();

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. Attendu : depose_le, justificatif, type, vu_le.
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'fermetures'
   and column_name in ('type', 'justificatif', 'depose_le', 'vu_le')
 order by column_name;

-- 2. Attendu : deux contraintes.
select conname from pg_constraint
 where conrelid = 'fermetures'::regclass
   and conname in ('fermetures_type_valide', 'fermetures_motif_requis');

-- 3. Attendu : fermeture_figee.
select tgname from pg_trigger
 where not tgisinternal and tgrelid = 'fermetures'::regclass;
