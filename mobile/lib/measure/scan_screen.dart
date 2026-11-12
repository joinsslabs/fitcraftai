// Measure with photos: height → front photo → side photo → AI estimates → tailor reviews and confirms.
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import 'body_math.dart';
import 'scanner.dart' if (dart.library.js_interop) 'scanner_web.dart';

/// Returns the confirmed measurements (field → inches as text), or null if cancelled.
class ScanScreen extends StatefulWidget {
  final Template template;
  final String customer;
  const ScanScreen({super.key, required this.template, required this.customer});
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

enum _Step { height, front, side, working, review }

class _ScanScreenState extends State<ScanScreen> {
  final _height = TextEditingController();
  final _picker = ImagePicker();
  _Step step = _Step.height;
  String? frontPath, sidePath, error;
  Map<String, Measure> result = {};
  final fields = <String, TextEditingController>{};

  double? get heightCm => double.tryParse(_height.text.trim());

  Future<void> _take(bool front, {bool gallery = false}) async {
    final x = await _picker.pickImage(source: gallery ? ImageSource.gallery : ImageSource.camera, maxWidth: 1600, imageQuality: 90);
    if (x == null) return;
    setState(() {
      error = null;
      if (front) {
        frontPath = x.path;
        step = _Step.side;
      } else {
        sidePath = x.path;
      }
    });
    if (!front) await _analyse();
  }

  Future<void> _analyse() async {
    setState(() => step = _Step.working);
    final scanner = Scanner();
    try {
      final f = await scanner.read(frontPath!), s = await scanner.read(sidePath!);
      result = measureBody(front: f, side: s, heightCm: heightCm!);
      for (final field in widget.template.fields) {
        final src = fieldSource[field];
        final m = src == null ? null : result[src];
        fields[field] = TextEditingController(text: m == null ? '' : ((m.inches * 4).round() / 4).toString()); // nearest quarter inch
      }
      setState(() => step = _Step.review);
    } on ScanError catch (e) {
      setState(() {
        error = e.message;
        step = _Step.front;
      });
    } catch (e) {
      setState(() {
        error = 'The photos could not be read ($e). Try again in good light.';
        step = _Step.front;
      });
    } finally {
      await scanner.close();
    }
  }

  bool demo = false;

  /// Browser preview only: plausible sample values so the review screen can be tried. Never used on a phone.
  void _showExample() {
    const sample = {'chest': 99.0, 'waist': 86.0, 'hip': 104.0, 'shoulderWidth': 46.0, 'sleeve': 61.0, 'shoulderToWaist': 44.0,
      'shoulderToHip': 56.0, 'shoulderToAnkle': 140.0, 'waistToAnkle': 102.0};
    result = {for (final e in sample.entries) e.key: Measure(e.value, ['chest', 'waist', 'hip'].contains(e.key) ? Confidence.estimate : Confidence.good)};
    for (final field in widget.template.fields) {
      final src = fieldSource[field];
      final m = src == null ? null : result[src];
      fields[field] = TextEditingController(text: m == null ? '' : ((m.inches * 4).round() / 4).toString());
    }
    setState(() { demo = true; step = _Step.review; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Measure ${widget.customer}')),
      body: SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: _body(context))),
    );
  }

