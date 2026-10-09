import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

/// A [MaterialApp] wrapper giving every demo the same light and dark themes
/// and a working light/dark toggle.
///
/// The toggle matters here: most of what these demos show — the inline code
/// chip, link colours, table borders — is derived from the ambient
/// [ColorScheme], and a default that reads well on white can disappear on
/// black. Checking both is the point.
class DemoApp extends StatefulWidget {
  /// Creates a demo app.
  const DemoApp({super.key, required this.title, required this.pageBuilder});

  /// Window and app title.
  final String title;

  /// Builds the home page. [toggleTheme] flips light and dark; pass it to
  /// [DemoThemeButton].
  final Widget Function(VoidCallback toggleTheme) pageBuilder;

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  ThemeMode _mode = ThemeMode.light;

  void _toggle() => setState(
        () =>
            _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light,
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.title,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        extensions: [GptMarkdownThemeData(brightness: Brightness.light)],
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
        brightness: Brightness.dark,
        extensions: [GptMarkdownThemeData(brightness: Brightness.dark)],
      ),
      themeMode: _mode,
      home: widget.pageBuilder(_toggle),
    );
  }
}

/// The light/dark toggle every demo puts in its app bar.
class DemoThemeButton extends StatelessWidget {
  /// Creates the toggle.
  const DemoThemeButton({super.key, required this.onToggle});

  /// Flips the theme. Usually the callback [DemoApp] hands to its page builder.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? 'Switch to light' : 'Switch to dark',
      icon: Icon(isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
      onPressed: onToggle,
    );
  }
}
