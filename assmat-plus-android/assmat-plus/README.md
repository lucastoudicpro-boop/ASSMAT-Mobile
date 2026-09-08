# AssMat+ — version Android

Fiches de calcul du salaire d'une assistante maternelle (modèle Pajemploi), portage
de l'application Windows Electron vers Android via Capacitor.

Les règles de calcul et le gabarit A4 viennent de `renderer/template.js` de la version
PC, repris ligne pour ligne. Aucun montant ne change.

## Obtenir l'APK sans rien installer

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
cp android-extra/*.java android/app/src/main/java/fr/lucas/assmat/
npx cap sync android
cd android && ./gradlew assembleDebug
```

L'APK sort dans `android/app/build/outputs/apk/debug/app-debug.apk`.

## Ce que contient le dépôt

| Chemin | Rôle |
| --- | --- |
| `www/index.html` | L'application entière : interface, calculs, gabarit A4 |
| `capacitor.config.json` | Nom, identifiant `fr.lucas.assmat`, dossier web |
| `android-extra/AssMatPrint.java` | Module natif d'impression et d'export PDF |
| `android-extra/MainActivity.java` | Enregistre ce module au démarrage |
| `.github/workflows/build-apk.yml` | Compilation automatique de l'APK |

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
