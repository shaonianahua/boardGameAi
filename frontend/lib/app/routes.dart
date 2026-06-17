import 'package:get/get.dart';

import '../pages/index/index_page.dart';
import '../pages/splendor/splendor_create_session_page.dart';
import '../pages/splendor/splendor_table_page.dart';

/// App 路由集中登记表。
///
/// 页面跳转统一从这里取路由名，避免页面里散落字符串。
class AppRoutes {
  const AppRoutes._();

  /// 首页路由。
  static const index = '/';

  /// 璀璨宝石创建对局页。
  static const splendorCreateSession = '/splendor/create-session';

  /// 璀璨宝石对局桌面页。
  static const splendorTable = '/splendor/table';

  /// GetX 页面配置。
  static final pages = <GetPage>[
    GetPage(name: index, page: () => const IndexPage()),
    GetPage(
      name: splendorCreateSession,
      page: () => const SplendorCreateSessionPage(),
    ),
    GetPage(name: splendorTable, page: () => const SplendorTablePage()),
  ];
}
