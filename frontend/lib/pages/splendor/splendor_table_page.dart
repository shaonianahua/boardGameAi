import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';

import '../../api/splendor_api.dart';
import '../../models/api_models.dart';
import '../../models/splendor_models.dart';

/// 璀璨宝石对局桌面页。
///
/// 当前先展示后端返回的基础状态快照，后续再在本页逐步接入行动 UI。
class SplendorTablePage extends StatefulWidget {
  const SplendorTablePage({super.key});

  @override
  State<SplendorTablePage> createState() => _SplendorTablePageState();
}

class _SplendorTablePageState extends State<SplendorTablePage> {
  final SplendorApi _splendorApi = SplendorApi();

  SplendorSessionResponse? _sessionResponse;
  SplendorCatalogResponse? _catalog;
  bool _isRefreshing = false;
  bool _isLoadingCatalog = false;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    if (arguments is SplendorSessionResponse) {
      _sessionResponse = arguments;
    }
    _loadCatalog();
  }

  /// 拉取固定 catalog，用于把状态里的卡牌/贵族 ID 显示成具体内容。
  Future<void> _loadCatalog() async {
    setState(() {
      _isLoadingCatalog = true;
    });

    try {
      final catalog = await _splendorApi.getCatalog();
      if (!mounted) {
        return;
      }
      setState(() {
        _catalog = catalog;
      });
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('读取卡牌数据失败，请确认后端服务已启动');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCatalog = false;
        });
      }
    }
  }

  /// 从后端重新拉取当前对局快照。
  Future<void> _refreshSession() async {
    final sessionId = _sessionResponse?.session.id;
    if (sessionId == null) {
      _showMessage('没有找到当前对局');
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    try {
      final response = await _splendorApi.getSession(sessionId);
      if (!mounted) {
        return;
      }
      setState(() {
        _sessionResponse = response;
      });
    } on ApiException catch (error) {
      _showMessage(error.error.message);
    } catch (_) {
      _showMessage('刷新对局失败，请确认后端服务已启动');
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  /// 在当前页底部显示对局相关提示。
  void _showMessage(String message) {
    Get.snackbar(
      '璀璨宝石',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: EdgeInsets.all(16.w),
      borderRadius: 8,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final response = _sessionResponse;

    return Scaffold(
      appBar: AppBar(
        title: const Text('璀璨宝石'),
        actions: [
          IconButton(
            tooltip: '刷新对局',
            onPressed: _isRefreshing ? null : _refreshSession,
            icon: _isRefreshing
                ? SizedBox(
                    width: 18.w,
                    height: 18.w,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: response == null
            ? const _EmptySessionView()
            : _SessionContent(
                response: response,
                catalog: _catalog,
                isLoadingCatalog: _isLoadingCatalog,
              ),
      ),
    );
  }
}

/// 对局主体展示区。
class _SessionContent extends StatelessWidget {
  const _SessionContent({
    required this.response,
    required this.catalog,
    required this.isLoadingCatalog,
  });

  final SplendorSessionResponse response;
  final SplendorCatalogResponse? catalog;
  final bool isLoadingCatalog;

  @override
  Widget build(BuildContext context) {
    final state = response.state;
    final currentPlayer = state.players[state.currentPlayerIndex];
    final cardsById = {
      for (final card in catalog?.cards ?? const <SplendorCard>[])
        card.id: card,
    };
    final noblesById = {
      for (final noble in catalog?.nobles ?? const <SplendorNoble>[])
        noble.id: noble,
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      children: [
        _TurnHeader(
          turnIndex: state.currentTurnIndex,
          currentPlayerName: currentPlayer.name,
          status: state.status.toJson(),
        ),
        SizedBox(height: 14.h),
        _TokenPoolCard(tokenPool: state.tokenPool),
        SizedBox(height: 14.h),
        _MarketCard(
          markets: state.markets,
          cardsById: cardsById,
          isLoadingCatalog: isLoadingCatalog,
        ),
        SizedBox(height: 14.h),
        _NobleCard(
          nobles: state.nobles,
          noblesById: noblesById,
          isLoadingCatalog: isLoadingCatalog,
        ),
        SizedBox(height: 14.h),
        _PlayersCard(
          players: state.players,
          currentPlayerIndex: state.currentPlayerIndex,
        ),
      ],
    );
  }
}

/// 当前回合摘要。
class _TurnHeader extends StatelessWidget {
  const _TurnHeader({
    required this.turnIndex,
    required this.currentPlayerName,
    required this.status,
  });

  final int turnIndex;
  final String currentPlayerName;
  final String status;

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
            Text(
              '第 ${turnIndex + 1} 回合',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '当前玩家：$currentPlayerName',
              style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6.h),
            Text(
              '状态：$status',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 公共 token 池展示卡。
class _TokenPoolCard extends StatelessWidget {
  const _TokenPoolCard({required this.tokenPool});

  final SplendorTokenSet tokenPool;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '公共宝石',
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: [
          _GemChip(label: '白', count: tokenPool.white, color: Colors.white),
          _GemChip(label: '蓝', count: tokenPool.blue, color: Colors.blue),
          _GemChip(label: '绿', count: tokenPool.green, color: Colors.green),
          _GemChip(label: '红', count: tokenPool.red, color: Colors.red),
          _GemChip(label: '黑', count: tokenPool.black, color: Colors.black87),
          _GemChip(label: '金', count: tokenPool.gold, color: Colors.amber),
        ],
      ),
    );
  }
}

/// 市场卡牌展示卡，把状态中的卡牌 ID 映射成 catalog 中的真实卡牌内容。
class _MarketCard extends StatelessWidget {
  const _MarketCard({
    required this.markets,
    required this.cardsById,
    required this.isLoadingCatalog,
  });

  final SplendorCardArea markets;
  final Map<String, SplendorCard> cardsById;
  final bool isLoadingCatalog;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '市场卡牌',
      child: Column(
        children: [
          if (isLoadingCatalog) const _CatalogLoadingText(),
          if (isLoadingCatalog) SizedBox(height: 12.h),
          _MarketLevelSection(
            title: '三级',
            cardIds: markets.level3,
            cardsById: cardsById,
          ),
          SizedBox(height: 14.h),
          _MarketLevelSection(
            title: '二级',
            cardIds: markets.level2,
            cardsById: cardsById,
          ),
          SizedBox(height: 14.h),
          _MarketLevelSection(
            title: '一级',
            cardIds: markets.level1,
            cardsById: cardsById,
          ),
        ],
      ),
    );
  }
}

/// 贵族展示卡，把状态中的贵族 ID 映射成 catalog 中的需求和分数。
class _NobleCard extends StatelessWidget {
  const _NobleCard({
    required this.nobles,
    required this.noblesById,
    required this.isLoadingCatalog,
  });

  final List<String> nobles;
  final Map<String, SplendorNoble> noblesById;
  final bool isLoadingCatalog;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '贵族',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoadingCatalog) const _CatalogLoadingText(),
          if (isLoadingCatalog) SizedBox(height: 12.h),
          LayoutBuilder(
            builder: (context, constraints) {
              final tileWidth = (constraints.maxWidth - 8.w) / 2;
              return Wrap(
                spacing: 8.w,
                runSpacing: 8.h,
                children: nobles.map((id) {
                  return SizedBox(
                    width: tileWidth,
                    child: _NobleTile(noble: noblesById[id], fallbackId: id),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// 玩家状态摘要卡。
class _PlayersCard extends StatelessWidget {
  const _PlayersCard({required this.players, required this.currentPlayerIndex});

  final List<SplendorPlayerState> players;
  final int currentPlayerIndex;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: '玩家',
      child: Column(
        children: List<Widget>.generate(players.length, (index) {
          final player = players[index];
          return Padding(
            padding: EdgeInsets.only(
              bottom: index == players.length - 1 ? 0 : 10.h,
            ),
            child: _PlayerSummaryRow(
              player: player,
              isCurrent: index == currentPlayerIndex,
            ),
          );
        }),
      ),
    );
  }
}

/// 通用信息卡片，用于桌面页的几块基础状态区。
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 12.h),
            child,
          ],
        ),
      ),
    );
  }
}

