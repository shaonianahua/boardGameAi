import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';
import '../widgets/splendor_selectable_gem_token.dart';

/// 拿宝石行动面板。
///
/// 用户通过点击圆形宝石形成选择；面板用后端返回的合法行动判断当前选择是否可提交。
class TakeTokensPanel extends StatefulWidget {
  /// 构造拿宝石行动面板。
  const TakeTokensPanel({
    required this.actions,
    required this.tokenPool,
    required this.isSubmitting,
    required this.onSubmit,
    super.key,
  });

  /// 后端返回的合法行动列表。
  final List<SplendorLegalAction> actions;

  /// 当前公共 token 池，用于显示每种宝石剩余数量。
  final SplendorTokenSet tokenPool;

  /// 是否正在提交行动。
  final bool isSubmitting;

  /// 用户选择一个合法拿宝石行动后的提交回调。
  final ValueChanged<SplendorLegalAction> onSubmit;

  @override
  State<TakeTokensPanel> createState() => _TakeTokensPanelState();
}

class _TakeTokensPanelState extends State<TakeTokensPanel> {
  final Map<String, int> _selected = {
    'white': 0,
    'blue': 0,
    'green': 0,
    'red': 0,
    'black': 0,
  };

  List<SplendorLegalAction> get _takeTokenActions {
    return widget.actions
        .where((item) => item.action.type == SplendorActionType.takeTokens)
        .toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant TakeTokensPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions != widget.actions) {
      _clearSelection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canTakeTokens = _takeTokenActions.isNotEmpty;
    final matchedAction = _matchedExactAction();
    final totalSelected = _selected.values.fold<int>(
      0,
      (sum, item) => sum + item,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10.w,
          runSpacing: 10.h,
          children: [
            ..._gemKeys.map((colorKey) {
              return SplendorSelectableGemToken(
                colorKey: colorKey,
                selectedCount: _selected[colorKey] ?? 0,
                count: _tokenCount(widget.tokenPool, colorKey),
                enabled: canTakeTokens && !widget.isSubmitting,
                canAdd: canTakeTokens && _canTapColor(colorKey),
                onTap: canTakeTokens ? () => _toggleGem(colorKey) : null,
              );
            }),
            SplendorSelectableGemToken(
              colorKey: 'gold',
              count: widget.tokenPool.gold,
              enabled: false,
            ),
          ],
        ),
        if (!canTakeTokens) ...[
          SizedBox(height: 10.h),
          Text(
            '当前不能拿宝石，公共宝石仅展示数量。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (canTakeTokens) ...[
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  totalSelected == 0 ? '点击宝石选择拿取' : '已选择：${_selectionLabel()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.66),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: widget.isSubmitting || totalSelected == 0
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
            child: Text(widget.isSubmitting ? '提交中' : '拿取宝石'),
          ),
        ],
      ],
    );
  }

  void _toggleGem(String colorKey) {
    if (widget.isSubmitting) {
      return;
    }

    final next = _nextSelectionAfterTap(colorKey);
    if (next == null) {
      return;
    }

    setState(() {
      _selected
        ..clear()
        ..addAll(next);
    });
  }

  bool _canTapColor(String colorKey) {
    return _nextSelectionAfterTap(colorKey) != null;
  }

  Map<String, int>? _nextSelectionAfterTap(String colorKey) {
    final current = _selected[colorKey] ?? 0;
    final directNext = Map<String, int>.from(_selected)
      ..[colorKey] = current + 1;

    if (_isSelectionPrefix(directNext)) {
      return directNext;
    }

    if (current > 0) {
      final clearedNext = Map<String, int>.from(_selected)..[colorKey] = 0;
      return _isSelectionPrefix(clearedNext) ? clearedNext : null;
    }

    return _compatibleSelectionContaining(colorKey);
  }

  Map<String, int>? _compatibleSelectionContaining(String colorKey) {
    for (final legalAction in _takeTokenActions) {
      final tokens = _tokensFromAction(legalAction.action);
      if (_tokenCount(tokens, colorKey) == 0) {
        continue;
      }

      final next = <String, int>{};
      for (final gemKey in _gemKeys) {
        next[gemKey] = (_selected[gemKey] ?? 0).clamp(
          0,
          _tokenCount(tokens, gemKey),
        );
      }
      next[colorKey] = _tokenCount(tokens, colorKey);

      if (_isSelectionPrefix(next)) {
        return next;
      }
    }
    return null;
  }

  bool _isSelectionPrefix(Map<String, int> selection) {
    final selectedTotal = selection.values.fold<int>(
      0,
      (sum, item) => sum + item,
    );
    if (selectedTotal == 0) {
      return true;
    }

    return _takeTokenActions.any((legalAction) {
      final tokens = _tokensFromAction(legalAction.action);
      return _gemKeys.every((colorKey) {
        return (selection[colorKey] ?? 0) <= _tokenCount(tokens, colorKey);
      });
    });
  }

  SplendorLegalAction? _matchedExactAction() {
    for (final legalAction in _takeTokenActions) {
      final tokens = _tokensFromAction(legalAction.action);
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

const List<String> _gemKeys = ['white', 'blue', 'green', 'red', 'black'];

SplendorTokenSet _tokensFromAction(SplendorAction action) {
  return SplendorTokenSet.fromJson(action.payload['tokens'] as JsonMap?);
}

int _tokenCount(SplendorTokenSet tokens, String colorKey) {
  return switch (colorKey) {
    'white' => tokens.white,
    'blue' => tokens.blue,
    'green' => tokens.green,
    'red' => tokens.red,
    'black' => tokens.black,
    _ => 0,
  };
}
