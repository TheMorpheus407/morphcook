/// Settings + backup/restore copy. Registered in main.dart.
const Map<String, Map<String, String>> strings = {
  'settings.title': {'en': 'settings', 'de': 'einstellungen'},

  // ---- you ----------------------------------------------------------------
  'settings.section.you': {'en': 'you', 'de': 'du'},
  'settings.name.label': {'en': 'your name', 'de': 'dein name'},
  'settings.name.hint': {
    'en': 'what should we call you?',
    'de': 'wie sollen wir dich nennen?',
  },
  'settings.language.label': {'en': 'language', 'de': 'sprache'},
  'settings.language.en': {'en': 'english', 'de': 'english'},
  'settings.language.de': {'en': 'deutsch', 'de': 'deutsch'},

  // ---- avoid ----------------------------------------------------------------
  'settings.section.avoid': {
    'en': 'things you avoid',
    'de': 'was du vermeidest',
  },
  'settings.avoid.diets': {
    'en': 'diets & lifestyles',
    'de': 'ernährungsweisen',
  },
  'settings.avoid.classes': {
    'en': 'ingredient classes',
    'de': 'zutatenklassen',
  },
  'settings.avoid.specific': {
    'en': 'specific ingredients',
    'de': 'einzelne zutaten',
  },
  'settings.avoid.searchHint': {
    'en': 'type an ingredient…',
    'de': 'zutat eingeben…',
  },
  'settings.avoid.noMatches': {
    'en': 'no matches — maybe it\'s already covered above',
    'de': 'nichts gefunden — vielleicht oben schon abgedeckt',
  },

  // ---- requirements -----------------------------------------------------------
  'settings.section.requirements': {
    'en': 'requirements',
    'de': 'anforderungen',
  },
  'settings.requirements.hint': {
    'en': 'only show recipes that fit',
    'de': 'nur passende rezepte zeigen',
  },
  'settings.halal.note': {
    'en':
        'we never claim halal- or kosher-certification — these filters match compatible ingredients only. certification is about sourcing, not recipe text.',
    'de':
        'wir erheben keinen anspruch auf halal- oder koscher-zertifizierung — diese filter prüfen nur kompatible zutaten. zertifizierung ist eine frage der herkunft, nicht des rezepttexts.',
  },

  // ---- cooking ------------------------------------------------------------------
  'settings.section.cooking': {'en': 'cooking', 'de': 'kochen'},
  'settings.effort.label': {
    'en': 'preferred effort',
    'de': 'bevorzugter aufwand',
  },
  'settings.time.label': {'en': 'max time', 'de': 'max. zeit'},
  'settings.calories.label': {
    'en': 'calorie target per meal',
    'de': 'kalorienziel pro mahlzeit',
  },

  // ---- interface ------------------------------------------------------------------
  'settings.section.interface': {'en': 'interface', 'de': 'oberfläche'},
  'settings.ui.variantTags': {
    'en': 'show variant tags',
    'de': 'varianten-labels zeigen',
  },
  'settings.ui.variantTags.sub': {
    'en': 'little labels on recipe cards (vegan, quick, …)',
    'de': 'kleine labels auf rezeptkarten (vegan, schnell, …)',
  },
  'settings.ui.visualAlert': {
    'en': 'flash alert when timers ring',
    'de': 'blitz-signal bei timern',
  },
  'settings.ui.visualAlert.sub': {
    'en':
        'a screen flash, not just sound — made for deaf & hard-of-hearing cooks',
    'de':
        'ein bildschirmblitz, nicht nur ton — für gehörlose & schwerhörige köch:innen',
  },
  'settings.ui.quickNext': {
    'en': 'one-handed tap-to-advance',
    'de': 'einhand-tippen zum weitergehen',
  },
  'settings.ui.quickNext.sub': {
    'en': 'opt-in: tap anywhere in cook mode for the next step',
    'de': 'opt-in: im kochmodus irgendwo tippen für den nächsten schritt',
  },
  'settings.ui.reduceMotion': {
    'en': 'reduce motion',
    'de': 'bewegung reduzieren',
  },
  'settings.motion.system': {'en': 'system', 'de': 'system'},
  'settings.motion.on': {'en': 'on', 'de': 'an'},
  'settings.motion.off': {'en': 'off', 'de': 'aus'},

  // ---- more -----------------------------------------------------------------------
  'settings.section.more': {'en': 'more', 'de': 'mehr'},
  'settings.insights': {'en': 'shopping insights', 'de': 'einkaufs-statistik'},
  'settings.faq': {'en': 'help & faq', 'de': 'hilfe & faq'},

  // ---- backup -----------------------------------------------------------------------
  'settings.backup.section': {
    'en': 'backup & restore',
    'de': 'sicherung & wiederherstellung',
  },
  'backup.export': {'en': 'export backup', 'de': 'backup exportieren'},
  'backup.import': {
    'en': 'restore from backup',
    'de': 'aus backup wiederherstellen',
  },
  'backup.password.label': {
    'en': 'password (optional)',
    'de': 'passwort (optional)',
  },
  'backup.password.hint': {
    'en': 'the .json gets encrypted with this — the .gz stays unencrypted',
    'de': 'die .json wird damit verschlüsselt — die .gz bleibt unverschlüsselt',
  },
  'backup.export.success': {
    'en': 'backup ready — pick where to keep it',
    'de': 'backup fertig — such dir einen ort dafür',
  },
  'backup.export.failure': {
    'en': 'export failed — please try again',
    'de': 'export fehlgeschlagen — bitte nochmal versuchen',
  },
  'backup.import.success': {
    'en': 'welcome back — your data was restored',
    'de': 'willkommen zurück — deine daten sind wieder da',
  },
  'backup.import.corpusNote': {
    'en': 'only your data is restored — the bundled cookbook is never touched',
    'de':
        'nur deine daten werden wiederhergestellt — das mitgelieferte kochbuch bleibt unberührt',
  },
  'backup.password.title': {
    'en': 'this backup is locked',
    'de': 'dieses backup ist geschützt',
  },
  'backup.password.body': {
    'en': 'enter the password you chose when exporting',
    'de': 'gib das passwort vom export ein',
  },
  'backup.password.confirm': {'en': 'unlock', 'de': 'entsperren'},
  'backup.merge.title': {
    'en': 'how should we restore?',
    'de': 'wie wiederherstellen?',
  },
  'backup.merge.body': {
    'en':
        'merge keeps your current data and adds the backup on top. replace wipes your current data first.',
    'de':
        'zusammenführen behält deine aktuellen daten und ergänzt das backup. ersetzen löscht vorher alles aktuelle.',
  },
  'backup.merge.merge': {'en': 'merge', 'de': 'zusammenführen'},
  'backup.merge.replace': {'en': 'replace', 'de': 'ersetzen'},
  'backup.error.title': {
    'en': 'hmm, that didn\'t work',
    'de': 'hmm, das hat nicht geklappt',
  },
  'backup.share.subject': {'en': 'morphcook backup', 'de': 'morphcook backup'},
};
