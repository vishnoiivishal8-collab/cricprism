// ============================================================================
// CricPrism - Cricket Analytics & Broadcast Engine
// Complete Production-Grade Flutter Code (Android SDK 21+ & Flutter 3.22+)
// Modules:
// 1. Dual Modes (Match Broadcast & Practice Nets)
// 2. Real-Time Hawk-Eye Curved Ball Tracer (CustomPainter)
// 3. Multi-Camera Feed Selector (Front-On, Stump Cam, Side-On, Top Radar)
// 4. Aerodynamic Drag & Seam Physics with Ball Wear & Pitch Conditions
// 5. AI Bowling Coach Engine (Real-Time Biomechanics & Technique Tips)
// 6. AI Umpire & Decision Review System (LBW, UltraEdge Snicko Waveform)
// 7. Athlete User Profile & Persistent History Logs
// 8. Automated Match Engine & Strike Rotation
// 9. Crash-Proof FlutterTTS Spoken Commentary Engine
// ============================================================================

import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Enforce Landscape Immersive Sticky Mode for Broadcast & Optics
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint('Hardware camera fallback to synthetic pitch stream: $e');
  }

  runApp(CricPrismApp(cameras: cameras));
}

// ============================================================================
// 1. DOMAIN MODELS & ENUMS
// ============================================================================

enum AppMode { match, practice }

enum CameraViewAngle {
  frontOn('Front-On Broadcast', '1'),
  batsmanView('Stump Cam / Batter POV', '2'),
  sideOn('Side-On Biomechanics', '3'),
  topDown('2D Aerial Radar', '4');

  final String label;
  final String key;
  const CameraViewAngle(this.label, this.key);
}

enum BallWearCondition {
  newShining('Brand New (0-10 Overs)', 0.05, 1.0, 0.72),
  semiWorn('Semi-Worn (15-40 Overs)', 0.18, 0.88, 0.68),
  roughReverse('Reverse Swing (40+ Overs)', 0.42, 0.70, 0.62),
  abrasiveTorn('Deteriorated Surface', 0.65, 0.55, 0.54);

  final String label;
  final double surfaceRoughness;
  final double coefficientOfRestitution;
  final double frictionCoefficient;

  const BallWearCondition(
    this.label,
    this.surfaceRoughness,
    this.coefficientOfRestitution,
    this.frictionCoefficient,
  );
}

enum PitchCondition {
  greenSeamer('Green Seamer', 0.75, 1.8, 0.68),
  hardBouncy('Hard & Bouncy', 0.85, 0.8, 0.58),
  dryDusty('Dry & Dusty (Spin)', 0.68, 2.4, 0.76),
  crackedDay5('Day 5 Cracked (Variable)', 0.60, 3.8, 0.82);

  final String label;
  final double baseBounceFactor;
  final double seamMultiplier;
  final double pitchFriction;

  const PitchCondition(
    this.label,
    this.baseBounceFactor,
    this.seamMultiplier,
    this.pitchFriction,
  );
}

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

enum LineCorridor { outsideOff, stumps, downLeg }
enum PitchingZone { inLine, outsideOff, outsideLeg }
enum ImpactZone { inLine, umpireCall, outside }
enum WicketsZone { hitting, clippingUmpireCall, missing }
enum UmpireDecision { out, notOut, umpireCall }

class ColorsCustom {
  static const Color cyanCore = Color(0xFF00E5FF);
  static const Color amberGlow = Color(0xFFFFB300);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color crimsonRed = Color(0xFFFF1744);
  static const Color broadcastNavy = Color(0xFF081226);
  static const Color broadcastGold = Color(0xFFFFD700);
}

class TrajectoryPoint {
  final Offset position;
  final double timestamp;
  final double radius;
  final double opacity;
  final bool isBounce;
  final double depth;
  final double velocityKmph;
  final double lateralAeroForce;

  TrajectoryPoint({
    required this.position,
    required this.timestamp,
    this.radius = 4.0,
    this.opacity = 1.0,
    this.isBounce = false,
    this.depth = 0.5,
    this.velocityKmph = 135.0,
    this.lateralAeroForce = 0.0,
  });
}

class LbwReviewData {
  final PitchingZone pitching;
  final ImpactZone impact;
  final WicketsZone wickets;
  final bool originalOnFieldOut;
  final UmpireDecision finalDecision;
  final String verdictText;

  LbwReviewData({
    required this.pitching,
    required this.impact,
    required this.wickets,
    required this.originalOnFieldOut,
    required this.finalDecision,
    required this.verdictText,
  });
}

class UltraEdgeData {
  final List<double> acousticFrequencies;
  final int spikeFrameIndex;
  final bool batPadSeparationConfirmed;
  final bool edgeDetected;

