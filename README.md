# FileZipper + Snake Game

Flutter source code for a Data Structures final project containing:

- **Huffman File Zipper** – file selection, Huffman compression/decompression, ZIP output, and optional Google Drive file access.
- **Snake Game** – linked-list/deque snake body, input queue, collision detection, scoring, and BFS auto-play.

## Requirements

- Flutter SDK 3.47.x or newer
- Dart 3.7 or newer
- Visual Studio Code with the Flutter/Dart extensions
- Android Studio + Android SDK if running on Android
- A browser such as Chrome if running on Web

## 1. Open the project

Extract the ZIP and open the `filezipper_snakegame_source` folder in VS Code.

## 2. Generate Flutter platform folders

This package contains the project source files. If the `android`, `web`, `ios`, etc. folders are not present, open the project terminal and run:

```powershell
flutter create .
```

If Flutter asks whether existing files should be kept, keep the existing `lib` and `pubspec.yaml` files.

## 3. Install packages

Run:

```powershell
flutter pub get
```

## 4. Check Flutter

Run:

```powershell
flutter doctor
flutter devices
```

Make sure your desired device is listed.

## 5. Run on Chrome

For the easiest first test:

```powershell
flutter run -d chrome
```

## 6. Run on Android

Connect your Android phone with USB debugging enabled, then check:

```powershell
flutter devices
```

Run the application with:

```powershell
flutter run -d <YOUR_DEVICE_ID>
```

For example, if Flutter lists your phone as `TECNO KI5k`:

```powershell
flutter run -d "TECNO KI5k"
```

## 7. Project structure

```text
lib/
├── main.dart
├── snake/
│   ├── snake_screen.dart
│   ├── models/
│   │   ├── point.dart
│   │   ├── double_linked_list.dart
│   │   └── input_queue.dart
│   └── services/
│       └── snake_game_logic.dart
└── zipper/
    ├── zipper_screen.dart
    └── services/
        ├── huffman_engine.dart
        └── drive_service.dart
```

## 8. Main Data Structures

### Snake

- `Point` represents an `(x, y)` board position.
- `Deque` stores the snake body using a custom doubly linked list.
- `InputQueue` buffers movement directions.
- `Set<Point>` is used for fast snake collision checks.
- BFS searches for a shortest path from the snake head to the food when AI mode is enabled.

### Huffman Zipper

- A custom `MinHeap` is used as the priority queue for Huffman tree construction.
- A Huffman binary tree is built from byte frequencies.
- The generated codes are written into a custom compressed format.
- The project can also package processed data as a standard ZIP archive.

## Google Drive note

The Google Drive button requires Google Sign-In configuration for the target platform. If Google Sign-In is not configured, the local file picker/compression features can still be used.

For a normal class demonstration, test the local file zipper first before configuring Google Drive.

## Common commands

Clean the build:

```powershell
flutter clean
```

Get packages again:

```powershell
flutter pub get
```

Check source errors:

```powershell
flutter analyze
```

Run the app:

```powershell
flutter run
```

## Troubleshooting

### `Expected to find project root`

Make sure the terminal is opened in the folder containing `pubspec.yaml`.

Example:

```powershell
cd C:\path\to\filezipper_snakegame_source
flutter pub get
```

### `Target of URI doesn't exist`

Check that the file paths match the project structure shown above. In particular, Snake imports use:

```dart
import 'models/point.dart';
import 'services/snake_game_logic.dart';
```

### Android build problems

Run:

```powershell
flutter doctor
flutter clean
flutter pub get
flutter run
```

If the Android SDK/NDK itself is missing or corrupted, fix the Android SDK installation before changing the Dart source code.

## Submission

For a source-code submission, submit this project ZIP together with the README. Do not include the `.dart_tool` folder, build output, or other generated cache folders.
