-- Cocon — évolution 008
-- L'assistante maternelle crée l'accueil et invite la famille.
-- À exécuter après 004-a-007. Rejouable.

-- ============================================================
-- Le contrat peut naître sans employeur : elle le crée, la famille le rejoint
-- ============================================================
alter table contrats alter column employeur_id drop not null;

-- Au moins une des deux parties doit être présente.
alter table contrats drop constraint if exists contrats_une_partie;
alter table contrats add constraint contrats_une_partie
  check (employeur_id is not null or salariee_id is not null);

-- ============================================================
-- Règles : chacun peut créer, le créateur gère jusqu'à l'arrivée de l'autre,
-- puis l'employeur gère les termes du contrat.
-- ============================================================
drop policy if exists contrats_creation on contrats;
create policy contrats_creation on contrats for insert to authenticated
  with check (employeur_id = auth.uid() or salariee_id = auth.uid());

drop policy if exists contrats_modification on contrats;
create policy contrats_modification on contrats for update to authenticated
  using (
    employeur_id = auth.uid()
    or (salariee_id = auth.uid() and employeur_id is null)
  )
  with check (
    employeur_id = auth.uid()
    or (salariee_id = auth.uid() and employeur_id is null)
  );

drop policy if exists contrats_suppression on contrats;
create policy contrats_suppression on contrats for delete to authenticated
  using (
    employeur_id = auth.uid()
    or (salariee_id = auth.uid() and employeur_id is null)
  );

-- Les invitations sont créées par l'une ou l'autre partie du contrat.
drop policy if exists invitations_creation on invitations;
create policy invitations_creation on invitations for insert to authenticated
  with check (est_membre(contrat_id));

drop policy if exists invitations_suppression on invitations;
create policy invitations_suppression on invitations for delete to authenticated
  using (est_membre(contrat_id));

-- ============================================================
-- Rejoindre : la place libre est prise selon le rôle de l'appelant
-- ============================================================
create or replace function rejoindre(p_code text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  inv  invitations;
  role_appelant text;
  c    contrats;
begin
  select * into inv
    from invitations
   where code = upper(trim(p_code))
     and utilisee_le is null
     and expire_le > now();
  if not found then
    raise exception 'Code invalide ou expiré';
  end if;

  select role into role_appelant from profils where id = auth.uid();
  if role_appelant is null then
    raise exception 'Profil introuvable';
  end if;

  select * into c from contrats where id = inv.contrat_id;

  if role_appelant = 'employeur' then
    if c.employeur_id is not null and c.employeur_id <> auth.uid() then
      raise exception 'Ce contrat a déjà une famille';
    end if;
    if c.salariee_id = auth.uid() then
      raise exception 'Impossible de rejoindre son propre contrat';
    end if;
    update contrats set employeur_id = auth.uid(), statut = 'actif' where id = c.id;

  elsif role_appelant = 'salariee' then
    if c.salariee_id is not null and c.salariee_id <> auth.uid() then
      raise exception 'Ce contrat a déjà une salariée';
    end if;
    if c.employeur_id = auth.uid() then
      raise exception 'Impossible de rejoindre son propre contrat';
    end if;
    update contrats set salariee_id = auth.uid(), statut = 'actif' where id = c.id;

  else
    raise exception 'Rôle inconnu';
  end if;

  update invitations set utilisee_le = now() where code = inv.code;
  return c.id;
end;
$$;

revoke all on function rejoindre(text) from anon;

-- ============================================================
-- Contrôles
-- ============================================================
-- 1. employeur_id accepte le vide. Attendu : is_nullable = YES.
select column_name, is_nullable from information_schema.columns
 where table_schema = 'public' and table_name = 'contrats' and column_name = 'employeur_id';

-- 2. La règle de création accepte les deux parties. Attendu : une ligne contenant salariee_id.
select policyname from pg_policies
 where schemaname = 'public' and tablename = 'contrats' and cmd = 'INSERT'
   and with_check like '%salariee_id%';

-- 3. La fonction est bien remplacée. Attendu : une ligne contenant role_appelant.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace and proname = 'rejoindre'
   and prosrc like '%role_appelant%';
