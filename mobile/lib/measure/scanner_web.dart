// Browser preview: ML Kit runs only on Android and iOS, so photo analysis is not available here.
import 'body_math.dart';

class Scanner {
  Future<Shot> read(String path) async =>
      throw ScanError('Photo measurement runs in the Android app. In this browser preview, use "Show an example result".');
  Future<void> close() async {}
}
