-- AssMat+ partagé — règles d'accès
-- À exécuter après 001-schema.sql, dans l'éditeur SQL de Supabase.
--
-- Principe : la base refuse par défaut. Chaque autorisation est écrite
-- explicitement ci-dessous. Même si l'application se trompe, un compte ne peut
-- pas lire les données d'un foyer auquel il n'appartient pas.

-- ============================================================
-- Rien n'est accessible sans être connecté
-- ============================================================
revoke all on profils, contrats, invitations, jours, mois, messages,
              consentements, support, espaces, membres_espace, annonces
  from anon;

revoke all on function rejoindre(text) from anon;

alter table profils        enable row level security;
alter table contrats       enable row level security;
alter table invitations    enable row level security;
alter table jours          enable row level security;
alter table mois           enable row level security;
alter table messages       enable row level security;
alter table consentements  enable row level security;
alter table support        enable row level security;
alter table espaces        enable row level security;
alter table membres_espace enable row level security;
alter table annonces       enable row level security;

-- ============================================================
-- Profils
-- On lit son propre profil, et celui des personnes avec qui on a un contrat.
-- ============================================================
create policy profils_lecture on profils for select to authenticated
  using (
    id = auth.uid()
    or exists (
      select 1 from contrats c
       where (c.employeur_id = auth.uid() and c.salariee_id = profils.id)
          or (c.salariee_id  = auth.uid() and c.employeur_id = profils.id)
    )
  );

create policy profils_creation on profils for insert to authenticated
  with check (id = auth.uid());

create policy profils_modification on profils for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- ============================================================
-- Contrats
-- L'employeur gère, la salariée lit seulement.
-- ============================================================
create policy contrats_lecture on contrats for select to authenticated
  using (employeur_id = auth.uid() or salariee_id = auth.uid());

create policy contrats_creation on contrats for insert to authenticated
  with check (employeur_id = auth.uid());

create policy contrats_modification on contrats for update to authenticated
  using (employeur_id = auth.uid()) with check (employeur_id = auth.uid());

create policy contrats_suppression on contrats for delete to authenticated
  using (employeur_id = auth.uid());

-- ============================================================
-- Invitations
-- Aucune lecture, jamais : un code ne doit pas pouvoir être deviné en listant
-- la table. La salariée passe uniquement par la fonction rejoindre().
-- ============================================================
create policy invitations_creation on invitations for insert to authenticated
  with check (
    exists (select 1 from contrats
             where id = invitations.contrat_id and employeur_id = auth.uid())
  );

create policy invitations_suppression on invitations for delete to authenticated
  using (
    exists (select 1 from contrats
             where id = invitations.contrat_id and employeur_id = auth.uid())
  );

-- ============================================================
-- Jours et mois
-- L'appartenance suffit pour lire et écrire : c'est le déclencheur
-- proprietaire_jour() qui décide colonne par colonne.
-- ============================================================
create policy jours_lecture on jours for select to authenticated
  using (est_membre(contrat_id));

create policy jours_creation on jours for insert to authenticated
  with check (est_membre(contrat_id));

create policy jours_modification on jours for update to authenticated
  using (est_membre(contrat_id)) with check (est_membre(contrat_id));

create policy mois_lecture on mois for select to authenticated
  using (est_membre(contrat_id));

create policy mois_ecriture on mois for insert to authenticated
  with check (
    exists (select 1 from contrats
             where id = mois.contrat_id and employeur_id = auth.uid())
  );

create policy mois_modification on mois for update to authenticated
  using (
    exists (select 1 from contrats
             where id = mois.contrat_id and employeur_id = auth.uid())
  )
  with check (
    exists (select 1 from contrats
             where id = mois.contrat_id and employeur_id = auth.uid())
  );

-- ============================================================
-- Messages
-- On écrit en son nom, on lit ceux de son contrat, on ne réécrit pas le passé.
-- ============================================================
create policy messages_lecture on messages for select to authenticated
  using (est_membre(contrat_id));

create policy messages_envoi on messages for insert to authenticated
  with check (auteur_id = auth.uid() and est_membre(contrat_id));

create policy messages_suppression on messages for delete to authenticated
  using (auteur_id = auth.uid());

-- ============================================================
-- Consentements
-- Chacun signe le sien. Aucune modification ni suppression : un consentement
-- signé doit rester tel quel, c'est toute son utilité.
-- ============================================================
create policy consentements_lecture on consentements for select to authenticated
  using (est_membre(contrat_id));

create policy consentements_signature on consentements for insert to authenticated
  with check (personne_id = auth.uid() and est_membre(contrat_id));

-- ============================================================
-- Accès support
-- L'utilisateur l'ouvre lui-même et peut le refermer avant l'échéance.
-- ============================================================
create policy support_lecture on support for select to authenticated
  using (est_membre(contrat_id));

create policy support_ouverture on support for insert to authenticated
  with check (ouvert_par = auth.uid() and est_membre(contrat_id));

create policy support_fermeture on support for delete to authenticated
  using (ouvert_par = auth.uid());

-- ============================================================
-- Espace partagé
-- La salariée l'ouvre. Chaque famille accepte pour elle-même.
-- ============================================================
create policy espaces_lecture on espaces for select to authenticated
  using (est_membre_espace(id));

create policy espaces_creation on espaces for insert to authenticated
  with check (salariee_id = auth.uid());

create policy espaces_modification on espaces for update to authenticated
  using (salariee_id = auth.uid()) with check (salariee_id = auth.uid());

-- Une famille voit sa propre adhésion, et celle des autres seulement une fois
-- la sienne acceptée : refuser l'espace, c'est aussi rester invisible.
create policy membres_lecture on membres_espace for select to authenticated
  using (
    est_membre(contrat_id)
    or est_membre_espace(espace_id)
  );

create policy membres_invitation on membres_espace for insert to authenticated
  with check (
    exists (select 1 from espaces
             where id = membres_espace.espace_id and salariee_id = auth.uid())
  );

create policy membres_reponse on membres_espace for update to authenticated
  using (est_membre(contrat_id)) with check (est_membre(contrat_id));

create policy annonces_lecture on annonces for select to authenticated
  using (est_membre_espace(espace_id));

create policy annonces_publication on annonces for insert to authenticated
  with check (auteur_id = auth.uid() and est_membre_espace(espace_id));

create policy annonces_suppression on annonces for delete to authenticated
  using (auteur_id = auth.uid());
