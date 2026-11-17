import 'package:flutter/material.dart';

import 'package:habitoliving_shared/ui/tokens.dart';

/// Shown while the stored session is being validated.
///
/// It is deliberately plain: a wordmark and a progress indicator on the brand
/// ground, so a slow start reads as "loading the app" rather than a broken
/// screen.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Tokens.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Wordmark(),
            SizedBox(height: Tokens.space6),
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Tokens.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Tokens.accent,
            borderRadius: BorderRadius.circular(Tokens.radiusMd),
          ),
          alignment: Alignment.center,
          child: Text(
            'H',
            style: TextStyle(
              fontFamily: Tokens.fontFamilyFigure,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Tokens.accentOn,
            ),
          ),
        ),
        SizedBox(height: Tokens.space4),
        Text(
          'Habito Living',
          style: TextStyle(
            fontFamily: Tokens.fontFamilyFigure,
            fontSize: Tokens.typeLg,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: Tokens.ink,
          ),
        ),
      ],
    );
  }
}
