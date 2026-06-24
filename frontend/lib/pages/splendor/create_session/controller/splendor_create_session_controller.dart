import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../api/splendor_api.dart';
import '../../../../app/routes.dart';
import '../../../../models/api_models.dart';
import '../../../../models/splendor_models.dart';

/// 璀璨宝石创建对局页控制器。
///
/// 负责管理人数、玩家名称、创建对局接口调用和成功跳转。
class SplendorCreateSessionController extends GetxController {
  /// 创建一个新的对局页控制器。
  SplendorCreateSessionController({SplendorApi? splendorApi})
    : _splendorApi = splendorApi ?? SplendorApi();

  final SplendorApi _splendorApi;

  /// 当前玩家人数。
  final RxInt playerCount = 2.obs;

  /// 创建对局中的加载状态。
  final RxBool isSubmitting = false.obs;

  /// 当前表单里的玩家名称输入框，固定保留 4 个以覆盖 2-4 人。
  final List<TextEditingController> nameControllers =
      List<TextEditingController>.generate(
        4,
        (index) => TextEditingController(text: '玩家${index + 1}'),
      );

  /// 当前表单里每个座位的控制方式，固定保留 4 个以覆盖 2-4 人。
  final List<Rx<SplendorSeatControlType>> seatControlTypes =
      List<Rx<SplendorSeatControlType>>.generate(
        4,
        (_) => SplendorSeatControlType.human.obs,
      );

  /// 更新玩家人数。
  void setPlayerCount(int value) {
    playerCount.value = value;
  }

  /// 设置某个座位由真人、本地 Bot 还是 AI 玩家控制。
  void setSeatControlType(int index, SplendorSeatControlType type) {
    if (index < 0 || index >= seatControlTypes.length) {
      return;
    }
    seatControlTypes[index].value = type;
  }

  /// 创建璀璨宝石对局，成功后进入桌面页。
  Future<void> createSession() async {
    final players = nameControllers
        .take(playerCount.value)
        .map((controller) => controller.text.trim())
        .toList(growable: false);

    if (players.any((name) => name.isEmpty)) {
      _showMessage('请填写玩家名称');
      return;
    }

    isSubmitting.value = true;

    try {
      final createPlayers = <SplendorCreatePlayerInput>[
        for (var index = 0; index < players.length; index += 1)
          SplendorCreatePlayerInput(
            name: players[index],
            type: seatControlTypes[index].value.playerType,
            botLevel: seatControlTypes[index].value.botLevel,
          ),
      ];

      final response = await _splendorApi.createSession(
        SplendorCreateSessionInput(
          playerCount: playerCount.value,
          title: '璀璨宝石本地对局',
          players: createPlayers,
        ),
      );

      Get.offNamed(AppRoutes.splendorTable, arguments: response);
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('创建对局失败，请确认后端服务已启动');
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 在创建对局页展示轻量提示，主要用于表单校验和接口错误。
  void _showMessage(String message) {
    Get.snackbar(
      '创建对局',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      duration: const Duration(seconds: 2),
    );
  }

  /// Controller 销毁时释放玩家名称输入框，避免页面退出后持有资源。
  @override
  void onClose() {
    for (final controller in nameControllers) {
      controller.dispose();
    }
    super.onClose();
  }
}
