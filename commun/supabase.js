/* Client Supabase minimal, partagé par Cocon Parent et Cocon Nounou.
   Aucune dépendance : les deux applications restent utilisables hors ligne. */
/* ---------------- Accès à la base partagée ----------------
   Client écrit à la main plutôt que la bibliothèque officielle : l'application
   ne charge aucun script externe, ce qui la garde utilisable hors connexion.
   Supabase expose de l'HTTP simple, une centaine de lignes suffisent. */
const Supa = (() => {
  let base = '', cle = '', session = null;

  /* Le stockage de la session est fourni par l'application hôte : chacune a le
     sien. À défaut, on retombe sur celui du navigateur. */
  let lireSession = async () => {
    try { return JSON.parse(localStorage.getItem('cocon-session') || 'null'); }
    catch (e) { return null; }
  };
  let ecrireSession = async (o) => {
    try {
      if (o) localStorage.setItem('cocon-session', JSON.stringify(o));
      else localStorage.removeItem('cocon-session');
    } catch (e) {}
  };
  function brancherStockage(lire, ecrire) { lireSession = lire; ecrireSession = ecrire; }

  function configurer(u, c) {
    base = String(u || '').trim().replace(/\/+$/, '');
    cle = String(c || '').trim();
  }
  const configure = () => !!(base && cle);
  const connecte = () => !!(session && session.access_token);
  const moi = () => (session && session.user) || null;

  async function appel(chemin, opts = {}, avecJeton = true) {
    if (!configure()) throw new Error('Adresse et clé du projet manquantes');
    const entetes = { apikey: cle, 'Content-Type': 'application/json', ...(opts.headers || {}) };
    if (avecJeton && connecte()) entetes.Authorization = 'Bearer ' + session.access_token;

    let r;
    try {
      r = await fetch(base + chemin, { ...opts, headers: entetes });
    } catch (e) {
      throw new Error('Serveur injoignable — vérifie la connexion et l\u2019adresse du projet');
    }
    const brut = await r.text();
    let data = null;
    try { data = brut ? JSON.parse(brut) : null; } catch (e) { data = brut; }

    if (!r.ok) {
      const m = (data && (data.msg || data.message || data.error_description || data.error || data.hint)) || null;
      throw new Error(m || ('Erreur ' + r.status));
    }
    return data;
  }

  async function memoriser(s) {
    session = s;
    try {
      await ecrireSession(s ? { ...s, expire_a: Date.now() + (s.expires_in || 3600) * 1000 } : null);
    } catch (e) { /* la session vaut au moins pour cette ouverture */ }
  }

  async function reprendre() {
    const s = await lireSession();
    if (!s || !s.refresh_token) return false;
    session = s;
    if (s.expire_a && s.expire_a - Date.now() > 60000) return true;
    return rafraichir();
  }

  async function rafraichir() {
    const s = await lireSession();
    if (!s || !s.refresh_token) return false;
    try {
      const r = await appel('/auth/v1/token?grant_type=refresh_token', {
        method: 'POST', body: JSON.stringify({ refresh_token: s.refresh_token })
      }, false);
      await memoriser(r);
      return true;
    } catch (e) {
      await memoriser(null);
      return false;
    }
  }

  async function inscrire(email, mdp) {
    const r = await appel('/auth/v1/signup', {
      method: 'POST', body: JSON.stringify({ email, password: mdp })
    }, false);
    if (r && r.access_token) await memoriser(r);
    return r;
  }

  async function connecter(email, mdp) {
    const r = await appel('/auth/v1/token?grant_type=password', {
      method: 'POST', body: JSON.stringify({ email, password: mdp })
    }, false);
    await memoriser(r);
    return r;
  }

  /* Envoie le lien de reinitialisation. La reponse est volontairement la meme
     que l'adresse existe ou non : sinon on donnerait le moyen de savoir qui a
     un compte. */
  async function recuperer(email) {
    await appel('/auth/v1/recover', {
      method: 'POST', body: JSON.stringify({ email })
    }, false);
  }

  async function deconnecter() {
    try { await appel('/auth/v1/logout', { method: 'POST' }); } catch (e) {}
    await memoriser(null);
  }

  /* Une requête sur une table, avec une reprise si le jeton vient d'expirer. */
  async function table(nom, opts = {}, requete = '') {
    const faire = () => appel('/rest/v1/' + nom + (requete ? '?' + requete : ''), opts);
    try { return await faire(); }
    catch (e) {
      if (!/401|JWT|expired/i.test(e.message)) throw e;
      if (!(await rafraichir())) throw new Error('Session expirée, reconnecte-toi');
      return faire();
    }
  }

  const lire = (nom, requete) => table(nom, { method: 'GET' }, requete);

  const ecrire = (nom, lignes, options = '') =>
    table(nom, {
      method: 'POST',
      headers: { Prefer: 'return=representation' + (options ? ',' + options : '') },
      body: JSON.stringify(lignes)
    });

  const modifier = (nom, valeurs, requete) =>
    table(nom, {
      method: 'PATCH',
      headers: { Prefer: 'return=representation' },
      body: JSON.stringify(valeurs)
    }, requete);

  const supprimer = (nom, requete) =>
    table(nom, { method: 'DELETE', headers: { Prefer: 'return=minimal' } }, requete);

  const fonction = (nom, args) =>
    appel('/rest/v1/rpc/' + nom, { method: 'POST', body: JSON.stringify(args || {}) });

  /* En-têtes prêtes à l'emploi, pour le stockage de fichiers qui n'est pas
     du JSON et ne passe donc pas par les fonctions ci-dessus. */
  function entetes() {
    const h = { apikey: cle };
    if (connecte()) h.Authorization = 'Bearer ' + session.access_token;
    return h;
  }
  const adresse = () => base;

  /* Notifications : le jeton de l'appareil est déposé en base, et l'envoi
     passe par la fonction serveur, seule à détenir la clé Firebase. */
  async function enregistrerJeton(jeton, application) {
    if (!connecte() || !jeton) return;
    await table('jetons_push', {
      method: 'POST',
      headers: { Prefer: 'return=minimal,resolution=merge-duplicates' },
      body: JSON.stringify({
        jeton, personne_id: session.user.id, application, maj_le: new Date().toISOString()
      })
    });
  }

  async function notifier(contratId, titre, corps) {
    if (!connecte()) return;
    try {
      await fetch(base + '/functions/v1/notifier', {
        method: 'POST',
        headers: { ...entetes(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ contrat_id: contratId, titre, corps })
      });
    } catch (e) { /* le message est déjà enregistré : la notification n'est qu'un plus */ }
  }

  return { brancherStockage, configurer, configure, connecte, moi, entetes, adresse,
           enregistrerJeton, notifier, supprimer, reprendre, rafraichir,
           inscrire, connecter, recuperer, deconnecter, lire, ecrire, modifier, fonction };
})();
