import 'package:marionette_flutter/marionette_flutter.dart';
import 'main.dart' as app;

/// The app with the Marionette binding, so tools such as the Marionette MCP
/// server can drive it. Run with `flutter run -t lib/main_dev.dart`.
Future<void> main() async {
  MarionetteBinding.ensureInitialized();
  await app.main();
}
