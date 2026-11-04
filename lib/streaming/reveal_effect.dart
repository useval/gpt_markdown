/// How streamed content arrives: the character reveal at the head, and the
/// entrance a finished block plays.
///
/// Two axes, deliberately. A reveal head and a block entrance answer different
/// questions — "how does this letter appear" and "how does this table appear"
/// — and pinning them to a single preset forces a new preset for every
/// combination. Kept apart they compose: blurred text arriving inside a table
/// that grows into place is two independent choices, not a third enum value.
library;

import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

/// How newly arrived text appears.
///
/// Every effect here is expressible as a [TextStyle], which is what keeps the
/// reveal cheap: characters mid-entrance become their own [TextSpan]s inside
/// one paragraph, and no effect needs a second render object, a per-glyph
/// layout pass, or a shader compile.
enum GptMarkdownAnimation {
  /// No reveal. The document is built whole, with no ticker and no wrapper —
  /// exactly the tree the widget built before the feature existed.
  none,

  /// Characters appear at full strength the instant they are revealed.
  ///
  /// The reveal still paces itself — this is a typewriter, not a dump — but
  /// no individual character animates.
  typewriter,

  /// Characters ramp from transparent to full opacity.
  fade,

  /// Characters resolve out of a blur while fading in, so the head reads as
  /// text coming into focus rather than text switching on.
  blurIn,

  /// Characters land in an accent colour and settle into the text colour, so
  /// a coloured crest travels along the newest text.
  ///
  /// The accent is the theme's `ColorScheme.primary`.
  wave;

  /// Whether the reveal paces itself at all, rather than showing everything.
  bool get reveals => this != GptMarkdownAnimation.none;

  /// Whether an in-flight character is drawn differently from a settled one.
  ///
  /// False for [none] and [typewriter], whose characters are final the moment
  /// they show — the renderer then skips splitting the head into
  /// per-character spans entirely.
  bool get animatesCharacters =>
      this != GptMarkdownAnimation.none &&
      this != GptMarkdownAnimation.typewriter;

  /// Whether each character needs its own style, rather than its word.
  ///
  /// Only [wave] draws neighbouring characters differently — the crest
  /// travels letter by letter. The fading effects style whole words: a word
  /// arrives as one span, so no style boundary ever lands inside a shaped
  /// run, and kerning, ligatures and line wrapping sit exactly where the
  /// settled text will put them. A boundary inside a word is not free — each
  /// side shapes as its own run, the advances change on a proportional font,
  /// and a nearly-full line flips its wrap point back and forth as the
  /// boundary moves.
  bool get animatesPerCharacter => this == GptMarkdownAnimation.wave;
}

/// How a block plays its entrance once it is complete enough to render.
///
/// Prose reveals a character at a time, but a fence, a table or a rule has no
/// meaningful half-state — the delimiter row lands and a full-height table
/// exists. Without an entrance that is a single-frame jump, and everything
/// below it moves. These give the layout somewhere to grow from.
enum GptMarkdownBlockAnimation {
  /// Blocks appear at full size immediately.
  none,

  /// Opacity only. The block occupies its full height from the first frame,
  /// so nothing below it moves.
  fadeIn,

  /// Height and opacity together, so the block grows into place and the
  /// document expands as smoothly as the text does.
  growIn,

  /// Rises a short distance while fading in, at full height throughout.
  slideUp,

  /// Scales up from slightly small while fading in, at full height
  /// throughout.
  scaleIn;

  /// Whether this entrance changes the space the block takes while it plays.
  ///
  /// True only for [growIn]. The others animate paint alone, so content below
  /// them holds still — worth knowing when the reveal is inside a scroll view
  /// pinned to the bottom.
  bool get affectsLayout => this == GptMarkdownBlockAnimation.growIn;
}

