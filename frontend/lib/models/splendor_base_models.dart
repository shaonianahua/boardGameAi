/// 璀璨宝石 API 模型共享的基础类型和枚举。
///
/// catalog、session、game-state、action 等模型文件都会复用这里的类型。
typedef JsonMap = Map<String, dynamic>;

/// 对局座位的玩家类型。
enum SplendorPlayerType {
  human,
  bot;

  /// 从后端字符串解析玩家类型，未知值默认按真人玩家处理。
  static SplendorPlayerType fromJson(String? value) {
    return switch (value) {
      'bot' => SplendorPlayerType.bot,
      _ => SplendorPlayerType.human,
    };
  }

  /// 转成后端创建对局接口需要的字符串。
  String toJson() => name;
}

/// 璀璨宝石对局状态。
enum SplendorSessionStatus {
  active,
  finished,
  abandoned;

  /// 从后端状态字符串解析对局状态，未知值默认按进行中处理。
  static SplendorSessionStatus fromJson(String? value) {
    return switch (value) {
      'finished' => SplendorSessionStatus.finished,
      'abandoned' => SplendorSessionStatus.abandoned,
      _ => SplendorSessionStatus.active,
    };
  }

  /// 转成后端接口使用的状态字符串。
  String toJson() => name;
}

/// 璀璨宝石玩家行动类型。
enum SplendorActionType {
  takeTokens('take_tokens'),
  reserveCard('reserve_card'),
  buyCard('buy_card'),
  discardTokens('discard_tokens'),
  chooseNoble('choose_noble'),
  nobleVisit('noble_visit');

  const SplendorActionType(this.value);

  /// 后端接口使用的 action.type 字符串。
  final String value;

  /// 从后端 action.type 字符串解析行动类型。
  static SplendorActionType fromJson(String? value) {
    return switch (value) {
      'reserve_card' => SplendorActionType.reserveCard,
      'buy_card' => SplendorActionType.buyCard,
      'discard_tokens' => SplendorActionType.discardTokens,
      'choose_noble' => SplendorActionType.chooseNoble,
      'noble_visit' => SplendorActionType.nobleVisit,
      _ => SplendorActionType.takeTokens,
    };
  }
}

/// 宝石 token 数量集合，包含黄金 token。
///
/// 用于玩家 token、公共 token 池、拿取/支付/弃牌等需要描述 token 数量的场景。
class SplendorTokenSet {
  /// 构造一组 token 数量，未传入的颜色默认是 0。
  const SplendorTokenSet({
    this.white = 0,
    this.blue = 0,
    this.green = 0,
    this.red = 0,
    this.black = 0,
    this.gold = 0,
  });

  /// 从后端 token JSON 解析，缺失的颜色按 0 处理。
  factory SplendorTokenSet.fromJson(JsonMap? json) {
    return SplendorTokenSet(
      white: intValue(json, 'white'),
      blue: intValue(json, 'blue'),
      green: intValue(json, 'green'),
      red: intValue(json, 'red'),
      black: intValue(json, 'black'),
      gold: intValue(json, 'gold'),
    );
  }

  final int white;
  final int blue;
  final int green;
  final int red;
  final int black;
  final int gold;

  /// 转成后端 action 或状态 JSON；`includeZero=false` 时会省略 0 值颜色。
  JsonMap toJson({bool includeZero = true}) {
    final json = <String, dynamic>{};
    void setValue(String key, int value) {
      if (includeZero || value != 0) {
        json[key] = value;
      }
    }

    setValue('white', white);
    setValue('blue', blue);
    setValue('green', green);
    setValue('red', red);
    setValue('black', black);
    setValue('gold', gold);
    return json;
  }
}

/// 永久宝石折扣数量集合，不包含黄金。
///
/// 用于卡牌费用、玩家已购卡带来的 bonus、贵族需求等场景。
class SplendorGemSet {
  /// 构造一组永久宝石数量，未传入的颜色默认是 0。
  const SplendorGemSet({
    this.white = 0,
    this.blue = 0,
    this.green = 0,
    this.red = 0,
    this.black = 0,
  });

  /// 从后端 gem JSON 解析，缺失的颜色按 0 处理。
  factory SplendorGemSet.fromJson(JsonMap? json) {
    return SplendorGemSet(
      white: intValue(json, 'white'),
      blue: intValue(json, 'blue'),
      green: intValue(json, 'green'),
      red: intValue(json, 'red'),
      black: intValue(json, 'black'),
    );
  }

  final int white;
  final int blue;
  final int green;
  final int red;
  final int black;

  /// 转成完整颜色集合 JSON，适合状态展示和接口提交。
  JsonMap toJson() {
    return {
      'white': white,
      'blue': blue,
      'green': green,
      'red': red,
      'black': black,
    };
  }
}

/// 从 JSON 中读取 int 字段，缺失时返回 0。
int intValue(JsonMap? json, String key) => json?[key] as int? ?? 0;

/// 从后端数组字段解析字符串列表，空值按空列表处理。
List<String> stringList(Object? value) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => item as String)
      .toList(growable: false);
}

/// 从后端数组字段解析对象列表，`fromJson` 负责单个对象转换。
List<T> objectList<T>(Object? value, T Function(JsonMap json) fromJson) {
  return (value as List<dynamic>? ?? const [])
      .map((item) => fromJson(item as JsonMap))
      .toList(growable: false);
}