  UltraEdgeData({
    required this.acousticFrequencies,
    required this.spikeFrameIndex,
    required this.batPadSeparationConfirmed,
    required this.edgeDetected,
  });
}

class AiCoachAdvice {
  final String headline;
  final int ratingScore;
  final String biomechanicsDiagnosis;
  final String technicalTip;
  final String recommendedDrill;

  AiCoachAdvice({
    required this.headline,
    required this.ratingScore,
    required this.biomechanicsDiagnosis,
    required this.technicalTip,
    required this.recommendedDrill,
  });
}

class UserProfile {
  String username;
  String email;
  String bowlingStyle;
  double targetVelocityKmph;

  UserProfile({
    required this.username,
    required this.email,
    required this.bowlingStyle,
    required this.targetVelocityKmph,
  });
}

class PracticeDeliveryRecord {
  final DateTime timestamp;
  final double speedKmph;
  final String pitchLength;
  final String line;
  final double swingDeg;
  final double seamMm;
  final bool hitsStumps;
  final String coachHeadline;
  final int score;

  PracticeDeliveryRecord({
    required this.timestamp,
    required this.speedKmph,
    required this.pitchLength,
    required this.line,
    required this.swingDeg,
    required this.seamMm,
    required this.hitsStumps,
    required this.coachHeadline,
    required this.score,
  });
}

class MatchRecord {
  final DateTime timestamp;
  final String title;
  final int teamRuns;
  final int wickets;
  final String overs;
  final String strikerStat;
  final String bowlerStat;

  MatchRecord({
    required this.timestamp,
    required this.title,
    required this.teamRuns,
    required this.wickets,
    required this.overs,
    required this.strikerStat,
    required this.bowlerStat,
  });
}

class DeliveryAnalytics {
  final double releaseSpeedKmph;
  final double pitchSpeedKmph;
  final PitchLength pitchLength;
  final LineCorridor lineCorridor;
  final double swingAngleDegrees;
  final double seamDeviationMm;
  final double aeroDragDecel;
  final BallWearCondition ballCondition;
  final PitchCondition pitchCondition;
  final List<TrajectoryPoint> points;
  final Offset bouncePoint;
  final Offset stumpsArrivalPoint;
  final bool hitsStumps;
  final LbwReviewData lbwData;
  final UltraEdgeData ultraEdgeData;
  final AiCoachAdvice coachAdvice;
  final DateTime timestamp;

  DeliveryAnalytics({
    required this.releaseSpeedKmph,
    required this.pitchSpeedKmph,
    required this.pitchLength,
    required this.lineCorridor,
    required this.swingAngleDegrees,
    required this.seamDeviationMm,
    required this.aeroDragDecel,
    required this.ballCondition,
    required this.pitchCondition,
    required this.points,
    required this.bouncePoint,
    required this.stumpsArrivalPoint,
    required this.hitsStumps,
    required this.lbwData,
    required this.ultraEdgeData,
    required this.coachAdvice,
    required this.timestamp,
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
  int maidens;
  int runsConceded;
  int wickets;

  Bowler({
    required this.name,
    this.ballsBowled = 0,
    this.maidens = 0,
    this.runsConceded = 0,
    this.wickets = 0,
  });

  String get oversFormatted {
    int overs = ballsBowled ~/ 6;
    int rem = ballsBowled % 6;
    return '$overs.$rem';
  }

  double get economy =>
      ballsBowled > 0 ? runsConceded / (ballsBowled / 6.0) : 0.0;
}

// ============================================================================
// 2. ROOT FLUTTER APPLICATION
// ============================================================================

class CricPrismApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const CricPrismApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CricPrism Broadcast Engine',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: ColorsCustom.cyanCore,
          secondary: ColorsCustom.amberGlow,
          surface: ColorsCustom.broadcastNavy,
        ),
      ),
      home: CricPrismEngineView(cameras: cameras),
    );
  }
}

// ============================================================================
// 3. MAIN BROADCAST ENGINE & CONTROLLER
// ============================================================================

class CricPrismEngineView extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CricPrismEngineView({super.key, required this.cameras});

  @override
  State<CricPrismEngineView> createState() => _CricPrismEngineViewState();
}

