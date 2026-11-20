import 'dead_bug_metric_base.dart';
import '../../../utils/debouncer.dart';

class StableLimbsMetric extends DeadBugMetricBase {
  @override
  String get name => 'StableLimbs';
  final List<FaultRecord> _faults = [];
  final Map<String, dynamic> _debugData = {};

  final Debouncer _faultDebouncer = Debouncer(requiredFrames: 5);

  @override
  List<FaultRecord> get faults => _faults;
  @override
  Map<String, dynamic> get debugData => _debugData;

  @override
  double? get value => _debugData['supportMaxAngle'] as double?;

  @override
  ThresholdBand? get threshold => const ThresholdBand(faultAbove: 135.0);

  @override
  void update(DeadBugRepContext ctx) {
    if (ctx.state == DeadBugState.extending || ctx.state == DeadBugState.hold) {
      // Chi ĐANG DUỖI = the active arm/leg pair chosen by DeadBug. The other
      // arm and leg are the support (CHI TRỤ) limbs and must stay <= 135 độ.
      // (Before 2026-11-17 "extending" meant any limb > 118 and support meant
      // "not extending and > 135", which could never both hold.)
      final supportArm = ctx.physicalLeftArmExtending
          ? ctx.rightArmAngle
          : ctx.leftArmAngle;
      final supportLeg = ctx.physicalLeftLegExtending
          ? ctx.rightHipAngle
          : ctx.leftHipAngle;
      final supportMax = supportArm > supportLeg ? supportArm : supportLeg;
      _debugData['supportMaxAngle'] = supportMax;

      if (_faultDebouncer.update(supportMax > 135.0)) {
        if (!_faults.any((f) => f.type == 'stable_limbs')) {
          _faults.add(FaultRecord(
            phase: ctx.state.name,
            type: 'stable_limbs',
            message: 'Chi trụ bị kéo xê dịch',
            voiceMessage: 'Giữ cố định tay và chân còn lại vuông góc nhé!',
            affectsForm: true,
            priority: DeadBugFaultPriority.stableLimbs,
          ));
        }
      }
    }
  }

  @override
  void reset() {
    _faults.clear();
    _debugData.clear();
    _faultDebouncer.reset();
  }
}
