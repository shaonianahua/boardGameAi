import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';
import '../widgets/splendor_selectable_gem_token.dart';

/// 弃宝石行动面板。
///
/// 当后端返回 `pendingAction: discard_tokens` 时，用户在这里选择需要弃掉的宝石并提交。
class DiscardTokensPanel extends StatefulWidget {
  /// 构造弃宝石行动面板。
  const DiscardTokensPanel({
    required this.pendingAction,
    required this.playerTokens,
    required this.actions,
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  /// 当前待处理的弃宝石挂起行动。
  final SplendorPendingAction pendingAction;

  /// 当前处理挂起行动玩家手里的 token 数量，用于展示可弃颜色和数量。
  final SplendorTokenSet playerTokens;

  /// 后端返回的合法弃宝石行动。
  final List<SplendorLegalAction> actions;

  /// 是否正在提交行动。
  final bool isSubmitting;

  /// 提交匹配到的合法弃宝石行动。
  final ValueChanged<SplendorLegalAction> onSubmit;

  @override
  State<DiscardTokensPanel> createState() => _DiscardTokensPanelState();
}

class _DiscardTokensPanelState extends State<DiscardTokensPanel> {
  final Map<String, int> _selected = {
    'white': 0,
    'blue': 0,
    'green': 0,
    'red': 0,
    'black': 0,
    'gold': 0,
  };

  List<SplendorLegalAction> get _discardActions {
    return widget.actions
        .where((item) => item.action.type == SplendorActionType.discardTokens)
        .toList(growable: false);
  }

  int get _requiredDiscardCount {
    return (widget.pendingAction.tokenCount ?? 0) -
        (widget.pendingAction.maxTokenCount ?? 0);
  }

  @override
  void didUpdateWidget(covariant DiscardTokensPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions != widget.actions ||
        oldWidget.pendingAction != widget.pendingAction) {
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_discardActions.isEmpty) {
      return Text(
        '当前没有可执行的弃宝石行动。',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.62),
        ),
      );
    }

    final matchedAction = _matchedExactAction();
    final selectedTotal = _selected.values.fold<int>(
      0,
      (sum, item) => sum + item,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '需要弃掉 $_requiredDiscardCount 个宝石',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 10.h),
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            ..._gemKeys.map((colorKey) {
              return SplendorSelectableGemToken(
                colorKey: colorKey,
                count: _tokenCount(widget.playerTokens, colorKey),
                selectedCount: _selected[colorKey] ?? 0,
                enabled: !widget.isSubmitting,
                canAdd: _canAdd(colorKey),
                onTap: () => _toggleGem(colorKey),
              );
            }),
          ],
        ),
        SizedBox(height: 10.h),
        Row(
          children: [
            Expanded(
              child: Text(
                selectedTotal == 0 ? '点击宝石选择弃掉的数量' : '已选择：${_selectionLabel()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.66),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.isSubmitting || selectedTotal == 0
                  ? null
                  : _clearSelection,
              child: const Text('清空'),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        FilledButton(
          onPressed: widget.isSubmitting || matchedAction == null
              ? null
              : () => widget.onSubmit(matchedAction),
          child: Text(widget.isSubmitting ? '提交中' : '确认弃宝石'),
        ),
      ],
    );
  }

  void _toggleGem(String colorKey) {
    if (widget.isSubmitting) {
      return;
    }

    final current = _selected[colorKey] ?? 0;
    final next = Map<String, int>.from(_selected);

    if (current > 0 && !_canAdd(colorKey)) {
      next[colorKey] = 0;
    } else {
      next[colorKey] = current + 1;
    }

    if (!_isSelectionPrefix(next)) {
      next[colorKey] = 0;
    }

    setState(() {
      _selected
        ..clear()
        ..addAll(next);
    });
  }

  bool _canAdd(String colorKey) {
    final current = _selected[colorKey] ?? 0;
    final next = Map<String, int>.from(_selected)..[colorKey] = current + 1;
    return _isSelectionPrefix(next);
  }

  bool _isSelectionPrefix(Map<String, int> selection) {
    final selectedTotal = selection.values.fold<int>(
      0,
      (sum, item) => sum + item,
    );
    if (selectedTotal == 0) {
      return true;
    }
    if (selectedTotal > _requiredDiscardCount) {
      return false;
    }

    return _discardActions.any((legalAction) {
      final tokens = SplendorTokenSet.fromJson(
        legalAction.action.payload['tokens'] as JsonMap?,
      );
      return _gemKeys.every((colorKey) {
        return (selection[colorKey] ?? 0) <= _tokenCount(tokens, colorKey);
      });
    });
  }

  SplendorLegalAction? _matchedExactAction() {
    for (final legalAction in _discardActions) {
      final tokens = SplendorTokenSet.fromJson(
        legalAction.action.payload['tokens'] as JsonMap?,
      );
      final isExact = _gemKeys.every((colorKey) {
        return (_selected[colorKey] ?? 0) == _tokenCount(tokens, colorKey);
      });
      if (isExact) {
        return legalAction;
      }
    }
    return null;
  }

  String _selectionLabel() {
    return _gemKeys
        .where((colorKey) => (_selected[colorKey] ?? 0) > 0)
        .map((colorKey) => '${gemShortName(colorKey)}${_selected[colorKey]}')
        .join(' ');
  }

  void _clearSelection() {
    setState(() {
      for (final colorKey in _gemKeys) {
        _selected[colorKey] = 0;
      }
    });
  }
}

const List<String> _gemKeys = [
  'white',
  'blue',
  'green',
  'red',
  'black',
  'gold',
];

int _tokenCount(SplendorTokenSet tokens, String colorKey) {
  return switch (colorKey) {
    'white' => tokens.white,
    'blue' => tokens.blue,
    'green' => tokens.green,
    'red' => tokens.red,
    'black' => tokens.black,
    'gold' => tokens.gold,
    _ => 0,
  };
}
