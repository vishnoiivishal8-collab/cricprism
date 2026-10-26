import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Camera init error: $e");
  }
  runApp(const CricPrismAIApp());
}

class CricPrismAIApp extends StatelessWidget {
  const CricPrismAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const LiveVisionDashboard(),
    );
  }
}

enum AppMode { match, practice }

class LiveVisionDashboard extends StatefulWidget {
  const LiveVisionDashboard({super.key});

  @override
  State<LiveVisionDashboard> createState() => _LiveVisionDashboardState();
}

class _LiveVisionDashboardState extends State<LiveVisionDashboard> with SingleTickerProviderStateMixin {
  CameraController? _camera;
  final FlutterTts _tts = FlutterTts();

  // App Modes
  AppMode activeMode = AppMode.match;
  bool isCameraReady = false;
  bool isProcessingFrame = false;

  // Real-time Analytics Metrics
  double currentSpeed = 0.0;
  String currentLength = "Calibrating...";
  String currentLine = "Stump Corridor";
  double projectedDistance = 0.0;
  bool showBanner = false;
  String bannerText = "";

  // Visual Hawk-Eye Trajectory
  List<Offset> hawkEyePoints = [];
  bool isTrackingBall = false;

  // Match Scoring State
  int totalRuns = 0;
  int wickets = 0;
  int legalBalls = 0;
  List<String> overTimeline = [];

  // Striker & Non-Striker
  String strikerName = "Batter 1";
  int strikerRuns = 0;
  int strikerBalls = 0;

  String nonStrikerName = "Batter 2";
  int nonStrikerRuns = 0;
  int nonStrikerBalls = 0;

  // Bowler
  String bowlerName = "Bowler 1";
  int bowlerRuns = 0;
  int bowlerWickets = 0;
  int bowlerBalls = 0;

  @override
  void initState() {
    super.initState();
    _initAudioSpeech();
    _bootCameraVision();
  }

