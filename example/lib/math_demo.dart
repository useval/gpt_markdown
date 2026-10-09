import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';

/// A tour of the maths gpt_markdown renders, from inline symbols to
/// multi-line derivations, chemistry and units.
///
/// Run it directly with:
/// ```
/// flutter run -t lib/math_demo.dart
/// ```
void main() => runApp(const MathApp());

/// The demo app shell.
class MathApp extends StatelessWidget {
  /// Creates the demo app.
  const MathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — maths',
      pageBuilder: (toggleTheme) => MathPage(onToggleTheme: toggleTheme),
    );
  }
}

/// One section of the tour: a title, a line on what it shows, and the
/// Markdown that shows it.
class MathSample {
  /// Creates a section.
  const MathSample(this.title, this.description, this.markdown);

  /// Section heading.
  final String title;

  /// What the section demonstrates.
  final String description;

  /// The Markdown, exactly as a model would send it.
  final String markdown;
}

/// Every section of the tour, in order.
const mathSamples = <MathSample>[
  MathSample(
    'Inline, on the baseline',
    'Formulas sit on the text baseline and keep the line readable.',
    r'''The golden ratio \( \varphi = \frac{1 + \sqrt{5}}{2} \approx 1.618 \)
satisfies \( \varphi^2 = \varphi + 1 \). Summing the first \( n \) integers
gives \( \sum_{i=1}^{n} i = \frac{n(n+1)}{2} \), and Euler tied five constants
together in \( e^{i\pi} + 1 = 0 \). Distances use
\( \lVert \mathbf{v} \rVert = \sqrt{v_1^2 + v_2^2 + v_3^2} \).''',
  ),
  MathSample(
    'The classics',
    'Display formulas: big operators, limits above and below.',
    r'''\[
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
\]

\[
\int_{-\infty}^{\infty} e^{-x^2}\,dx = \sqrt{\pi}
\]

\[
\sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}
\]

\[
\zeta(s) = \prod_{p\ \text{prime}} \frac{1}{1 - p^{-s}}
\]''',
  ),
  MathSample(
    'Calculus',
    'Limits, derivatives, integrals and series.',
    r'''\[
f'(x) = \lim_{h \to 0} \frac{f(x + h) - f(x)}{h}
\]

\[
\int_a^b f'(x)\,dx = f(b) - f(a)
\]

\[
\frac{\partial^2 u}{\partial t^2} = c^2 \left(
\frac{\partial^2 u}{\partial x^2} + \frac{\partial^2 u}{\partial y^2}
\right)
\]

\[
\oint_{\partial S} \mathbf{F} \cdot d\mathbf{r}
= \iint_S (\nabla \times \mathbf{F}) \cdot d\mathbf{S}
\]

\[
f(x) = \sum_{n=0}^{\infty} \frac{f^{(n)}(a)}{n!}\,(x - a)^n
\]''',
  ),
  MathSample(
    'Linear algebra',
    'Matrices with every bracket style, determinants and systems.',
    r'''\[
\begin{pmatrix} a & b \\ c & d \end{pmatrix}
\begin{pmatrix} x \\ y \end{pmatrix}
= \begin{pmatrix} ax + by \\ cx + dy \end{pmatrix}
\]

\[
\det \begin{vmatrix} a & b \\ c & d \end{vmatrix} = ad - bc
\]

\[
A = \begin{bmatrix}
1 & 0 & \cdots & 0 \\
0 & 1 & \cdots & 0 \\
\vdots & \vdots & \ddots & \vdots \\
0 & 0 & \cdots & 1
\end{bmatrix}
\]

\[
A\mathbf{v} = \lambda \mathbf{v}
\iff (A - \lambda I)\,\mathbf{v} = \mathbf{0}
\]''',
  ),
  MathSample(
    'Multi-line and numbered',
    'Aligned derivations, equation numbers and piecewise definitions.',
    r'''\[
\begin{align}
(a + b)^2 &= (a + b)(a + b) \\
&= a^2 + ab + ba + b^2 \\
&= a^2 + 2ab + b^2 \tag{binomial}
\end{align}
\]

\[
|x| = \begin{cases}
x & \text{if } x \ge 0, \\
-x & \text{if } x < 0.
\end{cases}
\]

\[
F_n = \begin{cases}
0 & n = 0 \\
1 & n = 1 \\
F_{n-1} + F_{n-2} & n > 1
\end{cases}
\]''',
  ),
  MathSample(
    'Physics',
    'Vector calculus, quantum mechanics and the physics shorthands.',
    r'''\[
\begin{aligned}
\nabla \cdot \mathbf{E} &= \frac{\rho}{\varepsilon_0} &
\nabla \times \mathbf{E} &= -\frac{\partial \mathbf{B}}{\partial t} \\
\nabla \cdot \mathbf{B} &= 0 &
\nabla \times \mathbf{B} &= \mu_0 \mathbf{J}
  + \mu_0 \varepsilon_0 \frac{\partial \mathbf{E}}{\partial t}
\end{aligned}
\]

\[
i\hbar \frac{\partial}{\partial t} \Psi(\mathbf{r}, t)
= \left[ -\frac{\hbar^2}{2m} \nabla^2 + V(\mathbf{r}, t) \right] \Psi(\mathbf{r}, t)
\]

Shorthands: \( \abs{\psi}^2 \), \( \dv{x}{t} \), \( \pdv{f}{x} \) and
\( \expval{\hat{H}} \).''',
  ),
  MathSample(
    'Chemistry and units',
    r'Reactions with \ce and quantities with \SI, out of the box.',
    r'''\[
\ce{2H2 + O2 -> 2H2O}
\]

\[
\ce{N2 + 3H2 <=> 2NH3}
\]

\[
\ce{Cu^2+ + 2OH- -> Cu(OH)2 v}
\]

\[
\ce{CaCO3(s) ->[\Delta] CaO(s) + CO2(g) ^}
\]

Gravity pulls at \( \SI{9.81}{\metre\per\second\squared} \), light travels at
\( \SI{299792458}{\metre\per\second} \), and water boils at
\( \SI{373.15}{\kelvin} \).''',
  ),
  MathSample(
    'Probability and statistics',
    'Distributions, expectations and Bayes.',
    r'''\[
f(x \mid \mu, \sigma^2)
= \frac{1}{\sqrt{2\pi\sigma^2}}\, e^{-\frac{(x - \mu)^2}{2\sigma^2}}
\]

\[
P(A \mid B) = \frac{P(B \mid A)\, P(A)}{P(B)}
\]

\[
\mathbb{E}[X] = \sum_{i} x_i\, p(x_i)
\]

\[
\operatorname{Var}(X) = \mathbb{E}\left[(X - \mathbb{E}[X])^2\right]
\]

\[
\binom{n}{k} = \frac{n!}{k!\,(n - k)!}
\]''',
  ),
  MathSample(
    'Symbols, fonts and accents',
    'Blackboard bold, calligraphic, fraktur, accents and braces.',
    r'''\[
\mathbb{N} \subset \mathbb{Z} \subset \mathbb{Q} \subset \mathbb{R}
\subset \mathbb{C}
\]

\[
\mathcal{L}\{f\}(s) = \int_0^\infty f(t)\, e^{-st}\,dt
\]

\[
\mathfrak{g}, \ \boldsymbol{\alpha}
\]

\[
\hat{x},\ \vec{v},\ \dot{q},\ \ddot{q},\ \tilde{n},\ \overline{z}
\]

\[
\underbrace{1 + 1 + \cdots + 1}_{n \text{ times}} = n
\]

\[
\overbrace{a + b}^{\text{sum}}
\]

\[
\forall \varepsilon > 0\ \exists \delta > 0 :
\quad |x - a| < \delta \implies |f(x) - f(a)| < \varepsilon
\]''',
  ),
  MathSample(
    'Colour',
    'Highlight the part of a formula that matters.',
    r'''\[
\textcolor{teal}{a^2} + \textcolor{orange}{b^2} = \textcolor{purple}{c^2}
\]

\[
\frac{d}{dx}\left( {\color{red} x^n} \right) = {\color{red} n}\, x^{n - 1}
\]''',
  ),
  MathSample(
    'Long formulas',
    'Wider than the screen: they scroll sideways instead of running off the '
        'edge.',
    r'''\[
(a + b)^7 = a^7 + 7a^6 b + 21a^5 b^2 + 35a^4 b^3 + 35a^3 b^4 + 21a^2 b^5
+ 7a b^6 + b^7
\]

\[
\cos x = 1 - \frac{x^2}{2!} + \frac{x^4}{4!} - \frac{x^6}{6!}
+ \frac{x^8}{8!} - \frac{x^{10}}{10!} + \frac{x^{12}}{12!}
- \frac{x^{14}}{14!} + \cdots
\]''',
  ),
  MathSample(
    'Inside Markdown',
    'Maths in tables, lists and alerts, mixed with everything else.',
    r'''| Shape                | Area                          | Perimeter            |
|----------------------|-------------------------------|----------------------|
| Circle               | \( \pi r^2 \)                 | \( 2\pi r \)         |
| Rectangle            | \( ab \)                      | \( 2(a + b) \)       |
| Equilateral triangle | \( \frac{\sqrt{3}}{4} s^2 \)  | \( 3s \)             |

1. Start from \( y'' + \omega^2 y = 0 \).
2. Guess \( y = e^{rt} \), so \( r^2 + \omega^2 = 0 \) and \( r = \pm i\omega \).
3. Combine: \( y(t) = A\cos(\omega t) + B\sin(\omega t) \).

> [!TIP]
> Tap any formula to see the part you tapped. Select one and copy it: you get
> its LaTeX source back, ready to paste into a paper or another chat.''',
  ),
];

