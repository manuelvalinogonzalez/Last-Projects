import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'views/main_view.dart';

/// Punto de entrada de la aplicación
/// Este método es llamado automáticamente por Flutter cuando la app se inicia
/// Inicializa el servicio de API y lanza la aplicación Flutter
void main() {
  // Asegura que Flutter esté inicializado antes de usar cualquier widget
  // Es necesario para operaciones que requieren el binding de Flutter (como plugins)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Crea una instancia del servicio de API que manejará todas las comunicaciones con el backend
  // Por defecto usa la URL 'http://10.0.2.2:8000' (emulador Android) y timeout de 10 segundos
  final apiService = ApiService();
  
  // Inicia la aplicación con el widget raíz
  runApp(GastosAmigosApp(apiService: apiService));
}

/// Widget raíz de la aplicación que configura el MaterialApp
/// 
/// Este widget:
/// - Configura el tema de la aplicación (Material Design 3)
/// - Inyecta el ApiService a través de toda la jerarquía de widgets
/// - Define la pantalla principal (MainScreen)
/// 
/// Usa el patrón de inyección de dependencias pasando el ApiService como parámetro
class GastosAmigosApp extends StatelessWidget {
  const GastosAmigosApp({super.key, required this.apiService});

  /// Servicio de API que se pasará a todas las vistas y viewmodels
  /// Permite la comunicación con el backend REST
  final ApiService apiService;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Título de la aplicación (se muestra en la barra de tareas del sistema)
      title: 'MVVM Gastos & Amigos',
      
      // Configuración del tema visual de la aplicación
      theme: ThemeData(
        // Esquema de colores generado a partir de un color base (indigo)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        // Habilita Material Design 3 (la versión más reciente del sistema de diseño)
        useMaterial3: true,
      ),
      
      // Pantalla inicial que se muestra al abrir la app
      // Se le pasa el ApiService para que pueda inyectarlo en los ViewModels
      home: MainScreen(apiService: apiService),
    );
  }
}

