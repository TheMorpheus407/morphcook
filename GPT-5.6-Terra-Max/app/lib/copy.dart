import 'models.dart';

class Copybook {
  const Copybook._();

  static const _values = <String, LocalizedText>{
    'home': {'en': 'home', 'de': 'zuhause'},
    'discover': {'en': 'discover', 'de': 'entdecken'},
    'cookbook': {'en': 'cookbook', 'de': 'kochbuch'},
    'plan': {'en': 'plan', 'de': 'plan'},
    'settings': {'en': 'settings', 'de': 'einstellungen'},
    'shoppingList': {'en': 'shopping list', 'de': 'einkaufsliste'},
    'saved': {'en': 'saved', 'de': 'gespeichert'},
    'save': {'en': 'save recipe', 'de': 'rezept speichern'},
    'savedRecipe': {
      'en': 'saved to your cookbook',
      'de': 'in deinem kochbuch gespeichert',
    },
    'startCooking': {'en': 'start cooking', 'de': 'kochen starten'},
    'ingredients': {'en': 'ingredients', 'de': 'zutaten'},
    'method': {'en': 'method', 'de': 'zubereitung'},
    'macros': {'en': 'macros', 'de': 'nährwerte'},
    'diet': {'en': 'diet', 'de': 'ernährung'},
    'effort': {'en': 'effort', 'de': 'aufwand'},
    'calorieLevel': {'en': 'calorie level', 'de': 'kalorienniveau'},
    'outsideTarget': {
      'en': 'show versions outside my calorie target',
      'de': 'versionen außerhalb meines kalorienziels zeigen',
    },
    'noCombination': {
      'en': 'no version for this combination yet',
      'de': 'noch keine version für diese kombination',
    },
    'learnMore': {'en': 'learn more', 'de': 'mehr erfahren'},
    'matchingHelp': {
      'en': 'how does matching work?',
      'de': 'wie funktioniert das matching?',
    },
    'searchHint': {
      'en': 'search dishes, ingredients, feelings…',
      'de': 'gerichte, zutaten, gefühle suchen…',
    },
    'noResults': {
      'en': 'nothing here yet — we noted your wish.',
      'de': 'noch nichts da — dein wunsch ist notiert.',
    },
    'filters': {'en': 'filters', 'de': 'filter'},
    'all': {'en': 'all', 'de': 'alle'},
    'breakfast': {'en': 'breakfast', 'de': 'frühstück'},
    'lunch': {'en': 'lunch', 'de': 'mittagessen'},
    'dinner': {'en': 'dinner', 'de': 'abendessen'},
    'quick': {'en': 'little time', 'de': 'wenig zeit'},
    'weekend': {'en': 'slow weekend', 'de': 'langsames wochenende'},
    'today': {'en': 'for today', 'de': 'für heute'},
    'yourCookbook': {'en': 'your cookbook', 'de': 'dein kochbuch'},
    'emptyCookbook': {
      'en': 'save the precise version you want to make again.',
      'de': 'speichere genau die version, die du wieder kochen möchtest.',
    },
    'addToList': {'en': 'add to list', 'de': 'zur liste'},
    'plannedToList': {'en': 'add week to list', 'de': 'woche zur liste'},
    'chooseRecipe': {'en': 'choose a recipe', 'de': 'rezept auswählen'},
    'clear': {'en': 'clear', 'de': 'leeren'},
    'dragHint': {
      'en': 'long-press and drag a meal to move it',
      'de': 'mahlzeit lange drücken und verschieben',
    },
    'finishShop': {'en': 'mark shopping done', 'de': 'einkauf abschließen'},
    'emptyShopping': {
      'en': 'your list is a quiet little blank page.',
      'de': 'deine liste ist noch eine ruhige, leere seite.',
    },
    'profile': {'en': 'your profile', 'de': 'dein profil'},
    'name': {'en': 'name', 'de': 'name'},
    'language': {'en': 'language', 'de': 'sprache'},
    'avoid': {'en': 'things to avoid', 'de': 'bitte vermeiden'},
    'specificAvoid': {'en': 'specific ingredients', 'de': 'bestimmte zutaten'},
    'requirements': {
      'en': 'positive requirements',
      'de': 'positive anforderungen',
    },
    'timeBudget': {'en': 'time budget', 'de': 'zeitbudget'},
    'calorieTarget': {'en': 'calorie target', 'de': 'kalorienziel'},
    'preferredEffort': {'en': 'effort mood', 'de': 'aufwandslaune'},
    'showTags': {'en': 'show variant tags', 'de': 'varianten-tags zeigen'},
    'visualAlerts': {
      'en': 'visual timer alerts',
      'de': 'visuelle timer-hinweise',
    },
    'reduceMotion': {'en': 'reduce motion', 'de': 'bewegung reduzieren'},
    'quickTap': {
      'en': 'single tap advances cook mode',
      'de': 'ein tippen geht im kochmodus weiter',
    },
    'quietControls': {
      'en': 'quiet little controls',
      'de': 'leise kleine Einstellungen',
    },
    'whatItIs': {'en': 'what it is', 'de': 'was es ist'},
    'littleTip': {'en': 'little tip', 'de': 'kleiner Tipp'},
    'storage': {'en': 'storage', 'de': 'aufbewahrung'},
    'whereToFind': {'en': 'where to find it', 'de': 'wo du es findest'},
    'halalNote': {
      'en':
          '“Halal-compatible ingredients” describes recipes, not certification or sourcing.',
      'de':
          '„halal-kompatible zutaten“ beschreibt rezepte, nicht zertifizierung oder herkunft.',
    },
    'kosherNote': {
      'en':
          '“Kosher-compatible ingredients” describes recipes, not certification or sourcing.',
      'de':
          '„koscher-kompatible zutaten“ beschreibt rezepte, nicht zertifizierung oder herkunft.',
    },
    'faq': {'en': 'help center', 'de': 'hilfe-center'},
    'insights': {'en': 'shopping insights', 'de': 'einkaufs-einblicke'},
    'history': {'en': 'cooking history', 'de': 'kochverlauf'},
    'backup': {'en': 'backup & restore', 'de': 'backup & wiederherstellen'},
    'export': {'en': 'export backup', 'de': 'backup exportieren'},
    'restore': {'en': 'restore backup', 'de': 'backup wiederherstellen'},
    'passwordOptional': {
      'en': 'password (optional)',
      'de': 'passwort (optional)',
    },
    'merge': {
      'en': 'merge with this device',
      'de': 'mit diesem gerät zusammenführen',
    },
    'replace': {'en': 'replace this device', 'de': 'dieses gerät ersetzen'},
    'cancel': {'en': 'cancel', 'de': 'abbrechen'},
    'continue': {'en': 'continue', 'de': 'weiter'},
    'done': {'en': 'done', 'de': 'fertig'},
    'next': {'en': 'next', 'de': 'weiter'},
    'back': {'en': 'back', 'de': 'zurück'},
    'welcome': {
      'en': 'a cookbook that keeps you in the picture.',
      'de': 'ein kochbuch, in dem du mitgedacht wirst.',
    },
    'pickLanguage': {
      'en': 'first, your language.',
      'de': 'zuerst deine sprache.',
    },
    'whatCallYou': {
      'en': 'what should we call you?',
      'de': 'wie sollen wir dich nennen?',
    },
    'dietQuestion': {
      'en': 'what should stay off your plate?',
      'de': 'was soll nicht auf deinen teller?',
    },
    'goalsQuestion': {
      'en': 'what feels good today?',
      'de': 'was fühlt sich heute gut an?',
    },
    'confirmQuestion': {
      'en': 'your cookbook, your rules.',
      'de': 'dein kochbuch, deine regeln.',
    },
    'ready': {'en': 'open my cookbook', 'de': 'mein kochbuch öffnen'},
    'easy': {'en': 'easy', 'de': 'einfach'},
    'medium': {'en': 'medium', 'de': 'mittel'},
    'hard': {'en': 'hard', 'de': 'aufwendig'},
    'classic': {'en': 'classic', 'de': 'klassisch'},
    'vegan': {'en': 'vegan', 'de': 'vegan'},
    'keto': {'en': 'keto', 'de': 'keto'},
    'halal': {'en': 'halal-compatible', 'de': 'halal-kompatibel'},
    'kosher': {'en': 'kosher-compatible', 'de': 'koscher-kompatibel'},
    'variety': {'en': 'variety score', 'de': 'vielfalts-score'},
    'topIngredients': {'en': 'most added', 'de': 'am häufigsten hinzugefügt'},
    'seasonal': {'en': 'by month', 'de': 'nach monat'},
    'noData': {
      'en': 'shop once and this page will start telling your story.',
      'de': 'nach deinem ersten einkauf erzählt diese seite deine geschichte.',
    },
    'servings': {'en': 'servings', 'de': 'portionen'},
    'previous': {'en': 'previous', 'de': 'zurück'},
    'pause': {'en': 'pause', 'de': 'pause'},
    'resume': {'en': 'resume', 'de': 'weiter'},
    'finish': {'en': 'finish', 'de': 'fertig'},
    'cooked': {'en': 'beautifully done.', 'de': 'wundervoll gemacht.'},
    'cookAgain': {'en': 'back to recipe', 'de': 'zurück zum rezept'},
  };

  static String t(String key, String lang) =>
      localize(_values[key] ?? {'en': key, 'de': key}, lang);
}
