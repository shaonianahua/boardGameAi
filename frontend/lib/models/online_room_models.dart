/// 在线房间 API 模型。
///
/// 对齐后端 `features/online` 模块，当前只覆盖房间大厅 MVP：
/// 创建房间、加入房间、查询房间、订阅房间事件。
typedef OnlineJsonMap = Map<String, dynamic>;

/// 在线房间生命周期状态。
enum OnlineRoomStatus {
  waiting,
  playing,
  finished,
  closed;

  /// 从后端字符串解析房间状态，未知值按等待中处理。
  static OnlineRoomStatus fromJson(String? value) {
    return switch (value) {
      'playing' => OnlineRoomStatus.playing,
      'finished' => OnlineRoomStatus.finished,
      'closed' => OnlineRoomStatus.closed,
      _ => OnlineRoomStatus.waiting,
    };
  }

  /// 转成后端接口使用的状态字符串。
  String toJson() => name;
}

/// 在线房间座位控制方式。
enum OnlineSeatControlType {
  human('human'),
  localBot('local_bot'),
  aiPlayer('ai_player');

  const OnlineSeatControlType(this.value);

  /// 后端接口使用的 controlType 字符串。
  final String value;

  /// 从后端字符串解析座位控制方式，未知值按真人处理。
  static OnlineSeatControlType fromJson(String? value) {
    return switch (value) {
      'local_bot' => OnlineSeatControlType.localBot,
      'ai_player' => OnlineSeatControlType.aiPlayer,
      _ => OnlineSeatControlType.human,
    };
  }

  /// 转成后端接口使用的字符串。
  String toJson() => value;
}

/// 创建在线房间请求体，对应 `POST /api/online/rooms`。
class CreateOnlineRoomInput {
  /// 构造创建房间请求；`clientId` 为空时后端会生成临时 ID。
  const CreateOnlineRoomInput({
    this.gameType = 'splendor',
    required this.hostName,
    this.clientId,
  });

  final String gameType;
  final String hostName;
  final String? clientId;

  /// 转成后端创建房间接口需要的 JSON。
  OnlineJsonMap toJson() {
    return {
      'gameType': gameType,
      'hostName': hostName,
      if (clientId != null && clientId!.isNotEmpty) 'clientId': clientId,
    };
  }
}

/// 加入在线房间请求体，对应 `POST /api/online/rooms/join`。
class JoinOnlineRoomInput {
  /// 构造加入房间请求；`controlType` 当前默认真人玩家。
  const JoinOnlineRoomInput({
    required this.roomCode,
    required this.playerName,
    this.clientId,
    this.controlType = OnlineSeatControlType.human,
  });

  final String roomCode;
  final String playerName;
  final String? clientId;
  final OnlineSeatControlType controlType;

  /// 转成后端加入房间接口需要的 JSON。
  OnlineJsonMap toJson() {
    return {
      'roomCode': roomCode,
      'playerName': playerName,
      if (clientId != null && clientId!.isNotEmpty) 'clientId': clientId,
      'controlType': controlType.toJson(),
    };
  }
}

/// 在线房间座位公开信息，由 REST 接口和 WebSocket 事件共同返回。
class OnlineRoomSeat {
  /// 构造一个在线房间座位快照。
  const OnlineRoomSeat({
    required this.id,
    required this.roomId,
    required this.seatIndex,
    required this.playerName,
    required this.clientId,
    required this.controlType,
    required this.ready,
    required this.connected,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从后端座位 JSON 解析座位快照。
  factory OnlineRoomSeat.fromJson(OnlineJsonMap json) {
    return OnlineRoomSeat(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      seatIndex: json['seatIndex'] as int? ?? 0,
      playerName: json['playerName'] as String? ?? '',
      clientId: json['clientId'] as String? ?? '',
      controlType: OnlineSeatControlType.fromJson(
        json['controlType'] as String?,
      ),
      ready: json['ready'] as bool? ?? false,
      connected: json['connected'] as bool? ?? false,
      createdAt: _dateTimeValue(json['createdAt']),
      updatedAt: _dateTimeValue(json['updatedAt']),
    );
  }

  final String id;
  final String roomId;
  final int seatIndex;
  final String playerName;
  final String clientId;
  final OnlineSeatControlType controlType;
  final bool ready;
  final bool connected;
  final DateTime? createdAt;
  final DateTime? updatedAt;
}

/// 在线房间公开快照，由 REST 接口和 WebSocket 事件共同返回。
class OnlineRoom {
  /// 构造一个在线房间快照。
  const OnlineRoom({
    required this.id,
    required this.roomCode,
    required this.gameType,
    required this.status,
    required this.hostSeatIndex,
    required this.sessionId,
    required this.seats,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 从后端房间 JSON 解析房间快照。
  factory OnlineRoom.fromJson(OnlineJsonMap json) {
    return OnlineRoom(
      id: json['id'] as String? ?? '',
      roomCode: json['roomCode'] as String? ?? '',
      gameType: json['gameType'] as String? ?? 'splendor',
      status: OnlineRoomStatus.fromJson(json['status'] as String?),
      hostSeatIndex: json['hostSeatIndex'] as int?,
      sessionId: json['sessionId'] as String?,
      seats: (json['seats'] as List<dynamic>? ?? const [])
          .map((item) => OnlineRoomSeat.fromJson(item as OnlineJsonMap))
          .toList(growable: false),
      createdAt: _dateTimeValue(json['createdAt']),
      updatedAt: _dateTimeValue(json['updatedAt']),
    );
  }

  final String id;
  final String roomCode;
  final String gameType;
  final OnlineRoomStatus status;
  final int? hostSeatIndex;
  final String? sessionId;
  final List<OnlineRoomSeat> seats;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 按座位号查找座位，页面展示座位列表时使用。
  OnlineRoomSeat? seatAt(int seatIndex) {
    for (final seat in seats) {
      if (seat.seatIndex == seatIndex) {
        return seat;
      }
    }
    return null;
  }
}

/// 在线房间 WebSocket 事件。
class OnlineRoomEvent {
  /// 构造一个在线房间事件。
  const OnlineRoomEvent({required this.type, required this.room});

  /// 从 WebSocket JSON 解析房间事件；不含 room 的消息会返回 null。
  factory OnlineRoomEvent.fromJson(OnlineJsonMap json) {
    return OnlineRoomEvent(
      type: json['type'] as String? ?? 'unknown',
      room: OnlineRoom.fromJson(json['room'] as OnlineJsonMap),
    );
  }

  final String type;
  final OnlineRoom room;
}

/// 安全解析后端时间字段，缺失或格式异常时返回 null。
DateTime? _dateTimeValue(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
