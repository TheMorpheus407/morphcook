import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'profile_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int page = 0;
  Profile? draft;
  final nameController = TextEditingController();
  final scrollController = ScrollController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (draft == null) {
      draft = AppScope.of(context).profile.copy();
      nameController.text = draft!.name;
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void move(int delta) {
    if (delta > 0 && page == 1 && draft!.name.trim().isEmpty) {
      toast(context, 'nameRequired');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => page = (page + delta).clamp(0, 4));
    if (scrollController.hasClients) scrollController.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final title = [
      'onboardWelcome',
      'onboardName',
      'onboardDiet',
      'onboardTargets',
      'onboardConfirm',
    ][page];
    return PaperScaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 26, 26, 15),
                child: Row(
                  children: [
                    Text(t(context, 'brand'), style: serif(30, italic: true)),
                    const Spacer(),
                    Text(
                      t(context, 'onboardStep', {'step': page + 1}),
                      style: mono(9, spacing: 1),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Row(
                  children: [
                    for (var i = 0; i < 5; i++)
                      Expanded(
                        child: Container(
                          height: 3,
                          margin: EdgeInsets.only(right: i == 4 ? 0 : 6),
                          color: i <= page
                              ? KitchenColors.teal
                              : KitchenColors.line,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(26, 34, 26, 24),
                  child: AnimatedSwitcher(
                    duration: motionDuration(context),
                    child: Column(
                      key: ValueKey(page),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (page == 0) ...[
                          SizedBox(
                            height: 180,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Transform.rotate(
                                  angle: -.04,
                                  child: Container(
                                    width: 255,
                                    height: 155,
                                    decoration: BoxDecoration(
                                      color: KitchenColors.card,
                                      border: Border.all(
                                        color: KitchenColors.line,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: KitchenColors.ink.withValues(
                                            alpha: .06,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(4, 6),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(9),
                                    child: RecipeArt(
                                      dish: state.repository.dishes['doener']!,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 3,
                                  right: 22,
                                  child: Transform.rotate(
                                    angle: -.06,
                                    child: Text(
                                      t(context, 'tagline'),
                                      style: hand(22),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 26),
                        ],
                        Text(t(context, title), style: serif(39, italic: true)),
                        const SizedBox(height: 14),
                        Text(t(context, '${title}Body'), style: mono(12)),
                        const SizedBox(height: 30),
                        if (page == 0) ...[
                          Text(t(context, 'onboardLanguage'), style: mono(12)),
                          const SizedBox(height: 18),
                          Row(
                            children: ['en', 'de']
                                .map(
                                  (lang) => Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        right: lang == 'en' ? 10 : 0,
                                      ),
                                      child: ChoiceChip(
                                        label: SizedBox(
                                          width: double.infinity,
                                          child: Center(
                                            child: Text(
                                              t(
                                                context,
                                                lang == 'en'
                                                    ? 'english'
                                                    : 'german',
                                              ),
                                            ),
                                          ),
                                        ),
                                        selected: draft!.lang == lang,
                                        onSelected: (_) {
                                          setState(() => draft!.lang = lang);
                                          state.updateProfile(draft!.copy());
                                        },
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                        if (page == 1)
                          TextField(
                            controller: nameController,
                            autofocus: true,
                            maxLength: 100,
                            textCapitalization: TextCapitalization.words,
                            onChanged: (value) => draft!.name = value.trim(),
                            onSubmitted: (_) => move(1),
                            decoration: InputDecoration(
                              hintText: t(context, 'nameHint'),
                            ),
                          ),
                        if (page == 2)
                          DietFields(
                            draft: draft!,
                            onChanged: () => setState(() {}),
                          ),
                        if (page == 3)
                          TargetFields(
                            draft: draft!,
                            onChanged: () => setState(() {}),
                          ),
                        if (page == 4)
                          NoteCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t(context, 'hello', {'name': draft!.name}),
                                  style: hand(32),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  translate(
                                    state.repository.ontology.label(
                                      'diets',
                                      draft!.diet,
                                    ),
                                    draft!.lang,
                                  ),
                                  style: mono(14, color: KitchenColors.ink),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t(context, 'minutes', {
                                    'count': draft!.maxTimeMinutes,
                                  }),
                                  style: mono(12),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  t(context, 'calorieRange', {
                                    'min':
                                        (draft!.calorieTarget -
                                                draft!.calorieTolerance)
                                            .clamp(0, 10000),
                                    'max':
                                        draft!.calorieTarget +
                                        draft!.calorieTolerance,
                                  }),
                                  style: mono(12),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  translate(
                                    state.repository.ontology.valueLabel(
                                      'effort',
                                      draft!.preferredEffort,
                                    ),
                                    draft!.lang,
                                  ),
                                  style: mono(12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 12, 26, 24),
                child: Row(
                  children: [
                    if (page > 0) ...[
                      IconButton(
                        tooltip: t(context, 'back'),
                        onPressed: () => move(-1),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          if (page < 4) {
                            move(1);
                            return;
                          }
                          draft!.onboarded = true;
                          state.updateProfile(draft!.copy());
                          try {
                            await state.flush();
                          } catch (_) {
                            if (context.mounted) toast(context, 'storageError');
                          }
                        },
                        child: Text(
                          t(context, page == 4 ? 'openKitchen' : 'next'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
