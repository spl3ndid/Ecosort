import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

// Main entry point with error handling
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    final cameras = await availableCameras();
    runApp(EcoSortApp(cameras: cameras));
  } catch (e) {
    print('Initialization error: $e');
    runApp(const ErrorApp());
  }
}

// Error fallback app
class ErrorApp extends StatelessWidget {
  const ErrorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Failed to initialize the app',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Please restart the application',
                  style: TextStyle(fontSize: 16))
            ],
          ),
        ),
      ),
    );
  }
}

class EcoSortApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const EcoSortApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Lock orientation to portrait mode
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoSort AI',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A86B),
          brightness: Brightness.light,
          primary: const Color(0xFF00A86B),
          secondary: const Color(0xFF4CAF50),
          tertiary: const Color(0xFF2E7D32),
          background: const Color(0xFFF8F9FA),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
          displayMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          displaySmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          headlineLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontFamily: 'Inter', height: 1.5),
          bodyMedium: TextStyle(fontFamily: 'Inter', height: 1.5),
          bodySmall: TextStyle(fontFamily: 'Inter', height: 1.4),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            backgroundColor: const Color(0xFF00A86B),
            foregroundColor: Colors.white,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
            side: const BorderSide(color: Color(0xFF00A86B), width: 2),
          ),
        ),
      ),
      home: SplashScreen(cameras: cameras),
    );
  }
}
// Helper class for managing app state
class AppStateProvider {
  static final AppStateProvider _instance = AppStateProvider._internal();
  factory AppStateProvider() => _instance;
  AppStateProvider._internal();

  // Singleton model interpreter
  Interpreter? _interpreter;
  List<String>? _labels;
  bool _modelLoaded = false;
  final List<ScanResult> _scanHistory = [];

  Future<void> initializeModel() async {
    if (_modelLoaded) return;

    try {
      final modelFile = await _getModel();
      _interpreter = await Interpreter.fromFile(modelFile);
      await _loadLabels();
      _modelLoaded = true;
      print('Model loaded successfully');
    } catch (e) {
      print('Error loading model: $e');
      throw Exception('Failed to initialize model: $e');
    }
  }

  Future<File> _getModel() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelPath = '${appDir.path}/model.tflite';
    final modelFile = File(modelPath);

    if (!await modelFile.exists()) {
      final byteData = await rootBundle.load('assets/model.tflite');
      await modelFile.writeAsBytes(byteData.buffer.asUint8List());
    }
    return modelFile;
  }

  Future<void> _loadLabels() async {
    try {
      final labelData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelData.split('\n')
          .map((String label) => label.trim())
          .where((String label) => label.isNotEmpty)
          .toList();
    } catch (e) {
      print('Error loading labels: $e');
      throw Exception('Failed to load labels: $e');
    }
  }

  Interpreter? get interpreter => _interpreter;
  List<String>? get labels => _labels;
  List<ScanResult> get scanHistory => _scanHistory;

  void addScanResult(ScanResult result) {
    _scanHistory.insert(0, result); // Add newest first
    // Limit history to 50 items
    if (_scanHistory.length > 50) {
      _scanHistory.removeLast();
    }
    _saveScanHistory();
  }

  Future<void> _saveScanHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyData = _scanHistory.take(20).map((result) => result.toJson()).toList();
      await prefs.setStringList('scan_history', historyData);
    } catch (e) {
      print('Error saving scan history: $e');
    }
  }

  Future<void> loadScanHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyData = prefs.getStringList('scan_history') ?? [];
      _scanHistory.clear();
      _scanHistory.addAll(historyData.map((json) => ScanResult.fromJson(json)));
    } catch (e) {
      print('Error loading scan history: $e');
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}

// Model class for scan results
class ScanResult {
  final String itemType;
  final double confidence;
  final String imagePath;
  final DateTime timestamp;
  final String? disposalInstructions;

  ScanResult({
    required this.itemType,
    required this.confidence,
    required this.imagePath,
    required this.timestamp,
    this.disposalInstructions,
  });

  String toJson() {
    return '{"itemType":"$itemType","confidence":$confidence,"imagePath":"$imagePath","timestamp":"${timestamp.toIso8601String()}","disposalInstructions":"${disposalInstructions ?? ""}"}';
  }

