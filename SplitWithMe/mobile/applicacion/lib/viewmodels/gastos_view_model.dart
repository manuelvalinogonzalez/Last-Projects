import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/gasto.dart';

/// ViewModel que gestiona el estado y la lógica de negocio de los gastos
/// 
/// Este ViewModel implementa el patrón MVVM (Model-View-ViewModel):
/// - **Model**: La clase Gasto representa los datos
/// - **View**: Las pantallas de la UI (GastosScreen)
/// - **ViewModel**: Esta clase gestiona la lógica y el estado
/// 
/// Usa ChangeNotifier para notificar cambios a la UI cuando el estado cambia
/// La UI escucha estos cambios mediante un ChangeNotifierProvider o similar
/// 
/// Similar a AmigosViewModel pero gestiona gastos compartidos entre amigos
class GastosViewModel extends ChangeNotifier {
  /// Constructor que recibe el servicio de API necesario para comunicarse con el backend
  GastosViewModel(this._apiService);

  /// Servicio que maneja todas las operaciones HTTP con la API REST
  final ApiService _apiService;

  /// Lista privada de gastos (estado interno del ViewModel)
  /// Solo se expone mediante el getter 'gastos' que retorna una lista inmutable
  final List<Gasto> _gastos = [];
  
  /// Indica si se está cargando información desde el servidor
  bool _cargando = false;
  
  /// Mensaje de error si alguna operación falló (null si no hay error)
  String? _mensajeError;
  
  /// Flag para prevenir notificaciones después de que el ViewModel fue destruido
  /// Esto evita errores si se intenta notificar después de dispose()
  bool _disposed = false;

  /// Rastrea las operaciones en progreso para mostrar indicadores de carga específicos
  /// 
  /// Cada operación tiene un ID único (ej: 'add_gasto_1234567890', 'update_gasto_5')
  /// Esto permite mostrar indicadores de carga diferentes para diferentes operaciones
  final Set<String> _operacionesEnProgreso = {};

  /// Getter que expone la lista de gastos de forma inmutable
  /// 
  /// List.unmodifiable() crea una vista de solo lectura de la lista
  /// Esto previene que la UI modifique directamente el estado interno
  List<Gasto> get gastos => List<Gasto>.unmodifiable(_gastos);
  
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
  /// Parámetro [operacion]: ID de la operación a verificar (ej: 'add_gasto_1234567890')
  bool estaOperandoEn(String operacion) =>
      _operacionesEnProgreso.contains(operacion);

  /// Carga inicial de datos si la lista está vacía (carga lazy)
  /// 
  /// Este método implementa carga lazy (perezosa): solo carga datos cuando se necesita
  /// Si la lista ya tiene datos o ya se está cargando, no hace nada
  /// 
  /// Útil para inicializar el ViewModel sin cargar datos innecesariamente
  Future<void> inicializar() async {
    if (_gastos.isEmpty && !_cargando && !_disposed) {
      await cargarGastos();
    }
  }

