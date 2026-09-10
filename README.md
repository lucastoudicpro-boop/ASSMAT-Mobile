# Cocon — deux applications Android

Version 0.9.7

**Cocon Parent** (`fr.lucas.cocon.parent`, vert d'eau) — le parent employeur.
Fiches de salaire, calculs Pajemploi, PDF, planning, contrat, congés, rappels.
C'est l'application historique, renommée.

**Cocon Nounou** (`fr.lucas.cocon.nounou`, rose poudré) — l'assistante maternelle.
Le planning de chaque enfant en horaires, les informations utiles, les demandes de
fourniture en un geste, les échanges et les photos. Elle rejoint un contrat avec un
code d'invitation, après avoir signé l'accord de partage.

Elle ne déclare pas d'heures : la saisie du temps de travail reste du côté du
parent employeur, avec les calculs.

Les deux partagent `commun/` : le client de base de données et l'encodeur QR.
Un seul dépôt, deux compilations, deux APK.

## Ce qui ne circule pas

L'application de la salariée ne contient tout simplement pas le code qui manipule
les montants, l'IBAN ou le numéro de sécurité sociale. Une fuite par bug
d'affichage y est impossible, pas seulement improbable.


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
| `android-extra/AssMatBio.java` | Deverrouillage par empreinte |
| `android-extra/biometrie.gradle` | Dependance androidx.biometric, ajoutee par le workflow |
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

**Navigation.** Barre en bas a cinq entrees : Accueil, Saisie, Fiche, Bilan, Dossier.
Le tiroir lateral ne sert qu'a choisir le mois et a en creer un nouveau. Les
actions du mois affiche sont dans le menu a trois points en haut a droite.

**Theme.** Clair par defaut. Dossier salariee -> Apparence pour passer en sombre
ou suivre le reglage du telephone.

**Bouton retour d'Android.** Referme le tiroir, la feuille d'actions ou la
fenetre ouverte, revient a la saisie, et ne quitte l'application qu'au dernier
appui.

**Grands ecrans.** A partir de 1000 px, le tiroir devient une colonne fixe a
gauche et les cartes se repartissent sur deux colonnes.

## Accueil

Ecran d'ouverture de l'application.

**En-tete.** Mois affiche, solde a verser, et l'etat de la fiche : a etablir, en
cours, envoyee.

**A faire.** Les deux alertes les plus urgentes. La cloche en haut a droite ouvre
la liste complete, avec un bouton par alerte qui mene directement a l'endroit ou
la regler. Ces alertes sont deduites des donnees du mois : calendrier vide,
salaire net non reporte, fiche non envoyee, periode de declaration Pajemploi en
cours, jours feries du mois, rappel desactive.

**Raccourcis.** Six tuiles : nouveau mois, remplir le calendrier, enregistrer le
PDF, envoyer la fiche, signaler une absence, partager le planning.

**Demarches.** Liens vers les sites officiels, ouverts dans le navigateur du
telephone : Pajemploi, le simulateur brut vers net, la CAF, l'aide Pajemploi de
l'Urssaf, les impots et monenfant.fr.

**Annee en cours.** Total verse, heures cumulees, nombre de fiches.

## Versement et rappels

Le **jour de versement du salaire** est une donnee du contrat, saisie une fois
dans Dossier salariee -> Versement et rappels. Saisir 31 pour « dernier jour du
mois » : les mois plus courts sont ramenes a leur dernier jour.

Tous les rappels en decoulent, trois par mois :

| Quand | Objet |
| --- | --- |
| N jours avant le versement, 3 par defaut | La fiche du mois est a etablir |
| Le jour du versement | Relance si la fiche n'est pas partie |
| Le 1er du mois suivant | La declaration Pajemploi est ouverte, jusqu'au 5 |

L'accueil affiche le compte a rebours jusqu'au versement, et le centre de
notifications alerte a partir de sept jours avant si la fiche n'est pas envoyee.

La declaration Pajemploi se fait du 1er au 5 du mois qui suit la periode de paie.
Depuis janvier 2026, une declaration distincte est demandee pour chaque enfant
accueilli.

## Gestion du contrat

**Avenants dates.** Dossier salariee -> Avenants au contrat. Le bouton enregistre
les tarifs et horaires de la fiche affichee comme version du contrat a partir
d'une date d'effet. Chaque nouveau mois reprend la version en vigueur a son
premier jour : une revalorisation au 1er janvier s'applique a janvier et aux
mois suivants, sans jamais toucher aux fiches deja etablies.

**Conges payes.** Compteur base sur la convention des particuliers employeurs :
2,5 jours ouvrables acquis par mois travaille, du 1er juin au 31 mai, plafonnes
a 30 jours. Les jours pris se saisissent a la main. L'indemnite affichee est la
regle des 10 % du brut de la periode de reference ; le maintien de salaire peut
etre plus favorable, c'est le plus avantageux des deux qui s'applique, a
verifier au cas par cas.

**Suivi des versements.** Une case « Salaire verse » avec sa date et son moyen
de paiement, dans la carte Conges et paiement. L'accueil affiche l'etat reel de
la fiche : a etablir, en cours, envoyee, versee. Le bilan annuel gagne une
colonne « Paye », et une alerte remonte si une fiche est partie sans que le
versement soit enregistre.

**Bloc declaration de revenus.** En bas du bilan annuel : sommes effectivement
versees et part des indemnites. Ces chiffres viennent de tes fiches et servent
de controle. L'attestation fiscale de Pajemploi reste la reference : elle
integre les cotisations et le complement de libre choix du mode de garde, que
l'application ne connait pas.

## Verrouillage

Dossier salariee -> Securite. Un code a quatre chiffres, saisi sur un pave
numerique, et l'empreinte si le telephone en a une d'enregistree.

Le code n'est jamais stocke : l'application conserve une empreinte PBKDF2-SHA256
sur 120 000 iterations, avec un sel tire au hasard a chaque changement de code.
Verifie dans les tests : le fichier de donnees ne contient nulle part le code en
clair.

L'application se reverrouille apres deux minutes passees en arriere-plan, pas
avant : passer sur Pajemploi ou l'application e-mail pendant la saisie ne
redemande pas le code.

**Ce que ce verrou ne fait pas.** Il protege l'affichage, pas le fichier. Qui a
un acces root ou une sauvegarde complete du telephone lit les fiches malgre lui.
Le chiffrement du stockage serait une autre chantier.

## Seuils legaux

Dossier salariee -> Seuils legaux. Le salaire horaire minimum et l'indemnite
d'entretien minimum se saisissent a la main : ils sont revises chaque annee et
l'application ne les devine pas. Une alerte remonte des qu'un tarif de la fiche
passe dessous, et une autre rappelle de les verifier quand l'annee indiquee est
depassee.

## Regularisation annuelle

En bas du bilan : heures payees par la mensualisation, heures relevees au
calendrier, et l'ecart entre les deux. Un ecart positif signale des heures
effectuees au-dela de la mensualisation, a verifier en heures complementaires ou
majorees.

## Signature de l'APK

Sans clé, le workflow produit une version de debogage : elle s'installe, mais
chaque nouvelle version doit etre desinstallee avant d'installer la suivante.
Avec une cle, les mises a jour s'installent par-dessus et gardent les donnees.

**Creer la cle, une seule fois.** Onglet Actions -> « Creer la cle de signature »
-> Run workflow. Le nom saisi sert uniquement a identifier la cle ; les
caracteres reserves des noms X.500 (`, + = < > # ;` et l'antislash) sont retires
automatiquement, car keytool les interprete comme des separateurs.

Telecharger l'artefact, lire `a-faire.txt`, puis creer quatre secrets dans
Settings -> Secrets and variables -> Actions :

| Secret | Contenu |
| --- | --- |
| `ANDROID_KEYSTORE` | le contenu de `assmat.jks.base64` |
| `ANDROID_KEYSTORE_PASSWORD` | le mot de passe genere |
| `ANDROID_KEY_ALIAS` | `assmat` |
| `ANDROID_KEY_PASSWORD` | le meme mot de passe |

Conserver `assmat.jks` hors de GitHub. Cette cle perdue, aucune mise a jour ne
s'installe plus par-dessus l'application existante.

**Ce que la signature ne fait pas.** Elle ne supprime pas l'avertissement
« application inconnue » : celui-ci vient de l'installation hors magasin, pas de
l'absence de signature. Tout APK est signe, y compris celui de debogage.

## Publier une version

Poser une etiquette declenche la compilation et la publication :

```
git tag v0.8.0
git push origin v0.8.0
```

Le workflow attache `AssMat-plus.apk` a une version publiee du depot.

## Mises a jour

Dossier salariee -> Mises a jour. L'application interroge les versions publiees
du depot et compare a sa propre version. Si une version plus recente existe,
elle apparait dans le centre de notifications avec un bouton de telechargement.

L'application ne telecharge ni n'installe rien elle-meme : Android l'interdit a
une application hors magasin. Elle ouvre la page, le reste est manuel.

## Plusieurs enfants

Dossier salariee -> Enfants accueillis -> Ajouter un enfant. Chaque enfant a ses
propres fiches mensuelles, son propre contrat et son propre calendrier. Le
selecteur en haut du tiroir bascule de l'un a l'autre, et le bilan annuel
ventile chaque ligne par enfant.

Depuis janvier 2026, Pajemploi demande une declaration distincte par enfant
accueilli, meme chez la meme assistante maternelle : l'application suit
desormais ce decoupage.

**Compatibilite.** Le premier enfant conserve les cles de fiches existantes
(`AAAA-MM`), les suivants utilisent `AAAA-MM#e2`. Aucune migration n'a lieu :
les fiches deja enregistrees restent lisibles telles quelles.

## Aide a la declaration

Onglet Saisie -> Ma declaration Pajemploi. Les valeurs a saisir dans le
formulaire, dans son ordre : periode, jours d'activite, heures normales
arrondies a l'entier, heures complementaires, heures majorees, salaire net,
indemnites d'entretien et de repas. Un appui sur une ligne copie la valeur.

## Heures complementaires automatiques

Carte Heures du mois -> bouton Reprendre. Reporte les heures complementaires
relevees au calendrier, et les heures majorees qui depassent la mensualisation.
Les heures majorees prevues au contrat sont deja payees par la mensualisation :
seules celles effectuees en plus sont reportees.

## Sauvegarde

Dossier salariee -> Sauvegarde des donnees -> Sauvegarder hors du telephone.
Envoie la sauvegarde complete vers Drive, la boite mail ou toute application de
partage. La date de la derniere sauvegarde est affichee, une alerte remonte
apres 45 jours, et un rappel mensuel peut etre programme le lendemain du
versement.

Les fiches ne vivent que sur l'appareil : sans copie, un telephone perdu ou
reinitialise emporte tout l'historique.

## Attestations

Dossier salariee -> Attestations. Deux documents A4, partages comme la fiche :

- **Attestation d'emploi** : identites, date d'embauche, enfant accueilli, duree
  contractuelle et salaire mensualise.
- **Attestation de salaire** : les N derniers mois declares, mois par mois, avec
  le total et la moyenne mensuelle.

Ce sont des attestations sur l'honneur, pour un dossier de location ou de
credit. Elles ne remplacent pas l'attestation employeur destinee a France
Travail, qui se genere depuis Pajemploi en fin de contrat.

## Fin de contrat

Dossier salariee -> Fin de contrat. L'application additionne ce qu'elle sait de
facon certaine : anciennete, total des salaires bruts et nets sur toute la duree
du contrat, indemnites versees, conges acquis non pris et leur indemnite
compensatrice.

**Elle ne tranche pas sur l'indemnite de rupture.** Les sources se contredisent :
plusieurs retiennent le 1/80e des salaires bruts issu de l'ancienne convention
des assistants maternels, une autre le 1/120e des nets depuis la convention des
particuliers employeurs entree en vigueur en 2022. L'ecart est important.
L'application affiche les deux montants et renvoie vers le Relais Petite Enfance,
gratuit, pour confirmer la formule applicable au contrat.

L'ecran rappelle aussi ce qui reste manuel : notification ecrite, preavis,
regularisation du dernier mois, attestation France Travail via Pajemploi,
certificat de travail et recu pour solde de tout compte.

## Recherche et graphique

Un champ de recherche filtre la liste des mois dans le tiroir, par nom de mois,
annee ou prenom. Le bilan annuel affiche douze barres, une par mois, pour lire
l'allure de l'annee d'un coup d'oeil.

## Planning en grille

Carte Calendrier de presence -> bascule **Grille / Liste**. La grille montre le
mois en sept colonnes, une case par jour, avec le total d'heures, les week-ends,
les jours feries et les absences. Un appui sur une case ouvre l'edition du jour :
presence, heures complementaires, heures majorees, et l'etat d'absence.

La liste reste disponible pour la saisie au clavier ; les deux vues portent sur
les memes donnees et se mettent a jour ensemble.

## Dossier et parametres

Deux ecrans distincts. Le **Dossier**, dans la barre du bas, contient ce qui
concerne la relation de travail : salariee, enfants accueillis, planning type,
contrat et avenants, conges payes, attestations, fin de contrat, notes.

Les **Parametres**, accessibles par l'engrenage en haut a droite, contiennent le
reglage de l'application : banniere des documents, modele d'e-mail, securite,
seuils legaux, apparence, versement et rappels, agenda, mises a jour,
sauvegarde.

## Banniere des documents

Parametres -> Banniere des documents. Ajoute un bandeau signe en bas du planning
partage et des attestations, avec un apercu en direct.

Elle n'est jamais ajoutee a la fiche de calcul A4 : ce document doit rester
conforme au modele papier de Pajemploi.

## Compte en ligne

Parametres -> Compte en ligne. Adresse du projet Supabase, cle publique
« anon », puis creation du compte ou connexion.

Le bouton **Verifier l'acces a la base** interroge reellement le serveur et
rapporte trois points : la lecture du profil, celle des contrats, et surtout que
la table des invitations refuse bien la lecture. Ce dernier point est le controle
de securite : une base qui laisse lire les codes d'invitation laisse rejoindre
le contrat de n'importe qui.

**Aucune bibliotheque externe.** Le client est ecrit a la main, une centaine de
lignes sur l'HTTP de Supabase. L'application ne charge donc aucun script depuis
Internet et reste utilisable hors connexion.

**La session vit dans sa propre cle de stockage**, hors du bloc sauvegarde et
exporte : un jeton de rafraichissement n'a rien a faire dans un fichier de
sauvegarde partage par e-mail.

**Ce qui n'est jamais envoye** : fiches, montants, IBAN, numero de securite
sociale, numero d'agrement. La connexion ne sert qu'au planning partage.

### Avant d'ouvrir a d'autres

La cle « anon » est publique par conception, mais le depot GitHub l'est aussi
si les Pages sont activees. Elle est saisie dans l'application, pas ecrite dans
le code, ce qui evite de la publier. Cote Supabase, pense a fermer les
inscriptions libres tant que l'usage reste prive : Authentication -> Providers ->
desactiver « Enable email signup », et creer les comptes a la main.

## Partage avec la salariee

Dossier salariee -> Partage avec la salariee. Un contrat par enfant, comme
l'exige Pajemploi depuis janvier 2026.

**Publier le contrat.** L'accord de partage s'affiche, la validation vaut
signature. Le contrat est cree en base et le planning du mois part aussitot.

**Code d'invitation.** Six caracteres tires au hasard, sans O ni 0 ni I ni 1,
valables sept jours. Deux QR l'accompagnent : l'un pointe vers la page de
telechargement de Cocon Nounou, l'autre porte le code. A montrer quand vous etes
ensemble : elle installe, puis rejoint.

**Synchronisation.** Automatique, quatre secondes apres chaque modification, et
au lancement. Un bouton force l'envoi. Ce qui monte : les heures prevues jour par
jour, les absences de l'enfant, le total du mois et l'etat de la fiche.

**Retirer l'acces.** En fin de contrat. La salariee ne voit plus rien ; les
fiches locales ne sont pas touchees.

### Pourquoi l'envoi ne peut pas ecraser son travail

L'envoi du parent est un upsert sur la table `jours`. Pour les lignes qui
existent deja, le declencheur `proprietaire_jour` restaure les colonnes qui
appartiennent a la salariee : ses heures effectuees et ses propres absences.
La base protege donc son travail meme si l'application se trompe.

### Le QR

Encodeur ecrit a la main, sans bibliotheque : les applications ne chargent aucun
script externe. Verifie en relisant les codes produits avec un decodeur
independant, sur les dix versions et sur les cas reels, et en controlant que les
600 syndromes Reed-Solomon sont nuls.

## Ce que contient Cocon Nounou

**Accueil.** Le total de la semaine et la liste de ses familles.

**Planning.** Par enfant : les horaires convenus au contrat, jour par jour, sous
la forme « lundi 08:00 vers 17:30 ». Puis le calendrier du mois avec les
exceptions et les absences. Enfin les informations de l'enfant : prenom, date de
naissance, age calcule, lieu d'accueil.

**Messages.** Huit demandes de fourniture en un appui : couches, lait, eau, tenue
de rechange, creme, repas, chaussons, doudou. Un champ libre pour un mot au
parent. Et l'envoi de photos.

**Familles.** Rejoindre avec un code, voir ses contrats.

## Les photos

Bucket prive, range par contrat : le premier segment du chemin est l'identifiant
du contrat, et les regles du stockage s'appuient dessus. Une famille ne peut pas
voir les photos prises chez une autre, meme en devinant une adresse.

Les photos ne sont jamais servies par une URL publique : les deux applications
les telechargent avec le jeton de session, puis les affichent depuis la memoire.

L'appareil photo passe par le champ de fichier du navigateur, avec `capture` :
aucun module natif supplementaire, donc rien de plus a compiler.

## Les horaires

Le planning de base vit sur le contrat, sous forme d'horaires par jour de
semaine. Le parent les saisit dans Planning type, ils partent avec la
synchronisation, et la salariee les voit tels quels. La duree quotidienne en est
deduite pour la mensualisation : 08:00 vers 17:30 donne 9,5 heures.

## Notifications

Vraies notifications systeme, qui arrivent ecran verrouille. La chaine complete :
Firebase, jeton de l'appareil en base, fonction serveur, plugin dans les APK.

### Ce qu'il faut faire une fois, cote Firebase

1. Creer un projet sur console.firebase.google.com.
2. Y ajouter deux applications Android : `fr.lucas.cocon.parent` et
   `fr.lucas.cocon.nounou`. Telecharger les deux `google-services.json`.
3. Les convertir en base64 : `base64 -w0 google-services.json`
4. Deux secrets GitHub : `GOOGLE_SERVICES_PARENT` et `GOOGLE_SERVICES_NOUNOU`.
   Sans eux, la compilation reussit quand meme, simplement sans notifications.
5. Parametres du projet -> Comptes de service -> generer une cle privee.
   Le fichier JSON obtenu devient le secret `FCM_COMPTE_SERVICE` cote Supabase.

### Cote Supabase

Executer `005-notifications-fermetures.sql`, puis deployer la fonction
`supabase/functions/notifier`. Depuis le tableau de bord : Edge Functions ->
Deploy a new function, coller le contenu de `index.ts`. Ajouter le secret
`FCM_COMPTE_SERVICE`.

### Comment c'est protege

La fonction verifie l'appelant deux fois. Son jeton doit etre valide, et la
lecture du contrat se fait **avec ses propres droits** : s'il n'appartient pas au
contrat, la base ne lui renvoie rien et l'envoi s'arrete. La cle de service ne
sert qu'a une chose, lire les jetons du destinataire, que personne d'autre ne
peut lire.

Le destinataire est toujours l'autre partie, jamais l'expediteur. Un jeton refuse
par Firebase, signe d'une application desinstallee, est retire de la base.

### Ce qui declenche une notification

| Evenement | Qui recoit |
| --- | --- |
| Demande de fourniture | le parent |
| Message de la salariee | le parent |
| Photo envoyee | le parent |
| Fermeture annoncee | toutes ses familles |
| Reponse du parent | la salariee |

## Cocon Nounou, suite

**Aujourd'hui.** Sur l'accueil : qui vient aujourd'hui et de quelle heure a
quelle heure, toutes familles confondues, dans l'ordre des arrivees. Un appui
ouvre le planning de l'enfant.

**Mes fermetures.** Ses conges et jours de fermeture. Chaque famille est
prevenue automatiquement, par message et par notification. Les employeurs les
lisent aussi depuis leur propre application.

## Le journal de la journee

Elle remplit, les parents lisent. La base leur interdit d'ecrire : les trois
regles d'ecriture exigent d'etre la salariee du contrat. Une transmission que le
parent pourrait reecrire ne vaudrait rien.

**Cote Cocon Nounou**, onglet Journal. Un jour a la fois, avec les fleches, sans
possibilite d'aller sur un jour a venir. Repas et humeur en un appui, horaires de
sieste, compteur de changes, et un mot libre. L'enregistrement previent le parent
par notification, avec le resume en corps de message.

**Cote Cocon Parent**, Dossier -> Journal de la journee. Les quatorze derniers
jours, en lecture seule.

Le fichier `006-journal.sql` se termine par un controle qui verifie precisement
ce point : les trois regles d'ecriture doivent toutes mentionner `salariee_id`.

## La fiche d'urgence

Cocon Parent, Dossier -> Fiche d'urgence. Medecin et son numero, allergies,
traitements, particularites, personnes autorisees a venir chercher l'enfant, et
les autorisations. Un badge « a remplir » reste visible tant qu'elle n'est pas
signee.

Cote Cocon Nounou, elle apparait dans la fiche de l'enfant, en lecture seule.
Les allergies et les traitements sont mis en evidence, les numeros sont
cliquables.

**Elle est conservee sur l'appareil de la salariee.** Le jour ou il faut appeler
le medecin, il n'y a pas toujours de reseau. La copie locale est rafraichie a
chaque consultation en ligne.

Cote base, seul le parent ecrit : les deux regles d'ecriture exigent d'etre
l'employeur du contrat.

## La galerie et les photos de groupe

Une photo peut concerner plusieurs enfants. Quand la salariee en envoie une,
l'application lui propose les autres familles **qui ont coche l'autorisation des
photos de groupe**, et elle seules.

Cette regle n'est pas seulement dans l'interface : un declencheur la verifie a
l'ecriture du lien entre la photo et l'enfant. Une famille qui n'a pas autorise
les photos de groupe voit le lien refuse par la base, meme si l'application se
trompe.

Le rangement du stockage a change : le dossier est desormais l'identifiant de la
photo, ce qui permet a plusieurs familles d'y acceder sans se voir entre elles.

## Finition

Fond legerement irise vers le haut, cartes plus douces, retour au toucher sur
tous les elements cliquables, et une apparition en fondu a chaque changement de
vue. Tout est desactive si le telephone est regle sur mouvement reduit.

## Correctifs 0.9.6

Deux manques introduits en 0.9.5, cote parent :

- La galerie remplie par la salariee n'etait lue par personne. Le parent la voit
  desormais dans Dossier -> Galerie, avec le nombre de photos en badge.
- Ses fermetures n'arrivaient que sous forme de message. Elles ont maintenant
  leur carte, avec la mention passee ou a venir. Le README affirmait deja que le
  parent les voyait : c'etait faux, ca ne l'est plus.

## Reprendre un mois

Menu des trois points -> Reprendre un mois precedent. Les donnees du mois choisi
remplacent celles du mois affiche : identites, contrat, tarifs, quantites
d'indemnites, salaire net. Tout reste modifiable ensuite.

Trois choses ne se reprennent jamais, parce qu'elles appartiennent au mois
affiche : la periode, les acomptes, et l'etat d'envoi ou de versement.

**Le calendrier n'est pas repris par defaut.** Les jours de la semaine ne tombent
pas aux memes dates d'un mois a l'autre : recopier le calendrier de septembre sur
octobre decale tous les jours. « Remplir le mois » fait mieux le travail, en
connaissant les horaires du contrat et les jours feries. Une case permet quand
meme de le reprendre si tu le veux.

## Regularisation annuelle

Bilan annuel, en bas. Obligatoire en annee incomplete : la convention prevoit une
regularisation a la date anniversaire du contrat quand l'accueil porte sur 46
semaines ou moins par periode de douze mois.

L'application suit la **periode en cours**, du dernier anniversaire a
aujourd'hui, plutot que d'attendre l'echeance : l'ecart se lit au fil des mois.
Elle compare les heures payees par la mensualisation, augmentees des heures
complementaires et majorees deja reglees, aux heures relevees au calendrier. La
difference est valorisee au taux horaire moyen de la periode.

Une alerte remonte dans le centre de notifications quand l'anniversaire approche
a moins de trente jours.

**L'application ne tranche pas.** Elle affiche l'ecart et son montant indicatif,
rappelle que la mensualisation reste due meme si les heures relevees sont
inferieures, et renvoie vers le Relais Petite Enfance avant tout versement.

## Correctif 0.9.10 — l'application tombait a la connexion

Cause : apres la connexion, l'application demandait a Firebase d'enregistrer
l'appareil. Sans `google-services.json` dans l'APK, Firebase n'est pas
initialise et cet appel arrete le processus natif. Ce n'est pas une erreur
JavaScript, rien n'est attrapable depuis le code web : l'application se ferme.

Correction : un drapeau `PROJET.notifications`, faux par defaut. Le workflow ne
le passe a vrai que dans l'etape qui a effectivement depose
`google-services.json`. Tant qu'il est faux, l'application ne sollicite jamais
Firebase.

Verifie au test : connexion reussie, zero appel au module de notifications.

## L'adresse du projet livree avec l'application

Deux secrets facultatifs, `SUPABASE_URL` et `SUPABASE_ANON_KEY`. Quand ils
existent, le workflow les inscrit dans les deux applications avant la
compilation : il ne reste alors qu'une adresse e-mail et un mot de passe a
saisir. Sinon les champs restent disponibles sous « Projet Supabase ».

La cle « anon » est publique par conception. Passer par un secret evite
simplement de la commiter.

## Premier lancement

**Cocon Nounou** s'ouvre sur l'ecran de connexion tant qu'aucun compte n'est
actif : toutes ses donnees viennent du serveur, un accueil vide sans explication
n'aurait aucun sens.

**Cocon Parent** ne demande rien. Fiches, calculs, PDF, sauvegardes : tout
fonctionne sans compte. La connexion ne sert qu'au partage, et l'imposer
casserait l'usage principal.

## 1.0.0 — refonte

### Cocon Parent

**Connexion obligatoire.** Une porte d'entree a l'ouverture, sans compte on
n'entre pas. La session vaut huit heures ; au-dela, le mot de passe est
redemande. Entre deux, le verrou local par code ou empreinte protege l'appareil.

**Dashboard en tuiles.** Journal du jour avec l'humeur de l'enfant, galerie,
messages, retard, demandes. Puis la progression du mois.

**Barre du bas personnalisable.** Quatre emplacements autour d'un bouton « + »
qui ouvre le volet de tous les modules. Un appui long sur un module le place
dans la barre. Le choix est conserve.

**Le Dossier fait foi.** Famille, salariee, enfant s'y saisissent ; chaque fiche
les reprend et une modification se repercute sur le mois affiche. Les champs de
la saisie deviennent un simple miroir.

**Mes nounous.** L'ancien « Partage avec la salariee », au meme endroit :
publication du contrat, code et QR d'invitation, synchronisation, retrait.

**Co-parent.** Dossier -> Ma famille -> Inviter le co-parent. Un code et un QR ;
il cree son compte dans Cocon Parent, saisit le code, et voit tout ce que tu
vois. Deux parents maximum par contrat, verifie par la base.

**Retard.** Cinq boutons : 15, 30, 45 minutes, une heure, plus. La nounou est
notifiee aussitot, et le retard apparait sur son ecran du jour.

**Demandes.** Ce qu'elle demande, tu l'acceptes ou le refuses avec un motif
qu'elle voit. La base l'empeche de decider elle-meme.

### Cocon Nounou

Session de huit heures, comme le parent. Demandes de materiel depuis l'onglet
Messages, avec le suivi des reponses. Humeur de fin de journee avec des visages.
Retards des parents affiches sur Aujourd'hui.

### Base

`008-a-011-tout.sql` : co-parent, invitation par l'une ou l'autre partie,
demandes, retards, pointage arrivee / depart, accuse de lecture des messages.

### Pointage et presences

Cocon Nounou, ecran Aujourd'hui : un bouton « Arrive » puis « Parti » par enfant.
L'heure est notee, le parent recoit une notification, et la base en deduit les
heures reelles. Ces deux colonnes appartiennent a la nounou : un envoi du parent
ne peut pas les ecraser.

Cocon Parent, module Presences : les trois dernieres semaines, avec l'ecart
entre prevu et reel jour par jour.

### Ma semaine

Cocon Parent, module Ma semaine : humeur la plus frequente, journees notees,
repas, heures de presence, photos, demandes, et les mots de la nounou. Un rappel
arrive le dimanche a 19 h.

### Charte 1.0

Fond legerement chaud, cartes qui flottent, heros avec des halos, boutons en
relief, entree en cascade des blocs, tuiles colorees par module, barre du bas
avec pastille et petit saut de l'icone, volets qui glissent avec un leger
ressort, etats vides dessines. Tout est desactive en mouvement reduit.

## Quand l'invitation est refusee

Message typique : *new row violates row-level security policy for table
"invitations"*.

**Cause principale, corrigee en 1.0.0.** La table `invitations` n'a
volontairement aucune regle de lecture : un compte capable de lister les codes
pourrait rejoindre le contrat de n'importe qui. Mais le client demandait a
PostgREST de lui renvoyer la ligne inseree. Postgres devait donc la relire,
n'y parvenait pas, et refusait l'ecriture entiere — en accusant la regle
d'ecriture, qui n'y etait pour rien.

Le client envoie desormais `Prefer: return=minimal` sur les tables sans lecture,
`invitations` et `jetons_push`.

**Autre cause possible.** Le contrat n'existe plus cote serveur, ou appartient a
une autre adresse e-mail. Attention : l'editeur SQL de Supabase tourne en role
privilege, ou `auth.uid()` vaut NULL et les regles d'acces ne s'appliquent pas.
Voir un contrat dans le tableau de bord ne signifie donc pas que l'application
peut le voir.

L'application le detecte desormais seule. La carte « Mes nounous » affiche
« Contrat en ligne : introuvable », explique pourquoi, et propose **Oublier ce
lien et republier**. Rien n'est perdu : les fiches, les calculs et les
sauvegardes vivent sur le telephone, pas sur le serveur.

Pour verifier soi-meme, dans l'editeur SQL :

```sql
select c.id, c.enfant_prenom, c.statut,
       e.email as compte_employeur,
       s.email as compte_salariee
  from contrats c
  left join auth.users e on e.id = c.employeur_id
  left join auth.users s on s.id = c.salariee_id;
```

`compte_employeur` doit etre l'adresse avec laquelle tu es connecte dans Cocon
Parent. Si c'en est une autre, l'application ne verra jamais ce contrat.

## L'accuse de lecture ne tenait pas

Trouve par un controle systematique, pas en s'en apercevant a l'usage : pour
chaque table, comparer ce que les applications font a ce que les regles
autorisent.

`messages` n'avait aucune regle de modification. L'application marquait les
messages comme lus, PostgREST ne mettait a jour aucune ligne, et n'en disait
rien. La pastille des non-lus serait revenue a chaque ouverture, indefiniment,
sans aucun message d'erreur.

La regle existe desormais, mais un declencheur n'accepte que le champ `lu_le` :
personne ne peut reecrire le texte d'un message recu, changer son auteur, ni
retirer un accuse deja pose. Marquer comme lu ne vaut que pour ce qu'on n'a pas
ecrit soi-meme.

### Le controle

Il vaut la peine d'etre rejoue apres chaque ajout de table :

```
pour chaque table ecrite par une application
  si l'operation utilisee n'a pas de regle correspondante  -> faille silencieuse
  si INSERT sans regle de lecture et relecture demandee    -> ecriture refusee
```

C'est ce controle qui a trouve les deux bugs de la 1.0.0, celui des invitations
et celui-ci.

## Mettre a jour le depot depuis un telephone

Deposer une arborescence complete demande un ordinateur : le glisser-deposer
n'existe pas sur mobile, et GitHub ne decompresse pas les archives.

Le workflow **Extraire une archive** contourne cela. Deposer un seul fichier
fonctionne depuis un telephone, et le reste se fait cote serveur.

1. Depot -> Add file -> Upload files -> deposer `cocon-vX.Y.Z.zip` a la racine.
2. Onglet Actions -> « Extraire une archive » -> Run workflow.
3. Il extrait, retire le dossier racine `cocon/`, remplace les dossiers
   concernes, supprime le zip et commite.

Deux points a connaitre.

**Les workflows ne sont jamais remplaces.** Le jeton fourni aux actions n'a pas
le droit de modifier `.github/workflows` : GitHub refuse le push. Le dossier
est donc ignore, et le resume de l'execution le signale. Si `build-apk.yml` a
change, il faut le mettre a jour a la main — c'est rare.

**Seuls les dossiers presents dans l'archive sont remplaces.** Ce qui existe
dans le depot mais pas dans le zip reste en place. Aucun risque d'effacer un
fichier qu'on avait ajoute de son cote.

**Prealable** : Settings -> Actions -> General -> Workflow permissions ->
« Read and write permissions ». Sans cela, le commit final echoue.

## 1.0.1 — refonte des ecrans

### Cocon Parent

**Une page par module.** Journal, galerie, messages, demandes, ma semaine,
presences, mes nounous, fiche d'urgence, conges, documents, fermetures : chacun
a son ecran, avec son titre. Le Dossier ne garde que le contractuel, celui qui
alimente la saisie : ma famille, salariee, enfants, planning type, contrat,
avenants, notes.

Techniquement, les cartes vivent dans une reserve masquee et sont deplacees dans
la page a l'ouverture. Un seul balisage, un seul rendu, pas de duplication.

**Roue de chargement.** Le bouton de connexion se vide et tourne, une ligne
centree annonce l'etape en cours. Plus de texte de travers.

### Cocon Nounou

**Ecran de connexion**, comme le parent, avec la meme roue et la session de huit
heures.

**Familles.** La liste d'abord, avec le nombre et le rythme hebdomadaire de
chaque enfant. La carte « Rejoindre » se replie des qu'une famille est reliee, et
respecte ensuite les ouvertures manuelles.

**Reglages refondus.** Un en-tete de profil avec initiale et adresse, des
interrupteurs a glissiere pour la securite, un selecteur de theme a trois
positions. La connexion au projet passe dans une carte repliee, reservee au
depannage.

**Planning sur les horaires du contrat.** Le pointage arrivee / depart est
retire : c'est l'horaire prevu qui fait foi pour la paie, meme en cas de retard.
L'ecran du jour montre le creneau et sa duree, le mois affiche les creneaux
habituels, et les exceptions saisies par le parent priment.

## 1.0.2 — l'exoneration etait soustraite

L'exoneration des heures complementaires et majorees est un **report** : les
cotisations allegees sur ces heures reviennent a la salariee. Elle s'ajoute donc
au net, elle ne s'en retire pas.

Le moteur la soustrayait. Le libelle de la fiche A4 disait pourtant deja
« Report du montant de l'exoneration au titre des heures complementaires et / ou
majorees », juste avant « SALAIRE NET en tenant compte de l'exoneration ».

Consequence : toutes les fiches ou une exoneration etait saisie affichaient un
net trop bas, du double du montant saisi. Sur 12,40 € d'exoneration, l'ecart est
de 24,80 €.

**A verifier de ton cote** : rouvre les mois deja etablis ou tu avais saisi une
exoneration, et compare le net a ton decompte Pajemploi. Si un versement a deja
ete fait sur l'ancien calcul, il manque la difference.

## 1.0.3 — retouches

**L'ecran de lancement se retirait trop tot.** Il partait avant que
l'application sache s'il fallait afficher le tableau de bord ou la connexion :
on apercevait l'un une fraction de seconde avant l'autre. Il reste desormais
au-dessus jusqu'a ce que la destination soit connue.

**Quitter une famille**, cote nounou. La regle d'acces l'en empechait : une fois
la famille reliee, les termes du contrat appartiennent a l'employeur. Une
fonction dediee, `quitter_contrat`, lui permet de se retirer sans dependre de
lui. Le contrat repasse en attente, la famille peut inviter quelqu'un d'autre,
et rien n'est efface.

**Selecteur d'enfant** en tete des ecrans Journal et Messages, quand plusieurs
familles sont reliees. Il n'apparait pas s'il n'y en a qu'une.

**Mise en forme des demandes et des besoins.** Un besoin s'affiche avec son
emoji, un chapeau « Il manque » et l'objet en gras, plus « Il manque : couches »
en texte brut. Les retards ont leur propre couleur. Les demandes de materiel
montrent leur etat par une pastille : en attente, acceptee, refusee avec le
motif en rouge.

`012-quitter-contrat.sql` est a executer.

## 1.0.4

**Un nouveau mois reprend le precedent.** Horaires, tarifs, quantites
d'indemnites : tout est repris, et le calendrier est **regenere depuis les
horaires du contrat** plutot que recopie jour par jour. Recopier decalerait
tout, les jours de la semaine ne tombant pas aux memes dates. Les feries sont
sautes, les quantites d'indemnites suivent le nouveau nombre de jours.

Ne se reprennent jamais : le salaire net, les acomptes, les heures
complementaires, les absences. Une absence est par nature exceptionnelle.

Un reglage permet de repartir a vide : Parametres -> Banniere -> « Commencer
chaque mois a vide ».

**Motifs d'absence.** Maladie, conges, jour non travaille, ecole, formation,
autre. Le motif apparait dans la case du calendrier, dans le recapitulatif des
absences, et dans le message pre-rempli : « Elii sera absent le 2 octobre 2026
pour maladie. »

**Corrige** : la tuile du journal collait son titre a son sous-titre.

### Trois bugs trouves en testant

`base` etait declare dans une branche et utilise en dehors : toute creation de
mois levait une erreur qui tuait le demarrage de l'application.

`MOTIFS` s'etait glisse dans le moteur de calcul, a l'interieur d'un bloc, donc
invisible depuis l'application : les motifs ne s'affichaient jamais.

L'ecran de lancement passait au-dessus de l'ecran de connexion sans jamais lui
ceder la place quand le demarrage echouait.

### Audit

Syntaxe des deux applications, identifiants references mais absents, tables et
colonnes appelees contre le schema, regles d'acces manquantes, pages de modules
sans carte : aucun ecart.

## 1.0.5

### Modules regroupes en pages a onglets

Dix-neuf entrees, c'etait trop. Cote parent, deux familles de modules :

- **Au quotidien** : journal, galerie, messages, demandes, ma semaine, espace
  commun.
- **Le contrat** : mes nounous, urgence, presences, fermetures, conges,
  documents.

Chaque page porte une barre d'onglets ; on passe de l'un a l'autre sans revenir
en arriere. Le volet « + » range les modules par groupe, avec le salaire et
l'application a part. On peut toujours epingler un onglet precis dans la barre
du bas.

### L'espace commun

Les tables existaient depuis le premier fichier SQL. L'interface arrive.

**Cote nounou**, onglet Commun. Elle ouvre l'espace en un geste ; chaque
famille reliee recoit une invitation. Elle publie des annonces par categorie :
maladie, fermeture, sortie, info. Rien n'est publie automatiquement.

**Cote parent**, onglet Espace commun dans « Au quotidien ». L'invitation
s'affiche avec ce que les autres verront — le prenom de l'enfant et ce qu'on
ecrit, rien d'autre — et deux boutons, rejoindre ou pas maintenant. Une fois
membre : les prenoms des autres familles, les annonces, et la possibilite d'en
publier. Quitter est possible a tout moment.

Teste de bout en bout : la nounou ouvre, invite deux familles, publie une
alerte varicelle ; le parent recoit l'invitation, accepte, lit l'alerte, repond.

## 1.0.6

### Mode silencieux

Parametres -> Mode silencieux. Couper le quotidien le week-end, ou sur une
periode : journal, photos, messages et demandes se taisent. L'urgent passe
toujours — fiche d'urgence modifiee, alerte maladie de l'espace commun.

Le reglage est enregistre sur le profil serveur, et c'est **la fonction
d'envoi** qui l'applique. Un filtre sur le telephone ne servirait a rien : la
notification arriverait quand meme. La fonction calcule le week-end a l'heure
de Paris, celle du destinataire, pas celle du serveur.

`013-mode-silencieux.sql` ajoute les trois colonnes ; la fonction `notifier`
est a redeployer.

### Tour guide

Trois ecrans apres la premiere connexion : le bouton « + », l'appui long, le
quotidien sur l'accueil. Une seule fois ; « Revoir la presentation » dans A
propos pour le relancer. Le bouton retour d'Android le ferme.

### Corrige

Le numero de version affiche dans A propos etait reste a 0.9.8 : ma mise a jour
cherchait un ancien numero qui n'y etait plus. Il est desormais remplace quel
que soit son contenu.

## 1.0.7 — retirer l'acces de la nounou

Deux defauts, dont un qui masquait l'autre.

**La carte ne disait jamais si une nounou etait reliee.** « Contrat en ligne :
publie », avant comme apres le retrait. Quoi que fasse la base, l'ecran ne
bougeait pas. Elle affiche desormais « en attente d'une nounou » ou « nounou
reliee », et les boutons suivent : code d'invitation dans le premier cas,
retrait dans le second.

**Le retrait ne verifiait pas son resultat.** PostgREST ne se plaint pas quand
une regle d'acces bloque une mise a jour : il ne modifie aucune ligne et repond
normalement. L'application affichait « Acces retire » sans rien avoir retire.
Elle lit maintenant la reponse : aucune ligne modifiee donne un message clair,
et la nounou encore presente aussi.

Le contrat revient en **attente** plutot qu'en « termine » : le parent peut
inviter quelqu'un d'autre sans republier.

Cote nounou, la liste des familles filtre en plus sur son propre identifiant,
et l'enfant affiche bascule si celui qu'elle regardait a disparu.

Si le message « la base n'a rien modifie » apparait chez toi, la cause est
ailleurs que dans l'application : le contrat n'est pas rattache au compte
connecte. La requete du README, section « Quand l'invitation est refusee », le
montre.

## 1.0.8 — le lien survit a une reinstallation

**Cote nounou**, rien a faire : tout est sur le serveur, elle se reconnecte et
ses familles reviennent.

**Cote parent**, le lien avec la nounou n'etait qu'un identifiant garde sur le
telephone. Apres reinstallation, l'application ne le connaissait plus, proposait
« Publier ce contrat », et creait un doublon — la nounou restait reliee a
l'ancien.

Desormais, a chaque connexion et a chaque demarrage, l'application redemande
ses contrats au serveur et les rattache aux enfants du telephone : par prenom si
un enfant sans lien porte le meme, sinon en reutilisant l'enfant vide du
premier lancement, sinon en creant l'enfant. « Publier » verifie aussi avant de
creer : si le contrat de cet enfant existe deja, il est rattache.

Teste : telephone vierge, deux contrats sur le serveur, les deux reviennent
avec prenom et date de naissance, aucun doublon.

**Ce qui ne revient pas** : les fiches de salaire, les calculs, les
sauvegardes. Ces donnees ne vivent que sur le telephone, c'est voulu. Pour les
retrouver apres reinstallation, importer la sauvegarde JSON depuis Parametres.
Le journal, les photos, les messages et la fiche d'urgence, eux, sont sur le
serveur et reviennent seuls.

## 1.0.9 — verification complete

### Ce qui ne tenait plus debout

**Les photos du fil de messages etaient refusees.** Depuis l'evolution 007, la
regle de stockage exige que le dossier d'une photo soit l'identifiant d'une
ligne de `photos`. Le bouton « Ajouter une photo » du fil envoyait encore dans
un dossier nomme d'apres le contrat : refus silencieux a chaque fois. Il passe
desormais par le meme chemin que la galerie, et poste en plus la photo dans la
conversation. Un seul chemin pour les photos.

**Le module Presences lisait un pointage que plus personne n'ecrivait.** Le
pointage arrivee / depart a ete retire cote nounou en 1.0.1 ; le module etait
reste, toujours vide. Retire. « Ma semaine » compte les heures d'accueil
prevues, pas plus un pointage inexistant.

**Refus de photo sans explication.** Quand le parent n'a pas encore rempli la
fiche d'urgence, aucune photo n'est autorisee, et la nounou voyait un message
vague. Elle lit maintenant : « Le parent n'a pas encore autorise les photos dans
la fiche d'urgence. »

### Menu

Deux fonctions mortes retirees, un identifiant en double dans le logo anime
renomme, la requete des jours allegee des colonnes qui ne servaient plus.

### Ajouts

**« Je serai en retard »**, cote nounou : quatre boutons, toutes les familles
attendues aujourd'hui sont prevenues d'un coup. Le miroir de ce que le parent a
deja.

**L'etat de la fiche du mois**, dans la fiche de l'enfant cote nounou : en
preparation, envoyee, salaire verse. Elle sait ou en est sa paie sans demander.

### Audit

Syntaxe, identifiants en double, references sans element, fonctions jamais
appelees, chemins de stockage contre la regle, colonnes du schema jamais
utilisees. Restent inutilisees : `profils.telephone` et la table `support`,
prevue pour un acces d'assistance qui n'est pas construit. Sans consequence.

## 1.0.10

**La fonction `notifier` ne reconnaissait pas le co-parent.** Elle testait
seulement `employeur_id` : pour un co-parent, le destinataire calcule etait
l'employeur, donc sa propre notification lui revenait au lieu d'aller a la
nounou. Corrige dans le depot ; redeployer la fonction.

Le reste est inchange depuis 1.0.9.

### Rappel de l'ordre pour les notifications

1. `013-mode-silencieux.sql` dans l'editeur SQL
2. Secret `FCM_COMPTE_SERVICE` dans Edge Functions -> Secrets
3. Fonction `notifier`, nom exact, contenu de `supabase/functions/notifier/index.ts`
4. Secrets GitHub `GOOGLE_SERVICES_PARENT` et `GOOGLE_SERVICES_NOUNOU`
5. Compiler : l'etape « Brancher les notifications Firebase » doit afficher
   « Notifications Firebase activees »
6. Installer, se connecter, accepter l'autorisation Android
7. Verifier que `jetons_push` contient une ligne par appareil

## 1.0.11 — il n'y avait aucune boucle de rafraichissement

Les deux applications ne rechargeaient leurs donnees qu'au changement d'ecran.
Un message envoye n'apparaissait donc chez l'autre qu'en naviguant, et une
notification pouvait arriver sans que l'ecran derriere bouge. L'impression de
latence venait de la : rien n'attendait les nouveautes.

Trois declencheurs desormais :

- **Une boucle de vingt secondes**, active seulement quand l'application est
  visible. En arriere-plan, rien n'est interroge : pas de batterie gaspillee.
- **Le retour au premier plan**, immediat.
- **La reception d'une notification**, immediate elle aussi : l'ecran est a jour
  avant meme qu'on ait fini de lire la banniere.

Un verrou empeche deux rafraichissements simultanes, et un delai minimal de huit
secondes evite de marteler le serveur quand on navigue vite.

Teste : un message depose cote serveur apparait seul en moins de vingt-trois
secondes, pastille comprise ; un second apparait en une seconde apres un retour
au premier plan.

**Ce que cela ne remplace pas.** Les notifications restent le seul moyen d'etre
prevenu application fermee. La boucle sert a ce qu'on voie la meme chose des
qu'on ouvre.

## 1.0.12 — les notifications partaient avec un jeton perime

L'onglet Invocations de la fonction montrait des `401` sur chaque POST : la
passerelle refusait l'appel avant meme que le code s'execute.

Cause : le jeton d'acces ne vaut qu'une heure, la session huit. Les appels aux
tables passent par un enveloppeur qui rafraichit et rejoue en cas de 401 ;
l'appel a la fonction, lui, partait en `fetch` brut, sans rien de tout cela.
Passe la premiere heure, plus aucune notification.

Corrige : le jeton est rafraichi d'avance s'il arrive a echeance dans les deux
minutes, et un 401 declenche un rafraichissement puis un second essai. Teste
avec un serveur qui refuse le premier jeton : l'appel est rejoue et aboutit.

La fonction journalise desormais chaque etape, ce qu'elle ne faisait pas :
les logs ne montraient que des demarrages de conteneur, sans jamais dire
pourquoi un envoi n'aboutissait pas.

## 1.0.13 — la chaine des notifications se diagnostique elle-meme

Je ne peux pas executer l'APK. Plutot que de deviner ou ca casse, l'application
le dit : Reglages -> Notifications, dans les deux applications.

Cinq lignes, un maillon chacune. La premiere en rouge est le coupable :

| Ligne | Si elle est rouge |
| --- | --- |
| Firebase dans l'application | l'APK a ete compile sans les secrets `GOOGLE_SERVICES_*` |
| Module de notifications | le module n'est pas dans l'APK : voir l'etape « Ajouter le module » du build |
| Autorisation Android | refusee : Reglages Android -> Applications -> Cocon -> Notifications |
| Jeton de l'appareil | Firebase n'a pas repondu : nom de package faux, ou `google-services.json` illisible |
| Jetons deposes pour ce compte | la base a refuse le depot : voir la regle sur `jetons_push` |

Sous les lignes, la derniere etape atteinte en toutes lettres.

**« M'envoyer une notification de test »** appelle la fonction avec `test: true` :
elle envoie a l'appelant lui-meme, sans contrat ni tiers, et ignore le mode
silencieux. La reponse s'affiche telle quelle. Si elle dit « Envoye a 1
appareil » et que rien n'arrive, le probleme est sur le telephone — economiseur
de batterie, ou APK installe different de celui compile.

**« Reessayer l'enregistrement »** relance la demande a Firebase sans se
reconnecter.

La fonction `notifier` est a redeployer : elle comprend desormais le mode test.

Corrige au passage cote nounou : l'enregistrement etait demande avant la
verification de session, donc parfois jamais. Il vient apres, une fois connectee.

## 1.0.14 — le nouveau format de cle Supabase

Le diagnostic a rendu la cause en clair : la passerelle des fonctions refuse
l'ancienne cle `anon` (un JWT en `eyJ...`) et exige le nouveau format
`sb_publishable_...`. La base de donnees accepte encore l'ancienne, ce qui
expliquait que tout marche sauf les notifications.

A faire : Project Settings -> API Keys -> copier la cle **publishable**, et la
mettre a la place de l'ancienne dans `commun/projet.js` puis dans les deux
`index.html` — ou dans le secret GitHub `SUPABASE_ANON_KEY`, que le workflow
injecte. Elle vaut pour tout : base, authentification, fonctions.

## 1.0.15 — l'icone de notification

Android n'affiche pas l'icone de l'application dans la barre d'etat : il exige
une **silhouette monochrome**, dont il ne garde que la transparence avant de la
teinter lui-meme. Sans elle, il reduit l'icone coloree a un rond blanc.

Une icone dediee est desormais dessinee aux cinq densites, `ic_stat_cocon` :
le cocon en cadre, la pousse a deux feuilles au centre, lisible a 24 pixels.
Le script `android-extra/icone-notification.py` la declare dans le manifeste au
moment de la compilation, avec une couleur de teinte prise dans la
configuration : vert d'eau pour Cocon Parent, rose poudre pour Cocon Nounou.

Le script est idempotent et verifie la presence de la balise `</application>`
avant d'ecrire. Teste sur un faux projet : manifeste et ressource couleur
valides apres une execution comme apres deux.

## 1.0.16

### Retirer n'importe quel enfant

Le premier enfant etait indeboulonnable. C'etait une facilite de ma part : ses
fiches sont les seules sans suffixe dans les cles, et je n'avais pas voulu
traiter le cas. Rien ne le justifiait.

Tout enfant peut maintenant partir, tant qu'il en reste un. Ses fiches sont
supprimees avec lui — sinon elles resteraient sans proprietaire, invisibles et
encombrantes. Le nombre de fiches concernees est annonce avant confirmation.

Le libelle sous chaque nom disait « Premier enfant » ou « Fiches separees », ce
qui ne renseignait sur rien. Il dit desormais si l'enfant est relie a la nounou.

### Supprimer le contrat en ligne

Dans Mes nounous, sous un intitule « Fin de la relation » qui rappelle d'abord
qu'un contrat qui s'acheve vraiment passe par **Documents -> Fin de contrat** :
preavis, conges payes, indemnite de rupture. Le bouton de suppression est fait
pour effacer un essai, et le dit.

Deux confirmations, la seconde renvoyant explicitement vers Fin de contrat. La
suppression emporte tout ce qui depend du contrat cote serveur — jours, mois,
messages, journal, photos, invitations — pour les deux parties. Les fiches de
salaire, elles, vivent sur le telephone et ne sont pas touchees.

### Les suppressions se verifient

Meme defaut que pour le retrait d'acces : `Prefer: return=minimal` ne renvoyait
rien, donc aucun moyen de savoir si une regle d'acces avait bloque l'operation.
Les suppressions demandent desormais les lignes supprimees, sauf sur les tables
sans regle de lecture ou cette demande ferait echouer l'operation entiere.

## 1.1.0

`014-contacts-siestes-portraits.sql` est a executer.

### Joindre les parents

La fiche d'urgence ne donnait que le medecin. Elle commence desormais par
**qui joindre, dans l'ordre** : mere, pere, grand-parent, autant de lignes que
voulu, chacune avec son role. Cote nounou, ce sont des boutons d'appel : un
appui, le telephone compose.

Le numero de l'employeur, saisi une fois dans Dossier -> Ma famille, apparait
aussi. Il est masque s'il figure deja dans les contacts, pour ne pas afficher le
meme numero deux fois.

### Siestes multiples

Un bebe en fait deux ou trois. Autant de lignes qu'il en faut, chacune avec sa
duree calculee en direct. Les journees deja saisies avec une sieste unique sont
reprises par la migration ; les deux anciennes colonnes gardent la premiere
sieste, rien n'est perdu.

### Un vrai module photo

Onglet **Photos** cote nounou. Deux boutons : prendre une photo avec l'appareil,
ou en choisir plusieurs d'un coup dans la pellicule. Les photos sont regroupees
par mois. Un appui ouvre la visionneuse, avec navigation et suppression.

### Portraits

Huit frimousses dessinees — renard, koala, lapin, ourson, chaton, poussin,
grenouille, hibou — ou une vraie photo prise depuis l'application. Tant que
rien n'est choisi, chaque enfant recoit une frimousse stable tiree de son
prenom : le meme prenom donne toujours le meme animal.

C'est la nounou qui pose le portrait, souvent elle qui prend la photo. Un
declencheur limite ce qu'elle peut modifier sur le contrat : le portrait, rien
d'autre.

### Centre de notifications cote nounou

Comme chez le parent, une cloche en haut a droite. Ce qui demande son
attention : familles manquantes, messages non lus, retards annonces, demandes
refusees, journal du jour non rempli passe seize heures, notifications
inactives. Un point rouge quand quelque chose presse.

## 1.1.1 — une vraie messagerie cote nounou

Le selecteur d'enfant en tete de l'ecran Messages supposait qu'on sache deja ou
chercher. Avec trois familles, un message pouvait attendre des heures dans un fil
qu'on ne regardait pas.

**Une boite de reception.** Chaque famille est une conversation : portrait de
l'enfant, dernier message, heure, pastille des non-lus. Le total apparait en
tete de carte. Ce qui attend se voit d'un coup d'oeil.

**L'espace commun y figure comme une conversation**, epinglee en premier. Meme
allure, meme fil, meme champ de saisie — sauf que le message part vers toutes
les familles membres. Les actions du quotidien y sont masquees : on ne signale
pas un manque de couches a tout le monde.

**Une conversation ouverte** montre le fil, un champ, et quatre actions rangees
sous lui : photo, il manque, demander, retard. Chacune deplie son volet a la
demande, au lieu des quatre cartes empilees en permanence.

Le bouton retour d'Android ferme la conversation avant de quitter l'ecran.

Teste : trois conversations dont l'espace commun, deux non-lus comptes
correctement, ouverture, volet, retour, et le fil du commun avec ses actions
masquees.

## 1.1.2

### La barre du bas cote nounou

Sept entrees, c'etait trop. Meme dispositif que chez le parent : quatre
emplacements autour d'un « + » qui ouvre les huit ecrans. Un appui long en
epingle un dans la barre, le choix est conserve. La pastille des messages non
lus remonte dans la barre.

### Une vraie conversation

Ce que j'ai repris de la messagerie classique :

- **Des bulles**, a droite ce qu'on ecrit, a gauche ce qu'on recoit. Un fil se
  lit d'un coup d'oeil, la ou une liste plate demande de dechiffrer « moi » ou
  « le parent » a chaque ligne.
- **Du plus ancien au plus recent**, avec descente automatique en bas. C'est le
  sens d'une conversation ; l'ordre inverse convient a une boite, pas a un fil.
- **Des separateurs de jour** — aujourd'hui, hier, puis la date — au lieu de
  dater chaque ligne.
- Les besoins et les retards gardent leur couleur et leur chapeau dans la bulle.

Ce que je n'ai pas repris, et pourquoi :

- **Pas d'accuse de lecture par message.** La pastille des non-lus suffit. Des
  petites coches diraient « elle a vu et n'a pas repondu », ce qui cree une
  tension inutile entre deux personnes qui se voient tous les jours.
- **Pas d'indicateur de frappe.** Il demanderait une connexion permanente, et
  installerait une attente de reponse immediate. Un mot depose le matin peut
  attendre le soir.

Les deux applications affichent le meme fil.

## 1.1.3 — « la famille » plutot que « le parent »

Depuis que le co-parent existe, un contrat peut avoir deux parents. Toutes les
formulations qui en supposaient un seul etaient fausses des qu'ils sont deux :
« Un mot au parent », « Un appui envoie la demande au parent », « Autorise par
le parent », « Le parent te donne ce code ».

Elles parlent desormais de **la famille**. Quinze formulations revues cote
nounou, deux cote parent.

Restent au singulier les endroits ou c'est juridiquement exact : « le parent
employeur » designe la personne qui signe le contrat et verse le salaire, meme
si un co-parent l'accompagne.

## 1.1.5 — six correctifs

**Les pastilles de messages ne partaient jamais.** `marquerMessagesLus` existait
cote parent mais n'etait appelee nulle part, et la nounou n'en avait pas du
tout. Ouvrir un module ou une conversation vaut desormais lecture.

**Photo et Frimousse se chevauchaient**, et « Prendre une photo » ne
declenchait rien. Les champs de fichier etaient enveloppes dans des `label`,
ce qui echoue dans une WebView Android selon la mise en page. Des boutons
declenchent maintenant le champ explicitement, aux trois endroits concernes.

**Notifications envoyees au mauvais appareil.** La fonction se fiait au seul
filtre `.eq('personne_id', ...)`. Elle verifie desormais chaque jeton en
memoire avant l'envoi, et journalise l'ecart s'il y en a un. Envoyer a la
mauvaise personne serait pire qu'un envoi manque.

Un jeton n'est plus supprime sur un simple code 400 : seuls un 404 ou un refus
explicite de Firebase le retirent. Un 400 peut venir d'une charge mal formee, et
supprimait des jetons valides — ce qui expliquait les notifications
parent vers nounou perdues apres un essai.

**Deux ecrans de lancement.** Celui d'Android, puis le mien. Le mien est retire
des que l'application tourne sous Capacitor, et la configuration reduit la duree
du natif.

**Retirer un enfant laissait un contrat orphelin** : la nounou continuait de le
voir, le parent n'y accedait plus. La suppression se fait maintenant dans
l'ordre — acces de la nounou, contrat en ligne, puis l'enfant — et s'arrete si
une etape echoue plutot que de continuer a moitie.

**Et pour reparer l'existant** : Mes nounous detecte les contrats en ligne sans
enfant correspondant, les nomme, et propose de les supprimer.

La fonction `notifier` est a redeployer.

## 1.2.0

`015-absences.sql` est a executer.

### Trois correctifs

**Les bannieres restaient apres ouverture de l'application.** Elles sont
retirees a chaque retour au premier plan, meme sans avoir clique dessus :
ouvrir l'application vaut prise de connaissance.

**« Prendre une photo » ouvrait le selecteur de fichiers.** Un champ de fichier
avec `capture="environment"` n'ouvre pas l'appareil quand il est declenche par
script : Android retombe sur le selecteur. Le module appareil photo natif est
desormais utilise, le champ restant le recours quand il n'est pas disponible.

**« Il manque : lait » etait du texte brut.** La nounou envoie maintenant une
phrase : « Il manque du lait pour Elio », articles compris — du lait, des
couches, de l'eau, une tenue de rechange. La notification porte le prenom en
titre et la phrase en corps.

### Module absences

Sept types, chacun avec ses regles :

| Type | Prevenance | Motif | Justificatif |
| --- | --- | --- | --- |
| Conges, Formation | deux semaines | facultatif | non |
| Conge maternite | un mois | obligatoire | oui |
| Maladie, Accident du travail | aucune | obligatoire | oui |
| Urgence | aucune | obligatoire | non |
| Jour ferie | aucune | facultatif | non |

Le delai **previent sans interdire** : declarer des conges dans six jours
affiche « il reste 6 jours alors que 14 sont attendus », et laisse passer si on
confirme. Une convention n'est pas un verrou, et une absence tardive reste
parfois inevitable.

Les absences qui l'exigent affichent « Justificatif a joindre » tant qu'il
manque. Le trombone ouvre l'appareil ou les fichiers ; l'arret de travail
emprunte le chemin des photos, donc les memes regles d'acces.

Cote parent, chaque absence montre son type, son motif, le justificatif s'il
existe, et un bouton « J'ai bien note ». Un declencheur limite le parent a ce
seul accuse : il ne peut ni changer les dates ni retirer l'absence.

## 1.3.0

`016-remplacement-adaptation-reprise.sql` est a executer.

### Remplacement temporaire

Une nounou malade, une collegue prend le relais trois jours. Lui ouvrir le
contrat entier serait excessif ; ne rien lui donner la laisserait aveugle.

La titulaire cree un code date. Le remplacant le saisit et voit **le planning,
la fiche d'urgence et le journal**, sur la periode seulement. Ni contrat, ni
salaire, ni historique. L'acces expire seul : la regle d'acces verifie
`current_date between du and au`, sans que personne ait a y penser.

### Adaptation

L'arrivee d'un tout-petit se fait par paliers : une visite, une heure, une
matinee, avec le repas, avec la sieste, la journee entiere. La nounou note
chaque etape et son ressenti ; le parent ajoute le sien dessous.

**Chacun n'ecrit que le sien** : un declencheur restaure le champ de l'autre a
chaque ecriture. On peut lire ce que l'autre a ressenti, jamais le reecrire.

C'est le moment le plus anxieux pour des parents, et celui ou personne ne leur
dit rien.

### Reprise apres absence

Apres deux semaines, elle retrouve un enfant qui a change. Le parent ecrit ce
qui s'est passe — nouveaux mots, nouvelles habitudes ; la carte s'ouvre d'
elle-meme cote nounou tant que la transmission n'est pas lue.

### Archive du contrat

Quand tout s'arrete, un dossier a garder : identites, contrat, fiches de
salaire, journal, adaptation, transmissions, et **les photos telechargees**.
Un lien vers le serveur ne vaudrait rien le jour ou le contrat n'existe plus.

Trois ans de la vie d'un enfant ne devraient pas disparaitre avec un contrat.

## 1.3.1 — les photos orphelines

Le bucket contenait des dossiers, les fichiers etaient bien la, et l'application
n'affichait rien. Cause : l'ordre des operations.

`envoyerGalerie` creait la ligne photo, **deposait le fichier**, puis tentait le
lien vers la famille. Or le declencheur `verifier_autorisation_photo` refuse ce
lien tant que le parent n'a pas coche « photos » dans sa fiche d'urgence. Le
fichier restait alors dans le stockage sans aucun lien — donc invisible pour
tout le monde, y compris son auteur.

Trois corrections :

- **L'autorisation est verifiee avant le depot.** Rien n'est envoye si elle
  manque, et le message le dit : « la famille n'a pas coche photos dans sa fiche
  d'urgence, rien n'a ete envoye ».
- **Le fichier est retire si aucun lien n'aboutit.** La ligne photo et l'objet
  du stockage partent ensemble.
- **Une photo illisible ne disparait plus en silence.** Elle laisse une case
  « illisible » plutot que de s'effacer sans rien dire.

**Pour reparer l'existant** : onglet Photos, une banniere compte les photos
orphelines et propose de les rattacher a la famille affichee, ou de les
supprimer.

Teste dans les deux cas : sans autorisation, zero fichier depose et zero ligne
creee ; avec autorisation, un fichier, une ligne, un lien.

### Appareil photo

Il ouvre encore le selecteur de fichiers ? Le module natif n'est pas dans l'APK.
`build-apk.yml` a change en 1.2.0 pour l'installer, et **ce fichier ne peut pas
etre mis a jour par l'extraction automatique** : GitHub interdit a un workflow
de se modifier lui-meme. Il faut le recopier a la main.

L'application le dit desormais au lieu de laisser croire a un bug : « Module
appareil photo absent de cette version ».

## 1.3.4 — la galerie

**Deux elements portaient le meme identifiant `galerie`** : l'ancienne carte de
l'ecran Planning et la nouvelle page Photos. `$('#galerie')` renvoie le premier
trouve — donc le rendu allait dans une carte invisible pendant que la page
restait blanche, compteur a jour et grille vide.

L'ancienne carte est retiree : la page Photos la remplace entierement.

Mon controle des identifiants en double existait depuis la 1.0.9, mais je ne
l'avais pas rejoue apres avoir ajoute l'ecran. Il fait desormais partie du
controle systematique.

**Une erreur tuait le demarrage** : en remplacant la visionneuse, mon
remplacement avait emporte `supprimerPhoto`, encore branchee sur un bouton.
L'application ne depassait plus l'ecran de lancement.

### Une vraie visionneuse

Plein ecran sur fond sombre, des deux cotes :

- **La date en toutes lettres** — mardi 8 septembre 2026 — l'heure, et le rang
  dans la serie.
- **Le glissement du doigt** pour passer d'une photo a l'autre, avec une
  entree laterale dans le sens du geste.
- **L'enregistrement** : le partage natif propose la pellicule, un message ou
  un courriel ; a defaut, la photo se telecharge.
- Les fleches se desactivent aux extremites, le bouton retour d'Android ferme
  la visionneuse avant de quitter l'ecran.

La grille est regroupee par mois des deux cotes.

Teste : trois photos sur deux mois, grille et compteur corrects, ouverture,
date, passage a la suivante, fermeture.

## 1.3.5 — la notification mene ou elle annonce

Toucher une banniere ouvrait l'accueil, quel qu'en soit le sujet. Chaque envoi
transporte desormais sa destination : la fonction la transmet a Firebase dans
les donnees du message, et l'application l'ouvre.

| Notification | Ouvre |
| --- | --- |
| Il manque du lait, retard, message | Messages |
| Nouvelle photo | Photos |
| Journal de la journee | Journal |
| Demande, reponse a une demande | Demandes |
| Fiche d'urgence modifiee | Urgence |
| Absence, justificatif depose | Fermetures |
| Adaptation | Adaptation |
| Reprise | Reprise |
| Espace commun | Commun |
| Remplacement | Mes nounous |

Cote nounou, une notification de message ouvre **la conversation de la famille
concernee**, pas la boite : l'identifiant du contrat voyage avec.

Vingt envois passes en revue, aucun sans destination.

### La galerie cote parent

La meme visionneuse : plein ecran, date en toutes lettres, glissement du doigt,
enregistrement dans la pellicule. La grille est regroupee par mois.

La fonction `notifier` est a redeployer : elle transmet la destination.

## 1.3.6 — le centre du parent ignorait la nounou

Le centre de notifications est **une liste de ce qui demande une action**, pas
un historique des bannieres recues. C'est voulu : une notification touchee mene
deja au bon endroit, et un journal d'evenements de plus ne ferait que doubler
ce que chaque module affiche avec sa pastille.

Mais cote parent, il ne contenait que les obligations administratives —
calendrier a remplir, sauvegarde, seuils, versement. **Rien de ce que la nounou
envoyait.** Ouvrir la cloche ne disait pas qu'un message attendait.

Il annonce desormais aussi :

- messages non lus, en signalant les demandes de materiel qu'ils contiennent
- demandes a accepter ou refuser
- journal du jour, avec l'humeur et le mot, tant qu'il n'a pas ete ouvert
- photos des trois derniers jours
- absences annoncees non encore accusees
- etapes d'adaptation ou la nounou attend le ressenti du parent
- invitation a l'espace commun

Un point important : ces elements disparaissent une fois consultes. Le journal
retient la date de derniere lecture, les messages leur accuse, les absences leur
accuse de reception. Un centre qui repete indefiniment la meme chose finit par
ne plus etre lu.

La boucle de rafraichissement charge maintenant tout ce dont le centre parle —
absences, adaptation, espace commun — sinon il annonçait moins que ce qui
attendait vraiment.

## 1.4.0

### Messages d'erreur en français

Supabase repond en anglais et en jargon. Douze messages courants sont traduits
en ce qu'il faut faire : « Adresse e-mail ou mot de passe incorrect », « Confirme
ton adresse : un lien t'a ete envoye », « Trop d'essais, attends une minute ».
Le formulaire se secoue brievement — un refus se comprend avant d'etre lu.

### La mauvaise application

Une nounou qui se connecte dans Cocon Parent voyait un ecran vide sans
comprendre pourquoi. Le profil porte son role : l'application le lit, le dit, et
la deconnecte plutot que de la laisser devant un espace qui ne sera jamais
rempli. Dans les deux sens.

### Le telechargement des photos

Un lien de telechargement ne fait rien dans une WebView Android. La photo est
desormais ecrite dans le cache puis confiee au systeme, qui propose la
pellicule, un message ou un courriel. Deux modules s'ajoutent a la
compilation : `@capacitor/filesystem` et `@capacitor/share`.

### La visionneuse suit le doigt

Le glissement attendait le relachement pour agir : d'ou l'impression de saut.
L'image suit maintenant le doigt en direct.

- **Vers le cote** : l'image se decale, et au relachement l'ancienne part du
  cote du geste pendant que la nouvelle entre de l'autre.
- **Vers le bas** : l'image descend et retrecit, le fond s'eclaircit
  progressivement. Passe cent dix pixels, la visionneuse se ferme.
- **Au bout de la serie** : un rebond de dix-huit pixels. Un geste doit
  toujours repondre quelque chose.

### Animations

Le heros eclot a l'ouverture, les pastilles apparaissent par une breve
impulsion, le bouton central respire lentement — jamais de clignotement. Les
messages envoyes montent depuis le bas, les frimousses se posent en tournant
legerement. Tout est desactive en mouvement reduit.

## 1.4.1 — verification a fond, et le soin du detail

### Ce que la verification a trouve

Six controles passes sur les deux applications : syntaxe, identifiants en
double, references vers des elements absents, fonctions mortes ou branchees
mais absentes, chaque appel a la base contre le schema complet (vingt et une
tables, quinze fonctions), notifications sans destination, coherence des
versions, formulations au singulier.

Un seul reste : `totalSiestes`, du code mort, retire. Le reste etait propre.

### Le mobile

Au-dessus du logo sur l'ecran de connexion, un mobile de berceau : une etoile,
un nuage, une feuille, suspendus a une tige. Chacun se balance a son rythme —
3,6 s, 4,4 s, 3,1 s — pour que l'ensemble ne soit jamais synchrone. C'est le
premier ecran qu'on voit, il devait dire « cocon » avant le premier mot.

### Le montant compte

Le solde du mois et les heures de la semaine comptent jusqu'a leur valeur en
un peu plus d'une demi-seconde, avec une deceleration cubique. Un chiffre qui
arrive se remarque ; un chiffre pose la se lit sans y penser.

### Le toucher repond

- **Une onde** part du point exact ou le doigt s'est pose, sur les boutons,
  tuiles, modules, conversations. Le retour visuel le plus lisible qui soit.
- **Les cases a cocher** dessinent leur coche avec un leger depassement.
- **Les cartes** s'enfoncent d'un pixel au toucher.

### Illustrations dessinees

Berceau sous un mobile pour la nounou sans famille, ballons pour la galerie
vide, lune et nuage sur la tuile du journal quand rien n'est note. Elles
flottent doucement. Tout est desactive en mouvement reduit.

`build-apk.yml` n'a pas change depuis la 1.4.0.

## 1.4.2

### Les heures et les dates se choisissent, elles ne se tapent plus

Taper « 13:00 » au clavier etait penible. Chaque champ d'heure ouvre desormais
le selecteur d'Android — celui d'un reveil — et chaque champ de date son
calendrier.

Le format stocke ne change pas. Il traverse la fiche, le PDF, les calculs de
duree : le modifier aurait ete un risque pour un gain d'ergonomie. Un champ
natif invisible est pose par-dessus le champ texte : il s'ouvre au toucher, et
son choix est recopie dans le texte au format attendu. Dix-sept champs cote
parent, sept cote nounou, y compris ceux crees a la volee comme les siestes.

Un appui long sur le champ le vide. Une petite pointe a droite signale qu'il
s'ouvre.

### Le salut du moment

Le heros dit bonjour selon l'heure — bonjour, bon apres-midi, bonsoir, bonne
nuit — avec un soleil ou une lune dessine.

### Les ecrans arrivent

Chaque changement d'ecran glisse legerement depuis le bas. On sent le
changement sans qu'il ralentisse.

### Le mois est plie

Quand la fiche est marquee envoyee, vingt-six confettis en papier decoupe
tombent pendant une seconde et demie. Ce n'est pas un jeu, c'est un
soulagement — et ca n'arrive qu'une fois par mois.

### Frimousse partout

« Mes familles » sur l'accueil nounou affichait encore l'initiale a la place de
la frimousse.
