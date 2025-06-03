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

Voice messages are now recorded on device and uploaded to Amazon S3. During the
recording the `speech_to_text` package transcribes the audio locally. After the
file is uploaded, the transcript together with the resulting S3 URL is sent to
the backend `/chat/prompt` route. The backend stores both pieces so that the
conversation history can later show the audio clip along with its text
representation.

The upload service uses credentials defined in `.env`:

- `AWS_S3_REGION`
- `AWS_S3_BUCKET`
- `AWS_ACCESS_KEY`
- `AWS_SECRET_KEY`

Make sure these values are set before running the app.

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
3. **Audio playback UI** – Provide controls to play back recorded clips inside
   the conversation history.

