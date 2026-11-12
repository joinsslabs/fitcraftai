// Turns two photos' body points (pose landmarks) and body outlines (segmentation masks) into
// measurements. Pure Dart with no plugin types, so it is unit-tested without a phone.
//
// Method
// - Scale: eye height is about 0.936 of standing height (standard anthropometric ratio), so
//   cm per pixel = 0.936 * height / (heel y - eye y).
// - Lengths come from the distances between body points in the front photo.
// - Circumferences treat the body's cross-section at chest, waist and hip as an ellipse:
//   width from the front outline, depth from the side outline, perimeter by Ramanujan's formula.
// These are ESTIMATES for the tailor to confirm. The ratios below are starting values to calibrate
// against tape measurements during the pilot.
import 'dart:math' as math;

class Pt {
  final double x, y, likelihood;
  const Pt(this.x, this.y, [this.likelihood = 1]);
  double dist(Pt o) => math.sqrt(math.pow(x - o.x, 2) + math.pow(y - o.y, 2));
}

/// A body outline: [confidence] per pixel (0..1) that it belongs to the person, row by row.
class Mask {
  final int width, height;
  final List<double> confidence;
  const Mask(this.width, this.height, this.confidence);

  /// Width in mask pixels of the body run that contains [x] on row [y].
  int runWidth(int y, int x) {
    if (y < 0 || y >= height || x < 0 || x >= width) return 0;
    bool on(int xx) => confidence[y * width + xx] >= 0.5;
    if (!on(x)) return 0;
    var l = x, r = x;
    while (l > 0 && on(l - 1)) {
      l--;
    }
    while (r < width - 1 && on(r + 1)) {
      r++;
    }
    return r - l + 1;
  }
}

/// One photo: its pixel size, named body points, and optional outline.
class Shot {
  final int imageWidth, imageHeight;
  final Map<String, Pt> points; // keys: nose, leftEye, rightEye, leftShoulder, ... leftHeel, rightHeel
  final Mask? mask;
  const Shot(this.imageWidth, this.imageHeight, this.points, [this.mask]);
  Pt? operator [](String k) => points[k];
}

enum Confidence { good, check, estimate }

class Measure {
  final double cm;
  final Confidence confidence;
  const Measure(this.cm, this.confidence);
  double get inches => cm / 2.54;
}

class ScanError implements Exception {
  final String message;
  ScanError(this.message);
  @override
  String toString() => message;
}

const eyeHeightRatio = 0.936;

double ellipsePerimeter(double width, double depth) {
  final a = width / 2, b = depth / 2;
  return math.pi * (3 * (a + b) - math.sqrt((3 * a + b) * (a + 3 * b)));
}

Pt _mid(Pt a, Pt b) => Pt((a.x + b.x) / 2, (a.y + b.y) / 2, math.min(a.likelihood, b.likelihood));

Pt _need(Shot s, String k, String what) {
  final p = s[k];
  if (p == null || p.likelihood < 0.5) throw ScanError('Could not see the $what clearly. $_retake');
  return p;
}

const _retake = 'Retake the photo with the whole body in frame, in good light, about 2 to 3 metres away.';

/// cm per image pixel for this photo, from the person's height.
double cmPerPixel(Shot s, double heightCm) {
  final eye = _mid(_need(s, 'leftEye', 'eyes'), _need(s, 'rightEye', 'eyes'));
  final heelL = _need(s, 'leftHeel', 'feet'), heelR = _need(s, 'rightHeel', 'feet');
  final px = math.max(heelL.y, heelR.y) - eye.y;
  if (px < s.imageHeight * 0.4) throw ScanError('You are too far from the camera. $_retake');
  return eyeHeightRatio * heightCm / px;
}

/// Width of the body outline at image row [y], in image pixels, measured around column [x].
double? outlineWidthPx(Shot s, double y, double x) {
  final m = s.mask;
  if (m == null) return null;
  final mx = (x / s.imageWidth * m.width).round(), my = (y / s.imageHeight * m.height).round();
  // Look a few rows up and down and keep the widest run, so one noisy row does not decide it.
  var best = 0;
  for (var dy = -2; dy <= 2; dy++) {
    best = math.max(best, m.runWidth(my + dy, mx));
  }
  return best == 0 ? null : best * s.imageWidth / m.width;
}

