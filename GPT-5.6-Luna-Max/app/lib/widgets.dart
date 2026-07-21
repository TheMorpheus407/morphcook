import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.child, this.dark = false});

  final Widget child;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: dark ? night : paper,
      child: CustomPaint(
        painter: PaperTexturePainter(dark: dark),
        child: SafeArea(child: child),
      ),
    );
  }
}

class PaperTexturePainter extends CustomPainter {
  PaperTexturePainter({this.dark = false});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final base = dark ? night : paper;
    canvas.drawColor(base, BlendMode.srcOver);
    final grain = Paint()
      ..color = (dark ? Colors.white : ink).withValues(
        alpha: dark ? 0.025 : 0.035,
      )
      ..strokeWidth = 0.6;
    for (var y = 8.0; y < size.height; y += 17) {
      final offset = math.sin(y * 0.09) * 5;
      canvas.drawLine(Offset(offset, y), Offset(size.width + offset, y), grain);
    }
    final fleck = Paint()
      ..color = (dark ? Colors.white : ink).withValues(
        alpha: dark ? 0.035 : 0.05,
      );
    for (var i = 0; i < 160; i++) {
      final x = (i * 73.0) % (size.width + 40) - 20;
      final y = (i * 127.0) % (size.height + 40) - 20;
      canvas.drawCircle(Offset(x, y), i % 3 == 0 ? 0.8 : 0.45, fleck);
    }
  }

  @override
  bool shouldRepaint(covariant PaperTexturePainter oldDelegate) =>
      oldDelegate.dark != dark;
}

class StripeArt extends StatelessWidget {
  const StripeArt({
    super.key,
    required this.color,
    required this.caption,
    this.pattern = 1,
    this.height,
    this.child,
    this.borderRadius = 2,
  });

  final Color color;
  final String caption;
  final int pattern;
  final double? height;
  final Widget? child;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CustomPaint(
        painter: StripePainter(color: color, pattern: pattern),
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Align(
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: -0.035,
                  child: Text(
                    caption,
                    textAlign: TextAlign.center,
                    style: displayStyle(
                      size: 25,
                      color: ink.withValues(alpha: 0.66),
                      style: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              if (child != null) child!,
            ],
          ),
        ),
      ),
    );
  }
}

class StripePainter extends CustomPainter {
  StripePainter({required this.color, required this.pattern});

  final Color color;
  final int pattern;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(color.withValues(alpha: 0.92), BlendMode.srcOver);
    final lighter = Paint()..color = Colors.white.withValues(alpha: 0.32);
    final darker = Paint()..color = ink.withValues(alpha: 0.07);
    final spacing = pattern.isEven ? 18.0 : 23.0;
    if (pattern % 3 == 0) {
      for (var x = -size.height; x < size.width + size.height; x += spacing) {
        canvas.drawLine(
          Offset(x, 0),
          Offset(x + size.height, size.height),
          lighter..strokeWidth = 8,
        );
        canvas.drawLine(
          Offset(x + 10, 0),
          Offset(x + size.height + 10, size.height),
          darker..strokeWidth = 1,
        );
      }
    } else if (pattern.isEven) {
      for (var y = 0.0; y < size.height; y += spacing) {
        canvas.drawRect(Rect.fromLTWH(0, y, size.width, 9), lighter);
        canvas.drawLine(
          Offset(0, y + 11),
          Offset(size.width, y + 11),
          darker..strokeWidth = 1,
        );
      }
    } else {
      for (var x = 0.0; x < size.width; x += spacing) {
        canvas.drawRect(Rect.fromLTWH(x, 0, 9, size.height), lighter);
        canvas.drawLine(
          Offset(x + 12, 0),
          Offset(x + 12, size.height),
          darker..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StripePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.pattern != pattern;
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false, this.small = false});

  final bool light;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final color = light ? whiteInk : ink;
    return RichText(
      text: TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: 'morph',
            style: displayStyle(
              size: small ? 22 : 27,
              color: color,
              style: FontStyle.italic,
            ),
          ),
          TextSpan(
            text: 'cook',
            style: displayStyle(
              size: small ? 22 : 27,
              color: light ? sea : seaDeep,
            ),
          ),
        ],
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    super.key,
    this.color = inkMuted,
    this.center = false,
  });

  final String text;
  final Color color;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: monoStyle(color: color),
    );
  }
}

class HandNote extends StatelessWidget {
  const HandNote(this.text, {super.key, this.color = coral, this.size = 24});

  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: handStyle(size: size, color: color),
  );
}

class DashedRule extends StatelessWidget {
  const DashedRule({
    super.key,
    this.color = const Color(0xFFCDBEAD),
    this.padding = 12,
  });

  final Color color;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: padding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = (constraints.maxWidth / 10).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(
              count,
              (_) =>
                  SizedBox(width: 5, child: Divider(color: color, height: 1)),
            ),
          );
        },
      ),
    );
  }
}

class PageTopBar extends StatelessWidget {
  const PageTopBar({
    super.key,
    this.title,
    this.showBack = false,
    this.onBack,
    this.trailing,
    this.dark = false,
  });

  final String? title;
  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final foreground = dark ? whiteInk : ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: <Widget>[
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_rounded, color: foreground),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            )
          else
            const SizedBox(width: 4),
          Expanded(
            child: title == null
                ? BrandMark(light: dark)
                : Text(
                    title!,
                    style: displayStyle(size: 24, color: foreground),
                  ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.onTap});

  final String name;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'M'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .map((part) => part[0])
              .take(2)
              .join()
              .toUpperCase();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: coral,
          shape: BoxShape.circle,
          border: Border.all(color: ink, width: 1.2),
        ),
        alignment: Alignment.center,
        child: Text(initials, style: monoStyle(size: 11, color: ink)),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 17),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: ink,
        foregroundColor: whiteInk,
        disabledBackgroundColor: ink.withValues(alpha: 0.25),
        disabledForegroundColor: whiteInk.withValues(alpha: 0.8),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: monoStyle(size: 10, color: whiteInk),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = ink,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        textStyle: monoStyle(size: 10, color: color),
      ),
    );
  }
}

