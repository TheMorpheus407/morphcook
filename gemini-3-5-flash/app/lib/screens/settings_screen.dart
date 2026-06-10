import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/backup_service.dart';
import '../theme/brand_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Profile controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _backupPasswordController = TextEditingController();
  final TextEditingController _backupFilePathController = TextEditingController();

  // FAQ Search
  final TextEditingController _faqSearchController = TextEditingController();
  String _faqQuery = '';
  String _selectedFAQCategory = '';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppProvider>(context, listen: false);
    _nameController.text = provider.profile.name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _backupPasswordController.dispose();
    _backupFilePathController.dispose();
    _faqSearchController.dispose();
    super.dispose();
  }

  void _saveProfileChanges() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    provider.profile.name = _nameController.text.trim().isEmpty ? "Cook" : _nameController.text.trim();
    provider.saveProfile();
  }

  Future<void> _exportBackup(bool compressed) async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isEn = provider.currentLanguage == 'en';

    try {
      final dataMap = BackupService.createBackupData(provider);
      final jsonString = json.encode(dataMap);

      final directory = await getApplicationDocumentsDirectory();
      final password = _backupPasswordController.text;

      String fileName;
      List<int> fileBytes;

      if (compressed) {
        fileName = "morphcook-backup.json.gz";
        fileBytes = BackupService.compressGZip(jsonString);
      } else {
        fileName = "morphcook-backup.json";
        if (password.isNotEmpty) {
          fileBytes = BackupService.encryptGCM(jsonString, password);
        } else {
          fileBytes = utf8.encode(jsonString);
        }
      }

      final file = File("${directory.path}/$fileName");
      await file.writeAsBytes(fileBytes);

      _showTactileSnackBar(
        isEn 
          ? "backup exported successfully to:\n${file.path}" 
          : "sicherung erfolgreich gespeichert unter:\n${file.path}",
      );
    } catch (e) {
      _showTactileSnackBar(isEn ? "failed to export backup: $e" : "fehler beim exportieren: $e");
    }
  }

  Future<void> _importBackup() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isEn = provider.currentLanguage == 'en';
    final path = _backupFilePathController.text.trim();

    if (path.isEmpty) {
      _showTactileSnackBar(isEn ? "please enter a valid backup file path" : "bitte gib einen dateipfad an");
      return;
    }

    try {
      final file = File(path);
      if (!await file.exists()) {
        _showTactileSnackBar(isEn ? "file does not exist" : "datei existiert nicht");
        return;
      }

      final bytes = await file.readAsBytes();
      String jsonString = '';

      try {
        jsonString = BackupService.parseBackupBytes(bytes);
      } on DecryptionException catch (e) {
        if (e.message == 'PASSWORD_REQUIRED') {
          // Prompt for password
          final pwd = await _promptPasswordDialog();
          if (pwd == null) return;
          jsonString = BackupService.parseBackupBytes(bytes, password: pwd);
        } else {
          rethrow;
        }
      }

      final Map<String, dynamic> backupData = json.decode(jsonString);

      // Confirm merge vs replace
      final merge = await _promptMergeOrOverwrite();
      if (merge == null) return;

      BackupService.restoreBackupData(provider, backupData, merge: merge);
      _showTactileSnackBar(isEn ? "kitchen profile restored successfully!" : "profil erfolgreich wiederhergestellt!");
      setState(() {
        _nameController.text = provider.profile.name;
      });
    } on DecryptionException catch (e) {
      _showTactileSnackBar(isEn ? "error: ${e.message}" : "fehler: ${e.message}");
    } catch (e) {
      _showTactileSnackBar(isEn ? "invalid format or corrupted backup file" : "ungültiges backup-format");
    }
  }

  Future<String?> _promptPasswordDialog() async {
    final isEn = Provider.of<AppProvider>(context, listen: false).currentLanguage == 'en';
    final textController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BrandColors.creamBg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            isEn ? "encrypted backup detected" : "verschlüsseltes backup erkannt",
            style: BrandFonts.displaySerif(fontSize: 18.0, italic: true),
          ),
          content: TextField(
            controller: textController,
            obscureText: true,
            cursorColor: BrandColors.charcoalInk,
            style: BrandFonts.mono(fontSize: 14.0),
            decoration: InputDecoration(
              hintText: isEn ? "enter backup password" : "passwort eingeben",
              isDense: true,
              border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(isEn ? "cancel" : "abbrechen", style: BrandFonts.mono(fontSize: 12.0)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, textController.text),
              style: ElevatedButton.styleFrom(backgroundColor: BrandColors.charcoalInk),
              child: Text(isEn ? "decrypt" : "entschlüsseln", style: BrandFonts.mono(fontSize: 12.0, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<bool?> _promptMergeOrOverwrite() async {
    final isEn = Provider.of<AppProvider>(context, listen: false).currentLanguage == 'en';
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BrandColors.creamBg,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Text(
            isEn ? "restore options" : "wiederherstellungsoptionen",
            style: BrandFonts.displaySerif(fontSize: 18.0, italic: true),
          ),
          content: Text(
            isEn
              ? "do you want to merge backup data into your current kitchen profile, or overwrite it completely?"
              : "möchtest du die daten zusammenführen oder dein aktuelles profil überschreiben?",
            style: BrandFonts.body(fontSize: 13.0),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(isEn ? "merge" : "zusammenführen", style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.teal)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, false),
              style: ElevatedButton.styleFrom(backgroundColor: BrandColors.coral),
              child: Text(isEn ? "overwrite" : "überschreiben", style: BrandFonts.mono(fontSize: 12.0, color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showTactileSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: BrandColors.charcoalInk,
        content: Text(
          text,
          style: BrandFonts.mono(fontSize: 11.0, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isEn = provider.currentLanguage == 'en';

    // Filter FAQs based on query and category
    final filteredFAQs = provider.faqs.where((faq) {
      final categoryStr = faq.category[isEn ? 'en' : 'de'] ?? '';
      final questionStr = faq.question[isEn ? 'en' : 'de'] ?? '';
      final answerStr = faq.answer[isEn ? 'en' : 'de'] ?? '';

      final matchesQuery = _faqQuery.isEmpty || 
          questionStr.toLowerCase().contains(_faqQuery.toLowerCase()) || 
          answerStr.toLowerCase().contains(_faqQuery.toLowerCase());
      
      final matchesCategory = _selectedFAQCategory.isEmpty || 
          categoryStr.toLowerCase() == _selectedFAQCategory.toLowerCase();

      return matchesQuery && matchesCategory;
    }).toList();

    final faqCategories = provider.faqs.map((f) => f.category[isEn ? 'en' : 'de']!).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: BrandColors.creamBg,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: BrandColors.charcoalInk, size: 18.0),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEn ? "kitchen settings" : "küchen-einstellungen",
          style: BrandFonts.displaySerif(fontSize: 20.0, italic: true, fontWeight: FontWeight.bold),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: DashedDivider(),
        ),
      ),
      body: PaperGrainBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION 1: Profile Editor ---
              _buildSectionHeader(isEn ? "CHEF PROFILE //" : "CHEF-PROFIL //"),
              const SizedBox(height: 12.0),
              _buildProfileEditor(provider, isEn),

              const SizedBox(height: 24.0),
              const DashedDivider(),
              const SizedBox(height: 16.0),

              // --- SECTION 2: Dietary Disclaimer ---
              _buildSectionHeader(isEn ? "HALAL & KOSHER NOTICE //" : "HALAL & KOSCHER HINWEIS //"),
              const SizedBox(height: 12.0),
              _buildDietaryDisclaimer(isEn),

              const SizedBox(height: 24.0),
              const DashedDivider(),
              const SizedBox(height: 16.0),

              // --- SECTION 3: Backup & Restore ---
              _buildSectionHeader(isEn ? "FILE-BASED BACKUP & RESTORE //" : "DATENSICHERUNG & RESTORE //"),
              const SizedBox(height: 12.0),
              _buildBackupPanel(isEn),

              const SizedBox(height: 24.0),
              const DashedDivider(),
              const SizedBox(height: 16.0),

              // --- SECTION 4: FAQ Searchable Help Center ---
              _buildSectionHeader(isEn ? "KITCHEN HELP CENTER //" : "KÜCHEN-RATGEBER //"),
              const SizedBox(height: 12.0),
              _buildFAQPanel(faqCategories, filteredFAQs, isEn),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: BrandFonts.mono(fontSize: 11.0, color: BrandColors.coral, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildProfileEditor(AppProvider provider, bool isEn) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
      ),
      child: Column(
        children: [
          // Name Input
          TextField(
            controller: _nameController,
            cursorColor: BrandColors.charcoalInk,
            style: BrandFonts.mono(fontSize: 14.0),
            decoration: InputDecoration(
              labelText: isEn ? "Chef Name" : "Name des Chefs",
              labelStyle: BrandFonts.displaySerif(fontSize: 14.0, italic: true),
              isDense: true,
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BrandColors.coral)),
            ),
            onChanged: (_) => _saveProfileChanges(),
          ),

          const SizedBox(height: 16.0),

          // Language Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn ? "Language" : "Sprache",
                style: BrandFonts.displaySerif(fontSize: 15.0, italic: true),
              ),
              DropdownButton<String>(
                value: provider.currentLanguage,
                underline: Container(height: 1, color: BrandColors.charcoalInk),
                onChanged: (val) {
                  if (val != null) provider.setLanguage(val);
                },
                items: const [
                  DropdownMenuItem(value: 'en', child: Text("English")),
                  DropdownMenuItem(value: 'de', child: Text("Deutsch")),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16.0),

          // Preference Sliders
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEn ? "Calorie Target" : "Kalorienziel", style: BrandFonts.displaySerif(fontSize: 14.0, italic: true)),
                  Text("${provider.profile.calorieTarget} kcal", style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.coral, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: provider.profile.calorieTarget.toDouble(),
                min: 300,
                max: 1000,
                divisions: 14,
                activeColor: BrandColors.coral,
                onChanged: (val) {
                  setState(() {
                    provider.profile.calorieTarget = val.toInt();
                  });
                  provider.saveProfile();
                },
              ),
            ],
          ),

          // Cooking Time Budget Slider
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(isEn ? "Max Cooking Time" : "Maximalzeit", style: BrandFonts.displaySerif(fontSize: 14.0, italic: true)),
                  Text("${provider.profile.maxTimeMinutes} mins", style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.teal, fontWeight: FontWeight.bold)),
                ],
              ),
              Slider(
                value: provider.profile.maxTimeMinutes.toDouble(),
                min: 15,
                max: 90,
                divisions: 5,
                activeColor: BrandColors.teal,
                onChanged: (val) {
                  setState(() {
                    provider.profile.maxTimeMinutes = val.toInt();
                  });
                  provider.saveProfile();
                },
              ),
            ],
          ),

          // Accessibility: Reduce Motion
          CheckboxListTile(
            title: Text(isEn ? "Reduce Motion" : "Animationen reduzieren", style: BrandFonts.displaySerif(fontSize: 14.0, italic: true)),
            subtitle: Text(isEn ? "smoothens / disables heavy transitions" : "schont systemleistung", style: BrandFonts.mono(fontSize: 10.0, color: BrandColors.softGrey)),
            activeColor: BrandColors.coral,
            value: provider.profile.reduceMotion ?? false,
            onChanged: (val) {
              setState(() {
                provider.profile.reduceMotion = val;
              });
              provider.saveProfile();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDietaryDisclaimer(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: BrandColors.paleCream,
        border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: BrandColors.coral, size: 18.0),
              const SizedBox(width: 8.0),
              Text(
                isEn ? "Dietary Compatibility Guide" : "Kompatibilitäts-Hinweis",
                style: BrandFonts.displaySerif(fontSize: 15.0, italic: true, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8.0),
          Text(
            isEn
              ? "We never claim 'halal-certified' or 'kosher-certified' inside the recipe text or copy. We surface 'halal-compatible ingredients' and 'kosher-compatible combinations' only. Certification is a property of the physical sourcing (supervision, slaughter methods), not of our recipe database."
              : "Wir weisen in Rezepten keine offizielle Halal- oder Koscher-Zertifizierung aus. Wir weisen lediglich auf Halal- oder Koscher-kompatible Zutaten hin. Zertifizierungen betreffen die physische Beschaffung der Ware vor Ort.",
            style: BrandFonts.body(fontSize: 13.0, color: BrandColors.charcoalInk),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupPanel(bool isEn) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: BrandColors.charcoalInk, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Optional Password Textfield
          TextField(
            controller: _backupPasswordController,
            obscureText: true,
            cursorColor: BrandColors.charcoalInk,
            style: BrandFonts.mono(fontSize: 13.0),
            decoration: InputDecoration(
              labelText: isEn ? "Optional Encryption Password" : "Verschlüsselungspasswort (Optional)",
              labelStyle: BrandFonts.displaySerif(fontSize: 13.0, italic: true),
              isDense: true,
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BrandColors.coral)),
            ),
          ),

          const SizedBox(height: 16.0),

          // Export Controls
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _exportBackup(false),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.charcoalInk,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: Text(isEn ? "EXPORT JSON" : "EXPORTIEREN", style: BrandFonts.mono(fontSize: 11.0, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _exportBackup(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: BrandColors.teal,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  ),
                  child: Text(isEn ? "EXPORT GZIP" : "COMPRIMIEREN", style: BrandFonts.mono(fontSize: 11.0, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12.0),
          const DashedDivider(),
          const SizedBox(height: 12.0),

          // Import controls
          TextField(
            controller: _backupFilePathController,
            cursorColor: BrandColors.charcoalInk,
            style: BrandFonts.mono(fontSize: 12.0),
            decoration: InputDecoration(
              labelText: isEn ? "File Path to Import" : "Dateipfad zum Importieren",
              labelStyle: BrandFonts.displaySerif(fontSize: 13.0, italic: true),
              isDense: true,
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: BrandColors.teal)),
            ),
          ),

          const SizedBox(height: 12.0),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _importBackup,
              style: OutlinedButton.styleFrom(
                foregroundColor: BrandColors.teal,
                side: const BorderSide(color: BrandColors.teal, width: 0.5),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              child: Text(isEn ? "RESTORE FROM BACKUP FILE" : "SICHERUNG RE-IMPORTIEREN", style: BrandFonts.mono(fontSize: 11.0, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQPanel(List<String> categories, List<FAQEntry> filteredFAQs, bool isEn) {
    return Column(
      children: [
        // FAQ Search textfield
        TextField(
          controller: _faqSearchController,
          cursorColor: BrandColors.charcoalInk,
          style: BrandFonts.mono(fontSize: 13.0),
          decoration: InputDecoration(
            hintText: isEn ? "search help articles..." : "hilfethemen suchen...",
            prefixIcon: const Icon(Icons.search, size: 16.0, color: BrandColors.charcoalInk),
            isDense: true,
            border: const OutlineInputBorder(borderRadius: BorderRadius.zero),
          ),
          onChanged: (val) {
            setState(() {
              _faqQuery = val;
            });
          },
        ),

        const SizedBox(height: 8.0),

        // Category scroll bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: Text(isEn ? "all" : "alle", style: BrandFonts.mono(fontSize: 10.0)),
                selected: _selectedFAQCategory.isEmpty,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                onSelected: (_) => setState(() => _selectedFAQCategory = ''),
              ),
              const SizedBox(width: 6.0),
              ...categories.map((cat) {
                final active = _selectedFAQCategory.toLowerCase() == cat.toLowerCase();
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: FilterChip(
                    label: Text(cat.toLowerCase(), style: BrandFonts.mono(fontSize: 10.0, color: active ? Colors.white : BrandColors.charcoalInk)),
                    selected: active,
                    selectedColor: BrandColors.coral,
                    checkmarkColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    onSelected: (_) => setState(() => _selectedFAQCategory = cat),
                  ),
                );
              }).toList(),
            ],
          ),
        ),

        const SizedBox(height: 12.0),

        // Expandable list tiles
        filteredFAQs.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(isEn ? "no help topics found." : "keine einträge gefunden.", style: BrandFonts.mono(fontSize: 12.0, color: BrandColors.softGrey)),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredFAQs.length,
              itemBuilder: (context, idx) {
                final entry = filteredFAQs[idx];
                final q = entry.question[isEn ? 'en' : 'de'] ?? '';
                final a = entry.answer[isEn ? 'en' : 'de'] ?? '';

                return Card(
                  color: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero, side: BorderSide(color: BrandColors.dashedLine, width: 0.5)),
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8.0),
                  child: ExpansionTile(
                    collapsedTextColor: BrandColors.charcoalInk,
                    textColor: BrandColors.coral,
                    iconColor: BrandColors.coral,
                    title: Text(q.toLowerCase(), style: BrandFonts.displaySerif(fontSize: 14.0, italic: true, fontWeight: FontWeight.bold)),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
                        child: Text(a, style: BrandFonts.body(fontSize: 13.0, color: BrandColors.charcoalInk)),
                      ),
                    ],
                  ),
                );
              },
            ),
      ],
    );
  }
}
