# Protocole de sécurité — Cocon

À rejouer **avant chaque publication**, et une fois par trimestre. Chaque point
a une commande ou une action précise et un résultat attendu. Un point qui ne
donne pas le résultat attendu bloque la publication.

Le script `verifier-securite.py` à la racine joue les points marqués ⚙ en une
commande : `python3 verifier-securite.py`.

---

## A. La base de données

### A1 ⚙ Toute table est protégée par ligne
Attendu : zéro ligne.
```sql
select relname from pg_class
 where relnamespace = 'public'::regnamespace and relkind = 'r' and not relrowsecurity;
```

### A2 ⚙ Le rôle anonyme ne peut rien lire
Attendu : zéro ligne.
```sql
select table_name from information_schema.role_table_grants
 where grantee = 'anon' and table_schema = 'public';
```

### A3 ⚙ Aucune règle permissive
Une règle `using (true)` sans `auth.uid()` ouvre la table à tout compte connecté.
Attendu : zéro ligne.
```sql
select tablename, policyname from pg_policies
 where schemaname = 'public'
   and (qual = 'true' or with_check = 'true');
```

### A4 ⚙ Toute fonction privilégiée vérifie l'appelant
Une fonction `security definer` contourne les règles : elle doit vérifier
elle-même `auth.uid()` ou passer par `est_membre` / `est_employeur`. Le script
liste celles qui ne le font pas ; chacune doit être justifiée (déclencheur,
ou lecture volontairement publique comme `rechercher_nounous`).

### A5 ⚙ `search_path` figé sur chaque fonction privilégiée
Sans cela, un attaquant peut faire résoudre `now()` vers une fonction à lui.
Attendu : zéro ligne.
```sql
select proname from pg_proc p
 where pronamespace = 'public'::regnamespace and prosecdef
   and not exists (select 1 from unnest(proconfig) c where c like 'search_path=%');
```

### A6 — Le stockage vérifie l'identité
Chaque règle sur `storage.objects` doit citer `auth.uid()` ou une fonction
d'appartenance. Le bucket `photos` est **privé** (pas d'URL publique).

### A7 — Limites du bucket
Tableau de bord → Storage → photos → Settings :
- taille maximale : **8 Mo**
- types autorisés : `image/jpeg`, `image/png`, `image/webp`, `application/pdf`

Sans cela, l'API accepte cinquante mégaoctets de n'importe quoi.

---

## B. Les fonctions serveur

### B1 — `notifier` : la clé de service ne sort jamais
Grep dans `index.ts` : `CLE_SERVICE` n'apparaît que dans la création du
client, jamais dans un `console.log`, un `return`, une réponse.

### B2 — `notifier` : identité vérifiée côté serveur
La fonction appelle `getUser()` avec le jeton reçu et refuse sans lui. Elle ne
fait jamais confiance à un `user_id` passé dans le corps.

### B3 — `notifier` : destinataire filtré en mémoire
Après lecture des jetons, `personne_id === destinataire` est vérifié une
seconde fois. Un jeton d'un autre compte ne peut pas recevoir la notification.

### B4 — Secrets dans Supabase, jamais dans le dépôt
`FCM_COMPTE_SERVICE` et `SUPABASE_SERVICE_ROLE_KEY` vivent dans Edge Functions
→ Secrets. Grep du dépôt : aucune clé privée, aucun JSON de compte de service.

---

## C. Le client

### C1 ⚙ Aucun texte d'autrui inséré sans échappement
Tout ce qui vient du serveur — message, mot du journal, prénom, présentation —
passe par `esc()` avant `innerHTML`. Le script cherche les interpolations
`${...}` portant un champ utilisateur sans `esc(`. Attendu : zéro.

### C2 ⚙ Ce qui doit rester local ne part jamais
Le script cherche `secu`, `iban`, `bic`, `nir`, `adresse` dans tout appel
`Supa.ecrire` / `Supa.modifier` et dans la sauvegarde. Attendu : zéro.

### C3 — Session limitée et rafraîchie
Session de huit heures, jeton rafraîchi automatiquement, retry sur 401.
Déconnexion accessible depuis les réglages.

### C4 — Verrou local
Code ou empreinte disponibles, jamais imposés. Le code est haché avant
stockage.

### C5 — Aucun `prompt` / `confirm` du navigateur
Ils permettent le détournement par une extension. Attendu : zéro.

### C6 — La mauvaise application refuse à la porte
Un compte nounou dans Cocon Parent (et l'inverse) est arrêté **avant**
l'affichage, déconnecté, et ne voit qu'un écran dédié.

---

## D. Le transport et la configuration

### D1 — HTTPS seul
`capacitor.config.json` : `"allowNavigation"` limité à Supabase ;
`androidScheme: "https"`. Aucun `cleartextTrafficPermitted`.

### D2 — La clé publique est publiable
`sb_publishable_…` est faite pour être dans le code. La clé `service_role`
ne l'est **jamais**. Grep : `service_role` absent des `docs/`.

### D3 — Les secrets GitHub inutiles sont supprimés
`SUPABASE_ANON_KEY` et `SUPABASE_URL` sont dans le code : les retirer des
secrets du dépôt. Seul `FCM_COMPTE_SERVICE` et la clé de signature restent.

### D4 — La clé de signature Android est sauvegardée
`cocon.jks` et son mot de passe dans un gestionnaire de mots de passe. Perdue,
aucune mise à jour n'est plus possible. Play App Signing activé.

---

## E. Le processus

### E1 ⚙ Syntaxe, doublons, fonctions mortes
Le script vérifie les deux applications. Attendu : tout vert.

### E2 — Chaque migration est rejouable
Tout `create policy` a son `drop policy if exists`, tout `create trigger` son
`drop trigger if exists`, toute table `if not exists`.

### E3 — L'archive ne contient pas de dépôt Git
Le workflow d'extraction jette tout `.git` et ne remplace jamais `.github`.

### E4 — Un compte de test par rôle
Un parent et une nounou de test, reliés, pour rejouer les parcours avant
publication : connexion, journal, photo, message, notification, suppression.

---

## F. Le RGPD

### F1 — La politique dit la vérité
`docs/confidentialite.html` correspond à ce que fait l'application. Chaque
promesse (archive, effacement, opposition) a son bouton.

### F2 — L'effacement existe
Réglages → Mes données → Supprimer mon compte. Quinze jours de délai, puis
purge quotidienne à 3 h 30 (`pg_cron` activé).

### F3 — Ce qui reste après purge
Le compte d'authentification (`auth.users`) survit : l'adresse e-mail reste.
**À lever avant production** : fonction serveur avec la clé de service
appelant `auth.admin.deleteUser`.

### F4 — Une adresse joignable
`rgpd@cocon-app.fr` dans la politique, avec réponse sous un mois.

### F5 — Registre des traitements
Un document listant : quelles données, pourquoi, qui y accède, combien de
temps. Obligatoire dès que l'application sort du cercle familial.

---

## G. Ce qui n'est pas couvert

Dit franchement, pour ne pas croire à une protection qui n'existe pas :

- **Pas d'audit externe.** Ce protocole est celui de l'auteur. Un regard
  extérieur trouvera ce qu'il n'a pas vu.
- **Pas de limitation de débit** sur les fonctions serveur : un compte peut
  appeler `notifier` en boucle.
- **Pas de journal d'accès** : on ne sait pas qui a lu quoi, seulement qui a
  écrit.
- **Pas de chiffrement de bout en bout** : Supabase voit les données. Le
  chiffrement au repos est celui de l'hébergeur.
- **Pas de double authentification.**

Chacun de ces points est un chantier, pas une case à cocher.
