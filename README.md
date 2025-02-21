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

# EcoSort AI Model 🧠

EcoSort utilizes a custom **TensorFlow Lite** model built on the **MobileNetV2** architecture for efficient on-device waste classification.

## Model Specifications 📊
- **Architecture:** MobileNetV2 (transfer learning)
- **Input:** 224×224 RGB images
- **Output:** 7 waste categories
- **Model Size:** ~8MB (optimized for mobile)
- **Accuracy:** 92.4% on validation set

## Waste Categories 🏷️
- 📦 **Cardboard**
- 🥫 **Metal**
- 📄 **Paper**
- 🍶 **Glass**
- 🥤 **Plastic**
- 🍎 **Biological/Compost**
- 🗑️ **Mixed Trash/Landfill**

## Model Training 📚
The model was trained using a combined dataset from three public waste classification datasets:

- **25,000+** waste item images
- Applied **data augmentation** (rotation, zoom, flip)
- Fine-tuned **MobileNetV2**, pre-trained on ImageNet

## Deployment 🚀
EcoSort's AI model is optimized for mobile devices using **TensorFlow Lite (TFLite)**, ensuring efficient on-device inference without requiring an internet connection.

## Usage 🛠️
To use the model in a Flutter application:
1. **Load the TFLite model** using `tflite_flutter` package.
2. **Preprocess input** images to match the model’s expected **224×224 RGB** format.
3. **Run inference** and classify the waste item into one of the seven categories.
4. **Display results** with confidence scores.

## Future Enhancements 🔮
- Expand dataset for improved accuracy.
- Implement real-time classification optimizations.
- Support additional waste types and regional recycling guidelines.

---
🚀 **EcoSort AI – Making Waste Sorting Smarter!**



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

# Install dependencies
flutter pub get

# Run on connected Android device
flutter run


## Acknowledgements 🙏

This project leverages the following resources:

- **TensorFlow Lite** by the [TensorFlow team](https://www.tensorflow.org/lite)
- Kaggle datasets:
  - [Waste Classification Data](https://www.kaggle.com/datasets/techsash/waste-classification-data)
  - [Garbage Classification](https://www.kaggle.com/datasets/mostafaabiba/garbage-classification)
  - [Garbage Classification Dataset](https://www.kaggle.com/datasets/aryashah2k/garbage-classification-dataset) (12-class version)

We gratefully acknowledge the contributors and maintainers of these valuable resources.
