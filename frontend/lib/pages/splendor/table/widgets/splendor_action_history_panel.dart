import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../models/splendor_models.dart';
import '../splendor_card_style_helpers.dart';

/// 璀璨宝石行动历史面板。
///
/// 负责把后端 action 记录转成适合玩家回看的中文描述。
class SplendorActionHistoryPanel extends StatelessWidget {
  /// 构造行动历史面板。
  const SplendorActionHistoryPanel({
    required this.actions,
    required this.players,
    required this.cardsById,
    required this.noblesById,
    required this.isLoading,
    this.scrollController,
    super.key,
  });

  /// 后端返回的历史行动记录；面板内会倒序展示，最新操作在最上方。
  final List<SplendorActionRecord> actions;

  /// 当前对局玩家列表，用于把 playerIndex 转成玩家名称。
  final List<SplendorPlayerState> players;

  /// 发展卡 catalog 索引，用于展示购买和预留目标。
  final Map<String, SplendorCard> cardsById;

  /// 贵族 catalog 索引，用于展示自动获得贵族事件。
  final Map<String, SplendorNoble> noblesById;

  /// 历史记录是否正在刷新。
  final bool isLoading;

  /// 外部滚动控制器；在 bottom sheet 中传入可让拖拽和列表滚动协同。
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    if (isLoading && actions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (actions.isEmpty) {
      return Center(
        child: Text(
          '暂无行动记录',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.58),
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final displayActions = actions.reversed.toList(growable: false);

    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(14.w, 6.h, 14.w, 20.h),
      itemCount: displayActions.length,
      separatorBuilder: (context, index) => SizedBox(height: 8.h),
      itemBuilder: (context, index) {
        final action = displayActions[index];
        return _ActionHistoryTile(
          action: action,
          title: _titleFor(action),
          description: _descriptionFor(action),
        );
      },
    );
  }

  String _playerName(int playerIndex) {
    if (playerIndex < 0 || playerIndex >= players.length) {
      return '玩家${playerIndex + 1}';
    }
    return players[playerIndex].name;
  }

  String _titleFor(SplendorActionRecord record) {
    final playerName = _playerName(record.playerIndex);
    return switch (record.action.type) {
      SplendorActionType.takeTokens => '$playerName 拿取宝石',
      SplendorActionType.reserveCard => '$playerName 预留卡牌',
      SplendorActionType.buyCard => '$playerName 购买卡牌',
      SplendorActionType.discardTokens => '$playerName 弃掉宝石',
      SplendorActionType.nobleVisit => '$playerName 获得贵族',
      SplendorActionType.chooseNoble => '$playerName 选择贵族',
    };
  }

  String _descriptionFor(SplendorActionRecord record) {
    final payload = record.action.payload;
    return switch (record.action.type) {
      SplendorActionType.takeTokens => '拿取 ${_tokenText(payload['tokens'])}',
      SplendorActionType.reserveCard => _reserveDescription(payload),
      SplendorActionType.buyCard => _buyDescription(payload),
      SplendorActionType.discardTokens => '弃掉 ${_tokenText(payload['tokens'])}',
      SplendorActionType.nobleVisit => _nobleVisitDescription(payload),
      SplendorActionType.chooseNoble => _nobleVisitDescription(payload),
    };
  }

  String _reserveDescription(JsonMap payload) {
    final source = payload['source'];
    final cardId = payload['cardId'] as String?;
    if (source == 'deck') {
      return '从 ${levelLabel(payload['level'] as int? ?? 0)} 级牌堆盲预留';
    }

    final card = cardId == null ? null : cardsById[cardId];
    final cardText = card == null
        ? cardId ?? '未知卡牌'
        : '${gemName(card.bonusColor)}色${card.prestige}分卡';
    return '预留 $cardText';
  }

  String _buyDescription(JsonMap payload) {
    final cardId = payload['cardId'] as String?;
    final card = cardId == null ? null : cardsById[cardId];
    final source = payload['source'] == 'reserved' ? '预留区' : '公开市场';
    if (card == null) {
      return '从$source购买 ${cardId ?? '未知卡牌'}';
    }

    return '从$source购买 ${gemName(card.bonusColor)}色${card.prestige}分卡';
  }

  String _nobleVisitDescription(JsonMap payload) {
    final nobleId = payload['nobleId'] as String?;
    final noble = nobleId == null ? null : noblesById[nobleId];
    if (noble == null) {
      return '获得 ${nobleId ?? '未知贵族'}';
    }

    return '获得 ${noble.prestige}分贵族';
  }

  String _tokenText(Object? value) {
    if (value is! JsonMap) {
      return '未知宝石';
    }

    final entries = <String>[];
    for (final colorKey in ['white', 'blue', 'green', 'red', 'black', 'gold']) {
      final count = value[colorKey];
      if (count is int && count > 0) {
        entries.add('${gemName(colorKey)}$count');
      }
    }

    return entries.isEmpty ? '无' : entries.join('、');
  }
}

/// 单条行动历史卡片。
class _ActionHistoryTile extends StatelessWidget {
  const _ActionHistoryTile({
    required this.action,
    required this.title,
    required this.description,
  });

  final SplendorActionRecord action;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                '回合 ${action.turnIndex + 1}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.58),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.68),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
