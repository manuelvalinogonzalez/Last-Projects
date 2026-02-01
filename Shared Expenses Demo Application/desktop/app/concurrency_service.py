#!/usr/bin/env python3

"""
Módulo de servicio de concurrencia para operaciones asíncronas.

Este módulo proporciona funcionalidades para:
- Ejecutar operaciones en hilos separados 
- Gestionar callbacks que se ejecutan en el hilo principal de GTK
- Controlar operaciones activas y esperar su finalización
- Simular latencia en operaciones asíncronas

Utiliza threading de Python para crear hilos de trabajo y GLib.idle_add
para asegurar que los callbacks se ejecuten en el hilo principal de GTK,
lo cual es necesario para actualizar la interfaz gráfica de forma segura.

Nota importante:
    En aplicaciones GTK, todas las actualizaciones de la interfaz gráfica
    deben realizarse desde el hilo principal. Este servicio garantiza que
    los callbacks se ejecuten en el hilo correcto mediante GLib.idle_add.
"""

import threading
import time
from typing import Callable, Any, Optional
from gi.repository import GLib


class ConcurrencyService:
    """
    Servicio para gestionar operaciones concurrentes y asíncronas.
    
    Esta clase permite ejecutar funciones en hilos separados y gestionar
    los callbacks de éxito y error, asegurándose de que estos se ejecuten
    en el hilo principal de GTK para actualizaciones seguras de la UI.
    
    Características:
    - Ejecuta operaciones en hilos de fondo (daemon threads)
    - Gestiona múltiples hilos simultáneos
    - Permite esperar la finalización de todas las operaciones
    - Controla el estado de las operaciones activas
    """
    
    def __init__(self):
        """
        Inicializa el servicio de concurrencia.
        
        Crea las estructuras necesarias para gestionar hilos y operaciones.
        """
        self.threads = []  # Lista de hilos activos
        self.active_operations = 0  # Contador de operaciones activas
    
    def execute_async(self, func: Callable, callback: Callable = None, 
                     error_callback: Callable = None, delay: float = 0.0):
        """
        Ejecuta una función de forma asíncrona en un hilo separado.
        
        La función se ejecuta en un hilo de fondo (daemon thread). Cuando
        la función completa exitosamente, se llama al callback en el hilo
        principal de GTK. Si ocurre una excepción, se llama al error_callback.
        
        Returns:
            El objeto Thread creado para ejecutar la operación
        
        """
        def worker():
            """
            Función worker que se ejecuta en el hilo de fondo.
            
            Ejecuta la función principal, maneja errores y notifica
            los resultados mediante callbacks en el hilo principal.
            """
            try:
                # Incrementar contador de operaciones activas 
                # self.active_operations += 1
                
                # Simular latencia si se especificó un delay
                if delay > 0:
                    time.sleep(delay)
                
                # Ejecutar la función principal en el hilo de fondo
                result = func()
                
                # Si hay callback de éxito, ejecutarlo en el hilo principal
                # GLib.idle_add asegura que el callback se ejecute en el hilo
                # principal de GTK, lo cual es necesario para actualizar la UI
                if callback:
                    GLib.idle_add(lambda: callback(result))
                    
            except Exception as e:
                # Si ocurre una excepción, llamar al error_callback en el hilo principal
                if error_callback:
                    error = e  # Capturar la excepción para el callback
                    GLib.idle_add(lambda: error_callback(error))
            finally:
                # Decrementar contador de operaciones activas
                self.active_operations -= 1
        
        # Crear y configurar el hilo como daemon (se termina cuando termina el programa principal)
        thread = threading.Thread(target=worker, daemon=True)
        thread.start()  # Iniciar el hilo
        
        # Registrar el hilo en la lista de hilos activos
        self.threads.append(thread)
        return thread
    
    def has_active_operations(self) -> bool:
        """
        Verifica si hay operaciones activas en este momento.
    
        """
        return self.active_operations > 0
    
    def wait_for_completion(self, timeout: float = None):
        """
        Espera a que todos los hilos activos terminen su ejecución.
        
        Este método bloquea hasta que todos los hilos en self.threads
        hayan terminado, o hasta que se alcance el timeout si se especifica.
        Después de la espera, limpia la lista de hilos eliminando los que
        ya han terminado.
        
        Ejemplo:
            # Ejecutar varias operaciones
            service.execute_async(operacion1)
            service.execute_async(operacion2)
            
            # Esperar a que ambas terminen (máximo 5 segundos)
            service.wait_for_completion(timeout=5.0)
            
            # O esperar indefinidamente
            service.wait_for_completion()
        
        """
        # Esperar a que cada hilo termine 
        for thread in self.threads:
            thread.join(timeout)
        
        # Limpiar hilos completados: mantener solo los que aún están vivos
        # Esto evita que la lista crezca indefinidamente
        self.threads = [t for t in self.threads if t.is_alive()]
