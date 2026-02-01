// ============================================================================
// IMPORTS Y DEPENDENCIAS
// ============================================================================

// Importación de la biblioteca de asincronía (necesaria para Future, async/await, TimeoutException)
import 'dart:async';

// Importación para codificar/decodificar JSON (jsonEncode, jsonDecode)
import 'dart:convert';

// Importación para operaciones de E/S (SocketException para errores de conexión)
import 'dart:io';

// Biblioteca HTTP para hacer peticiones al servidor REST
// El 'as http' crea un alias para evitar conflictos de nombres
import 'package:http/http.dart' as http;

// Importación de los modelos de datos que se usarán en este servicio
import '../models/amigo.dart';
import '../models/gasto.dart';

// ============================================================================
// CLASE PRINCIPAL: ApiService
// ============================================================================

/// Servicio para comunicarse con la API REST del backend
/// 
/// Esta clase centraliza todas las operaciones de comunicación con el servidor:
/// - Operaciones CRUD (Create, Read, Update, Delete) para amigos
/// - Operaciones CRUD para gastos compartidos
/// - Gestión de participantes en gastos
/// - Distribución de pagos y cálculo de saldos
/// - Manejo robusto de errores (timeouts, conexión, formato)
/// 
/// Características principales:
/// - Uso de programación asíncrona (async/await) para no bloquear la UI
/// - Ejecución en paralelo de operaciones independientes para mejor rendimiento
/// - Manejo de timeouts para evitar esperas infinitas
/// - Rollback automático en caso de errores para mantener consistencia
/// - Conversión automática entre objetos Dart y JSON
class ApiService {
  /// Constructor del servicio de API
  /// 
  /// Parámetros opcionales (todos nullable con '?'):
  /// - [client]: Cliente HTTP personalizado (útil para testing o configuraciones especiales)
  ///             Si no se proporciona, usa http.Client() por defecto
  /// - [baseUrl]: URL base del servidor (ej: 'http://10.0.2.2:8000')
  ///              Si no se proporciona, usa la URL por defecto del emulador Android
  /// - [timeout]: Tiempo máximo de espera para las peticiones HTTP
  ///              Si no se proporciona, usa 10 segundos por defecto
  /// 
  /// La lista de inicialización (después de ':') se ejecuta ANTES del cuerpo del constructor
  ApiService({http.Client? client, String? baseUrl, Duration? timeout})
    // Si client es null, crear un nuevo http.Client; si no, usar el proporcionado
    : _client = client ?? http.Client(),
      // Si baseUrl es null, usar la URL por defecto; si no, usar la proporcionada
      _baseUrl = baseUrl ?? _defaultBaseUrl,
      // Si timeout es null, usar 10 segundos; si no, usar el proporcionado
      _timeout = timeout ?? const Duration(seconds: 10);

  // ============================================================================
  // CONSTANTES Y PROPIEDADES PRIVADAS
  // ============================================================================

  /// URL por defecto para el emulador de Android
  /// 
  /// 'static const' significa:
  /// - 'static': pertenece a la clase, no a las instancias (compartida por todos)
  /// - 'const': valor constante de compilación (no puede cambiar)
  /// - '10.0.2.2' es la IP especial del emulador Android que redirige al localhost del host
  ///   Esto permite que la app en el emulador se comunique con el servidor en la PC
  static const _defaultBaseUrl = 'http://10.0.2.2:8000';

  /// Cliente HTTP que realiza las peticiones al servidor
  /// 
  /// Es 'final' porque una vez asignado no puede cambiar (inmutable)
  /// Privado (prefijo '_') para que solo esta clase pueda usarlo
  final http.Client _client;
  
  /// URL base del servidor (ej: 'http://10.0.2.2:8000')
  /// Se usa como prefijo para construir todas las URLs completas
  final String _baseUrl;
  
  /// Duración máxima de tiempo para esperar respuestas del servidor
  /// Después de este tiempo, se lanza una TimeoutException
  /// Por defecto es 10 segundos
  final Duration _timeout;

  // ============================================================================
  // MÉTODO AUXILIAR: Construcción de URLs
  // ============================================================================

  /// Construye una URI completa con el path y parámetros de consulta opcionales
  /// 
  /// Este método auxiliar privado ayuda a construir URLs completas de forma consistente.
  /// Combina la URL base con el path del endpoint y opcionalmente agrega parámetros de consulta.
  /// 
  /// Parámetros:
  /// - [path]: Ruta del endpoint (ej: '/friends/', '/expenses/123')
  /// - [query]: Parámetros opcionales de consulta (query parameters) como Map
  ///            Ej: {'friend_id': 5, 'amount': 100.0} → ?friend_id=5&amount=100.0
  /// 
  /// Ejemplo de uso:
  /// ```dart
  /// _uri('/friends/')  // → 'http://10.0.2.2:8000/friends/'
  /// _uri('/expenses/123/friends', {'friend_id': 5})  // → 'http://10.0.2.2:8000/expenses/123/friends?friend_id=5'
  /// ```
  Uri _uri(String path, [Map<String, dynamic>? query]) {
    // Construir la URL base combinando _baseUrl con el path
    // Ej: 'http://10.0.2.2:8000' + '/friends/' = 'http://10.0.2.2:8000/friends/'
    final uri = Uri.parse('$_baseUrl$path');
    
    // Si no hay parámetros de consulta, retornar la URI tal cual
    if (query == null) {
      return uri;
    }
    
    // Si hay parámetros de consulta, agregarlos a la URI
    // replace() crea una nueva URI con los parámetros agregados
    return uri.replace(
      // Convertir el Map de parámetros al formato que espera Uri
      queryParameters: query.map(
        // Para cada par clave-valor en el Map:
        // - La clave (key) se mantiene como String
        // - El valor (value) se convierte a String, o '' si es null
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    );
  }

  // ============================================================================
  // SECCIÓN 1: OPERACIONES CRUD PARA AMIGOS
  // ============================================================================
  // Estos métodos implementan las operaciones básicas de base de datos:
  // - Create: addAmigo() - Crear un nuevo amigo
  // - Read: cargarAmigos(), _obtenerAmigo() - Leer/obtener amigos
  // - Update: updateAmigo() - Actualizar un amigo existente
  // - Delete: deleteAmigo() - Eliminar un amigo
  // ============================================================================

  /// Obtiene la lista completa de amigos desde el servidor
  /// 
  /// Realiza una petición GET al endpoint '/friends/' para obtener todos los amigos.
  /// 
  /// Flujo:
  /// 1. Hace una petición GET al servidor con timeout
  /// 2. Verifica que el código de estado sea 200 (éxito)
  /// 3. Decodifica el JSON recibido
  /// 4. Convierte cada objeto JSON en un objeto Amigo usando el factory constructor
  /// 5. Retorna la lista de amigos
  /// 
  /// Manejo de errores:
  /// - SocketException: El servidor no está disponible o no se puede conectar
  /// - TimeoutException: El servidor tardó demasiado en responder
  /// - FormatException: El JSON recibido no tiene el formato esperado
  /// 
  /// Retorna: Lista de objetos Amigo con todos los amigos del servidor
  Future<List<Amigo>> cargarAmigos() async {
    try {
      // Hacer petición GET al endpoint '/friends/' con timeout configurado
      // 'await' pausa la ejecución hasta que la petición termine
      // .timeout() lanza TimeoutException si la petición tarda más que _timeout
      final response = await _client.get(_uri('/friends/')).timeout(_timeout);
      
      // Verificar código de estado HTTP 200 (OK - éxito)
      if (response.statusCode == 200) {
        // Decodificar el cuerpo de la respuesta (JSON) a un objeto Dart
        final data = jsonDecode(response.body);
        
        // Verificar que los datos recibidos sean una lista
        if (data is List) {
          // Transformar la lista de objetos JSON a lista de objetos Amigo:
          // 1. whereType<Map<String, dynamic>>() - Filtra solo los elementos que son Map
          // 2. .map(Amigo.fromJson) - Convierte cada Map JSON en un objeto Amigo
          // 3. .toList() - Convierte el Iterable resultante en una List
          return data
              .whereType<Map<String, dynamic>>()
              .map(Amigo.fromJson)
              .toList();
        }
        // Si no es una lista, lanzar excepción de formato
        throw const FormatException('Formato inesperado en la respuesta.');
      }
      // Si el código de estado no es 200, lanzar error HTTP personalizado
      _throwHttpError('cargar amigos', response);
    } on SocketException {
      // Capturar error de conexión (servidor no disponible, sin internet, etc.)
      throw ApiException(
        'El servidor no está corriendo. '
        'No se puede conectar al servidor. '
        'Asegúrate de que está disponible en $_baseUrl',
      );
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder al cargar amigos.',
      );
    } on FormatException catch (error) {
      throw ApiException('Error de formato al cargar amigos: ${error.message}');
    }

    throw ApiException('Error desconocido al cargar amigos.');
  }

