import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import 'player_count_selector.dart';
import 'splendor_create_session_controller.dart';

/// 璀璨宝石创建对局页。
///
/// 负责收集玩家人数和玩家名称，并触发创建对局。
class SplendorCreateSessionPage extends StatefulWidget {
  /// 构造创建对局页。
  const SplendorCreateSessionPage({super.key});

  @override
  State<SplendorCreateSessionPage> createState() =>
      _SplendorCreateSessionPageState();
}

class _SplendorCreateSessionPageState extends State<SplendorCreateSessionPage> {
  late final SplendorCreateSessionController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(SplendorCreateSessionController());
  }

  @override
  void dispose() {
    Get.delete<SplendorCreateSessionController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('创建璀璨宝石对局')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          children: [
            Text(
              '选择玩家',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '先创建本地同屏对局，规则判断由后端统一处理。',
              style: textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
            SizedBox(height: 20.h),
            Obx(
              () => PlayerCountSelector(
                playerCount: controller.playerCount.value,
                onChanged: controller.setPlayerCount,
              ),
            ),
            SizedBox(height: 18.h),
            Obx(
              () => Column(
                children: List<Widget>.generate(controller.playerCount.value, (
                  index,
                ) {
                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: TextField(
                      controller: controller.nameControllers[index],
                      textInputAction: index == controller.playerCount.value - 1
                          ? TextInputAction.done
                          : TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: '玩家 ${index + 1}',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: 8.h),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isSubmitting.value
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        controller.createSession();
                      },
                icon: controller.isSubmitting.value
                    ? SizedBox(
                        width: 18.w,
                        height: 18.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(controller.isSubmitting.value ? '创建中' : '开始对局'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
