import 'package:board_game_ai/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Index page renders app entry', (tester) async {
    await tester.pumpWidget(const BoardGameAiApp());

    expect(find.text('AI人玩桌游'), findsOneWidget);
    expect(find.text('璀璨宝石'), findsOneWidget);
    expect(find.text('开始对局'), findsOneWidget);
  });
}
