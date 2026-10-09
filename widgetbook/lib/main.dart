import 'package:material_ui/material_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

import 'main.directories.g.dart';

/// Catalogue for inspecting every gpt_markdown component across devices,
/// themes and text scales.
///
/// ```
/// flutter run -d macos  -t lib/main.dart
/// flutter run -d chrome -t lib/main.dart
/// ```
void main() => runApp(const GptMarkdownWidgetbook());

ThemeData _theme(Brightness brightness) => ThemeData(
  useMaterial3: true,
  colorSchemeSeed: Colors.indigo,
  brightness: brightness,
  extensions: [GptMarkdownThemeData(brightness: brightness)],
);

/// The widgetbook app.
@widgetbook.App()
class GptMarkdownWidgetbook extends StatelessWidget {
  /// Creates the widgetbook app.
  const GptMarkdownWidgetbook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      directories: directories,
      addons: [
        ThemeAddon<ThemeData>(
          themes: [
            WidgetbookTheme(name: 'Light', data: _theme(Brightness.light)),
            WidgetbookTheme(name: 'Dark', data: _theme(Brightness.dark)),
          ],
          themeBuilder: (context, theme, child) => Theme(
            data: theme,
            child: ColoredBox(
              color: theme.scaffoldBackgroundColor,
              child: DefaultTextStyle(
                style: theme.textTheme.bodyMedium!,
                child: child,
              ),
            ),
          ),
        ),
        // The reason this catalogue exists: a paragraph scales the box it
        // reserves for an inline widget, so anything rendered through a
        // WidgetSpan used to reserve far more space than it occupied. Drag
        // this up and the layout should stay proportional.
        TextScaleAddon(min: 0.85, max: 3.0, divisions: 10, initialScale: 1.0),
        ViewportAddon([
          IosViewports.iPhoneSE,
          IosViewports.iPhone13,
          IosViewports.iPhone13ProMax,
          IosViewports.iPadAir4,
          AndroidViewports.samsungGalaxyS20,
          AndroidViewports.onePlus8Pro,
        ]),
        AlignmentAddon(),
        InspectorAddon(),
        GridAddon(),
      ],
    );
  }
}
