import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';

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
    if (_takeTokenActions.isEmpty) {
      return Text(
        '当前没有可执行的拿宝石行动。',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(
            context,
          ).colorScheme.onSurface.withValues(alpha: 0.62),
        ),
      );
    }

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
              return _SelectableGemToken(
                colorKey: colorKey,
                selectedCount: _selected[colorKey] ?? 0,
                poolCount: _tokenCount(widget.tokenPool, colorKey),
                enabled: !widget.isSubmitting,
                canAdd: _canAdd(colorKey),
                onTap: () => _toggleGem(colorKey),
              );
            }),
            _StaticGemToken(colorKey: 'gold', count: widget.tokenPool.gold),
          ],
        ),
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

/// 点击式圆形宝石。
class _SelectableGemToken extends StatelessWidget {
  const _SelectableGemToken({
    required this.colorKey,
    required this.selectedCount,
    required this.poolCount,
    required this.enabled,
    required this.canAdd,
    required this.onTap,
  });

  final String colorKey;
  final int selectedCount;
  final int poolCount;
  final bool enabled;
  final bool canAdd;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = gemColor(colorKey);
    final textColor = readableTextColor(color);
    final isDimmed = !enabled || (!canAdd && selectedCount == 0);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: isDimmed ? null : onTap,
      child: Opacity(
        opacity: isDimmed ? 0.38 : 1,
        child: SizedBox(
          width: 50.w,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42.w,
                    height: 42.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedCount > 0
                            ? Theme.of(context).colorScheme.primary
                            : Colors.black.withValues(alpha: 0.14),
                        width: selectedCount > 0 ? 3 : 1,
                      ),
                    ),
                    child: Text(
                      '$poolCount',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (selectedCount > 0)
                    Positioned(
                      right: -2.w,
                      top: -4.h,
                      child: Container(
                        width: 20.w,
                        height: 20.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$selectedCount',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                gemShortName(colorKey),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 不参与普通拿宝石选择的公共宝石展示。
class _StaticGemToken extends StatelessWidget {
  const _StaticGemToken({required this.colorKey, required this.count});

  final String colorKey;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = gemColor(colorKey);
    final textColor = readableTextColor(color);

    return Opacity(
      opacity: 0.72,
      child: SizedBox(
        width: 50.w,
        child: Column(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black.withValues(alpha: 0.14)),
              ),
              child: Text(
                '$count',
                style: TextStyle(color: textColor, fontWeight: FontWeight.w900),
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              gemShortName(colorKey),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
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
