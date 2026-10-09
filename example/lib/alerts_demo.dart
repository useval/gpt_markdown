import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import 'demo_theme.dart';

/// Standalone demo of alerts — quotes that open with `[!NOTE]`, `[!TIP]`,
/// `[!IMPORTANT]`, `[!WARNING]` or `[!CAUTION]`.
///
/// Run it directly with:
/// ```
/// flutter run -t lib/alerts_demo.dart
/// ```
void main() => runApp(const AlertsApp());

/// Sample text: every alert type, plus the cases that stay ordinary quotes.
const alertsMarkdown = r'''# Alerts

> [!NOTE]
> Highlights information that users should take into account, even when skimming.

> [!TIP]
> Optional information to help a user be **more successful**.

> [!IMPORTANT]
> Crucial information necessary for users to succeed.

> [!WARNING]
> Critical content demanding immediate user attention due to potential risks.

> [!CAUTION]
> Negative potential consequences of an action.

## Rich content inside

> [!TIP]
> Alerts hold any Markdown:
>
> - lists, `inline code` and [links](https://example.com)
> - maths: \( e^{i\pi} + 1 = 0 \)

## Still ordinary quotes

> A quote with no marker.

> [!FOO]
> An unknown marker is left as written.

> [!NOTE] with text after the marker is not an alert either.
''';

/// Ways to style the same alerts, from the stock look to a full builder.
enum AlertPreset {
  /// No style sheet: the stock accent colours, icons and titles.
  standard('Default'),

  /// The tint and rounded corners turned off: just the bar.
  plain('No tint'),

  /// Translated titles and a different icon per type.
  titles('Custom titles'),

  /// No title row at all — just the coloured bar and the body.
  minimal('Body only'),

  /// `alertBuilder` draws a card; tips fall back to a plain quote.
  builder('alertBuilder');

  const AlertPreset(this.label);

  /// Shown on the preset's chip.
  final String label;
}

/// The demo app shell.
class AlertsApp extends StatelessWidget {
  /// Creates the demo app.
  const AlertsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoApp(
      title: 'gpt_markdown — alerts',
      pageBuilder: (toggleTheme) => AlertsPage(onToggleTheme: toggleTheme),
    );
  }
}

/// Editor, live preview, and a row of style presets.
class AlertsPage extends StatefulWidget {
  /// Creates the demo page.
  const AlertsPage({super.key, this.onToggleTheme});

  /// Flips the app between light and dark.
  final VoidCallback? onToggleTheme;

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  late final TextEditingController _controller = TextEditingController(
    text: alertsMarkdown,
  );
  AlertPreset _preset = AlertPreset.standard;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The style sheet for [_preset]. Every field is optional, so each preset
  /// sets only what it changes.
  GptMarkdownStyleSheet? _styleSheet() {
    switch (_preset) {
      case AlertPreset.standard:
      case AlertPreset.builder:
        return null;
      case AlertPreset.plain:
        return const GptMarkdownStyleSheet(
          alert: AlertStyle(
            backgroundColor: Colors.transparent,
            borderRadius: Radius.zero,
            padding: EdgeInsetsDirectional.only(start: 12, top: 4, bottom: 4),
          ),
        );
      case AlertPreset.titles:
        return const GptMarkdownStyleSheet(
          alert: AlertStyle(
            titleStyle: TextStyle(letterSpacing: 0.5),
            note: AlertStyle(title: 'Nota', icon: Icons.sticky_note_2_outlined),
            tip: AlertStyle(title: 'Consejo', icon: Icons.tips_and_updates),
            important: AlertStyle(
              title: 'Importante',
              icon: Icons.priority_high_rounded,
            ),
            warning: AlertStyle(title: 'Atención', icon: Icons.bolt),
            caution: AlertStyle(
              title: 'Precaución',
              icon: Icons.dangerous_outlined,
            ),
          ),
        );
      case AlertPreset.minimal:
        return const GptMarkdownStyleSheet(
          alert: AlertStyle(title: '', showIcon: false, barWidth: 4),
        );
    }
  }

  /// A card per alert, built from the stock title and body. Tips opt out and
  /// render as the quote they are written as.
  Widget _cardAlert(BuildContext context, AlertBuildDetails details) {
    if (details.type == MarkdownAlertType.tip) {
      return details.asBlockQuote();
    }
    final accent = details.style.color!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        elevation: 0,
        color: accent.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              details.title,
              const SizedBox(height: 6),
              details.content
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 900;

    final editor = TextField(
      controller: _controller,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      style:
          const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5),
      decoration: const InputDecoration(
        contentPadding: EdgeInsets.all(16),
        border: InputBorder.none,
        hintText: 'Type Markdown here…',
      ),
      onChanged: (_) => setState(() {}),
    );

    final preview = SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: GptMarkdown(
        _controller.text,
        // Builders are closures and are not compared when the widget updates,
        // so a builder switched on at runtime needs a new key to take effect.
        key: ValueKey(_preset),
        styleSheet: _styleSheet(),
        alertBuilder: _preset == AlertPreset.builder ? _cardAlert : null,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [DemoThemeButton(onToggle: widget.onToggleTheme)],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                for (final preset in AlertPreset.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(preset.label),
                      selected: _preset == preset,
                      onSelected: (_) => setState(() => _preset = preset),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      body: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _pane(theme, editor)),
                VerticalDivider(
                  width: 1,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(child: preview),
              ],
            )
          : Column(
              children: [
                SizedBox(height: 200, child: _pane(theme, editor)),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                Expanded(child: preview),
              ],
            ),
    );
  }

  Widget _pane(ThemeData theme, Widget editor) => ColoredBox(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        child: editor,
      );
}
