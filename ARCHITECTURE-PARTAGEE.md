# AssMat+ partagé — architecture

Document de conception, avant tout code. À relire et à corriger : chaque
décision ci-dessous engage la suite.

---

## 1. Ce qui reste sur le téléphone, ce qui monte en ligne

C'est la décision la plus importante, et elle est déjà prise : **les données
sensibles ne quittent pas l'appareil de l'employeur.**

### Jamais en ligne

| Donnée | Pourquoi |
| --- | --- |
| IBAN de la salariée | Aucun usage partagé, risque maximal |
| N° de sécurité sociale | Sert uniquement à la déclaration Pajemploi |
| N° d'agrément | Idem |
| Montants : brut, net, indemnités, solde | Le calcul reste local |
| Fiches A4 et attestations | Générées et partagées à la demande |
| Seuils légaux, sauvegardes, code de l'application | Réglages personnels |

### Partagé entre les deux comptes

| Donnée | Écrite par | Lue par |
| --- | --- | --- |
| Prénom et nom des deux personnes | chacun le sien | les deux |
| Prénom de l'enfant, date de naissance | employeur | les deux |
| Coordonnées de contact (téléphone, e-mail) | chacun les siennes | les deux |
| Adresse d'accueil | salariée | les deux |
| Planning type de la semaine | employeur | les deux |
| Heures prévues, jour par jour | employeur | les deux |
| Heures réellement effectuées | salariée | les deux |
| Absences enfant | employeur | les deux |
| Absences salariée | salariée | les deux |
| Total d'heures du mois | calculé | les deux |
| État de la fiche : établie, transmise, versée | employeur | les deux |
| Messages | chacun | les deux |
| Consentement signé | chacun le sien | les deux |

Le montant du salaire n'est volontairement pas partagé. La salariée reçoit la
fiche PDF comme aujourd'hui, et son bulletin officiel vient de Pajemploi. Mettre
les montants en ligne apporterait peu et ajouterait du risque.

---

## 2. Les rôles

Deux rôles, portés par le même contrat.

**Employeur.** Établit les fiches, saisit les heures prévues, marque les
absences de l'enfant, transmet la fiche, enregistre le versement. C'est
l'application actuelle, augmentée de la synchronisation.

**Salariée.** Consulte son planning, déclare les heures réellement effectuées,
signale ses absences, voit l'état des fiches du mois, accuse réception. Elle n'a
accès ni aux montants, ni aux réglages de l'employeur.

### Une salariée travaille pour plusieurs employeurs

Point de modèle à corriger avant d'aller plus loin : la relation n'est pas
une salariée pour un employeur. Une assistante maternelle agréée accueille
couramment trois ou quatre enfants **de familles différentes, en même temps**.
Et un même employeur peut lui confier deux enfants.

La relation est donc **plusieurs à plusieurs**, et l'unité de base n'est ni la
personne ni le foyer : c'est **le contrat**, un par enfant accueilli.

```
Marie (salariée)
 ├── contrat · Léo    · employeur Lucas
 ├── contrat · Zoé    · employeur Lucas
 ├── contrat · Sacha  · employeur Nadia
 └── contrat · Inès   · employeur Karim
```

La table `contrats` du chapitre 6 porte déjà ce modèle : une ligne par enfant,
avec un employeur et une salariée. Rien à changer, mais deux conséquences.

**Côté salariée, ça change tout.** Son application ne montre plus un planning
mais l'agenda consolidé de ses quatre accueils, avec les conflits d'horaires
visibles, et le total d'heures de sa semaine. C'est le vrai intérêt de
l'application pour elle : aucun employeur ne peut lui offrir cette vue, et c'est
ce qui la décidera à l'installer.

**Côté employeur, rien ne change.** Il ne voit que ses propres contrats, jamais
les autres familles chez qui travaille sa salariée. La règle d'accès au niveau
de la ligne s'en charge, et elle doit être écrite dans ce sens dès le premier
jour.

### Sur la troisième application, celle de l'administrateur

