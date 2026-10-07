import 'package:mood_bunny/bunny/desktop_pet.dart';

/// Dev preview entry for the desktop pet (transparent always-on-top window).
///
/// Run: `flutter run -d windows -t lib/pet_main.dart`
/// Release uses the normal exe + `--pet` arg (see [runDesktopPet]).
Future<void> main(List<String> args) => runDesktopPet();
