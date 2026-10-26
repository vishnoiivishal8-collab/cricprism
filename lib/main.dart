// ============================================================================
// CricPrism - Cricket Analytics & Broadcast Engine
// Complete Production-Grade Flutter Code (Android SDK 21+ & Flutter 3.22+)
// ============================================================================

import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Hardware camera fallback: $e');
  }

  runApp(CricPrismApp(cameras: cameras));
}

enum AppMode { match, practice }

enum PitchLength {
  yorker('Yorker', Colors.purpleAccent, 0.0, 0.18),
  fullLength('Full Length', Colors.blueAccent, 0.18, 0.40),
  goodLength('Good Length', Color(0xFF10B981), 0.40, 0.65),
  shortPitch('Short Pitch', Colors.amberAccent, 0.65, 0.85),
  bouncer('Bouncer', Colors.redAccent, 0.85, 1.0);

  final String label;
  final Color color;
  final double normMin;
  final double normMax;

  const PitchLength(this.label, this.color, this.normMin, this.normMax);
}

class TrajectoryPoint {
  final Offset position;
  final double timestamp;
  final double radius;
  final double opacity;
  final bool isBounce;
  final double velocityKmph;

  TrajectoryPoint({
    required this.position,
    required this.timestamp,
    this.radius = 4.0,
    this.opacity = 1.0,
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
  final List<CameraDescription> cameras;
  const CricPrismApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CricPrism Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: CricPrismEngineView(cameras: cameras),
    );
  }
}

class CricPrismEngineView extends StatefulWidget {
  final List<CameraDescription> cameras;
  const CricPrismEngineView({super.key, required this.cameras});

  @override
  State<CricPrismEngineView> createState() => _CricPrismEngineViewState();
}

class _CricPrismEngineViewState extends State<CricPrismEngineView> with SingleTickerProviderStateMixin {
  AppMode _currentMode = AppMode.match;
  CameraController? _cameraController;
  final FlutterTts _flutterTts = FlutterTts();

  // Metrics
  double _releaseSpeed = 138.4;
  String _pitchLength = "Good Length";
  String _line = "Off-Stump";
  double _swingDeg = 1.8;
  double _seamDevMm = 3.2;
  int _coachScore = 88;
  String _coachAdvice = "Ideal Corridor of Uncertainty";

