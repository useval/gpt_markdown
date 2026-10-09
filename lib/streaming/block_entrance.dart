/// The one-shot entrance a block plays the first time it is built.
///
/// Prose can arrive a character at a time, but a table, a fence or a rule has
/// no half-state to reveal: the delimiter row lands and a full-height widget
/// exists in the next frame. Without an entrance that is a step change in
/// layout, and every block below it moves at once.
library;

import 'package:material_ui/material_ui.dart';

import 'reveal_effect.dart';

/// Plays [animation] once, the first time this widget is built, then never
/// again.
///
/// Deliberately one-shot and decided on first build: a streaming document
/// rebuilds its tail constantly, and an entrance that re-armed on prop changes
/// would restart every frame. A block that has already arrived stays arrived.
///
/// Honours the platform's reduced-motion setting, and renders statically when
/// [animation] is [GptMarkdownBlockAnimation.none] — in that case no
/// controller is created and no wrapper is added to the tree.
class GptMarkdownBlockEntrance extends StatefulWidget {
  /// Creates a one-shot block entrance.
  const GptMarkdownBlockEntrance({
    super.key,
    required this.animation,
    required this.duration,
    required this.curve,
    required this.child,
  });

  /// Which entrance to play.
  final GptMarkdownBlockAnimation animation;

  /// How long the entrance takes.
  final Duration duration;

  /// The entrance's easing.
  final Curve curve;

  /// The block itself.
  final Widget child;

  @override
  State<GptMarkdownBlockEntrance> createState() =>
      _GptMarkdownBlockEntranceState();
}

class _GptMarkdownBlockEntranceState extends State<GptMarkdownBlockEntrance>
    with SingleTickerProviderStateMixin {
  /// How far [GptMarkdownBlockAnimation.slideUp] travels, in logical pixels.
  static const double _slideDistance = 8;

  /// Where [GptMarkdownBlockAnimation.scaleIn] starts.
  static const double _scaleFrom = 0.96;

  AnimationController? _controller;
  late final CurvedAnimation _eased;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) {
      return;
    }
    _decided = true;
    if (widget.animation == GptMarkdownBlockAnimation.none ||
        MediaQuery.disableAnimationsOf(context)) {
      return;
    }
    final controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );
    _controller = controller;
    _eased = CurvedAnimation(parent: controller, curve: widget.curve);
    controller.forward();
  }

  @override
  void dispose() {
    if (_controller != null) {
      _eased.dispose();
      _controller!.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    // Not animating at all: the child passes through untouched. Once an
    // entrance *has* played, though, the wrapper stays — swapping to the bare
    // child would change the widget type at this slot and re-inflate the
    // whole block subtree, losing any state inside a table or fence for the
    // sake of removing a finished, paint-free passthrough.
    if (controller == null) {
      return widget.child;
    }
    final faded = FadeTransition(opacity: _eased, child: widget.child);
    switch (widget.animation) {
      case GptMarkdownBlockAnimation.none:
        return widget.child;

      case GptMarkdownBlockAnimation.fadeIn:
        return faded;

      case GptMarkdownBlockAnimation.growIn:
        // Hand-rolled rather than SizeTransition: its Align has no
        // widthFactor, which under bounded constraints is "expand", and since
        // this wrapper now stays after the entrance it would force the whole
        // document to the offered width forever. widthFactor 1.0 keeps the
        // block shrink-wrapped while the height grows in.
        return ClipRect(
          child: AnimatedBuilder(
            animation: _eased,
            builder: (context, child) => Align(
              alignment: AlignmentDirectional.topStart,
              widthFactor: 1.0,
              heightFactor: _eased.value.clamp(0.0, 1.0),
              child: child,
            ),
            child: faded,
          ),
        );

      case GptMarkdownBlockAnimation.slideUp:
        return AnimatedBuilder(
          animation: _eased,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _slideDistance * (1 - _eased.value)),
            child: child,
          ),
          child: faded,
        );

      case GptMarkdownBlockAnimation.scaleIn:
        return AnimatedBuilder(
          animation: _eased,
          builder: (context, child) => Transform.scale(
            scale: _scaleFrom + (1 - _scaleFrom) * _eased.value,
            alignment: AlignmentDirectional.topStart,
            child: child,
          ),
          child: faded,
        );
    }
  }
}
