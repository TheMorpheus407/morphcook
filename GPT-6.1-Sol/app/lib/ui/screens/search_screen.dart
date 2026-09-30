import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/pagination.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'dish_screen.dart';
import 'help_screen.dart';

class SearchScreen extends StatefulWidget {
  final void Function(Recipe)? onSelect;
  final bool embedded;
  const SearchScreen({super.key, this.onSelect, this.embedded = false});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final field = TextEditingController();
  final tags = <String>{};
  Timer? debounce;
  String query = '';
  String? profileFingerprint;
  PaginationController<Recipe>? pages;
  List<Recipe>? _results;
  int _queryGeneration = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    final fingerprint = jsonEncode(state.profile.toJson());
    pages ??= PaginationController(
      loader: (cursor, limit) async {
        if (_results == null) {
          final generation = _queryGeneration;
          final currentQuery = query;
          final results = await state.repository.search(
            currentQuery,
            Set.of(tags),
            state.profile.copy(),
          );
          if (!mounted || generation != _queryGeneration) {
            return PageResult([], null);
          }
          _results = results;
          if (results.isEmpty &&
              currentQuery.trim().isNotEmpty &&
              currentQuery == query) {
            Future.microtask(() => state.logContentRequest(currentQuery));
          }
        }
        return cursorPage(_results!, cursor, limit, (recipe) => recipe.id);
      },
    );
    if (fingerprint != profileFingerprint) {
      profileFingerprint = fingerprint;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) refresh();
      });
    }
  }

  void refresh() {
    _queryGeneration++;
    _results = null;
    pages!.refresh();
  }

  @override
  void dispose() {
    field.dispose();
    debounce?.cancel();
    pages?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final values = [
      'all',
      'quick',
      'breakfast',
      'lunch',
      'dinner',
      'cozy',
      'one-pot',
      'italian',
      'asian',
      'middle-eastern',
      'sweet',
    ];
    return Column(
      children: [
        if (!widget.embedded)
          PageHeading(
            title: t(context, 'discoverTitle'),
            subtitle: t(context, 'discoverSubtitle'),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(22, widget.embedded ? 15 : 0, 22, 4),
          child: TextField(
            controller: field,
            onChanged: (value) {
              debounce?.cancel();
              debounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted) {
                  query = value;
                  refresh();
                }
              });
            },
            onSubmitted: (value) {
              debounce?.cancel();
              query = value;
              refresh();
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, size: 20),
              hintText: t(context, 'searchHint'),
              suffixIcon: IconButton(
                tooltip: t(context, 'close'),
                onPressed: () {
                  debounce?.cancel();
                  field.clear();
                  query = '';
                  refresh();
                },
                icon: const Icon(Icons.close, size: 17),
              ),
            ),
          ),
        ),
        ChipStrip(
          values: values,
          label: (value) => value == 'all'
              ? t(context, 'all')
              : textFor(
                  context,
                  state.repository.ontology.label('tag_labels', value),
                ),
          selected: (value) =>
              value == 'all' ? tags.isEmpty : tags.contains(value),
          onTap: (value) {
            setState(() {
              if (value == 'all') {
                tags.clear();
              } else if (!tags.add(value)) {
                tags.remove(value);
              }
            });
            refresh();
          },
        ),
        Expanded(
          child: PagedRecipes(
            controller: pages!,
            onOpen: (recipe) => widget.onSelect != null
                ? widget.onSelect!(recipe)
                : openRecipe(context, recipe),
            empty: EmptyPaper(
              title: t(context, 'noResults'),
              body: t(context, 'noResultsBody'),
              icon: Icons.search,
              action: Column(
                children: [
                  TextButton(
                    onPressed: () => openHelp(context, 'visibility'),
                    child: Text(t(context, 'profileHelp')),
                  ),
                  if (query.trim().isNotEmpty)
                    Text(
                      t(context, 'requestRemembered'),
                      style: mono(10),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
