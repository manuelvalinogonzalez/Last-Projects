// ============================================================================
// IMPORTS Y DEPENDENCIAS
// ============================================================================

// Biblioteca principal de Flutter para widgets de Material Design
import 'package:flutter/material.dart';

// ViewModels que gestionan la lógica de negocio y el estado
import '../viewmodels/amigos_view_model.dart';
import '../viewmodels/gastos_view_model.dart';

// Servicio de API para comunicación con el backend
import '../services/api_service.dart';

// Widgets reutilizables para formularios y feedback
import '../widgets/form_dialog.dart';
import '../widgets/feedback_screen.dart';

// ============================================================================
// VARIABLES Y FUNCIONES AUXILIARES GLOBALES
// ============================================================================

/// Variable global para controlar si ya hay un FeedbackScreen de error visible.
/// 
/// Esta variable previene que se apilen múltiples pantallas de error cuando
/// el servidor no está disponible. Sin esto, cada operación fallida intentaría
/// mostrar su propia pantalla de error, creando múltiples overlays.
/// 
/// Uso:
/// - Se establece en true cuando se muestra un error
/// - Se establece en false cuando se cierra el error
/// - Permite que solo haya una pantalla de error visible a la vez
bool _hayErrorVisible = false;

/// Helper para detectar si un error es de servidor no disponible
/// 
/// Esta función analiza el mensaje de error para determinar si es un error
/// de conectividad/servidor (vs. errores de validación u otros tipos).
/// 
/// Es útil para:
/// - Mostrar mensajes específicos de "servidor no disponible"
/// - Evitar mostrar múltiples errores del mismo tipo
/// - Ofrecer acciones específicas (ej: "Reintentar conexión")
/// 
/// Parámetro [mensajeError]: El mensaje de error a analizar
/// Retorna: true si es un error de servidor/conexión, false en caso contrario
bool _esErrorServidorNoDisponible(String? mensajeError) {
  // Si no hay mensaje, no es un error de servidor
  if (mensajeError == null) return false;
  
  // Convertir a minúsculas para comparación case-insensitive
  final error = mensajeError.toLowerCase();
  
  // Verificar si contiene alguna frase clave relacionada con problemas de servidor/conexión
  return error.contains('servidor no está corriendo') ||
      error.contains('no se puede conectar') ||
      error.contains('servidor no disponible') ||
      error.contains('connection refused') ||      // Conexión rechazada
      error.contains('failed host lookup') ||      // No encuentra el servidor (DNS)
      error.contains('network is unreachable');    // Sin conexión de red
}

// ============================================================================
// CLASE PRINCIPAL: MainScreen
// ============================================================================

/// Pantalla principal que coordina la vista de amigos y gastos
/// 
/// Esta es la pantalla raíz de la aplicación que:
/// - Coordina las dos vistas principales: Amigos y Gastos
/// - Adapta su layout según el tamaño de pantalla (tablet vs móvil)
/// - Gestiona los ViewModels que contienen la lógica de negocio
/// 
/// Layout adaptativo:
/// - **Tablet (ancho >= 600px)**: Vista dividida horizontalmente
///   - Gastos a la izquierda
///   - Amigos a la derecha
///   - Ambos visibles simultáneamente
/// 
/// - **Móvil (< 600px)**: Vista con pestañas
///   - Pestaña "Amigos"
///   - Pestaña "Gastos"
///   - Solo una visible a la vez
/// 
/// Implementa StatefulWidget porque necesita mantener estado (los ViewModels)
class MainScreen extends StatefulWidget {
  const MainScreen({super.key, required this.apiService});

  /// Servicio de API que se pasará a los ViewModels
  /// Permite la comunicación con el backend REST
  final ApiService apiService;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// Estado privado de MainScreen que mantiene los ViewModels
/// 
/// Los ViewModels se crean aquí y se pasan a las pantallas hijas (AmigosScreen, GastosScreen)
/// Esto permite que todas las pantallas compartan el mismo estado y se actualicen
/// cuando cambian los datos (patrón MVVM)
class _MainScreenState extends State<MainScreen> {
  /// ViewModel que gestiona la lógica y estado de los amigos
  /// 
  /// 'late final' significa:
  /// - 'late': Se inicializa después de la declaración (en initState)
  /// - 'final': Una vez asignado, no puede cambiar (inmutable)
  late final AmigosViewModel _amigosViewModel;
  
  /// ViewModel que gestiona la lógica y estado de los gastos
  late final GastosViewModel _gastosViewModel;

  /// Método llamado cuando el widget se inserta en el árbol de widgets
  /// 
  /// Aquí se inicializan los ViewModels pasándoles el ApiService.
  /// Los ViewModels se crean una vez y se reutilizan durante toda la vida del widget.
  @override
  void initState() {
    super.initState(); // Siempre llamar primero al método del padre
    
    // Crear los ViewModels con el servicio de API
    _amigosViewModel = AmigosViewModel(widget.apiService);
    _gastosViewModel = GastosViewModel(widget.apiService);
  }

  /// Método llamado cuando el widget se elimina del árbol de widgets
  /// 
  /// Es importante hacer dispose() de los ViewModels para:
  /// - Liberar recursos (cerrar listeners, cancelar operaciones)
  /// - Prevenir memory leaks
  /// - Evitar notificaciones después de que el widget fue destruido
  @override
  void dispose() {
    // Hacer dispose de los ViewModels para liberar recursos
    _amigosViewModel.dispose();
    _gastosViewModel.dispose();
    super.dispose(); // Llamar al dispose del padre al final
  }

