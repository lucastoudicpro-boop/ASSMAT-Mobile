-- Cocon — évolution 013
-- Mode silencieux : les notifications du quotidien se taisent le week-end ou
-- sur une période, l'urgent passe toujours. Rejouable.

alter table profils add column if not exists silence_weekend boolean not null default false;
alter table profils add column if not exists silence_du date;
alter table profils add column if not exists silence_au date;

comment on column profils.silence_weekend is
  'Notifications du quotidien coupees le samedi et le dimanche. L''urgent passe toujours.';

-- Contrôle. Attendu : 3 lignes.
select column_name from information_schema.columns
 where table_schema = 'public' and table_name = 'profils'
   and column_name in ('silence_weekend', 'silence_du', 'silence_au')
 order by column_name;
