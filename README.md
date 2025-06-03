# orion_ai

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Documentation

- [Handling links in chat messages](docs/link_handling.md)
- [Voice input feature](docs/voice_input_feature.md)

## Environment Configuration

Create a `.env` file based on the template below:

```
GOOGLE_CLIENT_ID_IOS=...
GOOGLE_CLIENT_ID_ANDROID=...
GOOGLE_CUSTOM_SCHEME_IOS=...
GOOGLE_CUSTOM_SCHEME_ANDROID=...
BACKEND_API_BASE_URL=http://<backend-url>
AWS_S3_REGION=us-east-1
AWS_S3_BUCKET=<your-bucket>
AWS_ACCESS_KEY=<your-access-key>
AWS_SECRET_KEY=<your-secret-key>
```

These values are loaded at runtime to configure Google OAuth and the S3 upload service.
