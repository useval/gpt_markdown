/// The arithmetic behind the streaming reveal.
///
/// Deliberately free of Flutter: it owns counters, the widget owns the
/// [Ticker] and calls `setState`. That split keeps the pacing rules — which
/// are the fiddly part — testable without pumping a widget.
///
/// Three behaviours a naive typewriter gets wrong, and this does not:
///
/// * **Lag adaptation.** A model can emit faster than the reveal speed. Left
///   alone the animation falls further behind for the whole reply. Whenever
///   the backlog would take longer than [maxLagSeconds] to clear, the reveal
///   speeds up to clear it in that window instead.
/// * **Fast-forward.** When the stream ends there is nothing left to wait
///   for, so the remainder lands within [fastForwardSeconds] rather than
///   trickling at the baseline rate.
/// * **Replacement.** A regenerate or branch switch replaces the text rather
///   than extending it, and must restart rather than continue from a
///   meaningless offset.
/// * **Per-character timing.** A reveal that only tracks "how many characters
///   are visible" can do nothing softer than a hard cut. Each newly revealed
///   character is stamped with the time it arrived, so the renderer can ask
///   how far along that one character's entrance is and style it accordingly.
library;

import 'dart:math' as math;
import 'dart:typed_data';

/// Counters for a character-by-character reveal.
class RevealEngine {
  /// Creates an engine whose characters take [fadeSeconds] to finish their
  /// entrance.
  RevealEngine({this.fadeSeconds = 0.25})
    : assert(fadeSeconds >= 0, 'fadeSeconds must not be negative');

  /// Longest the reveal may lag behind the text it has been given.
  static const double maxLagSeconds = 0.4;

  /// Window the remainder is revealed over once streaming has finished.
  static const double fastForwardSeconds = 0.15;

  /// The smallest number of characters that can be mid-entrance at once —
  /// what every engine starts with.
  ///
  /// A character further behind the head than [window] is treated as
  /// finished, so its timestamp is no longer worth keeping: stamps live in a
  /// ring of [window] slots rather than a list that grows with the reply.
  /// Memory stays bounded, and a fast-forward that reveals thousands of
  /// characters in one frame stamps only the last [window] of them.
  ///
  /// A power of two, so the ring index is a mask rather than a modulo.
  static const int fadeWindow = 64;

  /// The largest [window] grows to.
  ///
  /// Bounds the per-frame cost: at most this many characters are restyled in
  /// a frame, and the ring is at most 2 KB.
  static const int maxFadeWindow = 256;

  /// How many characters can be mid-entrance at once, between [fadeWindow]
  /// and [maxFadeWindow].
  ///
  /// Grows when the head moves fast enough that more characters than this
  /// are still inside their [fadeSeconds]: `charactersPerSecond ×
  /// fadeSeconds` above 64 — which the defaults (300 × 0.25 = 75) already
  /// are. A fixed 64 snapped the oldest of them to their final style before
  /// their entrance ended, cutting every effect short at speed. Never
  /// shrinks, so a character mid-entrance is never dropped from the ring.
  int get window => _window;
  int _window = fadeWindow;
  int _mask = fadeWindow - 1;

  /// How long one character takes to finish its entrance.
  final double fadeSeconds;

  double _revealed = 0;
  bool _fastForwarding = false;

  /// Monotonic seconds, accumulated across ticker runs.
  double _clock = 0;

  /// Arrival time of character `i`, at ring slot `i & _mask`.
  Float64List _stamps = Float64List(fadeWindow);

  /// Characters that arrived with no entrance to play — everything below this
  /// index is fully revealed regardless of what the ring holds.
  int _settledBelow = 0;

  /// The target of the last [tick] — how many characters the document
  /// actually holds. The head can sit above it after a shrink, so "is the
  /// tail still fading" is asked of the newest character that *exists*, not
  /// of the head.
  int _lastTarget = 0;

  /// Characters revealed so far, fractional between characters.
  double get revealed => _revealed;

  /// Characters to show this frame.
  int get revealedFloor => _revealed.floor();

  /// Whether the newest character is still playing its entrance.
  ///
  /// The reveal is not finished when the last character *appears*, only when
  /// it has finished arriving — stopping the ticker at the former freezes the
  /// final characters part-way through.
  bool get tailStillFading {
    final last = math.min(_revealed.floor(), _lastTarget) - 1;
    if (last < _settledBelow || last < 0) {
      return false;
    }
    return _clock - _stamps[last & _mask] < fadeSeconds;
  }

