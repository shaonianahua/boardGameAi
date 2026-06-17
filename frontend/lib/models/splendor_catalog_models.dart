// `GET /api/splendor/catalog` 的固定图鉴模型。
// 包含后端返回的发展卡和贵族板块数据。
import 'splendor_base_models.dart';

/// 璀璨宝石发展卡图鉴项。
class SplendorCard {
  /// 构造一张发展卡，字段直接对应后端 catalog card JSON。
  const SplendorCard({
    required this.id,
    required this.level,
    required this.bonusColor,
    required this.prestige,
    required this.cost,
  });

  /// 从后端 catalog card JSON 解析发展卡。
  factory SplendorCard.fromJson(JsonMap json) {
    return SplendorCard(
      id: json['id'] as String,
      level: json['level'] as int,
      bonusColor: json['bonusColor'] as String,
      prestige: json['prestige'] as int,
      cost: SplendorGemSet.fromJson(json['cost'] as JsonMap?),
    );
  }

  /// 卡牌唯一 ID，用于市场、牌堆、购买、预留等引用。
  final String id;

  /// 卡牌等级，取值对应一、二三级发展卡。
  final int level;

  /// 购买后提供的永久宝石颜色。
  final String bonusColor;

  /// 卡牌胜利分。
  final int prestige;

  /// 购买这张卡需要支付的宝石费用。
  final SplendorGemSet cost;
}

/// 璀璨宝石贵族板块图鉴项。
class SplendorNoble {
  /// 构造一个贵族板块，字段直接对应后端 catalog noble JSON。
  const SplendorNoble({
    required this.id,
    required this.prestige,
    required this.requirement,
  });

  /// 从后端 catalog noble JSON 解析贵族板块。
  factory SplendorNoble.fromJson(JsonMap json) {
    return SplendorNoble(
      id: json['id'] as String,
      prestige: json['prestige'] as int,
      requirement: SplendorGemSet.fromJson(json['requirement'] as JsonMap?),
    );
  }

  /// 贵族唯一 ID，用于场上贵族、玩家获得贵族、选择贵族等引用。
  final String id;

  /// 贵族提供的胜利分。
  final int prestige;

  /// 获得该贵族需要满足的永久宝石数量。
  final SplendorGemSet requirement;
}

/// 璀璨宝石固定图鉴接口响应。
class SplendorCatalogResponse {
  /// 构造 catalog 响应，包含发展卡和贵族图鉴。
  const SplendorCatalogResponse({required this.cards, required this.nobles});

  /// 从 `GET /api/splendor/catalog` 响应 JSON 解析图鉴。
  factory SplendorCatalogResponse.fromJson(JsonMap json) {
    return SplendorCatalogResponse(
      cards: objectList(json['cards'], SplendorCard.fromJson),
      nobles: objectList(json['nobles'], SplendorNoble.fromJson),
    );
  }

  /// 全量发展卡列表。
  final List<SplendorCard> cards;

  /// 全量贵族板块列表。
  final List<SplendorNoble> nobles;
}
