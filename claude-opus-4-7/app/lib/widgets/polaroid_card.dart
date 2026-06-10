import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';

/// Polaroid-ish card: white border, slight rotation, soft shadow, optional
/// strip of "tape" at the top corner.
class PolaroidCard extends StatelessWidget {
  final Widget image;
  final String? title;
  final String? subtitle;
  final String? handwrittenNote;
  final double rotation;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  final bool tape;
  final double width;

  const PolaroidCard({
    super.key,
    required this.image,
    this.title,
    this.subtitle,
    this.handwrittenNote,
    this.rotation = 0,
    this.onTap,
    this.margin = const EdgeInsets.all(10),
    this.tape = true,
    this.width = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Transform.rotate(
        angle: rotation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(2),
            child: SizedBox(
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAF4E4),
                      boxShadow: [
                        BoxShadow(
                          color: MorphColors.ink.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(2, 6),
                        )
                      ],
                      border: Border.all(
                        color: MorphColors.paperShadow.withValues(alpha: 0.6),
                        width: 0.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 130,
                          width: double.infinity,
                          child: image,
                        ),
                        const SizedBox(height: 10),
                        if (title != null)
                          Text(
                            title!.toLowerCase(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: MorphType.headline(size: 17),
                          ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!.toUpperCase(),
                            style: MorphType.smallCaps(size: 9),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (tape)
                    Positioned(
                      top: -8,
                      left: width * 0.25,
                      child: Transform.rotate(
                        angle: -0.08,
                        child: Container(
                          width: width * 0.35,
                          height: 16,
                          color: MorphColors.tape,
                        ),
                      ),
                    ),
                  if (handwrittenNote != null)
                    Positioned(
                      bottom: -8,
                      right: 6,
                      child: Transform.rotate(
                        angle: -0.04,
                        child: Text(
                          handwrittenNote!,
                          style: MorphType.hand(
                              size: 20, color: MorphColors.coral),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
