import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../api/splendor_api.dart';
import '../../app/routes.dart';
import '../../models/api_models.dart';
import '../../models/splendor_models.dart';

/// 璀璨宝石创建对局页。
///
/// 负责收集玩家人数和玩家名称，并调用后端创建本地同屏对局。
class SplendorCreateSessionPage extends StatefulWidget {
  const SplendorCreateSessionPage({super.key});

  @override
  State<SplendorCreateSessionPage> createState() =>
      _SplendorCreateSessionPageState();
}

class _SplendorCreateSessionPageState extends State<SplendorCreateSessionPage> {
  final SplendorApi _splendorApi = SplendorApi();
  final List<TextEditingController> _nameControllers =
      List<TextEditingController>.generate(
        4,
        (index) => TextEditingController(text: '玩家${index + 1}'),
      );

  int _playerCount = 2;
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final controller in _nameControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// 调用创建对局接口，成功后把完整对局响应传给桌面页。
  Future<void> _createSession() async {
    FocusScope.of(context).unfocus();

    final players = _nameControllers
        .take(_playerCount)
        .map((controller) => controller.text.trim())
        .toList(growable: false);

    if (players.any((name) => name.isEmpty)) {
      _showMessage('请填写玩家名称');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _splendorApi.createSession(
        SplendorCreateSessionInput(
          playerCount: _playerCount,
          title: '璀璨宝石本地对局',
          players: players
              .map((name) => SplendorCreatePlayerInput(name: name))
              .toList(growable: false),
        ),
      );

      if (!mounted) {
        return;
      }

      Get.offNamed(AppRoutes.splendorTable, arguments: response);
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('创建对局失败，请确认后端服务已启动');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// 在当前页底部显示轻量错误提示。
  void _showMessage(String message) {
    Get.snackbar(
      '创建对局',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.all(16.w),
      borderRadius: 8,
      duration: const Duration(seconds: 2),
    );
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
            _PlayerCountSelector(
              playerCount: _playerCount,
              onChanged: (value) {
                setState(() {
                  _playerCount = value;
                });
              },
            ),
            SizedBox(height: 18.h),
            ...List<Widget>.generate(_playerCount, (index) {
              return Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: TextField(
                  controller: _nameControllers[index],
                  textInputAction: index == _playerCount - 1
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
            SizedBox(height: 8.h),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _createSession,
              icon: _isSubmitting
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_isSubmitting ? '创建中' : '开始对局'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玩家人数选择控件，仅开放璀璨宝石基础版支持的 2-4 人。
class _PlayerCountSelector extends StatelessWidget {
  const _PlayerCountSelector({
    required this.playerCount,
    required this.onChanged,
  });

  final int playerCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 2, label: Text('2人')),
        ButtonSegment(value: 3, label: Text('3人')),
        ButtonSegment(value: 4, label: Text('4人')),
      ],
      selected: {playerCount},
      onSelectionChanged: (values) {
        onChanged(values.first);
      },
    );
  }
}
