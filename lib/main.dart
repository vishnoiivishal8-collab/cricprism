// ============================================================================
// CricPrism - Cricket Analytics & Broadcast Engine
// Stable Production Build
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Hardware camera fallback: $e');
  }

  runApp(const CricPrismApp());
}

enum AppMode { match, practice }

class TrajectoryPoint {
  final Offset position;
  final double timestamp;
  final double radius;
  final bool isBounce;
  final double velocityKmph;

  TrajectoryPoint({
    required this.position,
    required this.timestamp,
    this.radius = 4.0,
    this.isBounce = false,
    this.velocityKmph = 135.0,
  });
}

class Batsman {
  String name;
  int runs;
  int balls;
  int fours;
  int sixes;
  bool isStriker;

  Batsman({
    required this.name,
    this.runs = 0,
    this.balls = 0,
    this.fours = 0,
    this.sixes = 0,
    this.isStriker = false,
  });

  double get strikeRate => balls > 0 ? (runs / balls) * 100.0 : 0.0;
}

class Bowler {
  String name;
  int ballsBowled;
  int runsConceded;
  int wickets;

  Bowler({
    required this.name,
    this.ballsBowled = 0,
    this.runsConceded = 0,
    this.wickets = 0,
  });

  String get oversFormatted => "${ballsBowled ~/ 6}.${ballsBowled % 6}";
  double get economy => ballsBowled > 0 ? runsConceded / (ballsBowled / 6.0) : 0.0;
}

class CricPrismApp extends StatelessWidget {
  const CricPrismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CricPrism Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const CricPrismEngineView(),
    );
  }
}

class CricPrismEngineView extends StatefulWidget {
  const CricPrismEngineView({super.key});

  @override
  State<CricPrismEngineView> createState() => _CricPrismEngineViewState();
}

class _CricPrismEngineViewState extends State<CricPrismEngineView> {
  AppMode _currentMode = AppMode.match;
  CameraController? _cameraController;
  final FlutterTts _flutterTts = FlutterTts();

  // Metrics
  double _releaseSpeed = 138.4;
  String _pitchLength = "Good Length";
  double _swingDeg = 1.8;
  int _coachScore = 88;

  // Hawk-Eye
  List<TrajectoryPoint> _trajectory = [];

  // Match State
  int _totalRuns = 194;
  int _wickets = 3;
  int _legalBalls = 114;
  List<String> _timeline = ['0', '1', '4', '1', '2'];

  late Batsman _striker;
  late Batsman _nonStriker;
  late Bowler _bowler;

  // Banner
  bool _showBanner = false;
  String _bannerTitle = "";
  String _bannerSubtitle = "";

  @override
  void initState() {
    super.initState();
    _striker = Batsman(name: 'V. Kohli', runs: 74, balls: 48, fours: 8, sixes: 2, isStriker: true);
    _nonStriker = Batsman(name: 'H. Pandya', runs: 36, balls: 21, fours: 3, sixes: 1, isStriker: false);
    _bowler = Bowler(name: 'M. Starc', ballsBowled: 24, runsConceded: 41, wickets: 2);

    _initCamera();
    _initTts();
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    try {
      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setSpeechRate(0.85);
      await _flutterTts.setVolume(1.0);
      _speak("CricPrism Pro Engine Ready");
    } catch (_) {}
  }

  void _speak(String txt) async {
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(txt);
    } catch (_) {}
  }

  void _swapStrike() {
    final temp = _striker;
    _striker = _nonStriker;
    _nonStriker = temp;
    _striker.isStriker = true;
    _nonStriker.isStriker = false;
  }

  void _triggerDelivery(String outcome) {
    final rnd = math.Random();
    _releaseSpeed = 122.0 + rnd.nextInt(26) + rnd.nextDouble();
    _swingDeg = 0.5 + rnd.nextDouble() * 2.5;

    List<String> lengths = ["Yorker", "Full Length", "Good Length", "Short Pitch", "Bouncer"];
    _pitchLength = lengths[rnd.nextInt(lengths.length)];
    _coachScore = 65 + rnd.nextInt(32);

    _trajectory.clear();
    for (int i = 0; i < 9; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (!mounted) return;
        setState(() {
          _trajectory.add(TrajectoryPoint(
            position: Offset(110.0 + (i * 44), 160.0 - math.sin(i * 0.42) * 40),
            timestamp: i * 0.05,
            isBounce: i == 4,
          ));
        });
      });
    }

    setState(() {
      _legalBalls++;
      _striker.balls++;
      _bowler.ballsBowled++;
      _timeline.add(outcome);

      if (outcome == "6") {
        _totalRuns += 6;
        _striker.runs += 6;
        _striker.sixes++;
        _bowler.runsConceded += 6;
        double dist = 85.0 + rnd.nextInt(30);
        _bannerTitle = "💥 MAXIMUM 💥";
        _bannerSubtitle = "${dist.toStringAsFixed(0)} METERS PROJECTED";
        _showBanner = true;
        _speak("Huge Six! ${dist.toStringAsFixed(0)} meters");
      } else if (outcome == "4") {
        _totalRuns += 4;
        _striker.runs += 4;
        _striker.fours++;
        _bowler.runsConceded += 4;
        _bannerTitle = "⚡ BOUNDARY FOUR ⚡";
        _bannerSubtitle = "SWEET SPOT TIMING";
        _showBanner = true;
        _speak("Four runs off a $_pitchLength delivery");
      } else if (outcome == "W") {
        _wickets++;
        _bowler.wickets++;
        _bannerTitle = "🔴 WICKET DOWN 🔴";
        _bannerSubtitle = "STUMPS DISTURBED";
        _showBanner = true;
        _speak("Clean bowled at ${_releaseSpeed.toStringAsFixed(0)} kph");
        _striker = Batsman(name: "Batter ${_wickets + 2}", isStriker: true);
      } else {
        int r = int.tryParse(outcome) ?? 0;
        _totalRuns += r;
        _striker.runs += r;
        _bowler.runsConceded += r;
        if (r == 0) {
          _speak("Dot ball. Speed ${_releaseSpeed.toStringAsFixed(0)} kph");
        } else {
          _speak("$r run taken.");
        }
        if (r % 2 != 0) _swapStrike();
      }

      if (_legalBalls % 6 == 0) {
        _swapStrike();
        _speak("End of over. Strike changed.");
      }
    });

    if (_showBanner) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showBanner = false);
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? sz.width,
                  height: _cameraController!.value.previewSize?.width ?? sz.height,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),

          // 2. HawkEye Tracer
          CustomPaint(
            size: Size.infinite,
            painter: HawkEyeAdvancedPainter(points: _trajectory),
          ),

          // 3. Stumps Target Box
          Center(
            child: Container(
              width: 140,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 32,
                  color: Colors.redAccent.withOpacity(0.4),
                  alignment: Alignment.center,
                  child: const Text("TARGET STUMPS", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),

          // 4. Mode Switcher
          Positioned(
            top: 12,
            right: 80,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  _modeButton("MATCH", AppMode.match),
                  _modeButton("PRACTICE", AppMode.practice),
                ],
              ),
            ),
          ),

          // 5. Telemetry Top Left
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8