Tu veux une application à part pour toi, créateur, afin de gérer l'ensemble si
plusieurs assistantes maternelles s'y mettent. Le besoin est légitime, la forme
que tu proposes ne l'est pas. Trois objections.

**Une application Android d'administration est un mauvais support.** Elle
demanderait de détenir sur ton téléphone une clé donnant accès à toute la base.
Téléphone perdu, volé ou compromis, et c'est l'ensemble des foyers qui tombe.
Une page web protégée, sur une machine que tu contrôles, fait le même travail
sans ce risque.

**Le tableau de bord existe déjà.** Supabase fournit une console : comptes,
tables, requêtes, journaux. Reconstruire cela dans une troisième application
Android serait plusieurs semaines de travail pour un résultat inférieur.

**Surtout : administrer n'oblige pas à tout lire.** C'est la distinction
importante. Pour faire tourner un service tu as besoin de savoir combien de
comptes existent, combien de contrats sont actifs, quelles versions sont
installées et quelles erreurs remontent. Rien de tout cela n'exige de lire le
planning de Nadia ni le prénom de ses enfants.

Ce que je recommande à la place :

| Besoin | Réponse |
| --- | --- |
| Savoir si le service tourne | Compteurs agrégés : nombre de comptes, de contrats actifs, d'erreurs |
| Diagnostiquer un problème | Journaux techniques, sans contenu métier |
| Aider quelqu'un de bloqué | Accès support **consenti**, activé par l'utilisateur, limité à 24 h, tracé |
| Facturer, un jour | Table d'abonnements, sans lien avec le contenu |

Tu restes responsable de traitement dans tous les cas, avec ce que cela implique :
registre, politique de confidentialité, droit à l'effacement, notification en cas
de fuite. Mais ne pas pouvoir lire les données réduit énormément ta surface de
responsabilité, et c'est une protection pour toi autant que pour eux.

**Reste donc à trancher :** administration par compteurs agrégés et accès support
consenti, ou lecture complète de toutes les données ? Je recommande fermement la
première.

---

## 3. Deux applications, un seul code

Tu veux une application distincte côté salariée. D'accord sur le principe, mais
pas sur deux projets séparés : le moteur de calcul, la couche de
synchronisation et la charte visuelle seraient dupliqués, et diverger au premier
correctif.

La bonne forme est **un dépôt, deux compilations** :

```
docs/            interface employeur   → fr.lucas.assmat
docs-salariee/   interface salariée    → fr.lucas.assmat.salariee
commun/          moteur, sync, styles, icônes
console/         page web d'administration, hors application mobile
```

Deux `capacitor.config.json`, deux `applicationId`, deux workflows de
compilation, deux APK sur les versions publiées. Un seul correctif de calcul
profite aux deux.

Bénéfice de sécurité, non négligeable : l'application de la salariée ne contient
tout simplement pas le code qui manipule l'IBAN, les montants ou la déclaration
Pajemploi. Une fuite par un bug d'affichage devient impossible, pas seulement
improbable.

---

## 3 bis. L'espace partagé entre les familles

Les enfants de trois ou quatre familles passent leurs journées ensemble. Un
espace commun a du sens, mais c'est aussi la fonction la plus susceptible de
créer des ennuis. Elle demande donc les règles les plus strictes.

### Ce qui la justifie

**La maladie contagieuse.** C'est le cas qui compte. Varicelle, gastro,
scarlatine : les autres familles ont un intérêt réel et immédiat à savoir. Aucun
autre canal ne le fait aujourd'hui, sinon l'assistante maternelle qui prévient
chacun de son côté.

**Les fermetures et les congés.** Se répartir les semaines de vacances, savoir
qu'une famille libère une place.

**Les sorties et les événements.** Un anniversaire, une sortie au parc.

Ce qui ne la justifie pas : une messagerie entre parents. Une fois qu'ils se
connaissent, ils échangent leurs numéros. Ajouter une messagerie, c'est ajouter
de la modération, des signalements, et des conflits où l'assistante maternelle
se retrouverait arbitre.

