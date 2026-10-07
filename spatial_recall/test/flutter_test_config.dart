import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's real fonts (Poppins from assets/, Material Icons from the
/// Flutter SDK) so widget tests measure text like a real device instead of
/// with the blocky test font.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  Future<ByteData> read(String path) async => ByteData.sublistView(Uint8List.fromList(File(path).readAsBytesSync()));

  final poppins = FontLoader('Poppins');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    poppins.addFont(read('assets/fonts/Poppins-$w.ttf'));
  }
  await poppins.load();

  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (root != null && icons.existsSync()) {
    await (FontLoader('MaterialIcons')..addFont(read(icons.path))).load();
  }
  await testMain();
}
