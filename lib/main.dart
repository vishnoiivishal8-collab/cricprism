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
    debugPrint("Camera error: $e");
  }
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CricPrismPro(),
  ));
}

enum AppMode { match, practice }

class CricPrismPro extends StatefulWidget {
  const CricPrismPro({super.key});
  @override
  State<CricPrismPro> createState() => _CricPrismProState();
}

class _CricPrismProState extends State<CricPrismPro> {
  CameraController? _camera;
  final FlutterTts _tts = FlutterTts();
  AppMode currentMode = AppMode.match;

  // Match Engine Data
  int totalRuns = 0;
  int totalWickets = 0;
  int legalBalls = 0;
  List<String> currentOverTimeline = [];

  // Batsmen Data
  String strikerName = "Virat";
  int strikerRuns = 0;
  int strikerBalls = 0;

  String nonStrikerName = "Rohit";
  int nonStrikerRuns = 0;
  int nonStrikerBalls = 0;

  // Bowler Data
  String bowlerName = "Bumrah";
  int bowlerRuns = 0;
  int bowlerWkts = 0;
  int bowlerBalls = 0;

  // Analytics Metrics
  double deliverySpeed = 138.4;
  String deliveryLength = "Good Length";
  String deliveryLine = "Off-Stump";
  double sixDistance = 0.0;
  bool isBallActive = false;
  bool showSixBanner = false;

  // Visual Hawk-Eye Points
  List<Offset> trajectory = [];

  @override
  void initState() {
    super.initState();
    _initTTS();
    _initCamera();
  }

