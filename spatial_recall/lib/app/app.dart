import 'package:flutter/material.dart';

import '../screens/splash_screen.dart';
import '../state/app_state.dart';
import 'theme.dart';

class SpatialRecallApp extends StatelessWidget {
  const SpatialRecallApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
    state: state,
    child: MaterialApp(
      title: 'Spatial Recall',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const SplashScreen(),
    ),
  );
}
