import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_state.dart';
import '../../logic/feedback.dart';
import '../theme.dart';

/// A local composer. Opening a draft is a deliberate external-browser action;
/// submitting it remains the user's decision on GitHub.
class FeedbackScreen extends StatefulWidget {
  final Future<bool> Function(Uri)? openDraft;
  final Future<void> Function(String)? copyDraft;

  const FeedbackScreen({super.key, this.openDraft, this.copyDraft});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  String? _status;

  String _t(String en, String de) =>
      context.read<AppState>().lang == 'de' ? de : en;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  String? _validate(String? value, int maximum) {
    if (value == null || value.trim().isEmpty) {
      return _t('Please enter some text.', 'Bitte Text eingeben.');
    }
    if (value.trim().length > maximum) {
      return _t('Please shorten this text.', 'Bitte diesen Text kürzen.');
    }
    return null;
  }

  Future<void> _openDraft() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    late final Uri uri;
    try {
      uri = buildFeedbackDraftUrl(title: _title.text, message: _message.text);
    } on FeedbackDraftException {
      setState(() {
        _status = _t(
          'This draft is too long for a browser link. Shorten it or copy your feedback below.',
          'Dieser Entwurf ist zu lang für einen Browser-Link. Kürze ihn oder kopiere dein Feedback unten.',
        );
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = null;
    });
    var opened = false;
    try {
      opened =
          await (widget.openDraft?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // An unavailable browser, platform error, or refusal all have the same
      // recovery: preserve the draft and offer copying.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = opened
          ? _t(
              'Draft opened in your browser. Review it and submit it there.',
              'Der Entwurf wurde im Browser geöffnet. Prüfe ihn und sende ihn dort ab.',
            )
          : _t(
              'The browser could not open the draft. Your text is still here; use Copy feedback or try again.',
              'Der Browser konnte den Entwurf nicht öffnen. Dein Text bleibt hier; nutze Feedback kopieren oder versuche es erneut.',
            );
    });
  }

  Future<void> _copyDraft() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final text = feedbackClipboardText(
      title: _title.text,
      message: _message.text,
    );
    setState(() {
      _busy = true;
      _status = null;
    });
    var copied = false;
    try {
      if (widget.copyDraft != null) {
        await widget.copyDraft!(text);
      } else {
        await Clipboard.setData(ClipboardData(text: text));
      }
      copied = true;
    } catch (_) {
      // Keep the controllers intact so the user can retry or select the text.
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = copied
          ? _t('Feedback copied.', 'Feedback kopiert.')
          : _t(
              'Copying failed. Try again or select and copy the text in the fields.',
              'Kopieren fehlgeschlagen. Versuche es erneut oder markiere und kopiere den Text in den Feldern.',
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>();
    final morph = MorphTheme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Feedback',
          style: morph.text.display.copyWith(fontSize: 22),
        ),
      ),
      body: PaperBackground(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _t(
                    'Describe a problem or suggestion. For a problem, include what you did, what you expected, and what happened.',
                    'Beschreibe ein Problem oder einen Vorschlag. Nenne bei Problemen deine Schritte, das erwartete Ergebnis und was tatsächlich passiert ist.',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _t(
                    'Open GitHub draft sends only the text you enter below to your browser and GitHub. Review and submit it there yourself; nothing is posted automatically. Submitted issues are public and GitHub may require sign-in. No profile, recipes, or logs are attached. Leave out private information. Copy feedback works offline. Leaving this screen discards the local draft.',
                    'GitHub-Entwurf öffnen übergibt nur deinen unten eingegebenen Text an den Browser und GitHub. Prüfe und sende ihn dort selbst ab; nichts wird automatisch veröffentlicht. Gesendete Issues sind öffentlich und GitHub kann eine Anmeldung verlangen. Profil, Rezepte und Protokolle werden nicht angehängt. Lass private Angaben weg. Feedback kopieren funktioniert offline. Beim Verlassen dieser Seite wird der lokale Entwurf verworfen.',
                  ),
                  style: TextStyle(color: morph.colors.inkSoft),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  key: const ValueKey('feedback-title'),
                  controller: _title,
                  enabled: !_busy,
                  maxLength: maxFeedbackTitleLength,
                  decoration: InputDecoration(labelText: _t('Title', 'Titel')),
                  validator: (value) =>
                      _validate(value, maxFeedbackTitleLength),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('feedback-message'),
                  controller: _message,
                  enabled: !_busy,
                  maxLength: maxFeedbackMessageLength,
                  minLines: 5,
                  maxLines: 10,
                  decoration: InputDecoration(
                    labelText: _t('Your feedback', 'Dein Feedback'),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      _validate(value, maxFeedbackMessageLength),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  key: const ValueKey('open-feedback-draft'),
                  onPressed: _busy ? null : _openDraft,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(_t('Open GitHub draft', 'GitHub-Entwurf öffnen')),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const ValueKey('copy-feedback'),
                  onPressed: _busy ? null : _copyDraft,
                  icon: const Icon(Icons.copy_outlined),
                  label: Text(_t('Copy feedback', 'Feedback kopieren')),
                ),
                TextButton(
                  key: const ValueKey('cancel-feedback'),
                  onPressed: _busy
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: Text(_t('Cancel', 'Abbrechen')),
                ),
                if (_status != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _status!,
                      key: const ValueKey('feedback-status'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