/// 单个等级的市场卡牌区域。
class _MarketLevelSection extends StatelessWidget {
  const _MarketLevelSection({
    required this.title,
    required this.cardIds,
    required this.cardsById,
  });

  final String title;
  final List<String> cardIds;
  final Map<String, SplendorCard> cardsById;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 8.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final tileWidth = (constraints.maxWidth - 8.w) / 2;
            return Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: cardIds.map((id) {
                return SizedBox(
                  width: tileWidth,
                  child: _DevelopmentCardTile(
                    card: cardsById[id],
                    fallbackId: id,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

/// 发展卡简化卡面，展示等级、分数、奖励颜色和购买费用。
class _DevelopmentCardTile extends StatelessWidget {
  const _DevelopmentCardTile({required this.card, required this.fallbackId});

  final SplendorCard? card;
  final String fallbackId;

  @override
  Widget build(BuildContext context) {
    final card = this.card;
    final colorScheme = Theme.of(context).colorScheme;

    if (card == null) {
      return _MissingCatalogTile(label: fallbackId);
    }

    final bonusColor = _gemColor(card.bonusColor);
    final bonusTextColor = _readableTextColor(bonusColor);

    return Container(
      constraints: BoxConstraints(minHeight: 132.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: bonusColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_levelLabel(card.level)} ${_gemName(card.bonusColor)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: bonusTextColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${card.prestige}分',
                  style: TextStyle(
                    color: bonusTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(10.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '购买费用',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                _CostWrap(gems: card.cost),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 贵族简化卡面，展示分数和到访所需永久宝石。
class _NobleTile extends StatelessWidget {
  const _NobleTile({required this.noble, required this.fallbackId});

  final SplendorNoble? noble;
  final String fallbackId;

  @override
  Widget build(BuildContext context) {
    final noble = this.noble;
    final colorScheme = Theme.of(context).colorScheme;

    if (noble == null) {
      return _MissingCatalogTile(label: fallbackId);
    }

    return Container(
      constraints: BoxConstraints(minHeight: 112.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '贵族',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${noble.prestige}分',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            '需求',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 8.h),
          _CostWrap(gems: noble.requirement),
        ],
      ),
    );
  }
}

/// 宝石费用/需求集合展示。
class _CostWrap extends StatelessWidget {
  const _CostWrap({required this.gems});

  final SplendorGemSet gems;

  @override
  Widget build(BuildContext context) {
    final entries = _nonZeroGemEntries(gems);

    if (entries.isEmpty) {
      return Text(
        '无',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      );
    }

    return Wrap(
      spacing: 6.w,
      runSpacing: 6.h,
      children: entries.map((entry) {
        return _CostChip(colorKey: entry.key, count: entry.value);
      }).toList(),
    );
  }
}

/// 单个颜色费用标签。
class _CostChip extends StatelessWidget {
  const _CostChip({required this.colorKey, required this.count});

  final String colorKey;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = _gemColor(colorKey);
    final textColor = _readableTextColor(color);

    return Container(
      constraints: BoxConstraints(minWidth: 36.w),
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
      child: Text(
        '${_gemShortName(colorKey)} $count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontSize: 11.sp,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// catalog 未加载到对应 ID 时的兜底展示。
class _MissingCatalogTile extends StatelessWidget {
  const _MissingCatalogTile({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(minHeight: 88.h),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// catalog 正在加载时的说明文本。
class _CatalogLoadingText extends StatelessWidget {
  const _CatalogLoadingText();

  @override
  Widget build(BuildContext context) {
    return Text(
      '正在读取卡牌数据...',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}

/// 玩家摘要行，展示分数、token、bonus 和当前玩家标记。
class _PlayerSummaryRow extends StatelessWidget {
  const _PlayerSummaryRow({required this.player, required this.isCurrent});

  final SplendorPlayerState player;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: isCurrent
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isCurrent
              ? colorScheme.primary.withValues(alpha: 0.32)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  player.name,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${player.score} 分',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'token ${_tokenTotal(player.tokens)} / bonus ${_bonusTotal(player.bonuses)} / 预留 ${player.reservedCards.length}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
        ],
      ),
    );
  }
}

/// 宝石数量标签。
class _GemChip extends StatelessWidget {
  const _GemChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isLight = color.computeLuminance() > 0.72;

    return Container(
      width: 54.w,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isLight ? Colors.black : Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            '$count',
            style: TextStyle(
              color: isLight ? Colors.black87 : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 没有路由参数时的空状态。
class _EmptySessionView extends StatelessWidget {
  const _EmptySessionView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Text(
          '没有找到当前对局，请返回首页重新创建。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// 计算玩家持有 token 总数。
int _tokenTotal(SplendorTokenSet tokens) {
  return tokens.white +
      tokens.blue +
      tokens.green +
      tokens.red +
      tokens.black +
      tokens.gold;
}

/// 计算玩家永久 bonus 总数。
int _bonusTotal(SplendorGemSet bonuses) {
  return bonuses.white +
      bonuses.blue +
      bonuses.green +
      bonuses.red +
      bonuses.black;
}

/// 返回非 0 宝石条目，供费用和贵族需求展示使用。
List<MapEntry<String, int>> _nonZeroGemEntries(SplendorGemSet gems) {
  return [
    MapEntry('white', gems.white),
    MapEntry('blue', gems.blue),
    MapEntry('green', gems.green),
    MapEntry('red', gems.red),
    MapEntry('black', gems.black),
  ].where((entry) => entry.value > 0).toList(growable: false);
}

/// 后端等级数字转成 UI 展示文本。
String _levelLabel(int level) {
  return switch (level) {
    1 => 'I',
    2 => 'II',
    3 => 'III',
    _ => '$level',
  };
}

/// 宝石颜色英文 key 转中文名。
String _gemName(String colorKey) {
  return switch (colorKey) {
    'white' => '白',
    'blue' => '蓝',
    'green' => '绿',
    'red' => '红',
    'black' => '黑',
    _ => colorKey,
  };
}

/// 宝石颜色英文 key 转短中文名。
String _gemShortName(String colorKey) => _gemName(colorKey);

/// 宝石颜色英文 key 转 UI 颜色。
Color _gemColor(String colorKey) {
  return switch (colorKey) {
    'white' => Colors.white,
    'blue' => Colors.blue,
    'green' => Colors.green,
    'red' => Colors.red,
    'black' => Colors.black87,
    _ => Colors.grey,
  };
}

/// 根据背景色亮度选择可读文字颜色。
Color _readableTextColor(Color backgroundColor) {
  return backgroundColor.computeLuminance() > 0.72
      ? Colors.black87
      : Colors.white;
}
