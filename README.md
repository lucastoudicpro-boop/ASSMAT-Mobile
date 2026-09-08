# AssMat+ — version Android

Fiches de calcul du salaire d'une assistante maternelle (modèle Pajemploi), portage
de l'application Windows Electron vers Android via Capacitor.

Les règles de calcul et le gabarit A4 viennent de `renderer/template.js` de la version
PC, repris ligne pour ligne. Aucun montant ne change.

## Le plus simple : installer sans compiler

L'application s'installe directement depuis le navigateur, sans APK et sans outil
de compilation. Elle obtient une icone sur l'ecran d'accueil, s'ouvre en plein
ecran et fonctionne hors connexion.

1. Sur GitHub : **Settings** -> **Pages** -> *Source* : `Deploy from a branch`,
   branche `main`, dossier **`/docs`** -> **Save**.
2. Attendre une a deux minutes, puis recharger la page Settings -> Pages :
   l'adresse `https://<compte>.github.io/<depot>/` s'affiche en haut.
3. Ouvrir cette adresse dans **Chrome** sur le telephone.
4. Menu a trois points -> **Installer l'application** (ou *Ajouter a l'ecran d'accueil*).

L'export PDF passe alors par l'impression de Chrome, qui propose
« Enregistrer au format PDF ». Meme moteur de rendu que la version PC.

Pour publier une correction : modifier `docs/index.html`, incrementer `VERSION`
dans `docs/sw.js`, valider. Le telephone recupere la nouvelle version au lancement
suivant.

## Obtenir un vrai APK sans rien installer

1. Pousser ce dossier sur un dépôt GitHub (branche `main` ou `master`).
2. Onglet **Actions** → le workflow « Construire l'APK » démarre tout seul.
3. Au bout de 5 à 8 minutes, télécharger l'artefact **AssMat-plus** en bas de la page.
4. Décompresser, puis ouvrir `app-debug.apk` sur le téléphone. Android demandera
   d'autoriser l'installation depuis cette source : c'est normal pour une app non
   passée par le Play Store.

Le workflow tourne aussi à la demande : Actions → « Construire l'APK » → *Run workflow*.

## Compiler depuis le PC

Il faut Node 20, Java 21 et le SDK Android (fourni avec Android Studio).

```
npm install
npx cap add android
mkdir -p android/app/src/main/java/fr/lucas/assmat
mkdir -p android/app/src/main/java/android/print
cp android-extra/AssMatPrint.java android-extra/MainActivity.java android/app/src/main/java/fr/lucas/assmat/
cp android-extra/PdfPrint.java android/app/src/main/java/android/print/
npx cap sync android
cd android && ./gradlew assembleDebug
```

L'APK sort dans `android/app/build/outputs/apk/debug/app-debug.apk`.

## Ce que contient le dépôt

| Chemin | Rôle |
| --- | --- |
| `docs/index.html` | L'application entière : interface, calculs, gabarit A4 |
| `capacitor.config.json` | Nom, identifiant `fr.lucas.assmat`, dossier web |
| `android-extra/AssMatPrint.java` | Module natif : impression, PDF, envoi |
| `android-extra/PdfPrint.java` | Ecriture du PDF dans un fichier |
| `android-extra/res/` | Icones du lanceur Android |
| `android-extra/MainActivity.java` | Enregistre ce module au démarrage |
| `.github/workflows/build-apk.yml` | Compilation automatique de l'APK |
| `build-apk.yml` | Copie visible du meme fichier, a recopier sur GitHub |

Le dossier `android/` n'est pas versionné : Capacitor le régénère à chaque compilation.

## Différences avec la version Windows

**Stockage.** Les fiches passent des fichiers JSON de `%APPDATA%` aux préférences
Android. Elles restent sur le téléphone et survivent aux mises à jour de l'app.

**Export PDF.** `printToPDF` d'Electron est remplacé par le service d'impression
d'Android, qui propose « Enregistrer au format PDF ». Rendu vectoriel identique.

