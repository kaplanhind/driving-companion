import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:vibration/vibration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: DrivingCompanionScreen(),
  ));
}

class DrivingCompanionScreen extends StatefulWidget {
  const DrivingCompanionScreen({Key? key}) : super(key: key);

  @override
  State<DrivingCompanionScreen> createState() => _DrivingCompanionScreenState();
}

class _DrivingCompanionScreenState extends State<DrivingCompanionScreen>
    with SingleTickerProviderStateMixin {
  int _score = 100;
  bool _isShocked = false;
  Timer? _shockTimer;

  Timer? _touchTimer;
  late AnimationController _progressController;

  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  DateTime _lastDeductionTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _initSensors();
  }

  void _initSensors() {
    _accelSubscription = userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      final now = DateTime.now();
      if (now.difference(_lastDeductionTime).inMilliseconds < 1500) return;

      if (event.y < -3.8) {
        _applyPenalty(5);
      } else if (event.y > 3.5) {
        _applyPenalty(3);
      } else if (event.x.abs() > 3.8) {
        _applyPenalty(8);
      }
    });
  }

  void _applyPenalty(int points) {
    _lastDeductionTime = DateTime.now();
    setState(() {
      _score = max(0, _score - points);
      _isShocked = true;
    });

    _shockTimer?.cancel();
    _shockTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _isShocked = false);
      }
    });
  }

  void _onPointerDown() {
    _progressController.forward(from: 0.0);
    _touchTimer = Timer(const Duration(seconds: 2), () async {
      setState(() {
        _score = 100;
        _isShocked = false;
      });
      _progressController.reset();

      if (await Vibration.hasVibrator() ?? false) {
        Vibration.vibrate(pattern: [0, 120, 80, 120]);
      }
    });
  }

  void _onPointerUp() {
    _touchTimer?.cancel();
    _progressController.reset();
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _shockTimer?.cancel();
    _touchTimer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTapDown: (_) => _onPointerDown(),
              onTapUp: (_) => _onPointerUp(),
              onTapCancel: () => _onPointerUp(),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 290,
                    height: 290,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF111418),
                      boxShadow: [
                        BoxShadow(
                          color: _getCurrentColor().withOpacity(0.35),
                          blurRadius: 35,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, child) {
                      return SizedBox(
                        width: 290,
                        height: 290,
                        child: CircularProgressIndicator(
                          value: _progressController.value,
                          strokeWidth: 6,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                          backgroundColor: Colors.transparent,
                        ),
                      );
                    },
                  ),
                  CustomPaint(
                    size: const Size(290, 290),
                    painter: AvatarPainter(
                      score: _score,
                      isShocked: _isShocked,
                      themeColor: _getCurrentColor(),
                    ),
                  ),
                  Positioned(
                    bottom: 28,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '$_score',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 35),
            Text(
              'المس الشاشة لمدة ثانيتين للتصفير',
              style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCurrentColor() {
    if (_isShocked) return const Color(0xFF38BDF8);
    if (_score >= 90) return const Color(0xFF22C55E);
    if (_score >= 75) return const Color(0xFF84CC16);
    if (_score >= 60) return const Color(0xFFEAB308);
    if (_score >= 45) return const Color(0xFFF97316);
    if (_score >= 25) return const Color(0xFFEA580C);
    return const Color(0xFFEF4444);
  }
}

class AvatarPainter extends CustomPainter {
  final int score;
  final bool isShocked;
  final Color themeColor;

