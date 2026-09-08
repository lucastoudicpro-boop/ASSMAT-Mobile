# Notifications — mode d'emploi

Cinq étapes, une heure environ. Rien n'est irréversible : sans ces réglages, les
deux applications se compilent et fonctionnent, simplement sans notifications.

Les deux identifiants d'application, à recopier exactement :

```
fr.lucas.cocon.parent
fr.lucas.cocon.nounou
```

---

## 1. Créer le projet Firebase

1. Aller sur **console.firebase.google.com**, se connecter avec ton compte
   Google.
2. **Créer un projet**. Nom au choix, par exemple `Cocon`.
3. Google Analytics : **désactiver**. Inutile ici, et ça évite d'avoir à
   accepter des conditions supplémentaires.
4. Attendre la création, puis **Continuer**.

## 2. Déclarer les deux applications Android

À faire **deux fois**, une par application.

1. Sur la page d'accueil du projet, cliquer l'icône **Android**.
2. **Nom du package** : `fr.lucas.cocon.parent` la première fois,
   `fr.lucas.cocon.nounou` la seconde. Une faute de frappe ici et les
   notifications n'arriveront jamais, sans message d'erreur.
3. Surnom : `Cocon Parent`, puis `Cocon Nounou`.
4. **Certificat SHA-1 : laisser vide.** Il ne sert qu'à la connexion Google,
   pas aux notifications.
5. **Enregistrer l'application**, puis **télécharger google-services.json**.
6. Les étapes suivantes proposées par Firebase — ajouter le SDK, modifier les
   fichiers Gradle — **sont déjà faites** par le workflow. Cliquer
   « Suivant » puis « Continuer vers la console ».

Tu dois te retrouver avec deux fichiers. Renomme-les tout de suite pour ne pas
les confondre :

```
google-services-parent.json
google-services-nounou.json
```

## 3. Convertir les deux fichiers en base64

Un secret GitHub ne peut contenir qu'une seule ligne de texte. Il faut donc
convertir chaque fichier.

**Sur Windows**, ouvrir PowerShell dans le dossier contenant les fichiers, et
lancer ces deux commandes l'une après l'autre :

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("google-services-parent.json")) | Set-Clipboard
```

Le résultat est dans le presse-papiers : le coller directement dans le secret
GitHub de l'étape 4, puis recommencer avec l'autre fichier.

Si `Set-Clipboard` n'existe pas, remplacer la fin par
`| Out-File parent.txt` et ouvrir le fichier obtenu.

**Sur Mac ou Linux** : `base64 -i google-services-parent.json | tr -d '\n'`

## 4. Déposer les secrets sur GitHub

Dépôt → **Settings** → menu de gauche **Secrets and variables** → **Actions** →
**New repository secret**.

| Nom du secret | Contenu |
| --- | --- |
| `GOOGLE_SERVICES_PARENT` | le base64 du fichier `parent` |
| `GOOGLE_SERVICES_NOUNOU` | le base64 du fichier `nounou` |

Coller sans espace ni retour à la ligne ajouté. Les quatre secrets de signature
créés précédemment restent en place.

## 5. La clé du compte de service

C'est elle qui autorise le serveur à envoyer les notifications. Elle est
sensible : elle ne va **pas** sur GitHub, seulement dans Supabase.

1. Firebase → roue dentée en haut à gauche → **Paramètres du projet**.
2. Onglet **Comptes de service**.
3. **Générer une nouvelle clé privée** → confirmer. Un fichier `.json` se
   télécharge.
4. L'ouvrir avec le Bloc-notes, **tout sélectionner, tout copier**. Cette fois
   c'est le JSON tel quel, pas du base64.

Puis dans Supabase :

1. Tableau de bord du projet → **Edge Functions** → **Secrets**.
2. **Add new secret**.
3. Nom : `FCM_COMPTE_SERVICE`
4. Valeur : le JSON collé.

Garde ce fichier hors de GitHub. Quiconque l'obtient peut envoyer des
notifications au nom de ton projet.

## 6. Déployer la fonction

1. Supabase → **Edge Functions** → **Deploy a new function**.
2. Nom exact : `notifier`. Le nom sert d'adresse, une variante ne marchera pas.
3. Coller le contenu de `supabase/functions/notifier/index.ts`.
4. **Deploy**.

Trois variables sont fournies automatiquement par Supabase et n'ont pas à être
créées : `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`.

## 7. Les réglages d'authentification

Supabase → **Authentication** → **Providers** → **Email**.

- **Confirm email** : à activer. La personne devra cliquer un lien avant de
  pouvoir se connecter. Ça évite les comptes créés au hasard sur ton projet.
- **Allow new users to sign up** : à laisser activé le temps que ta salariée
  crée son compte. Tu pourras le désactiver ensuite.

## 8. Compiler et essayer

1. Pousser les modifications, ou lancer le workflow à la main.
2. Deux artefacts sont produits : `Cocon-Parent` et `Cocon-Nounou`.
3. Installer chacun sur son téléphone.
4. Ouvrir chaque application, aller dans les réglages, créer le compte.
   Android demandera l'autorisation d'envoyer des notifications : accepter.
5. Depuis Cocon Nounou, appuyer sur un besoin, par exemple **Couches**.
6. La notification doit arriver sur le téléphone du parent, écran verrouillé.

---

## Si rien n'arrive

Vérifier dans cet ordre, en s'arrêtant au premier point qui cloche.

**Le jeton est-il enregistré ?** Supabase → Table Editor → `jetons_push`. Il
doit y avoir une ligne par appareil connecté, avec `parent` ou `nounou` dans la
colonne `application`. Vide signifie que l'autorisation Android a été refusée,
ou que `google-services.json` manquait à la compilation.

**La fonction est-elle appelée ?** Supabase → Edge Functions → `notifier` →
onglet **Logs**. Chaque envoi doit y apparaître.

- `Jeton Google refusé` : le secret `FCM_COMPTE_SERVICE` est absent, tronqué ou
  mal collé.
- `Contrat inaccessible` : la personne n'appartient pas au contrat, ou le
  contrat n'est pas publié.
- `aucun appareil enregistré` : le destinataire ne s'est jamais connecté sur un
  téléphone, ou son autorisation a été refusée.

**L'application a-t-elle l'autorisation ?** Réglages Android → Applications →
Cocon → Notifications. Depuis Android 13, elles sont refusées par défaut.

**Le nom du package correspond-il ?** C'est l'erreur la plus courante et la plus
silencieuse : Firebase accepte l'envoi, mais aucun appareil ne le reçoit. Le
package déclaré dans Firebase doit être exactement `fr.lucas.cocon.parent` ou
`fr.lucas.cocon.nounou`.

---

## Ce qui n'a pas pu être vérifié

La signature du jeton Google et l'appel à Firebase n'ont jamais été exécutés :
il n'y avait ni réseau ni projet Firebase au moment d'écrire la fonction. Le
code est écrit avec soin, la logique d'autorisation est vérifiée, mais le
premier envoi réel sera aussi le premier essai.

Si la fonction renvoie une erreur, son message vient directement de Google et
dit précisément ce qui manque.