class TagPill extends StatelessWidget {
  const TagPill(
    this.label, {
    super.key,
    this.color = sea,
    this.textColor = ink,
    this.compact = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.72),
        border: Border.all(color: textColor.withValues(alpha: 0.17)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: monoStyle(
          size: compact ? 9 : 10,
          color: textColor,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.lang,
    required this.onTap,
    this.onSave,
    this.wide = false,
  });

  final Recipe recipe;
  final String lang;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final card = Transform.rotate(
      angle: wide ? -0.006 : (recipe.id.hashCode.isEven ? -0.012 : 0.009),
      child: Material(
        color: const Color(0xFFF9F5ED),
        elevation: 1.2,
        shadowColor: ink.withValues(alpha: 0.18),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: wide ? 170 : 122,
                  child: StripeArt(
                    color: Color(recipe.accent),
                    caption: recipe.caption(lang),
                    pattern: recipe.id.hashCode.abs() % 6 + 1,
                    height: double.infinity,
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(7),
                        child: onSave == null
                            ? null
                            : IconButton(
                                onPressed: onSave,
                                style: IconButton.styleFrom(
                                  backgroundColor: paper.withValues(
                                    alpha: 0.86,
                                  ),
                                  foregroundColor: ink,
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(30, 30),
                                ),
                                icon: const Icon(
                                  Icons.bookmark_border_rounded,
                                  size: 17,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 11),
                Text(
                  recipe.name(lang),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: displayStyle(size: wide ? 23 : 18),
                ),
                const SizedBox(height: 5),
                Text(
                  recipe.subline(lang),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: monoStyle(
                    size: 9,
                    color: inkMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: <Widget>[
                    Icon(Icons.schedule_rounded, size: 14, color: seaDeep),
                    const SizedBox(width: 4),
                    Text(
                      '${recipe.timeMinutes} min',
                      style: monoStyle(
                        size: 9,
                        color: inkMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${recipe.calories} kcal',
                      style: monoStyle(
                        size: 9,
                        color: inkMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return card;
  }
}

class CompactRecipeTile extends StatelessWidget {
  const CompactRecipeTile({
    super.key,
    required this.recipe,
    required this.lang,
    required this.onTap,
    this.trailing,
  });

  final Recipe recipe;
  final String lang;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9F5ED),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 74,
                height: 74,
                child: StripeArt(
                  color: Color(recipe.accent),
                  caption: recipe.diet,
                  pattern: recipe.id.hashCode.abs() % 6 + 1,
                  height: 74,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      recipe.name(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: displayStyle(size: 19),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recipe.subline(lang),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: monoStyle(
                        size: 9,
                        color: inkMuted,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${recipe.timeMinutes} min  /  ${recipe.calories} kcal',
                      style: monoStyle(
                        size: 9,
                        color: seaDeep,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.action,
    this.onAction,
  });

  final String eyebrow;
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Eyebrow(eyebrow),
              const SizedBox(height: 4),
              Text(title, style: displayStyle(size: 25)),
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: seaDeep,
              padding: EdgeInsets.zero,
            ),
            child: Text(action!, style: monoStyle(size: 9, color: seaDeep)),
          ),
      ],
    );
  }
}

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final AppTab current;
  final ValueChanged<AppTab> onChanged;

  @override
  Widget build(BuildContext context) {
    const items = <({AppTab tab, IconData icon, String label})>[
      (tab: AppTab.home, icon: Icons.home_outlined, label: 'home'),
      (
        tab: AppTab.cookbook,
        icon: Icons.bookmark_border_rounded,
        label: 'book',
      ),
      (tab: AppTab.plan, icon: Icons.calendar_month_outlined, label: 'plan'),
      (tab: AppTab.search, icon: Icons.search_rounded, label: 'find'),
      (tab: AppTab.settings, icon: Icons.tune_rounded, label: 'you'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4EBDD).withValues(alpha: 0.97),
        border: const Border(top: BorderSide(color: Color(0xFFD5C6B5))),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final selected = item.tab == current;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(item.tab),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    item.icon,
                    size: 21,
                    color: selected ? seaDeep : inkMuted,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label,
                    style: monoStyle(
                      size: 8,
                      color: selected ? seaDeep : inkMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 20 : 4,
                    height: 2,
                    color: selected ? coral : Colors.transparent,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.action,
    this.onAction,
  });

  final String title;
  final String message;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: sea.withValues(alpha: 0.18),
        border: Border.all(color: seaDeep.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: <Widget>[
          Text('✳', style: displayStyle(size: 30, color: coral)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: displayStyle(size: 23),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (action != null) ...<Widget>[
            const SizedBox(height: 16),
            QuietButton(label: action!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

class StatBox extends StatelessWidget {
  const StatBox({
    super.key,
    required this.value,
    required this.label,
    this.color = sea,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.42),
          border: Border.all(color: ink.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: <Widget>[
            Text(value, style: displayStyle(size: 24)),
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: monoStyle(size: 8, color: inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title, style: displayStyle(size: 18)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeThumbColor: seaDeep,
            ),
          ],
        ),
      ),
    );
  }
}

Color colorFromInt(int value) => Color(value);
