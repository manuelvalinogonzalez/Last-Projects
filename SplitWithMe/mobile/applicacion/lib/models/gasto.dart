/// Modelo de datos que representa un gasto compartido entre amigos
/// 
/// Un gasto tiene:
/// - Un pagador (quien pagó el gasto)
/// - Una lista de deudores (quienes deben parte del gasto)
/// - Un monto total y la distribución entre participantes
class Gasto {
  /// Constructor que crea una instancia de Gasto
  /// 
  /// Parámetros:
  /// - [id]: Identificador único del gasto
  /// - [descripcion]: Descripción del gasto (ej: "Cena en restaurante")
  /// - [monto]: Cantidad total del gasto
  /// - [fecha]: Fecha en que se realizó el gasto
  /// - [pagadorId]: ID del amigo que pagó el gasto
  /// - [deudoresIds]: Lista de IDs de amigos que deben parte del gasto
  /// - [creditBalance]: Saldo a favor (por defecto 0)
  /// - [numParticipantes]: Número total de participantes (por defecto 0)
  Gasto({
    required this.id,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    required this.pagadorId,
    required List<int> deudoresIds,
    this.creditBalance = 0,
    this.numParticipantes = 0,
  }) : deudoresIds = List<int>.unmodifiable(deudoresIds);
  // La lista de inicialización (después de ':') se ejecuta ANTES del cuerpo del constructor
  // List.unmodifiable() convierte la lista mutable recibida en una lista de solo lectura
  // Esto previene que alguien modifique la lista desde fuera después de crear el Gasto

  /// Identificador único del gasto en el sistema
  final int id;
  
  /// Descripción del gasto (ej: "Cena", "Gasolina", "Supermercado")
  final String descripcion;
  
  /// Monto total del gasto
  final double monto;
  
  /// Fecha en que se realizó el gasto
  final DateTime fecha;
  
  /// ID del amigo que pagó el gasto (el pagador)
  final int pagadorId;
  
  /// Lista inmutable de IDs de amigos que deben parte del gasto
  /// Esta lista está protegida contra modificaciones externas gracias a unmodifiable()
  final List<int> deudoresIds;
  
  /// Saldo a favor relacionado con este gasto
  final double creditBalance;
  
  /// Número total de participantes en el gasto (incluyendo pagador y deudores)
  final int numParticipantes;

  /// Calcula cuánto debe pagar cada participante del gasto
  /// 
  /// La fórmula es: monto total / número de participantes
  /// 
  /// Retorna:
  /// - El monto que cada persona debe pagar si hay participantes
  /// - 0 si no hay participantes (evita división por cero)
  /// 
  /// El operador ternario '? :' funciona como un if-else:
  /// condición ? valor_si_verdadero : valor_si_falso
  double get montoPorPersona =>
      numParticipantes == 0 ? 0 : monto / numParticipantes;

  /// Crea una copia del gasto con los campos especificados modificados
  /// 
  /// Sigue el mismo patrón que Amigo.copyWith()
  /// Útil para actualizar un gasto sin modificar la instancia original
  Gasto copyWith({
    int? id,
    String? descripcion,
    double? monto,
    DateTime? fecha,
    int? pagadorId,
    List<int>? deudoresIds,
    double? creditBalance,
    int? numParticipantes,
  }) {
    return Gasto(
      id: id ?? this.id,
      descripcion: descripcion ?? this.descripcion,
      monto: monto ?? this.monto,
      fecha: fecha ?? this.fecha,
      pagadorId: pagadorId ?? this.pagadorId,
      // Si se proporciona una nueva lista, se usa; si no, se mantiene la original
      deudoresIds: deudoresIds ?? this.deudoresIds,
      creditBalance: creditBalance ?? this.creditBalance,
      numParticipantes: numParticipantes ?? this.numParticipantes,
    );
  }

  /// Constructor factory que crea un Gasto desde un objeto JSON recibido de la API
  /// 
  /// Parámetros:
  /// - [json]: Objeto JSON recibido del servidor
  /// - [deudoresIds]: Lista opcional de IDs de deudores (si no viene en el JSON)
  /// 
  /// Este método:
  /// - Parsea la fecha desde string ISO 8601
  /// - Convierte los valores numéricos de forma segura
  /// - Maneja casos donde los datos pueden faltar o ser null
  factory Gasto.fromJson(Map<String, dynamic> json, {List<int>? deudoresIds}) {
    // Extraer la fecha como string desde el JSON
    final fechaStr = json['date'] as String?;
    // Intentar parsear la fecha, si falla retorna null
    final parsedFecha = fechaStr != null ? DateTime.tryParse(fechaStr) : null;
    
    return Gasto(
      id: json['id'] as int,
      descripcion: json['description'] as String? ?? '',
      monto: _toDouble(json['amount']),
      // Si no se pudo parsear la fecha, usar la fecha actual
      fecha: parsedFecha ?? DateTime.now(),
      pagadorId: json['pagador_id'] as int? ?? 0,
      // Si no se proporciona deudoresIds, usar una lista vacía
      deudoresIds: deudoresIds ?? <int>[],
      creditBalance: _toDouble(json['credit_balance']),
      // Número de participantes: primero intenta del JSON, luego del tamaño de deudoresIds
      numParticipantes:
          json['num_friends'] as int? ??
          (deudoresIds != null ? deudoresIds.length : 0),
    );
  }

  /// Convierte el Gasto a formato JSON para enviar a la API
  /// 
  /// Convierte todos los campos al formato esperado por el servidor:
  /// - Fecha se convierte a string ISO 8601
  /// - Nombres de campos en snake_case (formato de la API)
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'description': descripcion,
      'amount': monto,
      // Convierte la fecha a formato ISO 8601 (ej: "2024-01-15T10:30:00.000Z")
      'date': fecha.toIso8601String(),
      'pagador_id': pagadorId,
      'num_friends': numParticipantes,
      'deudores': deudoresIds,
    };
  }

  /// Método auxiliar privado que convierte valores a double de forma segura
  /// 
  /// Maneja diferentes tipos que pueden venir del JSON:
  /// - null → 0
  /// - double → valor directo
  /// - int → convierte a double
  /// - String → intenta parsear como número
  /// - Otro tipo → 0
  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
