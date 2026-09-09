-- Cocon — évolution 010
-- Heures d'arrivée et de départ réelles, tapées par la nounou en un geste.
-- À exécuter après 008-a-009. Rejouable.

alter table jours add column if not exists arrivee time;
alter table jours add column if not exists depart  time;

-- La salariée seule écrit l'arrivée et le départ ; l'employeur seul écrit le
-- prévu. Chaque envoi de l'un préserve les colonnes de l'autre.
create or replace function proprietaire_jour()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  emp uuid; cop uuid; sal uuid;
begin
  select employeur_id, coparent_id, salariee_id into emp, cop, sal
    from contrats where id = new.contrat_id;

  if auth.uid() = emp or auth.uid() = cop then
    if tg_op = 'UPDATE' then
      new.heures_reelles   := old.heures_reelles;
      new.absence_salariee := old.absence_salariee;
      new.arrivee          := old.arrivee;
      new.depart           := old.depart;
    else
      new.heures_reelles   := null;
      new.absence_salariee := false;
      new.arrivee          := null;
      new.depart           := null;
    end if;

  elsif auth.uid() = sal then
    if tg_op = 'UPDATE' then
      new.heures_prevues := old.heures_prevues;
      new.absence_enfant := old.absence_enfant;
    else
      new.heures_prevues := null;
      new.absence_enfant := false;
    end if;
    -- les heures réelles se déduisent des deux pointages
    if new.arrivee is not null and new.depart is not null and new.depart > new.arrivee then
      new.heures_reelles := round(extract(epoch from (new.depart - new.arrivee)) / 3600.0, 2);
    end if;

  else
    raise exception 'Acces refuse a ce contrat';
  end if;

  new.maj_le := now();
  return new;
end;
$$;

-- Contrôle. Attendu : arrivee, depart.
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'jours' and column_name in ('arrivee', 'depart')
 order by column_name;
