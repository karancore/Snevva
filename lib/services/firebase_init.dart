import 'package:firebase_core/firebase_core.dart';
import 'package:snevva/firebase_options.dart';

class FirebaseInit {
  static bool _done = false;
  static Future<void> init() async {
    if (_done) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on Exception catch (_) {}
    _done = false;
  }
}