  Future<void> _initTTS() async {
    await _tts.setLanguage("en-US");
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.85);
    await _tts.setVolume(1.0);
    _speak("CricPrism Match and Practice Engine ready");
  }

  Future<void> _initCamera() async {
    if (cameras.isNotEmpty) {
      _camera = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
      await _camera!.initialize();
      if (mounted) setState(() {});
    }
  }

  void _speak(String txt) async {
    await _tts.stop();
    await _tts.speak(txt);
  }

  // Auto Strike Rotation
  void _swapStrike() {
    final tName = strikerName;
    final tR = strikerRuns;
    final tB = strikerBalls;
    strikerName = nonStrikerName;
    strikerRuns = nonStrikerRuns;
    strikerBalls = nonStrikerBalls;
    nonStrikerName = tName;
    nonStrikerRuns = tR;
    nonStrikerBalls = tB;
  }

  // Automatic Ball Process & Trajectory Calculation
  void _processBall(String event) {
    final rnd = Random();
    deliverySpeed = 125.0 + rnd.nextInt(25) + rnd.nextDouble();
    List<String> lengths = ["Yorker", "Full Length", "Good Length", "Short Pitch"];
    deliveryLength = lengths[rnd.nextInt(lengths.length)];
    List<String> lines = ["Outside Off", "On Stumps", "Down Leg"];
    deliveryLine = lines[rnd.nextInt(lines.length)];

    // Simulate Hawk-Eye Curve
    trajectory.clear();
    for (int i = 0; i < 7; i++) {
      Future.delayed(Duration(milliseconds: i * 60), () {
        if (!mounted) return;
        setState(() {
          trajectory.add(Offset(100.0 + (i * 40), 160.0 - sin(i * 0.4) * 35));
        });
      });
    }

    setState(() {
      isBallActive = true;
      legalBalls++;
      strikerBalls++;
      bowlerBalls++;
      currentOverTimeline.add(event);

      if (event == "6") {
        totalRuns += 6;
        strikerRuns += 6;
        bowlerRuns += 6;
        sixDistance = 80.0 + rnd.nextInt(30) + rnd.nextDouble();
        showSixBanner = true;
        _speak("Massive hit! Six runs, ${sixDistance.toStringAsFixed(0)} meters at ${deliverySpeed.toStringAsFixed(0)} kph");
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => showSixBanner = false);
        });
      } else if (event == "4") {
        totalRuns += 4;
        strikerRuns += 4;
        bowlerRuns += 4;
        _speak("Boundary! Four runs off a $deliveryLength delivery");
      } else if (event == "W") {
        totalWickets++;
        bowlerWkts++;
        _speak("Wicket! Clean bowled at ${deliverySpeed.toStringAsFixed(0)} kph");
        strikerRuns = 0;
        strikerBalls = 0;
        strikerName = "Batter ${totalWickets + 2}";
      } else {
        int r = int.tryParse(event) ?? 0;
        totalRuns += r;
        strikerRuns += r;
        bowlerRuns += r;
        if (r == 0) {
          _speak("Dot ball. Speed ${deliverySpeed.toStringAsFixed(0)} kph, $deliveryLength");
        } else {
          _speak("$r run taken.");
        }
        // Auto strike change on odd runs
        if (r % 2 != 0) {
          _swapStrike();
        }
      }

      // Auto strike change at over end
      if (legalBalls % 6 == 0) {
        _swapStrike();
        _speak("End of over. Strike changed.");
      }
    });

    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => isBallActive = false);
    });
  }

  // Math Calculations
  double get strikeRate => strikerBalls > 0 ? (strikerRuns / strikerBalls) * 100 : 0.0;
  double get economy => bowlerBalls > 0 ? (bowlerRuns / (bowlerBalls / 6.0)) : 0.0;

  @override
  void dispose() {
    _camera?.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Live Stream
          if (_camera != null && _camera!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _camera!.value.previewSize?.height ?? sz.width,
                  height: _camera!.value.previewSize?.width ?? sz.height,
                  child: CameraPreview(_camera!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),

          // 2. Hawk-Eye Tracer
          CustomPaint(size: Size.infinite, painter: PathTracer(points: trajectory)),

          // 3. Stumps Alignment Target
          Center(
            child: Container(
              width: 140,
              height: 230,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent.withOpacity(0.5), width: 2),
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

          // 4. Mode Switcher (Top Right Bar)
          Positioned(
            top: 10,
            right: 80,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  _modeTab("MATCH", AppMode.match),
                  _modeTab("PRACTICE", AppMode.practice),
                ],
              ),
            ),
          ),

          // 5. Telemetry HUD (Speed, Length, Line)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xE60A1128),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.6)),
              ),
              child: Row(
                children: [
                  _hudItem("SPEED", "${deliverySpeed.toStringAsFixed(1)} KM/H", Colors.greenAccent),
                  const SizedBox(width: 12),
                  _hudItem("LENGTH", deliveryLength, Colors.amberAccent),
                  const SizedBox(width: 12),
                  _hudItem("LINE", deliveryLine, Colors.white),
                  if (currentMode == AppMode.match) ...[
                    const SizedBox(width: 12),
                    _hudItem("ECONOMY", economy.toStringAsFixed(2), Colors.cyanAccent),
                    const SizedBox(width: 12),
                    _hudItem("STRIKE RATE", strikeRate.toStringAsFixed(1), Colors.orangeAccent),
                  ]
                ],
              ),
            ),
          ),

          // 6. Maximum Celebration Card
          if (showSixBanner)
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.purple, Colors.pinkAccent]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber, width: 3),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text("💥 6 MAXIMUM 💥", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text("PROJECTED: ${sixDistance.toStringAsFixed(1)} METERS", style: const TextStyle(fontSize: 16, color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          // 7. Right Controls (Scoring & Ball Pitch Trigger)
          Positioned(
            right: 12,
            top: 60,
            child: Column(
              children: [
                _ctrlBtn("0", () => _processBall("0")),
                _ctrlBtn("1", () => _processBall("1")),
                _ctrlBtn("4", () => _processBall("4"), color: Colors.blueAccent),
                _ctrlBtn("6", () => _processBall("6"), color: Colors.purpleAccent),
                _ctrlBtn("OUT", () => _processBall("W"), color: Colors.redAccent),
              ],
            ),
          ),

          // 8. Match Mode Bottom Broadcast Banner
          if (currentMode == AppMode.match)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 52,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF070F1E),
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
                          Text("$totalRuns - $totalWickets", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                          Text("OVERS ${legalBalls ~/ 6}.${legalBalls % 6}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _playerTag("$strikerName *", "$strikerRuns ($strikerBalls)", isStriker: true),
                            const SizedBox(width: 18),
                            _playerTag(nonStrikerName, "$nonStrikerRuns ($nonStrikerBalls)"),
                            const Spacer(),
                            _playerTag("Bowler: $bowlerName", "$bowlerWkts-$bowlerRuns (${bowlerBalls ~/ 6}.${bowlerBalls % 6})"),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      color: Colors.black45,
                      child: Row(
                        children: currentOverTimeline.reversed.take(6).toList().reversed.map((e) => _ballChip(e)).toList(),
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

  Widget _modeTab(String title, AppMode mode) {
    bool active = currentMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() => currentMode = mode);
        _speak("$title mode activated");
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.greenAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: active ? Colors.black : Colors.white70)),
      ),
    );
  }

  Widget _hudItem(String label, String value, Color col) {
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

  Widget _ballChip(String e) {
    Color bg = Colors.grey[800]!;
    if (e == '4') bg = Colors.blue;
    if (e == '6') bg = Colors.purple;
    if (e == 'W') bg = Colors.red;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 20,
      height: 20,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(e, style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _ctrlBtn(String label, VoidCallback tap, {Color color = const Color(0x991E293B)}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: 46,
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

class PathTracer extends CustomPainter {
  final List<Offset> points;
  PathTracer({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = Colors.amberAccent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..color = Colors.amber.withOpacity(0.4)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke;

    Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, glow);
    canvas.drawPath(path, paint);

    for (var pt in points) {
      canvas.drawCircle(pt, 4.0, Paint()..color = Colors.redAccent);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
