# Base de données partagée

Trois fichiers, à exécuter dans l'ordre, dans l'éditeur SQL de Supabase.

| Fichier | Rôle |
| --- | --- |
| `001-schema.sql` | Tables, déclencheurs, fonctions |
| `002-politiques.sql` | Règles d'accès au niveau de la ligne |
| `003-verification.sql` | Contrôles à passer après |

## Avant de commencer

**Sur un projet neuf.** `001-schema.sql` commence par supprimer les onze tables :
lancé sur un projet contenant déjà des données, il les efface. Crée un projet
dédié.

**Ce SQL n'a pas été exécuté.** Je n'avais ni Postgres ni réseau pour le tester.
La syntaxe est écrite avec soin, mais elle peut contenir une erreur. Si
l'éditeur en signale une, envoie-moi le message : la correction est rapide.
C'est aussi la raison d'être de `003-verification.sql`.

## Marche à suivre

1. Créer un projet sur supabase.com, noter l'URL et la clé publique `anon`.
2. Éditeur SQL, coller `001-schema.sql`, exécuter.
3. Même chose avec `002-politiques.sql`.
4. Exécuter `003-verification.sql` requête par requête et comparer aux valeurs
   attendues, écrites en commentaire au-dessus de chacune.

Le contrôle numéro 2 est le plus important : toute table qu'il renvoie est
lisible par n'importe quel compte connecté.

## Ce que la base ne contient pas

Ni IBAN, ni numéro de sécurité sociale, ni numéro d'agrément, ni aucun montant.
Ces données restent sur le téléphone de l'employeur. La base ne connaît que le
planning, les absences, l'état des fiches et les messages.

Si un jour tu ajoutes une colonne, pose-toi la question avant : cette donnée
a-t-elle vraiment besoin de traverser le réseau ?

## Les deux mécanismes qui font la sécurité

**Les règles au niveau de la ligne.** La base refuse tout par défaut. Chaque
autorisation est écrite dans `002-politiques.sql`. Même si l'application est
boguée, un compte ne peut pas lire le foyer d'un autre.

**Le déclencheur de propriété des colonnes.** Sur la table `jours`, chaque
colonne a un seul propriétaire : l'employeur écrit les heures prévues et les
absences de l'enfant, la salariée les heures effectuées et ses propres absences.
Le déclencheur restaure silencieusement les colonnes qui ne t'appartiennent pas,
au lieu de rejeter l'écriture. Une synchronisation ne doit jamais échouer en bloc
à cause d'un champ interdit.

Conséquence : deux personnes ne peuvent jamais modifier la même valeur. Il n'y a
rien à fusionner, et rien ne se perd en silence.

## La table des invitations

Elle n'a aucune règle de lecture, volontairement. Un compte capable de lister
les codes pourrait rejoindre le contrat de n'importe qui. La salariée passe par
la fonction `rejoindre(code)`, qui vérifie l'expiration et l'unicité avant
d'attacher le contrat.

Le contrôle numéro 4 vérifie qu'aucune règle de lecture n'a été ajoutée par
mégarde sur cette table.

## Reste à décider avant d'aller plus loin

La mise en pause du plan gratuit : un projet sans activité pendant sept jours
devient injoignable jusqu'à restauration manuelle. Pour une application ouverte
quelques fois par mois, il faut soit une tâche planifiée qui maintient le projet
éveillé, soit le plan payant.