### Ce qui traverse, et ce qui ne traverse jamais

**Rien ne se publie automatiquement.** C'est la règle de sécurité principale.
Une absence saisie dans un contrat n'apparaît pas dans l'espace commun. Un
parent écrit une annonce, ou il ne se passe rien. Les accidents de
confidentialité viennent presque toujours d'une publication automatique que
personne n'avait anticipée.

| Visible des autres familles | Jamais visible |
| --- | --- |
| Prénom de l'enfant | Nom de famille |
| Prénom du parent qui publie | Adresse, téléphone, e-mail |
| Le texte de l'annonce, écrit par le parent | Planning, heures, absences du contrat |
| La date de publication | Salaire, contrat, tout le reste |

Sur la maladie : le parent écrit lui-même ce qu'il veut dire. Pas de champ
médical structuré, pas de liste de pathologies à cocher. La santé d'un enfant
est une donnée sensible, et le parent doit rester maître du niveau de détail.

### Le consentement, famille par famille

L'espace est ouvert par l'assistante maternelle : elle est le lien commun. Mais
chaque famille décide séparément d'y entrer, et ce consentement est distinct de
celui du contrat.

Une famille qui refuse continue d'utiliser l'application normalement. Elle
n'apparaît pas dans la liste des membres, et les autres n'ont aucun moyen de
savoir qu'elle existe.

Quitter l'espace est possible à tout moment, en un geste. Les annonces déjà
publiées par la personne sont retirées avec elle. En fin de contrat, la sortie
est automatique.

### Tables

```
espaces         (id, salariee_id, nom, cree_le)
membres_espace  (espace_id, contrat_id, accepte_le, quitte_le)
annonces        (espace_id, auteur_id, categorie, texte, cree_le)
```

`categorie` vaut `maladie`, `absence`, `sortie` ou `info` : elle sert à trier
l'affichage et à notifier différemment, pas à décrire un contenu médical.

La règle d'accès est indépendante de celle des contrats : on lit un espace si
l'un de ses contrats nous cite **et** que l'adhésion est acceptée et non
quittée. Aucune jointure ne doit pouvoir remonter d'un espace vers les données
d'un contrat d'une autre famille. C'est le point à vérifier ligne par ligne au
moment de l'écrire.

### Quand la construire

En dernier, après la synchronisation du planning. C'est la fonction qui apporte
le moins tant que l'application n'a pas ses premiers utilisateurs, et celle qui
coûte le plus cher si elle est mal cadrée.

---

## 4. Le lien entre les deux comptes

1. L'employeur crée le contrat dans son application et génère un **code
   d'invitation** à six caractères, valable sept jours.
2. La salariée installe AssMat+ Salariée, crée son compte, saisit le code.
3. Le contrat les relie. L'employeur voit la demande et confirme.
4. Chacun signe son consentement avant que la moindre donnée ne circule.

Le code expire, ne se devine pas, et une invitation déjà utilisée est close.
L'employeur peut révoquer l'accès à tout moment : la salariée garde alors son
compte mais perd la lecture du contrat.

---

## 5. Le consentement signé

Avant tout partage, chacun voit le texte et le signe dans l'application.

Ce qui est enregistré : l'identifiant de la personne, la version exacte du texte
accepté, la date et l'heure, et le nom saisi à la main. Pas d'adresse IP : c'est
une donnée personnelle de plus, sans utilité ici.

Le texte doit dire, en clair : quelles données sont partagées, avec qui,
pourquoi, combien de temps elles sont conservées, et comment demander leur
effacement. Un exemplaire PDF est envoyé aux deux parties après signature.

Le refus est possible et sans conséquence : l'application fonctionne alors en
mode local, exactement comme aujourd'hui.

---

## 6. La synchronisation, et pourquoi elle ne posera pas de conflit

C'est le point technique qui fait échouer la plupart des applications
collaboratives. La solution ici est structurelle, pas algorithmique.

