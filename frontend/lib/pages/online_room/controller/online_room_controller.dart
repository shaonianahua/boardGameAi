import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../api/online_api.dart';
import '../../../models/api_models.dart';
import '../../../models/online_room_models.dart';

/// 在线房间页面控制器。
///
/// 负责创建房间、加入房间、保存客户端临时 ID、订阅房间 WebSocket 更新和维护页面状态。
class OnlineRoomController extends GetxController {
  /// 构造在线房间控制器，允许注入 API 方便测试。
  OnlineRoomController({OnlineApi? onlineApi})
    : _onlineApi = onlineApi ?? OnlineApi();

  static const _clientIdKey = 'online_room_client_id';

  final OnlineApi _onlineApi;
  final _uuid = const Uuid();
  StreamSubscription<OnlineRoomEvent>? _roomSubscription;

  /// 创建房间时使用的房主名称输入框。
  final TextEditingController hostNameController = TextEditingController(
    text: '玩家1',
  );

  /// 加入房间时使用的玩家名称输入框。
  final TextEditingController joinNameController = TextEditingController(
    text: '玩家2',
  );

  /// 加入房间时输入的 6 位房间码。
  final TextEditingController roomCodeController = TextEditingController();

  /// 当前房间快照；为空代表还没有进入房间。
  final Rxn<OnlineRoom> room = Rxn<OnlineRoom>();

  /// 当前 REST 请求提交状态，用于禁用按钮和展示 loading。
  final RxBool isSubmitting = false.obs;

  /// WebSocket 是否已进入监听流程；不代表网络一定永久可用。
  final RxBool isWatching = false.obs;

  /// 当前页面提示信息，主要展示实时连接状态和错误。
  final RxString statusMessage = '创建或加入在线房间后，会在这里显示座位。'.obs;

  /// 当前设备的临时 clientId，用于重复进入同一房间时找回座位。
  final RxString clientId = ''.obs;

  /// 页面初始化时准备 clientId，保证创建和加入房间都能复用同一设备标识。
  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadClientId();
  }

  /// 创建一个璀璨宝石在线房间，并自动订阅房间事件。
  Future<void> createRoom() async {
    final hostName = hostNameController.text.trim();
    if (hostName.isEmpty) {
      _showMessage('请填写房主名称');
      return;
    }

    await _submitRoomRequest(() {
      return _onlineApi.createRoom(
        CreateOnlineRoomInput(hostName: hostName, clientId: clientId.value),
      );
    });
  }

  /// 使用房间码加入在线房间，并自动订阅房间事件。
  Future<void> joinRoom() async {
    final playerName = joinNameController.text.trim();
    final roomCode = roomCodeController.text.trim();
    if (playerName.isEmpty) {
      _showMessage('请填写玩家名称');
      return;
    }
    if (roomCode.isEmpty) {
      _showMessage('请填写房间码');
      return;
    }

    await _submitRoomRequest(() {
      return _onlineApi.joinRoom(
        JoinOnlineRoomInput(
          roomCode: roomCode,
          playerName: playerName,
          clientId: clientId.value,
        ),
      );
    });
  }

  /// 主动刷新当前房间快照，WebSocket 临时断开时可以手动拉取最新状态。
  Future<void> refreshRoom() async {
    final currentRoom = room.value;
    if (currentRoom == null || currentRoom.roomCode.isEmpty) {
      return;
    }

    try {
      final latestRoom = await _onlineApi.getRoom(currentRoom.roomCode);
      room.value = latestRoom;
      statusMessage.value = '房间信息已刷新';
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('刷新房间失败，请确认后端服务已启动');
    }
  }

  /// 离开当前房间页面状态，关闭 WebSocket 订阅但不删除后端房间。
  Future<void> leaveRoom() async {
    await _roomSubscription?.cancel();
    _roomSubscription = null;
    isWatching.value = false;
    room.value = null;
    statusMessage.value = '已离开当前房间';
  }

  /// 统一执行创建/加入房间请求，成功后保存快照并启动实时订阅。
  Future<void> _submitRoomRequest(Future<OnlineRoom> Function() request) async {
    if (isSubmitting.value) {
      return;
    }

    isSubmitting.value = true;
    try {
      final nextRoom = await request();
      room.value = nextRoom;
      statusMessage.value = '已进入房间 ${nextRoom.roomCode}';
      await _watchRoom(nextRoom.roomCode);
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('房间操作失败，请确认后端服务已启动');
    } finally {
      isSubmitting.value = false;
    }
  }

  /// 订阅指定房间的 WebSocket 事件，并用事件里的 room 快照刷新页面。
  Future<void> _watchRoom(String roomCode) async {
    await _roomSubscription?.cancel();
    isWatching.value = true;
    statusMessage.value = '正在监听房间变化';

    _roomSubscription = _onlineApi
        .watchRoomEvents(roomCode)
        .listen(
          (event) {
            room.value = event.room;
            statusMessage.value = event.type == 'room_snapshot'
                ? '已连接房间实时更新'
                : '房间座位已更新';
          },
          onError: (Object error) {
            isWatching.value = false;
            final message = error is ApiException
                ? error.error.message
                : '房间实时连接已断开';
            statusMessage.value = message;
          },
          onDone: () {
            isWatching.value = false;
          },
        );
  }

  /// 读取或创建本机临时 clientId，供后端识别同一设备重复加入。
  Future<void> _loadClientId() async {
    final preferences = await SharedPreferences.getInstance();
    final savedClientId = preferences.getString(_clientIdKey);
    if (savedClientId != null && savedClientId.isNotEmpty) {
      clientId.value = savedClientId;
      return;
    }

    final nextClientId = _uuid.v4();
    await preferences.setString(_clientIdKey, nextClientId);
    clientId.value = nextClientId;
  }

  /// 展示在线房间页的轻量提示，主要用于表单校验和接口错误。
  void _showMessage(String message) {
    statusMessage.value = message;
    Get.snackbar(
      '在线房间',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 8,
      duration: const Duration(seconds: 2),
    );
  }

  /// 页面销毁时释放输入框和实时订阅。
  @override
  void onClose() {
    _roomSubscription?.cancel();
    hostNameController.dispose();
    joinNameController.dispose();
    roomCodeController.dispose();
    super.onClose();
  }
}