/// The style an in-flight character is drawn with.
///
/// [progress] is 0 the moment the character is revealed and 1 when its
/// entrance is over. [color] is the colour it will settle into.
///
/// The result is a *delta*, applied over whatever the span already carries, so
/// an effect only names what it changes and inherits the rest. That is also
/// what makes [GptMarkdownAnimation.blurIn] safe: `foreground` and `color`
/// cannot both be set on one style, and `TextStyle.merge` drops the inherited
/// colour when the delta brings a paint.
///
/// Returns null when the character should be drawn exactly as it will settle,
/// which the renderer takes as licence to skip styling it at all.
///
/// [accent] is the colour [GptMarkdownAnimation.wave]'s crest lands in; the
/// widget passes the theme's `ColorScheme.primary`. Without one the crest is
/// derived from [color], which on the near-grey text colours of most themes
/// is a grey — close to indistinguishable from [GptMarkdownAnimation.fade].
///
/// [fontSize] is the text's laid-out size, which
/// [GptMarkdownAnimation.blurIn] scales its blur by, so the effect reads the
/// same at any size. Without one the blur is a fixed 3 logical pixels.
TextStyle? revealStyleFor(
  GptMarkdownAnimation effect,
  double progress,
  Color color, {
  Color? accent,
  double? fontSize,
}) {
  if (progress >= 1) {
    return null;
  }
  final t = progress.clamp(0.0, 1.0);
  switch (effect) {
    case GptMarkdownAnimation.none:
    case GptMarkdownAnimation.typewriter:
      return null;

    case GptMarkdownAnimation.fade:
      return TextStyle(color: color.withValues(alpha: color.a * t));

    case GptMarkdownAnimation.blurIn:
      // Opacity runs ahead of the blur. The other way round — blur strongest
      // while the character is still nearly transparent — the blur was over
      // before anyone could see it, and the effect read as a plain fade: by
      // half opacity it was under a pixel. Here a word is two-thirds opaque
      // while still clearly soft, then sharpens through the rest of its
      // entrance, finishing as its opacity long since has.
      final opacity = Curves.easeOut.transform((t * 1.6).clamp(0.0, 1.0));
      final soft = 1 - t;
      final peak = fontSize == null
          ? _blurSigma
          : (fontSize * _blurPerEm).clamp(_minPeakSigma, _maxPeakSigma);
      final sigma = peak * soft * soft;
      final paint = Paint()..color = color.withValues(alpha: color.a * opacity);
      if (sigma > _minSigma) {
        paint.maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, sigma);
      }
      // `foreground` and `color` are mutually exclusive in a TextStyle, and
      // the base may carry a colour, so it is cleared here.
      return TextStyle(color: null, foreground: paint);

    case GptMarkdownAnimation.wave:
      // Full opacity almost immediately — the motion readers see is the
      // colour crest travelling, not letters materialising.
      if (accent != null) {
        final opacity = (t * 4).clamp(0.0, 1.0);
        // Eased in, so a letter holds the accent for a moment before it
        // settles: the crest is a band a few words long, not a flicker.
        final crest =
            Color.lerp(accent, color, Curves.easeIn.transform(t)) ?? color;
        return TextStyle(color: crest.withValues(alpha: color.a * opacity));
      }
      final opacity = (t * 3).clamp(0.0, 1.0);
      final crest = Color.lerp(_waveCrest(color), color, t) ?? color;
      return TextStyle(color: crest.withValues(alpha: color.a * opacity));
  }
}

/// Peak blur radius, in logical pixels, at the instant a character appears,
/// when no font size is known.
const double _blurSigma = 3;

/// Peak blur radius per logical pixel of font size: 4 px on 20 px text.
const double _blurPerEm = 0.2;

/// Bounds on the font-scaled peak, so tiny text still blurs visibly and huge
/// text does not smear across its neighbours.
const double _minPeakSigma = 1.5;
const double _maxPeakSigma = 8;

/// Below this the blur costs a mask filter and shows nothing.
const double _minSigma = 0.05;

/// The colour a character lands in before settling into the text colour, when
/// no accent is given.
///
/// Derived from the text colour: its lightness moves 0.35 toward the middle —
/// light text dims, dark text lifts. On a near-grey text colour that is a
/// grey, so the widget passes the theme's accent instead.
Color _waveCrest(Color color) {
  final hsl = HSLColor.fromColor(color);
  final lightness = hsl.lightness > 0.5
      ? (hsl.lightness - 0.35).clamp(0.0, 1.0)
      : (hsl.lightness + 0.35).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}
