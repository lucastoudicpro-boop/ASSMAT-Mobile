#!/usr/bin/env python3
"""Déclare l'icône de notification dans le manifeste Android.

Android n'utilise pas l'icône de l'application dans la barre d'état : il exige
une silhouette monochrome. Faute de déclaration, il réduit l'icône colorée à un
rond blanc. On désigne donc ic_stat_cocon, et une couleur de teinte.
"""
import json, os, re, sys

config = sys.argv[1] if len(sys.argv) > 1 else 'capacitor.config.json'
teinte = json.load(open(config, encoding='utf-8')).get('teinte', '#2f7d73')

# la couleur, dans une ressource à part pour ne rien écraser
os.makedirs('android/app/src/main/res/values', exist_ok=True)
with open('android/app/src/main/res/values/couleurs_cocon.xml', 'w', encoding='utf-8') as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
            f'  <color name="cocon_notification">{teinte}</color>\n</resources>\n')

manifeste = 'android/app/src/main/AndroidManifest.xml'
s = open(manifeste, encoding='utf-8').read()

if 'default_notification_icon' in s:
    print('icone de notification : deja declaree')
    sys.exit(0)

bloc = (
    '\n        <meta-data\n'
    '            android:name="com.google.firebase.messaging.default_notification_icon"\n'
    '            android:resource="@drawable/ic_stat_cocon" />\n'
    '        <meta-data\n'
    '            android:name="com.google.firebase.messaging.default_notification_color"\n'
    '            android:resource="@color/cocon_notification" />\n'
)

if '</application>' not in s:
    print('::error::balise </application> introuvable dans le manifeste')
    sys.exit(1)

s = s.replace('</application>', bloc + '    </application>', 1)
open(manifeste, 'w', encoding='utf-8').write(s)
print(f'icone de notification declaree, teinte {teinte}')
