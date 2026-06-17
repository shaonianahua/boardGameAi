import 'package:flutter/material.dart';

/// 璀璨宝石创建对局页里使用的 2-4 人选择控件。
///
/// 这个控件只负责人数切换，不承载其它表单逻辑。
class PlayerCountSelector extends StatelessWidget {
  /// 构造人数选择控件。
  const PlayerCountSelector({
    required this.playerCount,
    required this.onChanged,
    super.key,
  });

  /// 当前选中的玩家人数。
  final int playerCount;

  /// 人数变化时回调。
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
