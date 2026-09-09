-- Cocon — évolution 012
-- La salariée peut se retirer d'un contrat.
-- À exécuter après 008-a-011. Rejouable.

-- Elle ne peut pas modifier le contrat directement une fois la famille reliée :
-- c'est voulu, les termes appartiennent à l'employeur. Mais partir doit rester
-- possible sans dépendre de lui.
create or replace function quitter_contrat(p_contrat uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (select 1 from contrats where id = p_contrat and salariee_id = auth.uid()) then
    raise exception 'Ce contrat ne vous est pas rattaché';
  end if;

  -- Le contrat revient en attente : la famille peut inviter quelqu'un d'autre.
  -- Rien n'est efface : planning, journal et messages restent lisibles par elle.
  update contrats
     set salariee_id = null,
         statut = 'invitation'
   where id = p_contrat;
end;
$$;

revoke all on function quitter_contrat(uuid) from anon;

-- Contrôle. Attendu : une ligne.
select proname from pg_proc
 where pronamespace = 'public'::regnamespace and proname = 'quitter_contrat';
