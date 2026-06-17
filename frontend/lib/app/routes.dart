import 'package:get/get.dart';

import '../pages/index/index_page.dart';

class AppRoutes {
  const AppRoutes._();

  static const index = '/';

  static final pages = <GetPage>[
    GetPage(name: index, page: () => const IndexPage()),
  ];
}
