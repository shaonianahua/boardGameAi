import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../shared/widgets/mobile_viewport.dart';
import 'routes.dart';
import 'theme.dart';

class BoardGameAiApp extends StatelessWidget {
  const BoardGameAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          title: 'AI人玩桌游',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          initialRoute: AppRoutes.index,
          getPages: AppRoutes.pages,
          builder: (context, child) {
            return MobileViewport(child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}
