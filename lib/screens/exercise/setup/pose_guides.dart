import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum PoseGuideJoint {
  ear(PoseLandmarkType.leftEar, PoseLandmarkType.rightEar),
  shoulder(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
  elbow(PoseLandmarkType.leftElbow, PoseLandmarkType.rightElbow),
  wrist(PoseLandmarkType.leftWrist, PoseLandmarkType.rightWrist),
  hip(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  knee(PoseLandmarkType.leftKnee, PoseLandmarkType.rightKnee),
  ankle(PoseLandmarkType.leftAnkle, PoseLandmarkType.rightAnkle);

  const PoseGuideJoint(this.left, this.right);

  final PoseLandmarkType left;
  final PoseLandmarkType right;
}

enum PoseGuideFrame { standing, floor, seated }

class PoseGuideStep {
  const PoseGuideStep(this.text, this.joint);

  final String text;
  final PoseGuideJoint joint;
}

class PoseGuide {
  const PoseGuide({
    required this.catalogId,
    required this.frame,
    required this.steps,
    this.facingCamera = false,
  });

  final String catalogId;
  final PoseGuideFrame frame;
  final List<PoseGuideStep> steps;
  final bool facingCamera;

  String get asset => 'assets/pose_guide/$catalogId.png';

  String get subtitle => facingCamera
      ? 'Quay mặt về phía điện thoại nhé.'
      : 'Quay nghiêng người với điện thoại nhé.';
}

const Map<String, PoseGuide> kPoseGuides = <String, PoseGuide>{
  'squat': PoseGuide(
    catalogId: 'squat',
    frame: PoseGuideFrame.standing,
    steps: [
      PoseGuideStep('Đứng thẳng người.', PoseGuideJoint.hip),
      PoseGuideStep('Duỗi thẳng gối.', PoseGuideJoint.knee),
      PoseGuideStep('Đặt cả bàn chân xuống sàn.', PoseGuideJoint.ankle),
    ],
  ),
  'push_up': PoseGuide(
    catalogId: 'push_up',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Chống thẳng tay, vai ngay trên cổ tay.', PoseGuideJoint.wrist),
      PoseGuideStep('Siết bụng, thân thẳng từ vai đến gót.', PoseGuideJoint.hip),
      PoseGuideStep('Chống mũi chân, duỗi thẳng gối.', PoseGuideJoint.ankle),
    ],
  ),
  'glute_bridge': PoseGuide(
    catalogId: 'glute_bridge',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Nằm ngửa, đầu và vai chạm sàn.', PoseGuideJoint.shoulder),
      PoseGuideStep('Gập gối, bàn chân gần mông.', PoseGuideJoint.knee),
      PoseGuideStep('Đặt cả bàn chân xuống sàn.', PoseGuideJoint.ankle),
    ],
  ),
  'plank': PoseGuide(
    catalogId: 'plank',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Chống cẳng tay, khuỷu ngay dưới vai.', PoseGuideJoint.elbow),
      PoseGuideStep('Thân thẳng một đường từ vai đến gót.', PoseGuideJoint.hip),
      PoseGuideStep('Chống mũi chân, duỗi thẳng gối.', PoseGuideJoint.knee),
    ],
  ),
  'lunge': PoseGuide(
    catalogId: 'lunge',
    frame: PoseGuideFrame.standing,
    steps: [
      PoseGuideStep('Đứng thẳng người, mắt nhìn phía trước.', PoseGuideJoint.shoulder),
      PoseGuideStep('Hai tay chống hông.', PoseGuideJoint.hip),
      PoseGuideStep('Hai bàn chân đặt ngay dưới hông.', PoseGuideJoint.ankle),
    ],
  ),
  'jump_squat': PoseGuide(
    catalogId: 'jump_squat',
    frame: PoseGuideFrame.standing,
    steps: [
      PoseGuideStep('Đứng thẳng người.', PoseGuideJoint.hip),
      PoseGuideStep('Gối thả lỏng, không khóa cứng.', PoseGuideJoint.knee),
      PoseGuideStep('Đặt cả bàn chân xuống sàn.', PoseGuideJoint.ankle),
    ],
  ),
  'jumping_jack': PoseGuide(
    catalogId: 'jumping_jack',
    frame: PoseGuideFrame.standing,
    facingCamera: true,
    steps: [
      PoseGuideStep('Đứng thẳng, mặt hướng về điện thoại.', PoseGuideJoint.shoulder),
      PoseGuideStep('Hai tay xuôi theo thân.', PoseGuideJoint.wrist),
      PoseGuideStep('Khép hai chân.', PoseGuideJoint.ankle),
    ],
  ),
  'wall_pushup': PoseGuide(
    catalogId: 'wall_pushup',
    frame: PoseGuideFrame.standing,
    steps: [
      PoseGuideStep('Chống hai tay vào tường, ngang vai.', PoseGuideJoint.wrist),
      PoseGuideStep('Thân thẳng từ đầu đến gót.', PoseGuideJoint.hip),
      PoseGuideStep('Đứng cách tường khoảng một sải tay.', PoseGuideJoint.ankle),
    ],
  ),
  'situp': PoseGuide(
    catalogId: 'situp',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Nằm ngửa, lưng chạm sàn.', PoseGuideJoint.shoulder),
      PoseGuideStep('Gập gối khoảng 90°.', PoseGuideJoint.knee),
      PoseGuideStep('Đặt cả bàn chân xuống sàn.', PoseGuideJoint.ankle),
    ],
  ),
  'leg_raises': PoseGuide(
    catalogId: 'leg_raises',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Nằm ngửa, ép lưng dưới sát sàn.', PoseGuideJoint.hip),
      PoseGuideStep('Duỗi thẳng hai chân.', PoseGuideJoint.knee),
      PoseGuideStep('Hai tay đặt dọc thân.', PoseGuideJoint.wrist),
    ],
  ),
  'vup': PoseGuide(
    catalogId: 'vup',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Nằm ngửa, duỗi thẳng người.', PoseGuideJoint.hip),
      PoseGuideStep('Vươn thẳng hai tay qua đầu.', PoseGuideJoint.wrist),
      PoseGuideStep('Duỗi thẳng và khép hai chân.', PoseGuideJoint.ankle),
    ],
  ),
  'mcgill_curlup': PoseGuide(
    catalogId: 'mcgill_curlup',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Nằm ngửa, hai tay luồn dưới lưng dưới.', PoseGuideJoint.wrist),
      PoseGuideStep('Gập một gối, bàn chân đặt trên sàn.', PoseGuideJoint.knee),
      PoseGuideStep('Chân còn lại duỗi thẳng.', PoseGuideJoint.ankle),
    ],
  ),
  'dead_bug': PoseGuide(
    catalogId: 'dead_bug',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Nằm ngửa, ép lưng dưới sát sàn.', PoseGuideJoint.hip),
      PoseGuideStep('Vươn thẳng hai tay lên trần.', PoseGuideJoint.wrist),
      PoseGuideStep('Gập gối 90°, cẳng chân song song sàn.', PoseGuideJoint.knee),
    ],
  ),
  'bird_dog': PoseGuide(
    catalogId: 'bird_dog',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Chống hai tay ngay dưới vai.', PoseGuideJoint.wrist),
      PoseGuideStep('Gối đặt ngay dưới hông.', PoseGuideJoint.knee),
      PoseGuideStep('Giữ lưng phẳng, cổ thẳng hàng với lưng.', PoseGuideJoint.shoulder),
    ],
  ),
  'mountain_climber': PoseGuide(
    catalogId: 'mountain_climber',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Chống thẳng tay, vai ngay trên cổ tay.', PoseGuideJoint.wrist),
      PoseGuideStep('Thân thẳng từ vai đến gót.', PoseGuideJoint.hip),
      PoseGuideStep('Chống mũi chân.', PoseGuideJoint.ankle),
    ],
  ),
  'superman': PoseGuide(
    catalogId: 'superman',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Nằm sấp, mặt hướng xuống sàn.', PoseGuideJoint.shoulder),
      PoseGuideStep('Duỗi thẳng hai tay về phía trước.', PoseGuideJoint.wrist),
      PoseGuideStep('Duỗi thẳng hai chân.', PoseGuideJoint.ankle),
    ],
  ),
  'tricep_dip': PoseGuide(
    catalogId: 'tricep_dip',
    frame: PoseGuideFrame.seated,
    steps: [
      PoseGuideStep('Ngồi trên sàn, hai tay chống phía sau.', PoseGuideJoint.wrist),
      PoseGuideStep('Duỗi thẳng khuỷu tay.', PoseGuideJoint.elbow),
      PoseGuideStep('Gập gối, đặt cả bàn chân xuống sàn.', PoseGuideJoint.ankle),
    ],
  ),
  'side_plank_dip': PoseGuide(
    catalogId: 'side_plank_dip',
    frame: PoseGuideFrame.floor,
    facingCamera: true,
    steps: [
      PoseGuideStep('Chống một khuỷu tay ngay dưới vai.', PoseGuideJoint.elbow),
      PoseGuideStep('Nâng hông, thân thẳng từ vai đến cổ chân.', PoseGuideJoint.hip),
      PoseGuideStep('Duỗi thẳng hai chân, xếp chồng lên nhau.', PoseGuideJoint.ankle),
    ],
  ),
  'seated_forward_fold': PoseGuide(
    catalogId: 'seated_forward_fold',
    frame: PoseGuideFrame.seated,
    steps: [
      PoseGuideStep('Ngồi thẳng lưng trên sàn.', PoseGuideJoint.shoulder),
      PoseGuideStep('Duỗi thẳng hai chân về phía trước.', PoseGuideJoint.knee),
      PoseGuideStep('Đặt hai tay nhẹ lên đùi.', PoseGuideJoint.wrist),
    ],
  ),
  'butterfly': PoseGuide(
    catalogId: 'butterfly',
    frame: PoseGuideFrame.seated,
    facingCamera: true,
    steps: [
      PoseGuideStep('Ngồi thẳng lưng, mặt hướng về điện thoại.', PoseGuideJoint.shoulder),
      PoseGuideStep('Chụm hai lòng bàn chân, kéo gót gần hông.', PoseGuideJoint.ankle),
      PoseGuideStep('Thả lỏng để hai gối hạ xuống.', PoseGuideJoint.knee),
    ],
  ),
  'sphinx': PoseGuide(
    catalogId: 'sphinx',
    frame: PoseGuideFrame.floor,
    steps: [
      PoseGuideStep('Nằm sấp, chống hai cẳng tay xuống sàn.', PoseGuideJoint.elbow),
      PoseGuideStep('Khuỷu tay ngay dưới vai.', PoseGuideJoint.shoulder),
      PoseGuideStep('Thả lỏng hông và hai chân trên sàn.', PoseGuideJoint.hip),
    ],
  ),
};
