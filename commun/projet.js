/* Reglages livres avec l'application, communs aux deux versions.

   La cle « anon » est publique par conception : elle identifie le projet et
   n'autorise rien par elle-meme. Ce sont les regles de la base qui decident de
   ce que chacun peut lire. La cle service_role, elle, n'est nulle part ici.

   notifications : ne passer a true que si google-services.json est present dans
   l'APK. Le workflow s'en charge. Sans lui, demander l'enregistrement a Firebase
   arrete l'application, et pas proprement : c'est le processus natif qui tombe. */
const PROJET = {
  url: "https://epixqfxqcaibxxdfujvb.supabase.co",
  cle: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwaXhxZnhxY2FpYnh4ZGZ1anZiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg4NjMyMjUsImV4cCI6MjEwNDQzOTIyNX0.Q-680Vy-7l23ikaByvAywXX-rlsHyloShkdEU9UYCMM",
  notifications: false
};