  factory ScanResult.fromJson(String json) {
    final parts = json.replaceAll('{', '').replaceAll('}', '').split(',');
    final map = <String, String>{};

    for (var part in parts) {
      final keyValue = part.split(':');
      if (keyValue.length == 2) {
        String key = keyValue[0].replaceAll('"', '');
        String value = keyValue[1].replaceAll('"', '');
        map[key] = value;
      }
    }

    return ScanResult(
      itemType: map['itemType'] ?? 'Unknown',
      confidence: double.tryParse(map['confidence'] ?? '0') ?? 0,
      imagePath: map['imagePath'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      disposalInstructions: map['disposalInstructions'],
    );
  }

  // Get appropriate disposal instructions based on item type
  String getDisposalInstructions() {
    if (disposalInstructions != null && disposalInstructions!.isNotEmpty) {
      return disposalInstructions!;
    }

    switch (itemType.toLowerCase()) {
      case 'plastic':
        return 'Rinse container and place in recycling bin. Remove caps if different material.';
      case 'glass':
        return 'Rinse and place in glass recycling. Remove any non-glass components.';
      case 'paper':
        return 'Place clean, dry paper in paper recycling. Shred confidential documents.';
      case 'metal':
        return 'Rinse and place in metal recycling. Large items may need special collection.';
      case 'organic':
        return 'Place in compost bin or green waste collection if available.';
      case 'electronic':
        return 'Take to e-waste recycling center. Do not place in regular trash.';
      default:
        return 'Check local guidelines for proper disposal of this item.';
    }
  }
}

class SplashScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SplashScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  bool _isLoading = true;
  String _loadingMessage = "Initializing...";

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() {
        _loadingMessage = "Loading AI model...";
      });

      // Initialize model in background
      await AppStateProvider().initializeModel();
      await AppStateProvider().loadScanHistory();

      // Ensure minimum splash screen display time
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
            _shouldShowOnboarding()
                ? OnboardingScreen(cameras: widget.cameras)
                : HomePage(cameras: widget.cameras),
            transitionDuration: const Duration(milliseconds: 800),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingMessage = "Failed to initialize. Please restart the app.";
      });
      print('Initialization error: $e');
    }
  }

  bool _shouldShowOnboarding() {
    return true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00A86B),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPatternPainter(),
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'EcoSort AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Poppins',
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Snap. Sort. Sustain.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontFamily: 'Inter',
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                      if (_isLoading)
                        Column(
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                backgroundColor: Colors.white.withOpacity(0.2),
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _loadingMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(0, i),
        Offset(i, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class OnboardingScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const OnboardingScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _onboardingData = [
    {
      'title': 'Scan & Identify',
      'description': 'Point your camera at any waste item and our AI will instantly identify what material it is.',
      'image': 'assets/onboarding_scan.png',
      'color': const Color(0xFF2E7D32),
    },
    {
      'title': 'Get Disposal Guidance',
      'description': 'Receive specific instructions on how to properly dispose of or recycle the item.',
      'image': 'assets/onboarding_guide.png',
      'color': const Color(0xFF00796B),
    },
    {
      'title': 'Track Your Impact',
      'description': 'See your recycling statistics and environmental impact over time.',
      'image': 'assets/onboarding_impact.png',
      'color': const Color(0xFF00695C),
    },
    {
      'title': 'Join the Movement',
      'description': 'Be part of the global community working toward a cleaner, more sustainable future.',
      'image': 'assets/onboarding_community.png',
      'color': const Color(0xFF004D40),
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => HomePage(cameras: widget.cameras),
          ),
        );
      }
    } catch (e) {
      print('Error saving onboarding status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            color: _onboardingData[_currentPage]['color'],
            curve: Curves.easeInOut,
          ),

          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _onboardingData.length,
                  itemBuilder: (context, index) {
                    return buildOnboardingPage(
                      title: _onboardingData[index]['title'],
                      description: _onboardingData[index]['description'],
                      image: _onboardingData[index]['image'],
                    );
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: List.generate(
                        _onboardingData.length,
                            (index) => buildPageIndicator(index == _currentPage),
                      ),
                    ),

                    ElevatedButton(
                      onPressed: () {
                        if (_currentPage < _onboardingData.length - 1) {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                        } else {
                          _completeOnboarding();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _onboardingData[_currentPage]['color'],
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < _onboardingData.length - 1 ? 'Next' : 'Get Started',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: TextButton(
              onPressed: _completeOnboarding,
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildOnboardingPage({
    required String title,
    required String description,
    required String image,
  }) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Icon(
                getIconForImage(image),
                size: 120,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          const Spacer(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
              fontFamily: 'Inter',
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  IconData getIconForImage(String imagePath) {
    if (imagePath.contains('scan')) return Icons.camera_alt;
    if (imagePath.contains('guide')) return Icons.info_outline;
    if (imagePath.contains('impact')) return Icons.eco;
    if (imagePath.contains('community')) return Icons.people;
    return Icons.image;
  }
}

class HomePage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomePage({Key? key, required this.cameras}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}


class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late CameraController _controller;
  bool _isProcessing = false;
  late AnimationController _scanAnimationController;
  late AnimationController _pulseAnimationController;
  bool _isFlashOn = false;
  final int _inputSize = 224;
  final int _numChannels = 3;
  String _errorMessage = "";
  bool _showFeatures = false;

  // Dummy data for nearby facilities
  final List<Map<String, dynamic>> _nearbyFacilities = [
    {
      'name': 'Green Recycling Center',
      'distance': '0.8 km',
      'rating': 4.5,
      'type': 'All Materials',
      'address': '123 Green Street',
      'isOpen': true,
    },
    {
      'name': 'Electronic Waste Facility',
      'distance': '1.2 km',
      'rating': 4.2,
      'type': 'Electronics',
      'address': '456 Tech Road',
      'isOpen': true,
    },
    {
      'name': 'City Recycling Depot',
      'distance': '2.5 km',
      'rating': 4.0,
      'type': 'General Waste',
      'address': '789 Municipal Ave',
      'isOpen': false,
    },
  ];

  // Dummy data for recycling tips
  final List<Map<String, dynamic>> _recyclingTips = [
    {
      'title': 'Plastic Recycling',
      'tip': 'Clean and dry containers before recycling',
      'icon': Icons.local_drink,
    },
    {
      'title': 'Paper Waste',
      'tip': 'Flatten cardboard boxes to save space',
      'icon': Icons.article,
    },
    {
      'title': 'Battery Disposal',
      'tip': 'Never throw batteries in regular trash',
      'icon': Icons.battery_alert,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();

    _scanAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller.initialize();
      // Set initial camera settings
      await _controller.setFlashMode(FlashMode.off);
      await _controller.setExposureMode(ExposureMode.auto);
      await _controller.setFocusMode(FocusMode.auto);

      if (mounted) setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to initialize camera: $e";
      });
      print('Error initializing camera: $e');
    }
  }

  Future<Float32List?> _processImage(String imagePath) async {
    try {
      final imageData = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageData);

      if (image == null) return null;

      final resizedImage = img.copyResize(
        image,
        width: _inputSize,
        height: _inputSize,
      );

      Float32List float32Data = Float32List(_inputSize * _inputSize * _numChannels);
      int pixelIndex = 0;

      for (int y = 0; y < _inputSize; y++) {
        for (int x = 0; x < _inputSize; x++) {
          final pixel = resizedImage.getPixel(x, y);
          float32Data[pixelIndex] = pixel.r / 255.0;
          float32Data[pixelIndex + 1] = pixel.g / 255.0;
          float32Data[pixelIndex + 2] = pixel.b / 255.0;
          pixelIndex += 3;
        }
      }

      return float32Data;
    } catch (e) {
      print('Error processing image: $e');
      return null;
    }
  }

  Future<ScanResult?> _runInference(String imagePath) async {
    final appState = AppStateProvider();
    if (appState.interpreter == null || appState.labels == null) {
      setState(() => _errorMessage = "Model or labels not loaded");
      return null;
    }

    try {
      final processedImageData = await _processImage(imagePath);
      if (processedImageData == null) {
        throw Exception('Failed to process image');
      }

      // Get shape information from the model
      final inputShape = appState.interpreter!.getInputTensor(0).shape;
      final outputShape = appState.interpreter!.getOutputTensor(0).shape;
      final numClasses = outputShape[outputShape.length - 1];

      final inputTensor = [
        processedImageData.reshape([1, _inputSize, _inputSize, _numChannels])
      ];
      final outputBuffer = List<double>.filled(numClasses, 0).reshape([1, numClasses]);

      appState.interpreter!.run(inputTensor[0], outputBuffer);
      final resultList = outputBuffer[0] as List<double>;

      double maxScore = 0;
      int maxIndex = 0;
      for (int i = 0; i < resultList.length; i++) {
        if (resultList[i] > maxScore) {
          maxScore = resultList[i];
          maxIndex = i;
        }
      }

      return ScanResult(
        itemType: appState.labels![maxIndex],
        confidence: maxScore,
        imagePath: imagePath,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      print('Error running inference: $e');
      setState(() => _errorMessage = "Error processing image: $e");
      return null;
    }
  }

  Future<void> captureAndClassify() async {
    if (!_controller.value.isInitialized || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Provide haptic feedback
      HapticFeedback.mediumImpact();

      // Show animation overlay
      _showCaptureAnimation();

      // Capture image
      final image = await _controller.takePicture();

      final result = await _runInference(image.path);

      if (result != null) {
        // Add result to history
        AppStateProvider().addScanResult(result);

        // Show results screen
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResultScreen(result: result),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to capture image: $e");
      print('Error capturing image: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showCaptureAnimation() {
    // Add capture animation logic here
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Transform.scale(
            scale: _showFeatures ? 0.7 : 1.0,
            child: Center(
              child: CameraPreview(_controller),
            ),
          ),

          // Additional features panel
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            bottom: 0,
            left: 0,
            right: 0,
            height: _showFeatures ? MediaQuery.of(context).size.height * 0.6 : 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recycling Hub',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _showFeatures = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Nearby Facilities Section
                    _buildSectionTitle('Nearby Facilities'),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _nearbyFacilities.length,
                        itemBuilder: (context, index) {
                          final facility = _nearbyFacilities[index];
                          return _buildFacilityCard(facility);
                        },
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Recycling Tips Section
                    _buildSectionTitle('Quick Recycling Tips'),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recyclingTips.length,
                      itemBuilder: (context, index) {
                        final tip = _recyclingTips[index];
                        return _buildTipCard(tip);
                      },
                    ),

                    const SizedBox(height: 24),

                    // Weekly Impact Section
                    _buildSectionTitle('Your Weekly Impact'),
                    _buildImpactCard(),
                  ],
                ),
              ),
            ),
          ),

          // Controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Flash toggle
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      try {
                        final newMode = _isFlashOn ? FlashMode.off : FlashMode.torch;
                        await _controller.setFlashMode(newMode);
                        setState(() => _isFlashOn = !_isFlashOn);
                      } catch (e) {
                        print('Error toggling flash: $e');
                      }
                    },
                  ),

                  // Capture button
                  GestureDetector(
                    onTap: captureAndClassify,
                    child: AnimatedBuilder(
                      animation: _pulseAnimationController,
                      builder: (context, child) {
                        return Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(
                                0.5 + (_pulseAnimationController.value * 0.5),
                              ),
                              width: 3,
                            ),
                            color: _isProcessing ? Colors.green : Colors.white,
                          ),
                          child: _isProcessing
                              ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          )
                              : null,
                        );
                      },
                    ),
                  ),

                  // Features toggle button
                  IconButton(
                    icon: Icon(
                      _showFeatures ? Icons.expand_more : Icons.expand_less,
                      color: Colors.white,
                    ),
                    onPressed: () => setState(() => _showFeatures = !_showFeatures),
                  ),
                ],
              ),
            ),
          ),

          // Error message
          if (_errorMessage.isNotEmpty)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFacilityCard(Map<String, dynamic> facility) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Handle facility tap
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: facility['isOpen']
                            ? Colors.green.withOpacity(0.1)
                            : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        facility['isOpen'] ? 'Open' : 'Closed',
                        style: TextStyle(
                          color: facility['isOpen'] ? Colors.green : Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          facility['rating'].toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  facility['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  facility['type'],
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      facility['distance'],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard(Map<String, dynamic> tip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(
          tip['icon'],
          color: Theme.of(context).primaryColor,
        ),
        title: Text(
          tip['title'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(tip['tip']),
      ),
    );
  }

  Widget _buildImpactCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.eco,
                color: Colors.green,
              ),
              SizedBox(width: 8),
              Text(
                'Your Contribution',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildImpactMetric(
                '12 kg',
                'Waste Recycled',
                Icons.delete_outline,
              ),
              _buildImpactMetric(
                '5.2 kg',
                'CO₂ Saved',
                Icons.cloud_outlined,
              ),
              _buildImpactMetric(
                '8',
                'Items Scanned',
                Icons.document_scanner,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImpactMetric(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.green,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ResultScreen extends StatelessWidget {
  final ScanResult result;

  const ResultScreen({super.key, required this.result});

  Color _getItemColor() {
    switch (result.itemType.toLowerCase()) {
      case 'plastic':
        return Colors.blue;
      case 'glass':
        return Colors.green;
      case 'paper':
        return Colors.brown;
      case 'metal':
        return Colors.grey;
      case 'organic':
        return Colors.green.shade800;
      case 'electronic':
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  IconData _getItemIcon() {
    switch (result.itemType.toLowerCase()) {
      case 'plastic':
        return Icons.local_drink;
      case 'glass':
        return Icons.wine_bar;
      case 'paper':
        return Icons.article;
      case 'metal':
        return Icons.recycling;
      case 'organic':
        return Icons.eco;
      case 'electronic':
        return Icons.devices;
      default:
        return Icons.category;
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemColor = _getItemColor();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          color: Colors.black87,
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  _buildHeader(context, itemColor),
                  _buildInfoCard(context, itemColor),
                  _buildActionButtons(context, itemColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Color itemColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Material(
            elevation: 2,
            shape: const CircleBorder(),
            color: itemColor.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Icon(
                _getItemIcon(),
                size: 64,
                color: itemColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            result.itemType,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: itemColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${(result.confidence * 100).toStringAsFixed(1)}% Confidence',
              style: TextStyle(
                color: itemColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, Color itemColor) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildDisposalInstructions(context, itemColor),
            _buildEnvironmentalImpact(context, itemColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDisposalInstructions(BuildContext context, Color itemColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: itemColor),
              const SizedBox(width: 12),
              Text(
                'How to Dispose',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            result.getDisposalInstructions(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentalImpact(BuildContext context, Color itemColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: itemColor.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.eco, color: itemColor),
              const SizedBox(width: 12),
              Text(
                'Environmental Impact',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _getEnvironmentalImpact(),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, Color itemColor) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: itemColor,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Scan Another Item',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              // TODO: Implement share functionality
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
              side: BorderSide(color: itemColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              'Share Results',
              style: TextStyle(
                color: itemColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getEnvironmentalImpact() {
    switch (result.itemType.toLowerCase()) {
      case 'plastic':
        return 'Plastic takes 400+ years to decompose. Recycling one ton of plastic saves 7.4 cubic yards of landfill space.';
      case 'glass':
        return 'Glass is 100% recyclable and can be recycled endlessly without loss in quality or purity.';
      case 'paper':
        return 'Recycling one ton of paper saves 17 trees and 7,000 gallons of water.';
      case 'metal':
        return 'Metal recycling reduces greenhouse gas emissions and saves up to 95% of the energy used to make products from raw materials.';
      case 'organic':
        return 'Composting organic waste reduces methane emissions from landfills and creates nutrient-rich soil.';
      case 'electronic':
        return 'E-waste contains toxic materials. Proper recycling prevents hazardous substances from entering the environment.';
      default:
        return 'Proper disposal helps protect our environment and reduce landfill waste.';
    }
  }
}

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final history = AppStateProvider().scanHistory;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: history.isEmpty
          ? const Center(
        child: Text('No scan history yet'),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          final scan = history[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              title: Text(scan.itemType),
              subtitle: Text(
                DateFormat('MMM d, y • h:mm a').format(scan.timestamp),
              ),
              trailing: Text(
                '${(scan.confidence * 100).toStringAsFixed(1)}%',
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultScreen(result: scan),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}