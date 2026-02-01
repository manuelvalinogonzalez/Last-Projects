import 'package:flutter/material.dart';

import '../models/amigo.dart';
import '../services/api_service.dart';

/// ViewModel que gestiona el estado y la lógica de negocio de los amigos
/// 
/// Este ViewModel implementa el patrón MVVM (Model-View-ViewModel):
/// - **Model**: La clase Amigo representa los datos
/// - **View**: Las pantallas de la UI (AmigosScreen)
/// - **ViewModel**: Esta clase gestiona la lógica y el estado
/// 
/// Usa ChangeNotifier para notificar cambios a la UI cuando el estado cambia
/// La UI escucha estos cambios mediante un ChangeNotifierProvider o similar
class AmigosViewModel extends ChangeNotifier {
  /// Constructor que recibe el servicio de API necesario para comunicarse con el backend
  AmigosViewModel(this._apiService);

  /// Servicio que maneja todas las operaciones HTTP con la API REST
  final ApiService _apiService;

  /// Lista privada de amigos (estado interno del ViewModel)
  /// Solo se expone mediante el getter 'amigos' que retorna una lista inmutable
  final List<Amigo> _amigos = [];
  
  /// Indica si se está cargando información desde el servidor
  bool _cargando = false;
  
  /// Mensaje de error si alguna operación falló (null si no hay error)
  String? _mensajeError;
  
  /// Flag para prevenir notificaciones después de que el ViewModel fue destruido
  /// Esto evita errores si se intenta notificar después de dispose()
  bool _disposed = false;

  /// Rastrea las operaciones en progreso para mostrar indicadores de carga específicos
  /// 
  /// Cada operación tiene un ID único (ej: 'add_1234567890', 'delete_5')
  /// Esto permite mostrar indicadores de carga diferentes para diferentes operaciones
  final Set<String> _operacionesEnProgreso = {};

  /// Getter que expone la lista de amigos de forma inmutable
  /// 
  /// List.unmodifiable() crea una vista de solo lectura de la lista
  /// Esto previene que la UI modifique directamente el estado interno
  List<Amigo> get amigos => List<Amigo>.unmodifiable(_amigos);
  
  /// Indica si el ViewModel está cargando datos del servidor
  bool get cargando => _cargando;
  
  /// Mensaje de error actual (null si no hay error)
  String? get mensajeError => _mensajeError;

  /// Indica si hay alguna operación en progreso
  /// 
  /// Útil para mostrar indicadores de carga generales en la UI
  bool get tieneOperacionesEnProgreso => _operacionesEnProgreso.isNotEmpty;

  /// Verifica si una operación específica está en progreso
  /// 
  /// Útil para mostrar indicadores de carga específicos (ej: botón deshabilitado mientras se elimina)
  /// 
  /// Parámetro [operacion]: ID de la operación a verificar (ej: 'add_1234567890')
  bool estaOperandoEn(String operacion) =>
      _operacionesEnProgreso.contains(operacion);

  /// Carga inicial de datos si la lista está vacía
  /// 
  /// Este método implementa carga lazy (perezosa): solo carga datos cuando se necesita
  /// Si la lista ya tiene datos o ya se está cargando, no hace nada
  /// 
  /// Útil para inicializar el ViewModel sin cargar datos innecesariamente
  Future<void> inicializar() async {
    if (_amigos.isEmpty && !_cargando && !_disposed) {
      await cargarAmigos();
    }
  }

  /// Obtiene la lista de amigos desde el servidor y actualiza el estado
  /// 
  /// Este método:
  /// 1. Marca el estado como "cargando"
  /// 2. Llama al servicio de API para obtener los amigos
  /// 3. Actualiza la lista interna con los resultados
  /// 4. Notifica a los listeners (la UI) para que se actualice
  /// 5. Maneja errores y los expone mediante _mensajeError
  Future<void> cargarAmigos() async {
    _setCargando(true);
    try {
      // Llamar al servicio de API (operación asíncrona)
      final resultado = await _apiService.cargarAmigos();
      // Solo actualizar si el ViewModel no ha sido destruido
      if (!_disposed) {
        // Usar cascade operator (..) para múltiples operaciones en la misma lista
        _amigos
          ..clear()      // Limpiar lista anterior
          ..addAll(resultado); // Agregar nuevos amigos
        _mensajeError = null; // Limpiar errores previos
        _safeNotifyListeners(); // Notificar éxito a la UI
      }
    } catch (error) {
      // Si hay error, guardarlo y notificar a la UI
      if (!_disposed) {
        _mensajeError = error.toString();
        _safeNotifyListeners(); // Notificar error inmediatamente
      }
    } finally {
      // Siempre marcar como "no cargando" al terminar
      _setCargando(false);
      if (!_disposed) {
        _safeNotifyListeners(); // Notificar fin de carga
      }
    }
  }

