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
  runApp(const CricPrismApp());
}

class CricPrismApp extends StatelessWidget {
  const CricPrismApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CricPrismDashboard(),
    );
  }
}

class CricPrismDashboard extends StatefulWidget {
  const CricPrismDashboard({super.key});
  @override
  State<CricPrismDashboard> createState() => _CricPrismDashboardState();
}

class _CricPrismDashboardState extends State<CricPrismDashboard> {
  CameraController? _cameraController;
  final FlutterTts _tts = FlutterTts();

  int runs = 0;
  int wickets = 0;
  int legalBalls = 0;
  List<String> recentBalls = [];
  String strikerName = "Batsman 1";
  int strikerRuns = 0;
  int strikerBalls = 0;
  String nonStrikerName = "Batsman 2";
  int nonStrikerRuns = 0;
  int nonStrikerBalls = 0;
  String bowlerName = "Bowler 1";
  int bowlerRuns = 0;
  int bowlerWkts = 0;
  int bowlerBalls = 0;
  double lastSpeed = 132.4;
  String lastLength = "Good Length";
  String lastZone = "Straight";
  double lastSixDist = 0.0;
  bool showSixBanner = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initTTS();
  }

  Future<void> _initCamera() async {
    if (cameras.isNotEmpty) {
      _cameraController = CameraController(cameras[0], ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      if (mounted) setState(() {});
    }
  }

  void _initTTS() {
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.9);
  }

  void _speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  void _handleScore(String event) {
    setState(() {
      legalBalls++;
      strikerBalls++;
      bowlerBalls++;
      recentBalls.add(event);

      if (event == '6') {
        runs += 6;
        strikerRuns += 6;
        bowlerRuns += 6;
        lastSixDist = 84.0 + (legalBalls % 20) * 1.3;
        List<String> zones = ["Deep Mid-Wicket", "Long-On", "Long-Off", "Square Leg"];
        lastZone = zones[legalBalls % zones.length];
        showSixBanner = true;
        _speak("Huge Six, ${lastSixDist.toStringAsFixed(1)} meters towards$lastZone");
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => showSixBanner = false);
        });
      } else if (event == '4') {
        runs += 4;
        strikerRuns += 4;
        bowlerRuns += 4;
        lastZone = "Cover Boundary";
        _speak("Four runs, driven through covers");
      } else if (event == 'W') {
        wickets++;
        bowlerWkts++;
        _speak("Wicket down! Bowler strikes");
        strikerRuns = 0;
        strikerBalls = 0;
        strikerName = "New Batsman";
      } else if (int.tryParse(event) != null) {
        int r = int.parse(event);
        runs += r;
        strikerRuns += r;
        bowlerRuns += r;
        if (r % 2 != 0) _swapStrike();
      }

      if (legalBalls % 6 == 0) {
        _swapStrike();
      }
    });
  }

  void _swapStrike() {
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

  void _triggerPace() {
    List<double> speeds = [128.4, 131.2, 134.5, 122.0, 138.2];
    List<String> lengths = ["Good Length", "Full Yorker", "Short Pitch"];
    setState(() {
      lastSpeed = speeds[legalBalls % speeds.length];
      lastLength = lengths[legalBalls % lengths.length];
    });
    _speak("Delivery speed ${lastSpeed.toStringAsFixed(1)} kilometers per hour, pitched on$lastLength");
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _tts.stop();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? size.width,
                  height: _cameraController!.value.previewSize?.width ?? size.height,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            )
          else
            const Center(child: CircularProgressIndicator(color: Colors.greenAccent)),

          Center(
            child: Container(
              width: 140,
              height: 240,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.bottomCenter,
              child: Container(
                width: 90,
                height: 32,
                color: Colors.redAccent.withOpacity(0.35),
                alignment: Alignment.center,
                child: const Text("STUMP LINE", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
          ),

          Positioned(
            top: 12,
            left: 12,
            child: Row(
              children: [
                _buildTelemetryBox("PACE", "${lastSpeed.toStringAsFixed(1)} KM/H"),
                const SizedBox(width: 8),
                _buildTelemetryBox("LENGTH", lastLength),
                const SizedBox(width: 8),
                _buildTelemetryBox("ZONE", lastZone),
              ],
            ),
          ),

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
                    const Text("💥 MAXIMUM 💥", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text("PROJECTED: ${lastSixDist.toStringAsFixed(1)} METERS", style: const TextStyle(fontSize: 16, color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),

          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                _buildCtrlBtn("0", () => _handleScore("0")),
                _buildCtrlBtn("1", () => _handleScore("1")),
                _buildCtrlBtn("4", () => _handleScore("4"), color: Colors.blueAccent),
                _buildCtrlBtn("6", () => _handleScore("6"), color: Colors.purpleAccent),
                _buildCtrlBtn("W", () => _handleScore("W"), color: Colors.redAccent),
                _buildCtrlBtn("⚡", _triggerPace, color: Colors.teal),
              ],
            ),
          ),

          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 52,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0B132B),
                border: Border(top: BorderSide(color: Colors.greenAccent, width: 3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 125,
                    color: const Color(0xFF0284C7),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("RR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                        Text("$runs-$wickets", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
                        Text("OVERS ${legalBalls ~/ 6}.${legalBalls % 6}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xCC0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildPlayerColumn("$strikerName *", "$strikerRuns ($strikerBalls)", isActive: true),
                          const SizedBox(width: 20),
                          _buildPlayerColumn(nonStrikerName, "$nonStrikerRuns ($nonStrikerBalls)"),
                          const Spacer(),
                          _buildPlayerColumn(bowlerName, "$bowlerWkts-$bowlerRuns (${bowlerBalls ~/ 6}.${bowlerBalls % 6})"),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    color: const Color(0xF2020617),
                    child: Row(
                      children: recentBalls.reversed.take(6).toList().reversed.map((b) => _buildBallCircle(b)).toList(),
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

  Widget _buildTelemetryBox(String title, String val) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD90F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 9, color: Colors.white70)),
          Text(val, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
        ],
      ),
    );
  }

  Widget _buildCtrlBtn(String label, VoidCallback onTap, {Color color = const Color(0x991E293B)}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      width: 44,
      height: 38,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }

  Widget _buildPlayerColumn(String name, String stat, {bool isActive = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? Colors.amberAccent : Colors.white)),
        Text(stat, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }

  Widget _buildBallCircle(String b) {
    Color bg = const Color(0xFF334155);
    if (b == '4') bg = Colors.blue;
    if (b == '6') bg = Colors.purple;
    if (b == 'W') bg = Colors.red;
    return Container(
      margin: const EdgeInsets.only(left: 4),
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(b, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}
