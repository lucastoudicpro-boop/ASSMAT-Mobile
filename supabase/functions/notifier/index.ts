// Cocon — fonction « notifier »
//
// Envoie une notification à l'autre partie d'un contrat.
// Appelée par l'application juste après l'écriture d'un message.
//
// L'appelant est vérifié deux fois : son jeton doit être valide, et la lecture
// du contrat passe par ses propres droits. S'il n'appartient pas au contrat,
// la base ne lui renvoie rien et la fonction s'arrête.
//
// Secret à définir : FCM_COMPTE_SERVICE, le JSON du compte de service Firebase.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const URL_SUPABASE = Deno.env.get('SUPABASE_URL')!;
const CLE_SERVICE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const COMPTE = JSON.parse(Deno.env.get('FCM_COMPTE_SERVICE') ?? '{}');

const entetesCORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

/* ---- Jeton d'accès Google, signé avec la clé du compte de service ---- */
let cache: { jeton: string; expire: number } | null = null;

function base64url(donnees: Uint8Array | string): string {
  const octets = typeof donnees === 'string' ? new TextEncoder().encode(donnees) : donnees;
  return btoa(String.fromCharCode(...octets))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemVersBinaire(pem: string): ArrayBuffer {
  const corps = pem.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const brut = atob(corps);
  const t = new Uint8Array(brut.length);
  for (let i = 0; i < brut.length; i++) t[i] = brut.charCodeAt(i);
  return t.buffer;
}

async function jetonGoogle(): Promise<string> {
  if (cache && cache.expire > Date.now() + 60_000) return cache.jeton;

  const maintenant = Math.floor(Date.now() / 1000);
  const entete = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const charge = base64url(JSON.stringify({
    iss: COMPTE.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: maintenant,
    exp: maintenant + 3600,
  }));

  const cle = await crypto.subtle.importKey(
    'pkcs8', pemVersBinaire(COMPTE.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', cle, new TextEncoder().encode(entete + '.' + charge));

  const jwt = entete + '.' + charge + '.' + base64url(new Uint8Array(signature));

  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });
  const d = await r.json();
  if (!d.access_token) throw new Error('Jeton Google refusé : ' + JSON.stringify(d));

  cache = { jeton: d.access_token, expire: Date.now() + (d.expires_in ?? 3600) * 1000 };
  return cache.jeton;
}

/* ---- Envoi FCM ---- */
async function envoyer(jetonAppareil: string, titre: string, corps: string, donnees: Record<string, string>) {
  const acces = await jetonGoogle();
  const r = await fetch(
    `https://fcm.googleapis.com/v1/projects/${COMPTE.project_id}/messages:send`, {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + acces, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: jetonAppareil,
          notification: { title: titre, body: corps },
          data: donnees,
          android: { priority: 'high', notification: { sound: 'default' } },
        },
      }),
    });
  return { ok: r.ok, statut: r.status, reponse: await r.text() };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: entetesCORS });

  try {
    const autorisation = req.headers.get('Authorization') ?? '';
    if (!autorisation.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ erreur: 'Jeton manquant' }),
        { status: 401, headers: { ...entetesCORS, 'Content-Type': 'application/json' } });
    }

    const { contrat_id, titre, corps, urgent, test } = await req.json();
    if (!titre) throw new Error('titre requis');
    if (!contrat_id && !test) throw new Error('contrat_id requis');
    console.log(`demande | contrat=${contrat_id ?? '(test)'} titre="${titre}" urgent=${!!urgent} test=${!!test}`);
    if (!COMPTE.client_email) console.error('FCM_COMPTE_SERVICE absent ou illisible');

    // Première vérification : le contrat est lu avec les droits de l'appelant.
    // S'il n'y appartient pas, la règle d'accès ne renvoie rien. La clé passée
    // ici n'est qu'un laissez-passer réseau ; c'est l'en-tête Authorization
    // qui fixe l'identité, donc les règles s'appliquent bien à l'appelant.
    const commeUtilisateur = createClient(URL_SUPABASE, CLE_SERVICE, {
      global: { headers: { Authorization: autorisation } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    // On identifie l'appelant à partir de son propre jeton, explicitement.
    const { data: utilisateur } = await commeUtilisateur.auth.getUser(autorisation.slice(7));
    if (!utilisateur?.user) throw new Error('Session invalide');
    console.log('appelant identifié : ' + utilisateur.user.id);

    // Mode test : l'appelant s'envoie une notification a lui-meme. Sert a
    // verifier la chaine complete sans dependre d'un contrat ni d'un tiers.
    let destinataire: string | null = null;
    if (test) {
      destinataire = utilisateur.user.id;
      console.log('mode test : destinataire = appelant');
    }

    const { data: contrat } = test ? { data: null } : await commeUtilisateur
      .from('contrats')
      .select('id, employeur_id, coparent_id, salariee_id')
      .eq('id', contrat_id)
      .maybeSingle();
    if (!test) {
      if (!contrat) throw new Error('Contrat inaccessible');
      console.log(`appelant=${utilisateur.user.id} employeur=${contrat.employeur_id} coparent=${contrat.coparent_id} salariee=${contrat.salariee_id}`);

      // Le destinataire est l'autre partie, jamais l'expéditeur. Le co-parent
      // compte comme parent : sans cela, sa notification lui reviendrait.
      const moi = utilisateur.user.id;
      const coteParent = contrat.employeur_id === moi || contrat.coparent_id === moi;
      destinataire = coteParent ? contrat.salariee_id : contrat.employeur_id;
    }
    if (!destinataire) {
      console.warn('aucun destinataire : le contrat n\'a pas de seconde partie');
      return new Response(JSON.stringify({ envoyes: 0, raison: 'aucun destinataire' }),
        { headers: { ...entetesCORS, 'Content-Type': 'application/json' } });
    }

    // Les jetons ne sont lisibles que par leur propriétaire : cette lecture
    // exige la clé de service, et c'est la seule chose qu'elle sert ici.
    const commeService = createClient(URL_SUPABASE, CLE_SERVICE, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    // Mode silencieux du destinataire. L'urgent passe toujours, le test aussi.
    if (!urgent && !test) {
      const { data: pref } = await commeService
        .from('profils')
        .select('silence_weekend, silence_du, silence_au')
        .eq('id', destinataire)
        .maybeSingle();
      if (pref) {
        // heure de Paris : le week-end est celui du destinataire, pas du serveur
        const maintenant = new Date(new Date().toLocaleString('en-US', { timeZone: 'Europe/Paris' }));
        const jour = maintenant.getDay();
        const aujourdhui = maintenant.toISOString().slice(0, 10);
        const weekend = pref.silence_weekend && (jour === 0 || jour === 6);
        const periode = pref.silence_du && pref.silence_au && aujourdhui >= pref.silence_du && aujourdhui <= pref.silence_au;
        if (weekend || periode) {
          console.log(`mode silencieux actif pour ${destinataire} (weekend=${weekend} periode=${periode})`);
          return new Response(JSON.stringify({ envoyes: 0, raison: 'mode silencieux' }),
            { headers: { ...entetesCORS, 'Content-Type': 'application/json' } });
        }
      }
    }
    const { data: jetons } = await commeService
      .from('jetons_push')
      .select('jeton')
      .eq('personne_id', destinataire);

    if (!jetons?.length) {
      console.warn(`aucun jeton pour ${destinataire} : la table jetons_push est vide pour cette personne`);
      return new Response(JSON.stringify({ envoyes: 0, raison: 'aucun appareil enregistré' }),
        { headers: { ...entetesCORS, 'Content-Type': 'application/json' } });
    }

    console.log(`${jetons.length} appareil(s) pour le destinataire`);
    let envoyes = 0;
    const perimes: string[] = [];
    for (const j of jetons) {
      const r = await envoyer(j.jeton, titre, corps ?? '', { contrat_id: String(contrat_id ?? '') });
      if (r.ok) { envoyes++; console.log('envoi accepté par Firebase'); }
      else {
        console.error(`Firebase a refusé (${r.statut}) : ${r.reponse.slice(0, 300)}`);
        if (r.statut === 404 || r.statut === 400) perimes.push(j.jeton);
      }
    }

    // Un appareil désinstallé garde un jeton mort : on le retire.
    if (perimes.length) await commeService.from('jetons_push').delete().in('jeton', perimes);

    return new Response(JSON.stringify({ envoyes, retires: perimes.length }),
      { headers: { ...entetesCORS, 'Content-Type': 'application/json' } });

  } catch (e) {
    console.error('echec : ' + String((e as Error).message ?? e));
    return new Response(JSON.stringify({ erreur: String((e as Error).message ?? e) }),
      { status: 400, headers: { ...entetesCORS, 'Content-Type': 'application/json' } });
  }
});