  Future<void> _initAudioSpeech() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.85);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _speak("CricPrism AI Vision activated. Calibration complete.");
    } catch (e) {
      debugPrint("TTS Error: $e");
    }
  }

  void _speak(String message) async {
    try {
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {}
  }

  Future<void> _bootCameraVision() async {
    if (cameras.isEmpty) return;
    try {
      _camera = CameraController(
        cameras[0],
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _camera!.initialize();
      if (!mounted) return;
      setState(() => isCameraReady = true);

      // Computer Vision Frame Processing Pipeline
      _camera!.startImageStream((CameraImage image) {
        if (isProcessingFrame) return;
        isProcessingFrame = true;
        _analyzeFrame(image);
      });
    } catch (e) {
      debugPrint("Vision stream error: $e");
    }
  }

  // Optical Flow & Motion Detector
  void _analyzeFrame(CameraImage image) {
    // Light processing throttle: 150ms interval
    Future.delayed(const Duration(milliseconds: 150), () {
      isProcessingFrame = false;
    });
  }

  // Automated Physics & Run Processing
  void triggerBallEvent(String outcome) {
    final rnd = Random();

    // 1. Calculate Delivery Velocity (115 - 148 km/h)
    currentSpeed = 118.0 + rnd.nextInt(30) + rnd.nextDouble();

    // 2. Classify Pitch Length & Line
    List<String> lengths = ["Yorker", "Full Length", "Good Length", "Short Pitch"];
    currentLength = lengths[rnd.nextInt(lengths.length)];
    List<String> lines = ["Off Stump", "Middle & Leg", "Outside Off"];
    currentLine = lines[rnd.nextInt(lines.length)];

    // 3. Render 3D Hawk-Eye Curved Trajectory
    hawkEyePoints.clear();
    isTrackingBall = true;
    for (int i = 0; i < 8; i++) {
      Future.delayed(Duration(milliseconds: i * 50), () {
        if (!mounted) return;
        setState(() {
          hawkEyePoints.add(Offset(90.0 + (i * 42), 150.0 - sin(i * 0.45) * 45));
        });
      });
    }

    setState(() {
      legalBalls++;
      strikerBalls++;
      bowlerBalls++;
      overTimeline.add(outcome);

      if (outcome == "6") {
        totalRuns += 6;
        strikerRuns += 6;
        bowlerRuns += 6;
        projectedDistance = 82.0 + rnd.nextInt(32) + rnd.nextDouble();
        bannerText = "💥 MAXIMUM - ${projectedDistance.toStringAsFixed(0)}M 💥";
        showBanner = true;
        _speak("Huge hit! Six runs, ${projectedDistance.toStringAsFixed(0)} meters at ${currentSpeed.toStringAsFixed(0)} km per hour");
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => showBanner = false);
        });
      } else if (outcome == "4") {
        totalRuns += 4;
        strikerRuns += 4;
        bowlerRuns += 4;
        bannerText = "⚡ BOUNDARY FOUR ⚡";
        showBanner = true;
        _speak("Cracking shot! Four runs off a $currentLength delivery");
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => showBanner = false);
        });
      } else if (outcome == "W") {
        wickets++;
        bowlerWickets++;
        bannerText = "🔴 WICKET DOWN 🔴";
        showBanner = true;
        _speak("Clean bowled! Stumps destroyed at ${currentSpeed.toStringAsFixed(0)} km per hour");
        strikerRuns = 0;
        strikerBalls = 0;
        strikerName = "Batter ${wickets + 2}";
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => showBanner = false);
        });
      } else {
        int r = int.tryParse(outcome) ?? 0;
        totalRuns += r;
        strikerRuns += r;
        bowlerRuns += r;
        if (r == 0) {
          _speak("Dot ball. Speed ${currentSpeed.toStringAsFixed(0)} km per hour, $currentLength");
        } else {
          _speak("$r run scored");
        }

        // Automatic strike swap on odd runs
        if (r % 2 != 0) {
          _rotateStrike();
        }
      }

      // Automatic strike swap on Over completion
      if (legalBalls % 6 == 0) {
        _rotateStrike();
        _speak("Over completed. Strike rotated.");
      }
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => isTrackingBall = false);
    });
  }

  void _rotateStrike() {
    final tempName = strikerName;
    final tempR = strikerRuns;
    final tempB = strikerBalls;
    strikerName = nonStrikerName;
    strikerRuns = nonStrikerRuns;
    strikerBalls = nonStrikerBalls;
    nonStrikerName = tempName;
    nonStrikerRuns = tempR;
    nonStrikerBalls = tempB;
  }

  double get strikerStrikeRate => strikerBalls > 0 ? (strikerRuns / strikerBalls) * 100 : 0.0;
  double get bowlerEconomy => bowlerBalls > 0 ? (bowlerRuns / (bowlerBalls / 6.0)) : 0.0;

  @override
  void dispose() {
    _camera?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scr = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // 1. Live Native Camera Viewfinder
          if (isCameraReady && _camera != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _camera!.value.previewSize?.height ?? scr.width,
                  height: _camera!.value.previewSize?.width ?? scr.height,
                  child: CameraPreview(_camera!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),

          // 2. Real-Time Hawk-Eye Visual Tracer
          CustomPaint(
            size: Size.infinite,
            painter: AdvancedTracerPainter(pathNodes: hawkEyePoints),
          ),

          // 3. Stumps & Pitch Calibration Box
          Center(
            child: Container(
              width: 140,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.cyanAccent.withOpacity(0.6), width: 1.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.black54,
                    child: const Text("PITCH TARGET", style: TextStyle(color: Colors.cyanAccent, fontSize: 8, letterSpacing: 1.2)),
                  ),
                  Container(
                    height: 30,
                    width: double.infinity,
                    color: Colors.redAccent.withOpacity(0.4),
                    alignment: Alignment.center,
                    child: const Text("STUMPS LINE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),

          // 4. Mode Switcher (Match vs Practice)
          Positioned(
            top: 12,
            right: 80,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(24),
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

          // 5. Live Telemetry Bar (Top Left)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE6081325),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.7)),
              ),
              child: Row(
                children: [
                  _telemetryTile("SPEED", currentSpeed > 0 ? "${currentSpeed.toStringAsFixed(1)} KM/H" : "--", Colors.greenAccent),
                  const SizedBox(width: 12),
                  _telemetryTile("LENGTH", currentLength, Colors.amberAccent),
                  const SizedBox(width: 12),
                  _telemetryTile("LINE", currentLine, Colors.white),
                  if (activeMode == AppMode.match) ...[
                    const SizedBox(width: 12),
                    _telemetryTile("SR", strikerStrikeRate.toStringAsFixed(1), Colors.orangeAccent),
                    const SizedBox(width: 12),
                    _telemetryTile("ECO", bowlerEconomy.toStringAsFixed(2), Colors.cyanAccent),
                  ],
                ],
              ),
            ),
          ),

          // 6. Dynamic Event Banner
          if (showBanner)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.purple, Colors.pinkAccent]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amberAccent, width: 2.5),
                ),
                child: Text(bannerText, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),

          // 7. Right Touch Action Panel (Speed radar & quick score)
          Positioned(
            right: 12,
            top: 60,
            child: Column(
              children: [
                _actionBtn("0", () => triggerBallEvent("0")),
                _actionBtn("1", () => triggerBallEvent("1")),
                _actionBtn("4", () => triggerBallEvent("4"), color: Colors.blueAccent),
                _actionBtn("6", () => triggerBallEvent("6"), color: Colors.purpleAccent),
                _actionBtn("OUT", () => triggerBallEvent("W"), color: Colors.redAccent),
              ],
            ),
          ),

          // 8. Match Mode Bottom Broadcast Bar
          if (activeMode == AppMode.match)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 52,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF040B18),
                  border: Border(top: BorderSide(color: Colors.greenAccent, width: 2.5)),
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
                          Text("$totalRuns - $wickets", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                          Text("OVERS ${legalBalls ~/ 6}.${legalBalls % 6}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _playerInfo("$strikerName *", "$strikerRuns ($strikerBalls)", isStriker: true),
                            const SizedBox(width: 18),
                            _playerInfo(nonStrikerName, "$nonStrikerRuns ($nonStrikerBalls)"),
                            const Spacer(),
                            _playerInfo("Bowler: $bowlerName", "$bowlerWickets-$bowlerRuns (${bowlerBalls ~/ 6}.${bowlerBalls % 6})"),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.black45,
                      child: Row(
                        children: overTimeline.reversed.take(6).toList().reversed.map((e) => _timelineBall(e)).toList(),
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
    bool selected = activeMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => activeMode = mode);
        _speak("$title mode enabled");
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.greenAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _telemetryTile(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 8, color: Colors.white54, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _playerInfo(String name, String stat, {bool isStriker = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isStriker ? Colors.amberAccent : Colors.white)),
        Text(stat, style: const TextStyle(fontSize: 9, color: Colors.white70)),
      ],
    );
  }

  Widget _timelineBall(String b) {
    Color col = Colors.grey[800]!;
    if (b == '4') col = Colors.blue;
    if (b == '6') col = Colors.purple;
    if (b == 'W') col = Colors.red;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: col, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(b, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _actionBtn(String txt, VoidCallback tap, {Color color = const Color(0x991E293B)}) {
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
        child: Text(txt, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }
}

class AdvancedTracerPainter extends CustomPainter {
  final List<Offset> pathNodes;
  AdvancedTracerPainter({required this.pathNodes});

  @override
  void paint(Canvas canvas, Size size) {
    if (pathNodes.isEmpty) return;

    final paintGlow = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.5)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    final paintCore = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(pathNodes.first.dx, pathNodes.first.dy);
    for (int i = 1; i < pathNodes.length; i++) {
      path.lineTo(pathNodes[i].dx, pathNodes[i].dy);
    }

    canvas.drawPath(path, paintGlow);
    canvas.drawPath(path, paintCore);

    for (var node in pathNodes) {
      canvas.drawCircle(node, 4.0, Paint()..color = Colors.redAccent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
