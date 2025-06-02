# Handling Links in Chat Messages

The chat interface now uses the `flutter_linkify` package to detect and display
URLs contained in assistant messages. When the assistant replies with text that
includes a link (e.g. `https://example.com`), the text is automatically
converted into a clickable link. Tapping the link opens it using the
`url_launcher` package.

Because link detection happens in the Flutter client, the backend can simply
return plain URLs inside the `response_text` field. No special formatting such
as HTML or Markdown is required.
