```dart
// Render a reply while it streams in.
GptMarkdown(
  reply,
  isStreaming: !done,
  onLinkTap: (url, title) => launchUrlString(url),
)
```
