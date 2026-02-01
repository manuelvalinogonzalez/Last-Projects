"""
Módulo de vistas (interfaz gráfica) de la aplicación de gastos compartidos.

Contiene las clases que gestionan toda la interfaz gráfica de la aplicación
utilizando GTK 4.

Responsabilidades de la vista:
- Construir y gestionar la interfaz gráfica (ventanas, diálogos, widgets)
- Mostrar datos del modelo (amigos, gastos, saldos)
- Capturar interacciones del usuario (clicks, entrada de texto)
- Llamar a callbacks del controlador cuando el usuario actúa
- Mostrar indicadores de carga durante operaciones
- Gestionar diálogos para agregar/editar/eliminar elementos
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk
from translations import _, format_currency, format_date


class ErrorView:
    """
    Vista para mostrar mensajes de error e información al usuario.
    
    Esta clase encapsula la funcionalidad para mostrar diálogos modales
    que informan al usuario sobre errores o información importante.
    Utiliza Gtk.MessageDialog para crear diálogos estándar de GTK.
    """
    
    def __init__(self, parent_window):
        """
        Inicializa la vista de errores.
        
        parent_window: Ventana padre que será la propietaria de los diálogos
        """
        self.parent_window = parent_window  # Ventana padre para los diálogos

    def mostrar_error(self, mensaje: str):
        """
        Muestra un diálogo de error con un mensaje.
        
        Crea un diálogo modal de tipo ERROR con un botón OK.
        El mensaje se muestra como texto secundario del diálogo.
        El diálogo se cierra automáticamente cuando el usuario hace clic en OK.
        """
        dialog = Gtk.MessageDialog(
            transient_for=self.parent_window,  # Ventana padre (el diálogo aparece encima)
            modal=True,                        # Bloquea la interacción con otras ventanas
            message_type=Gtk.MessageType.ERROR,  # Tipo de diálogo: ERROR (icono de error)
            buttons=Gtk.ButtonsType.OK,       # Botones: solo OK
            text=_("An error occurred")       # Título del diálogo (traducido)
        )
        dialog.props.secondary_text = mensaje  # Mensaje principal (texto secundario)
        # Conectar el evento de respuesta para cerrar el diálogo cuando se hace clic
        dialog.connect("response", lambda d, r: d.close())
        dialog.present()  # Mostrar el diálogo
    
    def mostrar_info(self, mensaje: str):
        """
        Muestra un diálogo informativo con un mensaje.
        
        Crea un diálogo modal de tipo INFO con un botón OK.
        Similar a mostrar_error pero con icono informativo en lugar de error.
        Útil para mostrar mensajes de éxito o información.
        """
        dialog = Gtk.MessageDialog(
            transient_for=self.parent_window,  # Ventana padre
            modal=True,                        # Modal: bloquea otras ventanas
            message_type=Gtk.MessageType.INFO,  # Tipo: INFO (icono informativo)
            buttons=Gtk.ButtonsType.OK,       # Solo botón OK
            text=_("Information")             # Título traducido
        )
        dialog.props.secondary_text = mensaje  # Mensaje principal
        # Cerrar el diálogo cuando el usuario responde
        dialog.connect("response", lambda d, r: d.close())
        dialog.present()  # Mostrar el diálogo


class PantallaInicialView(Gtk.ApplicationWindow):
    """
    Vista principal de la aplicación de gastos compartidos.
    
    Esta clase representa la ventana principal de la aplicación y gestiona
    toda la interfaz gráfica. Extiende Gtk.ApplicationWindow para crear
    una ventana completa con todos los widgets necesarios.
    
    Características:
    - Ventana principal con dos paneles (amigos y gastos)
    - Listas desplazables con información de amigos y gastos
    - Botones para agregar, editar, eliminar elementos
    - Indicador de carga durante operaciones
    - Diálogos para entrada de datos
    - Capacidad de maximizar/restaurar ventana
    
    La vista se comunica con el controlador mediante callbacks que se
    asignan desde el controlador para manejar las acciones del usuario.
    """
    
    def __init__(self, app):
        """
        Inicializa la ventana principal de la aplicación.
        
        Configura la ventana, inicializa los callbacks y construye la interfaz.
        app: Instancia de Gtk.Application que representa la aplicación
        """
        super().__init__(application=app)
        self.set_title(_("Shared Expenses"))  # Título de la ventana (traducido)
        self.set_default_size(900, 600)       # Tamaño por defecto: 900x600 píxeles
        
        # Estado interno para controlar si la ventana está maximizada
        self._is_fullscreen = False

        # Callbacks del controlador que se asignan desde MainController
        # Estos permiten que los eventos de la UI llamen a métodos del controlador
        self.on_add_amigo_callback = None
        self.on_eliminar_amigo_callback = None
        self.on_add_gasto_callback = None
        self.on_eliminar_gasto_callback = None
        self.on_actualizar_gasto_callback = None
        self.on_pagar_saldo_callback = None
        self.on_actualizar_callback = None
        self.on_borrar_todos_gastos_callback = None
        self.on_borrar_todos_amigos_callback = None

        # Vista para mostrar mensajes de error e información
        self.error_view = ErrorView(self)
        
        # Construir la interfaz gráfica
        self._construir_interfaz()
        
        # Configurar la UI de carga (spinner y label)
        self._setup_loading_ui()

    def _construir_interfaz(self):
        """
        Construye toda la interfaz gráfica de la ventana principal.
        
        Este método crea todos los widgets necesarios y los organiza
        en una estructura jerárquica. La interfaz tiene:
        - HeaderBar con botones de acción y spinner de carga
        - Paned (panel dividido) con dos secciones:
          * Panel izquierdo: Lista de amigos
          * Panel derecho: Lista de gastos
        """
        # Contenedor principal vertical que ocupa toda la ventana
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.set_child(main_box)

        # Establecer tamaño mínimo de la ventana para evitar que sea demasiado pequeña
        main_box.set_size_request(500, 300)

        # HeaderBar: barra de título personalizada (estilo moderno de GTK)
        header_bar = Gtk.HeaderBar()
        self.set_titlebar(header_bar)

        # Botón para actualizar/refrescar los datos
        btn_actualizar = Gtk.Button(icon_name="view-refresh-symbolic")
        btn_actualizar.set_tooltip_text(_("Refresh data"))
        # Conectar el click del botón al callback (si existe)
        # Usa 'and' para ejecutar el callback solo si no es None
        btn_actualizar.connect("clicked", lambda w: self.on_actualizar_callback and self.on_actualizar_callback())
        header_bar.pack_start(btn_actualizar)  # Añadir al inicio del header

        # Botón para maximizar/restaurar ventana
        self.btn_fullscreen = Gtk.Button(icon_name="window-maximize-symbolic")
        self.btn_fullscreen.set_tooltip_text(_("Maximize"))
        self.btn_fullscreen.connect("clicked", self._on_toggle_fullscreen)
        header_bar.pack_end(self.btn_fullscreen)  # Añadir al final del header
        
        # Elementos de carga: spinner animado y label de estado
        # Estos se mostrarán durante operaciones asíncronas
        self.spinner = Gtk.Spinner()  # Indicador de carga giratorio
        self.status_label = Gtk.Label()  # Label para mostrar mensajes de estado
        self.status_label.set_margin_start(12)  # Margen izquierdo
        self.status_label.set_margin_end(12)    # Margen derecho

        # Paned: contenedor dividido que permite redimensionar dos paneles
        # El usuario puede arrastrar el divisor para cambiar el tamaño de cada panel
        paned = Gtk.Paned(orientation=Gtk.Orientation.HORIZONTAL, wide_handle=True)
        paned.set_position(400)  # Posición inicial del divisor (400 píxeles desde la izquierda)
        
        # Evita que los paneles se encojan demasiado cuando se redimensiona
        # Se usa try/except porque algunas versiones de GTK pueden no tener este método
        try:
            paned.set_shrink_start_child(False)  # Panel izquierdo no se encoge
            paned.set_shrink_end_child(False)    # Panel derecho no se encoge
        except Exception:
            pass  # Si no está disponible, continuar sin esta funcionalidad
        main_box.append(paned)  # Añadir el paned al contenedor principal

        # Panel izquierdo: Amigos
        # Contenedor vertical para el panel de amigos con márgenes y espaciado
        panel_amigos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin_top=12, margin_bottom=12, margin_start=12, margin_end=12)
        paned.set_start_child(panel_amigos)  # Establecer como panel izquierdo del Paned

        # Header del panel de amigos: título y botón de agregar
        header_amigos = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        lbl_amigos = Gtk.Label(label=_("Friends"), xalign=0, hexpand=True)  # Label que se expande horizontalmente
        btn_add_amigo = Gtk.Button(icon_name="list-add-symbolic")  # Botón con icono de agregar
        btn_add_amigo.set_tooltip_text(_("Add friend"))  # Tooltip al pasar el mouse
        btn_add_amigo.connect("clicked", self._on_btn_add_amigo_clicked)  # Conectar evento click
        header_amigos.append(lbl_amigos)
        header_amigos.append(btn_add_amigo)
        panel_amigos.append(header_amigos)

        # Ventana desplazable para la lista de amigos
        # Permite hacer scroll si hay muchos amigos
        scroll_amigos = Gtk.ScrolledWindow(vexpand=True, hscrollbar_policy=Gtk.PolicyType.NEVER)
        # ListBox: lista de filas seleccionables (una a la vez)
        self.listbox_amigos = Gtk.ListBox(selection_mode=Gtk.SelectionMode.SINGLE)
        scroll_amigos.set_child(self.listbox_amigos)  # Lista dentro de la ventana desplazable
        panel_amigos.append(scroll_amigos)

        # Botones de acción para amigos (eliminar, pagar saldo, borrar todos)
        box_acciones_amigos = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6, halign=Gtk.Align.CENTER) # Contenedor horizontal para los botones
        btn_eliminar_amigo = Gtk.Button(label=_("Delete friend"))
        btn_pagar_saldo = Gtk.Button(label=_("Pay balance"))
        btn_borrar_todos_amigos = Gtk.Button(label=_("Delete all"))

        # Conectar cada botón a su respectivo handler
        btn_eliminar_amigo.connect("clicked", self._on_btn_eliminar_amigo_clicked) 
        btn_pagar_saldo.connect("clicked", self._on_btn_pagar_saldo_clicked)
        btn_borrar_todos_amigos.connect("clicked", self._on_btn_borrar_todos_amigos_clicked)
        box_acciones_amigos.append(btn_eliminar_amigo)
        box_acciones_amigos.append(btn_pagar_saldo)
        box_acciones_amigos.append(btn_borrar_todos_amigos)
        panel_amigos.append(box_acciones_amigos)

        # Panel derecho: Gastos
        # Contenedor vertical para el panel de gastos con márgenes y espaciado
        panel_gastos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6, margin_top=12, margin_bottom=12, margin_start=12, margin_end=12)
        paned.set_end_child(panel_gastos)  # Establecer como panel derecho del Paned

        # Header del panel de gastos: título y botón de agregar
        header_gastos = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        lbl_gastos = Gtk.Label(label=_("Expenses"), xalign=0, hexpand=True)
        btn_add_gasto = Gtk.Button(icon_name="list-add-symbolic")
        btn_add_gasto.set_tooltip_text(_("Add expense"))
        btn_add_gasto.connect("clicked", self._on_btn_add_gasto_clicked)
        header_gastos.append(lbl_gastos)
        header_gastos.append(btn_add_gasto)
        panel_gastos.append(header_gastos)

        # Ventana desplazable para la lista de gastos
        scroll_gastos = Gtk.ScrolledWindow(vexpand=True, hscrollbar_policy=Gtk.PolicyType.NEVER)
        # ListBox para mostrar los gastos (selección única)
        self.listbox_gastos = Gtk.ListBox(selection_mode=Gtk.SelectionMode.SINGLE)
        scroll_gastos.set_child(self.listbox_gastos)
        panel_gastos.append(scroll_gastos)

        # Botones de acción para gastos (editar, eliminar, borrar todos)
        box_acciones_gastos = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6, halign=Gtk.Align.CENTER)
        btn_editar_gasto = Gtk.Button(label=_("Edit expense"))
        btn_eliminar_gasto = Gtk.Button(label=_("Delete expense"))
        btn_borrar_todos = Gtk.Button(label=_("Delete all"))
        # Conectar cada botón a su handler
        btn_editar_gasto.connect("clicked", self._on_btn_editar_gasto_clicked)
        btn_eliminar_gasto.connect("clicked", self._on_btn_eliminar_gasto_clicked)
        btn_borrar_todos.connect("clicked", self._on_btn_borrar_todos_clicked)
        box_acciones_gastos.append(btn_editar_gasto)
        box_acciones_gastos.append(btn_eliminar_gasto)
        box_acciones_gastos.append(btn_borrar_todos)
        panel_gastos.append(box_acciones_gastos)
    
    def _setup_loading_ui(self):
        """
        Configura los elementos de carga en el HeaderBar.
        
        Añade el spinner y el label de estado al HeaderBar para que
        se muestren durante las operaciones asíncronas.
        """
        header_bar = self.get_titlebar()
        header_bar.pack_start(self.spinner)      # Añadir spinner al inicio del header
        header_bar.pack_start(self.status_label)  # Añadir label de estado al inicio del header
    
    def mostrar_loading(self, mensaje: str = None):
        """
        Muestra el indicador de carga y un mensaje de estado.
        
        Activa el spinner y muestra un mensaje en el label de estado.
        Se llama cuando comienza una operación asíncrona (cargar datos, agregar, etc.).
        
        mensaje: Mensaje opcional a mostrar. Si es None, muestra "Loading..."
        """
        if mensaje is None:
            mensaje = _("Loading...")  # Mensaje por defecto traducido
        self.status_label.set_text(mensaje)  # Establecer el texto del label
        self.spinner.start()  # Iniciar la animación del spinner
    
    def ocultar_loading(self):
        """
        Oculta el indicador de carga.
        
        Detiene el spinner y limpia el mensaje de estado.
        Se llama cuando termina una operación asíncrona.
        """
        self.status_label.set_text("")  # Limpiar el texto
        self.spinner.stop()  # Detener la animación del spinner

    def _on_toggle_fullscreen(self, button):
        """
        Alterna entre maximizar y restaurar la ventana.
        
        Maneja el click del botón de maximizar/restaurar.
        Cambia el estado de la ventana y actualiza el icono y tooltip del botón.
        Usa try/except para manejar posibles errores si los métodos no están disponibles.
        """
        if not self._is_fullscreen:
            # Maximizar la ventana
            try:
                self.maximize()  # Maximizar la ventana
            except Exception:
                pass  # Si falla, continuar sin maximizar
            self._is_fullscreen = True  # Actualizar estado interno
            # Cambiar el icono a "restaurar"
            try:
                self.btn_fullscreen.set_icon_name("view-restore-symbolic")
                self.btn_fullscreen.set_tooltip_text(_("Restore"))
            except Exception:
                pass
        else:
            # Restaurar el tamaño normal de la ventana
            try:
                self.unmaximize()  # Restaurar tamaño normal
            except Exception:
                pass
            self._is_fullscreen = False  # Actualizar estado interno
            # Cambiar el icono a "maximizar"
            try:
                self.btn_fullscreen.set_icon_name("window-maximize-symbolic")
                self.btn_fullscreen.set_tooltip_text(_("Maximize"))
            except Exception:
                pass

    def mostrar_pantalla_inicial(self, grupo):
        """
        Actualiza la interfaz con los datos del grupo.
        
        Limpia las listas actuales y las rellena con los amigos y gastos
        del grupo proporcionado. Este método se llama cuando se actualizan
        los datos del modelo.
        
        grupo: Objeto Main que contiene la lista de amigos y gastos
        """
        # Limpiar y actualizar la lista de amigos
        self._limpiar_listbox(self.listbox_amigos)
        for amigo in grupo.amigos:
            self.listbox_amigos.append(self._crear_fila_amigo(amigo))

        # Limpiar y actualizar la lista de gastos
        self._limpiar_listbox(self.listbox_gastos)
        for gasto in grupo.gastos:
            self.listbox_gastos.append(self._crear_fila_gasto(gasto, grupo.amigos))

    def _limpiar_listbox(self, listbox):
        """
        Elimina todas las filas de un ListBox.
        
        Itera sobre las filas del ListBox y las elimina una por una
        hasta que no queden más filas.
        
        listbox: El ListBox que se desea limpiar
        """
        # Operador walrus (:=): asigna y evalúa en la misma expresión
        # Mientras hay una fila en el índice 0, la elimina
        while row := listbox.get_row_at_index(0):
            listbox.remove(row)

    def _crear_fila_amigo(self, amigo):
        """
        Crea una fila visual para mostrar un amigo en la lista.
        
        Crea un ListBoxRow con el nombre y el saldo del amigo.
        El saldo se formatea como moneda y se muestra en negrita.
        Guarda el ID y nombre del amigo en el row para accederlos después.
        
        Retorna: ListBoxRow configurado con la información del amigo
        """
        row = Gtk.ListBoxRow()  # Fila de la lista
        # Guardar datos del amigo en el row para acceso posterior
        row.amigo_id = amigo.id
        row.amigo_nombre = amigo.nombre

        # Contenedor vertical para los labels
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, margin_top=8, margin_bottom=8, margin_start=12, margin_end=12)
        
        # Label con el nombre en negrita (usando markup HTML)
        lbl_nombre = Gtk.Label(label=f"<b>{amigo.nombre}</b>", use_markup=True, xalign=0)
        
        # Calcular y formatear el saldo
        saldo = amigo.saldo()
        # Corregir -0.00 para mostrar 0.00 (evita mostrar valores negativos casi cero)
        if abs(saldo) < 0.01:
            saldo = 0.0
        saldo_texto = _("Balance: {amount}").format(amount=format_currency(saldo))  # Formatear como moneda
        lbl_saldo = Gtk.Label(label=saldo_texto, xalign=0)
        
        # Añadir los labels al contenedor
        box.append(lbl_nombre)
        box.append(lbl_saldo)
        row.set_child(box)  # Establecer el contenedor como hijo del row
        return row

    def _crear_fila_gasto(self, gasto, amigos=None):
        """
        Crea una fila visual para mostrar un gasto en la lista.
        
        Crea un ListBoxRow con la descripción, monto, fecha, división
        por persona y el nombre del pagador. Busca el nombre del pagador
        en la lista de amigos si está disponible.
        
        Retorna: ListBoxRow configurado con la información del gasto
        """
        row = Gtk.ListBoxRow()  # Fila de la lista
        row.gasto_id = gasto.id  # Guardar ID del gasto para acceso posterior

        # Contenedor vertical para todos los labels
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4, margin_top=8, margin_bottom=8, margin_start=12, margin_end=12)
        
        # Label con la descripción en negrita
        lbl_desc = Gtk.Label(label=f"<b>{gasto.descripcion}</b>", use_markup=True, xalign=0)
        # Label con monto y fecha formateados
        lbl_info = Gtk.Label(label=f"{format_currency(gasto.monto)} - {format_date(gasto.fecha)}", xalign=0)
        
        # Buscar el nombre del pagador si está disponible
        pagador_nombre = _("Unknown")  # Valor por defecto si no se encuentra
        if hasattr(gasto, 'pagador_id') and gasto.pagador_id and amigos:
            # Buscar el nombre del pagador en la lista de amigos
            for amigo in amigos:
                if amigo.id == gasto.pagador_id:
                    pagador_nombre = amigo.nombre
                    break  # Salir del loop cuando se encuentra
        
        # Calcular la división del gasto por persona
        division = gasto.split()
        lbl_div = Gtk.Label(label=_("Per person: {amount} ({count} people)").format(amount=format_currency(division), count=gasto.num_friends), xalign=0)
        lbl_pagador = Gtk.Label(label=_("Paid by: {name}").format(name=pagador_nombre), xalign=0)

        # Añadir todos los labels al contenedor
        box.append(lbl_desc)
        box.append(lbl_info)
        box.append(lbl_div)
        box.append(lbl_pagador)
        row.set_child(box)  # Establecer el contenedor como hijo del row
        return row

    def mostrar_dialogo_add_amigo(self):
        """
        Muestra un diálogo para agregar un nuevo amigo.
        
        Crea un diálogo modal con un campo de entrada de texto para
        introducir el nombre del amigo. Cuando el usuario hace clic
        en "Add", llama al callback del controlador con el nombre.
        """
        # Crear diálogo modal para agregar amigo
        dialog = Gtk.Dialog(transient_for=self, modal=True, title=_("Add friend"))
        content = dialog.get_content_area()  # Área de contenido del diálogo
        content.set_spacing(12)              # Espaciado entre widgets
        content.set_margin_top(12)
        content.set_margin_bottom(12)
        content.set_margin_start(12)
        content.set_margin_end(12)

        # Campo de entrada de texto para el nombre
        entry_nombre = Gtk.Entry(placeholder_text=_("Enter name"))
        content.append(Gtk.Label(label=_("Friend name:"), xalign=0))  # Label descriptivo
        content.append(entry_nombre)

        # Añadir botones al diálogo (Cancel y Add)
        dialog.add_button(_("Cancel"), Gtk.ResponseType.CANCEL)
        dialog.add_button(_("Add"), Gtk.ResponseType.OK)
        
        def on_response(d, response_id):
            """
            Maneja la respuesta del diálogo.
            
            Si el usuario hace clic en OK, obtiene el nombre del campo
            y llama al callback del controlador.
            """
            if response_id == Gtk.ResponseType.OK:
                nombre = entry_nombre.get_text().strip()  # Obtener y limpiar el texto
                if self.on_add_amigo_callback:
                    self.on_add_amigo_callback(nombre)  # Llamar al callback del controlador
            d.close()  # Cerrar el diálogo

        dialog.connect("response", on_response)  # Conectar el evento de respuesta
        dialog.present()  # Mostrar el diálogo

    def mostrar_dialogo_gasto(self, amigos, gasto_a_editar=None, participantes_ids=None):
        """
        Muestra un diálogo para agregar o editar un gasto.
        
        Este diálogo cambia su contenido dependiendo de si se está agregando
        un nuevo gasto o editando uno existente.
        
        Para agregar:
        - Campo de descripción
        - Campo de monto
        - Combo box para seleccionar quién pagó
        - Checkboxes para seleccionar quiénes participaron
        
        Para editar:
        - Campos prellenados con los datos actuales
        - Campo de fecha editable
        - Checkboxes para editar los participantes
        
        amigos: Lista de amigos disponibles
        gasto_a_editar: Gasto existente si se está editando, None si es nuevo
        participantes_ids: Lista de IDs de participantes (solo para edición)
        """
        # Determinar si es edición o creación
        es_edicion = gasto_a_editar is not None
        titulo = _("Edit expense") if es_edicion else _("Add expense")

        # Crear diálogo modal con ancho por defecto
        dialog = Gtk.Dialog(transient_for=self, modal=True, title=titulo, default_width=400)
        content = dialog.get_content_area()
        content.set_spacing(12)
        content.set_margin_top(12)
        content.set_margin_bottom(12)
        content.set_margin_start(12)
        content.set_margin_end(12)

        # Campos de entrada: descripción y monto
        # Si es edición, prellenar con los valores actuales
        entry_desc = Gtk.Entry(text=gasto_a_editar.descripcion if es_edicion else "")
        entry_monto = Gtk.Entry(text=str(gasto_a_editar.monto) if es_edicion else "")

        content.append(Gtk.Label(label=_("Description:"), xalign=0))
        content.append(entry_desc)
        content.append(Gtk.Label(label=_("Amount:"), xalign=0))
        content.append(entry_monto)

        if es_edicion:
            # Modo edición: añadir campo de fecha y lista de participantes
            entry_fecha = Gtk.Entry(text=gasto_a_editar.fecha)
            content.append(Gtk.Label(label=_("Date (YYYY-MM-DD):"), xalign=0))
            content.append(entry_fecha)
            
            # Lista de checkboxes para editar participantes
            content.append(Gtk.Label(label=_("Participants:"), xalign=0))
            box_participantes = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            scroll_participantes = Gtk.ScrolledWindow(min_content_height=150, hscrollbar_policy=Gtk.PolicyType.NEVER)
            scroll_participantes.set_child(box_participantes)
            checkboxes_participantes = []
            # Crear un checkbox por cada amigo, marcado si está en participantes_ids
            for amigo in amigos:
                check = Gtk.CheckButton(label=amigo.nombre, active=(amigo.id in (participantes_ids or [])))
                check.amigo_id = amigo.id  # Guardar ID para acceso posterior
                box_participantes.append(check)
                checkboxes_participantes.append(check)
            content.append(scroll_participantes)
        else:
            # Modo creación: añadir combo box para pagador y checkboxes para deudores
            nombres_amigos = []
            for a in amigos:
                nombres_amigos.append(a.nombre)
            # DropDown para seleccionar quién pagó
            combo_pagador = Gtk.DropDown.new_from_strings(nombres_amigos)
            content.append(Gtk.Label(label=_("Who paid?"), xalign=0))
            content.append(combo_pagador)
            
            # Lista de checkboxes para seleccionar quiénes participaron
            box_deudores = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            scroll = Gtk.ScrolledWindow(min_content_height=150, hscrollbar_policy=Gtk.PolicyType.NEVER)
            scroll.set_child(box_deudores)
            checkboxes = []
            # Crear un checkbox por cada amigo, sin marcar por defecto
            for amigo in amigos:
                check = Gtk.CheckButton(label=amigo.nombre, active=False)
                check.amigo_id = amigo.id  # Guardar ID para acceso posterior
                box_deudores.append(check)
                checkboxes.append(check)
            content.append(Gtk.Label(label=_("Who participated?"), xalign=0))
            content.append(scroll)
        
        # Añadir botones al diálogo
        dialog.add_button(_("Cancel"), Gtk.ResponseType.CANCEL)
        dialog.add_button(_("Save") if es_edicion else _("Add"), Gtk.ResponseType.OK)

        # Guardar referencia al callback original antes de que se modifique
        # (puede ser necesario si el callback cambia durante la ejecución)
        callback_original = self.on_add_gasto_callback
        
        def on_response(d, response_id):
            """
            Maneja la respuesta del diálogo.
            
            Si el usuario hace clic en OK, recopila todos los datos
            y llama al callback apropiado del controlador (crear o actualizar).
            """
            if response_id == Gtk.ResponseType.OK:
                descripcion = entry_desc.get_text().strip()
                monto_str = entry_monto.get_text().strip()

                if es_edicion:
                    # Modo edición: recopilar datos y llamar al callback de actualización
                    fecha = entry_fecha.get_text().strip()
                    # Obtener participantes seleccionados de los checkboxes
                    participantes_seleccionados = []
                    for cb in checkboxes_participantes:
                        if cb.get_active():
                            participantes_seleccionados.append(cb.amigo_id)
                    
                    # Crear diccionario con los datos del gasto editado
                    datos = {
                        "descripcion": descripcion, 
                        "monto_str": monto_str, 
                        "fecha": fecha,
                        "participantes_ids": participantes_seleccionados
                    }
                    if self.on_actualizar_gasto_callback:
                        self.on_actualizar_gasto_callback(gasto_a_editar.id, datos)
                else:
                    # Modo creación: obtener pagador y deudores y llamar al callback de creación
                    pagador_idx = combo_pagador.get_selected()  # Índice del pagador seleccionado
                    pagador_id = amigos[pagador_idx].id  # ID del pagador
                    deudores_ids = []
                    # Obtener IDs de los deudores seleccionados
                    for cb in checkboxes:
                        if cb.get_active():
                            deudores_ids.append(cb.amigo_id)
                    # Llamar al callback original de creación
                    if callback_original:
                        callback_original(descripcion, monto_str, pagador_id, deudores_ids)
            d.close()  # Cerrar el diálogo

        dialog.connect("response", on_response)  # Conectar el evento de respuesta
        dialog.present()  # Mostrar el diálogo
    
    def mostrar_dialogo_editar(self, gasto, participantes_ids=None, amigos=None):
        """
        Alias para mantener compatibilidad con el código existente.
        
        Este método simplemente llama a mostrar_dialogo_gasto con
        los parámetros en un orden diferente para facilitar la migración.
        """
        self.mostrar_dialogo_gasto(amigos, gasto, participantes_ids)

    def mostrar_dialogo_pagar_saldo(self, amigo_nombre):
        """
        Muestra un diálogo para registrar un pago de saldo de un amigo.
        
        Permite al usuario introducir un importe que se pagará para
        reducir el saldo negativo (deuda) de un amigo.
        
        amigo_nombre: Nombre del amigo cuyo saldo se va a pagar
        """
        # Crear diálogo modal con el nombre del amigo en el título
        dialog = Gtk.Dialog(transient_for=self, modal=True, title=_("Pay balance of {name}").format(name=amigo_nombre))
        content = dialog.get_content_area()
        content.set_spacing(12)
        content.set_margin_top(12)
        content.set_margin_bottom(12)
        content.set_margin_start(12)
        content.set_margin_end(12)
        
        # Campo de entrada para el importe a pagar
        entry_importe = Gtk.Entry(placeholder_text="0.00")
        content.append(Gtk.Label(label=_("Amount to pay:"), xalign=0))
        content.append(entry_importe)
        
        # Añadir botones al diálogo
        dialog.add_button(_("Cancel"), Gtk.ResponseType.CANCEL)
        dialog.add_button(_("Pay"), Gtk.ResponseType.OK)
        
        def on_response(d, response_id):
            """
            Maneja la respuesta del diálogo.
            
            Si el usuario hace clic en OK, obtiene el importe y el amigo
            seleccionado, y llama al callback del controlador.
            """
            if response_id == Gtk.ResponseType.OK:
                importe_str = entry_importe.get_text().strip()  # Obtener importe introducido
                row = self.listbox_amigos.get_selected_row()  # Obtener amigo seleccionado
                if row and self.on_pagar_saldo_callback:
                    # Llamar al callback con el ID del amigo y el importe
                    self.on_pagar_saldo_callback(row.amigo_id, importe_str)
            d.close()  # Cerrar el diálogo
        
        dialog.connect("response", on_response)  # Conectar el evento de respuesta
        dialog.present()  # Mostrar el diálogo

    # Callbacks de botones
    # Estos métodos son llamados cuando el usuario hace clic en los botones de la interfaz
    # Cada método obtiene la información necesaria y llama al callback del controlador
    
    def _on_btn_add_amigo_clicked(self, button):
        """
        Maneja el click del botón de agregar amigo.
        
        Muestra el diálogo para introducir el nombre del nuevo amigo.
        """
        self.mostrar_dialogo_add_amigo()
    
    def _on_btn_eliminar_amigo_clicked(self, button):
        """
        Maneja el click del botón de eliminar amigo.
        
        Obtiene el amigo seleccionado en la lista y llama al callback
        del controlador para eliminarlo. Solo actúa si hay una fila seleccionada.
        """
        row = self.listbox_amigos.get_selected_row()  # Obtener fila seleccionada
        if row and self.on_eliminar_amigo_callback:
            # Llamar al callback con el ID del amigo seleccionado
            self.on_eliminar_amigo_callback(row.amigo_id)

    def _on_btn_eliminar_gasto_clicked(self, button):
        """
        Maneja el click del botón de eliminar gasto.
        
        Obtiene el gasto seleccionado en la lista y llama al callback
        del controlador para eliminarlo. Solo actúa si hay una fila seleccionada.
        """
        row = self.listbox_gastos.get_selected_row()  # Obtener fila seleccionada
        if row and self.on_eliminar_gasto_callback:
            # Llamar al callback con el ID del gasto seleccionado
            self.on_eliminar_gasto_callback(row.gasto_id)
    
    def _on_btn_editar_gasto_clicked(self, button):
        """
        Maneja el click del botón de editar gasto.
        
        Obtiene el gasto seleccionado y llama al callback del controlador
        para editarlo. El controlador se encargará de cargar los datos
        y mostrar el diálogo de edición.
        """
        row = self.listbox_gastos.get_selected_row()  # Obtener fila seleccionada
        if row and self.on_actualizar_gasto_callback:
            # Llamar al callback con el ID del gasto para cargar y editar
            self.on_actualizar_gasto_callback(row.gasto_id)
    
    def _on_btn_add_gasto_clicked(self, button):
        """
        Maneja el click del botón de agregar gasto.
        
        Llama al callback del controlador que se encargará de mostrar
        el diálogo para crear un nuevo gasto.
        """
        if self.on_add_gasto_callback:
            self.on_add_gasto_callback()
    
    def _on_btn_borrar_todos_clicked(self, button):
        """
        Maneja el click del botón de borrar todos los gastos.
        
        Llama al callback del controlador para eliminar todos los gastos.
        El controlador debería mostrar una confirmación antes de proceder.
        """
        if self.on_borrar_todos_gastos_callback:
            self.on_borrar_todos_gastos_callback()
    
    def _on_btn_pagar_saldo_clicked(self, button):
        """
        Maneja el click del botón de pagar saldo.
        
        Obtiene el amigo seleccionado y muestra el diálogo para introducir
        el importe a pagar. Solo actúa si hay un amigo seleccionado.
        """
        row = self.listbox_amigos.get_selected_row()  # Obtener fila seleccionada
        if row:
            # Mostrar diálogo con el nombre del amigo seleccionado
            self.mostrar_dialogo_pagar_saldo(row.amigo_nombre)
    
    def _on_btn_borrar_todos_amigos_clicked(self, button):
        """
        Maneja el click del botón de borrar todos los amigos.
        
        Llama al callback del controlador para eliminar todos los amigos.
        El controlador debería mostrar una confirmación antes de proceder.
        """
        if self.on_borrar_todos_amigos_callback:
            self.on_borrar_todos_amigos_callback()