**Chaque champ a un seul propriétaire.**

| Champ | Qui écrit |
| --- | --- |
| Heures prévues | employeur seul |
| Absence de l'enfant | employeur seul |
| Heures effectuées | salariée seule |
| Absence de la salariée | salariée seule |
| État de la fiche | employeur seul |
| Message | son auteur seul |

Deux personnes ne peuvent donc jamais modifier la même valeur. Il n'y a rien à
fusionner, et la règle du dernier qui écrit — celle qui perd silencieusement des
données — n'a pas à s'appliquer.

L'application reste **locale d'abord** : elle fonctionne sans réseau, met les
changements en file, et les envoie au retour de la connexion. Un indicateur
discret dit si tout est synchronisé.

### Tables

```
profils        (id = auth.uid, role, prenom, nom, telephone)
contrats       (id, employeur_id, salariee_id, enfant_prenom,
                enfant_naissance, statut, cree_le)
invitations    (code, contrat_id, expire_le, utilisee_le)
jours          (contrat_id, date, heures_prevues, heures_reelles,
                absence_enfant, absence_salariee, maj_le)
mois           (contrat_id, mois, heures_total, etat_fiche, maj_le)
messages       (contrat_id, auteur_id, texte, cree_le, lu_le)
consentements  (contrat_id, personne_id, version_texte, nom_saisi, signe_le)
support        (contrat_id, ouvert_par, expire_le)   -- accès temporaire consenti
```

Chaque table est protégée par une règle d'accès au niveau de la ligne : on ne
voit que les lignes dont le contrat nous cite comme employeur ou comme salariée.
La règle est écrite une fois dans la base et s'applique même si l'application se
trompe. C'est la seule protection sur laquelle il faut compter.

---

## 7. Ce que ça coûte, honnêtement

**L'adoption.** Si ta salariée n'installe pas l'application ou ne l'ouvre pas,
tout ce travail ne sert à rien. C'est le risque numéro un, et il n'est pas
technique.

**La mise en pause Supabase.** Sur le plan gratuit, un projet sans activité
pendant sept jours est mis en pause et devient injoignable jusqu'à restauration
manuelle. Pour une application ouverte quelques fois par mois, il faut soit une
tâche planifiée qui maintient le projet éveillé, soit le plan payant.

**Le RGPD.** Même en lecture A, tu traites les données d'une autre personne.
Consentement, information claire, droit à l'effacement, suppression réelle à la
fin du contrat.

**La maintenance.** Deux applications à publier, une base à surveiller, des
comptes à gérer. L'application actuelle ne dépend de rien ni de personne.

---

## 8. Ordre de construction proposé

1. **Le socle partagé** : extraire le moteur et les styles dans `commun/`, sans
   rien changer au comportement. Vérifiable immédiatement, aucun risque.
2. **La deuxième compilation** : produire l'APK salariée, encore hors ligne, avec
   un jeu de données de démonstration. Permet de valider l'interface avec elle
   avant tout serveur.
3. **Les comptes et le consentement** : Supabase, authentification, invitation,
   signature. Aucune donnée métier encore.
4. **La synchronisation du planning** : les jours et les mois, dans les deux
   sens.
5. **Les messages** entre l'employeur et sa salariée.
6. **L'espace partagé entre familles**, en dernier.

L'étape 2 est le vrai jalon : c'est là que tu sauras si elle l'utilisera.

---

## À trancher avant de commencer

1. **Administration** : compteurs agrégés et accès support consenti, ou lecture
   complète de toutes les données ?
2. **Diffusion** : l'application reste-t-elle pour toi et ta salariée, ou vises-tu
   d'autres familles dès le départ ? La réponse change le niveau d'exigence
   juridique, pas l'architecture.
3. Ta salariée est-elle d'accord pour installer une application et créer un
   compte ?
4. Es-tu prêt à payer un hébergement, ou faut-il rester sur le plan gratuit avec
   la contrainte de mise en pause ?
