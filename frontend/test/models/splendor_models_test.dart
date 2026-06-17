import 'package:board_game_ai/models/splendor_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses catalog response', () {
    final catalog = SplendorCatalogResponse.fromJson({
      'cards': [
        {
          'id': 'dev-1-001',
          'level': 1,
          'bonusColor': 'white',
          'prestige': 0,
          'cost': {'white': 0, 'blue': 3, 'green': 0, 'red': 0, 'black': 0},
        },
      ],
      'nobles': [
        {
          'id': 'noble-001',
          'prestige': 3,
          'requirement': {
            'white': 3,
            'blue': 3,
            'green': 0,
            'red': 0,
            'black': 3,
          },
        },
      ],
    });

    expect(catalog.cards.single.id, 'dev-1-001');
    expect(catalog.cards.single.cost.blue, 3);
    expect(catalog.nobles.single.requirement.black, 3);
  });

  test('parses game state pending action', () {
    final state = SplendorGameState.fromJson({
      'gameType': 'splendor',
      'status': 'active',
      'playerCount': 2,
      'currentTurnIndex': 0,
      'currentPlayerIndex': 0,
      'tokenPool': {
        'white': 4,
        'blue': 4,
        'green': 4,
        'red': 4,
        'black': 4,
        'gold': 5,
      },
      'markets': {'level1': [], 'level2': [], 'level3': []},
      'decks': {'level1': [], 'level2': [], 'level3': []},
      'nobles': [],
      'players': [
        {
          'seatIndex': 0,
          'name': 'A',
          'type': 'human',
          'score': 0,
          'tokens': {
            'white': 0,
            'blue': 0,
            'green': 0,
            'red': 0,
            'black': 0,
            'gold': 0,
          },
          'bonuses': {'white': 0, 'blue': 0, 'green': 0, 'red': 0, 'black': 0},
          'purchasedCards': [],
          'reservedCards': [],
          'nobles': [],
        },
      ],
      'finalRound': {
        'triggered': false,
        'triggeredByPlayerIndex': null,
        'roundEndPlayerIndex': null,
      },
      'pendingAction': {
        'type': 'discard_tokens',
        'playerIndex': 0,
        'tokenCount': 12,
        'maxTokenCount': 10,
      },
      'winnerPlayerIndex': null,
    });

    expect(state.pendingAction?.type, SplendorActionType.discardTokens);
    expect(state.pendingAction?.tokenCount, 12);
  });

  test('serializes create session and action inputs', () {
    final input = SplendorCreateSessionInput(
      playerCount: 2,
      players: const [
        SplendorCreatePlayerInput(name: 'A'),
        SplendorCreatePlayerInput(name: 'B'),
      ],
    );

    expect(input.toJson()['playerCount'], 2);
    expect((input.toJson()['players'] as List).first['type'], 'human');

    final action = SplendorAction.takeTokens(
      const SplendorTokenSet(white: 1, blue: 1, green: 1),
    );
    expect(action.toJson(), {
      'type': 'take_tokens',
      'tokens': {'white': 1, 'blue': 1, 'green': 1},
    });
  });
}
