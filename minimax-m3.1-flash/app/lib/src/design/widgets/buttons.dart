import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../palette.dart';
import '../typography.dart';

/// Primary action: a stamped-ink button.
class PaperButton extends StatelessWidget {
  const PaperButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.accent = MC.coral,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color accent;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
      decoration: BoxDecoration(
        color: enabled ? accent : MC.inkGhost.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(3),
        boxShadow: enabled
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (busy)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation<Color>(MC.card),
                ),
              ),
            )
          else if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(icon, size: 16, color: MC.card),
            ),
          Text(
            label.toUpperCase(),
            style: Type.label(
              size: 11,
              weight: FontWeight.w700,
              color: MC.card,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(3),
          child: child,
        ),
      ),
    );
  }
}

/// Secondary action: an outlined button on paper.
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.accent = MC.ink,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color accent;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                }
              : null,
          borderRadius: BorderRadius.circular(3),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: enabled ? accent.withValues(alpha: 0.55) : MC.inkGhost,
              ),
            ),
            child: Row(
              mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (icon != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      icon,
                      size: 15,
                      color: enabled ? accent : MC.inkGhost,
                    ),
                  ),
                Text(
                  label.toUpperCase(),
                  style: Type.label(
                    size: 10.5,
                    weight: FontWeight.w700,
                    color: enabled ? accent : MC.inkGhost,
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

/// A text-only action.
class TextAction extends StatelessWidget {
  const TextAction({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.color = MC.inkSoft,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(2),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Icon(icon, size: 14, color: color),
                ),
              Text(
                label.toUpperCase(),
                style: Type.label(size: 10, weight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
