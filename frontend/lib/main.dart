import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Uncaught app error: $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  };

  await runZonedGuarded(() async {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    runApp(const BoardGameAiApp());
  }, (error, stackTrace) {
    debugPrint('Zone error: $error');
    debugPrintStack(stackTrace: stackTrace);
  });
}
