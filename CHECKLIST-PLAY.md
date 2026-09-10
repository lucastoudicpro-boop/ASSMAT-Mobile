# Publier Cocon sur Google Play

## Avant tout : quelle piste choisir

**Test interne** (recommandé pour commencer)
Jusqu'à cent testeurs invités par adresse e-mail. Pas de relecture par Google,
disponible en quelques minutes, et l'application n'apparaît nulle part
publiquement. Vous et votre assistante maternelle installez depuis un lien.

**Production**
Visible de tous. Relecture par Google, plusieurs jours. Et surtout : vous
devenez responsable de traitement pour les enfants d'autres familles, avec
toutes les obligations que cela suppose.

> Pour deux utilisateurs, le test interne suffit. Le passage en production se
> décide quand d'autres familles veulent l'utiliser, pas avant.

---

## 1. Le compte développeur

- Compte Google Play Console — 25 $ une fois, définitif
- Vérification d'identité : pièce d'identité, adresse
- Compte personnel : l'adresse est **publiée** sur la fiche en production
  (pas en test interne)
- Compter deux à trois jours de vérification

## 2. Deux applications, deux fiches

Cocon Parent et Cocon Nounou sont deux applications distinctes.

| | Cocon Parent | Cocon Nounou |
| --- | --- | --- |
| Nom de paquet | `fr.lucas.cocon.parent` | `fr.lucas.cocon.nounou` |
| Nom affiché | Cocon Parent | Cocon Nounou |
| Description courte | Fiches de salaire et suivi d'accueil pour parents employeurs | Le quotidien de vos accueils, en un endroit |
| Catégorie | Parentalité | Productivité |
| Public | Tout public | Tout public |

## 3. Les fichiers à fournir

Produits par le workflow, dans les artefacts de la compilation :

- `Cocon-Parent.aab` et `Cocon-Nounou.aab` — c'est ce que Play accepte
- Les `.apk` servent à l'installation directe, pas à Play

**Signature.** Play propose de gérer la clé pour vous (Play App Signing).
Acceptez : si vous perdez votre `.jks`, Google peut regénérer. Sinon, la perte
de la clé rend toute mise à jour impossible, définitivement.

## 4. Les images de la fiche

| Élément | Format | Obligatoire |
| --- | --- | --- |
| Icône | 512 × 512 px, PNG 32 bits | oui |
| Image de mise en avant | 1024 × 500 px | oui |
| Captures téléphone | 2 minimum, 8 maximum, 16:9 ou 9:16, min 320 px | oui |
| Captures tablette | même format | non |

## 5. Sécurité des données — les réponses exactes

Formulaire à remplir pour chaque application. Voici ce qui est vrai pour Cocon.

**Collectez-vous ou partagez-vous des données ?** Oui

| Type | Collecté | Partagé | Obligatoire | Raison |
| --- | --- | --- | --- | --- |
| Adresse e-mail | oui | non | oui | Gestion du compte |
| Numéro de téléphone | oui | non | non | Permettre de se joindre |
| Nom | oui | non | non | Fonctionnalité |
| Photos | oui | non | non | Fonctionnalité |
| Messages dans l'application | oui | non | non | Fonctionnalité |
| Informations de santé | oui | non | non | Fonctionnalité |
| Autres informations personnelles | oui | non | non | Fonctionnalité |

**« Partagé » signifie transmis à un tiers.** Supabase et Firebase sont des
sous-traitants, pas des tiers : la réponse reste « non ».

**Les données sont-elles chiffrées en transit ?** Oui
**L'utilisateur peut-il demander la suppression ?** Oui
**Suivez-vous une politique de familles ?** Non — l'application s'adresse à des adultes

**Ne cochez pas** : localisation, contacts, historique de navigation,
informations financières. Les montants et l'IBAN ne quittent pas le téléphone,
donc ne sont pas collectés au sens du formulaire.

## 6. Politique de confidentialité

Obligatoire, à une adresse publique. Le fichier est dans le dépôt :

- `docs/confidentialite.html` → publié par GitHub Pages
- URL à indiquer : `https://<votre-compte>.github.io/<dépôt>/confidentialite.html`

Vérifiez qu'elle s'ouvre dans un navigateur avant de la déclarer. Une adresse
morte fait refuser l'envoi.

## 7. Classification du contenu

Questionnaire. Pour Cocon, tout est « non » : ni violence, ni contenu sexuel,
ni jeu d'argent, ni substances. La seule question à traiter avec attention :
**partage d'informations personnelles entre utilisateurs → oui** (messages et
photos entre le parent et l'assistante maternelle).

Classification attendue : PEGI 3 / Tout public.

## 8. Points de refus les plus fréquents

- **Politique de confidentialité inaccessible** — vérifier l'adresse
- **Formulaire de sécurité incohérent** avec ce que fait l'application :
  déclarer les photos et la santé, sous peine de suspension
- **Niveau d'API cible trop ancien** — Play exige un niveau récent, à vérifier
  dans le journal de compilation
- **Captures d'écran trompeuses** — montrer l'application réelle
- **Absence de compte de démonstration** : si l'application exige une
  connexion, fournir des identifiants de test dans « Accès à l'application »,
  sinon le relecteur ne voit qu'un écran de connexion et refuse

## 9. Ordre des opérations

1. Créer le compte développeur, attendre la vérification
2. Publier la politique de confidentialité, vérifier qu'elle s'ouvre
3. Créer les deux applications dans la console
4. Remplir sécurité des données et classification pour chacune
5. Préparer icône, image de mise en avant, captures
6. Compiler, récupérer les deux `.aab`
7. Créer une version de **test interne**, y déposer l'AAB
8. Ajouter votre assistante maternelle comme testeuse
9. Lui envoyer le lien d'inscription

Le passage en production attend d'avoir des retours réels.