/// All body measurements in cm, keyed by name. Missing keys mean "could not estimate".
Map<String, Measure> measureBody({required Shot front, required Shot side, required double heightCm}) {
  if (heightCm < 100 || heightCm > 230) throw ScanError('Enter a height between 100 and 230 cm.');
  final k = cmPerPixel(front, heightCm);
  Confidence lenConf(List<Pt> pts) => pts.every((p) => p.likelihood >= 0.8) ? Confidence.good : Confidence.check;

  final ls = _need(front, 'leftShoulder', 'shoulders'), rs = _need(front, 'rightShoulder', 'shoulders');
  final le = _need(front, 'leftElbow', 'arms'), lw = _need(front, 'leftWrist', 'wrists');
  final re = _need(front, 'rightElbow', 'arms'), rw = _need(front, 'rightWrist', 'wrists');
  final lh = _need(front, 'leftHip', 'hips'), rh = _need(front, 'rightHip', 'hips');
  final lk = _need(front, 'leftKnee', 'knees'), rk = _need(front, 'rightKnee', 'knees');
  final la = _need(front, 'leftAnkle', 'ankles'), ra = _need(front, 'rightAnkle', 'ankles');

  final shoulder = _mid(ls, rs), hip = _mid(lh, rh);
  final torso = hip.y - shoulder.y;
  final chestY = shoulder.y + 0.28 * torso, waistY = shoulder.y + 0.62 * torso, hipY = hip.y + 0.05 * torso;

  // Use the arm the camera saw better.
  final leftArm = ls.dist(le) + le.dist(lw), rightArm = rs.dist(re) + re.dist(rw);
  final useLeft = math.min(le.likelihood, lw.likelihood) >= math.min(re.likelihood, rw.likelihood);
  final legL = lh.dist(lk) + lk.dist(la), legR = rh.dist(rk) + rk.dist(ra);

  final out = <String, Measure>{
    'shoulderWidth': Measure(ls.dist(rs) * k, lenConf([ls, rs])),
    'sleeve': Measure((useLeft ? leftArm : rightArm) * k, lenConf(useLeft ? [ls, le, lw] : [rs, re, rw])),
    'shoulderToWaist': Measure((waistY - shoulder.y) * k, lenConf([ls, rs, lh, rh])),
    'shoulderToHip': Measure((hip.y - shoulder.y) * k, lenConf([ls, rs, lh, rh])),
    'shoulderToAnkle': Measure((_mid(la, ra).y - shoulder.y) * k, lenConf([ls, rs, la, ra])),
    'waistToAnkle': Measure((_mid(la, ra).y - waistY) * k, lenConf([lh, rh, la, ra])),
    'inseamToAnkle': Measure((math.min(legL, legR)) * k, lenConf([lh, rh, lk, rk, la, ra])),
  };

  // Circumferences need both outlines. The side photo has its own scale.
  final ks = cmPerPixel(side, heightCm);
  Pt? sideJoint(String l, String r) {
    final a = side[l], b = side[r];
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return a.likelihood >= b.likelihood ? a : b;
  }

  final sShoulder = sideJoint('leftShoulder', 'rightShoulder'), sHip = sideJoint('leftHip', 'rightHip');
  if (sShoulder != null && sHip != null && front.mask != null && side.mask != null) {
    final sTorso = sHip.y - sShoulder.y;
    final sx = (sShoulder.x + sHip.x) / 2;
    void circ(String name, double frontY, double frac) {
      final w = outlineWidthPx(front, frontY, shoulder.x);
      final d = outlineWidthPx(side, sShoulder.y + frac * sTorso, sx);
      if (w != null && d != null) out[name] = Measure(ellipsePerimeter(w * k, d * ks), Confidence.estimate);
    }

    circ('chest', chestY, 0.28);
    circ('waist', waistY, 0.62);
    circ('hip', hipY, 1.05);
  }
  return out;
}

/// Which body measurement fills each garment template field. Fields not listed (neck, cap, thigh)
/// are left for the tailor to measure by hand.
const fieldSource = <String, String>{
  'Chest': 'chest', 'Bust': 'chest', 'Waist': 'waist', 'Trouser waist': 'waist', 'Hip': 'hip',
  'Shoulder': 'shoulderWidth', 'Sleeve': 'sleeve',
  'Top length': 'shoulderToHip', 'Blouse length': 'shoulderToWaist',
  'Agbada length': 'shoulderToAnkle', 'Gown length': 'shoulderToAnkle',
  'Wrapper length': 'waistToAnkle', 'Trouser length': 'waistToAnkle',
};