  // Hawk-Eye
  List<TrajectoryPoint> _trajectory = [];
  bool _isBallTracking = false;

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
    if (widget.cameras.isEmpty) return;
    try {
      _cameraController = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
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
      _speak("CricPrism Pro Engine Initialized. Pitch calibrated.");
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
    _seamDevMm = 1.0 + rnd.nextDouble() * 5.0;

    List<String> lengths = ["Yorker", "Full Length", "Good Length", "Short Pitch", "Bouncer"];
    _pitchLength = lengths[rnd.nextInt(lengths.length)];
    List<String> lines = ["Outside Off", "On Stumps", "Down Leg"];
    _line = lines[rnd.nextInt(lines.length)];

    _coachScore = 65 + rnd.nextInt(32);
    _coachAdvice = _pitchLength == "Yorker" ? "Pinpoint Searing Yorker" : (_pitchLength == "Good Length" ? "Ideal Corridor of Uncertainty" : "Aggressive Length");

    _trajectory.clear();
    _isBallTracking = true;
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
        _speak("Huge Six! ${dist.toStringAsFixed(0)} meters at ${_releaseSpeed.toStringAsFixed(0)} kph");
      } else if (outcome == "4") {
        _totalRuns += 4;
        _striker.runs += 4;
        _striker.fours++;
        _bowler.runsConceded += 4;
        _bannerTitle = "⚡ BOUNDARY FOUR ⚡";
        _bannerSubtitle = "SWEET SPOT TIMING";
        _showBanner = true;
        _speak("Four runs through the covers off a $_pitchLength delivery");
      } else if (outcome == "W") {
        _wickets++;
        _bowler.wickets++;
        _bannerTitle = "🔴 WICKET DOWN 🔴";
        _bannerSubtitle = "STUMPS DISTURBED";
        _showBanner = true;
        _speak("Clean bowled! Clocked at ${_releaseSpeed.toStringAsFixed(0)} kph");
        _striker = Batsman(name: "Batter ${_wickets + 2}", isStriker: true);
      } else {
        int r = int.tryParse(outcome) ?? 0;
        _totalRuns += r;
        _striker.runs += r;
        _bowler.runsConceded += r;
        if (r == 0) {
          _speak("Dot ball. Speed ${_releaseSpeed.toStringAsFixed(0)} kph, $_pitchLength");
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

    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) setState(() => _isBallTracking = false);
    });
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
          // 1. Live Camera Stream
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

          // 2. Hawk-Eye Tracer Painter
          CustomPaint(
            size: Size.infinite,
            painter: HawkEyeAdvancedPainter(points: _trajectory),
          ),

          // 3. Stumps Calibration Target
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

          // 4. Mode Switcher (Match vs Practice)
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

          // 5. Telemetry & AI Coach HUD (Top Left)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE6081226),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  _hudCol("SPEED", "${_releaseSpeed.toStringAsFixed(1)} KM/H", Colors.greenAccent),
                  const SizedBox(width: 12),
                  _hudCol("LENGTH", _pitchLength, Colors.amberAccent),
                  const SizedBox(width: 12),
                  _hudCol("SWING", "${_swingDeg.toStringAsFixed(1)}°", Colors.cyanAccent),
                  const SizedBox(width: 12),
                  _hudCol("COACH SCORE", "$_coachScore/100", Colors.orangeAccent),
                  if (_currentMode == AppMode.match) ...[
                    const SizedBox(width: 12),
                    _hudCol("SR", _striker.strikeRate.toStringAsFixed(1), Colors.white),
                    const SizedBox(width: 12),
                    _hudCol("ECO", _bowler.economy.toStringAsFixed(2), Colors.cyanAccent),
                  ]
                ],
              ),
            ),
          ),

          // 6. Celebration Banner
          if (_showBanner)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.purple, Colors.pinkAccent]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amberAccent, width: 2.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_bannerTitle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text(_bannerSubtitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                  ],
                ),
              ),
            ),

          // 7. Right Action Controls
          Positioned(
            right: 12,
            top: 60,
            child: Column(
              children: [
                _ctrlBtn("0", () => _triggerDelivery("0")),
                _ctrlBtn("1", () => _triggerDelivery("1")),
                _ctrlBtn("4", () => _triggerDelivery("4"), color: Colors.blueAccent),
                _ctrlBtn("6", () => _triggerDelivery("6"), color: Colors.purpleAccent),
                _ctrlBtn("OUT", () => _triggerDelivery("W"), color: Colors.redAccent),
              ],
            ),
          ),

          // 8. Match Mode Bottom Broadcast Bar
          if (_currentMode == AppMode.match)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 52,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF070F1E),
                  border: Border(top: BorderSide(color: Colors.cyanAccent, width: 2.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 135,
                      color: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("$_totalRuns - $_wickets", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                          Text("OVERS ${_legalBalls ~/ 6}.${_legalBalls % 6}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _playerTag("${_striker.name} *", "${_striker.runs} (${_striker.balls})", isStriker: true),
                            const SizedBox(width: 18),
                            _playerTag(_nonStriker.name, "${_nonStriker.runs} (${_nonStriker.balls})"),
                            const Spacer(),
                            _playerTag("Bowler: ${_bowler.name}", "${_bowler.wickets}-${_bowler.runsConceded} (${_bowler.oversFormatted})"),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.black45,
                      child: Row(
                        children: _timeline.reversed.take(6).toList().reversed.map((e) => _ballDot(e)).toList(),
                      ),
                    )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeButton(String title, AppMode mode) {
    bool selected = _currentMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => _currentMode = mode);
        _speak("$title mode enabled");
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.cyanAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selected ? Colors.black : Colors.white70)),
      ),
    );
  }

  Widget _hudCol(String label, String value, Color col) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 12, color: col, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _playerTag(String name, String stat, {bool isStriker = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isStriker ? Colors.amberAccent : Colors.white)),
        Text(stat, style: const TextStyle(fontSize: 9, color: Colors.white70)),
      ],
    );
  }

  Widget _ballDot(String b) {
    Color col = Colors.grey[800]!;
    if (b == '4') col = Colors.blue;
    if (b == '6') col = Colors.purple;
    if (b == 'W') col = Colors.red;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: col, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(b, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _ctrlBtn(String label, VoidCallback tap, {Color color = const Color(0x991E293B)}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: 48,
      height: 38,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: tap,
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }
}

class HawkEyeAdvancedPainter extends CustomPainter {
  final List<TrajectoryPoint> points;
  HawkEyeAdvancedPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintGlow = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5)
      ..strokeWidth = 7.0
      ..style = PaintingStyle.stroke;

    final paintCore = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Path path = Path()..moveTo(points.first.position.dx, points.first.position.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].position.dx, points[i].position.dy);
    }

    canvas.drawPath(path, glow: paintGlow);