  /// Método que construye la interfaz de usuario
  /// 
  /// Este método se llama cada vez que Flutter necesita reconstruir el widget.
  /// Retorna un Widget que representa la estructura visual de la pantalla.
  @override
  Widget build(BuildContext context) {
    // Detectar si es tablet basándose en el tamaño de pantalla
    // shortestSide >= 600px generalmente indica una tablet
    // shortestSide es el lado más corto (ancho en vertical, alto en horizontal)
    final isTablet = MediaQuery.of(context).size.shortestSide >= 600;

    // ========================================================================
    // VISTA ADAPTATIVA: Diferente layout según el tamaño de pantalla
    // ========================================================================
    
    if (isTablet) {
      // ========================================================================
      // LAYOUT PARA TABLET: Vista dividida horizontalmente
      // ========================================================================
      // En tablets hay más espacio, por lo que podemos mostrar ambas vistas
      // lado a lado simultáneamente para mejor usabilidad
      
      return Scaffold(
        // Barra superior con el título de la aplicación
        appBar: AppBar(title: const Text('SplitWithMe')),
        
        // Cuerpo de la pantalla: Row (fila) para dividir horizontalmente
        body: Row(
          children: [
            // ================================================================
            // PANEL IZQUIERDO: Pantalla de Gastos
            // ================================================================
            // Expanded hace que ocupe la mitad del ancho disponible
            Expanded(
              child: GastosScreen(
                viewModel: _gastosViewModel,          // ViewModel de gastos
                amigosViewModel: _amigosViewModel,    // Necesario para validaciones
              ),
            ),
            
            // ================================================================
            // DIVISOR VERTICAL: Línea que separa las dos vistas
            // ================================================================
            const VerticalDivider(
              width: 1, // Ancho de la línea divisoria
            ),
            
            // ================================================================
            // PANEL DERECHO: Pantalla de Amigos
            // ================================================================
            // Expanded hace que ocupe la otra mitad del ancho disponible
            Expanded(
              child: AmigosScreen(
                viewModel: _amigosViewModel,          // ViewModel de amigos
                gastosViewModel: _gastosViewModel,    // Necesario para validaciones
              ),
            ),
          ],
        ),
      );
    }

    // ========================================================================
    // LAYOUT PARA MÓVIL: Vista con pestañas (tabs)
    // ========================================================================
    // En móviles hay menos espacio, por lo que usamos pestañas para alternar
    // entre las dos vistas (una visible a la vez)
    
    // Detectar orientación del dispositivo (vertical u horizontal)
    // Esto permite ajustar el tamaño de la barra de herramientas
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // DefaultTabController gestiona el estado de las pestañas automáticamente
    // length: 2 indica que hay 2 pestañas (Amigos y Gastos)
    return DefaultTabController(
      length: 2, // Número de pestañas
      child: Scaffold(
        // Barra superior (AppBar) con título y pestañas
        appBar: AppBar(
          title: const Text('SplitWithMe'), // Título de la aplicación
          
          // Ajustar altura de la barra según orientación
          // En horizontal hay menos espacio vertical, usar altura mínima
          toolbarHeight: isLandscape ? kToolbarHeight : null,
          
          // Pestañas en la parte inferior del AppBar
          bottom: PreferredSize(
            // Altura preferida de las pestañas según orientación
            preferredSize: Size.fromHeight(isLandscape ? 40 : 48),
            child: const TabBar(
              // Definir las pestañas con íconos y texto
              tabs: [
                Tab(
                  icon: Icon(Icons.people),      // Ícono de personas
                  text: 'Amigos',                // Texto de la pestaña
                ),
                Tab(
                  icon: Icon(Icons.receipt_long), // Ícono de recibo/gasto
                  text: 'Gastos',                 // Texto de la pestaña
                ),
              ],
            ),
          ),
        ),
        
        // Contenido que se muestra según la pestaña activa
        // TabBarView muestra solo el contenido de la pestaña seleccionada
        body: TabBarView(
          children: [
            // Primera pestaña: Pantalla de Amigos
            AmigosScreen(
              viewModel: _amigosViewModel,
              gastosViewModel: _gastosViewModel,
            ),
            // Segunda pestaña: Pantalla de Gastos
            GastosScreen(
              viewModel: _gastosViewModel,
              amigosViewModel: _amigosViewModel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla que muestra y gestiona la lista de amigos
class AmigosScreen extends StatefulWidget {
  const AmigosScreen({
    super.key,
    required this.viewModel,
    required this.gastosViewModel,
  });

  final AmigosViewModel viewModel;
  final GastosViewModel
  gastosViewModel; // Necesario para validar saldos al eliminar

  @override
  State<AmigosScreen> createState() => _AmigosScreenState();
}

/// Estado privado de AmigosScreen que gestiona la interfaz de la lista de amigos
/// 
/// Esta clase maneja:
/// - La visualización de la lista de amigos
/// - Los diálogos para añadir, editar y eliminar amigos
/// - El diálogo para registrar pagos de saldo
/// - La comunicación con los ViewModels mediante listeners
class _AmigosScreenState extends State<AmigosScreen> {
  /// Variable que almacena el último mensaje de error mostrado
  /// 
  /// Se usa para evitar mostrar el mismo error múltiples veces consecutivas.
  /// Cuando el ViewModel notifica cambios y no hay error, se resetea a null.
  /// Esto mejora la UX evitando spam de mensajes de error.
  String? _ultimoMensajeErrorMostrado;

  /// Método llamado cuando el widget se inserta en el árbol de widgets
  /// 
  /// Se ejecuta una sola vez cuando el widget se crea. Aquí se configuran:
  /// - Los listeners para recibir notificaciones de cambios en los ViewModels
  /// - La carga inicial de datos (sin esperar, para no bloquear la UI)
  @override
  void initState() {
    // Siempre llamar primero a super.initState() para inicializar el widget padre
    super.initState();
    
    // Registrar listeners en los ViewModels para recibir notificaciones de cambios
    // Cuando los ViewModels llamen a notifyListeners(), se ejecutará _onViewModelChanged
    widget.viewModel.addListener(_onViewModelChanged);
    widget.gastosViewModel.addListener(_onViewModelChanged);
    
    // Iniciar la carga de datos SIN esperar (fire and forget)
    // Esto permite que la UI se muestre inmediatamente mientras se cargan los datos en segundo plano
    widget.viewModel.inicializar();      // Cargar lista de amigos desde el servidor
    widget.gastosViewModel.inicializar(); // Cargar lista de gastos (necesaria para validar saldos)
  }

  /// Método llamado cuando el widget se elimina del árbol de widgets
  /// 
  /// Es crucial remover los listeners para:
  /// - Evitar memory leaks (los ViewModels no deben mantener referencias a widgets destruidos)
  /// - Prevenir que se ejecuten callbacks en widgets que ya no existen
  /// - Liberar recursos correctamente
  @override
  void dispose() {
    // Remover listeners de los ViewModels para evitar memory leaks
    widget.viewModel.removeListener(_onViewModelChanged);
    widget.gastosViewModel.removeListener(_onViewModelChanged);
    
    // Llamar al dispose del padre al final para liberar recursos del widget base
    super.dispose();
  }

  /// Listener que se ejecuta cuando el ViewModel notifica cambios (patrón Observer)
  /// 
  /// Este método se ejecuta automáticamente cada vez que:
  /// - Un ViewModel llama a notifyListeners() (después de una operación)
  /// - Hay cambios en el estado (datos cargados, errores, etc.)
  /// 
  /// Responsabilidades:
  /// 1. Verificar si el widget aún está montado (para evitar errores)
  /// 2. Detectar y mostrar errores de los ViewModels
  /// 3. Actualizar la UI cuando hay cambios en los datos
  void _onViewModelChanged() {
    // PASO 1: Verificar que el widget aún esté montado en el árbol
    // Si el widget fue destruido, no debemos intentar actualizar la UI
    if (!mounted) return;

    // PASO 2: Obtener los mensajes de error de ambos ViewModels
    // Pueden ser null si no hay errores, o contener un String con el mensaje de error
    final mensajeErrorAmigos = widget.viewModel.mensajeError;
    final mensajeErrorGastos = widget.gastosViewModel.mensajeError;

    // PASO 3: Procesar errores del ViewModel de Amigos (prioridad)
    if (mensajeErrorAmigos != null) {
      // Verificar si es un error de servidor no disponible para mostrar mensaje específico
      final mensaje = _esErrorServidorNoDisponible(mensajeErrorAmigos)
          ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
          : 'Error al cargar datos: $mensajeErrorAmigos';
      // Mostrar el error al usuario
      _mostrarError(mensaje);
    } 
    // PASO 4: Si no hay error en amigos, verificar errores en gastos
    else if (mensajeErrorGastos != null) {
      // Mismo proceso: verificar tipo de error y mostrar mensaje apropiado
      final mensaje = _esErrorServidorNoDisponible(mensajeErrorGastos)
          ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
          : 'Error al cargar datos: $mensajeErrorGastos';
      _mostrarError(mensaje);
    } 
    // PASO 5: Si no hay errores, limpiar el último mensaje mostrado
    else {
      _ultimoMensajeErrorMostrado = null;
    }

    // PASO 6: Programar la actualización de la UI para después del frame actual
    // 
    // ¿Por qué usar addPostFrameCallback?
    // - Evita llamar setState() durante la construcción de widgets (que causaría errores)
    // - Asegura que todos los cambios de estado se procesen antes de reconstruir
    // - Es más seguro que llamar setState() directamente aquí
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Verificar nuevamente que el widget esté montado antes de actualizar
      if (mounted) {
        // setState() sin parámetros fuerza una reconstrucción del widget
        // Esto actualizará la UI con los nuevos datos del ViewModel
        setState(() {});
      }
    });
  }

  void _mostrarError(String mensaje) {
    // Si ya hay un error visible globalmente, no mostrar otro
    if (_hayErrorVisible) return;
    if (_ultimoMensajeErrorMostrado == mensaje) return;

    _ultimoMensajeErrorMostrado = mensaje;
    _hayErrorVisible = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _hayErrorVisible = false;
        return;
      }
      FeedbackScreen.showError(
        context,
        mensaje,
        onReturn: () {
          _ultimoMensajeErrorMostrado = null;
          _hayErrorVisible = false;
        },
      );
    });
  }

  /// Muestra un diálogo modal para añadir un nuevo amigo
  /// 
  /// Este método implementa un patrón "fire and forget" para añadir amigos:
  /// - Muestra un diálogo con un campo de texto para el nombre
  /// - Valida que el nombre no esté vacío
  /// - Envía la petición al servidor sin bloquear la UI
  /// - Muestra feedback (éxito o error) cuando la operación termina
  void _showAddFriendDialog() {
    // PASO 1: Crear un controlador de texto para el campo de entrada
    // TextEditingController permite leer y escribir el valor del campo de texto
    final nombreController = TextEditingController();
    
    // PASO 2: Capturar el contexto del widget padre antes de abrir el diálogo
    // Es importante capturarlo aquí porque el contexto puede cambiar cuando se abre el diálogo
    // Usaremos este contexto para mostrar mensajes de feedback después de cerrar el diálogo
    final parentContext = context;

    // PASO 3: Mostrar el diálogo usando showDialog de Flutter
    showDialog(
      context: context,  // Contexto necesario para mostrar el diálogo
      builder: (dialogContext) => FormDialog(
        // FormDialog es un widget reutilizable que crea un diálogo con formulario
        title: 'Añadir amigo',        // Título del diálogo
        confirmEnabled: true,         // El botón de confirmar estará habilitado
        onConfirm: () {
          // Esta función se ejecuta cuando el usuario presiona el botón "Confirmar"
          
          // PASO 4: Obtener el nombre ingresado y limpiar espacios en blanco
          // trim() elimina espacios al inicio y final del texto
          final nombre = nombreController.text.trim();
          
          // PASO 5: Cerrar el diálogo inmediatamente después de confirmar
          // Esto permite que la UI responda rápidamente sin esperar la respuesta del servidor
          Navigator.of(dialogContext).pop();

          // PASO 6: Validar que el nombre no esté vacío
          if (nombre.isEmpty) {
            // Si está vacío, mostrar error y terminar
            FeedbackScreen.showError(
              parentContext,
              'Por favor, introduce un nombre válido.',
            );
            return;  // Salir de la función sin continuar
          }

          // PASO 7: Añadir el amigo usando el ViewModel (patrón "fire and forget")
          // 
          // "Fire and forget" significa:
          // - Enviamos la petición y NO esperamos con await
          // - La UI sigue siendo interactiva mientras se procesa la petición
          // - Usamos .then() para manejar la respuesta cuando llegue
          widget.viewModel.addAmigo(nombre).then((_) {
            // Esta función se ejecuta cuando la operación termina (éxito o error)
            
            // PASO 8: Verificar que el widget aún esté montado
            // Si el usuario cerró la pantalla mientras se procesaba, no debemos actualizar la UI
            if (!mounted) return;
            
            // PASO 9: Verificar si hubo un error durante la operación
            if (widget.viewModel.mensajeError != null) {
              // Si hay error, determinar el mensaje apropiado según el tipo
              final mensaje =
                  _esErrorServidorNoDisponible(widget.viewModel.mensajeError)
                  ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
                  : 'Error al añadir amigo: ${widget.viewModel.mensajeError}';
              // Mostrar pantalla de error
              FeedbackScreen.showError(parentContext, mensaje);
            } else {
              // Si no hay error, mostrar mensaje de éxito
              FeedbackScreen.showSuccess(
                parentContext,
                'Amigo "$nombre" añadido correctamente',
              );
            }
          });
        },
        // PASO 10: Definir los widgets hijos del diálogo (campos del formulario)
        children: [
          FormTextField(
            controller: nombreController,  // Conectar el controlador al campo
            labelText: 'Nombre',            // Etiqueta del campo
            keyboardType: TextInputType.text, // Tipo de teclado (texto normal)
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo modal para editar el nombre de un amigo existente
  /// 
  /// Este método permite modificar el nombre de un amigo que ya existe en el sistema.
  /// A diferencia de añadir, aquí SÍ esperamos la respuesta del servidor (usamos await)
  /// porque queremos mostrar feedback inmediato antes de que el usuario continúe.
  /// 
  /// Parámetros:
  /// - [id]: El ID único del amigo que se va a editar
  /// - [currentName]: El nombre actual del amigo (se muestra como valor inicial en el campo)
  void _showEditFriendDialog(int id, String currentName) {
    // PASO 1: Crear controlador de texto pre-poblado con el nombre actual
    // Al pasar 'text: currentName' en el constructor, el campo mostrará el nombre actual
    final nombreController = TextEditingController(text: currentName);
    
    // PASO 2: Capturar el contexto del widget padre para usar después de cerrar el diálogo
    final parentContext = context;

    // PASO 3: Mostrar el diálogo de edición
    showDialog(
      context: context,
      builder: (dialogContext) => FormDialog(
        title: 'Editar amigo',        // Título del diálogo
        confirmEnabled: true,         // Botón de confirmar habilitado
        onConfirm: () async {
          // Esta función se ejecuta cuando el usuario confirma la edición
          // Es async porque vamos a esperar la respuesta del servidor
          
          // PASO 4: Obtener el nuevo nombre y limpiar espacios
          final nombre = nombreController.text.trim();
          
          // PASO 5: Cerrar el diálogo inmediatamente
          Navigator.of(dialogContext).pop();

          // PASO 6: Validar que el nombre no esté vacío
          if (nombre.isEmpty) {
            // Verificar que el widget aún esté montado antes de mostrar error
            if (!mounted) return;
            FeedbackScreen.showError(
              parentContext,
              'Por favor, introduce un nombre válido.',
            );
            return;  // Salir si la validación falla
          }

          // PASO 7: Actualizar el amigo en el servidor y ESPERAR la respuesta
          // Usamos await aquí (a diferencia de añadir) porque queremos mostrar
          // feedback inmediato antes de continuar
          await widget.viewModel.updateAmigo(id, nombre);

          // PASO 8: Verificar que el widget aún esté montado después de la operación
          if (!mounted) return;

          // PASO 9: Verificar si hubo un error
          if (widget.viewModel.mensajeError != null) {
            // Determinar mensaje según el tipo de error
            final mensaje =
                _esErrorServidorNoDisponible(widget.viewModel.mensajeError)
                ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
                : 'Error al editar amigo: ${widget.viewModel.mensajeError}';
            FeedbackScreen.showError(parentContext, mensaje);
          } else {
            // Si no hay error, mostrar mensaje de éxito
            FeedbackScreen.showSuccess(
              parentContext,
              'Amigo actualizado correctamente',
            );
          }
        },
        // PASO 10: Definir los campos del formulario
        children: [
          FormTextField(
            controller: nombreController,  // Campo pre-poblado con el nombre actual
            labelText: 'Nombre',
            keyboardType: TextInputType.text,
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo de confirmación para eliminar un amigo
  /// 
  /// Este método implementa una validación importante: solo permite eliminar
  /// un amigo si su saldo es cero (o muy cercano a cero, considerando errores
  /// de precisión de punto flotante).
  /// 
  /// Validaciones realizadas:
  /// - El saldo debe estar dentro del rango [-0.001, 0.001] para considerarse cero
  /// - Si hay saldo positivo, significa que el amigo debe recibir dinero
  /// - Si hay saldo negativo, significa que el amigo debe pagar dinero
  /// - En ambos casos, se previene la eliminación para mantener la integridad de los datos
  /// 
  /// Parámetros:
  /// - [id]: El ID único del amigo que se quiere eliminar
  /// - [nombre]: El nombre del amigo (se muestra en el diálogo y en mensajes de error)
  void _showDeleteFriendDialog(int id, String nombre) {
    // PASO 1: Capturar el contexto del widget padre
    final parentContext = context;

    // PASO 2: Mostrar el diálogo de confirmación
    showDialog(
      context: context,
      builder: (dialogContext) => FormDialog(
        title: 'Eliminar amigo',
        confirmEnabled: true,
        onConfirm: () async {
          // Esta función se ejecuta cuando el usuario confirma la eliminación
          // Es async porque debemos validar el saldo antes de eliminar
          
          // PASO 3: Cargar los gastos más recientes para calcular el saldo actualizado
          // IMPORTANTE: Esperamos aquí porque necesitamos el saldo actualizado antes de validar
          // Si no esperamos, podríamos validar con datos obsoletos
          await widget.gastosViewModel.cargarGastos();
          
          // PASO 4: Buscar el amigo en la lista actual
          // firstWhere() busca el primer elemento que cumple la condición
          final amigo = widget.viewModel.amigos.firstWhere(
            (element) => element.id == id,  // Condición: el ID coincide
          );
          
          // PASO 5: Obtener el saldo del amigo
          // El saldo se calcula como: creditBalance - debitBalance
          final saldo = amigo.saldo;
          
          // PASO 6: Verificar si el saldo está fuera del rango "casi cero"
          // 
          // ¿Por qué usar 0.001 en lugar de 0?
          // - Los números de punto flotante tienen errores de precisión
          // - Un saldo calculado podría ser 0.0000001 en lugar de exactamente 0
          // - Usamos un umbral pequeño (0.001) para considerar "prácticamente cero"
          final saldoPositivo = saldo > 0.001;  // Tiene saldo a favor (debe recibir dinero)
          final saldoNegativo = saldo < -0.001; // Tiene saldo negativo (debe pagar dinero)
          
          // PASO 7: Si hay saldo (positivo o negativo), prevenir la eliminación
          if (saldoPositivo || saldoNegativo) {
            // Cerrar el diálogo
            Navigator.of(dialogContext).pop();
            
            // Determinar el motivo del rechazo
            final motivo = saldoPositivo
                ? 'tiene un saldo a favor (${saldo.toStringAsFixed(2)} €)'  // Debe recibir dinero
                : 'su saldo es negativo (${saldo.toStringAsFixed(2)} €)';   // Debe pagar dinero
            
            // Mostrar error explicando por qué no se puede eliminar
            FeedbackScreen.showError(
              parentContext,
              'No se puede eliminar a $nombre porque $motivo. Liquida los saldos antes de eliminarlo.',
            );
            return;  // Salir sin eliminar
          }
          
          // PASO 8: Si el saldo está cerca de cero, proceder con la eliminación
          Navigator.of(dialogContext).pop();

          // PASO 9: Eliminar el amigo usando el ViewModel (patrón "fire and forget")
          // No bloqueamos la UI mientras se procesa la eliminación
          widget.viewModel.eliminarAmigo(id).then((_) {
            // Esta función se ejecuta cuando la eliminación termina
            
            // PASO 10: Verificar que el widget aún esté montado
            if (!mounted) return;
            
            // PASO 11: Verificar si hubo un error
            if (widget.viewModel.mensajeError != null) {
              // Determinar mensaje según el tipo de error
              final mensaje =
                  _esErrorServidorNoDisponible(widget.viewModel.mensajeError)
                  ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
                  : 'Error al eliminar amigo: ${widget.viewModel.mensajeError}';
              FeedbackScreen.showError(parentContext, mensaje);
            } else {
              // Si no hay error, mostrar mensaje de éxito
              FeedbackScreen.showSuccess(
                parentContext,
                'Amigo "$nombre" eliminado correctamente',
              );
            }
          });
        },
        // PASO 12: Definir los campos del formulario
        children: [
          FormTextField(
            controller: TextEditingController(text: nombre), // Campo con el nombre (solo lectura)
            labelText: 'Nombre',
            enabled: false,  // Deshabilitado para que el usuario no pueda modificarlo
          ),
        ],
      ),
    );
  }

  /// Muestra un diálogo para registrar un pago parcial del saldo de un amigo
  /// 
  /// Este método permite que un usuario registre un pago parcial cuando un amigo
  /// tiene un saldo negativo (debe dinero). Solo se pueden pagar deudas, no saldos positivos.
  /// 
  /// Características:
  /// - Filtra solo amigos con deudas (saldo negativo)
  /// - Permite seleccionar qué amigo pagará
  /// - Valida que el monto no exceda la deuda
  /// - Actualiza los saldos después del pago
  void _showPagarSaldoDialog() {
    // PASO 1: Obtener la lista actual de amigos del ViewModel
    final amigos = widget.viewModel.amigos;

    // PASO 2: Filtrar solo los amigos que tienen deuda (saldo negativo)
    // 
    // ¿Por qué filtrar?
    // - Solo queremos mostrar amigos que deben dinero
    // - No tiene sentido permitir pagos a quienes ya tienen saldo positivo o cero
    // 
    // ¿Por qué usar -0.001?
    // - Los números de punto flotante pueden tener errores de precisión
    // - Un saldo calculado podría ser -0.0000001 en lugar de exactamente 0
    // - Usamos un umbral pequeño para considerar "realmente negativo"
    final amigosConDeuda = amigos.where((a) => a.saldo < -0.001).toList();

    // PASO 3: Validar que haya al menos un amigo con deuda
    if (amigosConDeuda.isEmpty) {
      // Si no hay deudas, mostrar error y salir
      FeedbackScreen.showError(context, 'No hay amigos con deudas que pagar.');
      return;
    }

    // PASO 4: Crear controlador para el campo de monto a pagar
    final montoController = TextEditingController();
    
    // PASO 5: Seleccionar el primer amigo con deuda por defecto
    // El usuario podrá cambiar esta selección en el dropdown
    int? amigoSeleccionadoId = amigosConDeuda.first.id;
    
    // PASO 6: Capturar el contexto del widget padre
    final parentContext = context;

    // PASO 7: Mostrar el diálogo de pago de saldo
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        // StatefulBuilder permite actualizar el estado del diálogo sin reconstruir
        // el widget padre. Esto es necesario porque cuando el usuario cambia el
        // amigo seleccionado en el dropdown, necesitamos actualizar la deuda mostrada
        // sin cerrar y reabrir el diálogo.
        //
        // Parámetros del builder:
        // - context: El contexto del diálogo
        // - setDialogState: Función para actualizar el estado del diálogo
        builder: (context, setDialogState) {
          // PASO 8: Buscar el amigo seleccionado en la lista de deudores
          // firstWhere busca el primer elemento que cumple la condición
          // orElse se usa como fallback si no se encuentra (no debería pasar)
          final amigoSeleccionado = amigosConDeuda.firstWhere(
            (a) => a.id == amigoSeleccionadoId,  // Buscar por ID
            orElse: () => amigosConDeuda.first,  // Si no se encuentra, usar el primero
          );
          
          // PASO 9: Calcular la deuda actual del amigo seleccionado
          // El saldo es negativo cuando el amigo debe dinero, por lo que multiplicamos
          // por -1 para convertirlo en un valor positivo (la deuda que debe pagar)
          final deudaActual = -amigoSeleccionado.saldo;

          // PASO 10: Crear el formulario del diálogo
          return FormDialog(
            title: 'Pagar saldo',
            confirmEnabled: true,
            onConfirm: () async {
              // Esta función se ejecuta cuando el usuario presiona "Confirmar"
              
              // PASO 11: Obtener el monto ingresado por el usuario
              final montoText = montoController.text.trim();

              // PASO 12: Validar que el campo no esté vacío
              if (montoText.isEmpty) {
                FeedbackScreen.showError(
                  context,
                  'Por favor, introduce un importe.',
                );
                return;  // Salir si la validación falla
              }

              // PASO 13: Convertir el texto a número y validar formato
              // tryParse() retorna null si el texto no es un número válido
              final monto = double.tryParse(montoText);
              if (monto == null || monto <= 0) {
                // Validar que sea un número válido y mayor a cero
                FeedbackScreen.showError(
                  context,
                  'Por favor, introduce un importe válido mayor a 0.',
                );
                return;
              }

              // PASO 14: Validar que el monto no exceda la deuda
              // No se puede pagar más de lo que se debe
              if (monto > deudaActual) {
                FeedbackScreen.showError(
                  context,
                  'El importe no puede ser mayor a la deuda (${deudaActual.toStringAsFixed(2)} €).',
                );
                return;
              }

              // PASO 15: Cerrar el diálogo antes de procesar el pago
              Navigator.of(context).pop();

              // PASO 16: Procesar el pago en el servidor
              // Usamos await porque necesitamos esperar la respuesta antes de continuar
              await widget.viewModel.pagarSaldo(amigoSeleccionado, monto);

              // PASO 17: Verificar que el widget aún esté montado
              if (!mounted) return;

              // PASO 18: Verificar si hubo un error durante el pago
              if (widget.viewModel.mensajeError != null) {
                // Determinar el mensaje de error apropiado
                final mensaje =
                    _esErrorServidorNoDisponible(widget.viewModel.mensajeError)
                    ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
                    : 'Error al pagar saldo: ${widget.viewModel.mensajeError}';
                FeedbackScreen.showError(parentContext, mensaje);
              } else {
                // PASO 19: Si no hay error, recargar los datos
                // 
                // IMPORTANTE: Recargamos amigos Y gastos en PARALELO usando Future.wait()
                // 
                // ¿Por qué en paralelo?
                // - Ambas operaciones son independientes entre sí
                // - Hace la carga más rápida (no esperamos una tras otra)
                // - Mejora la experiencia de usuario
                //
                // ¿Por qué recargar después del pago?
                // - El pago modifica los saldos de los amigos
                // - Los gastos pueden afectar los saldos
                // - Queremos mostrar los datos actualizados al usuario
                await Future.wait([
                  widget.viewModel.cargarAmigos(),      // Actualizar lista de amigos y saldos
                  widget.gastosViewModel.cargarGastos(), // Actualizar lista de gastos
                ]);

                // PASO 20: Mostrar mensaje de éxito
                FeedbackScreen.showSuccess(
                  parentContext,
                  'Saldo pagado correctamente',
                );
              }
            },
            // PASO 21: Definir los widgets hijos del formulario
            children: [
              // Título de la sección de selección de amigo
              Text(
                'Selecciona el amigo:',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              
              // Espacio vertical entre el título y el dropdown
              const SizedBox(height: 8),
              
              // Dropdown para seleccionar qué amigo pagará
              DropdownButtonFormField<int>(
                initialValue: amigoSeleccionadoId,  // Valor inicial seleccionado
                isExpanded: true,                    // Expande el dropdown para usar todo el ancho disponible
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),      // Borde alrededor del campo
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,  // Padding horizontal interno
                    vertical: 8,     // Padding vertical interno
                  ),
                ),
                // Generar las opciones del dropdown mapeando la lista de deudores
                items: amigosConDeuda.map((amigo) {
                  return DropdownMenuItem<int>(
                    value: amigo.id,  // Valor que se guardará cuando se seleccione esta opción
                    child: Text(
                      // Mostrar el nombre del amigo y su deuda entre paréntesis
                      '${amigo.nombre} (debe ${(-amigo.saldo).toStringAsFixed(2)} €)',
                      overflow: TextOverflow.ellipsis,  // Si el texto es muy largo, mostrar "..."
                    ),
                  );
                }).toList(),  // Convertir el iterable a una lista
                onChanged: (value) {
                  // Esta función se ejecuta cuando el usuario cambia la selección
                  // setDialogState permite actualizar el estado del diálogo sin reconstruir el padre
                  setDialogState(() {
                    amigoSeleccionadoId = value;  // Actualizar el amigo seleccionado
                    // Esto causará que el builder se ejecute nuevamente, actualizando
                    // la deuda mostrada según el nuevo amigo seleccionado
                  });
                },
              ),
              
              // Espacio vertical antes de mostrar la deuda
              const SizedBox(height: 16),
              
              // Texto que muestra la deuda actual del amigo seleccionado
              Text(
                'Deuda actual: ${deudaActual.toStringAsFixed(2)} €',
                // Aplicar estilo visual: negrita y color rojo para destacar
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,  // Texto en negrita
                  color: Colors.red,            // Color rojo para indicar deuda
                ),
              ),
              
              // Espacio vertical antes del campo de monto
              const SizedBox(height: 12),
              
              // Campo de texto para ingresar el monto a pagar
              FormTextField(
                controller: montoController,  // Controlador conectado al campo
                labelText: 'Importe a pagar (€)',  // Etiqueta del campo
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,  // Permitir números decimales (para céntimos)
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Método que construye la interfaz de usuario de la pantalla de amigos
  /// 
  /// Este método crea una columna vertical con:
  /// - Un indicador de progreso si hay una operación en curso
  /// - Una barra de herramientas con botones de acción
  /// - Una lista scrollable de amigos o un estado vacío
  @override
  Widget build(BuildContext context) {
    // PASO 1: Obtener la lista de amigos actualizada del ViewModel
    final amigos = widget.viewModel.amigos;
    
    // PASO 2: Detectar la orientación del dispositivo
    // Esto permite ajustar el layout según si el dispositivo está en horizontal o vertical
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // PASO 3: Construir la estructura de la pantalla usando una Columna
    return Column(
      children: [
        // PASO 4: Mostrar indicador de progreso si hay una operación en curso
        // if (condición) widget - esto es un condicional inline en Dart
        // Solo se muestra el LinearProgressIndicator si viewModel.cargando es true
        if (widget.viewModel.cargando) const LinearProgressIndicator(),
        
        // PASO 5: Barra de herramientas con padding adaptativo
        Padding(
          // Padding adaptativo según orientación:
          // - 8px en horizontal (menos espacio vertical disponible)
          // - 16px en vertical (más espacio vertical disponible)
          padding: EdgeInsets.all(isLandscape ? 8 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,  // Los hijos se estiran horizontalmente
            children: [
              // Fila con título y botones de acción
              Row(
                children: [
                  // Título de la sección que ocupa el espacio disponible
                  Expanded(
                    child: Text(
                      'Lista de amigos',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  
                  // Botón para pagar saldo
                  FilledButton.icon(
                    key: const Key('pagar_saldo_button'),  // Key para testing
                    // Deshabilitar el botón si hay una operación en curso
                    onPressed: widget.viewModel.cargando
                        ? null  // null deshabilita el botón
                        : _showPagarSaldoDialog,  // Callback cuando se presiona
                    icon: const Icon(Icons.payment),  // Ícono del botón
                    label: const Text('Pagar saldo'), // Texto del botón
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.orange,  // Color naranja para destacar
                    ),
                  ),
                  
                  // Espacio horizontal entre botones
                  const SizedBox(width: 8),
                  
                  // Botón para añadir un nuevo amigo
                  FilledButton.icon(
                    key: const Key('add_amigo_button'),  // Key para testing
                    onPressed: widget.viewModel.cargando
                        ? null
                        : _showAddFriendDialog,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Añadir amigo'),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // PASO 6: Área de contenido principal (lista o estado vacío)
        // Expanded hace que este widget ocupe todo el espacio vertical restante
        Expanded(
          child: amigos.isEmpty
              // Si no hay amigos, mostrar estado vacío
              ? const _EmptyState(
                  icon: Icons.people_outline,
                  message: 'Aún no tienes amigos registrados.',
                )
              // Si hay amigos, mostrar la lista
              : ListView.separated(
                  // Padding horizontal adaptativo según orientación
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8 : 16,
                  ),
                  // Función que construye cada item de la lista
                  itemBuilder: (context, index) {
                    // PASO 7: Obtener el amigo en la posición actual
                    final amigo = amigos[index];
                    
                    // PASO 8: Verificar si este amigo está siendo eliminado actualmente
                    // esto permite mostrar un indicador de carga en lugar de los botones
                    final estaEliminando = widget.viewModel.estaOperandoEn(
                      'delete_${amigo.id}',  // Identificador único de la operación
                    );

                    // PASO 9: Construir el widget que representa cada amigo en la lista
                    return ListTile(
                      // Avatar circular con la primera letra del nombre
                      leading: CircleAvatar(
                        child: Text(
                          // Obtener la primera letra del nombre en mayúscula
                          // Si el nombre está vacío, mostrar '?' como fallback
                          amigo.nombre.isNotEmpty
                              ? amigo.nombre.substring(0, 1).toUpperCase()
                              : '?',
                        ),
                      ),
                      // Nombre del amigo como título
                      title: Text(amigo.nombre),
                      // Saldo del amigo como subtítulo
                      subtitle: Text(
                        'Saldo: ${amigo.saldo.toStringAsFixed(2)} €',
                      ),
                      // Widgets en el lado derecho (trailing)
                      trailing: estaEliminando
                          // Si está eliminando, mostrar indicador de progreso
                          ? Row(
                              mainAxisSize: MainAxisSize.min,  // Ocupar solo el espacio necesario
                              children: const [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,  // Grosor de la línea del indicador
                                  ),
                                ),
                                SizedBox(width: 12),  // Espacio entre indicador y texto
                                Text('Eliminando...'),
                              ],
                            )
                          // Si no está eliminando, mostrar botones de acción
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Botón para editar amigo
                                IconButton(
                                  key: Key('edit_amigo_button_${amigo.id}'),  // Key único para testing
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: widget.viewModel.cargando
                                      ? null  // Deshabilitar si hay operación en curso
                                      : () => _showEditFriendDialog(
                                          amigo.id,
                                          amigo.nombre,
                                        ),
                                  tooltip: 'Editar amigo',  // Texto de ayuda al hacer hover
                                ),
                                // Botón para eliminar amigo
                                IconButton(
                                  key: Key('delete_amigo_button_${amigo.id}'),
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: widget.viewModel.cargando
                                      ? null
                                      : () => _showDeleteFriendDialog(
                                          amigo.id,
                                          amigo.nombre,
                                        ),
                                  tooltip: 'Eliminar amigo',
                                ),
                              ],
                            ),
                    );
                  },
                  // Función que construye el separador entre items
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  // Número total de items en la lista
                  itemCount: amigos.length,
                ),
        ),
      ],
    );
  }
}

/// Pantalla que muestra y gestiona la lista de gastos compartidos
class GastosScreen extends StatefulWidget {
  const GastosScreen({
    super.key,
    required this.viewModel,
    required this.amigosViewModel,
  });

  final GastosViewModel viewModel;
  final AmigosViewModel
  amigosViewModel; // Necesario para obtener lista de amigos al crear/editar gastos

  @override
  State<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends State<GastosScreen> {
  /// Evita mostrar el mismo error múltiples veces
  String? _ultimoMensajeErrorMostrado;

  @override
  void initState() {
    super.initState();
    widget.viewModel.addListener(_onViewModelChanged);
    // Iniciar carga sin esperar
    widget.viewModel.inicializar();
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  /// Listener que se ejecuta cuando el ViewModel notifica cambios (patrón Observer)
  void _onViewModelChanged() {
    if (!mounted) return;

    final mensajeError = widget.viewModel.mensajeError;
    if (mensajeError != null) {
      final mensaje = _esErrorServidorNoDisponible(mensajeError)
          ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
          : 'Error al cargar datos: $mensajeError';
      _mostrarError(mensaje);
    } else {
      _ultimoMensajeErrorMostrado = null;
    }

    // Programar setState para después del frame actual para evitar errores
    // durante la construcción inicial de widgets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _mostrarError(String mensaje) {
    // Si ya hay un error visible globalmente, no mostrar otro
    if (_hayErrorVisible) return;
    if (_ultimoMensajeErrorMostrado == mensaje) return;

    _ultimoMensajeErrorMostrado = mensaje;
    _hayErrorVisible = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _hayErrorVisible = false;
        return;
      }
      FeedbackScreen.showError(
        context,
        mensaje,
        onReturn: () {
          _ultimoMensajeErrorMostrado = null;
          _hayErrorVisible = false;
        },
      );
    });
  }

  void _showAddExpenseDialog() {
    final amigos = widget.amigosViewModel.amigos;

    if (amigos.isEmpty) {
      FeedbackScreen.showError(
        context,
        'Necesitas al menos un amigo registrado para añadir un gasto.',
      );
      return;
    }

    final descripcionController = TextEditingController();
    final montoController = TextEditingController();
    int? pagadorId = amigos.first.id;
    final Set<int> deudoresIds = {amigos.first.id};
    final parentContext = context; // Capturar contexto del widget padre

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => FormDialog(
          title: 'Añadir gasto',
          confirmEnabled: true,
          onConfirm: () async {
            final descripcion = descripcionController.text.trim();
            final montoText = montoController.text.trim();

            if (descripcion.isEmpty) {
              FeedbackScreen.showError(
                context,
                'Por favor, introduce una descripción.',
              );
              return;
            }

            final monto = double.tryParse(montoText);
            if (monto == null || monto <= 0) {
              FeedbackScreen.showError(
                context,
                'Por favor, introduce un monto válido.',
              );
              return;
            }

            if (pagadorId == null) {
              FeedbackScreen.showError(
                context,
                'Por favor, selecciona quién pagó.',
              );
              return;
            }

            Navigator.of(context).pop();

            await widget.viewModel.addGasto(
              descripcion: descripcion,
              monto: monto,
              pagadorId: pagadorId!,
              deudoresIds: deudoresIds.toList(),
              onSyncComplete: widget.amigosViewModel.cargarAmigos,
            );

            if (!mounted) return;

            if (widget.viewModel.mensajeError != null) {
              final mensaje =
                  _esErrorServidorNoDisponible(widget.viewModel.mensajeError)
                  ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
                  : 'Error al añadir gasto: ${widget.viewModel.mensajeError}';
              FeedbackScreen.showError(parentContext, mensaje);
            } else {
              FeedbackScreen.showSuccess(
                parentContext,
                'Gasto añadido correctamente',
              );
              // Recargar amigos para actualizar los saldos
              await widget.amigosViewModel.cargarAmigos();
            }
          },
          children: [
            FormTextField(
              controller: descripcionController,
              labelText: 'Descripción',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            FormTextField(
              controller: montoController,
              labelText: 'Monto (€)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            Text('¿Quién pagó?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: pagadorId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: amigos.map((amigo) {
                return DropdownMenuItem<int>(
                  value: amigo.id,
                  child: Text(amigo.nombre),
                );
              }).toList(),
              onChanged: (value) {
                setDialogState(() {
                  pagadorId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              '¿Quiénes deben?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...amigos.map((amigo) {
              return CheckboxListTile(
                title: Text(amigo.nombre),
                value: deudoresIds.contains(amigo.id),
                onChanged: (bool? value) {
                  setDialogState(() {
                    if (value == true) {
                      deudoresIds.add(amigo.id);
                    } else {
                      deudoresIds.remove(amigo.id);
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Muestra diálogo para editar un gasto existente
  void _showEditExpenseDialog(
    int id,
    String descripcion,
    double monto,
    int currentPagadorId,
    List<int> currentDeudoresIds,
  ) {
    final amigos = widget.amigosViewModel.amigos;

    if (amigos.isEmpty) {
      FeedbackScreen.showError(
        context,
        'Necesitas al menos un amigo registrado para editar un gasto.',
      );
      return;
    }

    final descripcionController = TextEditingController(text: descripcion);
    final montoController = TextEditingController(
      text: monto.toStringAsFixed(2),
    );
    int? pagadorId = currentPagadorId;
    final Set<int> deudoresIds = Set<int>.from(currentDeudoresIds);
    final idsAmigos = amigos.map((amigo) => amigo.id).toSet();

    if (!idsAmigos.contains(pagadorId)) {
      pagadorId = idsAmigos.isNotEmpty ? idsAmigos.first : null;
    }

    deudoresIds.removeWhere((id) => !idsAmigos.contains(id));

    if (deudoresIds.isEmpty && pagadorId != null) {
      deudoresIds.add(pagadorId);
    }

    if (pagadorId == null) {
      FeedbackScreen.showError(
        context,
        'No quedan participantes válidos para editar este gasto.',
      );
      return;
    }

    final parentContext = context; // Capturar contexto del widget padre

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => FormDialog(
          title: 'Editar gasto',
          confirmEnabled: true,
          onConfirm: () async {
            final descripcion = descripcionController.text.trim();
            final montoText = montoController.text.trim();

            if (descripcion.isEmpty) {
              FeedbackScreen.showError(
                context,
                'Por favor, introduce una descripción.',
              );
              return;
            }

            final monto = double.tryParse(montoText);
            if (monto == null || monto <= 0) {
              FeedbackScreen.showError(
                context,
                'Por favor, introduce un monto válido.',
              );
              return;
            }

            if (pagadorId == null) {
              FeedbackScreen.showError(
                context,
                'Por favor, selecciona quién pagó.',
              );
              return;
            }

            Navigator.of(context).pop();

            await widget.viewModel.updateGasto(
              id: id,
              descripcion: descripcion,
              monto: monto,
              pagadorId: pagadorId!,
              deudoresIds: deudoresIds.toList(),
              onSyncComplete: widget.amigosViewModel.cargarAmigos,
            );

            if (!mounted) return;

            if (widget.viewModel.mensajeError != null) {
              final mensaje =
                  _esErrorServidorNoDisponible(widget.viewModel.mensajeError)
                  ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
                  : 'Error al editar gasto: ${widget.viewModel.mensajeError}';
              FeedbackScreen.showError(parentContext, mensaje);
            } else {
              FeedbackScreen.showSuccess(
                parentContext,
                'Gasto actualizado correctamente',
              );
              // Recargar amigos para actualizar los saldos después de modificar gastos
              await widget.amigosViewModel.cargarAmigos();
            }
          },
          children: [
            FormTextField(
              controller: descripcionController,
              labelText: 'Descripción',
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            FormTextField(
              controller: montoController,
              labelText: 'Monto (€)',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 16),
            Text('¿Quién pagó?', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: pagadorId,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: amigos.map((amigo) {
                return DropdownMenuItem<int>(
                  value: amigo.id,
                  child: Text(amigo.nombre),
                );
              }).toList(),
              onChanged: (value) {
                setDialogState(() {
                  pagadorId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            Text(
              '¿Quiénes deben?',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...amigos.map((amigo) {
              return CheckboxListTile(
                title: Text(amigo.nombre),
                value: deudoresIds.contains(amigo.id),
                onChanged: (bool? value) {
                  setDialogState(() {
                    if (value == true) {
                      deudoresIds.add(amigo.id);
                    } else {
                      deudoresIds.remove(amigo.id);
                    }
                  });
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Muestra diálogo de confirmación para eliminar un gasto
  void _showDeleteExpenseDialog(int id, String descripcion) {
    final descripcionController = TextEditingController(text: descripcion);
    final parentContext = context; // Capturar contexto del widget padre

    showDialog(
      context: context,
      builder: (dialogContext) => FormDialog(
        title: 'Eliminar gasto',
        confirmEnabled: true,
        onConfirm: () async {
          Navigator.of(dialogContext).pop();

          await widget.viewModel.eliminarGasto(
            id,
            onSyncComplete: widget.amigosViewModel.cargarAmigos,
          );

          if (!mounted) return;

          if (widget.viewModel.mensajeError != null) {
            final mensaje =
                _esErrorServidorNoDisponible(widget.viewModel.mensajeError)
                ? 'El servidor no está corriendo. Por favor, inicia el servidor e intenta nuevamente.'
                : 'Error al eliminar gasto: ${widget.viewModel.mensajeError}';
            FeedbackScreen.showError(parentContext, mensaje);
          } else {
            FeedbackScreen.showSuccess(
              parentContext,
              'Gasto eliminado correctamente',
            );
            // Recargar amigos para actualizar los saldos después de modificar gastos
            await widget.amigosViewModel.cargarAmigos();
          }
        },
        children: [
          FormTextField(
            controller: descripcionController,
            labelText: 'Descripción',
            enabled: false,
          ),
          const SizedBox(height: 8),
          const Text(
            '¿Estás seguro de que quieres eliminar este gasto?',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gastos = widget.viewModel.gastos;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      children: [
        if (widget.viewModel.cargando) const LinearProgressIndicator(),
        Padding(
          padding: EdgeInsets.all(isLandscape ? 8 : 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Gastos registrados',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                key: const Key('add_gasto_button'),
                onPressed: widget.viewModel.cargando
                    ? null
                    : _showAddExpenseDialog,
                icon: const Icon(Icons.add),
                label: const Text('Añadir gasto'),
              ),
            ],
          ),
        ),
        Expanded(
          child: gastos.isEmpty
              ? const _EmptyState(
                  icon: Icons.receipt_long_outlined,
                  message: 'Todavía no hay gastos registrados.',
                )
              : ListView.separated(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 8 : 16,
                  ),
                  itemBuilder: (context, index) {
                    final gasto = gastos[index];
                    final amigos = widget.amigosViewModel.amigos;
                    String pagadorNombre = 'Desconocido';
                    try {
                      final pagador = amigos.firstWhere(
                        (a) => a.id == gasto.pagadorId,
                      );
                      pagadorNombre = pagador.nombre;
                    } catch (_) {
                      // Si no se encuentra el pagador, usar el valor por defecto
                    }

                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.receipt)),
                      title: Text(gasto.descripcion),
                      subtitle: Text(
                        'Monto: ${gasto.monto.toStringAsFixed(2)} € - Pagó: $pagadorNombre',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            key: Key('edit_gasto_button_${gasto.id}'),
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: widget.viewModel.cargando
                                ? null
                                : () => _showEditExpenseDialog(
                                    gasto.id,
                                    gasto.descripcion,
                                    gasto.monto,
                                    gasto.pagadorId,
                                    gasto.deudoresIds,
                                  ),
                            tooltip: 'Editar gasto',
                          ),
                          IconButton(
                            key: Key('delete_gasto_button_${gasto.id}'),
                            icon: const Icon(Icons.delete_outline),
                            onPressed: widget.viewModel.cargando
                                ? null
                                : () => _showDeleteExpenseDialog(
                                    gasto.id,
                                    gasto.descripcion,
                                  ),
                            tooltip: 'Eliminar gasto',
                          ),
                        ],
                      ),
                    );
                  },
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1), // Línea divisoria entre items
                  itemCount: gastos.length,
                ),
        ),
      ],
    );
  }
}

/// Widget privado reutilizable que muestra un estado vacío cuando no hay datos
/// 
/// Este widget se usa tanto en AmigosScreen como en GastosScreen cuando las
/// listas están vacías. Proporciona una experiencia de usuario consistente
/// mostrando un ícono y un mensaje explicativo.
/// 
/// Características:
/// - Es un StatelessWidget porque no necesita mantener estado
/// - Es privado (prefijo _) porque solo se usa dentro de este archivo
/// - Es completamente reutilizable mediante parámetros
/// 
/// Parámetros:
/// - [icon]: El ícono a mostrar (ej: Icons.people_outline para amigos vacíos)
/// - [message]: El mensaje explicativo a mostrar al usuario
class _EmptyState extends StatelessWidget {
  /// Constructor constante que requiere icon y message
  const _EmptyState({required this.icon, required this.message});

  /// Ícono a mostrar en el estado vacío
  final IconData icon;
  
  /// Mensaje de texto a mostrar debajo del ícono
  final String message;

  /// Método que construye la interfaz del estado vacío
  @override
  Widget build(BuildContext context) {
    // Centrar el contenido vertical y horizontalmente
    return Center(
      child: Column(
        // mainAxisSize.min hace que la columna solo ocupe el espacio necesario
        // en lugar de expandirse para llenar todo el espacio disponible
        mainAxisSize: MainAxisSize.min,
        children: [
          // Ícono grande y centrado
          // Usa el color secundario del tema para consistencia visual
          Icon(
            icon, 
            size: 48,  // Tamaño del ícono en píxeles
            color: Theme.of(context).colorScheme.secondary,  // Color del tema
          ),
          
          // Espacio vertical entre el ícono y el texto
          const SizedBox(height: 12),
          
          // Mensaje de texto explicativo
          Text(
            message,
            textAlign: TextAlign.center,  // Centrar el texto
            style: Theme.of(context).textTheme.bodyMedium,  // Estilo del tema
          ),
        ],
      ),
    );
  }
}
