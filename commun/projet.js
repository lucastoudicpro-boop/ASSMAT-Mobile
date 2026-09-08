/* Reglages livres avec l'application, communs aux deux versions.

   url et cle : adresse du projet Supabase. La cle « anon » est publique par
   conception, ce sont les regles de la base qui protegent les donnees.
   Le workflow les remplit depuis les secrets SUPABASE_URL et SUPABASE_ANON_KEY
   s'ils existent ; sinon on peut les ecrire ici a la main.

   notifications : ne passer a true que si google-services.json est bien present
   dans l'APK. Sans lui, demander l'enregistrement a Firebase fait tomber
   l'application, et pas proprement : c'est le processus natif qui s'arrete. */
const PROJET = {
  url: '',
  cle: '',
  notifications: false
};
