# EcoSort AI 🍃

[![Flutter](https://img.shields.io/badge/Flutter-3.22-blue)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TensorFlow%20Lite-2.12-orange)](https://www.tensorflow.org/lite)
[![Android](https://img.shields.io/badge/Android-13%2B-brightgreen)](https://www.android.com)
[![APK Download](https://img.shields.io/badge/Download-APK-success)](https://github.com/yourusername/ecosort-ai/releases/latest/download/app-release.apk)

An AI-powered waste classification app that helps you sort trash correctly and learn recycling practices.

<img src="docs/screenshots/screenshot1.jpg" width="200" hspace="10"> <img src="docs/screenshots/screenshot2.jpg" width="200" hspace="10"> <img src="docs/screenshots/screenshot3.jpg" width="200" hspace="10">

## Features ✨
- 📸 Real-time waste classification using camera
- ♻️ Material-specific recycling guidelines
- 📊 Environmental impact tracking
- 📍 Nearby recycling center suggestions
- 📚 Educational recycling tips
- 📁 Scan history storage


**Requirements:**
- Android 13 or higher
- Camera support
- 4GB+ RAM recommended

**Installation:**
1. Enable "Install from unknown sources" in Settings
2. Download the APK file
3. Open the downloaded file and install

## Tech Stack 🛠️
- **Frontend**: Flutter (Dart)
- **AI Model**: TensorFlow Lite (MobileNetV2)
- **Computer Vision**: Image package
- **State Management**: Provider
- **Local Storage**: SharedPreferences

## Installation (Development) 🔧
```bash
# Clone repository
git clone https://github.com/spl3ndid/Ecosort.git

# Enter project directory
cd ecosort-ai/app

# Install dependencies
flutter pub get

# Run on connected Android device
flutter run
