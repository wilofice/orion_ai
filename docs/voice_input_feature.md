# Voice Input Feature Study

This document summarizes design considerations for enabling voice input in the
Orion chat screen.

## Possible Approaches

1. **Send raw audio to backend**
   - Requires implementing audio recording and file upload.
   - Backend must accept audio, transcribe it, then generate a reply.
   - Higher network usage and increased backend complexity.
2. **Client-side speech recognition**
   - Use a package such as `speech_to_text` to convert speech to text on the
device.
   - Send resulting text to the existing chat endpoint.
   - Works offline for recognition initialization and keeps backend unchanged.

## Chosen Solution

The repository already expects text prompts. Using client-side speech
recognition keeps the API simple while giving users quick feedback. The
`speech_to_text` package is widely used and works on both Android and iOS.
Therefore the implementation in this pull request adds `speech_to_text` as a
dependency and provides a small `SpeechService` wrapper.

## Customisation

Two new preferences are introduced:

- `inputMode` – `text`, `voice`, or `both`.
- `voiceButtonPosition` – `left` or `right` when both text and voice controls are
  shown.

Users can configure these values on the Preferences screen. The chat input bar
reads these settings and adapts its layout.

## Suggested Subtasks for Future Work

1. **Improve speech UX** – Provide visual feedback while listening and allow
   cancelling recording.
2. **Handle long recordings** – Automatically stop after a timeout or when the
   user pauses.
3. **Backend support for audio** *(optional)* – If higher quality is needed,
   split the work into backend upload, storage, and transcription steps.

