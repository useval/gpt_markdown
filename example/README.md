# example

A new Flutter project.

## RTL block alignment

Open **RTL block alignment demo** from the main example's toolbar, or run:

```sh
flutter run -d macos -t lib/rtl_demo.dart
```

The page uses one original Arabic showcase covering all heading levels, inline
formatting, mixed scripts, nested lists and quotes, tasks, radio options, tables,
math, code, offline illustrations and custom inline patterns/directives. Switch between Plusparse, legacy regex and lazy sliver
rendering, RTL/LTR direction, and text scales. The surrounding page deliberately
stays LTR so the preview tests the Markdown's own direction setting.

## Clamped previews (`maxLines`)

Open **maxLines demo** from the main example's toolbar, or run:

```sh
flutter run -d macos -t lib/max_lines_demo.dart
```

Both parsers render the same sample side by side at a chosen preview width,
with the measured height of each and a banner that turns red if they disagree.
They have to agree: a clamp is a property of the widget, so which parser runs
must not change how tall the preview is. The default sample has several blocks,
which is where this went wrong — the incremental parser gives each block its own
paragraph, and `maxLines` belongs to a paragraph, so every block used to take
the full allowance.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