/// The reply the "streaming" card replays, chunk by chunk, as a model would
/// send it.
const streamedMathReply =
    r'''Solving \( ax^2 + bx + c = 0 \) by completing the square:

\[
\begin{aligned}
x^2 + \frac{b}{a}x &= -\frac{c}{a} \\
\left(x + \frac{b}{2a}\right)^2 &= \frac{b^2 - 4ac}{4a^2} \\
x &= \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
\end{aligned}
\]

So the roots are real exactly when \( b^2 - 4ac \ge 0 \).''';

/// A page with every [mathSamples] section.
class MathPage extends StatefulWidget {
  /// Creates the page.
  const MathPage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<MathPage> createState() => _MathPageState();
}

class _MathPageState extends State<MathPage> {
  /// Show each section's Markdown under its rendering.
  bool _showSource = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maths & LaTeX'),
        actions: [DemoThemeButton(onToggle: widget.onToggleTheme)],
      ),
      body: Column(
        children: [
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  const Text('Source'),
                  Switch(
                    value: _showSource,
                    onChanged: (v) => setState(() => _showSource = v),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            // Selecting a formula copies its LaTeX source.
            child: SelectionArea(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _card(
                    theme,
                    title: 'Streams as it arrives',
                    description:
                        'A formula still arriving renders what is there so '
                        'far, inside the reply, and grows with the stream.',
                    child: const _StreamingReply(),
                  ),
                  for (final sample in mathSamples)
                    _card(
                      theme,
                      title: sample.title,
                      description: sample.description,
                      child: _markdown(sample.markdown),
                      source: _showSource ? sample.markdown : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _markdown(String data) => GptMarkdown(
        data,
        onLinkTap: (url, title) {},
        // Every formula is a tap target; the details say which part was hit.
        onLatexTap: (tap) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                tap.tappedTex == null
                    ? 'Tapped ${tap.source}'
                    : 'Tapped ${tap.tappedTex}  in  ${tap.source}',
              ),
            ),
          ),
        styleSheet: const GptMarkdownStyleSheet(
          latex: LatexStyle(scrollBlockHorizontally: true),
        ),
      );

  Widget _card(
    ThemeData theme, {
    required String title,
    required String description,
    required Widget child,
    String? source,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                child,
                if (source != null) ...[
                  const SizedBox(height: 16),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        source,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Streams [streamedMathReply] into a [GptMarkdown] a few characters at a
/// time, holds the finished reply, and starts over.
class _StreamingReply extends StatefulWidget {
  const _StreamingReply();

  @override
  State<_StreamingReply> createState() => _StreamingReplyState();
}

class _StreamingReplyState extends State<_StreamingReply> {
  /// Characters per tick: roughly a token.
  static const _chunk = 4;

  /// Ticks to hold the finished reply before starting over.
  static const _hold = 50;

  Timer? _timer;
  int _received = 0;
  int _held = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 60), (_) {
      setState(() {
        if (_received < streamedMathReply.length) {
          _received = (_received + _chunk).clamp(0, streamedMathReply.length);
        } else if (++_held > _hold) {
          _received = 0;
          _held = 0;
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final streaming = _received < streamedMathReply.length;
    return ConstrainedBox(
      // The finished reply's height, so the card does not grow as it streams.
      constraints: const BoxConstraints(minHeight: 230),
      child: Align(
        alignment: AlignmentDirectional.topStart,
        child: GptMarkdown(
          streamedMathReply.substring(0, _received),
          isStreaming: streaming,
          animation: GptMarkdownAnimation.fade,
          styleSheet: const GptMarkdownStyleSheet(
            latex: LatexStyle(scrollBlockHorizontally: true),
          ),
        ),
      ),
    );
  }
}
