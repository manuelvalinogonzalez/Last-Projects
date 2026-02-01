#!/usr/bin/env python3

"""
Módulo principal de la aplicación.

Este módulo contiene la clase Application que extiende Gtk.Application y actúa
como punto de entrada principal de la aplicación. Se encarga de:

- Inicializar la aplicación GTK 4 (biblioteca gráfica de herramientas graficas para crear interfaces gráficas)
- Detectar y configurar el idioma del sistema operativo
- Crear y gestionar el controlador principal
- Manejar el ciclo de vida de la aplicación

La aplicación utiliza el patrón MVC (Model-View-Controller) donde:
- Application: Coordina el inicio y gestión del ciclo de vida
- MainController: Maneja la lógica de negocio
- PantallaInicialView: Gestiona la interfaz gráfica
- Main: Representa el modelo de datos
"""

import sys
import gi
import locale

# Requerir la versión específica de GTK antes de importar
# Esto asegura que usamos GTK 4.0 y no otra versión
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk

from controllers import MainController
from translations import set_language


class Application(Gtk.Application):
    """
    Clase principal de la aplicación de gastos compartidos.
    
    Extiende Gtk.Application para proporcionar la funcionalidad base de una
    aplicación GTK moderna. Esta clase gestiona el ciclo de vida de la aplicación
    y coordina la inicialización de todos los componentes.
    
    Características:
    - Gestiona el ciclo de vida de la aplicación GTK
    - Detecta automáticamente el idioma del sistema operativo
    - Configura las traducciones antes de mostrar la interfaz
    - Inicializa el controlador principal y la vista
    """
    
    def __init__(self):
        """
        Inicializa la aplicación GTK.
        
        Configura el ID único de la aplicación que permite al sistema gestionar
        múltiples instancias de la misma aplicación y proporciona servicios como
        preferencias y notificaciones.
        """
        # ID único de la aplicación en formato reverse DNS
        # Formato: com.dominio.proyecto.nombre
        super().__init__(application_id='com.udc.ipm.gastoscompartidos')
        self.controller = None  # Se inicializa en do_activate()
    
    def do_activate(self):
        """
        Método llamado cuando la aplicación se activa.
        
        Este es el método principal de inicialización que se ejecuta cuando
        la aplicación GTK se activa.

        Flujo de inicialización:
        1. Detecta el idioma y codificación del sistema operativo
        2. Configura las traducciones según el idioma detectado
        3. Crea el controlador principal que gestiona la lógica de la aplicación
        4. Inicializa y muestra la interfaz gráfica
        
        """
        # Obtener el locale predeterminado del sistema operativo
        # Retorna una tupla: (locale, encoding) ("es_ES", "UTF-8")
        idioma, codificacion = locale.getdefaultlocale()
        
        # Mostrar información de depuración sobre el idioma detectado
        print(f"Idioma detectado: {idioma}, codificación: {codificacion}")
        
        # Configurar el idioma de la aplicación antes de crear la interfaz
        # Esto asegura que todos los textos se muestren en el idioma correcto
        # desde el inicio. El método set_language procesa el locale y carga
        # las traducciones correspondientes desde el directorio 'locales/'
        set_language(idioma, codificacion)
        
        # Crear el controlador principal que gestiona la lógica de la aplicación
        # El controlador coordina el modelo (datos) y la vista (interfaz gráfica)
        self.controller = MainController(self)
        
        # Inicializar y mostrar la interfaz gráfica
        # Este método presenta la ventana principal al usuario
        self.controller.iniciar()

    def on_quit(self, action, param):
        """
        Método para manejar la acción de salir de la aplicación.
        
        Se llama cuando el usuario solicita cerrar la aplicación. Termina el bucle principal de GTK,
        lo que provoca que la aplicación se cierre.
        
        Args:
            action: Acción que disparó el evento (Gio.Action)
            param: Parámetro opcional de la acción (puede ser None)
        """
        self.quit()


# Punto de entrada principal de la aplicación

if __name__ == "__main__":
    """
    Bloque principal que se ejecuta cuando se inicia la aplicación directamente.
    
    Este código no se ejecuta si el módulo se importa desde otro script,
    solo cuando se ejecuta directamente con: python main.py
    
    Flujo de ejecución:
    1. Crea una instancia de la aplicación
    2. Inicia el bucle principal de GTK que maneja eventos y dibuja la UI
    3. Maneja excepciones para un cierre controlado
    """
    # Crear la instancia única de la aplicación
    app = Application()
    
    try:
        # Mensaje informativo al iniciar
        print("Iniciando aplicación...")
        
        # Iniciar el bucle principal de GTK
        # Este método bloquea hasta que la aplicación se cierra
        # Maneja todos los eventos de la interfaz gráfica (clicks, redimensiones, etc.)
        app.run(sys.argv)  # Pasa los argumentos de línea de comandos
        
    except KeyboardInterrupt:
        # Capturar interrupción del usuario (Ctrl+C en terminal)
        # Permite cerrar la aplicación de forma controlada desde la terminal
        print("Interrupción del usuario")
        pass
        
    except Exception as e:
        # Capturar cualquier otro error no previsto
        # Muestra el error y sale con código de error para indicar fallo
        print(f"Error al ejecutar la aplicación: {e}")
        sys.exit(1)
