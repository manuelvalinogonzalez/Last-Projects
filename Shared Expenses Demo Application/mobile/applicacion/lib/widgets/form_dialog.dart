import 'package:flutter/material.dart';

/// Diálogo de formulario personalizado con botones de confirmar (✓) y cancelar (✗)
/// según el diseño de la UI
/// 
/// Este widget proporciona un diálogo reutilizable que se puede usar para cualquier formulario.
/// Sigue el diseño especificado con:
/// - Título con estrellitas (★★) para indicar campos requeridos
/// - Botones circulares con íconos y texto visible
/// - Soporte para scroll si el contenido es largo
/// - Validación mediante el parámetro confirmEnabled
class FormDialog extends StatelessWidget {
  const FormDialog({
    super.key,
    required this.title,
    required this.children,
    required this.onConfirm,
    this.confirmEnabled = true,
  });

  /// Título del diálogo que se muestra en la parte superior
  final String title;
  
  /// Lista de widgets (campos de formulario) que se muestran en el diálogo
  /// Puede contener cualquier widget, pero típicamente son FormTextField
  final List<Widget> children;
  
  /// Callback que se ejecuta cuando se presiona el botón de confirmar (✓)
  final VoidCallback onConfirm;
  
  /// Indica si el botón de confirmar está habilitado
  /// Si es false, el botón se muestra deshabilitado (gris) y no responde a toques
  /// Útil para validación: solo permitir confirmar cuando los datos sean válidos
  final bool confirmEnabled;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Título con estrellitas (para indicar campos requeridos)
            // Las estrellitas rojas son parte del diseño de UI especificado
            Row(
              children: [
                const Text(
                  '★★',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
                const SizedBox(width: 8), // Espacio entre estrellitas y título
                Expanded(
                  // Expanded hace que el título ocupe el espacio restante
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16), // Espacio entre título y campos

            // Envolver los campos en SingleChildScrollView para permitir scroll
            // Flexible permite que el contenido se ajuste al espacio disponible
            // Si hay muchos campos, se puede hacer scroll en lugar de desbordarse
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Solo ocupa el espacio necesario
                  crossAxisAlignment: CrossAxisAlignment.stretch, // Campos a lo ancho
                  children: children, // Los campos del formulario
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Botones de acción (✓ y ✗)
            // Los Keys son útiles para testing (encontrar los botones por ID)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribuir uniformemente
              children: [
                // Botón de confirmar (✓)
                _CircleActionButton(
                  key: const Key('dialog_aceptar_button'), // Para testing
                  icon: Icons.check, // Ícono de checkmark
                  // Cambiar color según si está habilitado o no
                  backgroundColor: confirmEnabled
                      ? Colors.green    // Verde si está habilitado
                      : Colors.grey.shade300, // Gris si está deshabilitado
                  iconColor: confirmEnabled ? Colors.white : Colors.grey,
                  label: 'Aceptar',
                  // Solo ejecutar onConfirm si está habilitado, si no null (deshabilitado)
                  onPressed: confirmEnabled ? onConfirm : null,
                ),

                // Botón de cancelar (✗)
                _CircleActionButton(
                  key: const Key('dialog_cancelar_button'), // Para testing
                  icon: Icons.close, // Ícono de X
                  backgroundColor: Colors.red, // Siempre rojo
                  iconColor: Colors.white,
                  label: 'Cancelar',
                  // Cerrar el diálogo (pop del Navigator)
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Botón circular de acción (✓ o ✗) con texto visible debajo
/// 
/// Widget privado (prefijo '_') que representa un botón circular con ícono y etiqueta.
/// Sigue el diseño de UI especificado donde los botones tienen:
/// - Forma circular con borde negro
/// - Ícono en el centro
/// - Texto descriptivo debajo
/// 
/// Se usa tanto para el botón de confirmar (✓) como para cancelar (✗)
class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    super.key,
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    required this.label,
    this.onPressed,
  });

  /// Ícono a mostrar en el centro del botón (ej: Icons.check, Icons.close)
  final IconData icon;
  
  /// Color de fondo del botón circular
  final Color backgroundColor;
  
  /// Color del ícono
  final Color iconColor;
  
  /// Texto visible debajo del botón (ej: "Aceptar", "Cancelar")
  final String label;
  
  /// Callback que se ejecuta al presionar el botón
  /// Si es null, el botón está deshabilitado (no responde a toques)
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: backgroundColor,
            shape: const CircleBorder(
              side: BorderSide(color: Colors.black, width: 2),
            ),
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 32,
                  semanticLabel: label,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: onPressed != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de texto personalizado para los formularios
/// 
/// Widget reutilizable que proporciona un campo de texto con estilo consistente.
/// Usa un TextEditingController para manejar el texto ingresado.
/// 
/// Características:
/// - Borde gris alrededor
/// - Soporte para diferentes tipos de teclado (números, texto, etc.)
/// - Puede ser multilínea o de una sola línea
/// - Puede habilitarse o deshabilitarse
class FormTextField extends StatelessWidget {
  const FormTextField({
    super.key,
    required this.controller,
    this.labelText,
    this.keyboardType,
    this.maxLines = 1,
    this.enabled = true,
  });

  /// Controlador que maneja el texto del campo
  /// Se usa para leer y escribir el valor del campo
  final TextEditingController controller;
  
  /// Texto de etiqueta que aparece dentro del campo cuando está vacío
  /// También se muestra como hint cuando hay texto
  final String? labelText;
  
  /// Tipo de teclado a mostrar (ej: TextInputType.number para números)
  /// Si no se especifica, usa el teclado de texto por defecto
  final TextInputType? keyboardType;
  
  /// Número máximo de líneas que puede ocupar el campo
  /// Si es 1, es un campo de una línea; si es mayor, permite múltiples líneas
  final int maxLines;
  
  /// Si es true, el campo se puede editar; si es false, está deshabilitado (gris)
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: labelText,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}
