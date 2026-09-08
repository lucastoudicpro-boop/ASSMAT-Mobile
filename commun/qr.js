/* Encodeur QR — mode octet, correction M, versions 1 à 10.
   Écrit à la main : l'application ne charge aucun script externe et doit
   rester utilisable hors connexion. */
const QR = (() => {

  /* ---- Corps de Galois GF(256), polynôme 0x11D ---- */
  const EXP = new Uint8Array(512), LOG = new Uint8Array(256);
  (() => {
    let x = 1;
    for (let i = 0; i < 255; i++) {
      EXP[i] = x; LOG[x] = i;
      x <<= 1; if (x & 0x100) x ^= 0x11d;
    }
    for (let i = 255; i < 512; i++) EXP[i] = EXP[i - 255];
  })();
  const mul = (a, b) => (a === 0 || b === 0) ? 0 : EXP[LOG[a] + LOG[b]];

  /* ---- Reed-Solomon ---- */
  function generateur(n) {
    let g = [1];
    for (let i = 0; i < n; i++) {
      const suivant = new Array(g.length + 1).fill(0);
      for (let j = 0; j < g.length; j++) {
        suivant[j] ^= mul(g[j], EXP[i]);
        suivant[j + 1] ^= g[j];
      }
      g = suivant;
    }
    // La division qui suit lit les coefficients du plus haut degré au plus bas.
    return g.reverse();
  }

  function correction(donnees, n) {
    const g = generateur(n);
    const reste = new Array(n).fill(0);
    for (const octet of donnees) {
      const facteur = octet ^ reste[0];
      reste.shift(); reste.push(0);
      if (facteur !== 0) for (let i = 0; i < n; i++) reste[i] ^= mul(g[i + 1], facteur);
    }
    return reste;
  }

  /* ---- Tables de la norme, niveau M, versions 1 à 10 ----
     [octets de correction par bloc, blocs groupe 1, données groupe 1,
      blocs groupe 2, données groupe 2] */
  const BLOCS = {
    1:  [10, 1, 16, 0, 0],
    2:  [16, 1, 28, 0, 0],
    3:  [26, 1, 44, 0, 0],
    4:  [18, 2, 32, 0, 0],
    5:  [24, 2, 43, 0, 0],
    6:  [16, 4, 27, 0, 0],
    7:  [18, 4, 31, 0, 0],
    8:  [22, 2, 38, 2, 39],
    9:  [22, 3, 36, 2, 37],
    10: [26, 4, 43, 1, 44]
  };

  const ALIGNEMENTS = {
    1: [], 2: [6, 18], 3: [6, 22], 4: [6, 26], 5: [6, 30],
    6: [6, 34], 7: [6, 22, 38], 8: [6, 24, 42], 9: [6, 26, 46], 10: [6, 28, 50]
  };

  const donneesTotales = v => {
    const [, b1, d1, b2, d2] = BLOCS[v];
    return b1 * d1 + b2 * d2;
  };

  const bitsCompteur = v => (v <= 9 ? 8 : 16);

  function choisirVersion(n) {
    for (let v = 1; v <= 10; v++) {
      const dispo = donneesTotales(v) * 8 - 4 - bitsCompteur(v);
      if (n * 8 <= dispo) return v;
    }
    return null;
  }

  /* ---- Flux binaire ---- */
  function fluxBinaire(octets, v) {
    const bits = [];
    const pousser = (val, n) => { for (let i = n - 1; i >= 0; i--) bits.push((val >> i) & 1); };

    pousser(0b0100, 4);                       // mode octet
    pousser(octets.length, bitsCompteur(v));
    for (const o of octets) pousser(o, 8);

    const capacite = donneesTotales(v) * 8;
    for (let i = 0; i < 4 && bits.length < capacite; i++) bits.push(0);   // terminateur
    while (bits.length % 8) bits.push(0);

    const mots = [];
    for (let i = 0; i < bits.length; i += 8) {
      let o = 0;
      for (let j = 0; j < 8; j++) o = (o << 1) | bits[i + j];
      mots.push(o);
    }
    const remplissage = [0xec, 0x11];
    let k = 0;
    while (mots.length < donneesTotales(v)) mots.push(remplissage[k++ % 2]);
    return mots;
  }

  /* ---- Découpe en blocs et entrelacement ---- */
  function motsFinaux(mots, v) {
    const [nEc, b1, d1, b2, d2] = BLOCS[v];
    const blocsDonnees = [], blocsEc = [];
    let pos = 0;
    for (let i = 0; i < b1; i++) { const b = mots.slice(pos, pos + d1); pos += d1; blocsDonnees.push(b); blocsEc.push(correction(b, nEc)); }
    for (let i = 0; i < b2; i++) { const b = mots.slice(pos, pos + d2); pos += d2; blocsDonnees.push(b); blocsEc.push(correction(b, nEc)); }

    const sortie = [];
    const maxD = Math.max(d1, d2);
    for (let i = 0; i < maxD; i++)
      for (const b of blocsDonnees) if (i < b.length) sortie.push(b[i]);
    for (let i = 0; i < nEc; i++)
      for (const b of blocsEc) sortie.push(b[i]);
    return sortie;
  }

  /* ---- Motifs fixes ---- */
  function grilleVide(v) {
    const t = v * 4 + 17;
    const m = Array.from({ length: t }, () => new Array(t).fill(null));
    const reserve = Array.from({ length: t }, () => new Array(t).fill(false));

    const finder = (l, c) => {
      for (let i = -1; i <= 7; i++) for (let j = -1; j <= 7; j++) {
        const y = l + i, x = c + j;
        if (y < 0 || y >= t || x < 0 || x >= t) continue;
        const dedans = i >= 0 && i <= 6 && j >= 0 && j <= 6;
        const noir = dedans && (i === 0 || i === 6 || j === 0 || j === 6 ||
                                (i >= 2 && i <= 4 && j >= 2 && j <= 4));
        m[y][x] = noir ? 1 : 0; reserve[y][x] = true;
      }
    };
    finder(0, 0); finder(0, t - 7); finder(t - 7, 0);

    for (let i = 8; i < t - 8; i++) {
      const noir = i % 2 === 0 ? 1 : 0;
      m[6][i] = noir; reserve[6][i] = true;
      m[i][6] = noir; reserve[i][6] = true;
    }

    // Un motif d'alignement est omis uniquement s'il chevauche un motif de
    // recherche, jamais parce qu'il croise la ligne de synchronisation.
    const dernier = ALIGNEMENTS[v][ALIGNEMENTS[v].length - 1];
    for (const cy of ALIGNEMENTS[v]) for (const cx of ALIGNEMENTS[v]) {
      if ((cy === 6 && cx === 6) || (cy === 6 && cx === dernier) || (cy === dernier && cx === 6)) continue;
      for (let i = -2; i <= 2; i++) for (let j = -2; j <= 2; j++) {
        const noir = (Math.abs(i) === 2 || Math.abs(j) === 2 || (i === 0 && j === 0)) ? 1 : 0;
        m[cy + i][cx + j] = noir; reserve[cy + i][cx + j] = true;
      }
    }

    m[t - 8][8] = 1; reserve[t - 8][8] = true;               // module toujours noir

    for (let i = 0; i < 9; i++) {                             // zones du format
      if (!reserve[8][i]) { reserve[8][i] = true; m[8][i] = 0; }
      if (!reserve[i][8]) { reserve[i][8] = true; m[i][8] = 0; }
    }
    for (let i = 0; i < 8; i++) {
      if (!reserve[8][t - 1 - i]) { reserve[8][t - 1 - i] = true; m[8][t - 1 - i] = 0; }
      if (!reserve[t - 1 - i][8]) { reserve[t - 1 - i][8] = true; m[t - 1 - i][8] = 0; }
    }

    if (v >= 7) {                                             // zones de la version
      for (let i = 0; i < 6; i++) for (let j = 0; j < 3; j++) {
        reserve[i][t - 11 + j] = true; m[i][t - 11 + j] = 0;
        reserve[t - 11 + j][i] = true; m[t - 11 + j][i] = 0;
      }
    }
    return { m, reserve, t };
  }

  /* ---- Placement en zigzag ---- */
  function placer(m, reserve, t, mots) {
    const bits = [];
    for (const o of mots) for (let i = 7; i >= 0; i--) bits.push((o >> i) & 1);

    let k = 0, montant = true;
    for (let col = t - 1; col > 0; col -= 2) {
      if (col === 6) col--;
      for (let n = 0; n < t; n++) {
        const ligne = montant ? t - 1 - n : n;
        for (const c of [col, col - 1]) {
          if (reserve[ligne][c]) continue;
          m[ligne][c] = k < bits.length ? bits[k++] : 0;
        }
      }
      montant = !montant;
    }
  }

  const MASQUES = [
    (l, c) => (l + c) % 2 === 0,
    (l) => l % 2 === 0,
    (l, c) => c % 3 === 0,
    (l, c) => (l + c) % 3 === 0,
    (l, c) => (Math.floor(l / 2) + Math.floor(c / 3)) % 2 === 0,
    (l, c) => ((l * c) % 2) + ((l * c) % 3) === 0,
    (l, c) => (((l * c) % 2) + ((l * c) % 3)) % 2 === 0,
    (l, c) => (((l + c) % 2) + ((l * c) % 3)) % 2 === 0
  ];

  function formatBits(masque) {
    const donnees = (0b00 << 3) | masque;          // 00 = niveau M
    let reste = donnees << 10;
    for (let i = 4; i >= 0; i--)
      if (reste & (1 << (i + 10))) reste ^= 0b10100110111 << i;
    return ((donnees << 10) | reste) ^ 0b101010000010010;
  }

  function versionBits(v) {
    let reste = v << 12;
    for (let i = 5; i >= 0; i--)
      if (reste & (1 << (i + 12))) reste ^= 0b1111100100101 << i;
    return (v << 12) | reste;
  }

  function penalite(m, t) {
    let p = 0;

    const serie = (lire) => {
      for (let a = 0; a < t; a++) {
        let compte = 1;
        for (let b = 1; b < t; b++) {
          if (lire(a, b) === lire(a, b - 1)) { compte++; }
          else { if (compte >= 5) p += 3 + (compte - 5); compte = 1; }
        }
        if (compte >= 5) p += 3 + (compte - 5);
      }
    };
    serie((a, b) => m[a][b]);
    serie((a, b) => m[b][a]);

    for (let l = 0; l < t - 1; l++) for (let c = 0; c < t - 1; c++)
      if (m[l][c] === m[l][c + 1] && m[l][c] === m[l + 1][c] && m[l][c] === m[l + 1][c + 1]) p += 3;

    const MOTIF = [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 0];
    const cherche = (lire) => {
      for (let a = 0; a < t; a++) for (let b = 0; b <= t - 11; b++) {
        let ok = true;
        for (let i = 0; i < 11; i++) if (lire(a, b + i) !== MOTIF[i]) { ok = false; break; }
        if (ok) p += 40;
        ok = true;
        for (let i = 0; i < 11; i++) if (lire(a, b + i) !== MOTIF[10 - i]) { ok = false; break; }
        if (ok) p += 40;
      }
    };
    cherche((a, b) => m[a][b]);
    cherche((a, b) => m[b][a]);

    let noirs = 0;
    for (let l = 0; l < t; l++) for (let c = 0; c < t; c++) noirs += m[l][c];
    const pourcent = noirs * 100 / (t * t);
    p += Math.floor(Math.abs(pourcent - 50) / 5) * 10;
    return p;
  }

  /* ---- Point d'entrée : renvoie une matrice de 0 et de 1 ---- */
  function matrice(texte) {
    const octets = [...new TextEncoder().encode(String(texte))];
    const v = choisirVersion(octets.length);
    if (!v) throw new Error('Texte trop long pour un QR de cette taille');

    const mots = motsFinaux(fluxBinaire(octets, v), v);
    let meilleure = null, meilleurScore = Infinity;

    for (let masque = 0; masque < 8; masque++) {
      const { m, reserve, t } = grilleVide(v);
      placer(m, reserve, t, mots);

      for (let l = 0; l < t; l++) for (let c = 0; c < t; c++)
        if (!reserve[l][c] && MASQUES[masque](l, c)) m[l][c] ^= 1;

      // Les quinze bits du format sont écrits deux fois. L'ordre suit la norme :
      // bit 0 en haut de la colonne 8 et à droite de la ligne 8.
      const f = formatBits(masque);
      for (let i = 0; i < 15; i++) {
        const bit = (f >> i) & 1;

        if (i < 6) m[i][8] = bit;
        else if (i < 8) m[i + 1][8] = bit;
        else m[t - 15 + i][8] = bit;

        if (i < 8) m[8][t - 1 - i] = bit;
        else if (i === 8) m[8][7] = bit;
        else m[8][14 - i] = bit;
      }
      m[t - 8][8] = 1;

      if (v >= 7) {
        const vb = versionBits(v);
        for (let i = 0; i < 18; i++) {
          const bit = (vb >> i) & 1;
          const l = Math.floor(i / 3), c = i % 3;
          m[l][t - 11 + c] = bit;
          m[t - 11 + c][l] = bit;
        }
      }

      const score = penalite(m, t);
      if (score < meilleurScore) { meilleurScore = score; meilleure = m; }
    }
    return meilleure;
  }

  /* ---- Rendu SVG ---- */
  function svg(texte, taille, marge) {
    const m = matrice(texte);
    const t = m.length;
    const q = marge === undefined ? 4 : marge;
    const total = t + q * 2;
    let chemin = '';
    for (let l = 0; l < t; l++) for (let c = 0; c < t; c++)
      if (m[l][c]) chemin += `M${c + q} ${l + q}h1v1h-1z`;
    return `<svg viewBox="0 0 ${total} ${total}" width="${taille || 200}" height="${taille || 200}" ` +
           `shape-rendering="crispEdges" xmlns="http://www.w3.org/2000/svg">` +
           `<rect width="${total}" height="${total}" fill="#fff"/>` +
           `<path d="${chemin}" fill="#000"/></svg>`;
  }

  return { matrice, svg };
})();