  /// The first character still playing its entrance; every character below
  /// it is finished.
  ///
  /// Exact, from the stamps, rather than [window] behind the head: a short
  /// entrance at speed has far fewer characters in flight than the window
  /// holds, and everything behind them can render as settled. Stamps rise
  /// with the index, so this is a binary search.
  int get fadingFrom {
    final head = _revealed.floor();
    if (fadeSeconds <= 0) return head;
    var low = math.max(_settledBelow, head - _window);
    if (low < 0) low = 0;
    var high = head;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (_clock - _stamps[mid & _mask] >= fadeSeconds) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// How far through its entrance the character at [index] is, 0 to 1.
  double progressFor(int index) {
    if (index < _settledBelow) {
      return 1;
    }
    if (index >= _revealed.floor()) {
      return 0;
    }
    if (fadeSeconds <= 0) {
      return 1;
    }
    // Older than the ring can hold, so certainly finished.
    if (index < _revealed.floor() - _window) {
      return 1;
    }
    final elapsed = _clock - _stamps[index & _mask];
    return (elapsed / fadeSeconds).clamp(0.0, 1.0);
  }

  /// Restarts from nothing — the text was replaced, not extended.
  void reset() {
    _revealed = 0;
    _settledBelow = 0;
    _lastTarget = 0;
    _fastForwarding = false;
  }

  /// Marks [length] characters revealed with no animation.
  void snapToEnd(int length) {
    _revealed = length.toDouble();
    _settledBelow = length;
    _lastTarget = length;
    _fastForwarding = false;
  }

  /// Clamps the reveal when the source shrank to a prefix of itself.
  ///
  /// The surviving prefix keeps its stamps, so text that merely restyled —
  /// a construct claiming characters the tail had already shown — carries on
  /// its entrance instead of starting over.
  void truncateTo(int length) {
    if (_revealed > length) {
      _revealed = length.toDouble();
    }
    if (_settledBelow > length) {
      _settledBelow = length;
    }
  }

  /// Enters the end-of-stream catch-up.
  void beginFastForward() => _fastForwarding = true;

  /// Leaves the catch-up because more text arrived after all.
  void clearFastForward() => _fastForwarding = false;

  /// Whether the reveal has caught up with [target].
  bool caughtUp(int target) => _revealed >= target;

  /// Advances by [dt] seconds toward [target] characters at
  /// [charactersPerSecond], adapting upward when behind.
  ///
  /// Returns false once the reveal has caught up — the caller's cue to stop
  /// its ticker and stop rebuilding.
  bool tick(double dt, int target, double charactersPerSecond) {
    _clock += dt;

    _lastTarget = target;
    // The document can shrink under a live reveal — a construct completing
    // renders fewer characters than its literal text, or a rewrite shortens
    // the source. What was on screen has been seen: the head holds its
    // ground, and only the *vanished* range [target, head) is marked settled
    // — characters below the target still exist, are still mid-fade, and
    // keep fading. Vanished indices keep their own old stamps (nothing
    // restamps below the head), so if the text grows back over them they
    // read as finished rather than replaying, and the `floor - window`
    // early-out in [progressFor] covers any slot a newer character
    // overwrites. A deliberate shrink goes through [reset] or [truncateTo]
    // instead.
    if (target < _revealed) {
      _settledBelow = math.max(_settledBelow, target);
    }

    var speed = charactersPerSecond;
    final backlog = target - _revealed;
    if (backlog > 0) {
      final window = _fastForwarding ? fastForwardSeconds : maxLagSeconds;
      speed = math.max(speed, backlog / window);
    }

    // Not while fast-forwarding: that lands the remainder at once, and
    // widening for it would restyle hundreds of characters for a moment no
    // reader is meant to watch.
    if (!_fastForwarding) _fit(speed * fadeSeconds);

    final before = _revealed.floor();
    _revealed = math.min(
      _revealed + speed * dt,
      math.max(target.toDouble(), _revealed),
    );
    final after = _revealed.floor();

    if (after > before) {
      final count = after - before;
      // Only the newest `window` characters can still be mid-entrance;
      // stamping the ones behind them would be overwritten immediately. This
      // is what keeps a fast-forward of a long reply O(window).
      final from = math.max(before, after - _window);
      for (var index = from; index < after; index++) {
        // Spread arrivals across the frame rather than stacking them on its
        // end, so a burst reveals as a ramp instead of a block.
        _stamps[index & _mask] =
            _clock - dt + dt * (index - before + 1) / count;
      }
    }

    if (_revealed >= target) {
      _fastForwarding = false;
      // The last character has appeared but may still be arriving.
      return tailStillFading;
    }
    return true;
  }

  /// Widens [window] to hold [inFlight] characters, up to [maxFadeWindow].
  ///
  /// The stamps of the characters already in the ring move with them, so a
  /// character mid-entrance carries on from where it was.
  void _fit(double inFlight) {
    if (inFlight <= _window || _window >= maxFadeWindow) return;
    var size = _window;
    while (size < inFlight && size < maxFadeWindow) {
      size <<= 1;
    }
    final stamps = Float64List(size);
    final mask = size - 1;
    final head = _revealed.floor();
    for (var index = math.max(0, head - _window); index < head; index++) {
      stamps[index & mask] = _stamps[index & _mask];
    }
    _stamps = stamps;
    _window = size;
    _mask = mask;
  }
}
