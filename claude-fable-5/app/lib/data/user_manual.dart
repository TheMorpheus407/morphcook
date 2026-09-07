/// Bundled help text: reading or searching the manual requires no connection.
class ManualSection {
  final String id;
  final String titleEn;
  final String titleDe;
  final String bodyEn;
  final String bodyDe;

  const ManualSection({
    required this.id,
    required this.titleEn,
    required this.titleDe,
    required this.bodyEn,
    required this.bodyDe,
  });

  String title(String lang) => lang == 'de' ? titleDe : titleEn;
  String body(String lang) => lang == 'de' ? bodyDe : bodyEn;

  bool matches(String query, String lang) {
    final search = query.trim().toLowerCase();
    return search.isEmpty ||
        '${title(lang)} ${body(lang)}'.toLowerCase().contains(search);
  }
}

const userManualSections = [
  ManualSection(
    id: 'start',
    titleEn: 'Getting started',
    titleDe: 'Erste Schritte',
    bodyEn:
        'Set your language and preferences during setup or later in Settings. Browse dishes from the home screen or use search. Open a dish to see its recipe and available variants. Save recipes to your Cookbook, organise meals in the plan, and start cook mode from a recipe.\n\n'
        'The bundled recipes, your saved data, and this manual work offline. Website imports and external actions such as opening a feedback draft need the corresponding connection. Search this manual by a word such as PDF, timer, or backup; tap a heading to read the instructions.',
    bodyDe:
        'Wähle Sprache und Vorlieben bei der Einrichtung oder später in den Einstellungen. Stöbere auf der Startseite oder nutze die Suche. Öffne ein Gericht für sein Rezept und die verfügbaren Varianten. Speichere Rezepte im Kochbuch, organisiere Mahlzeiten im Plan und starte den Kochmodus aus einem Rezept.\n\n'
        'Die mitgelieferten Rezepte, deine gespeicherten Daten und diese Anleitung funktionieren offline. Website-Importe und externe Aktionen wie das Öffnen eines Feedback-Entwurfs benötigen die entsprechende Verbindung. Suche hier nach einem Wort wie PDF, Timer oder Backup und tippe eine Überschrift an.',
  ),
  ManualSection(
    id: 'profile',
    titleEn: 'Profile, diet, and allergies',
    titleDe: 'Profil, Ernährung und Allergien',
    bodyEn:
        'In Settings, choose ingredients and ingredient groups to avoid and required attributes such as vegan or gluten-free. You can also set an optional calorie target, time budget, and preferred effort. These preferences guide matching among the bundled recipe variants. If no variant fits, change your preferences or choose another dish.\n\n'
        'Personal and imported recipes do not have verified diet, allergy, or nutrition data. An import does not make a recipe vegan or safe for an allergy. Check every ingredient, product label, and preparation step yourself; recipe matching and recorded expert comments do not certify suitability.',
    bodyDe:
        'Wähle in den Einstellungen zu vermeidende Zutaten und Zutatengruppen sowie erforderliche Merkmale wie vegan oder glutenfrei. Optional kannst du Kalorienziel, Zeitbudget und bevorzugten Aufwand einstellen. Diese Angaben steuern die Auswahl unter den mitgelieferten Rezeptvarianten. Passt keine Variante, ändere die Vorgaben oder wähle ein anderes Gericht.\n\n'
        'Eigene und importierte Rezepte haben keine verifizierten Ernährungs-, Allergie- oder Nährwertdaten. Ein Import macht ein Rezept weder vegan noch allergiegeeignet. Prüfe jede Zutat, Produktkennzeichnung und Zubereitung selbst; Rezeptauswahl und gespeicherte Fachkommentare bescheinigen keine Eignung.',
  ),
  ManualSection(
    id: 'variants',
    titleEn: 'Recipes and variants',
    titleDe: 'Rezepte und Varianten',
    bodyEn:
        'A bundled dish can have several complete recipes for different diets, levels of effort, and calorie ranges. Use the variant controls on its recipe page to switch. The ingredient list and instructions belong to the selected variant; MorphCook does not invent ingredient substitutions.\n\n'
        'Change the serving count to scale measured ingredients. Nutrition displayed for bundled recipes is per serving. Personal recipes have unknown nutrition. Ingredient lines marked as original text keep their original quantities and do not scale; adjust those quantities yourself.',
    bodyDe:
        'Ein mitgeliefertes Gericht kann mehrere vollständige Rezepte für verschiedene Ernährungsweisen, Aufwände und Kalorienbereiche haben. Wechsle mit den Varianten-Reglern auf der Rezeptseite. Zutaten und Anleitung gehören jeweils zur gewählten Variante; MorphCook erfindet keinen Zutatenaustausch.\n\n'
        'Ändere die Portionszahl, um erfasste Mengen zu skalieren. Nährwerte mitgelieferter Rezepte gelten pro Portion. Bei eigenen Rezepten sind Nährwerte unbekannt. Als Originaltext markierte Zutatenzeilen behalten ihre Mengen und werden nicht skaliert; passe diese Mengen selbst an.',
  ),
  ManualSection(
    id: 'personal',
    titleEn: 'Personal recipes and photos',
    titleDe: 'Eigene Rezepte und Fotos',
    bodyEn:
        'In Cookbook, use the add-recipe button to create a personal recipe. Enter a title, duration, servings, ingredients with quantities and units or original text, and cooking steps. Steps can have timers. Save the recipe, then open it from My recipes to cook, edit, or delete it.\n\n'
        'An optional photo is stored locally for offline use. Imported fields are drafts: check quantities, units, timings, and serving counts before saving. Photos are stored as supplied and may contain embedded metadata; check an image before choosing to include it in a share or backup.',
    bodyDe:
        'Erstelle im Kochbuch mit der Schaltfläche für ein neues Rezept ein eigenes Rezept. Gib Titel, Dauer, Portionen, Zutaten mit Menge und Einheit oder Originaltext sowie Kochschritte ein. Schritte können Timer haben. Speichere das Rezept und öffne es unter Meine Rezepte zum Kochen, Bearbeiten oder Löschen.\n\n'
        'Ein optionales Foto wird lokal für die Offline-Nutzung gespeichert. Importierte Angaben sind Entwürfe: Prüfe Mengen, Einheiten, Zeiten und Portionen vor dem Speichern. Fotos werden wie geliefert gespeichert und können eingebettete Metadaten enthalten; prüfe ein Bild, bevor du es beim Teilen oder im Backup weitergibst.',
  ),
  ManualSection(
    id: 'website',
    titleEn: 'Import from a website',
    titleDe: 'Von einer Website importieren',
    bodyEn:
        'Open the website import with the link icon in Cookbook. Paste a recipe URL, for example from Chefkoch or Allrecipes, and start the import. MorphCook requests that page and reads its structured recipe data. Sites without supported recipe data, login-only pages, or sites blocking requests may not import.\n\n'
        'Review the draft in the personal recipe editor. If a site provides no usable duration or serving count, the draft starts with 30 minutes and 2 servings; correct these values. A recipe photo is optional and is downloaded only when you choose it. Once saved, the recipe and any imported photo are available offline. No diet or nutrition suitability is inferred.',
    bodyDe:
        'Öffne den Website-Import über das Link-Symbol im Kochbuch. Füge eine Rezept-URL ein, etwa von Chefkoch oder Allrecipes, und starte den Import. MorphCook lädt diese Seite und liest ihre strukturierten Rezeptdaten. Seiten ohne unterstützte Rezeptdaten, mit Anmeldung oder mit blockierten Abrufen lassen sich eventuell nicht importieren.\n\n'
        'Prüfe den Entwurf im Editor für eigene Rezepte. Fehlen brauchbare Dauer oder Portionszahl, beginnt der Entwurf mit 30 Minuten und 2 Portionen; korrigiere diese Werte. Ein Rezeptfoto ist optional und wird erst auf deinen Wunsch geladen. Nach dem Speichern stehen Rezept und importiertes Foto offline bereit. Eine Ernährungs- oder Nährwerteignung wird nicht abgeleitet.',
  ),
  ManualSection(
    id: 'pdf',
    titleEn: 'Import PDF recipes',
    titleDe: 'PDF-Rezepte importieren',
    bodyEn:
        'Tap the PDF icon in Cookbook to open Import PDF, then pick a PDF file. Text extraction happens on your device. This also works for recipes exported to PDF from Sonnet or another authoring tool when the PDF contains selectable text. No AI service is contacted.\n\n'
        'With recognisable ingredient and instruction headings, review the extracted recipe draft in the personal recipe editor. If the structure is not recognised, read or copy the extracted text and create the recipe manually. Check every quantity, unit, step, duration, and serving count. Scanned images need OCR elsewhere first; image-only and password-protected PDFs are not supported.',
    bodyDe:
        'Tippe im Kochbuch auf das PDF-Symbol für PDF importieren und wähle eine PDF-Datei. Der Text wird auf deinem Gerät ausgelesen. Das funktioniert auch mit Rezepten, die mit Sonnet oder einem anderen Schreibwerkzeug als PDF exportiert wurden, sofern das PDF auswählbaren Text enthält. Kein KI-Dienst wird kontaktiert.\n\n'
        'Bei erkennbaren Überschriften für Zutaten und Zubereitung prüfst du den ausgelesenen Entwurf im Editor für eigene Rezepte. Wird die Struktur nicht erkannt, lies oder kopiere den ausgelesenen Text und lege das Rezept manuell an. Prüfe jede Menge, Einheit, jeden Schritt, Dauer und Portionen. Scans benötigen vorher eine Texterkennung außerhalb der App; reine Bild-PDFs und passwortgeschützte PDFs werden nicht unterstützt.',
  ),
  ManualSection(
    id: 'sharing',
    titleEn: 'Share a recipe or cookbook',
    titleDe: 'Rezept oder Kochbuch teilen',
    bodyEn:
        'Use Share on a recipe page to share that recipe, or the sharing action in Cookbook for your saved and personal recipes. Choose whether to include photos. MorphCook opens the Android share sheet with one ZIP containing recipe data and a readable recipe text. Select Bluetooth, Quick Share, or another available target. Targets depend on your device; wait for a transfer to finish before starting another share.\n\n'
        'On the receiving device, save the file and open the recipe-sharing screen in Cookbook to import the ZIP (or its recipe JSON). Review the preview and confirm adding the recipes. Existing recipes are retained; identical copies are skipped and changed copies are added separately. Sharing includes recipes, source links, and optional photos, but excludes your profile, meal plans, history, and private expert assessments. Use a full backup to transfer those personal records.',
    bodyDe:
        'Nutze Teilen auf einer Rezeptseite für dieses Rezept oder die Teilen-Funktion im Kochbuch für deine gespeicherten und eigenen Rezepte. Wähle, ob Fotos enthalten sein sollen. MorphCook öffnet das Android-Teilen-Menü mit einer ZIP-Datei aus Rezeptdaten und lesbarem Rezepttext. Wähle Bluetooth, Quick Share oder ein anderes verfügbares Ziel. Die Ziele hängen vom Gerät ab; warte das Ende einer Übertragung ab, bevor du erneut teilst.\n\n'
        'Speichere auf dem Empfangsgerät die Datei und öffne im Kochbuch die Rezept-Teilen-Seite zum Import der ZIP-Datei (oder ihrer Rezept-JSON). Prüfe die Vorschau und bestätige das Hinzufügen. Vorhandene Rezepte bleiben erhalten; identische Kopien werden übersprungen und geänderte Kopien separat ergänzt. Geteilt werden Rezepte, Quellenlinks und optionale Fotos. Profil, Essenspläne, Verlauf und private fachliche Einschätzungen bleiben ausgeschlossen. Nutze für diese persönlichen Daten ein vollständiges Backup.',
  ),
  ManualSection(
    id: 'planning',
    titleEn: 'Meal plan and shopping list',
    titleDe: 'Essensplan und Einkaufsliste',
    bodyEn:
        'Use the meal plan to assign a recipe to a day and meal. Choose the portions you need when adding recipe ingredients to the shopping list. Measured ingredients with compatible units can be combined. Original-text ingredient lines keep their original amounts and must be adjusted manually.\n\n'
        'Open the shopping list from Settings or its shortcut. Check off items as you buy them and clear checked items when done. Shopping insights describe the items you added; they are not a nutritional assessment of what you ate.',
    bodyDe:
        'Ordne im Essensplan einem Tag und einer Mahlzeit ein Rezept zu. Wähle beim Hinzufügen der Zutaten zur Einkaufsliste die benötigten Portionen. Erfasste Mengen mit passenden Einheiten können zusammengefasst werden. Zutatenzeilen mit Originaltext behalten ihre ursprünglichen Mengen und müssen manuell angepasst werden.\n\n'
        'Öffne die Einkaufsliste in den Einstellungen oder über ihre Verknüpfung. Hake gekaufte Artikel ab und entferne erledigte Einträge. Die Einkaufsauswertung beschreibt hinzugefügte Artikel; sie bewertet nicht die Nährwerte deiner tatsächlich gegessenen Mahlzeiten.',
  ),
  ManualSection(
    id: 'cooking',
    titleEn: 'Cook mode and timers',
    titleDe: 'Kochmodus und Timer',
    bodyEn:
        'Start cook mode on a recipe page. Read one step at a time, open the ingredient list when needed, and move forward or back with the step controls. A timed step has a timer you can start, pause, and resume. Completing the recipe clears the saved cooking progress.\n\n'
        'Pause a running timer before leaving to save its remaining time. Reopening cook mode restores saved progress with the timer paused. Timers run inside the app and are not background alarm notifications: keep cook mode open or set a phone timer if you need a reminder outside the app. Settings offers a visual timer alert and optional tap-to-advance controls.',
    bodyDe:
        'Starte den Kochmodus auf einer Rezeptseite. Lies Schritt für Schritt, öffne bei Bedarf die Zutatenliste und wechsle mit den Schaltflächen vor und zurück. Einen Timer im Kochschritt kannst du starten, pausieren und fortsetzen. Beim Abschließen des Rezepts wird der gespeicherte Kochfortschritt gelöscht.\n\n'
        'Pausiere einen laufenden Timer vor dem Verlassen, damit die Restzeit gespeichert wird. Beim erneuten Öffnen wird der gespeicherte Fortschritt mit pausiertem Timer geladen. Timer laufen innerhalb der App und sind keine Hintergrund-Alarme: Lass den Kochmodus offen oder stelle einen Handy-Timer, wenn du außerhalb der App erinnert werden möchtest. Die Einstellungen bieten einen visuellen Timer-Hinweis und optionales Weiterblättern durch Tippen.',
  ),
  ManualSection(
    id: 'expert',
    titleEn: 'Expert assessments',
    titleDe: 'Fachliche Einschätzungen',
    bodyEn:
        'Open Expert assessments from a recipe page. Request a review prepares recipe sharing so you can send the recipe and your question to a nutrition or health professional you choose. Select the recipient yourself; MorphCook does not contact an expert automatically or provide a review service.\n\n'
        'After receiving an assessment, use Record assessment to save the expert’s name, qualifications, date, assessment, and source privately on your device. These are your own records, not verified ratings or endorsements by MorphCook. Recording a comment does not change dietary matching or nutrition data. Records are included in full backups and excluded from recipe-sharing ZIPs.',
    bodyDe:
        'Öffne Fachliche Einschätzungen auf einer Rezeptseite. Mit Einschätzung anfragen bereitest du das Teilen des Rezepts vor, um es mit deiner Frage an eine von dir gewählte Ernährungs- oder Gesundheitsfachperson zu senden. Wähle den Empfänger selbst; MorphCook kontaktiert niemanden automatisch und bietet keinen Bewertungsdienst an.\n\n'
        'Nach Erhalt einer Einschätzung kannst du mit Einschätzung erfassen Name, Qualifikation, Datum, Einschätzung und Quelle privat auf deinem Gerät speichern. Das sind deine eigenen Aufzeichnungen, keine verifizierten Bewertungen oder Empfehlungen durch MorphCook. Ein Eintrag ändert weder die Ernährungsauswahl noch Nährwertdaten. Die Aufzeichnungen sind in vollständigen Backups enthalten und aus ZIP-Dateien zum Rezeptteilen ausgeschlossen.',
  ),
  ManualSection(
    id: 'backup',
    titleEn: 'Backup, restore, and privacy',
    titleDe: 'Backup, Wiederherstellen und Datenschutz',
    bodyEn:
        'In Settings, choose Export backup to save or share your complete personal data. Set and confirm a password to encrypt it, or leave the password empty for an unencrypted backup. Keep the password separately: it cannot be recovered by MorphCook. Choose Import backup to select a file, enter its password if needed, and deliberately choose Merge or Replace. Replace replaces your current personal data.\n\n'
        'Your profile, recipes, plans, and records are kept on the device. There is no automatic MorphCook account sync; your operating system may also back up app data according to device settings. Website imports contact the chosen site, and share targets or external browsers handle data you send to them. Backups can contain private records and photo metadata. Reset in Settings deletes the app’s personal data; exported files elsewhere remain.',
    bodyDe:
        'Wähle in den Einstellungen Backup exportieren, um deine vollständigen persönlichen Daten zu speichern oder zu teilen. Setze und bestätige ein Passwort für die Verschlüsselung oder lass es für ein unverschlüsseltes Backup leer. Bewahre das Passwort separat auf: MorphCook kann es nicht wiederherstellen. Wähle Backup importieren, öffne eine Datei, gib gegebenenfalls ihr Passwort ein und entscheide bewusst zwischen Zusammenführen und Ersetzen. Ersetzen ersetzt deine aktuellen persönlichen Daten.\n\n'
        'Profil, Rezepte, Pläne und Aufzeichnungen bleiben auf dem Gerät. Es gibt keine automatische Synchronisierung über ein MorphCook-Konto; dein Betriebssystem kann App-Daten entsprechend den Geräteeinstellungen sichern. Website-Importe kontaktieren die gewählte Seite; Teilen-Ziele und externe Browser verarbeiten die von dir übergebenen Daten. Backups können private Aufzeichnungen und Foto-Metadaten enthalten. Zurücksetzen in den Einstellungen löscht persönliche App-Daten; anderswo exportierte Dateien bleiben erhalten.',
  ),
  ManualSection(
    id: 'accessibility',
    titleEn: 'Language and accessibility',
    titleDe: 'Sprache und Barrierefreiheit',
    bodyEn:
        'Settings lets you switch between English and German and choose light, dark, or system appearance. Readable text uses a font intended for easier reading. Reduced motion can follow the system or be enabled explicitly. The visual timer alert and quick tap controls are optional.\n\n'
        'This manual is available in both languages offline. Its headings and text can be searched, and the instructions can be selected and copied. The Help center also offers searchable answers to common questions.',
    bodyDe:
        'In den Einstellungen wechselst du zwischen Englisch und Deutsch und wählst helles, dunkles oder systemgesteuertes Aussehen. Gut lesbarer Text verwendet eine auf Lesbarkeit ausgelegte Schrift. Reduzierte Bewegung kann der Systemeinstellung folgen oder ausdrücklich aktiviert werden. Visuelle Timer-Hinweise und schnelles Weiterblättern sind optional.\n\n'
        'Diese Anleitung steht offline in beiden Sprachen bereit. Du kannst Überschriften und Text durchsuchen sowie die Anleitung markieren und kopieren. Das Hilfezentrum enthält außerdem durchsuchbare Antworten auf häufige Fragen.',
  ),
  ManualSection(
    id: 'feedback',
    titleEn: 'Send feedback',
    titleDe: 'Feedback geben',
    bodyEn:
        'Open Feedback from Settings or the message icon in this manual. Enter a short title and describe your suggestion or the steps that reproduce a problem, including the expected and actual result. Do not include passwords, private health details, or other personal information.\n\n'
        'Open GitHub draft passes only your entered title and message to GitHub in your browser. Review the draft and submit it there yourself; GitHub may ask you to sign in and submitted issues are public. Nothing is posted automatically and no profile, recipes, or logs are attached. Copy feedback works offline and is also the fallback if a browser cannot open or the encoded link is too long. Leaving the composer discards its local draft.',
    bodyDe:
        'Öffne Feedback in den Einstellungen oder über das Nachrichten-Symbol dieser Anleitung. Gib einen kurzen Titel ein und beschreibe deinen Vorschlag oder die Schritte zum Nachstellen eines Problems mit erwartetem und tatsächlichem Ergebnis. Füge keine Passwörter, privaten Gesundheitsangaben oder andere persönlichen Daten hinzu.\n\n'
        'GitHub-Entwurf öffnen übergibt nur deinen eingegebenen Titel und Text an GitHub im Browser. Prüfe den Entwurf und sende ihn dort selbst ab; GitHub kann eine Anmeldung verlangen und gesendete Issues sind öffentlich. Nichts wird automatisch veröffentlicht; Profil, Rezepte und Protokolle werden nicht angehängt. Feedback kopieren funktioniert offline und hilft auch, wenn kein Browser verfügbar oder der kodierte Link zu lang ist. Beim Verlassen wird der lokale Entwurf verworfen.',
  ),
];
