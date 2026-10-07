import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the real Roboto and Material Icons fonts that ship with the Flutter
/// SDK, so widget tests measure text like a real Android device instead of
/// with the blocky test font. Falls back silently if they can't be found.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final dir = Directory('$root/bin/cache/artifacts/material_fonts');
    if (dir.existsSync()) {
      Future<ByteData> read(String name) async =>
          ByteData.sublistView(Uint8List.fromList(File('${dir.path}/$name').readAsBytesSync()));
      final roboto = FontLoader('Roboto');
      for (final w in ['Thin', 'Light', 'Regular', 'Medium', 'Bold', 'Black']) {
        roboto.addFont(read('Roboto-$w.ttf'));
      }
      await roboto.load();
      await (FontLoader('MaterialIcons')..addFont(read('MaterialIcons-Regular.otf'))).load();
    }
  }
  await testMain();
}
