import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sekitaran/features/auth/account_created_page.dart';
import 'package:sekitaran/features/auth/shake_analyzer.dart';
import 'package:sensors_plus/sensors_plus.dart';

class VerifyDevicePage extends StatefulWidget {
  const VerifyDevicePage({super.key});

  @override
  State<VerifyDevicePage> createState() => _VerifyDevicePageState();
}

class _VerifyDevicePageState extends State<VerifyDevicePage> {
  static const _green = Color(0xFF103D17);
  static const _star = Color(0xFF010C03);
  static const _label = Color(0xFF252525);
  static const _bg = Color(0xFFF2F9F8);
  static const _grey = Color(0xFF7A7A7A);
  static const _spinner = Color(0xFF5BAA5F);

  static const _maxAttempts = 3;
  static const _lockSeconds = 30;
  static const _windowSeconds = 8;

  bool _checking = false;
  String? _error;
  int _failedAttempts = 0;
  DateTime? _lockedUntil;

  StreamSubscription<UserAccelerometerEvent>? _sub;
  Timer? _timeout;
  final _samples = <ShakeSample>[];
  final _clock = Stopwatch();

  @override
  void dispose() {
    _stopListening();
    super.dispose();
  }

  void _stopListening() {
    _sub?.cancel();
    _sub = null;
    _timeout?.cancel();
    _timeout = null;
    _clock.stop();
  }

  void _onVerifyTap() {
    final until = _lockedUntil;
    if (until != null && DateTime.now().isBefore(until)) {
      final left = until.difference(DateTime.now()).inSeconds + 1;
      setState(
        () => _error = 'Terlalu banyak percobaan. Coba lagi dalam $left detik.',
      );
      return;
    }
    _startShakeDetection();
  }

  void _startShakeDetection() {
    _samples.clear();
    _clock
      ..reset()
      ..start();
    setState(() {
      _checking = true;
      _error = null;
    });
    _sub =
        userAccelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 20),
        ).listen(
          (e) {
            final mag = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
            _samples.add(ShakeSample(_clock.elapsedMilliseconds, mag));
            if (_samples.length % 5 == 0 &&
                ShakeAnalyzer.countPeaks(_samples) >=
                    ShakeAnalyzer.targetPeaks) {
              _finish();
            }
          },
          onError: (_) => _fail(
            'Sensor gerak tidak tersedia di perangkat ini.',
            countAttempt: false,
          ),
          cancelOnError: true,
        );
    _timeout = Timer(const Duration(seconds: _windowSeconds), _finish);
  }

  void _finish() {
    if (!_checking) return;
    final verdict = ShakeAnalyzer.analyze(List.of(_samples));
    _stopListening();
    switch (verdict) {
      case ShakeVerdict.human:
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AccountCreatedPage()),
        );
      case ShakeVerdict.tooFew:
        _fail('Guncangan kurang terdeteksi. Goyangkan ponsel lebih kuat.');
      case ShakeVerdict.tooShort:
        _fail('Guncangan terlalu singkat. Goyangkan beberapa saat.');
      case ShakeVerdict.tooRegular:
        _fail('Pola guncangan terlalu seragam. Goyangkan secara alami.');
    }
  }

  void _fail(String message, {bool countAttempt = true}) {
    _stopListening();
    if (!mounted) return;
    var msg = message;
    if (countAttempt) {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _failedAttempts = 0;
        _lockedUntil = DateTime.now().add(
          const Duration(seconds: _lockSeconds),
        );
        msg =
            'Terlalu banyak percobaan gagal. Coba lagi dalam $_lockSeconds detik.';
      }
    }
    setState(() {
      _checking = false;
      _error = msg;
    });
  }

  Widget _title() {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Text(
              'Create Account',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: _green,
              ),
            ),
            Positioned(
              top: -14,
              right: -24,
              child: Text(
                '*',
                style: GoogleFonts.poppins(
                  fontSize: 48,
                  fontWeight: FontWeight.w500,
                  color: _star,
                  height: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Join Sekitaran and discover',
                maxLines: 1,
                softWrap: false,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: _label,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.only(bottom: 3),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _green, width: 1.5)),
                ),
                child: Text(
                  "what's around you.",
                  maxLines: 1,
                  softWrap: false,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: _label,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bottomArea() {
    if (_checking) {
      return const SizedBox(
        height: 84,
        child: Center(
          child: SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              color: _spinner,
              backgroundColor: _green,
            ),
          ),
        ),
      );
    }
    return InkWell(
      onTap: _onVerifyTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: _green, width: 2)),
        child: Container(
          height: 76,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _green,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Text(
            'Verify My Device',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      children: [
                        const SizedBox(height: 64),
                        _title(),
                        const SizedBox(height: 36),
                        Text(
                          'One last step!',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: _label,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "Let's make sure you're a real person.",
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: _grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: 280,
                          height: 300,
                          child: Image.asset(
                            _checking
                                ? 'assets/images/shake_phone_checking.png'
                                : 'assets/images/shake_phone.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Center(
                              child: Icon(
                                Icons.vibration,
                                size: 110,
                                color: _green,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Shake your phone',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: _label,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Gently shake your device to complete human verification.',
                            maxLines: 1,
                            softWrap: false,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: _grey,
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(_checking),
                      child: _bottomArea(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
