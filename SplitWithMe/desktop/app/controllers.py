"""
Módulo del controlador principal de la aplicación de gastos compartidos.

Este módulo implementa el patrón Controller del MVC (Model-View-Controller).
El MainController actúa como intermediario entre la Vista (interfaz gráfica)
y el Modelo (datos y API), coordinando toda la lógica de negocio de la aplicación.

Responsabilidades del controlador:
- Conectar eventos de la vista con acciones del modelo
- Gestionar operaciones asíncronas mediante ConcurrencyService
- Validar datos antes de enviarlos al modelo
- Manejar errores y mostrar mensajes al usuario
- Actualizar la vista cuando cambian los datos
- Coordinar el flujo de operaciones (agregar, editar, eliminar amigos y gastos)
"""

from models import Main
from views import PantallaInicialView, ErrorView
from concurrency_service import ConcurrencyService
from translations import _, format_currency, format_date


class MainController:
    """
    Controlador principal de la aplicación de gastos compartidos.
    
    Este controlador coordina las interacciones entre la vista (interfaz gráfica)
    y el modelo (datos y comunicación con la API). Implementa el patrón Controller
    del MVC, gestionando toda la lógica de negocio de la aplicación.
    
    Características:
    - Conecta callbacks de la vista con métodos del controlador
    - Ejecuta operaciones de forma asíncrona para no bloquear la UI
    - Gestiona el estado de carga durante operaciones
    - Maneja errores y muestra mensajes traducidos al usuario
    - Valida datos antes de procesarlos
    - Actualiza la vista cuando cambian los datos
    """

    def __init__(self, app):
        """
        Inicializa el controlador principal.
        
        Crea y configura todas las instancias necesarias:
        - Modelo: gestiona los datos y comunicación con la API
        - Vista: interfaz gráfica de la aplicación
        - Servicio de concurrencia: ejecuta operaciones asíncronas
        - Vista de errores: muestra mensajes de error/información
        
        Conecta los callbacks de la vista con los métodos del controlador,
        estableciendo el flujo de comunicación Vista → Controller → Model.
        
        """
        self.app = app  # Instancia de la aplicación GTK
        self.modelo = Main()  # Modelo que gestiona los datos (amigos, gastos)
        self.vista = PantallaInicialView(app)  # Vista principal (interfaz gráfica)
        self.concurrency_service = ConcurrencyService()  # Servicio para operaciones asíncronas
        self.delay_servidor = 0.0  # Delay opcional para simular latencia (útil para testing)
        
        # Conectar callbacks de la vista con métodos del controlador
        # Esto permite que los eventos de la UI (clicks, etc.) disparen
        # las acciones correspondientes en el controlador
        self.vista.on_add_amigo_callback = self.add_amigo
        self.vista.on_eliminar_amigo_callback = self.eliminar_amigo
        self.vista.on_add_gasto_callback = self.add_gasto
        self.vista.on_eliminar_gasto_callback = self.eliminar_gasto
        self.vista.on_actualizar_gasto_callback = self.actualizar_gasto
        self.vista.on_pagar_saldo_callback = self.pagar_saldo
        self.vista.on_actualizar_callback = self.actualizar_datos
        self.vista.on_borrar_todos_gastos_callback = self.borrar_todos_gastos
        self.vista.on_borrar_todos_amigos_callback = self.borrar_todos_amigos
        
        # Vista para mostrar mensajes de error e información
        self.error_view = ErrorView(self.vista)
    
    def iniciar(self):
        """
        Inicia la aplicación mostrando la ventana y cargando los datos.
        
        Este método se llama al inicio de la aplicación para:
        1. Mostrar la ventana principal al usuario (present())
        2. Cargar los datos iniciales desde la API (actualizar_datos())
        """
        self.vista.present()  # Muestra la ventana principal
        self.actualizar_datos()  # Carga amigos y gastos desde la API
    
    def mostrar_detalles(self):
        """
        Actualiza la vista con los datos actuales del modelo.
        
        Este método se llama después de cargar o modificar datos para
        refrescar la interfaz gráfica y mostrar los cambios.
        """
        self.vista.mostrar_pantalla_inicial(self.modelo)
    
    def actualizar_datos(self):
        """
        Carga los datos de amigos y gastos desde la API de forma asíncrona.
        
        Este método es el punto central para actualizar la información mostrada
        en la interfaz. Se ejecuta al iniciar la aplicación y después de cada
        operación que modifica los datos (agregar, editar, eliminar).
        
        Flujo:
        1. Muestra indicador de carga (spinner)
        2. Ejecuta carga de datos en hilo de fondo
        3. Si éxito: actualiza la vista con los nuevos datos
        4. Si error: muestra mensaje de error traducido
        """
        def cargar_datos():
            """
            Función que se ejecuta en el hilo de fondo.
            
            Carga los datos desde la API sin bloquear la interfaz gráfica.
            Retorna True si la carga fue exitosa.
            """
            self.modelo.cargar_amigos()  # GET /friends/
            self.modelo.cargar_gastos()  # GET /expenses/
            return True
        
        def on_success(result):
            """
            Callback que se ejecuta en el hilo principal si la carga fue exitosa.
        
            """
            self.vista.ocultar_loading()  # Oculta el spinner de carga
            self.mostrar_detalles()  # Actualiza la vista con los datos cargados
        
        def on_error(error):
            """
            Callback que se ejecuta en el hilo principal si ocurrió un error.
            
            Analiza el tipo de error y muestra un mensaje apropiado traducido
            al idioma de la aplicación.
            """
            self.vista.ocultar_loading()  # Oculta el spinner de carga
            error_msg = str(error)
            
            # Clasificar el tipo de error y mostrar mensaje apropiado
            if "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
            elif "Timeout" in error_msg:
                self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
            else:
                self.error_view.mostrar_error(_("Error loading data: {error}").format(error=error_msg))
        
        # Mostrar indicador de carga al usuario
        self.vista.mostrar_loading(_("Loading data..."))
        
        # Ejecutar la carga de datos de forma asíncrona
        # La operación se realiza en un hilo separado para no bloquear la UI
        self.concurrency_service.execute_async(
            cargar_datos,      # Función a ejecutar en hilo de fondo
            callback=on_success,       # Se ejecuta en hilo principal si éxito
            error_callback=on_error,   # Se ejecuta en hilo principal si error
            delay=self.delay_servidor  # Delay opcional (simula latencia para testing)
        )
    
    # MÉTODOS DE AMIGOS
    
    def add_amigo(self, nombre: str):
        """
        Agrega un nuevo amigo a la aplicación de forma asíncrona.
        
        Este método se llama cuando el usuario confirma la adición de un amigo. 
        Ejecuta la operación en un hilo de fondo y muestra
        un mensaje de éxito o error según el resultado.
        
        Flujo:
        1. Muestra indicador de carga
        2. Ejecuta POST /friends/ en hilo de fondo
        3. Si éxito: actualiza la vista y muestra mensaje de éxito
        4. Si error: muestra mensaje de error traducido
        """
        def crear_amigo():
            """
            Función que se ejecuta en el hilo de fondo.
            
            Crea el amigo en la API mediante una petición HTTP POST.
            """
            self.modelo.add_amigo(nombre)  # POST /friends/ con {"name": nombre}
            return True
        
        def on_success(result):
            """
            Callback ejecutado en el hilo principal si el amigo se agregó exitosamente.

            """
            self.vista.ocultar_loading()
            self.mostrar_detalles()  # Actualiza la vista con el nuevo amigo
            self.error_view.mostrar_info(_("Friend '{name}' added successfully").format(name=nombre))
        
        def on_error(error):
            """
            Callback ejecutado en el hilo principal si ocurrió un error.
 
            """
            self.vista.ocultar_loading()
            error_msg = str(error)
            
            # Clasificar y mostrar el error apropiado
            if "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
            elif "Timeout" in error_msg:
                self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
            else:
                self.error_view.mostrar_error(_("Error adding friend: {error}").format(error=error_msg))
        
        # Mostrar indicador de carga con el nombre del amigo
        self.vista.mostrar_loading(_("Adding friend '{name}'...").format(name=nombre))
        
        # Ejecutar la creación de forma asíncrona
        self.concurrency_service.execute_async(
            crear_amigo,
            callback=on_success,
            error_callback=on_error,
            delay=self.delay_servidor
        )
    
    def eliminar_amigo(self, amigo_id: int):
        """
        Elimina un amigo de la aplicación de forma asíncrona.
        
        Antes de eliminar, verifica que el amigo no tenga saldo pendiente.
        Si tiene saldo, lanza una excepción con un mensaje informativo.
        
        Flujo:
        1. Obtiene los datos del amigo desde la API
        2. Verifica que el saldo sea cero (o casi cero, tolerancia 0.01)
        3. Si saldo es cero: elimina el amigo (DELETE /friends/{id})
        4. Si saldo no es cero: lanza excepción con mensaje de error
        5. Actualiza la vista y muestra mensaje de éxito o error
        """
        def eliminar_amigo_async():
            """
            Función que se ejecuta en el hilo de fondo.
            
            Obtiene el amigo desde la API, verifica su saldo y lo elimina
            solo si el saldo es cero.
            
            Returns:
                dict con información del amigo eliminado (para mostrar en mensaje)
            
            Raises:
                Exception: Si el amigo tiene saldo pendiente
            """
            # Obtener el amigo desde el modelo local (puede no estar actualizado)
            amigo = None
            for a in self.modelo.amigos:
                if a.id == amigo_id:  # Busca el amigo en el modelo local
                    amigo = a  # Si lo encuentra, lo asigna a la variable amigo
                    break
            
            # Obtener el amigo actualizado desde la API para verificar saldo
            amigo_api = self.modelo.obtener_amigo(amigo_id)
            
            # Calcular el saldo del amigo
            saldo = amigo_api.saldo()
            # Tolerancia de 0.01 para considerar saldo cero (evitar errores de punto flotante)
            saldo_es_cero = abs(saldo) < 0.01  
            
            if saldo_es_cero:
                # Saldo es cero, se puede eliminar
                self.modelo.eliminar_amigo(amigo_id)  # DELETE /friends/{id}
                return {"success": True, "amigo_nombre": amigo.nombre if amigo else amigo_api.nombre}
            else:
                # Saldo pendiente, no se puede eliminar
                raise Exception(_("Cannot delete {name} because they have a pending balance of {amount}").format(
                    name=amigo_api.nombre, 
                    amount=format_currency(saldo)
                ))
        
        def on_success(result):
            """
            Callback ejecutado en el hilo principal si el amigo se eliminó exitosamente.

            """
            self.vista.ocultar_loading()
            self.actualizar_datos()  # Recarga todos los datos para reflejar el cambio
            self.error_view.mostrar_info(_("Friend {name} deleted successfully").format(name=result['amigo_nombre']))
        
        def on_error(error):
            """
            Callback ejecutado en el hilo principal si ocurrió un error.

            """
            self.vista.ocultar_loading()
            error_msg = str(error)
            
            # Clasificar el error según el tipo
            if "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
            elif "Timeout" in error_msg:
                self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
            elif "saldo pendiente" in error_msg.lower() or "pending balance" in error_msg.lower():
                # Error de saldo pendiente: mostrar el mensaje tal cual (ya está traducido)
                self.error_view.mostrar_error(error_msg)
            else:
                self.error_view.mostrar_error(_("Error deleting friend: {error}").format(error=error_msg))
        
        # Obtener el nombre del amigo para mostrar en el mensaje de carga
        amigo_nombre = "amigo"
        for a in self.modelo.amigos:
            if a.id == amigo_id:
                amigo_nombre = a.nombre
                break
        
        # Mostrar indicador de carga
        self.vista.mostrar_loading(_("Deleting friend '{name}'...").format(name=amigo_nombre))
        
        # Ejecutar la eliminación de forma asíncrona
        self.concurrency_service.execute_async(
            eliminar_amigo_async,
            callback=on_success,
            error_callback=on_error,
            delay=self.delay_servidor
        )
    
    # MÉTODOS DE GASTOS
    
    def add_gasto(self):
        """
        Inicia el proceso de agregar un nuevo gasto.
        
        Verifica que existan amigos antes de mostrar el diálogo. Si no hay amigos,
        muestra un error. Si hay amigos, muestra el diálogo para ingresar los datos
        del gasto (descripción, monto, pagador, participantes).
        
        """
        # Validar que existan amigos antes de permitir agregar gastos
        if not self.modelo.amigos:
            self.error_view.mostrar_error(_("You must add friends first"))
            return
        
        # Guardar el callback original y establecer temporalmente el callback interno
        # para capturar los datos cuando el usuario confirme el diálogo
        callback_original = self.vista.on_add_gasto_callback
        self.vista.on_add_gasto_callback = self._realizar_add_gasto
        self.vista.mostrar_dialogo_gasto(self.modelo.amigos)  # Muestra el diálogo
        self.vista.on_add_gasto_callback = callback_original  # Restaura el callback original
    
    def _realizar_add_gasto(self, descripcion: str, monto_str: str, 
                           pagador_id: int, deudores_ids: list):
        """
        Método interno que realiza la creación del gasto después de capturar los datos.
        
        Este método se llama cuando el usuario confirma el diálogo de agregar gasto.
        Valida los datos, muestra loading y ejecuta la creación de forma asíncrona.

        """
        def crear_gasto():
            """
            Función que se ejecuta en el hilo de fondo.
            
            Valida los datos y crea el gasto en la API mediante POST /expenses/
            y luego asigna participantes y calcula saldos.
            
            Raises:
                ValueError: Si el monto es <= 0 o no hay participantes
            """
            monto = float(monto_str)
            
            # Validaciones en el hilo de fondo 
            if monto <= 0:
                raise ValueError(_("Amount must be greater than 0"))
            
            if not deudores_ids:
                raise ValueError(_("You must select at least one participant"))
            
            # Crear el gasto en la API (POST /expenses/ y luego asignar participantes)
            self.modelo.add_gasto(descripcion, monto, pagador_id, deudores_ids)
            return True
        
        def on_success(result):
            """
            Callback ejecutado en el hilo principal si el gasto se agregó exitosamente.

            """
            self.vista.ocultar_loading()
            self.actualizar_datos()  # Recarga todos los datos para reflejar el nuevo gasto
            self.error_view.mostrar_info(_("Expense '{description}' added successfully").format(description=descripcion))
        
        def on_error(error):
            """
            Callback ejecutado en el hilo principal si ocurrió un error.
            
            """
            self.vista.ocultar_loading()
            error_msg = str(error)
            
            # Clasificar el error según el tipo
            if "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
            elif "Timeout" in error_msg:
                self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
            else:
                self.error_view.mostrar_error(_("Error adding expense: {error}").format(error=error_msg))
        
        try:
            # Validaciones previas en el hilo principal (sin delay)
            # Esto evita hacer la petición HTTP si los datos son inválidos
            monto = float(monto_str)
            # Validar que el monto sea mayor que 0
            if monto <= 0:
                self.error_view.mostrar_error(_("Amount must be greater than 0"))
                return
            
            # Validar que se haya seleccionado al menos un participante
            if not deudores_ids:
                self.error_view.mostrar_error(_("You must select at least one participant"))
                return
            
            # Mostrar indicador de carga
            self.vista.mostrar_loading(_("Adding expense '{description}'...").format(description=descripcion))
            
            # Ejecutar la creación de forma asíncrona
            self.concurrency_service.execute_async(
                crear_gasto,
                callback=on_success,
                error_callback=on_error,
                delay=self.delay_servidor
            )
        except ValueError:
            # Error al convertir el monto a float (formato inválido)
            self.error_view.mostrar_error(_("Amount must be a valid number"))
    
    def eliminar_gasto(self, gasto_id: int):
        """
        Elimina un gasto de la aplicación de forma asíncrona.
        
        Flujo:
        1. Muestra indicador de carga
        2. Ejecuta DELETE /expenses/{id} en hilo de fondo
        3. Si éxito: actualiza la vista y muestra mensaje de éxito
        4. Si error: muestra mensaje de error traducido
        """
        def eliminar_gasto_async():
            """Función que se ejecuta en el hilo de fondo. Elimina el gasto desde la API."""
            self.modelo.eliminar_gasto(gasto_id)  # DELETE /expenses/{id}
            return True
        
        def on_success(result):
            """Callback ejecutado en el hilo principal si el gasto se eliminó exitosamente."""
            self.vista.ocultar_loading()
            self.actualizar_datos()  # Recarga todos los datos
            self.error_view.mostrar_info(_("Expense deleted successfully"))
        
        def on_error(error):
            """Callback ejecutado en el hilo principal si ocurrió un error."""
            self.vista.ocultar_loading()
            error_msg = str(error)
            
            # Clasificar el error según el tipo
            if "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
            elif "Timeout" in error_msg:
                self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
            else:
                self.error_view.mostrar_error(_("Error deleting expense: {error}").format(error=error_msg))
        
        # Mostrar indicador de carga
        self.vista.mostrar_loading(_("Deleting expense..."))
        
        # Ejecutar la eliminación de forma asíncrona
        self.concurrency_service.execute_async(
            eliminar_gasto_async,
            callback=on_success,
            error_callback=on_error,
            delay=self.delay_servidor
        )
    
    def actualizar_gasto(self, gasto_id: int, datos: dict = None):
        """
        Actualiza un gasto existente en la aplicación.
        
        Este método tiene dos modos de operación:
        1. Si datos es None: Obtiene los participantes del gasto y muestra el diálogo de edición
        2. Si datos no es None: Actualiza el gasto con los nuevos datos
        
        Flujo modo edición (datos is None):
        1. Busca el gasto en el modelo local
        2. Obtiene participantes desde la API
        3. Muestra diálogo de edición con los datos actuales
        
        Flujo actualización (datos no es None):
        1. Valida los datos (monto válido)
        2. Ejecuta PUT /expenses/{id} en hilo de fondo
        3. Si éxito: actualiza la vista y muestra mensaje de éxito
        """
        if datos is None:
            # Modo edición: obtener datos y mostrar diálogo
            # Buscar el gasto en el modelo local
            gasto = None 
            for g in self.modelo.gastos:
                if g.id == gasto_id:
                    gasto = g 
                    break
            # Si el gasto existe, obtener los participantes
            if gasto:
                # Función que se ejecuta en el hilo de fondo. Obtiene los IDs de los participantes del gasto desde la API.
                def obtener_participantes():
                    return self.modelo.obtener_participantes_gasto(gasto_id)  # GET /expenses/{id}/friends
                
                # Callback: muestra el diálogo de edición con los datos actuales.
                def on_success(participantes_ids):
                    self.vista.ocultar_loading()
                    self.vista.mostrar_dialogo_editar(gasto, participantes_ids, self.modelo.amigos)
                # Callback: muestra error si no se pudieron obtener los participantes.
                def on_error(error):
                    """Callback: muestra error si no se pudieron obtener los participantes."""
                    self.vista.ocultar_loading()
                    self.error_view.mostrar_error(_("Error getting participants: {error}").format(error=str(error)))
                
                self.vista.mostrar_loading(_("Getting participants..."))
                
                # Obtener participantes de forma asíncrona
                self.concurrency_service.execute_async(
                    obtener_participantes,
                    callback=on_success,
                    error_callback=on_error,
                    delay=self.delay_servidor
                )
            else:
                # Gasto no encontrado en el modelo local
                self.error_view.mostrar_error(_("Expense not found"))
        else:
            # Modo actualización: guardar los cambios en la API
            def actualizar_gasto_async():
                """Función que se ejecuta en el hilo de fondo. Actualiza el gasto en la API."""
                # Convertir monto_str a float si existe
                if "monto_str" in datos:
                    datos["monto"] = float(datos["monto_str"])
                    del datos["monto_str"]  # Eliminar la clave string
                
                # Actualizar el gasto mediante PUT /expenses/{id}
                self.modelo.update_gasto(gasto_id, datos)
                return True
            
            def on_success(result):
                """Callback ejecutado en el hilo principal si la actualización fue exitosa."""
                self.vista.ocultar_loading()
                self.actualizar_datos()  # Recarga todos los datos
                self.error_view.mostrar_info(_("Expense updated successfully"))
            
            def on_error(error):
                """Callback ejecutado en el hilo principal si ocurrió un error."""
                self.vista.ocultar_loading()
                error_msg = str(error)
                
                # Clasificar el error según el tipo
                if "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                    self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
                elif "Timeout" in error_msg:
                    self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
                else:
                    self.error_view.mostrar_error(_("Error updating expense: {error}").format(error=error_msg))
            
            try:
                # Validaciones previas en el hilo principal (sin delay)
                if "monto_str" in datos:
                    float(datos["monto_str"])  # Validar que sea un número válido
                
                # Mostrar indicador de carga
                self.vista.mostrar_loading(_("Updating expense..."))
                
                # Ejecutar la actualización de forma asíncrona
                self.concurrency_service.execute_async(
                    actualizar_gasto_async,
                    callback=on_success,
                    error_callback=on_error,
                    delay=self.delay_servidor
                )
            except ValueError:
                # Error al convertir el monto a float (formato inválido)
                self.error_view.mostrar_error(_("Amount must be a valid number"))
    
    # MÉTODOS DE PAGOS
    
    def pagar_saldo(self, amigo_id: int, importe_str: str):
        """
        Registra un pago realizado por un amigo para saldar su deuda.
        
        Este método distribuye el pago entre los gastos pendientes del amigo,
        actualizando los saldos correspondientes.
        
        Flujo:
        1. Valida que el importe sea válido y mayor que 0
        2. Ejecuta el pago en la API (distribuye entre gastos pendientes)
        3. Si éxito: actualiza la vista y muestra mensaje de éxito con el importe formateado
        4. Si error: muestra mensaje de error traducido
        """
        def procesar_pago():
            """Función que se ejecuta en el hilo de fondo. Procesa el pago en la API."""
            # Validar que el importe no esté vacío y sea mayor que 0
            if not importe_str.strip():
                raise ValueError(_("You must enter an amount"))
            
            importe = float(importe_str)
            if importe <= 0:
                raise ValueError(_("Amount must be greater than 0"))
            
            # Registrar el pago (distribuye entre gastos pendientes del amigo)
            self.modelo.pagar_saldo(amigo_id, importe)
            return True
        
        def on_success(result):
            """Callback ejecutado en el hilo principal si el pago se registró exitosamente."""
            self.vista.ocultar_loading()
            self.actualizar_datos()  # Recarga todos los datos para actualizar saldos
            # Mostrar mensaje con el importe formateado según el idioma
            self.error_view.mostrar_info(_("Payment of {amount} registered successfully").format(
                amount=format_currency(float(importe_str))
            ))
        
        def on_error(error):
            """Callback ejecutado en el hilo principal si ocurrió un error."""
            self.vista.ocultar_loading()
            error_msg = str(error)
            
            # Clasificar el error según el tipo
            if "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
            elif "Timeout" in error_msg:
                self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
            else:
                self.error_view.mostrar_error(_("Error registering payment: {error}").format(error=error_msg))
        
        try:
            # Validaciones previas en el hilo principal (sin delay)
            # Validar que el importe no esté vacío y sea mayor que 0
            if not importe_str.strip():
                self.error_view.mostrar_error(_("You must enter an amount"))
                return
            
            importe = float(importe_str)
            # Validar que el importe sea mayor que 0
            if importe <= 0:
                self.error_view.mostrar_error(_("Amount must be greater than 0"))
                return
            
            # Mostrar indicador de carga con el importe formateado
            self.vista.mostrar_loading(_("Registering payment of {amount}...").format(
                amount=format_currency(float(importe_str))
            ))
            
            # Ejecutar el pago de forma asíncrona
            self.concurrency_service.execute_async(
                procesar_pago,
                callback=on_success,
                error_callback=on_error,
                delay=self.delay_servidor
            )
        except ValueError:
            # Error al convertir el importe a float (formato inválido)
            self.error_view.mostrar_error(_("Amount must be a valid number"))
    
    def borrar_todos_gastos(self):
        """
        Elimina todos los gastos de la aplicación de forma asíncrona.
        
        Itera sobre todos los gastos y los elimina uno por uno mediante DELETE.
        Si no hay gastos, muestra un mensaje informativo.
        
        Flujo:
        1. Verifica que existan gastos
        2. Obtiene todos los IDs de gastos
        3. Elimina cada gasto en el hilo de fondo
        4. Si éxito: muestra cantidad eliminada
        5. Si error: muestra mensaje de error traducido
        """
        def eliminar_todos_gastos():
            """Función que se ejecuta en el hilo de fondo. Elimina todos los gastos."""
            gastos_ids = [gasto.id for gasto in self.modelo.gastos]
            
            if not gastos_ids:
                raise ValueError(_("No expenses to delete"))
            
            # Eliminar cada gasto mediante DELETE /expenses/{id}
            for gasto_id in gastos_ids:
                self.modelo.eliminar_gasto(gasto_id)
            
            return len(gastos_ids)  # Retornar cantidad eliminada
        
        def on_success(cantidad_eliminados):
            """Callback: muestra mensaje con la cantidad de gastos eliminados."""
            self.vista.ocultar_loading()
            self.actualizar_datos()
            self.error_view.mostrar_info(_("{count} expenses deleted successfully").format(count=cantidad_eliminados))
        
        def on_error(error):
            """Callback: maneja errores al eliminar gastos."""
            self.vista.ocultar_loading()
            error_msg = str(error)
            
            # Clasificar el error según el tipo
            if "No hay gastos para eliminar" in error_msg:
                self.error_view.mostrar_info(_("No expenses to delete"))
            elif "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
            elif "Timeout" in error_msg:
                self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
            else:
                self.error_view.mostrar_error(_("Error deleting expenses: {error}").format(error=error_msg))
        
        # Verificar si hay gastos antes de mostrar loading
        if not self.modelo.gastos:
            self.error_view.mostrar_info(_("No expenses to delete"))
            return
        
        # Mostrar indicador de carga con la cantidad de gastos
        self.vista.mostrar_loading(_("Deleting {count} expenses...").format(count=len(self.modelo.gastos)))
        
        # Ejecutar la eliminación de forma asíncrona
        self.concurrency_service.execute_async(
            eliminar_todos_gastos,
            callback=on_success,
            error_callback=on_error,
            delay=self.delay_servidor
        )
    
    def borrar_todos_amigos(self):
        """
        Elimina todos los amigos de la aplicación de forma asíncrona.
        
        Itera sobre todos los amigos e intenta eliminarlos uno por uno.
        Si algún amigo no se puede eliminar (ej: tiene saldo pendiente), 
        continúa con los demás y reporta los errores al final.
        
        Flujo:
        1. Verifica que existan amigos
        2. Intenta eliminar cada amigo (puede fallar si tiene saldo)
        3. Si éxito: muestra cantidad eliminada
        4. Si hay errores parciales: muestra resumen con amigos no eliminados
        5. Si error total: muestra mensaje de error traducido
        """
        def eliminar_todos_amigos():
            """
            Función que se ejecuta en el hilo de fondo.
            
            Intenta eliminar todos los amigos, continuando aunque algunos fallen.
            Retorna un diccionario con el resultado de la operación (eliminados, total, errores).
            """
            # Obtener los IDs de los amigos
            amigos_ids = [amigo.id for amigo in self.modelo.amigos]
            
            if not amigos_ids:
                # Si no hay amigos, lanzar un error
                raise ValueError(_("No friends to delete"))
            
            eliminados = 0
            errores = []
            # Copia para obtener nombres incluso si se eliminan de la lista
            amigos_originales = self.modelo.amigos.copy()
            
            # Intentar eliminar cada amigo (algunos pueden fallar si tienen saldo)
            for amigo_id in amigos_ids:
                try:
                    self.modelo.eliminar_amigo(amigo_id)  # DELETE /friends/{id}
                    eliminados += 1
                except Exception as e:
                    # Si falla, obtener el nombre del amigo para el mensaje de error
                    amigo_nombre = _("Unknown")
                    for amigo in amigos_originales:
                        if amigo.id == amigo_id:
                            amigo_nombre = amigo.nombre
                            break
                    errores.append(f"{amigo_nombre}: {str(e)}")
            
            # Retornar resultado con estadísticas
            return {
                "eliminados": eliminados,
                "total": len(amigos_ids),
                "errores": errores
            }
        
        def on_success(resultado):
            """Callback: muestra resumen de la operación (éxitos y errores)."""
            self.vista.ocultar_loading()
            self.actualizar_datos()
            
            eliminados = resultado["eliminados"]
            total = resultado["total"]
            errores = resultado["errores"]
            
            # Si hubo errores, mostrar resumen detallado
            if errores:
                mensaje = _("Deleted {deleted} of {total} friends.\n\nFriends not deleted:\n{errors}").format(
                    deleted=eliminados, total=total, errors="\n".join(errores)
                )
                self.error_view.mostrar_error(mensaje)
            else:
                # Todos se eliminaron exitosamente
                self.error_view.mostrar_info(_("{count} friends deleted successfully").format(count=eliminados))
        
        def on_error(error):
            """Callback: maneja errores generales al eliminar amigos."""
            self.vista.ocultar_loading()
            error_msg = str(error)
            
            # Clasificar el error según el tipo
            if "No hay amigos para eliminar" in error_msg:
                self.error_view.mostrar_info(_("No friends to delete"))
            elif "Algunos amigos no se pudieron eliminar" in error_msg:
                self.error_view.mostrar_error(error_msg)
            elif "ConnectionError" in error_msg or "No se pudo conectar" in error_msg:
                self.error_view.mostrar_error(_("Cannot connect to server. Verify that the server is running."))
            elif "Timeout" in error_msg:
                self.error_view.mostrar_error(_("Server took too long to respond. Try again."))
            else:
                self.error_view.mostrar_error(_("Error deleting friends: {error}").format(error=error_msg))
        
        # Verificar si hay amigos antes de mostrar loading
        if not self.modelo.amigos:
            self.error_view.mostrar_info(_("No friends to delete"))
            return
        
        # Mostrar indicador de carga con la cantidad de amigos
        self.vista.mostrar_loading(_("Deleting {count} friends...").format(count=len(self.modelo.amigos)))
        
        # Ejecutar la eliminación de forma asíncrona
        self.concurrency_service.execute_async(
            eliminar_todos_amigos,
            callback=on_success,
            error_callback=on_error,
            delay=self.delay_servidor
        )