  /// Crea un nuevo amigo en el servidor
  /// Esta operación realiza una petición POST al servidor para crear un nuevo amigo.
  /// El servidor asigna un ID único y retorna el amigo completo creado.
  /// 
  /// Parámetro [nombre]: Nombre del nuevo amigo a crear
  /// Retorna: El amigo recién creado con su ID asignado por el servidor
  Future<Amigo> addAmigo(String nombre) async { // Future representa algo que se creara en el futuro, para peticiones a servidores
    // PASO 1: Preparar los datos para enviar al servidor
    // jsonEncode() convierte un objeto Dart a formato JSON (string)
    // <String, dynamic> indica que el Map tiene claves String y valores dynamic
    // 'name' es el nombre del campo que espera la API (snake_case/camelCase según API)
    final payload = jsonEncode(<String, dynamic>{'name': nombre});
    
    try {
      // PASO 2: Realizar la petición POST al servidor
      // POST es el método HTTP para crear nuevos recursos
      final response = await _client // el await para el codigo hasya que responde el server, y luego continua
          // .post() envía una petición POST a la URL especificada
          // _uri('/friends/') construye la URL completa (ej: 'http://10.0.2.2:8000/friends/')
          .post(
            _uri('/friends/'),
            headers: _jsonHeaders, // Headers que indican que enviamos JSON
            body: payload,         // El cuerpo de la petición (el JSON con el nombre)
          )
          // .timeout() limita el tiempo de espera
          // Si tarda más que _timeout, lanza TimeoutException
          .timeout(_timeout);
      
      // PASO 3: Verificar el código de estado HTTP
      // 201 (Created) = recurso creado exitosamente
      // 200 (OK) = operación exitosa (algunas APIs lo usan para crear)
      if (response.statusCode == 201 || response.statusCode == 200) {
        // PASO 4: Decodificar la respuesta JSON
        // El servidor retorna el amigo creado en formato JSON
        // jsonDecode() convierte el string JSON a un objeto Dart (Map)
        final data = jsonDecode(response.body); // decodifica la respuesta del servidor, que es lo que le mandaste + id y demas
        
        // PASO 5: Verificar que los datos sean un objeto (Map) y no otro tipo
        if (data is Map<String, dynamic>) {
          // PASO 6: Convertir el JSON a un objeto Amigo usando el factory constructor
          // fromJson() crea una instancia de Amigo desde los datos JSON
          return Amigo.fromJson(data);
        }
        // Si los datos no son un Map, lanzar excepción de formato
        throw const FormatException('Formato inesperado al añadir amigo.');
      }
      // PASO 7: Si el código de estado no es 201 ni 200, lanzar error HTTP
      // Esto maneja errores como 400 (Bad Request), 500 (Server Error), etc.
      _throwHttpError('añadir amigo', response);
      
    } on SocketException {
      // Capturar error de conexión (servidor no disponible, sin internet, etc.)
      // SocketException se lanza cuando no se puede establecer conexión
      throw ApiException('El servidor no está corriendo. No se puede conectar al servidor.');
      
    } on TimeoutException {
      // Capturar error de timeout (servidor tardó demasiado en responder)
      // TimeoutException se lanza cuando .timeout() expira
      throw ApiException('El servidor tardó demasiado en responder.');
      
    } on FormatException catch (error) {
      // Capturar error de formato (JSON inválido, estructura incorrecta, etc.)
      // catch (error) nos permite acceder al objeto de error para obtener detalles
      throw ApiException('Error de formato: ${error.message}');
    }
    // Si ninguna excepción anterior se lanzó pero llegamos aquí, es un error desconocido
    throw ApiException('Error desconocido al añadir amigo.');
  }

  /// Elimina un amigo del servidor por su ID
  /// 
  /// Esta operación realiza una petición DELETE al servidor para eliminar un amigo.
  /// Una vez eliminado, no se puede recuperar.
  /// 
  /// Parámetro [id]: ID del amigo a eliminar
  /// Retorna: void (no retorna nada, solo confirma que se eliminó)
  Future<void> deleteAmigo(int id) async {
    try {
      // PASO 1: Realizar la petición DELETE al servidor
      // DELETE es el método HTTP para eliminar recursos
      final response = await _client
          // .delete() envía una petición DELETE a la URL especificada
          // _uri('/friends/$id') construye la URL con el ID del amigo
          // Ejemplo: 'http://10.0.2.2:8000/friends/5' para eliminar el amigo con ID 5
          .delete(_uri('/friends/$id'))
          // .timeout() limita el tiempo de espera de la petición
          .timeout(_timeout);
      
      // PASO 2: Verificar el código de estado HTTP
      // 204 (No Content) = recurso eliminado exitosamente, sin contenido en la respuesta
      // 200 (OK) = operación exitosa (algunas APIs retornan 200 al eliminar)
      if (response.statusCode == 204 || response.statusCode == 200) {
        // Si la eliminación fue exitosa, retornar sin hacer nada más
        // El método retorna void, así que solo confirmamos que terminó
        return;
      }
      // PASO 3: Si el código de estado no es 204 ni 200, lanzar error HTTP
      // Esto maneja errores como 404 (Not Found), 500 (Server Error), etc.
      _throwHttpError('eliminar amigo', response);
      
    } on SocketException {
      // Capturar error de conexión (servidor no disponible, sin internet, etc.)
      // SocketException se lanza cuando no se puede establecer conexión con el servidor
      throw ApiException('El servidor no está corriendo. No se puede conectar al servidor.');
      
    } on TimeoutException {
      // Capturar error de timeout (servidor tardó demasiado en responder)
      // TimeoutException se lanza cuando la petición tarda más que _timeout
      throw ApiException('El servidor tardó demasiado en responder.');
    }
    // Nota: No hay manejo de FormatException aquí porque DELETE normalmente
    // no retorna cuerpo en la respuesta, solo el código de estado
  }

  /// Actualiza el nombre de un amigo existente
  /// 
  /// Esta operación realiza una petición PUT al servidor para actualizar un amigo.
  /// PUT es idempotente: hacer la misma petición múltiples veces tiene el mismo efecto.
  /// 
  /// Parámetros:
  /// - [id]: ID del amigo a actualizar
  /// - [nombre]: Nuevo nombre para el amigo
  /// 
  /// Retorna: El amigo actualizado con los nuevos datos
  Future<Amigo> updateAmigo(int id, String nombre) async {
    // PASO 1: Preparar los datos para enviar al servidor
    // jsonEncode() convierte un objeto Dart a formato JSON (string)
    // Enviamos solo el campo 'name' porque es lo que vamos a actualizar
    final payload = jsonEncode(<String, dynamic>{'name': nombre});
    
    try {
      // PASO 2: Realizar la petición PUT al servidor
      // PUT es el método HTTP para actualizar recursos existentes
      final response = await _client
          // .put() envía una petición PUT a la URL especificada
          // _uri('/friends/$id') construye la URL con el ID del amigo a actualizar
          // Ejemplo: 'http://10.0.2.2:8000/friends/5' para actualizar el amigo con ID 5
          .put(
            _uri('/friends/$id'),
            headers: _jsonHeaders, // Headers que indican que enviamos JSON
            body: payload,         // El cuerpo de la petición (el JSON con el nuevo nombre)
          )
          // .timeout() limita el tiempo de espera
          .timeout(_timeout);
      
      // PASO 3: Manejar diferentes códigos de estado HTTP
      
      // CASO 1: Código 200 (OK) - Actualización exitosa con respuesta
      if (response.statusCode == 200) {
        // El servidor retorna el amigo actualizado en el cuerpo de la respuesta
        // Decodificar el JSON recibido
        final data = jsonDecode(response.body);
        
        // Verificar que los datos sean un objeto (Map)
        if (data is Map<String, dynamic>) {
          // Convertir el JSON a un objeto Amigo y retornarlo
          return Amigo.fromJson(data);
        }
        // Si los datos no son un Map, lanzar excepción de formato
        throw const FormatException('Formato inesperado al actualizar amigo.');
        
      } else if (response.statusCode == 204) {
        // CASO 2: Código 204 (No Content) - Actualización exitosa sin respuesta
        // Algunos servidores retornan 204 sin cuerpo cuando actualizan exitosamente
        // En este caso, necesitamos hacer otra petición GET para obtener el amigo actualizado
        return await _obtenerAmigo(id);
      }
      
      // CASO 3: Cualquier otro código de estado (400, 404, 500, etc.)
      // Lanzar error HTTP personalizado
      _throwHttpError('actualizar amigo', response);
      
    } on SocketException {
      // Capturar error de conexión (servidor no disponible, sin internet, etc.)
      throw ApiException('El servidor no está corriendo. No se puede conectar al servidor.');
      
    } on TimeoutException {
      // Capturar error de timeout (servidor tardó demasiado en responder)
      throw ApiException('El servidor tardó demasiado en responder.');
      
    } on FormatException catch (error) {
      // Capturar error de formato (JSON inválido, estructura incorrecta, etc.)
      // catch (error) nos permite acceder al mensaje del error
      throw ApiException('Error de formato: ${error.message}');
    }
    // Si ninguna excepción anterior se lanzó pero llegamos aquí, es un error desconocido
    throw ApiException('Error desconocido al actualizar amigo.');
  }

  // ============================================================================
  // MÉTODO ESPECIAL: Pago de saldo con distribución automática
  // ============================================================================

