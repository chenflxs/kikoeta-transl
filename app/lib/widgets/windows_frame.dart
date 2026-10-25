import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';

/// Uses the same window_manager caption and opaque divider as Kikoeta.
class KtWindowsFrame extends StatelessWidget {
  final Widget child;

  const KtWindowsFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final captionColor = Color.lerp(
      theme.scaffoldBackgroundColor,
      theme.colorScheme.surface,
      .5,
    )!;
    final dividerColor = Color.alphaBlend(
      theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: .08)
          : Colors.black.withValues(alpha: .08),
      theme.scaffoldBackgroundColor,
    );
    return VirtualWindowFrame(
      child: Column(
        children: [
          SizedBox(
            height: kWindowCaptionHeight,
            child: WindowCaption(
              brightness: theme.brightness,
              backgroundColor: captionColor,
              title: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Kikoeta Transl',
                    style: TextStyle(
                      fontFamily: kAppFontFamily,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            key: const ValueKey('titlebar-divider'),
            width: double.infinity,
            height: 1,
            child: ColoredBox(color: dividerColor),
          ),
          Expanded(child: ClipRect(child: child)),
        ],
      ),
    );
  }
}
