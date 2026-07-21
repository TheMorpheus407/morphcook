/// Cookbook (saved recipes + cooking history) strings.
/// Warm, lowercase, tumblr-notebook voice. Registered in main.dart.
const Map<String, Map<String, String>> strings = {
  'cookbook.title': {'en': 'your cookbook', 'de': 'dein kochbuch'},
  'cookbook.tab.saved': {'en': 'saved', 'de': 'gemerkt'},
  'cookbook.tab.history': {'en': 'history', 'de': 'verlauf'},

  'cookbook.empty.saved.note': {
    'en': 'nothing saved yet — go find your döner',
    'de': 'noch nichts gemerkt — such dir deinen döner',
  },
  'cookbook.empty.saved.cta': {
    'en': 'go find something tasty',
    'de': 'such dir was leckeres',
  },
  'cookbook.empty.history.note': {
    'en': 'nothing cooked yet — your story starts with the first sizzle',
    'de':
        'noch nichts gekocht — deine geschichte beginnt mit dem ersten brutzeln',
  },
  'cookbook.empty.history.cta': {
    'en': 'pick a recipe to cook',
    'de': 'such dir ein rezept zum kochen',
  },

  'cookbook.unsave.tooltip': {
    'en': 'remove from saved',
    'de': 'nicht mehr merken',
  },
  'cookbook.weekOf': {'en': 'week of', 'de': 'woche vom'},

  /// Comma-separated month names, january first. Used for week headers and
  /// cooked-on dates so no intl date-symbol init is required.
  'cookbook.months': {
    'en':
        'january,february,march,april,may,june,july,august,september,october,november,december',
    'de':
        'januar,februar,märz,april,mai,juni,juli,august,september,oktober,november,dezember',
  },
};