  /// Añade un nuevo amigo al servidor y actualiza la lista local
  /// 
  /// Parámetro [nombre]: Nombre del nuevo amigo a crear
  /// 
  /// Este método:
  /// 1. Crea un ID único para esta operación (para rastrear su progreso)
  /// 2. Marca la operación como "en progreso"
  /// 3. Llama al servicio de API para crear el amigo
  /// 4. Agrega el nuevo amigo a la lista local
  /// 5. Notifica a la UI de los cambios
  /// 
  /// Si ocurre un error, se guarda en _mensajeError y se notifica a la UI
  Future<void> addAmigo(String nombre) async {
    // Crear ID único basado en timestamp para rastrear esta operación específica
    final operacionId = 'add_${DateTime.now().millisecondsSinceEpoch}';
    _operacionesEnProgreso.add(operacionId);
    _safeNotifyListeners();

    // Operación asíncrona: se ejecuta en segundo plano
    // La UI puede continuar funcionando mientras se procesa
    try {
      // Crear el amigo en el servidor
      final nuevo = await _apiService.addAmigo(nombre);
      // Solo actualizar si el ViewModel no ha sido destruido
      if (!_disposed) {
        _amigos.add(nuevo); // Agregar a la lista local
        _mensajeError = null; // Limpiar errores
        _safeNotifyListeners(); // Notificar a la UI
      }
    } catch (error) {
      // Si hay error, guardarlo para mostrar en la UI
      if (!_disposed) {
        _mensajeError = error.toString();
        _safeNotifyListeners();
      }
    } finally {
      // Siempre remover la operación del conjunto cuando termine
      if (!_disposed) {
        _operacionesEnProgreso.remove(operacionId);
        _safeNotifyListeners();
      }
    }
  }

  /// Elimina un amigo del servidor y de la lista local
  /// 
  /// Parámetro [id]: ID del amigo a eliminar
  /// 
  /// Sigue el mismo patrón que addAmigo: rastrea la operación y maneja errores
  Future<void> eliminarAmigo(int id) async {
    // ID de operación basado en el ID del amigo (único para cada amigo)
    final operacionId = 'delete_$id';
    _operacionesEnProgreso.add(operacionId);
    _safeNotifyListeners();

    try {
      // Eliminar en el servidor
      await _apiService.deleteAmigo(id);
      if (!_disposed) {
        // Remover de la lista local usando removeWhere
        _amigos.removeWhere((amigo) => amigo.id == id);
        _mensajeError = null;
        _safeNotifyListeners();
      }
    } catch (error) {
      if (!_disposed) {
        _mensajeError = error.toString();
        _safeNotifyListeners();
      }
    } finally {
      if (!_disposed) {
        _operacionesEnProgreso.remove(operacionId);
        _safeNotifyListeners();
      }
    }
  }

  /// Actualiza el nombre de un amigo existente
  /// 
  /// Parámetros:
  /// - [id]: ID del amigo a actualizar
  /// - [nombre]: Nuevo nombre para el amigo
  /// 
  /// Actualiza tanto en el servidor como en la lista local
  Future<void> updateAmigo(int id, String nombre) async {
    _setCargando(true);
    try {
      // Actualizar en el servidor
      final actualizado = await _apiService.updateAmigo(id, nombre);
      if (!_disposed) {
        // Buscar el índice del amigo en la lista
        final index = _amigos.indexWhere((amigo) => amigo.id == id);
        if (index != -1) {
          // Reemplazar el amigo antiguo con el actualizado
          _amigos[index] = actualizado;
        }
        _mensajeError = null;
      }
    } catch (error) {
      if (!_disposed) {
        _mensajeError = error.toString();
      }
    } finally {
      _setCargando(false);
    }
  }

  /// Registra un pago parcial de un amigo, distribuyéndolo entre sus deudas pendientes
  /// 
  /// Parámetros:
  /// - [amigo]: El amigo que está pagando
  /// - [montoPagado]: Cantidad de dinero que está pagando
  /// 
  /// El servicio de API se encarga de distribuir el pago entre los gastos pendientes
  /// Este método solo actualiza el estado local después de que el servidor procesa el pago
  Future<void> pagarSaldo(Amigo amigo, double montoPagado) async {
    _setCargando(true);
    try {
      // El servicio distribuye el pago automáticamente entre las deudas
      final actualizado = await _apiService.pagarSaldoAmigo(amigo, montoPagado);
      if (!_disposed) {
        // Buscar y actualizar el amigo en la lista local
        final index = _amigos.indexWhere((a) => a.id == amigo.id);
        if (index != -1) {
          _amigos[index] = actualizado;
        }
        _mensajeError = null;
      }
    } catch (error) {
      if (!_disposed) {
        _mensajeError = error.toString();
      }
    } finally {
      _setCargando(false);
    }
  }

  /// Actualiza el estado de carga y notifica a los listeners
  /// 
  /// Método privado (prefijo '_') que centraliza la lógica de actualizar el estado de carga
  /// y notificar a la UI
  void _setCargando(bool valor) {
    _cargando = valor;
    _safeNotifyListeners();
  }

  /// Notifica a los listeners solo si el ViewModel no ha sido disposed
  /// 
  /// Esto previene errores si se intenta notificar después de que el widget fue destruido
  /// Es una práctica común en Flutter para evitar memory leaks y errores
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners(); // Método de ChangeNotifier que avisa a todos los listeners
    }
  }

  /// Método llamado cuando el ViewModel ya no se necesita
  /// 
  /// Marca el ViewModel como disposed para prevenir notificaciones futuras
  /// y libera recursos. Luego llama al dispose del padre (ChangeNotifier)
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
