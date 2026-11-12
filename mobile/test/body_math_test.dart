import 'package:fitcraft/measure/body_math.dart';
import 'package:flutter_test/flutter_test.dart';

// A synthetic 175 cm person photographed at exactly 0.1 cm per pixel, so every expected value is known.
const h = 175.0, cmPx = 0.1, eyeY = 150.0;
final heelY = eyeY + eyeHeightRatio * h / cmPx; // 1788

Mask rect(int w, int hgt, int x0, int x1) =>
    Mask(w, hgt, List.generate(w * hgt, (i) => (i % w >= x0 && i % w < x1) ? 1.0 : 0.0));

Shot person({required bool sideView}) {
  final p = <String, Pt>{
    'leftEye': Pt(480, eyeY), 'rightEye': Pt(520, eyeY),
    'leftShoulder': Pt(300, 380), 'rightShoulder': Pt(700, 380),
    'leftElbow': Pt(280, 650), 'rightElbow': Pt(720, 650),
    'leftWrist': Pt(270, 900), 'rightWrist': Pt(730, 900),
    'leftHip': Pt(400, 900), 'rightHip': Pt(600, 900),
    'leftKnee': Pt(400, 1350), 'rightKnee': Pt(600, 1350),
    'leftAnkle': Pt(400, 1760), 'rightAnkle': Pt(600, 1760),
    'leftHeel': Pt(400, heelY), 'rightHeel': Pt(600, heelY),
  };
  // Front outline 340 px wide (34 cm) centred on the body; side outline 240 px deep (24 cm) around the
  // side photo's shoulder-hip line (x = 350). Masks are at quarter resolution.
  final mask = sideView ? rect(250, 500, 58, 118) : rect(250, 500, 83, 168);
  return Shot(1000, 2000, p, mask);
}

void main() {
  test('scale comes from height and eye-to-heel distance', () {
    expect(cmPerPixel(person(sideView: false), h), closeTo(cmPx, 1e-9));
  });

  test('lengths and circumferences from a known body', () {
    final m = measureBody(front: person(sideView: false), side: person(sideView: true), heightCm: h);
    expect(m['shoulderWidth']!.cm, closeTo(40, 0.01));
    expect(m['shoulderToHip']!.cm, closeTo(52, 0.01));
    final sleevePx = Pt(300, 380).dist(Pt(280, 650)) + Pt(280, 650).dist(Pt(270, 900));
    expect(m['sleeve']!.cm, closeTo(sleevePx * cmPx, 0.01));
    // Mask is 1/4 resolution: 85 cols * 4 = 340 px wide, 60 * 4 = 240 px deep.
    expect(m['chest']!.cm, closeTo(ellipsePerimeter(34, 24), 0.01));
    expect(m['chest']!.confidence, Confidence.estimate);
    expect(m['sleeve']!.confidence, Confidence.good);
  });

  test('ellipse perimeter is right for a circle', () {
    expect(ellipsePerimeter(20, 20), closeTo(62.83, 0.01));
  });

  test('missing feet gives a clear retake message', () {
    final s = person(sideView: false);
    final noFeet = Shot(s.imageWidth, s.imageHeight, {...s.points, 'leftHeel': const Pt(400, 1788, 0.1)}, s.mask);
    expect(() => cmPerPixel(noFeet, h), throwsA(isA<ScanError>().having((e) => e.message, 'message', contains('feet'))));
  });

  test('standing too far away is caught', () {
    final s = person(sideView: false);
    final small = Shot(1000, 5000, s.points, s.mask);
    expect(() => cmPerPixel(small, h), throwsA(isA<ScanError>()));
  });
}
