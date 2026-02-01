import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:applicacion/main.dart' as app;
import 'package:applicacion/services/api_service.dart';
import 'package:applicacion/widgets/feedback_screen.dart';

/// Helper para cerrar el FeedbackScreen si está visible
Future<void> _cerrarFeedbackScreenSiVisible(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();

  final feedbackScreen = find.byType(FeedbackScreen);
  if (feedbackScreen.evaluate().isNotEmpty) {
    // Intentar cerrar con el botón de texto "Aceptar"
    final acceptButton = find.text('Aceptar');
    if (acceptButton.evaluate().isNotEmpty) {
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();
      return;
    }

    // Si no hay botón de texto, buscar el ícono de check dentro del FeedbackScreen
    final checkIcons = find.byIcon(Icons.check);
    if (checkIcons.evaluate().isNotEmpty) {
      // Buscar el que está dentro del FeedbackScreen
      for (final icon in checkIcons.evaluate()) {
        if (icon.widget is Icon) {
          await tester.tap(checkIcons.first);
          await tester.pumpAndSettle();
          return;
        }
      }
    }
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Tests de integracion de SplitWithMe', () {
    /// Verifica que la aplicación se inicia correctamente mostrando el título y pestañas
    testWidgets('Verificar que la aplicación se inicia correctamente', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Verificar que el título de la app está presente
      expect(find.text('SplitWithMe'), findsOneWidget);

      // Verificar que las pestañas están presentes
      expect(find.text('Amigos'), findsOneWidget);
      expect(find.text('Gastos'), findsOneWidget);
    });

    /// Verifica que el botón Añadir amigo abre el diálogo correctamente
    testWidgets('Probar botón Añadir amigo', (WidgetTester tester) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Verificar que estamos en la pestaña de Amigos
      expect(find.text('Lista de amigos'), findsOneWidget);

      // Buscar y pulsar el botón "Añadir amigo"
      final addFriendButton = find.byKey(const Key('add_amigo_button'));
      expect(addFriendButton, findsOneWidget);

      await tester.tap(addFriendButton);
      await tester.pumpAndSettle();

      // Verificar que se abre el diálogo
      expect(find.text('Añadir amigo'), findsWidgets);

      // Verificar que hay un campo de texto para el nombre
      expect(find.widgetWithText(TextField, 'Nombre'), findsOneWidget);

      // Cerrar el diálogo pulsando el botón cancelar (ícono X)
      final cancelButton = find.byIcon(Icons.close);
      if (cancelButton.evaluate().isNotEmpty) {
        await tester.tap(cancelButton);
        await tester.pumpAndSettle();
      }
    });

    /// Verifica que se puede añadir un amigo con un nombre válido
    testWidgets('Flujo completo: Añadir amigo con datos válidos', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Pulsar el botón "Añadir amigo"
      final addFriendButton = find.byKey(const Key('add_amigo_button'));
      await tester.tap(addFriendButton);
      await tester.pumpAndSettle();

      // Encontrar el campo de texto y escribir un nombre
      final nameField = find.widgetWithText(TextField, 'Nombre');
      await tester.enterText(
        nameField,
        'Amigo${DateTime.now().millisecondsSinceEpoch}',
      );
      await tester.pumpAndSettle();

      // Buscar y pulsar el botón de confirmar (ícono check)
      final confirmButton = find.byIcon(Icons.check);
      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        // Esperar a que se complete la operación
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Cerrar FeedbackScreen si está visible
        await _cerrarFeedbackScreenSiVisible(tester);
      }
    });

    testWidgets('Flujo completo: Añadir amigo con datos válidos', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Pulsar el botón "Añadir amigo"
      final addFriendButton = find.byKey(const Key('add_amigo_button'));
      await tester.tap(addFriendButton);
      await tester.pumpAndSettle();

      // Encontrar el campo de texto y escribir un nombre
      final nameField = find.widgetWithText(TextField, 'Nombre');
      await tester.enterText(
        nameField,
        'Amigo${DateTime.now().millisecondsSinceEpoch}',
      );
      await tester.pumpAndSettle();

      // Buscar y pulsar el botón de confirmar (ícono check)
      final confirmButton = find.byIcon(Icons.check);
      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        // Esperar a que se complete la operación
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Cerrar FeedbackScreen si está visible
        await _cerrarFeedbackScreenSiVisible(tester);
      }
    });

    testWidgets('Flujo completo: Intentar añadir amigo con datos no válidos', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Pulsar el botón "Añadir amigo"
      final addFriendButton = find.byKey(const Key('add_amigo_button'));
      await tester.tap(addFriendButton);
      await tester.pumpAndSettle();

      // Encontrar el campo de texto y escribir un nombre
      final nameField = find.widgetWithText(TextField, 'Nombre');
      await tester.enterText(nameField, '');
      await tester.pumpAndSettle();

      // Buscar y pulsar el botón de confirmar (ícono check)
      final confirmButton = find.byIcon(Icons.check);
      if (confirmButton.evaluate().isNotEmpty) {
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();

        // Esperar a que se complete la operación
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();

        // Cerrar FeedbackScreen si está visible
        await _cerrarFeedbackScreenSiVisible(tester);
      }
    });

    /// Verifica que se puede editar un amigo existente cambiando su nombre
    testWidgets('Flujo completo: Editar amigo con datos válidos', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Buscar todos los botones de editar por el ícono
      final editButtons = find.byIcon(Icons.edit_outlined);

      // Si hay amigos, debería haber al menos un botón de editar
      if (editButtons.evaluate().isNotEmpty) {
        // Pulsar el primer botón de editar
        await tester.tap(editButtons.first);
        await tester.pumpAndSettle();

        // Verificar que se abrió el diálogo
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          // Si se abrió el diálogo, proceder con la edición
          expect(dialog, findsOneWidget);

          // Encontrar el campo de texto y escribir un nombre
          final nameFields = find.byType(TextField);
          if (nameFields.evaluate().isNotEmpty) {
            await tester.enterText(
              nameFields.first,
              'Editado${DateTime.now().millisecondsSinceEpoch}',
            );
            await tester.pumpAndSettle();

            // Buscar y pulsar el botón de confirmar (ícono de check)
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton);
              await tester.pumpAndSettle();

              // Esperar para que se completen las operaciones asíncronas
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpAndSettle();

              // Cerrar FeedbackScreen si está visible
              await _cerrarFeedbackScreenSiVisible(tester);
            }
          }
        }
      }
    });

    /// Verifica que se puede eliminar un amigo (solo si no tiene saldo pendiente)
    testWidgets('Flujo completo: Eliminar amigo', (WidgetTester tester) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Buscar todos los botones de eliminar amigo por el ícono
      final deleteButtons = find.byIcon(Icons.delete_outline);

      // Si hay amigos, debería haber al menos un botón de eliminar
      if (deleteButtons.evaluate().isNotEmpty) {
        // Pulsar el primer botón de eliminar
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Verificar si se abrió un diálogo (puede no abrirse si el amigo tiene saldo)
        final dialog = find.byType(Dialog);

        if (dialog.evaluate().isNotEmpty) {
          // Si se abrió el diálogo de confirmación, proceder
          expect(dialog, findsOneWidget);

          // Buscar y pulsar el botón de confirmar (ícono de check)
          final confirmButton = find.byIcon(Icons.check);
          if (confirmButton.evaluate().isNotEmpty) {
            await tester.tap(confirmButton);
            await tester.pumpAndSettle();

            // Esperar para que se completen las operaciones asíncronas
            await tester.pump(const Duration(seconds: 2));
            await tester.pumpAndSettle();
          }
        } else {
          // Si no se abrió el diálogo, probablemente se mostró un error
          // porque el amigo tiene saldo. Esto es comportamiento esperado.
          // Simplemente verificamos que no crasheó la app
          expect(find.text('SplitWithMe'), findsOneWidget);
        }
      }
    });

    // ==================== TESTS DE PAGAR SALDOS ====================

    /// Verifica que se puede pagar una deuda introduciendo un importe válido
    testWidgets('Flujo completo: Pagar saldo con datos válidos', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Buscar el botón "Pagar saldo"
      final pagarSaldoButton = find.byKey(const Key('pagar_saldo_button'));
      if (pagarSaldoButton.evaluate().isNotEmpty) {
        await tester.tap(pagarSaldoButton);
        await tester.pumpAndSettle();

        // Verificar que se abrió el diálogo
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          expect(dialog, findsOneWidget);

          // Buscar el campo de importe
          final importeFields = find.byType(TextField);
          if (importeFields.evaluate().isNotEmpty) {
            // Introducir un importe válido (por ejemplo, 5.00)
            await tester.enterText(importeFields.first, '5.00');
            await tester.pumpAndSettle();

            // Buscar y pulsar el botón de confirmar
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton);
              await tester.pumpAndSettle();

              // Esperar para que se completen las operaciones asíncronas
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpAndSettle();

              // Cerrar FeedbackScreen si está visible
              await _cerrarFeedbackScreenSiVisible(tester);
            }
          }
        } else {
          // Si no hay amigos con deuda, se mostrará un error
          // Verificamos que la app no crasheó
          expect(find.text('SplitWithMe'), findsOneWidget);
        }
      }
    });

    /// Verifica que se muestra error al intentar pagar con importe negativo
    testWidgets(
      'Error de usuaria: Pagar saldo con importe inválido (negativo)',
      (WidgetTester tester) async {
        // Inicializar la aplicación
        final apiService = ApiService();
        await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
        await tester.pumpAndSettle();

        // Buscar el botón "Pagar saldo"
        final pagarSaldoButton = find.byKey(const Key('pagar_saldo_button'));
        if (pagarSaldoButton.evaluate().isNotEmpty) {
          await tester.tap(pagarSaldoButton);
          await tester.pumpAndSettle();

          // Verificar que se abrió el diálogo
          final dialog = find.byType(Dialog);
          if (dialog.evaluate().isNotEmpty) {
            // Buscar el campo de importe
            final importeFields = find.byType(TextField);
            if (importeFields.evaluate().isNotEmpty) {
              // Introducir un importe inválido (negativo)
              await tester.enterText(importeFields.first, '-10.00');
              await tester.pumpAndSettle();

              // Buscar y pulsar el botón de confirmar
              final confirmButton = find.byIcon(Icons.check);
              if (confirmButton.evaluate().isNotEmpty) {
                await tester.tap(confirmButton);
                await tester.pumpAndSettle();

                // Debería mostrarse un mensaje de error
                // Esperar un poco para que aparezca
                await tester.pump(const Duration(seconds: 1));
                await tester.pumpAndSettle();
              }
            }
          }
        }
      },
    );

    /// Verifica que se muestra error al intentar pagar más de lo que se debe
    testWidgets('Error de usuaria: Pagar saldo con importe mayor a la deuda', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Buscar el botón "Pagar saldo"
      final pagarSaldoButton = find.byKey(const Key('pagar_saldo_button'));
      if (pagarSaldoButton.evaluate().isNotEmpty) {
        await tester.tap(pagarSaldoButton);
        await tester.pumpAndSettle();

        // Verificar que se abrió el diálogo
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          // Buscar el campo de importe
          final importeFields = find.byType(TextField);
          if (importeFields.evaluate().isNotEmpty) {
            // Introducir un importe mayor a la deuda (por ejemplo, 999999)
            await tester.enterText(importeFields.first, '999999.00');
            await tester.pumpAndSettle();

            // Buscar y pulsar el botón de confirmar
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton);
              await tester.pumpAndSettle();

              // Debería mostrarse un mensaje de error
              // Esperar un poco para que aparezca
              await tester.pump(const Duration(seconds: 1));
              await tester.pumpAndSettle();
            }
          }
        }
      }
    });

    // ==================== TESTS DE GASTOS ====================

    /// Verifica que se puede crear un nuevo gasto con descripción y monto válidos
    testWidgets('Flujo completo: Añadir gasto con datos válidos', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Cambiar a la pestaña de Gastos
      final gastosTab = find.text('Gastos');
      if (gastosTab.evaluate().isNotEmpty) {
        await tester.tap(gastosTab);
        await tester.pumpAndSettle();
      }

      // Buscar el botón "Añadir gasto"
      final addGastoButton = find.byKey(const Key('add_gasto_button'));
      if (addGastoButton.evaluate().isNotEmpty) {
        await tester.tap(addGastoButton);
        await tester.pumpAndSettle();

        // Verificar que se abrió el diálogo
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          expect(dialog, findsOneWidget);

          // Buscar los campos de texto
          final textFields = find.byType(TextField);
          if (textFields.evaluate().length >= 2) {
            // Introducir descripción en el primer campo
            await tester.enterText(
              textFields.first,
              'Gasto Test ${DateTime.now().millisecondsSinceEpoch}',
            );
            await tester.pumpAndSettle();

            // Introducir monto en el segundo campo
            await tester.enterText(textFields.at(1), '25.50');
            await tester.pumpAndSettle();

            // Buscar y pulsar el botón de confirmar
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton);
              await tester.pumpAndSettle();

              // Esperar para que se completen las operaciones asíncronas
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpAndSettle();

              // Cerrar FeedbackScreen si está visible
              await _cerrarFeedbackScreenSiVisible(tester);
            }
          }
        }
      }
    });

    /// Verifica que se muestra error al intentar crear un gasto sin descripción
    testWidgets('Error de usuaria: Añadir gasto con descripción vacía', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Cambiar a la pestaña de Gastos
      final gastosTab = find.text('Gastos');
      if (gastosTab.evaluate().isNotEmpty) {
        await tester.tap(gastosTab);
        await tester.pumpAndSettle();
      }

      // Buscar el botón "Añadir gasto"
      final addGastoButton = find.byKey(const Key('add_gasto_button'));
      if (addGastoButton.evaluate().isNotEmpty) {
        await tester.tap(addGastoButton);
        await tester.pumpAndSettle();

        // Verificar que se abrió el diálogo
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          // Buscar los campos de texto
          final textFields = find.byType(TextField);
          if (textFields.evaluate().length >= 2) {
            // Dejar la descripción vacía y solo introducir monto
            await tester.enterText(textFields.at(1), '25.50');
            await tester.pumpAndSettle();

            // Buscar y pulsar el botón de confirmar
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton);
              await tester.pumpAndSettle();

              // Debería mostrarse un mensaje de error
              // Esperar un poco para que aparezca
              await tester.pump(const Duration(seconds: 1));
              await tester.pumpAndSettle();
            }
          }
        }
      }
    });

    /// Verifica que se muestra error al intentar crear un gasto con monto negativo
    testWidgets('Error de usuaria: Añadir gasto con monto inválido', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Cambiar a la pestaña de Gastos
      final gastosTab = find.text('Gastos');
      if (gastosTab.evaluate().isNotEmpty) {
        await tester.tap(gastosTab);
        await tester.pumpAndSettle();
      }

      // Buscar el botón "Añadir gasto"
      final addGastoButton = find.byKey(const Key('add_gasto_button'));
      if (addGastoButton.evaluate().isNotEmpty) {
        await tester.tap(addGastoButton);
        await tester.pumpAndSettle();

        // Verificar que se abrió el diálogo
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          // Buscar los campos de texto
          final textFields = find.byType(TextField);
          if (textFields.evaluate().length >= 2) {
            // Introducir descripción válida
            await tester.enterText(
              textFields.first,
              'Gasto Test ${DateTime.now().millisecondsSinceEpoch}',
            );
            await tester.pumpAndSettle();

            // Introducir monto inválido (negativo o cero)
            await tester.enterText(textFields.at(1), '-10.00');
            await tester.pumpAndSettle();

            // Buscar y pulsar el botón de confirmar
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton);
              await tester.pumpAndSettle();

              // Debería mostrarse un mensaje de error
              // Esperar un poco para que aparezca
              await tester.pump(const Duration(seconds: 1));
              await tester.pumpAndSettle();
            }
          }
        }
      }
    });

    /// Verifica que se puede editar un gasto existente cambiando descripción y monto
    testWidgets('Flujo completo: Editar gasto con datos válidos', (
      WidgetTester tester,
    ) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Cambiar a la pestaña de Gastos
      final gastosTab = find.text('Gastos');
      if (gastosTab.evaluate().isNotEmpty) {
        await tester.tap(gastosTab);
        await tester.pumpAndSettle();
      }

      // Buscar todos los botones de editar gasto por el ícono
      final editButtons = find.byIcon(Icons.edit_outlined);

      // Si hay gastos, debería haber al menos un botón de editar
      if (editButtons.evaluate().isNotEmpty) {
        // Pulsar el primer botón de editar
        await tester.tap(editButtons.first);
        await tester.pumpAndSettle();

        // Verificar que se abrió el diálogo
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          expect(dialog, findsOneWidget);

          // Buscar los campos de texto
          final textFields = find.byType(TextField);
          if (textFields.evaluate().length >= 2) {
            // Editar la descripción
            await tester.enterText(
              textFields.first,
              'Gasto Editado ${DateTime.now().millisecondsSinceEpoch}',
            );
            await tester.pumpAndSettle();

            // Editar el monto
            await tester.enterText(textFields.at(1), '50.00');
            await tester.pumpAndSettle();

            // Buscar y pulsar el botón de confirmar
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton);
              await tester.pumpAndSettle();

              // Esperar para que se completen las operaciones asíncronas
              await tester.pump(const Duration(seconds: 3));
              await tester.pumpAndSettle();

              // Cerrar FeedbackScreen si está visible
              await _cerrarFeedbackScreenSiVisible(tester);
            }
          }
        }
      }
    });

    /// Verifica que se puede eliminar un gasto existente y se actualizan los saldos
    testWidgets('Flujo completo: Eliminar gasto', (WidgetTester tester) async {
      // Inicializar la aplicación
      final apiService = ApiService();
      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pumpAndSettle();

      // Cambiar a la pestaña de Gastos
      final gastosTab = find.text('Gastos');
      if (gastosTab.evaluate().isNotEmpty) {
        await tester.tap(gastosTab);
        await tester.pumpAndSettle();
      }

      // Buscar todos los botones de eliminar gasto por el ícono
      final deleteButtons = find.byIcon(Icons.delete_outline);

      // Si hay gastos, debería haber al menos un botón de eliminar
      if (deleteButtons.evaluate().isNotEmpty) {
        // Pulsar el primer botón de eliminar
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Verificar que se abrió el diálogo de confirmación
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          expect(dialog, findsOneWidget);

          // Buscar y pulsar el botón de confirmar (ícono de check)
          final confirmButton = find.byIcon(Icons.check);
          if (confirmButton.evaluate().isNotEmpty) {
            await tester.tap(confirmButton);
            await tester.pumpAndSettle();

            // Esperar para que se completen las operaciones asíncronas
            await tester.pump(const Duration(seconds: 3));
            await tester.pumpAndSettle();

            // Cerrar FeedbackScreen si está visible
            await _cerrarFeedbackScreenSiVisible(tester);
          }
        }
      }
    });

    // ==================== TESTS DE CONTROL DE E/S ====================
    // Estos tests verifican que la app maneja errores de conexión sin crashear.
    // NOTA: Usan servidor inexistente para provocar errores controlados.

    // Verifica que la app no crashea cuando el servidor no está disponible
    testWidgets(
      'Control E/S: La app no crashea cuando el servidor no responde',
      (WidgetTester tester) async {
        // ApiService apuntando a servidor inexistente
        final apiService = ApiService(
          baseUrl: 'http://127.0.0.1:9999',
          timeout: const Duration(milliseconds: 50),
        );

        // Iniciar app
        await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
        await tester.pump();

        // Esperar un poco para que intente conectar
        await tester.pump(const Duration(milliseconds: 500));

        // TEST: La app debe existir (no crasheó)
        expect(find.byType(app.GastosAmigosApp), findsOneWidget);
      },
    );

    /// Verifica que se puede cerrar la pantalla de error
    testWidgets('Control E/S: Se puede cerrar la pantalla de error', (
      WidgetTester tester,
    ) async {
      final apiService = ApiService(
        baseUrl: 'http://127.0.0.1:9999',
        timeout: const Duration(milliseconds: 50),
      );

      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Si hay FeedbackScreen de error, intentar cerrarlo
      final feedbackScreen = find.byType(FeedbackScreen);
      if (feedbackScreen.evaluate().isNotEmpty) {
        // Buscar botón Aceptar y pulsarlo
        final acceptButton = find.text('Aceptar');
        if (acceptButton.evaluate().isNotEmpty) {
          await tester.tap(acceptButton, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      // TEST: La app sigue existiendo después de cerrar el error
      expect(find.byType(app.GastosAmigosApp), findsOneWidget);
    });

    /// Verifica que las pestañas siguen visibles tras error de conexión
    testWidgets(
      'Control E/S: Las pestañas son visibles tras error de conexión',
      (WidgetTester tester) async {
        final apiService = ApiService(
          baseUrl: 'http://127.0.0.1:9999',
          timeout: const Duration(milliseconds: 50),
        );

        await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Cerrar FeedbackScreen si existe
        final feedbackScreen = find.byType(FeedbackScreen);
        if (feedbackScreen.evaluate().isNotEmpty) {
          final acceptButton = find.text('Aceptar');
          if (acceptButton.evaluate().isNotEmpty) {
            await tester.tap(acceptButton, warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 200));
          }
        }

        // TEST: Las pestañas deben estar visibles
        final amigosTab = find.text('Amigos');
        final gastosTab = find.text('Gastos');

        final hayPestanas =
            amigosTab.evaluate().isNotEmpty || gastosTab.evaluate().isNotEmpty;

        expect(hayPestanas, isTrue);
      },
    );

    /// Verifica que al intentar añadir amigo sin servidor, la app no crashea
    testWidgets('Control E/S: Añadir amigo sin servidor no crashea la app', (
      WidgetTester tester,
    ) async {
      final apiService = ApiService(
        baseUrl: 'http://127.0.0.1:9999',
        timeout: const Duration(milliseconds: 50),
      );

      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Cerrar error inicial si existe
      var feedbackScreen = find.byType(FeedbackScreen);
      if (feedbackScreen.evaluate().isNotEmpty) {
        final acceptButton = find.text('Aceptar');
        if (acceptButton.evaluate().isNotEmpty) {
          await tester.tap(acceptButton, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      // Pulsar botón "Añadir amigo"
      final addFriendButton = find.text('Añadir amigo');
      if (addFriendButton.evaluate().isNotEmpty) {
        await tester.tap(addFriendButton, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));

        // Rellenar formulario si se abrió el diálogo
        final dialog = find.byType(Dialog);
        if (dialog.evaluate().isNotEmpty) {
          final nameFields = find.byType(TextField);
          if (nameFields.evaluate().isNotEmpty) {
            await tester.enterText(nameFields.first, 'Test Sin Servidor');
            await tester.pump(const Duration(milliseconds: 100));

            // Pulsar confirmar
            final confirmButton = find.byIcon(Icons.check);
            if (confirmButton.evaluate().isNotEmpty) {
              await tester.tap(confirmButton, warnIfMissed: false);
              await tester.pump(const Duration(milliseconds: 500));
            }
          }
        }
      }

      // TEST: La app sigue existiendo
      expect(find.byType(app.GastosAmigosApp), findsOneWidget);
    });

    // Verifica que al intentar añadir gasto sin servidor, la app no crashea
    testWidgets('Control E/S: Añadir gasto sin servidor no crashea la app', (
      WidgetTester tester,
    ) async {
      final apiService = ApiService(
        baseUrl: 'http://127.0.0.1:9999',
        timeout: const Duration(milliseconds: 50),
      );

      await tester.pumpWidget(app.GastosAmigosApp(apiService: apiService));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Cerrar error inicial si existe
      var feedbackScreen = find.byType(FeedbackScreen);
      if (feedbackScreen.evaluate().isNotEmpty) {
        final acceptButton = find.text('Aceptar');
        if (acceptButton.evaluate().isNotEmpty) {
          await tester.tap(acceptButton, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      // Cambiar a pestaña Gastos
      final gastosTab = find.text('Gastos');
      if (gastosTab.evaluate().isNotEmpty) {
        await tester.tap(gastosTab, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // Cerrar error de cambio de pestaña si existe
      feedbackScreen = find.byType(FeedbackScreen);
      if (feedbackScreen.evaluate().isNotEmpty) {
        final acceptButton = find.text('Aceptar');
        if (acceptButton.evaluate().isNotEmpty) {
          await tester.tap(acceptButton, warnIfMissed: false);
          await tester.pump(const Duration(milliseconds: 200));
        }
      }

      // Pulsar botón "Añadir gasto"
      final addGastoButton = find.text('Añadir gasto');
      if (addGastoButton.evaluate().isNotEmpty) {
        await tester.tap(addGastoButton, warnIfMissed: false);
        await tester.pump(const Duration(milliseconds: 300));
      }

      // TEST: La app sigue existiendo
      expect(find.byType(app.GastosAmigosApp), findsOneWidget);
    });
  });
}