  /// Registra un pago parcial de un amigo, distribuyéndolo entre sus deudas pendientes
  /// 
  /// Este es uno de los métodos más complejos. Implementa la lógica de negocio para
  /// distribuir un pago entre múltiples gastos pendientes de forma proporcional.
  /// 
  /// Algoritmo:
  /// 1. Obtiene todos los gastos donde el amigo tiene deudas
  /// 2. Para cada gasto, calcula cuánto debe el amigo
  /// 3. Distribuye el monto pagado entre los gastos en orden (hasta agotar el monto)
  /// 4. Actualiza todos los montos EN PARALELO para mejor rendimiento
  /// 5. Retorna el amigo actualizado con los nuevos saldos
  /// 
  /// Parámetros:
  /// - [amigo]: El amigo que está haciendo el pago
  /// - [montoPagado]: Cantidad de dinero que el amigo está pagando
  /// 
  /// Las actualizaciones se realizan en paralelo para mejorar el rendimiento:
  /// En lugar de actualizar gasto por gasto (secuencial), se actualizan todos
  /// al mismo tiempo usando Future.wait()
  Future<Amigo> pagarSaldoAmigo(Amigo amigo, double montoPagado) async {
    try {
      // PASO 1: Obtener todos los gastos donde este amigo tiene deudas
      // Endpoint: GET /friends/{id}/expenses
      final response = await _client
          .get(_uri('/friends/${amigo.id}/expenses'))
          .timeout(_timeout);

      // Verificar que la petición fue exitosa
      if (response.statusCode != 200) {
        _throwHttpError('obtener gastos del amigo', response);
      }

      // Decodificar la respuesta JSON
      final gastosData = jsonDecode(response.body);
      
      // Verificar que sea una lista
      if (gastosData is! List) {
        throw const FormatException('Formato inesperado de gastos del amigo.');
      }

      // PASO 2: Calcular todos los pagos antes de hacer cualquier actualización
      // Esto permite validar la lógica antes de modificar datos en el servidor
      
      double importeRestante = montoPagado; // Monto que aún queda por distribuir
      final actualizaciones = <Future<void>>[]; // Lista de operaciones a ejecutar en paralelo

      // Iterar sobre cada gasto para calcular cuánto pagar de cada uno
      for (final gastoData in gastosData) {
        // Si ya se distribuyó todo el monto, no seguir procesando
        if (importeRestante <= 0) break;

        // Si el dato no es un Map (objeto JSON), saltarlo
        if (gastoData is! Map<String, dynamic>) continue;

        // Extraer información del gasto
        final gastoId = gastoData['id'] as int?;
        final creditBalance = _toDouble(gastoData['credit_balance']); // Lo que le deben al amigo
        final debitBalance = _toDouble(gastoData['debit_balance']);   // Lo que el amigo debe

        // Si el gasto no tiene ID válido, saltarlo
        if (gastoId == null) continue;

        // Calcular la deuda neta en este gasto
        // deuda = lo que debe - lo que le deben
        // Si es positivo, el amigo debe dinero; si es negativo o cero, no debe nada
        final deuda = debitBalance - creditBalance;

        // Solo procesar si hay deuda pendiente
        if (deuda > 0) {
          // Calcular cuánto pagar de este gasto específico
          // Si el importe restante es menor que la deuda, pagar solo lo que queda
          // Si no, pagar toda la deuda de este gasto
          final pago = importeRestante < deuda ? importeRestante : deuda;

          // Agregar la operación de actualización a la lista
          // No se ejecuta todavía, solo se agrega a la lista para ejecutar después
          actualizaciones.add(
            _actualizarMontoParticipante(
              gastoId,              // ID del gasto
              amigo.id,             // ID del amigo
              creditBalance + pago, // Nuevo crédito (lo que le deben aumenta con el pago)
            ),
          );

          // Restar el pago del importe restante
          importeRestante -= pago;
        }
      }

      // PASO 3: Ejecutar TODAS las actualizaciones EN PARALELO
      // Future.wait() ejecuta todas las operaciones asíncronas simultáneamente
      // Esto es mucho más rápido que hacerlo secuencialmente (una por una)
      // Ejemplo: Si hay 5 gastos, en lugar de tomar 5*200ms = 1000ms,
      //          toma aproximadamente 200ms (el tiempo del más lento)
      await Future.wait(actualizaciones);

      // PASO 4: Obtener el amigo actualizado con los nuevos saldos
      // Después de todas las actualizaciones, el servidor ha recalculado los saldos
      return await _obtenerAmigo(amigo.id);
    } on SocketException {
      throw ApiException('El servidor no está corriendo. No se puede conectar al servidor.');
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder. El pago podría no haberse registrado correctamente.',
      );
    } on FormatException catch (error) {
      throw ApiException('Error de formato: ${error.message}');
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException('Error al registrar pago: ${error.toString()}');
    }
  }

  // ============================================================================
  // SECCIÓN 2: OPERACIONES CRUD PARA GASTOS
  // ============================================================================
  // Estos métodos manejan los gastos compartidos entre amigos.
  // Incluyen lógica compleja para gestionar participantes y distribuir montos.
  // ============================================================================

  /// Obtiene la lista completa de gastos desde el servidor
  /// 
  /// Similar a cargarAmigos(), pero más complejo porque cada gasto requiere:
  /// - Obtener sus participantes
  /// - Calcular quién es el pagador
  /// - Determinar quiénes son los deudores
  /// - Distribuir los montos correctamente
  /// 
  /// Los gastos se mapean en paralelo para mejorar el rendimiento:
  /// En lugar de procesar gasto por gasto (secuencial), se procesan todos
  /// al mismo tiempo usando Future.wait(), lo que reduce significativamente el tiempo.
  /// 
  /// Ejemplo de rendimiento:
  /// - Secuencial: 10 gastos × 300ms cada uno = 3000ms (3 segundos)
  /// - Paralelo: 10 gastos en paralelo = ~300ms (0.3 segundos) - ¡10x más rápido!
  Future<List<Gasto>> cargarGastos() async {
    try {
      // Petición GET al endpoint '/expenses/' para obtener todos los gastos
      final response = await _client.get(_uri('/expenses/')).timeout(_timeout);
      
      if (response.statusCode == 200) {
        // Decodificar el JSON recibido
        final data = jsonDecode(response.body);
        
        if (data is List) {
          // OPTIMIZACIÓN: Mapear todos los gastos EN PARALELO
          // 
          // Paso 1: Filtrar solo los elementos que son Map (objetos JSON)
          // Paso 2: Mapear cada Map a un Future<Gasto> usando _mapGasto()
          //         _mapGasto() es asíncrono porque necesita obtener participantes
          // Paso 3: Esto crea una lista de Futures (promesas de Gasto)
          final futures = data.whereType<Map<String, dynamic>>().map(
            (entry) => _mapGasto(entry), // Cada _mapGasto() retorna Future<Gasto>
          );

          // Ejecutar todas las operaciones de mapeo en paralelo
          // Future.wait() espera a que TODOS los Futures se completen
          // Retorna una List<Gasto> cuando todos terminan
          return await Future.wait(futures);
        }
        throw const FormatException('Formato inesperado al cargar gastos.');
      }
      _throwHttpError('cargar gastos', response);
    } on SocketException {
      throw ApiException('El servidor no está corriendo. No se puede conectar al servidor.');
    } on TimeoutException {
      throw ApiException(
        'El servidor tardó demasiado en responder al cargar gastos.',
      );
    } on FormatException catch (error) {
      throw ApiException('Error de formato al cargar gastos: ${error.message}');
    }
    throw ApiException('Error desconocido al cargar gastos.');
  }

  /// Crea un nuevo gasto y registra los participantes
  /// 
  /// Esta operación es compleja porque involucra múltiples pasos:
  /// 1. Crear el gasto en el servidor
  /// 2. Registrar todos los participantes (pagador y deudores)
  /// 3. Distribuir los montos correctamente
  /// 
  /// Si falla en cualquier punto, realiza rollback para mantener la consistencia:
  /// - Si se creó el gasto pero falla al registrar participantes, elimina el gasto
  /// - Esto previene que queden gastos "huérfanos" sin participantes
  /// 
  /// Parámetros:
  /// - [descripcion]: Descripción del gasto (ej: "Cena en restaurante")
  /// - [monto]: Monto total del gasto
  /// - [pagadorId]: ID del amigo que pagó el gasto
  /// - [deudoresIds]: Lista de IDs de amigos que deben parte del gasto
  /// 
  /// Retorna: El gasto completo creado con todos sus participantes y montos distribuidos
  Future<Gasto> addGasto({
    required String descripcion,
    required double monto,
    required int pagadorId,
    required List<int> deudoresIds,
  }) async {
    // PASO 1: Preparar los datos del gasto para enviar al servidor
    
    // Obtener la fecha y hora actual para el gasto
    final ahora = DateTime.now();
    
    // Construir el payload JSON con los datos del gasto
    // jsonEncode() convierte el Map a string JSON
    final payload = jsonEncode(<String, dynamic>{
      'description': descripcion,           // Descripción del gasto
      'amount': monto,                      // Monto total
      'date': _formatDate(ahora),           // Fecha formateada como YYYY-MM-DD
    });

    // Variable para guardar el ID del gasto una vez creado
    // Es nullable porque aún no existe (se creará en el servidor)
    // Se usa para rollback si algo falla después
    int? gastoId;
    
    try {
      // PASO 2: Crear el gasto en el servidor
      
      // Realizar petición POST para crear el gasto
      final response = await _client
          // .post() envía una petición POST al endpoint '/expenses/'
          .post(
            _uri('/expenses/'),
            headers: _jsonHeaders, // Headers indicando que enviamos JSON
            body: payload,         // El JSON con los datos del gasto
          )
          // .timeout() limita el tiempo de espera
          .timeout(_timeout);
      
      // PASO 3: Verificar que la creación fue exitosa
      // 201 (Created) = recurso creado exitosamente
      // 200 (OK) = operación exitosa (algunas APIs lo usan)
      if (response.statusCode != 201 && response.statusCode != 200) {
        // Si no es éxito, lanzar error HTTP
        _throwHttpError('añadir gasto', response);
      }
      
      // PASO 4: Extraer el ID del gasto creado de la respuesta
      // _decodeMap() decodifica el JSON y valida que sea un Map
      final data = _decodeMap(response.body);
      
      // Extraer el ID del gasto de la respuesta del servidor
      // El servidor retorna el gasto creado con su ID asignado
      gastoId = data['id'] as int?;
      
      // Verificar que el ID existe (si no, algo salió mal)
      if (gastoId == null) {
        throw const FormatException('La respuesta del gasto no incluye ID.');
      }

      // PASO 5: Registrar todos los participantes del gasto
      // Esto incluye:
      // - Registrar el pagador y los deudores en el servidor
      // - Distribuir los montos correctamente entre participantes
      // - Calcular cuánto debe cada uno
      await _registrarParticipantes(
        gastoId,                    // ID del gasto recién creado
        pagadorId: pagadorId,       // ID del amigo que pagó
        deudoresIds: deudoresIds,   // IDs de amigos que deben parte
        monto: monto,               // Monto total para distribuir
      );

      // PASO 6: Obtener el gasto completo con todos los datos actualizados
      // Después de registrar participantes, el servidor ha calculado los saldos
      // Necesitamos obtener el gasto completo para retornarlo
      return await _obtenerGasto(gastoId);
      
    } on SocketException {
      // ERROR: No se puede conectar al servidor
      // Si el gasto ya se creó (gastoId != null), hacer rollback
      await _rollbackGasto(gastoId);
      throw ApiException('El servidor no está corriendo. No se puede conectar al servidor.');
      
    } on TimeoutException {
      // ERROR: El servidor tardó demasiado
      // Si el gasto ya se creó, hacer rollback para mantener consistencia
      await _rollbackGasto(gastoId);
      throw ApiException('El servidor tardó demasiado en responder.');
      
    } on FormatException catch (error) {
      // ERROR: Formato de datos incorrecto
      // Si el gasto ya se creó, hacer rollback
      await _rollbackGasto(gastoId);
      throw ApiException('Error de formato: ${error.message}');
      
    } on ApiException {
      // ERROR: Cualquier otro error de la API
      // Si el gasto ya se creó, hacer rollback
      await _rollbackGasto(gastoId);
      // rethrow relanza la excepción sin modificarla (mantiene el mensaje original)
      rethrow;
    }
    // Nota: Si llegamos aquí, es un error desconocido (no debería pasar)
    // Pero por si acaso, también haríamos rollback si hubiera un catch general
  }

  /// Actualiza un gasto existente y sincroniza los participantes
  /// 
  /// Esta operación es compleja porque debe:
  /// 1. Actualizar los datos básicos del gasto (descripción, monto, fecha)
  /// 2. Sincronizar los participantes (eliminar los que ya no participan, añadir nuevos)
  /// 3. Recalcular y redistribuir los montos correctamente
  /// 
  /// La sincronización es importante porque los participantes pueden haber cambiado:
  /// - Pueden haberse eliminado algunos participantes
  /// - Pueden haberse agregado nuevos participantes
  /// - El pagador puede haber cambiado
  /// 
  /// Parámetros:
  /// - [id]: ID del gasto a actualizar
  /// - [descripcion]: Nueva descripción del gasto
  /// - [monto]: Nuevo monto total del gasto
  /// - [pagadorId]: ID del nuevo pagador (puede ser diferente)
  /// - [deudoresIds]: Nueva lista de deudores (puede ser diferente)
  /// 
  /// Retorna: El gasto actualizado con los nuevos datos y participantes sincronizados
  Future<Gasto> updateGasto({
    required int id,
    required String descripcion,
    required double monto,
    required int pagadorId,
    required List<int> deudoresIds,
  }) async {
    // PASO 1: Preparar los datos actualizados del gasto
    
    // Construir el payload JSON con los datos actualizados
    // jsonEncode() convierte el Map a string JSON
    final payload = jsonEncode(<String, dynamic>{
      'description': descripcion,              // Nueva descripción
      'amount': monto,                         // Nuevo monto total
      'date': _formatDate(DateTime.now()),     // Fecha actual (o podría ser la original)
    });

    try {
      // PASO 2: Actualizar los datos básicos del gasto en el servidor
      
      // Realizar petición PUT para actualizar el gasto
      final response = await _client
          // .put() envía una petición PUT al endpoint '/expenses/{id}'
          // PUT es el método HTTP estándar para actualizar recursos existentes
          .put(
            _uri('/expenses/$id'),  // URL con el ID del gasto a actualizar
            headers: _jsonHeaders,  // Headers indicando que enviamos JSON
            body: payload,          // El JSON con los datos actualizados
          )
          // .timeout() limita el tiempo de espera
          .timeout(_timeout);
      
      // PASO 3: Verificar que la actualización fue exitosa
      // 200 (OK) = actualización exitosa con respuesta
      // 204 (No Content) = actualización exitosa sin respuesta
      if (response.statusCode != 200 && response.statusCode != 204) {
        // Si no es éxito, lanzar error HTTP
        _throwHttpError('actualizar gasto', response);
      }

      // PASO 4: Sincronizar los participantes del gasto
      // Esto es necesario porque los participantes pueden haber cambiado:
      // - Elimina participantes que ya no están en la lista
      // - Agrega nuevos participantes que no estaban antes
      // - Recalcula y redistribuye los montos entre todos los participantes
      await _sincronizarParticipantes(
        id,                      // ID del gasto a actualizar
        pagadorId: pagadorId,    // Nuevo pagador (puede ser diferente)
        deudoresIds: deudoresIds, // Nueva lista de deudores
        monto: monto,            // Nuevo monto total para redistribuir
      );

      // PASO 5: Obtener el gasto completo actualizado
      // Después de sincronizar participantes, el servidor ha recalculado todo
      // Necesitamos obtener el gasto completo para retornarlo
      return await _obtenerGasto(id);
      
    } on SocketException {
      // ERROR: No se puede conectar al servidor
      throw ApiException('El servidor no está corriendo. No se puede conectar al servidor.');
      
    } on TimeoutException {
      // ERROR: El servidor tardó demasiado en responder
      throw ApiException('El servidor tardó demasiado en responder.');
      
    } on FormatException catch (error) {
      // ERROR: Formato de datos incorrecto
      throw ApiException('Error de formato: ${error.message}');
    }
    // Nota: No hay rollback aquí porque estamos actualizando un recurso existente
    // Si falla, el gasto queda en su estado anterior (transacción atómica)
  }

  /// Elimina un gasto del servidor por su ID
  /// 
  /// Esta operación realiza una petición DELETE para eliminar permanentemente un gasto.
  /// Cuando se elimina un gasto, también se eliminan:
  /// - Todos sus participantes
  /// - Todos los saldos relacionados
  /// - El historial de ese gasto
  /// 
  /// IMPORTANTE: Esta operación es irreversible. Una vez eliminado, no se puede recuperar.
  /// El servidor debe manejar automáticamente la eliminación en cascada de todos los datos relacionados.
  /// 
  /// Parámetro [id]: ID del gasto a eliminar
  /// Retorna: void (no retorna nada, solo confirma que se eliminó)
  Future<void> deleteGasto(int id) async {
    try {
      // PASO 1: Realizar la petición DELETE al servidor
      
      // Realizar petición DELETE para eliminar el gasto
      final response = await _client
          // .delete() envía una petición DELETE a la URL especificada
          // _uri('/expenses/$id') construye la URL con el ID del gasto
          // Ejemplo: 'http://10.0.2.2:8000/expenses/5' para eliminar el gasto con ID 5
          .delete(_uri('/expenses/$id'))
          // .timeout() limita el tiempo de espera de la petición
          .timeout(_timeout);
      
      // PASO 2: Verificar que la eliminación fue exitosa
      // 204 (No Content) = recurso eliminado exitosamente, sin contenido en la respuesta
      // 200 (OK) = operación exitosa (algunas APIs retornan 200 al eliminar)
      if (response.statusCode == 204 || response.statusCode == 200) {
        // Si la eliminación fue exitosa, retornar sin hacer nada más
        // El método retorna void, así que solo confirmamos que terminó correctamente
        return;
      }
      
      // PASO 3: Si el código de estado no es 204 ni 200, lanzar error HTTP
      // Esto maneja errores como:
      // - 404 (Not Found): El gasto no existe
      // - 403 (Forbidden): No tienes permiso para eliminar
      // - 500 (Server Error): Error interno del servidor
      _throwHttpError('eliminar gasto', response);
      
    } on SocketException {
      // ERROR: No se puede conectar al servidor
      // SocketException se lanza cuando:
      // - El servidor no está corriendo
      // - No hay conexión a internet
      // - La URL es incorrecta o inalcanzable
      throw ApiException('El servidor no está corriendo. No se puede conectar al servidor.');
      
    } on TimeoutException {
      // ERROR: El servidor tardó demasiado en responder
      // TimeoutException se lanza cuando la petición tarda más que _timeout
      // Esto puede pasar si:
      // - El servidor está sobrecargado
      // - La red es lenta
      // - El servidor está procesando algo muy pesado
      throw ApiException('El servidor tardó demasiado en responder.');
    }
    // Nota: No hay manejo de FormatException aquí porque DELETE normalmente
    // no retorna cuerpo en la respuesta, solo el código de estado HTTP
    // Si el servidor retorna un cuerpo de error, se maneja en _throwHttpError()
  }

  /// Registra los participantes de un gasto y ajusta sus montos
  /// 
  /// Método auxiliar privado que realiza dos tareas importantes:
  /// 1. Registra todos los participantes (pagador y deudores) en el servidor
  /// 2. Distribuye y ajusta los montos según el rol de cada participante
  /// 
  /// Las operaciones se ejecutan en paralelo para mejorar el rendimiento:
  /// En lugar de registrar participante por participante (secuencial), se registran
  /// todos simultáneamente, lo que reduce significativamente el tiempo total.
  /// 
  /// Parámetros:
  /// - [gastoId]: ID del gasto al que pertenecen los participantes
  /// - [pagadorId]: ID del amigo que pagó el gasto
  /// - [deudoresIds]: Lista de IDs de amigos que deben parte del gasto
  /// - [monto]: Monto total del gasto a distribuir
  /// - [existentes]: Set opcional de IDs de participantes que ya están registrados
  ///                 (evita registrarlos dos veces)
  Future<void> _registrarParticipantes(
    int gastoId, {
    required int pagadorId,
    required List<int> deudoresIds,
    required double monto,
    Set<int>? existentes,
  }) async {
    // PASO 1: Determinar todos los participantes que deben estar en el gasto
    
    // Crear un Set con todos los participantes deseados
    // Set elimina duplicados automáticamente
    // {...deudoresIds, pagadorId} crea un nuevo Set con:
    // - Todos los deudores (lista)
    // - El pagador (incluido explícitamente)
    // El pagador también puede ser deudor, por eso usamos Set (elimina duplicados)
    final participantesDeseados = <int>{...deudoresIds, pagadorId};
    
    // Obtener el conjunto de participantes que ya están registrados
    // Si no se proporciona 'existentes', usar un Set vacío
    // Esto evita registrar participantes que ya existen
    final yaRegistrados = existentes ?? <int>{};

    // PASO 2: Registrar TODOS los participantes nuevos EN PARALELO
    
    // Crear una lista de Futures (operaciones asíncronas) para ejecutar en paralelo
    final futures = participantesDeseados
        // Filtrar solo los participantes que NO están ya registrados
        // .where() mantiene solo los elementos que cumplen la condición
        .where((p) => !yaRegistrados.contains(p))
        // .map() transforma cada participante en una operación asíncrona (Future)
        .map(
          (participante) => _client
              // POST para agregar un participante al gasto
              .post(
                // URL: '/expenses/{gastoId}/friends' con parámetro friend_id
                // Ejemplo: '/expenses/5/friends?friend_id=3'
                _uri('/expenses/$gastoId/friends', {'friend_id': participante}),
              )
              // Aplicar timeout a cada petición
              .timeout(_timeout)
              // .then() se ejecuta cuando la petición termina
              .then((response) {
                // Verificar que la respuesta sea exitosa
                // 200 (OK), 201 (Created), 204 (No Content) = éxito
                if (response.statusCode != 200 &&
                    response.statusCode != 201 &&
                    response.statusCode != 204) {
                  // Si no es exitoso, lanzar error HTTP
                  _throwHttpError(
                    'añadir participante $participante al gasto',
                    response,
                  );
                }
                // Si es exitoso, no hacer nada (solo verificar)
              }),
        );

    // PASO 3: Ejecutar TODAS las peticiones de registro EN PARALELO
    // Future.wait() espera a que todas las operaciones asíncronas se completen
    // Esto es mucho más rápido que hacerlo secuencialmente
    // Ejemplo: Si hay 5 participantes, en lugar de 5*200ms = 1000ms,
    //          toma aproximadamente 200ms (el tiempo del más lento)
    await Future.wait(futures);

    // PASO 4: Ajustar los montos de cada participante según su rol
    // Ahora que todos los participantes están registrados, necesitamos:
    // - Asignar el crédito al pagador (lo que le deben)
    // - Asignar el débito a los deudores (lo que deben)
    // - Distribuir el monto equitativamente entre los deudores
    await _ajustarMontosParticipantes(
      gastoId,                    // ID del gasto
      pagadorId: pagadorId,       // Quien pagó
      deudoresIds: deudoresIds,   // Quienes deben
      monto: monto,               // Monto total a distribuir
    );
  }

  /// Sincroniza los participantes de un gasto: elimina los que ya no participan y añade los nuevos
  /// 
  /// Este método es crítico cuando se actualiza un gasto porque los participantes pueden cambiar:
  /// - Se pueden haber eliminado participantes (ya no participan)
  /// - Se pueden haber agregado nuevos participantes
  /// - El pagador puede haber cambiado
  /// 
  /// Proceso de sincronización:
  /// 1. Obtener la lista actual de participantes del servidor
  /// 2. Comparar con la lista deseada (nueva)
  /// 3. Identificar participantes a eliminar (están en actual pero no en deseado)
  /// 4. Eliminar participantes que ya no participan (poner saldo a 0 y luego eliminar)
  /// 5. Agregar nuevos participantes (los que están en deseado pero no en actual)
  /// 6. Ajustar los montos de todos los participantes
  /// 
  /// Parámetros:
  /// - [gastoId]: ID del gasto a sincronizar
  /// - [pagadorId]: ID del nuevo pagador
  /// - [deudoresIds]: Nueva lista de deudores
  /// - [monto]: Nuevo monto total para redistribuir
  Future<void> _sincronizarParticipantes(
    int gastoId, {
    required int pagadorId,
    required List<int> deudoresIds,
    required double monto,
  }) async {
    // PASO 1: Obtener la lista actual de participantes desde el servidor
    // Esto nos permite comparar qué ha cambiado
    final actuales = await _obtenerParticipantesIds(gastoId);
    
    // PASO 2: Crear el conjunto de participantes deseados (nuevos)
    // Set elimina duplicados automáticamente
    final deseados = <int>{...deudoresIds, pagadorId};
    
    // PASO 3: Identificar participantes que deben eliminarse
    // Son los que están en 'actuales' pero NO están en 'deseados'
    // .where() filtra solo los que cumplen la condición
    final participantesAEliminar = actuales.where((p) => !deseados.contains(p));

    // PASO 4: Primero, poner el saldo a 0 para los participantes a eliminar
    // Esto se hace ANTES de eliminar para mantener consistencia en los saldos
    // Las operaciones se ejecutan EN PARALELO para mejor rendimiento
    
    // Crear lista de Futures para actualizar montos en paralelo
    final actualizacionesFutures = participantesAEliminar.map(
      // Para cada participante a eliminar, actualizar su monto a 0
      (participante) => _actualizarMontoParticipante(gastoId, participante, 0),
    );
    // Ejecutar todas las actualizaciones simultáneamente
    await Future.wait(actualizacionesFutures);

    // PASO 5: Ahora sí, eliminar los participantes del gasto
    // Se eliminan DESPUÉS de poner los saldos a 0 para mantener consistencia
    
    // Crear lista de Futures para eliminar participantes en paralelo
    final eliminacionesFutures = participantesAEliminar.map(
      (participante) => _client
          // DELETE para eliminar un participante del gasto
          .delete(_uri('/expenses/$gastoId/friends/$participante'))
          // Aplicar timeout
          .timeout(_timeout)
          // .then() se ejecuta cuando la petición termina
          .then((response) {
            // Verificar que la eliminación fue exitosa
            if (response.statusCode != 200 && response.statusCode != 204) {
              // Si falla, lanzar error HTTP
              _throwHttpError('eliminar participante $participante', response);
            }
          }),
    );
    // Ejecutar todas las eliminaciones simultáneamente
    await Future.wait(eliminacionesFutures);

    // PASO 6: Identificar participantes que ya existen y se mantienen
    // Son los que están tanto en 'actuales' como en 'deseados'
    // .where() filtra los que están en 'deseados' (usando .contains())
    // .toSet() convierte a Set para evitar duplicados
    final existentes = actuales.where(deseados.contains).toSet();

    // PASO 7: Registrar los nuevos participantes y ajustar montos
    // _registrarParticipantes() solo agrega participantes nuevos (no los existentes)
    // y luego ajusta los montos de todos según el nuevo monto total
    await _registrarParticipantes(
      gastoId,                    // ID del gasto
      pagadorId: pagadorId,       // Nuevo pagador
      deudoresIds: deudoresIds,   // Nueva lista de deudores
      monto: monto,               // Nuevo monto total
      existentes: existentes,     // Participantes que ya existen (no volver a registrar)
    );
  }

  /// Calcula y actualiza los montos de cada participante según su rol
  /// 
  /// Este método implementa la lógica de negocio para distribuir un gasto entre participantes.
  /// 
  /// Lógica de distribución:
  /// - **Pagador**: Recibe crédito (lo que le deben). Si también es deudor, recibe menos crédito.
  /// - **Deudores**: Reciben débito negativo (lo que deben). El monto se divide equitativamente.
  /// 
  /// Casos especiales:
  /// 1. Si no hay deudores: El pagador recibe todo el monto como crédito
  /// 2. Si el pagador también es deudor: Recibe crédito pero también debe su parte
  /// 
  /// Parámetros:
  /// - [gastoId]: ID del gasto
  /// - [pagadorId]: ID del amigo que pagó
  /// - [deudoresIds]: Lista de IDs de amigos que deben parte
  /// - [monto]: Monto total del gasto a distribuir
  Future<void> _ajustarMontosParticipantes(
    int gastoId, {
    required int pagadorId,
    required List<int> deudoresIds,
    required double monto,
  }) async {
    // VALIDACIÓN 1: Si el monto es 0 o negativo, no hay nada que distribuir
    if (monto <= 0) return;

    // CASO ESPECIAL 1: Si no hay deudores, el pagador recibe todo el monto
    // Ejemplo: Gasto de 100€, solo el pagador → recibe 100€ de crédito
    if (deudoresIds.isEmpty) {
      // Actualizar el pagador con todo el monto como crédito
      await _actualizarMontoParticipante(gastoId, pagadorId, monto);
      return; // Terminar aquí, no hay más que hacer
    }

    // CALCULAR LA DISTRIBUCIÓN DEL MONTO
    
    // Contar cuántos deudores hay
    final cantidadDeudores = deudoresIds.length;
    
    // Dividir el monto total entre todos los deudores de forma equitativa
    // Ejemplo: 100€ entre 4 deudores = 25€ cada uno
    final montoPorDeudor = monto / cantidadDeudores;
    
    // Verificar si el pagador también está en la lista de deudores
    // Esto puede pasar: alguien paga pero también debe su parte
    final pagadorEsDeudor = deudoresIds.contains(pagadorId);

    // Calcular el crédito del pagador:
    // - Si el pagador también es deudor: recibe monto total MENOS su parte como deudor
    //   Ejemplo: Pagó 100€, pero debe 25€ → crédito = 100 - 25 = 75€
    // - Si el pagador NO es deudor: recibe todo el monto total
    //   Ejemplo: Pagó 100€, no debe nada → crédito = 100€
    final creditoPagador = pagadorEsDeudor ? monto - montoPorDeudor : monto;

    // PASO 1: Preparar todas las actualizaciones a realizar
    
    // Crear lista vacía para almacenar todas las operaciones asíncronas
    final futures = <Future<void>>[];

    // PASO 2: Agregar la actualización del pagador
    // El pagador recibe crédito positivo (lo que le deben)
    futures.add(
      _actualizarMontoParticipante(gastoId, pagadorId, creditoPagador),
    );

    // PASO 3: Agregar las actualizaciones de todos los deudores
    // Iterar sobre cada deudor en la lista
    for (final deudorId in deudoresIds) {
      // Si el pagador también es deudor y este es el pagador, saltarlo
      // (ya se actualizó arriba con el crédito calculado)
      if (pagadorEsDeudor && deudorId == pagadorId) {
        continue; // Saltar esta iteración, ir al siguiente
      }
      
      // Agregar la actualización del deudor
      // Los deudores reciben débito negativo (lo que deben)
      // El signo negativo indica que deben dinero
      futures.add(
        _actualizarMontoParticipante(gastoId, deudorId, -montoPorDeudor),
      );
    }

    // PASO 4: Ejecutar TODAS las actualizaciones EN PARALELO
    // Future.wait() ejecuta todas las operaciones simultáneamente
    // Esto es mucho más rápido que hacerlo una por una
    await Future.wait(futures);
  }

  /// Actualiza el monto de un participante en un gasto específico
  /// 
  /// Método auxiliar privado que actualiza el monto (amount) de un participante en un gasto.
  /// Este método se usa para:
  /// - Asignar créditos a los pagadores (monto positivo)
  /// - Asignar débitos a los deudores (monto negativo)
  /// - Poner saldos a 0 cuando se elimina un participante
  /// 
  /// Parámetros:
  /// - [gastoId]: ID del gasto al que pertenece el participante
  /// - [friendId]: ID del amigo (participante) cuyo monto se va a actualizar
  /// - [amount]: Nuevo monto para el participante
  ///             - Positivo = crédito (le deben dinero)
  ///             - Negativo = débito (debe dinero)
  ///             - Cero = sin saldo
  Future<void> _actualizarMontoParticipante(
    int gastoId,
    int friendId,
    double amount,
  ) async {
    // Realizar petición PUT para actualizar el monto del participante
    await _client
        // .put() envía una petición PUT al endpoint específico del participante
        // _uri() construye la URL con parámetros de consulta
        // Ejemplo: '/expenses/5/friends/3?amount=25.0'
        .put(
          _uri(
            '/expenses/$gastoId/friends/$friendId',
            {'amount': amount}, // Parámetro de consulta con el nuevo monto
          ),
        )
        // .timeout() limita el tiempo de espera
        .timeout(_timeout)
        // .then() se ejecuta cuando la petición termina
        .then((response) {
          // Verificar que la actualización fue exitosa
          // 200 (OK) = actualización exitosa con respuesta
          // 204 (No Content) = actualización exitosa sin respuesta
          if (response.statusCode != 200 && response.statusCode != 204) {
            // Si no es exitoso, lanzar error HTTP con mensaje descriptivo
            _throwHttpError(
              'asignar importe al participante $friendId',
              response,
            );
          }
          // Si es exitoso, no hacer nada más (solo verificar)
        });
  }

  /// Obtiene la lista de IDs de participantes de un gasto
  /// 
  /// Método auxiliar privado que obtiene solo los IDs de los participantes de un gasto.
  /// La API puede retornar los participantes en diferentes formatos:
  /// - Lista simple de números: [1, 2, 3]
  /// - Lista de objetos: [{'friend_id': 1}, {'id': 2}, ...]
  /// 
  /// Este método maneja ambos casos y extrae siempre los IDs.
  /// 
  /// Parámetro [gastoId]: ID del gasto del que obtener los participantes
  /// Retorna: Lista de IDs (números) de los participantes
  Future<List<int>> _obtenerParticipantesIds(int gastoId) async {
    // Realizar petición GET para obtener los participantes del gasto
    final response = await _client
        // GET al endpoint '/expenses/{gastoId}/friends/'
        // Ejemplo: '/expenses/5/friends/' para obtener participantes del gasto 5
        .get(_uri('/expenses/$gastoId/friends/'))
        // Aplicar timeout
        .timeout(_timeout);
    
    // Verificar que la petición fue exitosa
    if (response.statusCode == 200) {
      // Decodificar el JSON recibido
      final data = jsonDecode(response.body);
      
      // Verificar que los datos sean una lista
      if (data is List) {
        // Extraer los IDs de los participantes
        // La API puede retornar diferentes formatos, así que manejamos ambos:
        return data
            .map(
              // Para cada elemento en la lista, extraer el ID
              (element) => switch (element) {
                // CASO 1: Si el elemento ya es un número (int), usarlo directamente
                int value => value,
                
                // CASO 2: Si el elemento es un objeto (Map), extraer el ID del objeto
                Map<String, dynamic> map =>
                  // Intentar primero obtener 'friend_id', si no existe, intentar 'id'
                  // Si ninguno existe o es null, usar 0
                  map['friend_id'] as int? ?? map['id'] as int? ?? 0,
                
                // CASO 3: Cualquier otro tipo, retornar 0 (se filtrará después)
                _ => 0,
              },
            )
            // Filtrar los valores que son 0 (elementos inválidos o no convertidos)
            .where((value) => value != 0)
            // Convertir el Iterable a List
            .toList();
      }
      // Si los datos no son una lista, lanzar excepción de formato
      throw const FormatException(
        'Formato inesperado al obtener participantes.',
      );
    }
    // Si el código de estado no es 200, lanzar error HTTP
    _throwHttpError('obtener participantes', response);
    // Esta línea nunca se alcanza (por el throw), pero el compilador lo requiere
    return const <int>[];
  }

  /// Obtiene los detalles completos de un participante en un gasto
  /// 
  /// Método auxiliar privado que obtiene toda la información de un participante específico
  /// en un gasto, incluyendo sus balances (credit_balance, debit_balance).
  /// 
  /// Esta información se usa para:
  /// - Determinar quién es el pagador (tiene crédito positivo)
  /// - Determinar quiénes son los deudores (tienen crédito negativo o débito positivo)
  /// - Calcular los saldos correctos
  /// 
  /// Parámetros:
  /// - [gastoId]: ID del gasto
  /// - [friendId]: ID del amigo (participante) del que obtener detalles
  /// 
  /// Retorna: Map con todos los datos del participante (credit_balance, debit_balance, etc.)
  Future<Map<String, dynamic>> _obtenerParticipanteDetalle(
    int gastoId,
    int friendId,
  ) async {
    // Realizar petición GET para obtener los detalles del participante
    final response = await _client
        // GET al endpoint específico del participante en el gasto
        // Ejemplo: '/expenses/5/friends/3' para obtener detalles del amigo 3 en el gasto 5
        .get(_uri('/expenses/$gastoId/friends/$friendId'))
        // Aplicar timeout
        .timeout(_timeout);
    
    // Verificar que la petición fue exitosa
    if (response.statusCode == 200) {
      // Decodificar el JSON recibido
      final data = jsonDecode(response.body);
      
      // Verificar que los datos sean un objeto (Map)
      if (data is Map<String, dynamic>) {
        // Retornar el Map con los detalles del participante
        return data;
      }
      // Si los datos no son un Map, lanzar excepción de formato
      throw const FormatException(
        'Formato inesperado al obtener detalle del participante.',
      );
    }
    // Si el código de estado no es 200, lanzar error HTTP
    _throwHttpError('obtener detalle del participante', response);
    // Esta línea nunca se alcanza (por el throw), pero el compilador lo requiere
    return const <String, dynamic>{};
  }

  /// Obtiene un gasto completo desde el servidor (incluye participantes)
  /// 
  /// Método auxiliar privado que obtiene un gasto completo con todos sus datos.
  /// A diferencia de obtener solo los datos básicos, este método:
  /// - Obtiene los datos básicos del gasto
  /// - Obtiene todos los participantes y sus detalles
  /// - Detecta automáticamente quién es el pagador
  /// - Calcula quiénes son los deudores
  /// - Retorna un objeto Gasto completo y listo para usar
  /// 
  /// Parámetro [id]: ID del gasto a obtener
  /// Retorna: Objeto Gasto completo con todos sus participantes y datos calculados
  Future<Gasto> _obtenerGasto(int id) async {
    // Realizar petición GET para obtener el gasto
    final response = await _client
        // GET al endpoint '/expenses/{id}'
        // Ejemplo: '/expenses/5' para obtener el gasto con ID 5
        .get(_uri('/expenses/$id'))
        // Aplicar timeout
        .timeout(_timeout);
    
    // Verificar que la petición fue exitosa
    if (response.statusCode == 200) {
      // Decodificar el JSON recibido
      final data = jsonDecode(response.body);
      
      // Verificar que los datos sean un objeto (Map)
      if (data is Map<String, dynamic>) {
        // Usar _mapGasto() para convertir el JSON a un objeto Gasto completo
        // _mapGasto() es más complejo porque también obtiene participantes y calcula roles
        return _mapGasto(data);
      }
      // Si los datos no son un Map, lanzar excepción de formato
      throw const FormatException('Formato inesperado al obtener gasto.');
    }
    // Si el código de estado no es 200, lanzar error HTTP
    _throwHttpError('obtener gasto', response);
    // Si llegamos aquí, algo salió mal
    throw ApiException('No se pudo obtener el gasto.');
  }

  /// Obtiene un amigo desde el servidor por su ID
  /// 
  /// Método auxiliar privado que obtiene los datos completos de un amigo específico.
  /// Se usa cuando necesitamos obtener un amigo actualizado después de una operación
  /// (ej: después de pagar saldo, después de actualizar, etc.)
  /// 
  /// Parámetro [id]: ID del amigo a obtener
  /// Retorna: Objeto Amigo con todos sus datos actualizados (incluyendo saldos)
  Future<Amigo> _obtenerAmigo(int id) async {
    // Realizar petición GET para obtener el amigo
    final response = await _client
        // GET al endpoint '/friends/{id}'
        // Ejemplo: '/friends/5' para obtener el amigo con ID 5
        .get(_uri('/friends/$id'))
        // Aplicar timeout
        .timeout(_timeout);
    
    // Verificar que la petición fue exitosa
    if (response.statusCode == 200) {
      // Decodificar el JSON recibido
      final data = jsonDecode(response.body);
      
      // Verificar que los datos sean un objeto (Map)
      if (data is Map<String, dynamic>) {
        // Convertir el JSON a un objeto Amigo usando el factory constructor
        // fromJson() crea una instancia de Amigo desde los datos JSON
        return Amigo.fromJson(data);
      }
      // Si los datos no son un Map, lanzar excepción de formato
      throw const FormatException('Formato inesperado al obtener amigo.');
    }
    // Si el código de estado no es 200, lanzar error HTTP
    _throwHttpError('obtener amigo', response);
    // Si llegamos aquí, algo salió mal
    throw ApiException('No se pudo obtener el amigo.');
  }

  /// Mapea los datos JSON de un gasto a un objeto Gasto completo
  /// 
  /// Este es uno de los métodos más complejos. Convierte los datos JSON básicos del gasto
  /// en un objeto Gasto completo con toda la información necesaria:
  /// - Detecta automáticamente quién es el pagador basándose en los balances
  /// - Identifica quiénes son los deudores
  /// - Obtiene todos los participantes y sus detalles
  /// - Calcula el número total de participantes
  /// 
  /// La detección del pagador se hace analizando los credit_balance de cada participante:
  /// - Si credit_balance > 0: tiene crédito (es pagador o le deben)
  /// - Si credit_balance < 0: tiene débito (es deudor)
  /// 
  /// Parámetro [data]: Map con los datos JSON básicos del gasto del servidor
  /// Retorna: Objeto Gasto completo con todos los datos y participantes calculados
  Future<Gasto> _mapGasto(Map<String, dynamic> data) async {
    // PASO 1: Extraer el ID del gasto de los datos JSON
    final id = data['id'] as int;
    
    // PASO 2: Obtener la lista de IDs de todos los participantes del gasto
    // Esto nos dice qué amigos están involucrados en este gasto
    final participantes = await _obtenerParticipantesIds(id);

    // PASO 3: Intentar obtener el pagador desde los datos JSON
    // El servidor puede proporcionar 'pagador_id' directamente
    int pagadorId = data['pagador_id'] as int? ?? 0;
    
    // Variable para almacenar el pagador detectado (puede ser diferente al del JSON)
    // Si pagadorId es 0, no se proporcionó, así que será null y lo detectaremos
    int? pagadorDetectado = pagadorId != 0 ? pagadorId : null;
    
    // Lista para almacenar los IDs de los deudores (se llenará después)
    final List<int> deudores = <int>[];

    // PASO 4: Obtener detalles de TODOS los participantes EN PARALELO
    // Esto es más eficiente que obtenerlos uno por uno
    
    // Crear una lista de Futures: una operación asíncrona por cada participante
    final detallesFutures = participantes.map(
      // Para cada participante, obtener sus detalles completos
      (participanteId) => _obtenerParticipanteDetalle(id, participanteId),
    );
    
    // Ejecutar todas las peticiones de detalles en paralelo
    // Future.wait() espera a que todas terminen y retorna una lista con los resultados
    final detalles = await Future.wait(detallesFutures);

    // PASO 5: Procesar los detalles para identificar pagador y deudores
    // Iterar sobre cada participante junto con sus detalles
    for (var i = 0; i < participantes.length; i++) {
      // Obtener el ID del participante en esta posición
      final participanteId = participantes[i];
      
      // Obtener los detalles del participante en la misma posición
      final detalle = detalles[i];
      
      // Extraer el credit_balance (lo que le deben al participante)
      final credit = _toDouble(detalle['credit_balance']);

      // Análisis del crédito para determinar el rol:
      
      // CASO 1: credit < 0 → Es deudor (debe dinero)
      // Agregarlo a la lista de deudores
      if (credit < 0) {
        deudores.add(participanteId);
      } 
      // CASO 2: credit > 0 → Tiene crédito (es pagador o le deben)
      else if (credit > 0) {
        // Si aún no se detectó un pagador, o si este es el pagador del JSON
        if (pagadorDetectado == null || participanteId == pagadorId) {
          // Este es el pagador (tiene el crédito más alto o coincide con pagador_id)
          pagadorDetectado = participanteId;
        }
      }
      // CASO 3: credit == 0 → No tiene saldo (raro pero posible)
      // No hacer nada, no es ni pagador ni deudor
    }

    // PASO 6: Determinar el pagador final
    // Prioridad:
    // 1. Usar el pagador detectado (si se encontró)
    // 2. Si no se detectó ninguno pero hay participantes, usar el primero
    // 3. Si no hay participantes, usar 0 (inválido)
    pagadorId =
        pagadorDetectado ??
        (participantes.isNotEmpty ? participantes.first : 0);

    // PASO 7: Crear el objeto Gasto completo
    // Primero crear el Gasto desde JSON con los deudores identificados
    return Gasto.fromJson(
      data,                      // Datos básicos del gasto
      deudoresIds: deudores,     // Lista de deudores identificados
    )
    // Luego usar copyWith() para actualizar el pagador y número de participantes
    // Esto es necesario porque fromJson() puede no tener estos datos correctos
    .copyWith(
      pagadorId: pagadorId,                    // Pagador detectado o del JSON
      numParticipantes: participantes.length,  // Número total de participantes
    );
  }

  /// Elimina un gasto en caso de error durante su creación (rollback)
  /// 
  /// Este método implementa la lógica de rollback (reversión) para mantener la consistencia
  /// de los datos. Si algo falla durante la creación de un gasto (ej: falla al registrar
  /// participantes), este método elimina el gasto creado para evitar datos inconsistentes.
  /// 
  /// IMPORTANTE: Los errores de rollback se ignoran silenciosamente. Si el rollback falla,
  /// puede quedar un gasto huérfano, pero es mejor que tener datos completamente inconsistentes.
  /// 
  /// Parámetro [gastoId]: ID del gasto a eliminar (puede ser null si no se creó)
  /// Retorna: void (no retorna nada)
  Future<void> _rollbackGasto(int? gastoId) async {
    // Si el gastoId es null, significa que el gasto nunca se creó
    // No hay nada que revertir, así que terminar aquí
    if (gastoId == null) return;
    
    try {
      // Intentar eliminar el gasto creado
      // Esto revierte la creación y mantiene la consistencia
      await _client
          // DELETE para eliminar el gasto
          .delete(_uri('/expenses/$gastoId'))
          // Aplicar timeout
          .timeout(_timeout);
      
      // Si la eliminación fue exitosa, el rollback se completó
    } catch (_) {
      // Ignorar todos los errores de rollback silenciosamente
      // El parámetro '_' indica que no usamos la información del error
      // 
      // Razones para ignorar errores de rollback:
      // - El gasto puede no existir (ya fue eliminado)
      // - Puede haber problemas de conexión
      // - Es mejor tener un gasto huérfano que datos completamente inconsistentes
      // - El usuario ya recibió el error de la operación original
    }
  }

  /// Headers HTTP para peticiones JSON
  /// 
  /// Getter que retorna los headers necesarios para enviar datos JSON al servidor.
  /// 
  /// 'Content-Type: application/json' le indica al servidor que estamos enviando
  /// datos en formato JSON, lo que permite que el servidor los interprete correctamente.
  /// 
  /// Es 'const' porque el valor nunca cambia (siempre es el mismo)
  /// Es un getter para que se pueda acceder como propiedad sin usar paréntesis
  /// 
  /// Ejemplo de uso:
  /// ```dart
  /// headers: _jsonHeaders  // En lugar de escribir el Map completo cada vez
  /// ```
  Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json', // Indica que enviamos JSON
  };

  /// Convierte un código de estado HTTP en una excepción ApiException con mensaje descriptivo
  /// 
  /// Este método centraliza el manejo de errores HTTP, convirtiendo códigos numéricos
  /// en mensajes de error amigables y descriptivos para el usuario.
  /// 
  /// Parámetros:
  /// - [accion]: Descripción de la acción que se intentaba realizar (ej: "añadir amigo")
  /// - [response]: Objeto Response HTTP que contiene el código de estado y detalles
  /// 
  /// Lanza: ApiException con un mensaje descriptivo del error
  void _throwHttpError(String accion, http.Response response) {
    // Extraer el código de estado HTTP de la respuesta
    // Ejemplos: 200 (OK), 400 (Bad Request), 404 (Not Found), 500 (Server Error)
    final status = response.statusCode;
    
    // Extraer detalles adicionales del cuerpo de la respuesta (si existe)
    // El servidor puede enviar mensajes de error más específicos en el cuerpo
    // isNotEmpty verifica que el string no esté vacío
    final detalle = response.body.isNotEmpty ? response.body : null;

    // Determinar el mensaje de error según el código de estado HTTP
    // switch-case permite manejar diferentes casos de forma clara
    String mensaje;
    switch (status) {
      case 400:
        // 400 Bad Request: Los datos enviados son inválidos o incorrectos
        // Ejemplo: Falta un campo requerido, formato incorrecto
        mensaje = 'Datos inválidos.';
        break;
      case 404:
        // 404 Not Found: El recurso solicitado no existe
        // Ejemplo: Intentar eliminar un amigo que ya no existe
        mensaje = 'Recurso no encontrado.';
        break;
      case 409:
        // 409 Conflict: Hay un conflicto con el estado actual
        // Ejemplo: Intentar crear un recurso que ya existe
        mensaje = 'Conflicto con el estado actual.';
        break;
      case 500:
        // 500 Internal Server Error: Error interno del servidor
        // Esto es un error del servidor, no de la aplicación cliente
        mensaje = 'Error interno del servidor.';
        break;
      case 503:
        // 503 Service Unavailable: El servicio no está disponible temporalmente
        // Ejemplo: El servidor está en mantenimiento o sobrecargado
        mensaje = 'Servicio no disponible. Intenta más tarde.';
        break;
      default:
        // Cualquier otro código de estado HTTP no manejado específicamente
        // Ejemplos: 401 (Unauthorized), 403 (Forbidden), 502 (Bad Gateway), etc.
        mensaje = 'Error HTTP $status.';
    }

    // Si hay detalles adicionales del servidor, agregarlos al mensaje
    // Esto proporciona información más específica sobre el error
    if (detalle != null) {
      mensaje = '$mensaje Detalles: $detalle';
    }

    // Lanzar la excepción personalizada con el mensaje completo
    // El mensaje incluye: acción + mensaje genérico + detalles (si existen)
    throw ApiException('Error al $accion: $mensaje');
  }

  /// Decodifica un cuerpo JSON a un mapa
  /// 
  /// Método auxiliar privado que convierte un string JSON a un Map de Dart.
  /// También valida que el JSON sea un objeto (Map) y no otro tipo (List, String, etc.)
  /// 
  /// Parámetro [body]: String con el JSON a decodificar
  /// Retorna: Map con los datos del JSON
  /// Lanza: FormatException si el JSON no es un objeto
  Map<String, dynamic> _decodeMap(String body) {
    // Decodificar el string JSON a un objeto Dart
    // jsonDecode() puede retornar diferentes tipos: Map, List, String, número, etc.
    final data = jsonDecode(body);
    
    // Verificar que los datos decodificados sean un Map (objeto JSON)
    // Un Map representa un objeto JSON: {"key": "value"}
    if (data is Map<String, dynamic>) {
      // Si es un Map, retornarlo directamente
      return data;
    }
    // Si no es un Map (es List, String, número, etc.), lanzar excepción
    // Esto previene errores más adelante cuando intentemos acceder a las claves
    throw const FormatException('Se esperaba un objeto JSON.');
  }

  /// Formatea una fecha al formato YYYY-MM-DD requerido por la API
  /// 
  /// Método estático privado que convierte un objeto DateTime a string en formato ISO.
  /// El formato YYYY-MM-DD es común en APIs REST.
  /// 
  /// Ejemplo: DateTime(2024, 1, 15) → "2024-01-15"
  /// 
  /// Parámetro [date]: Objeto DateTime a formatear
  /// Retorna: String con la fecha en formato YYYY-MM-DD
  static String _formatDate(DateTime date) =>
      // Construir el string concatenando año, mes y día con guiones
      '${date.year.toString().padLeft(4, '0')}-'     // Año con 4 dígitos (rellenar con 0s si es necesario)
      '${date.month.toString().padLeft(2, '0')}-'    // Mes con 2 dígitos (ej: "01", "12")
      '${date.day.toString().padLeft(2, '0')}';      // Día con 2 dígitos (ej: "01", "31")
      // padLeft(n, '0') rellena con ceros a la izquierda si el número tiene menos dígitos
      // Ejemplo: 5 → "05", 15 → "15"
      // Esto asegura que siempre tengamos el formato correcto YYYY-MM-DD

  /// Convierte un valor dinámico a double de forma segura (retorna 0 si falla)
  /// 
  /// Método auxiliar estático privado que maneja conversiones de tipos de forma robusta.
  /// El JSON puede contener números como int, double, o incluso como String.
  /// Este método maneja todos los casos y nunca lanza excepciones.
  /// 
  /// Parámetro [value]: Valor a convertir (puede ser null, int, double, String, etc.)
  /// Retorna: double (0 si no se puede convertir)
  /// 
  /// Casos manejados:
  /// - null → 0
  /// - double → retorna el valor directamente
  /// - int → convierte a double
  /// - String → intenta parsear, si falla retorna 0
  /// - Otro tipo → retorna 0
  static double _toDouble(Object? value) {
    // CASO 1: Si es null, retornar 0
    // null significa que el valor no existe o no fue proporcionado
    if (value == null) return 0;
    
    // CASO 2: Si ya es double, retornarlo directamente
    // No necesita conversión, ya es el tipo correcto
    if (value is double) return value;
    
    // CASO 3: Si es int, convertirlo a double
    // int y double son tipos numéricos compatibles
    // Ejemplo: 5 (int) → 5.0 (double)
    if (value is int) return value.toDouble();
    
    // CASO 4: Si es String, intentar parsearlo como número
    // El JSON puede venir con números como strings: "100.5"
    if (value is String) {
      // double.tryParse() intenta convertir el string a double
      // - Si tiene éxito, retorna el número como double
      // - Si falla (string inválido), retorna null
      // ?? 0 significa: si es null, usar 0
      return double.tryParse(value) ?? 0;
    }
    
    // CASO 5: Cualquier otro tipo (bool, List, Map, etc.)
    // No se puede convertir a double, retornar 0
    return 0;
  }
}

