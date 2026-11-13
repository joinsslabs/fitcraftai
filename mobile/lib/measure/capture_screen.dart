// In-app camera for the measurement photos: live preview, the pose outline to stand in, an optional
// 3-second self-timer, and a shutter button. Works in the Android app and in the browser (getUserMedia).
// Returns the photo's path, or null if cancelled.
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';

class CaptureScreen extends StatefulWidget {
  final bool front;
  const CaptureScreen({super.key, required this.front});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _ctrl;
  List<CameraDescription> _cams = [];
  int _camIndex = 0;
  String? _error;
  int? _countdown;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _cams = await availableCameras();
      if (_cams.isEmpty) throw CameraException('none', 'No camera found on this device.');
      // Prefer the back camera: a helper photographs the customer.
      final back = _cams.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _camIndex = back >= 0 ? back : 0;
      await _open();
    } on CameraException catch (e) {
      setState(() => _error = e.code == 'CameraAccessDenied' || e.code == 'cameraPermission' || e.code == 'notAllowedError'
          ? 'Camera access was blocked. Allow the camera for this app (or this site in your browser settings) and try again.'
          : 'The camera could not start: ${e.description ?? e.code}');
    }
  }

  Future<void> _open() async {
    final old = _ctrl;
    final c = CameraController(_cams[_camIndex], ResolutionPreset.high, enableAudio: false);
    await c.initialize();
    await old?.dispose();
    if (!mounted) return;
    setState(() => _ctrl = c);
  }

  Future<void> _switch() async {
    if (_cams.length < 2) return;
    _camIndex = (_camIndex + 1) % _cams.length;
    await _open();
  }

  Future<void> _shoot({bool timer = false}) async {
    if (_ctrl == null || _busy) return;
    setState(() => _busy = true);
    if (timer) {
      for (var i = 3; i > 0; i--) {
        setState(() => _countdown = i);
        await Future.delayed(const Duration(seconds: 1));
        if (!mounted) return;
      }
      setState(() => _countdown = null);
    }
    try {
      final x = await _ctrl!.takePicture();
      if (mounted) Navigator.pop(context, x.path);
    } catch (e) {
      setState(() { _busy = false; _error = 'Could not take the photo ($e). Try again.'; });
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.front ? 'Front photo' : 'Side photo'),
          actions: [if (_cams.length > 1) IconButton(tooltip: 'Switch camera', onPressed: _switch, icon: const Icon(Icons.cameraswitch))]),
      body: _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.no_photography, color: Colors.white70, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              FilledButton(onPressed: () { setState(() => _error = null); _start(); }, child: const Text('Try again')),
            ])))
          : c == null || !c.value.isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Stack(fit: StackFit.expand, children: [
                  Center(child: CameraPreview(c)),
                  // The outline to stand in: whole body, head to feet.
                  IgnorePointer(child: CustomPaint(painter: _GuidePainter(front: widget.front))),
                  Positioned(top: 12, left: 16, right: 16, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                    child: Text(widget.front ? 'Fit the whole body inside the outline, facing the camera, arms a little away from the body.' : 'Turn to the side, arms down, whole body inside the outline.',
                        textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  )),
                  if (_countdown != null) Center(child: Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 96, fontWeight: FontWeight.w900))),
                  Positioned(bottom: 24, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    TextButton.icon(onPressed: _busy ? null : () => _shoot(timer: true), icon: const Icon(Icons.timer_3, color: Colors.white), label: const Text('3 s timer', style: TextStyle(color: Colors.white))),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: _busy ? null : () => _shoot(),
                      child: Container(width: 76, height: 76, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
                          child: Padding(padding: const EdgeInsets.all(5), child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: _busy ? Colors.white38 : Colors.white)))),
                    ),
                    const SizedBox(width: 92),
                  ])),
                ]),
    );
  }
}

class _GuidePainter extends CustomPainter {
  final bool front;
  _GuidePainter({required this.front});
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0xCC34D399)..strokeWidth = 4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final h = s.height * 0.72, top = s.height * 0.14, cx = s.width / 2, u = h / 8;
    canvas.drawCircle(Offset(cx, top + u * 0.5), u * 0.45, p);
    canvas.drawLine(Offset(cx, top + u), Offset(cx, top + u * 4), p);
    if (front) {
      canvas.drawLine(Offset(cx, top + u * 1.4), Offset(cx - u * 1.6, top + u * 3.6), p);
      canvas.drawLine(Offset(cx, top + u * 1.4), Offset(cx + u * 1.6, top + u * 3.6), p);
      canvas.drawLine(Offset(cx, top + u * 4), Offset(cx - u * 0.7, top + h), p);
      canvas.drawLine(Offset(cx, top + u * 4), Offset(cx + u * 0.7, top + h), p);
    } else {
      canvas.drawLine(Offset(cx, top + u * 1.4), Offset(cx + u * 0.2, top + u * 3.8), p);
      canvas.drawLine(Offset(cx, top + u * 4), Offset(cx, top + h), p);
      canvas.drawLine(Offset(cx, top + h), Offset(cx + u * 0.6, top + h), p);
    }
    // Floor line: feet must be above it.
    canvas.drawLine(Offset(cx - u * 2, top + h + 6), Offset(cx + u * 2, top + h + 6), p..color = const Color(0x8834D399));
  }

  @override
  bool shouldRepaint(_GuidePainter o) => o.front != front;
}
