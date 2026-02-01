/// Modelo de datos que representa un amigo en el sistema de gastos compartidos
/// 
/// Este modelo sigue el patrón de inmutabilidad: una vez creado, no puede modificarse
/// Para cambiar valores, se usa el método copyWith() que crea una nueva instancia
class Amigo {
  /// Constructor que crea una instancia inmutable de Amigo
  /// 
  /// Parámetros:
  /// - [id]: Identificador único del amigo (requerido)
  /// - [nombre]: Nombre del amigo (requerido)
  /// - [creditBalance]: Lo que le deben al amigo (por defecto 0)
  /// - [debitBalance]: Lo que el amigo debe (por defecto 0)
  /// 
  /// La palabra 'const' indica que el objeto es inmutable y puede ser una constante
  /// de compilación, lo que mejora el rendimiento
  const Amigo({
    required this.id,
    required this.nombre,
    this.creditBalance = 0,
    this.debitBalance = 0,
  });

  /// Identificador único del amigo en el sistema
  final int id;
  
  /// Nombre del amigo
  final String nombre;
  
  /// Saldo a favor del amigo: cantidad que otros le deben
  /// Un valor positivo significa que otros amigos le deben dinero
  final double creditBalance;
  
  /// Saldo en contra del amigo: cantidad que él debe
  /// Un valor positivo significa que el amigo debe dinero
  final double debitBalance;

  /// Calcula el saldo neto del amigo
  /// 
  /// Retorna:
  /// - Valor positivo: otros le deben más de lo que él debe (está a favor)
  /// - Valor negativo: él debe más de lo que le deben (está en deuda)
  /// - Cero: está en equilibrio
  /// 
  /// El operador '=>' es una función flecha que retorna directamente la expresión
  /// Es equivalente a: double get saldo { return creditBalance - debitBalance; }
  double get saldo => creditBalance - debitBalance;

  /// Crea una copia del amigo con los campos especificados modificados
  /// 
  /// Este patrón es común en programación funcional e inmutabilidad.
  /// En lugar de modificar el objeto existente, se crea uno nuevo con los cambios.
  /// 
  /// Parámetros:
  /// Todos los parámetros son opcionales y pueden ser null (nullable con '?')
  /// - Si se proporciona un valor, se usa ese valor
  /// - Si es null, se mantiene el valor original del objeto actual

  Amigo copyWith({
    int? id,
    String? nombre,
    double? creditBalance,
    double? debitBalance,
  }) {
    return Amigo(
      // El operador '??' es el null-coalescing operator:
      // Si el valor de la izquierda NO es null, lo usa
      // Si es null, usa el valor de la derecha
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      creditBalance: creditBalance ?? this.creditBalance,
      debitBalance: debitBalance ?? this.debitBalance,
    );
  }

  /// Constructor factory que crea un Amigo desde un objeto JSON recibido de la API
  /// 
  /// Factory constructors permiten:
  /// - Devolver instancias existentes en lugar de crear nuevas siempre
  /// - Tener lógica adicional antes de crear el objeto
  /// - Tener múltiples constructores con nombres diferentes (.fromJson, .fromString, etc.)
  /// 
  /// Parámetros:
  /// - [json]: Un Map (diccionario) donde las claves son String y los valores son dynamic
  ///   (dynamic significa que el valor puede ser de cualquier tipo)
  /// 
  /// El método mapea los nombres de campos del JSON (snake_case) a los nombres del modelo (camelCase)
  factory Amigo.fromJson(Map<String, dynamic> json) {
    return Amigo(
      // 'as int' hace un cast (conversión de tipo) a int
      id: json['id'] as int,
      // 'as String?' permite que sea String o null, y '??' proporciona '' si es null
      nombre: json['name'] as String? ?? '',
      // Usa un método auxiliar para convertir valores de forma segura
      creditBalance: _toDouble(json['credit_balance']),
      debitBalance: _toDouble(json['debit_balance']),
    );
  }

  /// Convierte el Amigo a formato JSON para enviar a la API
  /// 
  /// Este método es el inverso de fromJson(): convierte el objeto Dart a un formato
  /// que puede ser serializado y enviado al servidor
  /// 
  /// Retorna un Map con los nombres de campos que espera la API (snake_case)
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': nombre, // La API usa 'name', no 'nombre'
      'credit_balance': creditBalance,
      'debit_balance': debitBalance,
    };
  }

  /// Método auxiliar privado (prefijo '_') que convierte valores a double de forma segura
  /// 
  /// Este método maneja diferentes tipos de entrada que pueden venir del JSON:
  /// - null → retorna 0
  /// - double → retorna el valor directamente
  /// - int → convierte a double
  /// - String → intenta parsear como número, si falla retorna 0
  /// - Otro tipo → retorna 0
  /// 
  /// Es 'static' porque no necesita una instancia de la clase para ser llamado
  static double _toDouble(Object? value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