// ============================================================================
// CLASE: ApiException - Excepción personalizada para errores de la API
// ============================================================================

/// Excepción personalizada para errores de la API
/// 
/// Esta clase permite manejar errores de forma consistente en toda la aplicación.
/// Implementa la interfaz Exception de Dart, lo que permite usar try-catch normalmente.
/// 
/// Ventajas sobre usar Exception genérico:
/// - Mensajes de error más descriptivos y amigables para el usuario
/// - Permite diferenciar tipos de errores (servidor no disponible, timeout, etc.)
/// - Facilita el manejo de errores en la UI (mostrar mensajes apropiados)
class ApiException implements Exception {
  /// Constructor que recibe el mensaje de error
  /// 
  /// 'const' permite crear instancias constantes, lo que mejora el rendimiento
  const ApiException(this.message);
  
  /// Mensaje descriptivo del error que se mostrará al usuario
  final String message;

  /// Método que se llama cuando se convierte la excepción a String
  /// 
  /// Se usa cuando se imprime o muestra el error:
  /// ```dart
  /// catch (e) {
  ///   print(e); // Llama automáticamente a toString()
  /// }
  /// ```
  @override
  String toString() => message;

  /// Verifica si este error es debido a que el servidor no está disponible
  /// 
  /// Este getter es muy útil para la UI porque permite:
  /// - Mostrar mensajes diferentes según el tipo de error
  /// - Ofrecer opciones específicas (ej: "Reintentar conexión")
  /// - Evitar mostrar múltiples errores del mismo tipo
  /// 
  /// Retorna true si el mensaje contiene palabras clave relacionadas con:
  /// - Servidor no corriendo
  /// - Problemas de conexión
  /// - Errores de red (DNS, conexión rechazada, etc.)
  bool get isServerUnavailable {
    // Convertir a minúsculas para comparación case-insensitive
    final msg = message.toLowerCase();
    
    // Verificar si el mensaje contiene alguna de estas frases clave
    return msg.contains('servidor no está corriendo') ||
        msg.contains('no se puede conectar') ||
        msg.contains('servidor no disponible') ||
        msg.contains('connection refused') ||      // Error común de conexión rechazada
        msg.contains('failed host lookup') ||      // Error de DNS (no encuentra el servidor)
        msg.contains('network is unreachable');    // Sin conexión de red
  }
}
