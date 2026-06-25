import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../app/app_colors.dart';
import '../../models/online_room_models.dart';
import 'controller/online_room_controller.dart';

/// 在线房间大厅页。
///
/// 当前阶段只支持创建房间、输入房间码加入、展示 4 个座位和监听房间更新。
class OnlineRoomPage extends StatefulWidget {
  /// 构造在线房间大厅页。
  const OnlineRoomPage({super.key});

  @override
  State<OnlineRoomPage> createState() => _OnlineRoomPageState();
}

class _OnlineRoomPageState extends State<OnlineRoomPage> {
  late final OnlineRoomController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(OnlineRoomController());
  }

  @override
  void dispose() {
    Get.delete<OnlineRoomController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('在线房间')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          children: [
            const _RoomIntroCard(),
            SizedBox(height: 14.h),
            Obx(() {
              final room = controller.room.value;
              if (room == null) {
                return _EnterRoomPanel(controller: controller);
              }
              return _RoomLobbyPanel(controller: controller, room: room);
            }),
          ],
        ),
      ),
    );
  }
}

/// 在线房间入口说明卡，提示当前阶段的能力边界。
class _RoomIntroCard extends StatelessWidget {
  const _RoomIntroCard();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hub_outlined, color: colorScheme.primary),
                SizedBox(width: 8.w),
                Text(
                  '璀璨宝石在线房间',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              '当前只做等待大厅：创建房间、加入房间、同步座位。开始在线对局会在下一阶段接入。',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.66),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 创建或加入在线房间的表单区域。
class _EnterRoomPanel extends StatelessWidget {
  const _EnterRoomPanel({required this.controller});

  final OnlineRoomController controller;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '创建房间',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: controller.hostNameController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '房主名称',
                    prefixIcon: const Icon(Icons.person_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Obx(
                  () => FilledButton.icon(
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            controller.createRoom();
                          },
                    icon: controller.isSubmitting.value
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.add_circle_outline_rounded),
                    label: Text(
                      controller.isSubmitting.value ? '处理中' : '创建在线房间',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '加入房间',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: controller.joinNameController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: '玩家名称',
                    prefixIcon: const Icon(Icons.person_add_alt_1_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                TextField(
                  controller: controller.roomCodeController,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '房间码',
                    prefixIcon: const Icon(Icons.tag_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                SizedBox(height: 12.h),
                Obx(
                  () => OutlinedButton.icon(
                    onPressed: controller.isSubmitting.value
                        ? null
                        : () {
                            FocusScope.of(context).unfocus();
                            controller.joinRoom();
                          },
                    icon: const Icon(Icons.login_rounded),
                    label: Text(
                      controller.isSubmitting.value ? '处理中' : '加入在线房间',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Obx(() => _StatusLine(message: controller.statusMessage.value)),
      ],
    );
  }
}

/// 已进入房间后的等待大厅区域。
class _RoomLobbyPanel extends StatelessWidget {
  const _RoomLobbyPanel({required this.controller, required this.room});

  final OnlineRoomController controller;
  final OnlineRoom room;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '房间码',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.62,
                              ),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            room.roomCode,
                            style: textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Obx(
                      () => _ConnectionBadge(
                        connected: controller.isWatching.value,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Obx(() => _StatusLine(message: controller.statusMessage.value)),
              ],
            ),
          ),
        ),
        SizedBox(height: 14.h),
        Text(
          '房间座位',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 10.h),
        for (var index = 0; index < 4; index += 1) ...[
          _SeatTile(
            seatIndex: index,
            seat: room.seatAt(index),
            isHostSeat: room.hostSeatIndex == index,
          ),
          SizedBox(height: 10.h),
        ],
        SizedBox(height: 4.h),

        // 开始游戏按钮（仅房主且房间等待中时显示）
        if (room.status == OnlineRoomStatus.waiting &&
            room.hostSeatIndex != null) ...[
          Builder(
            builder: (context) {
              final myClientId = controller.clientId.value;
              final hostSeat = room.seats.firstWhere(
                (seat) => seat.seatIndex == room.hostSeatIndex,
                orElse: () => room.seats.first,
              );
              final isHost = hostSeat.clientId == myClientId;

              if (!isHost) {
                return const SizedBox.shrink();
              }

              return Obx(
                () => FilledButton.icon(
                  onPressed: controller.isSubmitting.value ||
                          room.seats.length < 2
                      ? null
                      : controller.startGame,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('开始游戏'),
                  style: FilledButton.styleFrom(
                    minimumSize: Size(double.infinity, 48.h),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 10.h),
        ],

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.refreshRoom,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('刷新房间'),
              ),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: controller.leaveRoom,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('离开房间'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 单个座位展示组件，显示玩家名、控制方式、房主标记和连接状态。
class _SeatTile extends StatelessWidget {
  const _SeatTile({
    required this.seatIndex,
    required this.seat,
    required this.isHostSeat,
  });

  final int seatIndex;
  final OnlineRoomSeat? seat;
  final bool isHostSeat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final currentSeat = seat;
    final occupied = currentSeat != null;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: occupied
            ? Colors.white
            : AppColors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: occupied
              ? colorScheme.primary.withValues(alpha: 0.28)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: occupied
                  ? colorScheme.primary.withValues(alpha: 0.12)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${seatIndex + 1}',
              style: textTheme.titleMedium?.copyWith(
                color: occupied
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.48),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentSeat?.playerName ?? '等待玩家加入',
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: occupied
                        ? colorScheme.onSurface
                        : colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  occupied ? _controlTypeText(currentSeat.controlType) : '空座位',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.58),
                  ),
                ),
              ],
            ),
          ),
          if (isHostSeat) const _SmallTag(label: '房主'),
          if (occupied) ...[
            SizedBox(width: 8.w),
            _SmallTag(label: currentSeat.connected ? '在线' : '离线'),
          ],
        ],
      ),
    );
  }

  /// 把座位控制类型转换成页面展示文案。
  String _controlTypeText(OnlineSeatControlType type) {
    return switch (type) {
      OnlineSeatControlType.human => '真人玩家',
      OnlineSeatControlType.localBot => '本地 Bot',
      OnlineSeatControlType.aiPlayer => 'AI 玩家',
    };
  }
}

/// 房间实时连接状态标签。
class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final color = connected ? AppColors.primary : AppColors.error;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        connected ? '实时连接' : '未连接',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 小型状态标签，用于房主、在线等短文本。
class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// 页面底部状态行，展示当前房间操作或实时连接提示。
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.62),
      ),
    );
  }
}