  Widget _body(BuildContext context) {
    final t = Theme.of(context).textTheme;
    switch (step) {
      case _Step.height:
        return ListView(children: [
          Text('Measure with two photos', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text('You need: a helper to hold the phone, 2 to 3 metres of space, good light, and fitted clothes (no agbada or loose gown while measuring).'),
          const SizedBox(height: 20),
          TextField(controller: _height, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Height in cm', helperText: 'Needed to turn the photo into real sizes', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {})),
          const SizedBox(height: 20),
          FilledButton(onPressed: (heightCm ?? 0) >= 100 && (heightCm ?? 0) <= 230 ? () => setState(() => step = _Step.front) : null, child: const Text('Next: front photo')),
        ]);
      case _Step.front:
      case _Step.side:
        final front = step == _Step.front;
        return ListView(children: [
          if (error != null) Container(margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(12)), child: Text(error!)),
          Text(front ? 'Photo 1 of 2: front' : 'Photo 2 of 2: side', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Center(child: SizedBox(height: 220, width: 140, child: CustomPaint(painter: _PosePainter(front: front)))),
          const SizedBox(height: 12),
          Text(front
              ? '• Face the camera, feet slightly apart.\n• Arms a little away from the body, like this outline.\n• Whole body in the photo, head to feet, phone at waist height.'
              : '• Turn to your right, arms down by your sides.\n• Stand straight, look ahead.\n• Same distance as the first photo, whole body in frame.'),
          const SizedBox(height: 20),
          FilledButton.icon(onPressed: () => _take(front), icon: const Icon(Icons.photo_camera), label: Text(front ? 'Take front photo' : 'Take side photo')),
          TextButton(onPressed: () => _take(front, gallery: true), child: const Text('Use a photo from the gallery')),
          if (kIsWeb) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Text('Browser preview: the photo AI runs in the Android app. Tap below to see what the result screen looks like.')),
            OutlinedButton(onPressed: _showExample, child: const Text('Show an example result')),
          ],
        ]);
      case _Step.working:
        return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(), SizedBox(height: 16), Text('Finding body points and outline…'), SizedBox(height: 4), Text('This runs on the phone. Nothing is uploaded.'),
        ]));
      case _Step.review:
        return Column(children: [
          Expanded(child: ListView(children: [
            Text('Check before saving', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (demo) Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(10)),
                child: const Text('Example values for the preview, not measured from any photo.')),
            const Text('AI estimates in inches. Correct anything that looks wrong; fields marked "measure by hand" need the tape.'),
            const SizedBox(height: 12),
            for (final f in widget.template.fields) _row(f),
          ])),
          FilledButton(
            onPressed: () => Navigator.pop(context, {for (final e in fields.entries) if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim()}),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            child: const Text('Confirm measurements'),
          ),
        ]);
    }
  }

  Widget _row(String field) {
    final src = fieldSource[field];
    final m = src == null ? null : result[src];
    final (label, color) = switch (m?.confidence) {
      Confidence.good => ('Good', Colors.green),
      Confidence.check => ('Check', Colors.orange),
      Confidence.estimate => ('Estimate', Colors.deepOrange),
      null => ('Measure by hand', Colors.grey),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(flex: 3, child: Text(field, style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(flex: 3, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: color.shade800, fontSize: 12, fontWeight: FontWeight.w700)))),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: TextField(controller: fields[field], keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(isDense: true, suffixText: 'in', border: OutlineInputBorder()))),
      ]),
    );
  }
}

/// A simple outline of the pose to copy.
class _PosePainter extends CustomPainter {
  final bool front;
  _PosePainter({required this.front});
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()..color = const Color(0xFF065F46)..strokeWidth = 5..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final cx = s.width / 2;
    c.drawCircle(Offset(cx, 22), 16, p);
    c.drawLine(Offset(cx, 40), Offset(cx, 120), p);
    if (front) {
      c.drawLine(Offset(cx, 55), Offset(cx - 45, 115), p);
      c.drawLine(Offset(cx, 55), Offset(cx + 45, 115), p);
      c.drawLine(Offset(cx, 120), Offset(cx - 22, 210), p);
      c.drawLine(Offset(cx, 120), Offset(cx + 22, 210), p);
    } else {
      c.drawLine(Offset(cx, 55), Offset(cx + 4, 125), p);
      c.drawLine(Offset(cx, 120), Offset(cx, 210), p);
      c.drawLine(Offset(cx, 210), Offset(cx + 18, 210), p);
    }
  }

  @override
  bool shouldRepaint(_PosePainter o) => o.front != front;
}