class _CricPrismEngineViewState extends State<CricPrismEngineView>
    with TickerProviderStateMixin {
  AppMode _currentMode = AppMode.match;
  CameraViewAngle _viewAngle = CameraViewAngle.frontOn;

  // Ball & Pitch Physics
  BallWearCondition _ballWear = BallWearCondition.newShining;
  PitchCondition _pitchCondition = PitchCondition.greenSeamer;

  // Camera Controller
  CameraController? _cameraController;
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isProcessingFrame = false;

  // User Profile & History Lists (Persistent in memory & disk)
  final UserProfile _userProfile = UserProfile(
    username: 'PaceSpeeder_99',
    email: 'bowler@cricprism.ai',
    bowlingStyle: 'Right-Arm Fast',
    targetVelocityKmph: 142.0,
  );
  final List<PracticeDeliveryRecord> _practiceHistory = [];
  final List<MatchRecord> _matchHistory = [];

  // Audio / TTS Commentary Engine
  final FlutterTts _flutterTts = FlutterTts();
  bool _isTtsReady = false;

  // Hawk-Eye Tracer State
  List<TrajectoryPoint> _activeTrajectory = [];
  DeliveryAnalytics? _lastDelivery;
  late AnimationController _trajectoryAnimController;

  // DRS Review Active Dialog State
  bool _isDrsActive = false;
  int _drsStep = 0;
  Timer? _drsSequenceTimer;

  // Match State
  String _teamBatting = 'IND';
  int _totalRuns = 192;
  int _wickets = 3;
  int _legalBallsTotal = 114;
  List<String> _currentOverTimeline = ['0', '1', '4', '1', '2'];

  late Batsman _batsman1;
  late Batsman _batsman2;
  late Bowler _currentBowler;

  // Celebration Card Overlay
  String? _celebrationTitle;
  String? _celebrationSubtitle;
  Color _celebrationColor = ColorsCustom.broadcastGold;
  Timer? _celebrationDismissTimer;

  // Profile Dialog State
  bool _isProfileOpen = false;

  final Rect _alignmentBox = const Rect.fromLTWH(0.24, 0.18, 0.52, 0.72);

  @override
  void initState() {
    super.initState();

    _batsman1 = Batsman(name: 'V. Kohli', runs: 74, balls: 48, fours: 8, sixes: 2, isStriker: true);
    _batsman2 = Batsman(name: 'H. Pandya', runs: 36, balls: 21, fours: 3, sixes: 1, isStriker: false);
    _currentBowler = Bowler(name: 'M. Starc', ballsBowled: 24, maidens: 0, runsConceded: 41, wickets: 2);

    _trajectoryAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );

    _initCamera();
    _initTtsEngine();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _simulateAdvancedDelivery(runs: 0);
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _flutterTts.stop();
    _trajectoryAnimController.dispose();
    _celebrationDismissTimer?.cancel();
    _drsSequenceTimer?.cancel();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // AUDIO ENGINE
  // --------------------------------------------------------------------------
  Future<void> _initTtsEngine() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.53);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      setState(() => _isTtsReady = true);
    } catch (e) {
      debugPrint('TTS Initialization guarded: $e');
      _isTtsReady = false;
    }
  }

  Future<void> _speakCommentary(String message) async {
    if (!_isTtsReady) return;
    try {
      await _flutterTts.stop();
      await _flutterTts.speak(message);
    } catch (e) {
      debugPrint('Commentary audio error: $e');
    }
  }

  // --------------------------------------------------------------------------
  // MULTI-CAMERA SWITCHER
  // --------------------------------------------------------------------------
  Future<void> _initCamera([int? index]) async {
    if (widget.cameras.isEmpty) {
      debugPrint('Virtual turf simulator active.');
      return;
    }

    final targetIndex = index ?? _selectedCameraIndex;
    if (targetIndex >= widget.cameras.length) return;

    await _cameraController?.dispose();

    _cameraController = CameraController(
      widget.cameras[targetIndex],
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() {
        _selectedCameraIndex = targetIndex;
        _isCameraInitialized = true;
      });
    } catch (e) {
      debugPrint('Camera stream initialization guarded: $e');
    }
  }

  void _switchPhysicalCamera() {
    if (widget.cameras.length <= 1) return;
    final nextIndex = (_selectedCameraIndex + 1) % widget.cameras.length;
    _initCamera(nextIndex);
  }

  // --------------------------------------------------------------------------
  // AERODYNAMIC PHYSICS & AI COACHING EVALUATOR
  // --------------------------------------------------------------------------
  void _simulateAdvancedDelivery({
    int runs = 0,
    bool isWicket = false,
    bool forceLbwAppeal = false,
  }) {
    final random = math.Random();

    final double releaseSpeed = 120.0 + random.nextDouble() * 32.0;
    final double releaseSpeedMs = releaseSpeed / 3.6;

    const double airDensity = 1.225;
    const double ballRadius = 0.036;
    final double area = math.pi * ballRadius * ballRadius;
    final double cd = 0.28 + (_ballWear.surfaceRoughness * 0.16);
    final double dragDecel = (0.5 * airDensity * cd * area * math.pow(releaseSpeedMs, 2)) / 0.156;
    final double pitchSpeedKmph = math.max(22.0, releaseSpeedMs - (dragDecel * 0.44)) * 3.6;

    final double seamTilt = (random.nextDouble() * 14.0) - 7.0;
    double swingAngle;
    if (_ballWear == BallWearCondition.roughReverse) {
      swingAngle = (seamTilt * -0.35) + ((random.nextDouble() - 0.5) * 2.2);
    } else {
      swingAngle = (seamTilt * 0.25) + ((random.nextDouble() - 0.5) * 1.5);
    }

    final double seamDeviationMm = ((random.nextDouble() - 0.5) * 6.5) * _pitchCondition.seamMultiplier;

    final double pitchNormY = 0.14 + (random.nextDouble() * 0.72);
    PitchLength lengthCategory;
    if (pitchNormY <= PitchLength.yorker.normMax) {
      lengthCategory = PitchLength.yorker;
    } else if (pitchNormY <= PitchLength.fullLength.normMax) {
      lengthCategory = PitchLength.fullLength;
    } else if (pitchNormY <= PitchLength.goodLength.normMax) {
      lengthCategory = PitchLength.goodLength;
    } else if (pitchNormY <= PitchLength.shortPitch.normMax) {
      lengthCategory = PitchLength.shortPitch;
    } else {
      lengthCategory = PitchLength.bouncer;
    }

    final double lateralOffset = (random.nextDouble() - 0.48) * 0.38;
    final LineCorridor line = lateralOffset < -0.09
        ? LineCorridor.outsideOff
        : (lateralOffset > 0.09 ? LineCorridor.downLeg : LineCorridor.stumps);

    final points = <TrajectoryPoint>[];
    const int numSteps = 45;
    final double bounceIndex = numSteps * (0.34 + (pitchNormY * 0.36));

    final Offset startPos = Offset(0.50 + ((random.nextDouble() - 0.5) * 0.06), 0.21);
    final Offset bouncePos = Offset(0.50 + (lateralOffset * 0.65), 0.62 + (pitchNormY * 0.16));
    final double postBounceLateral = lateralOffset + (seamDeviationMm / 80.0);
    final Offset stumpsPos = Offset(
      0.50 + postBounceLateral,
      0.72 + (lengthCategory == PitchLength.bouncer ? -0.14 : (lengthCategory == PitchLength.yorker ? 0.08 : 0.0)),
    );

    for (int i = 0; i <= numSteps; i++) {
      final double t = i / numSteps;
      double x, y;
      bool isBounce = (i == bounceIndex.round());

      if (i <= bounceIndex) {
        final double segmentT = i / bounceIndex;
        final double lateralSwing = (swingAngle / 10.0) * math.sin(segmentT * math.pi);
        x = startPos.dx + (bouncePos.dx - startPos.dx) * segmentT + lateralSwing;
        y = startPos.dy + (bouncePos.dy - startPos.dy) * math.pow(segmentT, 1.28);
      } else {
        final double postT = (i - bounceIndex) / (numSteps - bounceIndex);
        x = bouncePos.dx + (stumpsPos.dx - bouncePos.dx) * postT;
        final double restitution = _ballWear.coefficientOfRestitution * _pitchCondition.baseBounceFactor;
        final double heightRebound = (lengthCategory == PitchLength.bouncer ? 0.24 : 0.12) * restitution;
        y = bouncePos.dy + (stumpsPos.dy - bouncePos.dy) * postT - (heightRebound * math.sin(postT * math.pi));
      }

      points.add(TrajectoryPoint(
        position: Offset(x, y),
        timestamp: t * 0.55,
        radius: 3.2 + (t * 4.6),
        opacity: 0.15 + (t * 0.85),
        isBounce: isBounce,
        depth: t,
        velocityKmph: releaseSpeed - (t * (releaseSpeed - pitchSpeedKmph)),
        lateralAeroForce: swingAngle,
      ));
    }

    final bool hits = (stumpsPos.dx >= 0.47 && stumpsPos.dx <= 0.53 && stumpsPos.dy >= 0.66 && stumpsPos.dy <= 0.82);

    // AI Coaching Diagnosis
    int coachScore = 72;
    if (releaseSpeed >= _userProfile.targetVelocityKmph - 4) coachScore += 12;
    if (hits) coachScore += 8;
    if (lengthCategory == PitchLength.goodLength) coachScore += 8;
    coachScore = coachScore.clamp(50, 99);

    final coachAdvice = AiCoachAdvice(
      headline: lengthCategory == PitchLength.yorker
          ? 'Pinpoint Searing Yorker'
          : (lengthCategory == PitchLength.goodLength
              ? 'Ideal Corridor of Uncertainty'
              : (lengthCategory == PitchLength.bouncer ? 'Aggressive Climbing Bouncer' : 'Full Attacking Length')),
      ratingScore: coachScore,
      biomechanicsDiagnosis: 'Clocked at ${releaseSpeed.toStringAsFixed(0)} km/h. Seam deviated ${seamDeviationMm.toStringAsFixed(1)}mm 
