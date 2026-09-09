/* Reglages livres avec l'application, communs aux deux versions.

   La cle publique identifie le projet et n'autorise rien par elle-meme : ce
   sont les regles de la base qui decident. Elle doit etre au NOUVEAU format,
   sb_publishable_... (Project Settings -> API Keys). L'ancienne cle « anon »
   en eyJ... passe encore pour la base mais la passerelle des fonctions la
   refuse : sans la nouvelle, aucune notification ne peut partir.
   La cle secrete, elle, n'est nulle part ici.

   notifications : ne passer a true que si google-services.json est present dans
   l'APK. Le workflow s'en charge. Sans lui, demander l'enregistrement a Firebase
   arrete l'application, et pas proprement : c'est le processus natif qui tombe. */
const PROJET = {
  url: "https://epixqfxqcaibxxdfujvb.supabase.co",
  cle: "sb_publishable_z3HtOQ9xSsHEgmUbVLqYZA_m1G2iu0K",
  notifications: false
};
