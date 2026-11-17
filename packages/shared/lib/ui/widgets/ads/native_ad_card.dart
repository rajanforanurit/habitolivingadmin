import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../services/ads/ad_config.dart';
import '../../../services/ads/ad_service.dart';
import '../../tokens.dart';

/// What kind of creative a slot is for.
enum AdSlotKind {
  /// A compact native ad that sits inline, like a row.
  inline,

  /// The larger video-capable card used for the "Sponsored video" section.
  video,
}

/// A native ad styled to match the app.
///
/// Uses the SDK's native *templates*, restyled with the app tokens, so no
/// platform-specific layout code is needed. The card always carries the SDK's
/// "Ad" badge, which AdMob policy requires on native ads, and wraps the ad in a
/// labelled container so it is never mistaken for a post.
///
/// Failure is silent and takes no space: no fill, no network or an unsupported
/// platform all collapse to nothing, so the feed never shows a hole.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key, this.kind = AdSlotKind.inline});

  final AdSlotKind kind;

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _requested = false;

  bool get _isVideo => widget.kind == AdSlotKind.video;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Styling reads Tokens, so wait for the first dependency pass.
    if (!_requested) {
      _requested = true;
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (!AdConfig.supported) return;
    final unitId = _isVideo ? AdConfig.videoUnitId : AdConfig.nativeUnitId;
    if (!AdConfig.isConfigured(unitId)) return;
    if (!await AdService.instance.ensureInitialised()) return;
    if (!mounted) return;

    final ad = NativeAd(
      adUnitId: unitId,
      request: AdService.instance.request(),
      nativeAdOptions: NativeAdOptions(
        videoOptions: VideoOptions(startMuted: true, clickToExpandRequested: true),
      ),
      nativeTemplateStyle: _style(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native ad failed: ${error.code} ${error.message}');
          ad.dispose();
          if (mounted) setState(() => _ad = null);
        },
      ),
    );
    _ad = ad;
    await ad.load();
  }

  NativeTemplateStyle _style() {
    return NativeTemplateStyle(
      templateType: _isVideo ? TemplateType.medium : TemplateType.small,
      mainBackgroundColor: Tokens.surface,
      cornerRadius: Tokens.radiusMd,
      callToActionTextStyle: NativeTemplateTextStyle(
        textColor: Tokens.accentOn,
        backgroundColor: Tokens.accent,
        style: NativeTemplateFontStyle.bold,
        size: 14,
      ),
      primaryTextStyle: NativeTemplateTextStyle(
        textColor: Tokens.ink,
        style: NativeTemplateFontStyle.bold,
        size: 15,
      ),
      secondaryTextStyle: NativeTemplateTextStyle(
        textColor: Tokens.inkMuted,
        style: NativeTemplateFontStyle.normal,
        size: 13,
      ),
      tertiaryTextStyle: NativeTemplateTextStyle(
        textColor: Tokens.inkFaint,
        style: NativeTemplateFontStyle.normal,
        size: 12,
      ),
    );
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();

    final constraints = _isVideo
        ? const BoxConstraints(
            minWidth: 320,
            minHeight: 320,
            maxHeight: 400,
          )
        : const BoxConstraints(
            minWidth: 320,
            minHeight: 90,
            maxHeight: 130,
          );

    final card = Container(
      decoration: BoxDecoration(
        color: Tokens.surface,
        borderRadius: BorderRadius.circular(Tokens.radiusMd),
        border: Border.all(color: Tokens.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: constraints,
        child: AdWidget(ad: ad),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Tokens.space2),
      child: _isVideo
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: Tokens.space1,
                    bottom: Tokens.space2,
                  ),
                  child: Text(
                    'Sponsored video',
                    style: TextStyle(
                      fontFamily: Tokens.fontFamily,
                      fontSize: Tokens.typeXs,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                      color: Tokens.inkFaint,
                    ),
                  ),
                ),
                card,
              ],
            )
          : card,
    );
  }
}