  /// Obtiene la lista de gastos desde el servidor y actualiza el estado
  /// 
  /// Este método:
  /// 1. Marca el estado como "cargando"
  /// 2. Llama al servicio de API para obtener los gastos
  /// 3. Actualiza la lista interna con los resultados
  /// 4. Notifica a los listeners (la UI) para que se actualice
  /// 5. Maneja errores y los expone mediante _mensajeError
  Future<void> cargarGastos() async {
    _setCargando(true);
    try {
      // Llamar al servicio de API (operación asíncrona)
      final resultado = await _apiService.cargarGastos();
      // Solo actualizar si el ViewModel no ha sido destruido
      if (!_disposed) {
        // Usar cascade operator (..) para múltiples operaciones en la misma lista
        _gastos
          ..clear()      // Limpiar lista anterior
          ..addAll(resultado); // Agregar nuevos gastos
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

  /// Añade un nuevo gasto al servidor y actualiza la lista local
  /// 
  /// Parámetros:
  /// - [descripcion]: Descripción del gasto
  /// - [monto]: Monto total del gasto
  /// - [pagadorId]: ID del amigo que pagó el gasto
  /// - [deudoresIds]: Lista de IDs de amigos que deben parte del gasto
  /// - [onSyncComplete]: Callback opcional que se ejecuta después de añadir el gasto
  ///                     Útil para sincronizar saldos con otros ViewModels
  /// 
  /// Este método:
  /// 1. Crea un ID único para esta operación (para rastrear su progreso)
  /// 2. Marca la operación como "en progreso"
  /// 3. Llama al servicio de API para crear el gasto
  /// 4. Agrega el nuevo gasto a la lista local
  /// 5. Ejecuta el callback de sincronización si se proporcionó
  /// 6. Notifica a la UI de los cambios
  Future<void> addGasto({
    required String descripcion,
    required double monto,
    required int pagadorId,
    required List<int> deudoresIds,
    void Function()? onSyncComplete,
  }) async {
    // Crear ID único basado en timestamp para rastrear esta operación específica
    final operacionId = 'add_gasto_${DateTime.now().millisecondsSinceEpoch}';
    _operacionesEnProgreso.add(operacionId);
    _safeNotifyListeners();

    // Operación asíncrona: se ejecuta en segundo plano
    try {
      // Crear el gasto en el servidor
      final nuevo = await _apiService.addGasto(
        descripcion: descripcion,
        monto: monto,
        pagadorId: pagadorId,
        deudoresIds: deudoresIds,
      );
      // Solo actualizar si el ViewModel no ha sido destruido
      if (!_disposed) {
        _gastos.add(nuevo); // Agregar a la lista local
        _mensajeError = null; // Limpiar errores
        _safeNotifyListeners(); // Notificar a la UI
        
        // Ejecutar callback de sincronización si se proporcionó
        // El operador '?.' solo llama al método si no es null
        onSyncComplete?.call();
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

  /// Actualiza un gasto existente en el servidor y en la lista local
  /// 
  /// Parámetros:
  /// - [id]: ID del gasto a actualizar
  /// - [descripcion]: Nueva descripción
  /// - [monto]: Nuevo monto total
  /// - [pagadorId]: Nuevo ID del pagador
  /// - [deudoresIds]: Nueva lista de deudores
  /// - [onSyncComplete]: Callback opcional para sincronizar después de actualizar
  /// 
  /// Sigue el mismo patrón que addGasto
  Future<void> updateGasto({
    required int id,
    required String descripcion,
    required double monto,
    required int pagadorId,
    required List<int> deudoresIds,
    void Function()? onSyncComplete,
  }) async {
    // ID de operación basado en el ID del gasto
    final operacionId = 'update_gasto_$id';
    _operacionesEnProgreso.add(operacionId);
    _safeNotifyListeners();

    try {
      // Actualizar en el servidor
      final actualizado = await _apiService.updateGasto(
        id: id,
        descripcion: descripcion,
        monto: monto,
        pagadorId: pagadorId,
        deudoresIds: deudoresIds,
      );
      if (!_disposed) {
        // Buscar y reemplazar el gasto en la lista local
        final index = _gastos.indexWhere((gasto) => gasto.id == id);
        if (index != -1) {
          _gastos[index] = actualizado;
        }
        _mensajeError = null;
        _safeNotifyListeners();
        // Ejecutar callback de sincronización
        onSyncComplete?.call();
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

  /// Elimina un gasto del servidor y de la lista local
  /// 
  /// Parámetros:
  /// - [id]: ID del gasto a eliminar
  /// - [onSyncComplete]: Callback opcional para sincronizar después de eliminar
  /// 
  /// Sigue el mismo patrón que los otros métodos
  Future<void> eliminarGasto(int id, {void Function()? onSyncComplete}) async {
    final operacionId = 'delete_gasto_$id';
    _operacionesEnProgreso.add(operacionId);
    _safeNotifyListeners();

    try {
      // Eliminar en el servidor
      await _apiService.deleteGasto(id);
      if (!_disposed) {
        // Remover de la lista local usando removeWhere
        _gastos.removeWhere((gasto) => gasto.id == id);
        _mensajeError = null;
        _safeNotifyListeners();
        // Ejecutar callback de sincronización
        onSyncComplete?.call();
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