  AvatarPainter({
    required this.score,
    required this.isShocked,
    required this.themeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintObj = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    strokePaint
      ..color = themeColor
      ..strokeWidth = 5;
    canvas.drawCircle(center, (size.width / 2) - 4, strokePaint);

    final leftEyePos = Offset(center.dx - 45, center.dy - 25);
    final rightEyePos = Offset(center.dx + 45, center.dy - 25);

    if (isShocked) {
      paintObj.color = Colors.white;
      canvas.drawCircle(leftEyePos, 14, paintObj);
      canvas.drawCircle(rightEyePos, 14, paintObj);

      strokePaint
        ..color = Colors.white
        ..strokeWidth = 4;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 35), width: 22, height: 32),
        strokePaint,
      );
      return;
    }

    if (score >= 90) {
      strokePaint
        ..color = Colors.white
        ..strokeWidth = 5;
      _drawArc(canvas, leftEyePos, 16, strokePaint, true);
      _drawArc(canvas, rightEyePos, 16, strokePaint, true);
      _drawMouthArc(canvas, Offset(center.dx, center.dy + 25), 45, 20, strokePaint);
    } else if (score >= 75) {
      paintObj.color = Colors.white;
      canvas.drawCircle(leftEyePos, 10, paintObj);
      canvas.drawCircle(rightEyePos, 10, paintObj);
      strokePaint
        ..color = Colors.white
        ..strokeWidth = 4;
      _drawMouthArc(canvas, Offset(center.dx, center.dy + 25), 35, 14, strokePaint);
    } else if (score >= 60) {
      paintObj.color = Colors.white;
      canvas.drawCircle(leftEyePos, 9, paintObj);
      canvas.drawCircle(rightEyePos, 9, paintObj);
      strokePaint
        ..color = Colors.white
        ..strokeWidth = 4;
      canvas.drawLine(
        Offset(center.dx - 22, center.dy + 30),
        Offset(center.dx + 22, center.dy + 30),
        strokePaint,
      );
    } else if (score >= 45) {
      paintObj.color = Colors.white;
      canvas.drawCircle(leftEyePos, 9, paintObj);
      canvas.drawCircle(rightEyePos, 9, paintObj);
      strokePaint
        ..color = Colors.white
        ..strokeWidth = 4;
      _drawMouthArc(canvas, Offset(center.dx, center.dy + 35), 32, -12, strokePaint);
    } else if (score >= 25) {
      paintObj.color = const Color(0xFFFF5252);
      canvas.drawCircle(leftEyePos, 9, paintObj);
      canvas.drawCircle(rightEyePos, 9, paintObj);
      strokePaint
        ..color = const Color(0xFFFF5252)
        ..strokeWidth = 4;
      canvas.drawLine(Offset(leftEyePos.dx - 14, leftEyePos.dy - 16),
          Offset(leftEyePos.dx + 12, leftEyePos.dy - 8), strokePaint);
      canvas.drawLine(Offset(rightEyePos.dx + 14, rightEyePos.dy - 16),
          Offset(rightEyePos.dx - 12, rightEyePos.dy - 8), strokePaint);
      _drawMouthArc(canvas, Offset(center.dx, center.dy + 36), 38, -16, strokePaint);
    } else {
      paintObj.color = const Color(0xFFFF1744);
      canvas.drawCircle(leftEyePos, 11, paintObj);
      canvas.drawCircle(rightEyePos, 11, paintObj);
      strokePaint
        ..color = const Color(0xFFFF1744)
        ..strokeWidth = 5;
      canvas.drawLine(Offset(leftEyePos.dx - 18, leftEyePos.dy - 18),
          Offset(leftEyePos.dx + 14, leftEyePos.dy - 7), strokePaint);
      canvas.drawLine(Offset(rightEyePos.dx + 18, rightEyePos.dy - 18),
          Offset(rightEyePos.dx - 14, rightEyePos.dy - 7), strokePaint);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(center.dx, center.dy + 35), width: 36, height: 26),
        strokePaint,
      );
    }
  }

  void _drawArc(Canvas canvas, Offset center, double radius, Paint paint, bool openUp) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, pi, pi, false, paint);
  }

  void _drawMouthArc(Canvas canvas, Offset center, double width, double height, Paint paint) {
    final path = Path();
    path.moveTo(center.dx - (width / 2), center.dy);
    path.quadraticBezierTo(center.dx, center.dy + (height * 2), center.dx + (width / 2), center.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant AvatarPainter oldDelegate) {
    return oldDelegate.score != score ||
        oldDelegate.isShocked != isShocked ||
        oldDelegate.themeColor != themeColor;
  }
}
