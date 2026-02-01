// Este es un test básico de widgets de Flutter.
//
// Para interactuar con un widget en tu test, usa la utilidad WidgetTester
// del paquete flutter_test. Por ejemplo, puedes enviar gestos de tap y scroll.
// También puedes usar WidgetTester para encontrar widgets hijos en el árbol,
// leer texto y verificar que los valores de las propiedades son correctos.

import 'package:flutter_test/flutter_test.dart';

import 'package:applicacion/main.dart';
import 'package:applicacion/services/api_service.dart';

void main() {
  testWidgets('La app muestra las pestañas principales', (WidgetTester tester) async {
    // Construir la app y esperar a que se estabilicen los frames iniciales
    await tester.pumpWidget(GastosAmigosApp(apiService: ApiService()));
    await tester.pumpAndSettle();

    // Verificar que las dos pestañas principales están presentes
    expect(find.text('Amigos'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);

    // Interacción básica: cambiar a la pestaña Gastos y volver
    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();
    expect(find.text('Gastos registrados'), findsOneWidget);

    // Interacción básica: cambiar a la pestaña Amigos y volver
    await tester.tap(find.text('Amigos'));
    await tester.pumpAndSettle();
    expect(find.text('Nombre del amigo'), findsOneWidget);
  });
}
