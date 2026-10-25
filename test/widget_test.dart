import 'package:flutter_test/flutter_test.dart';
import 'package:survivors_arena/main.dart';

void main() {
  testWidgets('la pantalla inicial muestra la opcion de iniciar', (
    tester,
  ) async {
    await tester.pumpWidget(const SurvivorsArenaApp());

    expect(find.text('Survivors Arena'), findsOneWidget);
    expect(find.text('Iniciar partida'), findsOneWidget);
  });
}
