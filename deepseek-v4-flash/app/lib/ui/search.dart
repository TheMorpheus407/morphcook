import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/theme.dart';
import '../data/services.dart';
import '../models/models.dart';
import 'dish_detail.dart';
import 'widgets.dart';

/// Full-text search over loaded recipes plus the local "wish list" of
/// content requests for the next corpus edition.
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final svc = Services.of(context);
    final lang = svc.state.lang;
    String t(String k) => L10n.strings(lang, k);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t(L10n.tSearchRecipes),
          style: AppText.serif(context, size: 18, weight: FontWeight.w700),
        ),
      ),
      body: ListenableBuilder(
        listenable: svc.state,
        builder: (context, _) {
          final q = _query.trim();
          final results = q.isEmpty ? const <Recipe>[] : svc.corpus.search(q, lang);
          final requests = svc.state.contentRequests;
          return SingleChildScrollView(
            child: Center(
              child: ZinePage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      autofocus: true,
                      onChanged: (v) => setState(() => _query = v),
                      style: AppText.mono(context, size: 12),
                      decoration: InputDecoration(
                        hintText: t(L10n.tSearchHint),
                        prefixIcon: const Icon(Icons.search, size: 17),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: t(L10n.tClear),
                                icon: const Icon(Icons.close, size: 17),
                                onPressed: () {
                                  _controller.clear();
                                  setState(() => _query = '');
                                },
                              ),
                      ),
                    ),
                    if (q.isNotEmpty && results.isEmpty)
                      _noResults(context, t)
                    else
                      for (final (i, r) in results.indexed)
                        ZebraRow(
                          index: i,
                          onTap: () => _open(context, r),
                          child: _resultRow(context, r, lang, t),
                        ),
                    const SizedBox(height: 8),
                    SectionHeader(
                      title: t(L10n.tBacklogFeed),
                      kicker: 'backlog',
                    ),
                    if (requests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          t(L10n.tBacklogEmpty),
                          style: AppText.mono(
                              context, size: 11, color: AppColors.inkFaint),
                        ),
                      )
                    else
                      for (final (i, req) in requests.indexed)
                        ZebraRow(
                          index: i,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  req,
                                  style: AppText.mono(
                                      context, size: 11, color: AppColors.ink),
                                ),
                              ),
                              IconButton(
                                tooltip: t(L10n.tClear),
                                icon: const Icon(Icons.delete_outline,
                                    size: 17, color: AppColors.inkFaint),
                                onPressed: () =>
                                    svc.state.removeContentRequest(req),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _dishName(Recipe r, String lang) {
    final dish = Services.of(context).corpus.dishById(r.dishId);
    if (dish == null) {
      return r.title[lang]?.toString() ?? r.title['en']?.toString() ?? r.id;
    }
    return dish.canonicalName[lang]?.toString() ??
        dish.canonicalName['en']?.toString() ??
        dish.id;
  }

  void _open(BuildContext context, Recipe r) {
    final dish = Services.of(context).corpus.dishById(r.dishId);
    if (dish == null) return;
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DishDetailPage(dish: dish, initialRecipe: r),
      ),
    );
  }

  Widget _resultRow(
      BuildContext context, Recipe r, String lang, String Function(String) t) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _dishName(r, lang),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.serif(context, size: 16),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${r.diet} · ${r.timeMinutes} ${t(L10n.tMinutes).toLowerCase()}',
          style: AppText.mono(context, size: 10, color: AppColors.inkFaint),
        ),
      ],
    );
  }

  Future<void> _requestDialog(String Function(String) t) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          t(L10n.tStringIt),
          style: AppText.serif(context, size: 18, weight: FontWeight.w700),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          maxLines: 3,
          style: AppText.mono(context, size: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(t(L10n.tCancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(t(L10n.tSave)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    Services.of(context).state.addContentRequest(text.trim());
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(t(L10n.tRequestSaved))));
  }

  Widget _noResults(BuildContext context, String Function(String) t) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Text(
                t(L10n.tNoResults),
                style: AppText.mono(
                    context, size: 11, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () => _requestDialog(t),
                icon: const Icon(Icons.edit_note, size: 15),
                label: Text(t(L10n.tStringIt)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}