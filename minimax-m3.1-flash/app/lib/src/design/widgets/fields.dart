import 'package:flutter/material.dart';

import '../palette.dart';
import '../typography.dart';

/// A ruled text field that looks like a blank line in a notebook.
class PaperField extends StatelessWidget {
  const PaperField({
    required this.controller,
    super.key,
    this.hint,
    this.label,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
    this.suffix,
    this.prefix,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLength;
  final Widget? suffix;
  final Widget? prefix;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (label != null) ...<Widget>[
          Text(label!.toUpperCase(), style: Type.label(size: 9.5)),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          maxLines: maxLines,
          minLines: minLines,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          onSubmitted: onSubmitted,
          autofocus: autofocus,
          maxLength: maxLength,
          onChanged: onChanged,
          textCapitalization: textCapitalization,
          style: Type.body(size: 16, color: MC.ink),
          cursorColor: MC.coral,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: Type.body(size: 16, color: MC.inkGhost),
            prefixIcon: prefix,
            suffixIcon: suffix,
            filled: true,
            fillColor: MC.card,
            counterStyle: Type.label(size: 9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: MC.ruleFaint),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: MC.coral, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

/// A label + description row with a switch, used all over Settings.
class ToggleRow extends StatelessWidget {
  const ToggleRow({
    required this.title,
    required this.value,
    required this.onChanged,
    super.key,
    this.description,
    this.accent = MC.teal,
    this.enabled = true,
  });

  final String title;
  final String? description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => onChanged?.call(!value) : null,
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: Type.bodyStrong(
                      size: 15,
                      color: enabled ? MC.ink : MC.inkGhost,
                    ),
                  ),
                  if (description != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      description!,
                      style: Type.small(size: 13, color: MC.inkFaint),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 14),
            IgnorePointer(
              ignoring: !enabled,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: MC.card,
                activeTrackColor: accent,
                inactiveThumbColor: MC.card,
                inactiveTrackColor: MC.rule,
                trackOutlineColor: WidgetStatePropertyAll<Color>(
                  enabled ? accent.withValues(alpha: 0.5) : MC.rule,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of mutually exclusive choices, rendered as paper chips.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
    this.accent = MC.coral,
  });

  final List<({T value, String label})> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final option in options)
          GestureDetector(
            onTap: () => onChanged(option.value),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: option.value == value ? accent : MC.card,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: option.value == value ? accent : MC.ruleFaint,
                ),
              ),
              child: Text(
                option.label,
                style: Type.label(
                  size: 10.5,
                  weight: option.value == value ? FontWeight.w700 : FontWeight.w500,
                  color: option.value == value ? MC.card : MC.inkSoft,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
