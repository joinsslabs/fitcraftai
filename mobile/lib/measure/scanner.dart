// Runs Google ML Kit on the phone (offline, no per-scan cost): pose detection finds the body points,
// selfie segmentation outlines the body. Converts both into the plain types body_math.dart uses.
// This is the "internal engine" behind the measurement adapter; a scan vendor can replace it later.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';

import 'body_math.dart';

const _names = <PoseLandmarkType, String>{
  PoseLandmarkType.leftEye: 'leftEye', PoseLandmarkType.rightEye: 'rightEye',
  PoseLandmarkType.leftShoulder: 'leftShoulder', PoseLandmarkType.rightShoulder: 'rightShoulder',
  PoseLandmarkType.leftElbow: 'leftElbow', PoseLandmarkType.rightElbow: 'rightElbow',
  PoseLandmarkType.leftWrist: 'leftWrist', PoseLandmarkType.rightWrist: 'rightWrist',
  PoseLandmarkType.leftHip: 'leftHip', PoseLandmarkType.rightHip: 'rightHip',
  PoseLandmarkType.leftKnee: 'leftKnee', PoseLandmarkType.rightKnee: 'rightKnee',
  PoseLandmarkType.leftAnkle: 'leftAnkle', PoseLandmarkType.rightAnkle: 'rightAnkle',
  PoseLandmarkType.leftHeel: 'leftHeel', PoseLandmarkType.rightHeel: 'rightHeel',
};

class Scanner {
  final _pose = PoseDetector(options: PoseDetectorOptions(mode: PoseDetectionMode.single, model: PoseDetectionModel.accurate));
  final _segment = SelfieSegmenter(mode: SegmenterMode.single, enableRawSizeMask: true);

  /// Reads one photo into a [Shot]. Throws [ScanError] with a plain-language fix when it cannot.
  Future<Shot> read(String path) async {
    final bytes = await File(path).readAsBytes();
    final decoded = await (await ui.instantiateImageCodec(bytes)).getNextFrame();
    final w = decoded.image.width, h = decoded.image.height;
    final input = InputImage.fromFilePath(path);

    final poses = await _pose.processImage(input);
    if (poses.isEmpty) throw ScanError('No person found in the photo. Stand in the middle of the frame, whole body visible.');
    if (poses.length > 1) throw ScanError('More than one person is in the photo. Only the customer should be in frame.');
    final points = <String, Pt>{
      for (final e in poses.first.landmarks.entries)
        if (_names[e.key] != null) _names[e.key]!: Pt(e.value.x, e.value.y, e.value.likelihood),
    };

    final m = await _segment.processImage(input);
    final mask = m == null ? null : Mask(m.width, m.height, m.confidences);
    return Shot(w, h, points, mask);
  }

  Future<void> close() async {
    await _pose.close();
    await _segment.close();
  }
}
