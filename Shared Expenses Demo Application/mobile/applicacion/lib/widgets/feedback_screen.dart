import 'package:flutter/material.dart';

/// Pantalla de feedback (éxito o error) que se muestra después de una operación
/// 
/// Este widget muestra un mensaje de éxito o error al usuario después de completar
/// una operación (como añadir un amigo, crear un gasto, etc.)
/// 
/// Características:
/// - Diseño según especificación de UI (con estrellitas, colores, etc.)
/// - Navegación como diálogo de pantalla completa
/// - Callback opcional para ejecutar acciones después de cerrar
class FeedbackScreen extends StatelessWidget {
  const FeedbackScreen({
    super.key,
    required this.isSuccess,
    required this.message,
    this.onReturn,
  });

  /// Indica si el feedback es de éxito (true) o error (false)
  /// Determina los colores y el estilo de la pantalla
  final bool isSuccess;
  
  /// Mensaje a mostrar al usuario
  final String message;
  
  /// Callback opcional que se ejecuta al volver (después de cerrar la pantalla)
  /// Útil para ejecutar acciones adicionales después de mostrar el feedback
  final VoidCallback? onReturn;

  /// Muestra una pantalla de éxito como diálogo de pantalla completa
  /// 
  /// Este método estático facilita mostrar la pantalla de feedback desde cualquier lugar
  /// sin necesidad de instanciar manualmente el widget y manejar la navegación
  /// 
  /// Parámetros:
  /// - [context]: Contexto de construcción necesario para la navegación
  /// - [message]: Mensaje de éxito a mostrar
  /// - [onReturn]: Callback opcional a ejecutar después de cerrar
  /// 
  /// Usa postFrameCallback anidados para asegurar que cualquier diálogo anterior
  /// se haya cerrado antes de mostrar este nuevo diálogo
  static void showSuccess(
    BuildContext context,
    String message, {
    VoidCallback? onReturn,
  }) {
    // Esperar múltiples frames para asegurar que cualquier diálogo anterior se haya cerrado
    // Esto previene conflictos de navegación cuando hay múltiples operaciones rápidas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Verificar que el contexto todavía esté montado antes de navegar
        // Esto previene errores si el widget fue destruido antes de ejecutar el callback
        if (!context.mounted) return;
        try {
          // Usar rootNavigator para asegurar que siempre encontramos un Navigator
          // rootNavigator: true busca el Navigator más arriba en el árbol de widgets
          final navigator = Navigator.of(context, rootNavigator: true);
          navigator.push(
            MaterialPageRoute(
              builder: (context) => FeedbackScreen(
                isSuccess: true,
                message: message,
                onReturn: onReturn,
              ),
              // fullscreenDialog hace que la transición sea de arriba hacia abajo (estilo iOS)
              fullscreenDialog: true,
            ),
          );
        } catch (e) {
          // Si falla la navegación, simplemente ignoramos el error
          // Esto puede ocurrir si el contexto ya no es válido (widget destruido)
        }
      });
    });
  }

  /// Muestra una pantalla de error como diálogo de pantalla completa
  /// 
  /// Similar a showSuccess() pero para mostrar mensajes de error
  /// La pantalla tendrá colores rojos en lugar de verdes
  /// 
  /// Parámetros:
  /// - [context]: Contexto de construcción necesario para la navegación
  /// - [message]: Mensaje de error a mostrar
  /// - [onReturn]: Callback opcional a ejecutar después de cerrar
  static void showError(
    BuildContext context,
    String message, {
    VoidCallback? onReturn,
  }) {
    // Esperar múltiples frames para asegurar que cualquier diálogo anterior se haya cerrado
    // Esto previene conflictos de navegación cuando hay múltiples operaciones rápidas
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Verificar que el contexto todavía esté montado antes de navegar
        if (!context.mounted) return;
        try {
          // Usar rootNavigator para asegurar que siempre encontramos un Navigator
          final navigator = Navigator.of(context, rootNavigator: true);
          navigator.push(
            MaterialPageRoute(
              builder: (context) => FeedbackScreen(
                isSuccess: false, // Marca como error (colores rojos)
                message: message,
                onReturn: onReturn,
              ),
              fullscreenDialog: true, // Transición de arriba hacia abajo
            ),
          );
        } catch (e) {
          // Si falla la navegación, simplemente ignoramos el error
          // Esto puede ocurrir si el contexto ya no es válido
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Colores dinámicos según el tipo de feedback (éxito o error)
    // Si es éxito: colores verdes; si es error: colores rojos
    final backgroundColor = isSuccess
        ? Colors.green.shade100  // Fondo verde claro para éxito
        : Colors.red.shade100;    // Fondo rojo claro para error
    final textColor = isSuccess ? Colors.green.shade900 : Colors.red.shade900;
    final iconColor = isSuccess ? Colors.green : Colors.red;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Estrellitas indicadoras (★★)
              Row(
                children: [
                  Text(
                    '★★',
                    style: TextStyle(
                      color: isSuccess ? Colors.green : Colors.red,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Contenedor con el mensaje
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade400, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Líneas decorativas (representando texto)
                    _MessageLine(),
                    const SizedBox(height: 12),
                    _MessageLine(),
                    const SizedBox(height: 12),
                    _MessageLine(),
                    const SizedBox(height: 24),

                    // Mensaje real
                    Text(
                      message,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Botón de confirmar (✓) con texto visible
              // Semantics ayuda con accesibilidad (lectores de pantalla)
              Center(
                child: Semantics(
                  button: true,  // Indica que es un botón para lectores de pantalla
                  label: 'Aceptar',  // Texto descriptivo para accesibilidad
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: iconColor,  // Color verde o rojo según el tipo
                        shape: const CircleBorder(
                          side: BorderSide(color: Colors.black, width: 2),
                        ),
                        child: InkWell(
                          // InkWell proporciona el efecto de ripple (onda) al tocar
                          onTap: () {
                            // Cerrar la pantalla de feedback
                            Navigator.of(context).pop();
                            // Ejecutar callback opcional si se proporcionó
                            onReturn?.call();
                          },
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 64,
                            height: 64,
                            child: Icon(
                              Icons.check,  // Ícono de checkmark (✓)
                              color: Colors.white,
                              size: 36,
                              semanticLabel: 'Aceptar',  // Para accesibilidad
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aceptar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Texto explicativo
              Text(
                isSuccess
                    ? 'Las pantallas con éxito muestran mensaje y vuelven a la pantalla anterior'
                    : 'Las pantallas con error pueden mostrar mensajes de error',
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget privado que muestra una línea decorativa para el diseño visual dentro de la pantalla de feedback
class _MessageLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
