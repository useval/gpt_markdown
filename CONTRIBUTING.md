# Contributing to gpt_markdown

Thanks for helping. This page covers how to report problems, set up the
project, and get a pull request merged.

## Issues

Use the issue forms: **Bug report** or **Feature request**. For a bug, the one
thing that matters most is the **smallest Markdown that still shows the
problem**, together with how you build `GptMarkdown`. Please search open issues
and pull requests first.

Many requests need no change to the package — a style field or a builder often
already covers it. See [customization](docs/customization.mdx) and
[API options](docs/options.mdx).

## Setup

You need Flutter on the stable channel. CI uses the latest stable release.

```sh
git clone https://github.com/useval/gpt_markdown.git
cd gpt_markdown
flutter pub get
```

The repository pins a Flutter version in `.fvmrc`. If you use
[FVM](https://fvm.app), `fvm use` picks it up, and every `just` recipe uses
that SDK automatically. Without FVM, the recipes use whatever `flutter` is on
your `PATH`.

Recipes run with [`just`](https://github.com/casey/just); `just` with no
argument lists them. The ones you will use most:

| Recipe | What it does |
|---|---|
| `just check` | Format check, analyze and test the package and all three apps — exactly what CI runs |
| `just fix` | Same, but applies formatting instead of failing |
| `just example` | Runs the showcase app (`-d macos` by default) |
| `just widgetbook` | Runs the component catalogue |
| `just ai-chat` | Runs the streaming chat harness |

## Tests

`just check` must pass before a pull request is merged. It runs
`./scripts/check.sh`, which covers the package and the `example`,
`example_ai_chat` and `widgetbook` apps, with `flutter analyze --fatal-infos`.

- **A fixed bug gets a regression test** in `test/regression/`. A known bug
  that is not fixed yet can be recorded in `test/bugs/`; see
  [test/README.md](test/README.md).
- **Golden tests** (`test/golden/`) are off by default, on CI too, because
  text rendering differs between platforms. Run them with
  `just check --golden`. If your change is meant to alter the default look,
  regenerate them with `just update-goldens` and review the images; see
  [docs/testing.mdx](docs/testing.mdx#golden-tests).
- **Component pages stay in step with `lib/`.** The API reference on each page
  under `docs/components/` is generated: run `dart run tool/docs/api_reference.dart`
  after changing a style field, a builder typedef or a doc comment
  (`test/docs/api_reference_test.dart` fails until you do). Each page's preview
  and Markdown tab come from `tool/screenshots/components/<name>.md`; re-render
  with `./scripts/screenshots.sh`.
- **Doc examples compile.** Code samples in `docs/` are mirrored in
  `test/docs/snippets_test.dart`; update both when you change an example.

## Making a change

**One change per pull request.** A fix, a feature, and a refactor are three
pull requests. Bundled changes are hard to review and are usually sent back.

What we look for:

- **No breaking changes** to the public API without discussion first. New
  options are optional, and new style fields default to the current look.
- **Unset styles render exactly as before.** Adding a field to a style must not
  change how existing content looks.
- **The default renderer first.** New syntax and features go into the default
  (plusparse) renderer. The legacy renderer — used when an app passes
  `components` or `inlineComponents` — is deprecated and only needs to keep
  working.
- **Text scaling and right-to-left.** Layout changes should hold up at large
  text scales and in right-to-left text.
- **A changelog entry** under `## Unreleased` in `CHANGELOG.md`, in the same
  style as the entries already there.
- **Docs** updated when behaviour or API changes.

## After you open a pull request

A maintainer is requested for review automatically. CI runs `just check`,
which needs to pass. Expect review comments — most pull requests go through a
round or two.

## License

gpt_markdown is released under the [BSD 3-Clause License](LICENSE). Your
contributions are released under the same license.
