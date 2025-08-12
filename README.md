# Coloring Book

A kid-friendly Flutter app that turns photos into coloring pages using AI and local processing.

## Features

- **Photo to Coloring Page**: Convert any photo from camera or photo library into line art
- **AI Generation**: Create coloring pages from text prompts using OpenAI
- **Local Processing**: Offline fallback that works without internet
- **Kid-Friendly UI**: Large buttons, simple navigation, haptic feedback
- **Tap-to-Fill Coloring**: Easy coloring with flood fill algorithm
- **Undo/Redo**: Up to 5 levels of undo/redo
- **Export**: Save as PNG or PDF, share completed artwork
- **Cross-Platform**: Works on both iOS and Android

## Setup

### Prerequisites

- Flutter 3.22+ with null safety
- iOS 14+ / Android API 21+
- Optional: OpenAI API key for AI features

### Installation

1. Clone this repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

### Platform Configuration

#### iOS Permissions

The app requires these permissions (already configured in `ios/Runner/Info.plist`):

- `NSPhotoLibraryUsageDescription`: Access photo library
- `NSPhotoLibraryAddUsageDescription`: Save to photo library
- `NSCameraUsageDescription`: Camera access

#### Android Permissions

Configured in `android/app/src/main/AndroidManifest.xml`:

- `READ_MEDIA_IMAGES` (API 33+)
- `READ_EXTERNAL_STORAGE` (older versions)
- `CAMERA`: Camera access
- `INTERNET`: OpenAI API calls

### OpenAI Setup

1. Get an API key from [OpenAI Platform](https://platform.openai.com/)
2. Open the app and go to Settings
3. Enable "OpenAI Features"
4. Enter your API key
5. Test the connection

## Architecture

- **State Management**: Riverpod
- **Networking**: Dio for OpenAI API
- **Image Processing**: Pure Dart `image` package
- **Local Storage**: SharedPreferences + file system
- **Export**: PDF generation with `printing` package

## File Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Main app widget
├── core/                     # Core utilities
│   ├── routing.dart         # Navigation
│   ├── theme.dart           # UI theme & colors
│   ├── haptics.dart         # Haptic feedback
│   └── result.dart          # Result type
├── features/
│   ├── home/                # Home screen
│   ├── help/                # Help screen
│   ├── settings/            # Settings & OpenAI config
│   └── pages/               # Coloring pages feature
│       ├── data/            # Data models & repository
│       ├── processing/      # Image processing & flood fill
│       └── ui/              # UI screens & widgets
├── ai/                      # OpenAI integration
│   ├── openai_backend.dart  # API client
│   └── prompts/             # Prompt templates
└── services/                # Shared services
    ├── storage_service.dart # File operations
    └── export_service.dart  # PNG/PDF export
```

## Key Components

### Image Processing Pipeline

1. **Resize** to max dimension (configurable)
2. **Grayscale** conversion
3. **Gaussian blur** for noise reduction
4. **Sobel edge detection** with adjustable threshold
5. **Binary threshold** for clean lines
6. **Dilation** to close gaps for flood fill

### Flood Fill Algorithm

- Scanline-based flood fill optimized for performance
- Respects outline boundaries (pixels < 50 luminance)
- Undo/redo via diff masks (limited to 5 actions)
- RGBA color layer composited over line art

### OpenAI Integration

- **Text-to-Image**: DALL-E 3 for prompt-based generation
- **Image-to-Image**: Image editing for photo conversion
- **Fallback**: Automatic local processing on API failure
- **Privacy**: Only selected images/prompts sent to OpenAI

## Privacy & Data

- **Local First**: All coloring pages stored locally
- **No Analytics**: No tracking or data collection
- **Optional AI**: OpenAI integration is opt-in only
- **Transparent**: Clear messaging about data sent to OpenAI

## Development

### Testing

```bash
# Run tests
flutter test

# Run with coverage
flutter test --coverage
```

### Building

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

## Troubleshooting

### Common Issues

1. **"Failed to pick image"**
   - Check camera/photo permissions
   - Restart app after granting permissions

2. **"AI unavailable → using Local"**
   - Check internet connection
   - Verify OpenAI API key in Settings
   - Check API key has sufficient credits

3. **"Failed to process image"**
   - Try a smaller or simpler image
   - Reduce outline strength setting
   - Check available device storage

4. **Coloring not working**
   - Ensure you're tapping white areas
   - Try adjusting outline strength for better boundaries
   - Use local processing for more predictable results

### Permissions (iOS)

If photo picker shows limited access:
- App will show a note with button to open Settings
- User can expand access in iOS Settings > Privacy & Security > Photos

### Performance Tips

- Images are automatically resized to 2048px max dimension
- Local processing is faster but less sophisticated than AI
- Undo/redo is limited to 5 actions to manage memory
- Old export files are cleaned up automatically

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Acknowledgments

- Uses OpenAI's DALL-E 3 for AI image generation
- Built with Flutter and the amazing Flutter community packages
- Designed specifically for young children with accessibility in mind