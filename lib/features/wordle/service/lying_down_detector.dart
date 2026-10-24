import 'dart:async';
import 'dart:math';

import 'package:sensors_plus/sensors_plus.dart';

class LyingDownDetector {
  // Toggle to enable/disable all debug print statements
  static bool debugLogging = false;

  StreamSubscription<GyroscopeEvent>? _subscription;
  Timer? _debounceTimer;
  bool? _debounceTarget; // Track the state we're debouncing toward
  bool _isLyingDown = false;
  final Function(bool) onLyingDownChanged;
  final Function(double pitch, double roll, double yaw)? onOrientationChanged;

  // Integrated orientation (radians)
  double _pitch = 0; // Rotation around X axis (forward/backward tilt)
  double _roll = 0; // Rotation around Y axis (left/right tilt)
  double _yaw = 0; // Rotation around Z axis (rotation in plane)
  DateTime? _lastTimestamp;

  // ~75 degrees in radians - threshold for "lying flat"
  static const double _lyingThreshold = 1.3;
  static const Duration _debounceDuration = Duration(seconds: 2);

  // For drift correction: reset when high angular velocity detected (user moving phone)
  static const double _resetThreshold = 10.0; // rad/sec

  LyingDownDetector({
    required this.onLyingDownChanged,
    this.onOrientationChanged,
  });

  bool get isLyingDown => _isLyingDown;
  double get pitch => _pitch;
  double get roll => _roll;
  double get yaw => _yaw;

  void startListening() {
    _subscription?.cancel();
    _pitch = 0;
    _roll = 0;
    _lastTimestamp = null;

    print('[GyroDetector] Starting gyroscope stream...');
    _subscription =
        gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 50))
            .listen(
              _onGyroscopeEvent,
              onError: (error) {
                print('[GyroDetector] Stream ERROR: $error');
                stopListening();
              },
              onDone: () {
                print('[GyroDetector] Stream DONE (closed)');
                stopListening();
              },
              cancelOnError: true,
            );

    print(
      '[GyroDetector] Stream subscription created: ${_subscription != null}',
    );
    if (debugLogging)
      print('[GyroDetector] Started listening (gyroscope-only)');
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _debounceTarget = null;
    _lastTimestamp = null;
    if (debugLogging) print('[GyroDetector] Stopped listening');
  }

  void _onGyroscopeEvent(GyroscopeEvent event) {
    print(
      '[GyroDetector] _onGyroscopeEvent called: x=${event.x.toStringAsFixed(2)}, y=${event.y.toStringAsFixed(2)}, z=${event.z.toStringAsFixed(2)}',
    );
    final now = DateTime.now();

    if (_lastTimestamp != null) {
      final dt = now.difference(_lastTimestamp!).inMicroseconds / 1_000_000.0;

      // Integrate angular velocity to get orientation
      // GyroscopeEvent: x = pitch rate, y = roll rate, z = yaw rate
      _pitch += event.x * dt;
      _roll += event.y * dt;
      _yaw += event.z * dt;

      // Normalize to [-π, π]
      _pitch = _normalizeAngle(_pitch);
      _roll = _normalizeAngle(_roll);
      _yaw = _normalizeAngle(_yaw);

      // Drift correction: reset orientation if phone is being moved quickly
      final angularSpeed = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      if (angularSpeed > _resetThreshold) {
        _pitch = 0;
        _roll = 0;
        _yaw = 0;
        if (debugLogging) {
          print(
            '[GyroDetector] High angular speed detected (${angularSpeed.toStringAsFixed(2)}), resetting orientation',
          );
        }
      }
    }
    _lastTimestamp = now;

    // Notify orientation change for UI updates
    onOrientationChanged?.call(_pitch, _roll, _yaw);

    // Check if lying flat (|pitch| or |roll| ≈ 90° = 1.57 rad)
    final currentlyLyingDown =
        _pitch.abs() > _lyingThreshold || _roll.abs() > _lyingThreshold;

    print(
      '[GyroDetector] currentlyLyingDown=$currentlyLyingDown (pitch=${_pitch.toStringAsFixed(2)}, roll=${_roll.toStringAsFixed(2)}, threshold=$_lyingThreshold)',
    );

    // Console logging for every event
    if (debugLogging) {
      print(
        '[GyroDetector] pitch=${_pitch.toStringAsFixed(2)}, '
        'roll=${_roll.toStringAsFixed(2)}, '
        'yaw=${_yaw.toStringAsFixed(2)}, '
        'lyingDown=$currentlyLyingDown, '
        'gyro=(${event.x.toStringAsFixed(2)}, ${event.y.toStringAsFixed(2)}, ${event.z.toStringAsFixed(2)})',
      );
    }

    _debounceStateChange(currentlyLyingDown);
  }

  void _debounceStateChange(bool currentlyLyingDown) {
    // If already debouncing toward this same target, do nothing
    if (_debounceTarget == currentlyLyingDown) {
      print(
        '[GyroDetector] Already debouncing toward $currentlyLyingDown, ignoring',
      );
      return;
    }

    // If current state already matches, no debounce needed
    if (currentlyLyingDown == _isLyingDown) {
      _debounceTimer?.cancel();
      _debounceTarget = null;
      print(
        '[GyroDetector] No state change needed: currentlyLyingDown=$currentlyLyingDown == _isLyingDown=$_isLyingDown',
      );
      return;
    }

    _debounceTimer?.cancel();
    _debounceTarget = currentlyLyingDown;
    print(
      '[GyroDetector] Debounce started: currentlyLyingDown=$currentlyLyingDown, _isLyingDown=$_isLyingDown, waiting ${_debounceDuration.inSeconds}s...',
    );
    _debounceTimer = Timer(_debounceDuration, () {
      _isLyingDown = currentlyLyingDown;
      _debounceTarget = null;
      print(
        '[GyroDetector] STATE CHANGED: lyingDown=$_isLyingDown (callback will fire)',
      );
      onLyingDownChanged(_isLyingDown);
    });
  }

  double _normalizeAngle(double angle) {
    while (angle > pi) {
      angle -= 2 * pi;
    }
    while (angle < -pi) {
      angle += 2 * pi;
    }
    return angle;
  }

  // Manual reset for testing/calibration
  void resetOrientation() {
    _pitch = 0;
    _roll = 0;
    _yaw = 0;
    _lastTimestamp = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _debounceTarget = null;
    onOrientationChanged?.call(0, 0, 0);
    if (debugLogging) print('[GyroDetector] Manual orientation reset');
  }

  void dispose() {
    stopListening();
  }
}
