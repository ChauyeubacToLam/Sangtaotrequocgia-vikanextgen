import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:native_device_orientation/native_device_orientation.dart';

import '../../../exercise/exercise_base.dart';

class SensorRotatedBox extends StatefulWidget {
  const SensorRotatedBox({
    super.key,
    required this.child,
    this.orientationStream,
    this.initialOrientation,
  });

  final Widget child;
  final Stream<VikaImageOrientation>? orientationStream;
  final Future<VikaImageOrientation>? initialOrientation;

  @override
  State<SensorRotatedBox> createState() => _SensorRotatedBoxState();
}

class _SensorRotatedBoxState extends State<SensorRotatedBox> {
  VikaImageOrientation _orientation = lastSensorOrientation;
  StreamSubscription<VikaImageOrientation>? _subscription;

  @override
  void initState() {
    super.initState();
    if (!ExerciseBase.kLandscapeRotationEnabled) {
      _orientation = VikaImageOrientation.portrait;
      return;
    }
    final communicator = NativeDeviceOrientationCommunicator();
    final initial = widget.initialOrientation ??
        communicator.orientation(useSensor: true).then((native) {
          if (native == NativeDeviceOrientation.unknown) return _orientation;
          final o = VikaImageOrientation.fromNative(native);
          return _orientation.isLandscape && !o.isLandscape ? _orientation : o;
        });
    unawaited(
      initial.then(_apply).catchError((Object _) {}),
    );
    final stream = widget.orientationStream ??
        settledSensorOrientation(
            communicator.onOrientationChanged(useSensor: true));
    _subscription = stream.listen(_apply, onError: (Object _) {});
  }

  void _apply(VikaImageOrientation orientation) {
    if (!mounted || orientation == _orientation) {
      return;
    }
    lastSensorOrientation = orientation;
    setState(() => _orientation = orientation);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quarterTurns =
        _orientation.isLandscape ? _orientation.uiQuarterTurns : 0;
    return RotatedBox(quarterTurns: quarterTurns, child: widget.child);
  }
}
