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
