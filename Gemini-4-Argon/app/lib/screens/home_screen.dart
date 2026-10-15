import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/nostalgic_theme.dart';
import '../widgets/nostalgic_widgets.dart';
import 'cook_mode_screen.dart';
import 'dish_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedPartition = ''; // '' = all loaded, or cuisine-italian, cuisine-asian, cuisine-middle-eastern, extended

  Future<void> _selectPartition(String partitionId) async {
    final appState = context.read<MorphCookAppState>();
    if (partitionId.isNotEmpty) {
      await appState.ensurePartitionLoaded(partitionId);
    } else {
      await appState.corpus.ensureAllPartitionsLoaded();
    }
    if (!mounted) return;
    setState(() => _selectedPartition = partitionId);
  }

  String _temporalEditionSubtitle(DateTime now, String lang) {
    final isDe = lang == 'de';
    final hour = now.hour;
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    if (hour >= 5 && hour < 11) {
      return isDe
          ? 'morgen-ausgabe (5–11 uhr) · frühstück im fokus'
          : 'morning edition (5am–11am) · breakfast forward';
    }
    if (hour >= 17 && hour < 21) {
      return isDe
          ? 'abend-ausgabe (17–21 uhr) · warme abendgerichte'
          : 'evening edition (5pm–9pm) · supper & comfort';
    }
    if (isWeekend) {
      return isDe
          ? 'wochenend-ausgabe · zeit für genuss & handwerk'
          : 'weekend edition · slow-simmer & kitchen projects';
    }
    return isDe
        ? 'tages-ausgabe · abgestimmt auf dein profil'
        : 'daily kitchen ledger · tailored to your table';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MorphCookAppState>();
    final lang = appState.lang;
    final isDe = lang == 'de';
    final ranked = appState.getRankedDishes(
      partitionFilter: _selectedPartition.isEmpty ? null : _selectedPartition,
    );
    final activeSession = appState.activeCookSession;
    final sessionRecipe = activeSession != null
        ? appState.corpus.recipeById(activeSession.recipeId)
        : null;

    return PaperGrainBackground(
      child: CustomScrollView(
        slivers: [
          // Newspaper-style Masthead
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'vol. i · issue ${appState.now.day}.${appState.now.month}',
                        style: NostalgicTheme.mono(fontSize: 10.5),
                      ),
                      Text(
                        _temporalEditionSubtitle(appState.now, lang),
                        style: NostalgicTheme.mono(
                          fontSize: 10.5,
                          color: NostalgicPalette.terracotta,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const DashedRule(),
                  const SizedBox(height: 4),
                  Text(
                    'morphcook',
                    style: NostalgicTheme.serifDisplay(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  Text(
                    isDe
                        ? 'das persönliche kochbuch für ${appState.profile.name.toLowerCase()} — jedes gericht für jeden körper'
                        : '${appState.profile.name.toLowerCase()}’s kitchen ledger — the same dish for every body',
                    textAlign: TextAlign.center,
                    style: NostalgicTheme.handwritten(
                      fontSize: 19,
                      color: NostalgicPalette.fadedInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const DashedRule(),
                ],
              ),
            ),
          ),

          // Resume Paused Cook Mode Banner
          if (activeSession != null && sessionRecipe != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
                child: Container(
                  key: const ValueKey('resume_cook_session_banner'),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: NostalgicPalette.cookDarkSurface,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: NostalgicPalette.saffron),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.play_circle_fill,
                        color: NostalgicPalette.saffron,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDe
                                  ? 'kochmodus fortsetzen (schritt 0${activeSession.currentStepIndex + 1})'
                                  : 'resume cook mode (step 0${activeSession.currentStepIndex + 1})',
                              style: NostalgicTheme.mono(
                                fontSize: 11,
                                color: NostalgicPalette.saffron,
                              ),
                            ),
                            Text(
                              sessionRecipe.title.resolve(lang),
                              style: NostalgicTheme.serifDisplay(
                                fontSize: 16.5,
                                color: NostalgicPalette.cookDarkInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('resume_cook_session_btn'),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CookModeScreen(
                                recipe: sessionRecipe,
                                dish: appState.corpus
                                    .dishById(sessionRecipe.dishId),
                                initialServings: activeSession.scaledServings,
                                restoredSession: activeSession,
                              ),
                            ),
                          );
                        },
                        child: Text(
                          isDe ? 'WEITER →' : 'RESUME →',
                          style: NostalgicTheme.mono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: NostalgicPalette.saffron,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Cuisine / Partition Filter Strip
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Row(
                children: [
                  _partitionChip(
                    id: '',
                    label: isDe ? 'alle ausgaben' : 'all dishes',
                  ),
                  const SizedBox(width: 8),
                  _partitionChip(
                    id: 'cuisine-middle-eastern',
                    label: isDe ? 'orientalisch & berlin' : 'levant & street',
                  ),
                  const SizedBox(width: 8),
                  _partitionChip(
                    id: 'cuisine-italian',
                    label: isDe ? 'italienisch' : 'italian',
                  ),
                  const SizedBox(width: 8),
                  _partitionChip(
                    id: 'cuisine-asian',
                    label: isDe ? 'asiatisch' : 'asian wok & broth',
                  ),
                  const SizedBox(width: 8),
                  _partitionChip(
                    id: 'extended',
                    label: isDe ? 'raritäten (extended)' : 'extended vault',
                  ),
                ],
              ),
            ),
          ),

          // Featured Dish ("Dish of the Hour")
          if (ranked.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DashedRule(
                      label: isDe
                          ? '✦ empfehlung der stunde ✦'
                          : '✦ featured dish of the hour ✦',
                    ),
                    const SizedBox(height: 10),
                    PolaroidDishCard(
                      dish: ranked.first.dish,
                      variant: ranked.first.variant,
                      lang: lang,
                      showVariantTag: appState.profile.showVariantTags,
                      isSaved: appState.isRecipeSaved(ranked.first.variant.id),
                      rotationIndex: 0,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DishDetailScreen(
                              dish: ranked.first.dish,
                              initialRecipe: ranked.first.variant,
                            ),
                          ),
                        );
                      },
                      onToggleSave: () => appState
                          .toggleSaveRecipe(ranked.first.variant.id),
                    ),
                  ],
                ),
              ),
            ),

          // Section Divider for Grid
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
              child: DashedRule(
                label: isDe
                    ? 'aus deiner küchen-sammlung (${ranked.length})'
                    : 'from your kitchen collection (${ranked.length})',
              ),
            ),
          ),

          // Dishes Grid / List
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
            sliver: SliverList.separated(
              itemCount: ranked.length > 1 ? ranked.length - 1 : ranked.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final entry =
                    ranked.length > 1 ? ranked[index + 1] : ranked[index];
                return PolaroidDishCard(
                  key: ValueKey('home_dish_card_${entry.dish.id}'),
                  dish: entry.dish,
                  variant: entry.variant,
                  lang: lang,
                  showVariantTag: appState.profile.showVariantTags,
                  isSaved: appState.isRecipeSaved(entry.variant.id),
                  rotationIndex: index + 1,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => DishDetailScreen(
                          dish: entry.dish,
                          initialRecipe: entry.variant,
                        ),
                      ),
                    );
                  },
                  onToggleSave: () =>
                      appState.toggleSaveRecipe(entry.variant.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _partitionChip({required String id, required String label}) {
    final selected = _selectedPartition == id;
    return ChoiceChip(
      key: ValueKey('partition_chip_${id.isEmpty ? "all" : id}'),
      selected: selected,
      label: Text(label),
      onSelected: (_) => _selectPartition(id),
    );
  }
}
