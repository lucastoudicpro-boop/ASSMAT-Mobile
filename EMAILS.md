# Les courriels de Cocon

## Pourquoi ne pas s'en passer

Supabase envoie par defaut depuis `noreply@mail.app.supabase.io`. Trois
consequences :

- une bonne partie arrive en indesirables, notamment chez Orange et Free ;
- l'expediteur n'inspire aucune confiance a un parent qui vient de creer son
  compte ;
- la limite est de **deux courriels par heure** sur l'offre gratuite. Deux
  inscriptions le meme matin, et la seconde n'en recoit pas.

Pour une application qu'on donne a d'autres, ce n'est pas tenable.

## Ce qu'il faut

**1. Le nom de domaine.** `cocon-app.fr` chez OVH ou Gandi, une dizaine
d'euros par an. Verifie qu'il est libre avant tout le reste.

**2. Un service d'envoi.** Trois qui conviennent :

| | Gratuit | Ensuite | Remarque |
| --- | --- | --- | --- |
| Resend | 3 000/mois | 20 $/mois | le plus simple a brancher |
| Brevo | 300/jour | 25 €/mois | francais, hebergement UE |
| Postmark | 100 en essai | 15 $/mois | le meilleur taux de remise |

Pour du RGPD, Brevo a l'avantage d'heberger en Europe. Resend passe par AWS
avec une region europeenne au choix.

**3. Les trois enregistrements DNS.** Sans eux, tout part en indesirables.

- **SPF** : dit quels serveurs ont le droit d'envoyer pour ton domaine
- **DKIM** : signe chaque courriel, prouve qu'il n'a pas ete modifie
- **DMARC** : dit quoi faire si les deux precedents echouent

Le service d'envoi te donne les valeurs exactes. Compter une heure, propagation
comprise.

**4. Brancher Supabase.** Authentication → Emails → SMTP Settings. Renseigner
l'hote, le port, l'utilisateur et le mot de passe fournis par le service.

## Les adresses

| Adresse | Usage | Recoit-elle ? |
| --- | --- | --- |
| `noreply@cocon-app.fr` | inscriptions, mots de passe, confirmations | non |
| `support@cocon-app.fr` | aide, questions, signalements | oui |
| `contact@cocon-app.fr` | fiche Google Play, mentions legales | oui |
| `rgpd@cocon-app.fr` | demandes d'acces et d'effacement | oui |

`support@` et `rgpd@` peuvent renvoyer vers ta boite personnelle : une
redirection suffit, aucune boite a gerer.

**`rgpd@` n'est pas facultatif** des lors que l'application est publique : la
politique de confidentialite doit indiquer une adresse joignable, et une
demande d'effacement doit recevoir reponse sous un mois.

## Les modeles a reecrire

Ceux de Supabase sont en anglais et impersonnels. A refaire dans
Authentication → Email Templates :

- **Confirmation d'inscription** — dire que le lien vaut vingt-quatre heures
- **Reinitialisation** — dire que le lien vaut une heure, et que si la demande
  ne vient pas d'eux, ils peuvent l'ignorer
- **Changement d'adresse** — envoye aux deux adresses, l'ancienne et la
  nouvelle

Ecrire comme l'application parle : « Bonjour, voici le lien pour choisir un
nouveau mot de passe. Il vaut une heure. »

## La suppression differee

Le fichier `022-suppression-differee.sql` programme l'effacement a quinze
jours. Il manque les deux courriels, qui demandent une fonction serveur :

- **a la demande** : rappeler la date, donner le lien pour se retracter,
  rappeler que l'archive est encore telechargeable
- **la veille** : dernier avertissement

Sans eux le delai fonctionne, mais personne n'est prevenu — ce qui enleve
l'essentiel de son interet. A ecrire une fois le service d'envoi en place.

## Le compte d'authentification

Meme apres la purge, l'adresse e-mail reste dans `auth.users` : une fonction
cote base ne peut pas y toucher. Il faut une fonction serveur appelant l'API
admin avec la cle de service. A prevoir avant toute mise en production reelle.
