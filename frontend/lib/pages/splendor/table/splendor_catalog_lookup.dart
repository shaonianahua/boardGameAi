import '../../../models/splendor_models.dart';

/// 璀璨宝石桌面页的 catalog 索引。
///
/// 用于把 GameState 里的卡牌和贵族 ID 快速映射成可读数据。
class SplendorCatalogLookup {
  /// 从 catalog 响应构造 ID 索引。
  SplendorCatalogLookup(SplendorCatalogResponse? catalog)
    : cardsById = {
        for (final card in catalog?.cards ?? const <SplendorCard>[])
          card.id: card,
      },
      noblesById = {
        for (final noble in catalog?.nobles ?? const <SplendorNoble>[])
          noble.id: noble,
      };

  /// 发展卡索引。
  final Map<String, SplendorCard> cardsById;

  /// 贵族索引。
  final Map<String, SplendorNoble> noblesById;
}
