import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/profile_store.dart';

/// Single canonical map of UI strings, per language.
class L10n {
  final String lang;
  L10n(this.lang);

  String t(String key) => _strings[key]?[lang] ?? _strings[key]?['en'] ?? key;
  String tParams(String key, Map<String, String> params) {
    String s = t(key);
    params.forEach((k, v) {
      s = s.replaceAll('{$k}', v);
    });
    return s;
  }

  /// Pull from context — reads the profile's lang.
  static L10n of(BuildContext context) {
    final lang = context.watch<ProfileStore>().profile.lang;
    return L10n(lang);
  }

  /// Non-listening variant (use in callbacks).
  static L10n read(BuildContext context) {
    final lang = context.read<ProfileStore>().profile.lang;
    return L10n(lang);
  }
}

const Map<String, Map<String, String>> _strings = {
  // App-level
  'app.name':            {'en':'MorphCook',                       'de':'MorphCook'},
  'app.tagline':         {'en':'a recipe book for every body',     'de':'ein kochbuch für jeden körper'},
  'app.continue':        {'en':'continue',                          'de':'weiter'},
  'app.back':            {'en':'back',                              'de':'zurück'},
  'app.done':            {'en':'done',                              'de':'fertig'},
  'app.skip':            {'en':'skip',                              'de':'überspringen'},
  'app.cancel':          {'en':'cancel',                            'de':'abbrechen'},
  'app.save':            {'en':'save',                              'de':'speichern'},
  'app.delete':          {'en':'delete',                            'de':'löschen'},
  'app.confirm':         {'en':'confirm',                           'de':'bestätigen'},
  'app.search':          {'en':'search',                            'de':'suchen'},
  'app.close':           {'en':'close',                             'de':'schließen'},
  'app.empty':           {'en':'nothing here yet',                  'de':'hier ist noch nichts'},
  'app.error':           {'en':'something went wrong',              'de':'etwas ist schiefgelaufen'},
  'app.retry':           {'en':'try again',                         'de':'erneut versuchen'},
  'app.loading':         {'en':'loading',                           'de':'lädt'},

  // Nav
  'nav.home':            {'en':'home',                              'de':'start'},
  'nav.cookbook':        {'en':'cookbook',                          'de':'kochbuch'},
  'nav.search':          {'en':'search',                            'de':'suchen'},
  'nav.plan':            {'en':'plan',                              'de':'plan'},
  'nav.shop':            {'en':'shop',                              'de':'einkauf'},
  'nav.settings':        {'en':'settings',                          'de':'einstellungen'},

  // Onboarding
  'onb.title':           {'en':'welcome to your cookbook',          'de':'willkommen in deinem kochbuch'},
  'onb.lang.title':      {'en':'first — language',                  'de':'zuerst — sprache'},
  'onb.lang.body':       {'en':'pick the language for your kitchen. you can change it later.',
                          'de':'wähle die sprache deiner küche. du kannst sie später ändern.'},
  'onb.name.title':      {'en':'and your name',                     'de':'und dein name'},
  'onb.name.body':       {'en':'we use it once, on the home page. nowhere else.',
                          'de':'wir verwenden ihn einmal, auf der startseite. sonst nirgends.'},
  'onb.name.hint':       {'en':'your name',                         'de':'dein name'},
  'onb.diet.title':      {'en':'how you eat',                       'de':'wie du isst'},
  'onb.diet.body':       {'en':'pick what to avoid. each entry expands; ingredients can be added later.',
                          'de':'wähle was du meidest. jeder eintrag wird automatisch erweitert; weitere zutaten kannst du später ergänzen.'},
  'onb.allergies.body':  {'en':'specific ingredients (typeahead).',
                          'de':'einzelne zutaten (autovervollständigung).'},
  'onb.budget.title':    {'en':'budgets',                           'de':'rahmen'},
  'onb.budget.cal':      {'en':'calorie target (per meal)',         'de':'kalorienziel (pro mahlzeit)'},
  'onb.budget.cal.body': {'en':'we hide things outside ± your tolerance. switch off the hard filter to soften.',
                          'de':'wir verstecken was außerhalb ± deiner toleranz liegt. das harte filter kannst du in den einstellungen abschalten.'},
  'onb.budget.time':     {'en':'time budget',                       'de':'zeit­rahmen'},
  'onb.budget.time.body':{'en':'maximum minutes from prep to plate. 0 = no limit.',
                          'de':'maximale minuten von vorbereitung bis teller. 0 = keine grenze.'},
  'onb.effort':          {'en':'effort mood today',                 'de':'aufwand heute'},
  'onb.confirm.title':   {'en':'all set',                           'de':'fertig eingerichtet'},
  'onb.confirm.body':    {'en':'this is your cookbook now. flexible. yours.',
                          'de':'das ist jetzt dein kochbuch. flexibel. deins.'},

  // Home
  'home.featured':       {'en':'today, for you',                    'de':'heute, für dich'},
  'home.hello':          {'en':'hello, {name}',                     'de':'hallo, {name}'},
  'home.cuisine':        {'en':'by cuisine',                        'de':'nach küche'},
  'home.quick':          {'en':'quick fixes',                       'de':'schnell gemacht'},
  'home.weekend':        {'en':'weekend long-cooks',                'de':'wochenend-projekte'},

  // Dish detail
  'dish.dimension.diet':    {'en':'diet',          'de':'ernährung'},
  'dish.dimension.effort':  {'en':'effort',        'de':'aufwand'},
  'dish.dimension.calorie': {'en':'calorie level', 'de':'kalorienstufe'},
  'dish.dimension.time':    {'en':'time',          'de':'zeit'},
  'dish.dimension.technique':{'en':'technique',    'de':'methode'},
  'dish.ingredients':       {'en':'ingredients',   'de':'zutaten'},
  'dish.method':            {'en':'method',        'de':'zubereitung'},
  'dish.macros':            {'en':'macros',        'de':'nährwerte'},
  'dish.unreachable':       {'en':'no version exists for this combination yet',
                             'de':'es gibt noch keine version für diese kombination'},
  'dish.save':              {'en':'save this version', 'de':'diese version speichern'},
  'dish.saved':             {'en':'saved',          'de':'gespeichert'},
  'dish.shop_add':          {'en':'add to shopping list', 'de':'zur einkaufsliste'},
  'dish.cook':              {'en':'cook',           'de':'kochen'},
  'dish.calorie.override':  {'en':'show all calorie levels for this dish',
                             'de':'alle kalorienstufen für dieses gericht zeigen'},
  'dish.servings':          {'en':'servings',       'de':'portionen'},
  'dish.minutes':           {'en':'min',            'de':'Min'},
  'dish.kcal':              {'en':'kcal',           'de':'kcal'},
  'dish.protein':           {'en':'protein',        'de':'eiweiß'},
  'dish.carbs':             {'en':'carbs',          'de':'kohlenhydrate'},
  'dish.fat':               {'en':'fat',            'de':'fett'},
  'dish.guide':             {'en':'learn more',     'de':'mehr erfahren'},

  // Cookbook
  'cookbook.title':         {'en':'your cookbook',  'de':'dein kochbuch'},
  'cookbook.empty':         {'en':'no saved variants yet — save one from a dish.',
                             'de':'noch keine gespeicherten varianten — speichere eine im gericht.'},

  // Search
  'search.placeholder':     {'en':'search recipes, ingredients, tags',
                             'de':'rezepte, zutaten, tags suchen'},
  'search.empty':           {'en':'no results — saved as a content request',
                             'de':'keine ergebnisse — als inhaltswunsch gespeichert'},
  'search.respect':         {'en':'results respect your profile',
                             'de':'ergebnisse nach deinem profil'},

  // Plan
  'plan.title':             {'en':'meal plan',      'de':'wochenplan'},
  'plan.add.shop':          {'en':'add week to shopping list', 'de':'woche zur einkaufsliste'},
  'plan.empty':             {'en':'tap a slot to plan',         'de':'tippe eine zeile zum planen'},
  'plan.breakfast':         {'en':'breakfast',                  'de':'frühstück'},
  'plan.lunch':             {'en':'lunch',                      'de':'mittag'},
  'plan.dinner':            {'en':'dinner',                     'de':'abend'},
  'plan.mon':               {'en':'mon', 'de':'mo'},
  'plan.tue':               {'en':'tue', 'de':'di'},
  'plan.wed':               {'en':'wed', 'de':'mi'},
  'plan.thu':               {'en':'thu', 'de':'do'},
  'plan.fri':               {'en':'fri', 'de':'fr'},
  'plan.sat':               {'en':'sat', 'de':'sa'},
  'plan.sun':               {'en':'sun', 'de':'so'},

  // Shopping
  'shop.title':             {'en':'shopping list', 'de':'einkaufsliste'},
  'shop.empty':             {'en':'list is empty', 'de':'liste ist leer'},
  'shop.clear_checked':     {'en':'clear checked', 'de':'erledigte entfernen'},
  'shop.clear_all':         {'en':'clear all',     'de':'alles löschen'},

  // Settings
  'settings.title':         {'en':'settings',                   'de':'einstellungen'},
  'settings.profile':       {'en':'profile',                    'de':'profil'},
  'settings.dietary':       {'en':'dietary',                    'de':'ernährung'},
  'settings.language':      {'en':'language',                   'de':'sprache'},
  'settings.lang.en':       {'en':'English',                    'de':'Englisch'},
  'settings.lang.de':       {'en':'German',                     'de':'Deutsch'},
  'settings.calorie_hard':  {'en':'hard calorie filter',        'de':'hartes kalorienfilter'},
  'settings.calorie_tol':   {'en':'calorie tolerance',          'de':'kalorientoleranz'},
  'settings.show_tags':     {'en':'show variant tags',          'de':'variantentags zeigen'},
  'settings.cook_mode':     {'en':'cook mode',                  'de':'kochmodus'},
  'settings.visual_alert':  {'en':'visual timer alert',         'de':'visueller timer-alarm'},
  'settings.quick_tap':     {'en':'tap step to advance',        'de':'tippe schritt für nächsten'},
  'settings.reduce_motion': {'en':'reduce motion',              'de':'bewegung reduzieren'},
  'settings.access':        {'en':'accessibility',              'de':'barrierefreiheit'},
  'settings.backup':        {'en':'backup & restore',           'de':'sichern & wiederherstellen'},
  'settings.backup.export': {'en':'export backup',              'de':'backup erstellen'},
  'settings.backup.import': {'en':'import backup',              'de':'backup laden'},
  'settings.backup.password':{'en':'password (optional)',       'de':'passwort (optional)'},
  'settings.backup.hint':   {'en':'password is required to decrypt later. no recovery.',
                             'de':'passwort wird zum entschlüsseln benötigt. keine wiederherstellung.'},
  'settings.insights':      {'en':'shopping insights',          'de':'einkaufsstatistik'},
  'settings.faq':           {'en':'help & FAQ',                 'de':'hilfe & FAQ'},
  'settings.calorie_target':{'en':'calorie target per meal',    'de':'kalorienziel pro mahlzeit'},
  'settings.max_time':      {'en':'maximum time per recipe',    'de':'maximale zeit je rezept'},
  'settings.effort':        {'en':'preferred effort',           'de':'bevorzugter aufwand'},

  // Insights
  'insights.title':         {'en':'shopping insights',          'de':'einkaufs­statistik'},
  'insights.variety':       {'en':'variety score',              'de':'vielfalt'},
  'insights.variety.body':  {'en':'unique ingredients across your saved recipes.',
                             'de':'einzigartige zutaten in deinem kochbuch.'},
  'insights.top':           {'en':'most-added ingredients',     'de':'häufigste zutaten'},
  'insights.season':        {'en':'by month',                   'de':'nach monat'},

  // FAQ
  'faq.title':              {'en':'help & FAQ',                 'de':'hilfe & FAQ'},
  'faq.category.all':       {'en':'all',                        'de':'alle'},
  'faq.category.dietary':   {'en':'dietary',                    'de':'ernährung'},
  'faq.category.recipes':   {'en':'recipes',                    'de':'rezepte'},
  'faq.category.features':  {'en':'features',                   'de':'funktionen'},
  'faq.category.trouble':   {'en':'troubleshooting',            'de':'fehler'},

  // Cook mode
  'cook.step':              {'en':'step',                       'de':'schritt'},
  'cook.of':                {'en':'of',                         'de':'von'},
  'cook.prev':              {'en':'prev',                       'de':'zurück'},
  'cook.next':              {'en':'next',                       'de':'weiter'},
  'cook.start':             {'en':'start',                      'de':'start'},
  'cook.pause':             {'en':'pause',                      'de':'pause'},
  'cook.resume':            {'en':'resume',                     'de':'weiter'},
  'cook.done':              {'en':'finished',                   'de':'fertig gekocht'},
  'cook.tap_to_advance':    {'en':'tap step to advance',        'de':'tippe um weiterzugehen'},
  'cook.exit':              {'en':'exit cook mode',             'de':'kochmodus beenden'},
  'cook.no_timer':          {'en':'no timer',                   'de':'kein timer'},
};
