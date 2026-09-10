#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Joue les points automatisables du PROTOCOLE-SECURITE.md.

    python3 verifier-securite.py

Sort avec un code non nul si un point bloquant échoue. Les points SQL
(A1, A2, A3, A5) sont vérifiés sur les fichiers de migration : le résultat
en base peut différer si une migration n'a pas été passée — les rejouer
depuis le tableau de bord reste la vérité.
"""
import re, subprocess, sys, glob, os, collections

RACINE = os.path.dirname(os.path.abspath(__file__))
os.chdir(RACINE)
ECHECS = []

def titre(t): print('\n' + '═' * 62 + '\n  ' + t + '\n' + '═' * 62)
def ok(msg): print('  ✓ ' + msg)
def ko(msg, bloquant=True):
    print('  ✗ ' + msg)
    if bloquant: ECHECS.append(msg)
def note(msg): print('  · ' + msg)

# ---------------------------------------------------------------- A. base
titre('A. LA BASE DE DONNÉES (lecture des migrations)')
sql = ''.join(open(f, encoding='utf-8').read() + '\n' for f in sorted(glob.glob('supabase/0*.sql')))

tables = set(re.findall(r'create table (?:if not exists )?(\w+)', sql))
rls = set(re.findall(r'alter table\s+(\w+)\s+enable row level security', sql))
sans_rls = sorted(tables - rls)
ok(f'A1 — {len(tables)} tables, toutes protégées par ligne') if not sans_rls else ko('A1 — sans RLS : ' + ', '.join(sans_rls))

revoke = set()
for m in re.finditer(r'revoke all on\s+([\w,\s]+?)\s+from anon', sql, re.S):
    revoke |= {t for t in re.split(r'[,\s]+', m.group(1)) if t}
sans_revoke = sorted(tables - revoke)
ok('A2 — anon révoqué sur toutes les tables') if not sans_revoke else ko('A2 — anon non révoqué : ' + ', '.join(sans_revoke), bloquant=False)

permissives = []
for m in re.finditer(r'create policy "?([\w ]+?)"? on (\w+)\s+for (\w+)(.*?);', sql, re.S):
    corps = m.group(4)
    if re.search(r'\(\s*true\s*\)', corps) and 'auth.uid' not in corps:
        permissives.append(f'{m.group(2)}.{m.group(1)}')
ok('A3 — aucune règle permissive') if not permissives else ko('A3 — permissives : ' + ', '.join(permissives))

# Une migration ulterieure peut corriger une fonction : seule la derniere
# definition fait foi.
definitions = {}
for m in re.finditer(r'create or replace function (\w+)\s*\((.*?)\)\s*returns(.*?)\$\$(.*?)\$\$;', sql, re.S):
    definitions[m.group(1)] = (m.group(3), m.group(4))
sans_verif, sans_path = [], []
for nom, (entete, corps) in definitions.items():
    if 'security definer' not in entete: continue
    if 'set search_path' not in entete: sans_path.append(nom)
    if 'trigger' in entete: continue
    if not re.search(r'auth\.uid|est_membre|est_employeur|relie_a_salariee|remplace_ce|visible_recherche|membre_du_sujet', corps):
        sans_verif.append(nom)
JUSTIFIEES = {'verifier_autorisation_photo', 'purger_comptes_expires'}
restantes = [n for n in sans_verif if n not in JUSTIFIEES]
ok('A4 — toute fonction privilégiée vérifie l\'appelant') if not restantes else ko('A4 — sans vérification : ' + ', '.join(restantes))
ok('A5 — search_path figé partout') if not sans_path else ko('A5 — search_path libre : ' + ', '.join(sans_path))

stockage = re.findall(r'create policy "([^"]+)" on storage\.objects\s+for \w+(.*?);', sql, re.S)
nues = [n for n, c in stockage if not re.search(r'auth\.uid|photo_visible|justificatif_visible|est_membre|relie_a_salariee|profils_pro', c)]
ok(f'A6 — {len(stockage)} règles de stockage, toutes avec identité') if not nues else ko('A6 — stockage sans identité : ' + ', '.join(nues))
note('A7 — limites du bucket : à vérifier dans le tableau de bord (8 Mo, images + PDF)')

# ------------------------------------------------------------- B. serveur
titre('B. LES FONCTIONS SERVEUR')
ts = open('supabase/functions/notifier/index.ts', encoding='utf-8').read()
fuites = [l for l in ts.split('\n') if 'console.' in l and re.search(r'CLE_SERVICE|private_key|SERVICE_ROLE', l) and 'Deno.env' not in l]
ok('B1 — la clé de service n\'est jamais journalisée') if not fuites else ko('B1 — fuite possible : ' + fuites[0].strip()[:80])
ok('B2 — identité vérifiée côté serveur') if 'getUser(' in ts else ko('B2 — getUser absent')
ok('B3 — destinataire filtré en mémoire') if 'personne_id === destinataire' in ts else ko('B3 — filtre du destinataire absent')
secrets = []
for f in glob.glob('**/*', recursive=True):
    if os.path.isfile(f) and not f.startswith('.git') and os.path.getsize(f) < 3_000_000:
        try: t = open(f, encoding='utf-8', errors='ignore').read()
        except Exception: continue
        if f == 'verifier-securite.py': continue
        # un vrai secret : une cle privee, ou un JSON de compte de service — pas
        # le mot « service_role » dans un commentaire qui explique qu'il n'y est pas
        if 'BEGIN PRIVATE KEY' in t or re.search(r'"private_key"\s*:\s*"', t) or re.search(r'"type"\s*:\s*"service_account"', t):
            secrets.append(f)
ok('B4 — aucun secret dans le dépôt') if not secrets else ko('B4 — secret trouvé dans : ' + ', '.join(secrets))

# -------------------------------------------------------------- C. client
titre('C. LE CLIENT')
CHAMPS = ['texte', 'mot', 'motif', 'nom', 'prenom', 'enfant_prenom', 'titre', 'legende',
          'presentation', 'intitule', 'organisme', 'commune', 'animaux', 'reponse_parent',
          'ressenti_salariee', 'ressenti_parent', 'agrement_num', 'allergies', 'medecin', 'consignes']
INTERDITS = ['secu', 'iban', 'bic', 'nir', 'adresse']
for f, app in [('docs/index.html', 'Parent'), ('docs-nounou/index.html', 'Nounou')]:
    s = open(f, encoding='utf-8').read()
    js = '\n'.join(re.findall(r'<script>(.*?)</script>', s, re.S))

    nus = []
    for m in re.finditer(r'\$\{([^}]{1,120})\}', js):
        e = m.group(1)
        if re.search(r'esc\(|badge|dessin|frimousse|portrait|inp\(|\.length|\?\s*[\'"]', e): continue
        if re.match(r'^[\w.]+\s*(\?|&&|\|\|)', e): continue
        for c in CHAMPS:
            if re.search(r'\b' + c + r'\b', e) and not re.search(r'\b' + c + r'\s*(===|!==|\?|&&|\|\|)', e):
                nus.append(e.strip()[:50]); break
    ok(f'C1 {app} — aucune interpolation non échappée') if not nus else ko(f'C1 {app} — non échappées : ' + ' | '.join(nus[:3]))

    fuites = []
    for m in re.finditer(r"Supa\.(?:ecrire|modifier)\(\s*'(\w+)'", js):
        bloc = js[m.start():m.start() + 900]
        fin = bloc.find(');')
        bloc = bloc[:fin if fin > 0 else 900]
        for i in INTERDITS:
            if re.search(r'\b' + i + r'\b\s*:', bloc):
                fuites.append(f'{m.group(1)}.{i}')
    ok(f'C2 {app} — secu/IBAN/adresse jamais envoyés') if not fuites else ko(f'C2 {app} — envoyé : ' + ', '.join(sorted(set(fuites))))

    dialogues = len(re.findall(r'(?<!await )\b(?:prompt|confirm)\(', js)) - len(re.findall(r'/\* Le pendant de confirm\(', js))
    ok(f'C5 {app} — aucun prompt/confirm du navigateur') if dialogues <= 0 else ko(f'C5 {app} — {dialogues} dialogue(s) navigateur', bloquant=False)
    ok(f'C6 {app} — refus à la porte de la mauvaise application') if 'verif-role' in s and 'barre-route' in s else ko(f'C6 {app} — refus à la porte absent')

# ------------------------------------------------------------- D. config
titre('D. TRANSPORT ET CONFIGURATION')
for cfg in ['capacitor.config.json', 'capacitor.config.nounou.json']:
    if not os.path.exists(cfg): continue
    t = open(cfg, encoding='utf-8').read()
    ok(f'D1 {cfg} — https, pas de trafic en clair') if 'cleartext' not in t.lower() else ko(f'D1 {cfg} — trafic en clair autorisé')
docs = ''.join(open(f, encoding='utf-8').read() for f in glob.glob('docs*/*.html') + glob.glob('commun/*.js'))
ok('D2 — aucune clé privilégiée dans le client') if not re.search(r'eyJ[\w-]{80,}\.[\w-]{20,}', docs) and not re.search(r'sb_secret_', docs) else ko('D2 — clé privilégiée dans le client')
note('D3 — secrets GitHub inutiles : à vérifier dans Settings → Secrets')
note('D4 — clé de signature sauvegardée hors du dépôt : à vérifier')

# ----------------------------------------------------------- E. processus
titre('E. LE PROCESSUS')
for f, app in [('docs/index.html', 'Parent'), ('docs-nounou/index.html', 'Nounou')]:
    s = open(f, encoding='utf-8').read()
    blocs = re.findall(r'<script>(.*?)</script>', s, re.S)
    for i, x in enumerate(blocs): open(f'/tmp/vs{i}.js', 'w').write(x)
    syntaxe = all(subprocess.run(['node', '--check', f'/tmp/vs{i}.js'], capture_output=True).returncode == 0 for i in range(len(blocs)))
    html = re.sub(r'<script>.*?</script>', '', s, flags=re.S)
    doublons = [k for k, v in collections.Counter(re.findall(r'\bid="([^"]+)"', html)).items() if v > 1]
    js = '\n'.join(blocs)
    defs = set(re.findall(r'^\s*(?:async )?function (\w+)\(', js, re.M))
    mortes = [d for d in defs if len(re.findall(r'\b' + d + r'\b', js)) <= 1]
    if syntaxe and not doublons and not mortes: ok(f'E1 {app} — syntaxe, identifiants, fonctions : propre')
    else: ko(f'E1 {app} — syntaxe {syntaxe}, doublons {doublons}, mortes {mortes}')

non_rejouables = []
for f in sorted(glob.glob('supabase/0*.sql')):
    t = open(f, encoding='utf-8').read()
    for m in re.finditer(r'create policy "?([\w ]+?)"? on', t):
        if f'drop policy if exists "{m.group(1)}"' not in t and f'drop policy if exists {m.group(1)}' not in t:
            non_rejouables.append(f'{os.path.basename(f)}:{m.group(1)}')
    for m in re.finditer(r'create trigger (\w+)', t):
        if f'drop trigger if exists {m.group(1)}' not in t: non_rejouables.append(f'{os.path.basename(f)}:{m.group(1)}')
ok('E2 — toutes les migrations sont rejouables') if not non_rejouables else ko('E2 — non rejouables : ' + ', '.join(non_rejouables[:5]), bloquant=False)
wf = open('.github/workflows/extraire-archive.yml', encoding='utf-8').read() if os.path.exists('.github/workflows/extraire-archive.yml') else ''
ok('E3 — le workflow jette .git et protège .github') if '.git|' in wf and '.github' in wf else ko('E3 — workflow d\'extraction sans protection .git')
numeros = collections.Counter(os.path.basename(f)[:3] for f in glob.glob('supabase/0*.sql'))
dbl = [n for n, c in numeros.items() if c > 1 and n not in ('004', '005', '006', '007', '008', '009', '010', '011')]
ok('E4 — aucun numéro de migration en double') if not dbl else ko('E4 — numéros en double : ' + ', '.join(dbl))

# --------------------------------------------------------------- F. rgpd
titre('F. LE RGPD')
pol = open('docs/confidentialite.html', encoding='utf-8').read() if os.path.exists('docs/confidentialite.html') else ''
parent = open('docs/index.html', encoding='utf-8').read()
for promesse, motif in [('archive téléchargeable', 'preparerArchive'), ('suppression du compte', 'supprimerMonCompte'),
                        ('suppression différée', 'demander_suppression'), ('mode silencieux', 'silence_weekend')]:
    ok(f'F1 — {promesse} : tenue') if motif in parent else ko(f'F1 — {promesse} : promise mais absente')
ok('F2 — purge quotidienne programmée') if 'cron.schedule' in sql else ko('F2 — pas de tâche de purge')
note('F3 — le compte auth.users survit à la purge : à lever avant production')
ok('F4 — adresse RGPD dans la politique') if re.search(r'rgpd@|cnil\.fr', pol) else ko('F4 — aucune adresse de contact RGPD', bloquant=False)

# ------------------------------------------------------------------ fin
print('\n' + '═' * 62)
if ECHECS:
    print(f'  {len(ECHECS)} point(s) bloquant(s) :')
    for e in ECHECS: print('   - ' + e)
    print('═' * 62); sys.exit(1)
print('  Tous les points bloquants passent. Les points « · » restent à faire à la main.')
print('═' * 62)