**Envoi par e-mail.** Le SMTP nodemailer ne peut pas fonctionner dans une WebView.
L'application ouvre le client e-mail du téléphone avec l'objet et le message
pré-remplis ; le PDF s'ajoute en pièce jointe depuis l'application e-mail. Plus de
mot de passe d'application à configurer.

**Interface.** Barre latérale devenue tiroir, sections repliables, calendrier en
liste d'un jour par ligne.

## Reprendre les fiches saisies sur le PC

Dossier salariée → Sauvegarde des données → **Importer un fichier .json**.
L'import accepte les fichiers de `%APPDATA%\fiche-salaire-assmat\fiches\`, un par un,
ainsi qu'une sauvegarde complète exportée depuis l'application.

## Icône

L'APK utilise l'icône Capacitor par défaut. Pour mettre celle de la version
Windows, remplacer les fichiers `android/app/src/main/res/mipmap-*/ic_launcher*.png`
après `npx cap add android`, ou passer par Android Studio (*Image Asset*).

## Le dossier `.github` est invisible

Windows et les gestionnaires de fichiers Android masquent les dossiers dont le nom
commence par un point. Le glisser-deposer sur GitHub les ignore aussi. Le fichier
`build-apk.yml` a la racine de l'archive en est une copie, a recreer sur GitHub :

1. **Add file** -> **Create new file**
2. Nom du fichier : `.github/workflows/build-apk.yml` (les `/` creent les dossiers)
3. Coller le contenu de `build-apk.yml`
4. **Commit changes**

Ce fichier ne sert qu'a produire un APK. Pour l'installation depuis Chrome
decrite plus haut, il est inutile.

## Planning et absences

**Marquer une absence.** Appuyer sur le numero d'un jour dans le calendrier fait
defiler trois etats : normal, enfant absent, salariee absente. La marque est
descriptive : elle n'entre dans aucun calcul, les heures restent celles saisies.
Elle alimente le planning partage et le message d'absence.

**Partager le planning.** Menu a trois points -> *Partager le planning du mois*.
Genere une feuille A4 avec les heures jour par jour, les jours feries, les
absences et le total, puis ouvre le selecteur d'applications : e-mail,
messagerie, enregistrement dans Drive.

**Signaler une absence.** Menu a trois points -> *Signaler une absence*. Le
message est prerempli a partir des jours marques, les dates consecutives etant
regroupees (« du 11 au 13 mars 2026 »). Il reste modifiable avant l'envoi.

## Rappel mensuel

Dossier salariee -> **Rappel mensuel**. Une notification le jour choisi du mois,
par defaut le 25, et une relance trois jours plus tard si la fiche n'a pas ete
envoyee. La fiche est marquee comme envoyee des qu'elle part par e-mail, ce qui
annule la relance du mois. Les rappels sont reprogrammes a chaque ouverture de
l'application, six mois a l'avance.

Android 13 et plus demande l'autorisation d'afficher des notifications : elle est
demandee a l'activation du rappel.

## Agenda

Dossier salariee -> **Agenda** -> *Exporter les plages du mois*. Produit un
fichier `.ics` avec une plage par jour d'accueil, en partant de l'heure d'arrivee
habituelle. Les jours feries et les jours marques absents sont exclus. Le partage
propose Google Agenda, qui importe le fichier directement.

Il n'y a volontairement pas de synchronisation permanente : elle imposerait un
projet Google Cloud, un ecran de consentement OAuth et une validation de
l'application pour les autorisations agenda.

## Interface

Theme sombre automatique selon le reglage du telephone. Bouton retour d'Android
gere : il referme le tiroir, la feuille d'actions ou la fenetre ouverte, revient
a la saisie, et ne quitte l'application qu'au dernier appui. Mise en page sur
deux colonnes a partir de 900 px de large, pour les tablettes et le mode paysage.
