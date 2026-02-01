/**
 * Script principal para la aplicación SplitWithMe
 * Tarea 1: Implementación básica de interfaz (sin funcionalidad completa)
 */

// ============================================
// Estructura de datos
// ============================================
let gastos = []; // Array local para compatibilidad
let amigos = []; // Array local para compatibilidad
let indiceGastoEditando = null; // null si es nuevo, índice si es edición
let indiceAmigoEditando = null; // null si es nuevo, índice si es edición

// Inicialización cuando el DOM está cargado
document.addEventListener('DOMContentLoaded', () => {
    // Crear modales primero
    crearModalGasto();
    crearModalAmigo();
    crearModalConfirmacion();
    crearModalPagarSaldos();
    
    // Cargar datos desde el HTML
    inicializarAmigosDesdeHTML();
    inicializarGastosDesdeHTML();
    
    // Recalcular participantes de los gastos ahora que los amigos están inicializados
    // Esto es importante porque cuando se inicializaron los gastos, los amigos podrían estar vacíos
    gastos.forEach(gasto => {
        if (!gasto.participantes || gasto.participantes.length === 0) {
            gasto.participantes = amigos.map(a => a.nombre);
        }
    });
    
    // Actualizar textos alternativos primero
    actualizarTextosAlternativos();
    
    // Configuración inicial
    inicializarApp();
    inicializarNavegacion();
    
    // Actualizar balances de amigos después de cargar todo
    // Es importante hacerlo después de que los gastos estén inicializados
    setTimeout(() => {
        actualizarTextosAlternativos();
        actualizarBalancesAmigos();
    }, 100);
});


/**
 * Inicializa los amigos desde el HTML existente
 */
function inicializarAmigosDesdeHTML() {
    const itemsAmigos = document.querySelectorAll('#lista-amigos .item-amigo');
    amigos = [];
    
    itemsAmigos.forEach((item, index) => {
        const nombre = item.querySelector('.item-titulo').textContent.trim();
        amigos.push({
            id: Date.now() + index, // Asignar ID único
            nombre: nombre
        });
    });
}

/**
 * Inicializa los gastos desde el HTML existente
 */
function inicializarGastosDesdeHTML() {
    const itemsGastos = document.querySelectorAll('#lista-gastos .item-gasto');
    gastos = [];
    
    itemsGastos.forEach(item => {
        const titulo = item.querySelector('.item-titulo')?.textContent.trim() || '';
        const detalle = item.querySelector('.item-detalle')?.textContent.trim() || '';
        
        // Obtener el monto del span con aria-hidden (el que tiene el formato €XX.XX)
        const montoElement = item.querySelector('.item-monto [aria-hidden="true"]');
        let montoTexto = '';
        if (montoElement) {
            montoTexto = montoElement.textContent.trim();
        } else {
            // Fallback: obtener del elemento .item-monto directamente
            montoTexto = item.querySelector('.item-monto')?.textContent.trim() || '';
        }
        
        // Limpiar el texto del monto: quitar €, espacios, y reemplazar coma por punto
        const montoLimpio = montoTexto.replace(/€/g, '').replace(/\s/g, '').replace(',', '.');
        const monto = parseFloat(montoLimpio);
        
        if (isNaN(monto)) {
            console.error(`No se pudo parsear el monto del gasto "${titulo}": "${montoTexto}" -> "${montoLimpio}"`);
        }
        
        // Extraer quién pagó del detalle (formato: "Pagado por [nombre]")
        const nombreParcial = detalle.replace('Pagado por ', '').trim();
        
        // Buscar el nombre completo del amigo que coincida
        // Primero busca coincidencia exacta, luego busca si el nombre parcial está al inicio del nombre completo
        let quienPago = null;
        const amigoEncontrado = amigos.find(a => {
            const nombreCompleto = a.nombre;
            // Coincidencia exacta
            if (nombreCompleto === nombreParcial) return true;
            // El nombre completo empieza con el nombre parcial seguido de un espacio
            if (nombreCompleto.startsWith(nombreParcial + ' ')) return true;
            // También verificar sin distinguir mayúsculas/minúsculas
            if (nombreCompleto.toLowerCase().startsWith(nombreParcial.toLowerCase() + ' ')) return true;
            return false;
        });
        if (amigoEncontrado) {
            quienPago = amigoEncontrado.nombre;
        } else if (amigos.length > 0) {
            // Si no se encuentra pero hay amigos, usar el nombre parcial como fallback
            // pero solo si hay al menos un amigo que empiece con ese nombre
            const amigoParcial = amigos.find(a => 
                a.nombre.toLowerCase().startsWith(nombreParcial.toLowerCase())
            );
            if (amigoParcial) {
                quienPago = amigoParcial.nombre;
            } else {
                quienPago = nombreParcial;
                console.warn(`No se encontró amigo para "${nombreParcial}". Usando nombre parcial.`);
            }
        } else {
            quienPago = nombreParcial;
        }
        
        // Por defecto, todos los amigos participan (para gastos existentes)
        // Asegurarse de que los participantes sean un array válido
        const participantes = amigos.length > 0 ? amigos.map(a => a.nombre) : [];
        
        // Verificar que el monto sea un número válido
        if (isNaN(monto) || monto <= 0) {
            console.warn(`Gasto "${titulo}" tiene un monto inválido: ${montoTexto}`);
        }
        
        gastos.push({
            titulo: titulo,
            monto: monto,
            quienPago: quienPago,
            participantes: participantes
        });
    });
}

/**
 * Inicializa la aplicación
 */
function inicializarApp() {
    // Actualizar textos alternativos de todos los elementos existentes
    actualizarTextosAlternativos();
    
    // Agregar listeners a los botones de control del footer
    const botonesControl = document.querySelectorAll('.btn-control');
    botonesControl.forEach(boton => {
        boton.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            // Usar currentTarget para asegurar que siempre sea el <button> aunque se cliquee el <span> interno
            manejarClickControlFooter(e.currentTarget);
        });
    });

    // Agregar listeners a los botones del header de gastos
    const botonAgregarGasto = document.querySelector('#gastos-panel .btn-agregar-header');
    if (botonAgregarGasto) {
        botonAgregarGasto.addEventListener('click', () => {
            abrirModalGasto();
        });
    }

    // Agregar listeners a los botones del header de amigos
    const botonAgregarAmigo = document.querySelector('#amigos-panel .btn-agregar-header');
    if (botonAgregarAmigo) {
        botonAgregarAmigo.addEventListener('click', () => {
            abrirModalAmigo();
        });
    }

    const botonesPagarHeader = document.querySelectorAll('.btn-pagar-header');
    botonesPagarHeader.forEach(boton => {
        boton.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            pagarSaldosPendientes();
        });
    });

    // Agregar listeners a los botones de item de gastos (editar/eliminar)
    delegarEventosGastos();

    // Agregar listeners a los botones de item de amigos
    delegarEventosAmigos();

    // Items vacíos (si existen)
    const itemsVacios = document.querySelectorAll('.item-vacio');
    itemsVacios.forEach((item, index) => {
        item.setAttribute('tabindex', '0');
        item.setAttribute('role', 'button');
        item.setAttribute('aria-label', `Espacio ${index + 1} para agregar elemento`);
    });
}

// Variable para almacenar el handler de eventos de gastos
let handlerEventosGastos = null;

/**
 * Delega eventos para los botones de gastos (para elementos dinámicos)
 */
function delegarEventosGastos() {
    const listaGastos = document.getElementById('lista-gastos');
    if (!listaGastos) return;
    
    // Remover el listener anterior si existe para evitar duplicados
    if (handlerEventosGastos) {
        listaGastos.removeEventListener('click', handlerEventosGastos, true);
        listaGastos.removeEventListener('click', handlerEventosGastos, false);
    }
    
    // Crear el nuevo handler
    handlerEventosGastos = (e) => {
        let boton = e.target;
        
        // Si el clic fue en un span u otro elemento dentro del botón, buscar el botón padre
        if (!boton.classList.contains('btn-editar') && !boton.classList.contains('btn-eliminar')) {
            boton = e.target.closest('.btn-editar, .btn-eliminar');
        }
        
        if (!boton || !boton.classList.contains('btn-item')) return;
        
        const item = boton.closest('.item-gasto');
        if (!item) return;
        
        // Detener la propagación inmediatamente para evitar que otros listeners interfieran
        e.stopImmediatePropagation();
        e.preventDefault();
        
        if (boton.classList.contains('btn-editar')) {
            const index = Array.from(listaGastos.children).indexOf(item);
            editarGasto(index);
        } else if (boton.classList.contains('btn-eliminar')) {
            const index = Array.from(listaGastos.children).indexOf(item);
            eliminarGasto(index);
        }
    };
    
    // Agregar el listener en fase de captura para capturarlo antes que otros listeners
    listaGastos.addEventListener('click', handlerEventosGastos, true);
}

// Variable para almacenar el handler de eventos de amigos
let handlerEventosAmigos = null;

/**
 * Delega eventos para los botones de amigos (para elementos dinámicos)
 */
function delegarEventosAmigos() {
    const listaAmigos = document.getElementById('lista-amigos');
    if (!listaAmigos) {
        console.error('No se encontró la lista de amigos');
        return;
    }
    
    // Remover el listener anterior si existe para evitar duplicados
    if (handlerEventosAmigos) {
        listaAmigos.removeEventListener('click', handlerEventosAmigos, true);
        listaAmigos.removeEventListener('click', handlerEventosAmigos, false);
    }
    
    // Crear el nuevo handler
    handlerEventosAmigos = (e) => {
        // Buscar el botón, puede ser el botón mismo o un elemento dentro (span, etc.)
        let boton = e.target;
        
        // Si el clic fue en un span u otro elemento dentro del botón, buscar el botón padre
        if (!boton.classList.contains('btn-editar') && !boton.classList.contains('btn-eliminar')) {
            boton = e.target.closest('button.btn-editar, button.btn-eliminar');
        }
        
        if (!boton || !boton.classList.contains('btn-item')) return;
        
        const item = boton.closest('.item-amigo');
        if (!item) return;
        
        // Detener la propagación inmediatamente para evitar que otros listeners interfieran
        e.stopImmediatePropagation();
        e.preventDefault();
        
        // Obtener el índice del elemento en la lista del DOM
        const listaAmigos = document.getElementById('lista-amigos');
        if (!listaAmigos) {
            console.error('No se encontró la lista de amigos');
            return;
        }
        
        const index = Array.from(listaAmigos.children).indexOf(item);
        
        if (index === -1) {
            console.error('No se pudo encontrar el índice del elemento en la lista');
            return;
        }
        
        // Verificar que el índice sea válido
        if (index < 0 || index >= amigos.length) {
            console.error(`Índice inválido: ${index} (array tiene ${amigos.length} elementos)`);
            return;
        }
        
        // Obtener el nombre del amigo desde el DOM para verificación
        const nombreElement = item.querySelector('.item-titulo');
        const nombreEnDOM = nombreElement ? nombreElement.textContent.trim() : '';
        
        // Verificar que el nombre en el DOM coincida con el del array (opcional, para debugging)
        if (nombreEnDOM && amigos[index].nombre !== nombreEnDOM) {
            console.warn(`Advertencia: El nombre en el DOM ("${nombreEnDOM}") no coincide con el del array ("${amigos[index].nombre}") en el índice ${index}`);
        }
        
        // Ejecutar la acción correspondiente
        if (boton.classList.contains('btn-editar')) {
            editarAmigo(index);
        } else if (boton.classList.contains('btn-eliminar')) {
            eliminarAmigo(index);
        }
    };
    
    // Agregar el listener en fase de captura para capturarlo antes que otros listeners
    listaAmigos.addEventListener('click', handlerEventosAmigos, true);
}

/**
 * Inicializa la navegación entre pantallas (móvil)
 * Implementa patrón WAI-ARIA para tabs
 */
function inicializarNavegacion() {
    const botonesNav = document.querySelectorAll('.nav-btn');
    const tablists = document.querySelectorAll('[role="tablist"]');
    
    botonesNav.forEach(boton => {
        boton.addEventListener('click', (e) => {
            const panelDestino = e.currentTarget.getAttribute('data-panel');
            cambiarPanel(panelDestino);
        });
    });
    
    // Agregar navegación por teclado para tabs (WAI-ARIA)
    tablists.forEach(tablist => {
        tablist.addEventListener('keydown', (e) => {
            const tabs = Array.from(tablist.querySelectorAll('[role="tab"]'));
            const currentIndex = tabs.findIndex(tab => tab.getAttribute('aria-selected') === 'true');
            
            let newIndex = currentIndex;
            
            switch (e.key) {
                case 'ArrowLeft':
                case 'ArrowUp':
                    e.preventDefault();
                    newIndex = currentIndex > 0 ? currentIndex - 1 : tabs.length - 1;
                    break;
                case 'ArrowRight':
                case 'ArrowDown':
                    e.preventDefault();
                    newIndex = currentIndex < tabs.length - 1 ? currentIndex + 1 : 0;
                    break;
                case 'Home':
                    e.preventDefault();
                    newIndex = 0;
                    break;
                case 'End':
                    e.preventDefault();
                    newIndex = tabs.length - 1;
                    break;
                default:
                    return;
            }
            
            if (newIndex !== currentIndex) {
                const newTab = tabs[newIndex];
                const panelDestino = newTab.getAttribute('data-panel');
                cambiarPanel(panelDestino);
                newTab.focus();
            }
        });
    });
    
    // Establecer estado inicial de visibilidad de paneles
    const panelAmigos = document.getElementById('amigos-panel');
    if (panelAmigos && !document.body.classList.contains('view-amigos')) {
        panelAmigos.setAttribute('aria-hidden', 'true');
    }
}

/**
 * Cambia entre los paneles de Gastos y Amigos
 * @param {string} panel - 'gastos' o 'amigos'
 */
function cambiarPanel(panel) {
    const body = document.body;
    const todosLosBotonesNav = document.querySelectorAll('.nav-btn');
    const panelGastos = document.getElementById('gastos-panel');
    const panelAmigos = document.getElementById('amigos-panel');
    
    // Actualizar clase del body para la transición
    if (panel === 'amigos') {
        body.classList.add('view-amigos');
    } else {
        body.classList.remove('view-amigos');
    }
    
    // Actualizar estado de botones de navegación (tabs)
    todosLosBotonesNav.forEach(btn => {
        const btnPanel = btn.getAttribute('data-panel');
        const estaActivo = btnPanel === panel;
        
        if (estaActivo) {
            btn.classList.add('active');
            btn.setAttribute('aria-selected', 'true');
            btn.setAttribute('tabindex', '0');
        } else {
            btn.classList.remove('active');
            btn.setAttribute('aria-selected', 'false');
            btn.setAttribute('tabindex', '-1');
        }
    });
    
    // Actualizar visibilidad de paneles para lectores de pantalla
    if (panel === 'gastos') {
        panelGastos.removeAttribute('aria-hidden');
        panelAmigos.setAttribute('aria-hidden', 'true');
    } else {
        panelAmigos.removeAttribute('aria-hidden');
        panelGastos.setAttribute('aria-hidden', 'true');
    }
    
    // Anunciar cambio a lectores de pantalla
    const nombrePanel = panel === 'gastos' ? 'Gastos' : 'Amigos';
    anunciarCambio(`Mostrando panel de ${nombrePanel}`);
}

/**
 * Maneja el click en los botones de control del footer (tablet/desktop)
 * @param {HTMLElement} boton - El botón que fue clickeado
 */
function manejarClickControlFooter(boton) {
    if (!boton) {
        console.error('Botón no válido en manejarClickControlFooter');
        return;
    }
    
    // Encontrar el tipo de botón
    const esEliminarTodos = boton.classList.contains('btn-eliminar-todos');
    const esPagarFooter = boton.classList.contains('btn-pagar-footer');
    
    // Determinar en qué panel estamos
    const panel = boton.closest('.panel');
    if (!panel) {
        console.error('No se pudo encontrar el panel del botón');
        return;
    }
    
    const esAmigos = panel.id === 'amigos-panel';
    
    // Funcionalidad para gastos
    if (!esAmigos && esEliminarTodos) {
        eliminarTodosLosGastos();
    } else if (esAmigos && esEliminarTodos) {
        eliminarTodosLosAmigos();
    } else if (esPagarFooter) {
        pagarSaldosPendientes();
    }
}

/**
 * Muestra un feedback temporal al usuario
 * @param {HTMLElement} elemento - Elemento donde mostrar el feedback (opcional)
 * @param {string} mensaje - Mensaje a mostrar
 * @param {string} tipo - Tipo de mensaje: 'success' (verde) o 'error' (rojo)
 */
function mostrarFeedback(elemento, mensaje, tipo = 'success') {
    // Crear elemento de feedback temporal
    const feedback = document.createElement('div');
    feedback.textContent = mensaje;
    feedback.className = `feedback-mensaje feedback-${tipo}`;
    feedback.style.cssText = `
        position: fixed;
        top: 20px;
        left: 50%;
        transform: translateX(-50%);
        padding: 1rem 2rem;
        border-radius: 0.5rem;
        z-index: 10000;
        font-size: 1rem;
        font-weight: 500;
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        animation: slideDown 0.3s ease-out;
    `;
    feedback.setAttribute('role', 'alert');
    feedback.setAttribute('aria-live', 'polite');
    
    document.body.appendChild(feedback);
    
    // Eliminar después de 3 segundos
    setTimeout(() => {
        feedback.style.animation = 'slideUp 0.3s ease-out';
        setTimeout(() => {
            feedback.remove();
        }, 300);
    }, 3000);
}

/**
 * Utilidad para anunciar cambios a lectores de pantalla
 * Usa una región aria-live persistente para mejor compatibilidad
 * @param {string} mensaje - Mensaje a anunciar
 */
function anunciarCambio(mensaje) {
    const regionLive = document.getElementById('anuncios-live');
    
    if (regionLive) {
        // Limpiar primero para forzar que se anuncie el nuevo mensaje
        regionLive.textContent = '';
        
        // Usar setTimeout para asegurar que el cambio se detecte
        setTimeout(() => {
            regionLive.textContent = mensaje;
        }, 100);
        
        // Limpiar después de un tiempo
        setTimeout(() => {
            regionLive.textContent = '';
        }, 3000);
    } else {
        // Fallback: crear elemento temporal si no existe la región
        const anuncio = document.createElement('div');
        anuncio.setAttribute('role', 'status');
        anuncio.setAttribute('aria-live', 'polite');
        anuncio.setAttribute('aria-atomic', 'true');
        anuncio.className = 'sr-only';
        anuncio.textContent = mensaje;
        
        document.body.appendChild(anuncio);
        
        setTimeout(() => {
            anuncio.remove();
        }, 3000);
    }
}

/**
 * Actualiza los textos alternativos de todos los botones de acción
 * basándose en el contenido real de cada elemento.
 * 
 * Esta función busca TODOS los elementos .item-gasto y .item-amigo en el DOM
 * (hardcodeados o añadidos dinámicamente) y actualiza sus textos alternativos.
 * 
 * Debe llamarse después de añadir, modificar o eliminar elementos dinámicamente.
 */
function actualizarTextosAlternativos() {
    // Actualizar botones de gastos
    const itemsGastos = document.querySelectorAll('.item-gasto');
    
    itemsGastos.forEach(item => {
        const titulo = item.querySelector('.item-titulo');
        if (titulo) {
            const nombreGasto = titulo.textContent.trim();
            
            const botonesEditar = item.querySelectorAll('button.btn-editar');
            const botonesEliminar = item.querySelectorAll('button.btn-eliminar');
            
            botonesEditar.forEach(boton => {
                const textoAlt = `Editar gasto: ${nombreGasto}`;
                boton.setAttribute('aria-label', textoAlt);
                let srOnly = boton.querySelector('.sr-only');
                if (!srOnly) {
                    srOnly = document.createElement('span');
                    srOnly.className = 'sr-only';
                    boton.appendChild(srOnly);
                }
                srOnly.textContent = textoAlt;
            });
            
            botonesEliminar.forEach(boton => {
                const textoAlt = `Eliminar gasto: ${nombreGasto}`;
                boton.setAttribute('aria-label', textoAlt);
                let srOnly = boton.querySelector('.sr-only');
                if (!srOnly) {
                    srOnly = document.createElement('span');
                    srOnly.className = 'sr-only';
                    boton.appendChild(srOnly);
                }
                srOnly.textContent = textoAlt;
            });
        }
    });
    
    // Actualizar botones de amigos
    const itemsAmigos = document.querySelectorAll('.item-amigo');
    
    itemsAmigos.forEach(item => {
        const titulo = item.querySelector('.item-titulo');
        if (titulo) {
            const nombreAmigo = titulo.textContent.trim();
            
            const botonesEditar = item.querySelectorAll('button.btn-editar');
            const botonesEliminar = item.querySelectorAll('button.btn-eliminar');
            
            botonesEditar.forEach(boton => {
                const textoAlt = `Editar amigo: ${nombreAmigo}`;
                boton.setAttribute('aria-label', textoAlt);
                let srOnly = boton.querySelector('.sr-only');
                if (!srOnly) {
                    srOnly = document.createElement('span');
                    srOnly.className = 'sr-only';
                    boton.appendChild(srOnly);
                }
                srOnly.textContent = textoAlt;
            });
            
            botonesEliminar.forEach(boton => {
                const textoAlt = `Eliminar amigo: ${nombreAmigo}`;
                boton.setAttribute('aria-label', textoAlt);
                let srOnly = boton.querySelector('.sr-only');
                if (!srOnly) {
                    srOnly = document.createElement('span');
                    srOnly.className = 'sr-only';
                    boton.appendChild(srOnly);
                }
                srOnly.textContent = textoAlt;
            });
        }
    });
}

// ============================================
// Gestión de foco para modales (Focus Trap)
// ============================================

/**
 * Elementos focusables dentro de un contenedor
 */
const FOCUSABLE_SELECTORS = 'button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/**
 * Almacena el último elemento enfocado antes de abrir un modal
 */
let ultimoElementoEnfocado = null;

/**
 * Crea un focus trap dentro de un modal
 * @param {HTMLElement} modal - El elemento modal
 */
function crearFocusTrap(modal) {
    const elementosFocusables = modal.querySelectorAll(FOCUSABLE_SELECTORS);
    const primerElemento = elementosFocusables[0];
    const ultimoElemento = elementosFocusables[elementosFocusables.length - 1];
    
    // Manejador para atrapar el foco dentro del modal
    const trapFocus = (e) => {
        if (e.key !== 'Tab') return;
        
        if (e.shiftKey) {
            // Shift + Tab: ir hacia atrás
            if (document.activeElement === primerElemento) {
                e.preventDefault();
                ultimoElemento.focus();
            }
        } else {
            // Tab: ir hacia adelante
            if (document.activeElement === ultimoElemento) {
                e.preventDefault();
                primerElemento.focus();
            }
        }
    };
    
    modal.addEventListener('keydown', trapFocus);
    
    // Retornar función para limpiar el listener
    return () => {
        modal.removeEventListener('keydown', trapFocus);
    };
}

/**
 * Guarda el elemento actualmente enfocado
 */
function guardarFocoAnterior() {
    ultimoElementoEnfocado = document.activeElement;
}

/**
 * Restaura el foco al elemento anterior
 */
function restaurarFocoAnterior() {
    if (ultimoElementoEnfocado && ultimoElementoEnfocado.focus) {
        setTimeout(() => {
            ultimoElementoEnfocado.focus();
        }, 100);
    }
}

// ============================================
// Funcionalidad de Gastos
// ============================================

/**
 * Crea el modal para agregar/editar gastos
 */
function crearModalGasto() {
    // Verificar si el modal ya existe
    if (document.getElementById('modal-gasto')) {
        return;
    }
    
    const modal = document.createElement('div');
    modal.id = 'modal-gasto';
    modal.className = 'modal';
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-labelledby', 'modal-gasto-titulo');
    modal.setAttribute('aria-modal', 'true');
    modal.innerHTML = `
        <div class="modal-contenido">
            <div class="modal-header">
                <h2 id="modal-gasto-titulo">Agregar Gasto</h2>
                <button type="button" class="modal-cerrar" aria-label="Cerrar modal">
                    <span aria-hidden="true">×</span>
                </button>
            </div>
            <form id="form-gasto" class="modal-formulario">
                <div class="form-grupo">
                    <label for="gasto-titulo">Título del gasto</label>
                    <input type="text" id="gasto-titulo" name="titulo" required 
                           aria-required="true" aria-describedby="gasto-titulo-error">
                    <span id="gasto-titulo-error" class="error-mensaje" role="alert"></span>
                </div>
                <div class="form-grupo">
                    <label for="gasto-monto">Monto (€)</label>
                    <input type="number" id="gasto-monto" name="monto" step="0.01" min="0" required 
                           aria-required="true" aria-describedby="gasto-monto-error">
                    <span id="gasto-monto-error" class="error-mensaje" role="alert"></span>
                </div>
                <div class="form-grupo">
                    <label for="gasto-quien-pago">Pagado por</label>
                    <select id="gasto-quien-pago" name="quienPago" required 
                            aria-required="true" aria-describedby="gasto-quien-pago-error">
                        <option value="">Selecciona un amigo</option>
                    </select>
                    <span id="gasto-quien-pago-error" class="error-mensaje" role="alert"></span>
                </div>
                <div class="form-grupo">
                    <fieldset>
                        <legend>Participantes en el gasto</legend>
                        <div id="gasto-participantes" class="participantes-lista" role="group" aria-labelledby="participantes-legend">
                            <span id="participantes-legend" class="sr-only">Selecciona quién participa en este gasto</span>
                        </div>
                        <span id="gasto-participantes-error" class="error-mensaje" role="alert"></span>
                    </fieldset>
                </div>
                <div class="modal-acciones">
                    <button type="button" class="btn-cancelar" aria-label="Cancelar">Cancelar</button>
                    <button type="submit" class="btn-guardar" aria-label="Guardar gasto">Guardar</button>
                </div>
            </form>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Event listeners del modal
    const cerrarBtn = modal.querySelector('.modal-cerrar');
    const cancelarBtn = modal.querySelector('.btn-cancelar');
    const form = modal.querySelector('#form-gasto');
    const overlay = modal;
    
    cerrarBtn.addEventListener('click', cerrarModalGasto);
    cancelarBtn.addEventListener('click', cerrarModalGasto);
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
            cerrarModalGasto();
        }
    });
    
    // Usuario hace clic en el botón de guardar y se ejecuta la función guardarGasto()
    form.addEventListener('submit', (e) => {
        e.preventDefault();
        guardarGasto();
    });
    
    // Cerrar con Escape
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal.classList.contains('activo')) {
            cerrarModalGasto();
        }
    });
    
    // Llenar select y checkboxes de amigos
    actualizarOpcionesAmigos();
}

/**
 * Actualiza las opciones de amigos en el select y los checkboxes
 */
function actualizarOpcionesAmigos() {
    const selectQuienPago = document.getElementById('gasto-quien-pago');
    const contenedorParticipantes = document.getElementById('gasto-participantes');
    
    if (!selectQuienPago || !contenedorParticipantes) return;
    
    // Limpiar opciones existentes (excepto la primera)
    while (selectQuienPago.children.length > 1) {
        selectQuienPago.removeChild(selectQuienPago.lastChild);
    }
    
    // Limpiar checkboxes
    contenedorParticipantes.innerHTML = '';
    
    // Agregar opciones al select
    amigos.forEach(amigo => {
        const option = document.createElement('option');
        option.value = amigo.nombre;
        option.textContent = amigo.nombre;
        selectQuienPago.appendChild(option);
    });
    
    // Agregar checkboxes para participantes
    amigos.forEach(amigo => {
        const label = document.createElement('label');
        label.className = 'checkbox-label';
        label.innerHTML = `
            <input type="checkbox" name="participante" value="${escaparHTML(amigo.nombre)}" 
                   aria-label="Participante: ${escaparHTML(amigo.nombre)}">
            <span>${escaparHTML(amigo.nombre)}</span>
        `;
        contenedorParticipantes.appendChild(label);
    });
}

/**
 * Abre el modal para agregar un nuevo gasto
 */
function abrirModalGasto() {
    const modal = document.getElementById('modal-gasto');
    const titulo = modal.querySelector('#modal-gasto-titulo');
    const form = modal.querySelector('#form-gasto');
    
    // Guardar el foco actual antes de abrir el modal
    guardarFocoAnterior();
    
    // Actualizar opciones de amigos antes de abrir
    actualizarOpcionesAmigos();
    
    indiceGastoEditando = null;
    titulo.textContent = 'Agregar Gasto';
    form.reset();
    
    // Seleccionar todos los participantes por defecto
    const checkboxes = form.querySelectorAll('input[name="participante"]');
    checkboxes.forEach(checkbox => {
        checkbox.checked = true;
    });
    
    // Limpiar mensajes de error
    modal.querySelectorAll('.error-mensaje').forEach(error => {
        error.textContent = '';
    });
    
    modal.classList.add('activo');
    document.body.style.overflow = 'hidden';
    
    // Crear focus trap
    modal.limpiarFocusTrap = crearFocusTrap(modal);
    
    // Focus en el primer campo
    setTimeout(() => {
        modal.querySelector('#gasto-titulo').focus();
    }, 100);
    
    anunciarCambio('Modal para agregar gasto abierto');
}

/**
 * Abre el modal para editar un gasto existente
 * @param {number} index - Índice del gasto a editar
 */
function editarGasto(index) {
    if (index < 0 || index >= gastos.length) {
        console.error('Índice de gasto inválido');
        return;
    }
    
    const gasto = gastos[index];
    const modal = document.getElementById('modal-gasto');
    const titulo = modal.querySelector('#modal-gasto-titulo');
    const form = modal.querySelector('#form-gasto');
    
    // Guardar el foco actual antes de abrir el modal
    guardarFocoAnterior();
    
    // Actualizar opciones de amigos antes de abrir
    actualizarOpcionesAmigos();
    
    indiceGastoEditando = index;
    titulo.textContent = 'Editar Gasto';
    
    // Llenar el formulario con los datos del gasto
    form.querySelector('#gasto-titulo').value = gasto.titulo;
    form.querySelector('#gasto-monto').value = gasto.monto;
    form.querySelector('#gasto-quien-pago').value = gasto.quienPago || '';
    
    // Marcar checkboxes de participantes
    const checkboxes = form.querySelectorAll('input[name="participante"]');
    const participantes = gasto.participantes || [];
    checkboxes.forEach(checkbox => {
        checkbox.checked = participantes.includes(checkbox.value);
    });
    
    // Limpiar mensajes de error
    modal.querySelectorAll('.error-mensaje').forEach(error => {
        error.textContent = '';
    });
    
    modal.classList.add('activo');
    document.body.style.overflow = 'hidden';
    
    // Crear focus trap
    modal.limpiarFocusTrap = crearFocusTrap(modal);
    
    // Focus en el primer campo
    setTimeout(() => {
        modal.querySelector('#gasto-titulo').focus();
    }, 100);
    
    anunciarCambio(`Editando gasto: ${gasto.titulo}`);
}

/**
 * Cierra el modal de gastos
 */
function cerrarModalGasto() {
    const modal = document.getElementById('modal-gasto');
    
    if (!modal) {
        console.warn('No se encontró el modal de gastos para cerrar');
        return;
    }
    
    // Limpiar focus trap si existe
    if (modal.limpiarFocusTrap) {
        try {
            modal.limpiarFocusTrap();
        } catch (e) {
            console.warn('Error al limpiar focus trap:', e);
        }
        modal.limpiarFocusTrap = null;
    }
    
    modal.classList.remove('activo');
    document.body.style.overflow = '';
    indiceGastoEditando = null;
    
    // Restaurar el foco al elemento anterior
    restaurarFocoAnterior();
    
    anunciarCambio('Modal cerrado');
}

/**
 * Guarda un gasto (nuevo o editado)
 */
function guardarGasto() {

    // PASO 1: Obtiene los valores del formulario
    const form = document.getElementById('form-gasto');
    const titulo = form.querySelector('#gasto-titulo').value.trim();
    const monto = parseFloat(form.querySelector('#gasto-monto').value);
    const quienPago = form.querySelector('#gasto-quien-pago').value;

    // Obtener participantes seleccionados
    const checkboxesParticipantes = form.querySelectorAll('input[name="participante"]:checked');
    const participantes = Array.from(checkboxesParticipantes).map(cb => cb.value);
    
    // PASO 2: Valida los datos
    // - Título no vacío
    // - Monto válido y > 0
    // - Quién pagó seleccionado
    // - Al menos un participante

    // Validación
    let hayErrores = false;
    
    if (!titulo) {
        mostrarError('gasto-titulo', 'El título es requerido');
        hayErrores = true;
    } else {
        limpiarError('gasto-titulo');
    }
    
    if (isNaN(monto) || monto <= 0) {
        mostrarError('gasto-monto', 'El monto debe ser un número mayor a 0');
        hayErrores = true;
    } else {
        limpiarError('gasto-monto');
    }
    
    if (!quienPago) {
        mostrarError('gasto-quien-pago', 'Debe seleccionar quién pagó');
        hayErrores = true;
    } else {
        limpiarError('gasto-quien-pago');
    }
    
    if (participantes.length === 0) {
        mostrarError('gasto-participantes', 'Debe seleccionar al menos un participante');
        hayErrores = true;
    } else {
        limpiarError('gasto-participantes');
    }
    
    // PASO 3: Si hay errores, muestra mensajes y termina
    if (hayErrores) {
        mostrarFeedback(null, 'Ha habido un error al guardar el gasto', 'error');
        return;
    }
    
    // PASO 4: Obtener IDs de amigos
    const pagador = amigos.find(a => a.nombre === quienPago);
    if (!pagador) {
        mostrarError('gasto-quien-pago', 'Amigo no encontrado');
        mostrarFeedback(null, 'Ha habido un error al guardar el gasto', 'error');
        return;
    }
    
    const participantesIds = participantes.map(nombre => {
        const amigo = amigos.find(a => a.nombre === nombre);
        return amigo ? amigo.id : null;
    }).filter(id => id !== null);
    
    if (participantesIds.length === 0) {
        mostrarError('gasto-participantes', 'No se encontraron participantes válidos');
        mostrarFeedback(null, 'Ha habido un error al guardar el gasto', 'error');
        return;
    }
    
    // PASO 5: Guardar en el array local
    try {
        if (indiceGastoEditando === null) {
            // Agregar nuevo gasto
            const gasto = {
                id: Date.now(), // ID temporal basado en timestamp
                titulo: titulo,
                monto: monto,
                quienPago: quienPago,
                participantes: participantes
            };
            gastos.push(gasto);
            agregarGastoAlDOM(gasto);
            anunciarCambio(`Gasto "${titulo}" agregado`);
            mostrarFeedback(null, `Gasto "${titulo}" creado satisfactoriamente`, 'success');
        } else {
            // Editar gasto existente
            const gastoActual = gastos[indiceGastoEditando];
            const gasto = {
                id: gastoActual.id,
                titulo: titulo,
                monto: monto,
                quienPago: quienPago,
                participantes: participantes
            };
            gastos[indiceGastoEditando] = gasto;
            actualizarGastoEnDOM(gasto, indiceGastoEditando);
            anunciarCambio(`Gasto "${titulo}" actualizado`);
            mostrarFeedback(null, `Gasto "${titulo}" actualizado satisfactoriamente`, 'success');
        }
        
        // Actualizar balances de amigos (importante hacerlo después de actualizar el gasto)
        // Esto actualiza los balances de TODOS los amigos, incluyendo los nuevos participantes
        actualizarBalancesAmigos();
        
        actualizarTextosAlternativos();
    } catch (error) {
        console.error('Error al guardar el gasto:', error);
        mostrarFeedback(null, 'Ha habido un error al guardar el gasto', 'error');
    } finally {
        // Siempre cerrar el modal, incluso si hay errores
        cerrarModalGasto();
    }
}

/**
 * Muestra un mensaje de error en un campo del formulario
 * @param {string} campoId - ID del campo
 * @param {string} mensaje - Mensaje de error
 */
function mostrarError(campoId, mensaje) {
    const campo = document.getElementById(campoId);
    const errorElement = document.getElementById(`${campoId}-error`);
    if (errorElement) {
        errorElement.textContent = mensaje;
    }
    campo.setAttribute('aria-invalid', 'true');
}

/**
 * Limpia el mensaje de error de un campo
 * @param {string} campoId - ID del campo
 */
function limpiarError(campoId) {
    const campo = document.getElementById(campoId);
    const errorElement = document.getElementById(`${campoId}-error`);
    if (errorElement) {
        errorElement.textContent = '';
    }
    if (campo) {
        campo.removeAttribute('aria-invalid');
    }
}

/**
 * Elimina un gasto
 * @param {number} index - Índice del gasto a eliminar
 */
function eliminarGasto(index) {
    if (index < 0 || index >= gastos.length) {
        console.error('Índice de gasto inválido');
        return;
    }
    
    const gasto = gastos[index];
    
    // Mostrar modal de confirmación
    mostrarModalConfirmacion(
        `¿Estás seguro de que quieres eliminar el gasto "${gasto.titulo}"?`,
        () => {
            try {
                gastos.splice(index, 1);
                eliminarGastoDelDOM(index);
                
                // Actualizar balances de amigos
                actualizarBalancesAmigos();
                
                actualizarTextosAlternativos();
                anunciarCambio(`Gasto "${gasto.titulo}" eliminado`);
                mostrarFeedback(null, `Gasto "${gasto.titulo}" eliminado satisfactoriamente`, 'success');
            } catch (error) {
                console.error('Error al eliminar el gasto:', error);
                mostrarFeedback(null, 'Ha habido un error al eliminar el gasto', 'error');
            }
        }
    );
}

/**
 * Elimina todos los gastos
 */
function eliminarTodosLosGastos() {
    if (gastos.length === 0) {
        mostrarFeedback(document.querySelector('#gastos-panel .btn-eliminar-todos'), 'No hay gastos para eliminar', 'error');
        return;
    }
    
    mostrarModalConfirmacion(
        `¿Estás seguro de que quieres eliminar todos los ${gastos.length} gastos?`,
        () => {
            try {
                gastos = [];
                renderizarGastos();
                
                // Actualizar balances de amigos
                actualizarBalancesAmigos();
                
                actualizarTextosAlternativos();
                anunciarCambio('Todos los gastos han sido eliminados');
                mostrarFeedback(null, 'Todos los gastos eliminados satisfactoriamente', 'success');
            } catch (error) {
                console.error('Error al eliminar todos los gastos:', error);
                mostrarFeedback(null, 'Ha habido un error al eliminar todos los gastos', 'error');
            }
        }
    );
}

/**
 * Renderiza todos los gastos en el DOM
 */
function renderizarGastos() {
   
    const listaGastos = document.getElementById('lista-gastos');
    if (!listaGastos) return;
    
    // Limpiar lista
    listaGastos.innerHTML = '';
    
    // Agregar cada gasto
    gastos.forEach((gasto, index) => {
        agregarGastoAlDOM(gasto, index);
    });
}

//Crea el elemento y lo inserta en la lista de gastos
/**
 * Agrega un gasto al DOM
 * @param {Object} gasto - Objeto gasto
 * @param {number} index - Índice del gasto (opcional, se calcula si no se proporciona)
 */
function agregarGastoAlDOM(gasto, index = null) {
     // 1. Obtiene la lista de gastos del DOM
    const listaGastos = document.getElementById('lista-gastos');
    if (!listaGastos) return;
    
    if (index === null) {
        index = gastos.length - 1;
    }
    
    // 2. Crea un nuevo elemento <li>
    const li = document.createElement('li');
    li.className = 'item-gasto';

     // 3. Llena el HTML con los datos del gasto
    // Generar descripción accesible del monto
    const montoEntero = Math.floor(gasto.monto);
    const montoCentimos = Math.round((gasto.monto - montoEntero) * 100);
    let montoAccesible = `Monto: ${montoEntero} euros`;
    if (montoCentimos > 0) {
        montoAccesible += ` con ${montoCentimos} céntimos`;
    }
    
    li.innerHTML = `
        <div class="item-contenido">
            <span class="item-titulo">${escaparHTML(gasto.titulo)}</span>
            <span class="item-detalle">Pagado por ${escaparHTML(gasto.quienPago)}</span>
        </div>
        <div class="item-derecha">
            <span class="item-monto"><span class="sr-only">${montoAccesible}</span><span aria-hidden="true">€${gasto.monto.toFixed(2)}</span></span>
            <div class="item-acciones" role="group" aria-label="Acciones para ${escaparHTML(gasto.titulo)}">
                <button type="button" class="btn-item btn-editar" aria-label="Editar gasto: ${escaparHTML(gasto.titulo)}">
                    <span aria-hidden="true">✏️</span>
                </button>
                <button type="button" class="btn-item btn-eliminar" aria-label="Eliminar gasto: ${escaparHTML(gasto.titulo)}">
                    <span aria-hidden="true">🗑️</span>
                </button>
            </div>
        </div>
    `;
    
    // Insertar en la posición correcta
    if (index < listaGastos.children.length) {
        listaGastos.insertBefore(li, listaGastos.children[index]);
    } else {
        // 4. Agrega el elemento a la lista
        listaGastos.appendChild(li);
    }
}

/**
 * Actualiza un gasto en el DOM
 * @param {Object} gasto - Objeto gasto actualizado
 * @param {number} index - Índice del gasto
 */
function actualizarGastoEnDOM(gasto, index) {
    const listaGastos = document.getElementById('lista-gastos');
    if (!listaGastos || index < 0 || index >= listaGastos.children.length) {
        return;
    }
    
    const item = listaGastos.children[index];
    item.querySelector('.item-titulo').textContent = gasto.titulo;
    item.querySelector('.item-detalle').textContent = `Pagado por ${gasto.quienPago}`;
    item.querySelector('.item-monto').textContent = `€${gasto.monto.toFixed(2)}`;
    
    // Actualizar aria-labels
    const botonEditar = item.querySelector('.btn-editar');
    const botonEliminar = item.querySelector('.btn-eliminar');
    const textoAltEditar = `Editar gasto: ${gasto.titulo}`;
    const textoAltEliminar = `Eliminar gasto: ${gasto.titulo}`;
    
    botonEditar.setAttribute('aria-label', textoAltEditar);
    botonEditar.querySelector('.sr-only').textContent = textoAltEditar;
    
    botonEliminar.setAttribute('aria-label', textoAltEliminar);
    botonEliminar.querySelector('.sr-only').textContent = textoAltEliminar;
}

/**
 * Elimina un gasto del DOM
 * @param {number} index - Índice del gasto a eliminar
 */
function eliminarGastoDelDOM(index) {
    const listaGastos = document.getElementById('lista-gastos');
    if (!listaGastos || index < 0 || index >= listaGastos.children.length) {
        return;
    }
    
    listaGastos.children[index].remove();
}

/**
 * Escapa HTML para prevenir XSS
 * @param {string} texto - Texto a escapar
 * @returns {string} Texto escapado
 */
function escaparHTML(texto) {
    const div = document.createElement('div');
    div.textContent = texto;
    return div.innerHTML;
}

// ============================================
// Modal de Confirmación
// ============================================

/**
 * Crea el modal de confirmación
 */
function crearModalConfirmacion() {
    // Verificar si el modal ya existe
    if (document.getElementById('modal-confirmacion')) {
        return;
    }
    
    const modal = document.createElement('div');
    modal.id = 'modal-confirmacion';
    modal.className = 'modal';
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-labelledby', 'modal-confirmacion-titulo');
    modal.setAttribute('aria-modal', 'true');
    modal.innerHTML = `
        <div class="modal-contenido modal-confirmacion-contenido">
            <div class="modal-header">
                <h2 id="modal-confirmacion-titulo">Confirmar acción</h2>
            </div>
            <div class="modal-confirmacion-cuerpo">
                <p id="modal-confirmacion-mensaje"></p>
            </div>
            <div class="modal-acciones modal-confirmacion-acciones">
                <button type="button" class="btn-cancelar" aria-label="Cancelar">Cancelar</button>
                <button type="button" class="btn-confirmar-eliminar" aria-label="Confirmar eliminación">Eliminar</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Event listeners del modal
    const cancelarBtn = modal.querySelector('.btn-cancelar');
    const confirmarBtn = modal.querySelector('.btn-confirmar-eliminar');
    const overlay = modal;
    
    cancelarBtn.addEventListener('click', cerrarModalConfirmacion);
    confirmarBtn.addEventListener('click', () => {
        try {
            if (modal.callbackConfirmacion) {
                modal.callbackConfirmacion();
            }
        } catch (error) {
            console.error('Error en el callback de confirmación:', error);
        } finally {
            // Siempre cerrar el modal, incluso si hay errores
            cerrarModalConfirmacion();
        }
    });
    
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
            cerrarModalConfirmacion();
        }
    });
    
    // Cerrar con Escape
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal.classList.contains('activo')) {
            cerrarModalConfirmacion();
        }
    });
}

/**
 * Muestra el modal de confirmación
 * @param {string} mensaje - Mensaje a mostrar
 * @param {Function} callback - Función a ejecutar si se confirma
 * @param {boolean} soloInformacion - Si es true, solo muestra el botón cancelar
 */
function mostrarModalConfirmacion(mensaje, callback, soloInformacion = false) {
    const modal = document.getElementById('modal-confirmacion');
    const mensajeElement = document.getElementById('modal-confirmacion-mensaje');
    const botonConfirmar = modal.querySelector('.btn-confirmar-eliminar');
    
    if (!modal || !mensajeElement) return;
    
    // Guardar el foco actual antes de abrir el modal
    guardarFocoAnterior();
    
    mensajeElement.textContent = mensaje;
    modal.callbackConfirmacion = callback;
    
    // Ocultar o mostrar el botón de confirmar según el caso
    if (soloInformacion) {
        botonConfirmar.style.display = 'none';
    } else {
        botonConfirmar.style.display = '';
    }
    
    modal.classList.add('activo');
    document.body.style.overflow = 'hidden';
    
    // Crear focus trap
    modal.limpiarFocusTrap = crearFocusTrap(modal);
    
    // Focus en el botón de cancelar por defecto
    setTimeout(() => {
        modal.querySelector('.btn-cancelar').focus();
    }, 100);
    
    anunciarCambio('Modal de confirmación abierto');
}

/**
 * Cierra el modal de confirmación
 */
function cerrarModalConfirmacion() {
    const modal = document.getElementById('modal-confirmacion');
    if (!modal) return;
    
    // Limpiar focus trap si existe
    if (modal.limpiarFocusTrap) {
        modal.limpiarFocusTrap();
        modal.limpiarFocusTrap = null;
    }
    
    modal.classList.remove('activo');
    document.body.style.overflow = '';
    modal.callbackConfirmacion = null;
    
    // Restaurar el foco al elemento anterior
    restaurarFocoAnterior();
    
    anunciarCambio('Modal de confirmación cerrado');
}

// ============================================
// Funcionalidad de Amigos
// ============================================

/**
 * Crea el modal para agregar/editar amigos
 */
function crearModalAmigo() {
    // Verificar si el modal ya existe
    if (document.getElementById('modal-amigo')) {
        return;
    }
    
    const modal = document.createElement('div');
    modal.id = 'modal-amigo';
    modal.className = 'modal';
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-labelledby', 'modal-amigo-titulo');
    modal.setAttribute('aria-modal', 'true');
    modal.innerHTML = `
        <div class="modal-contenido">
            <div class="modal-header">
                <h2 id="modal-amigo-titulo">Agregar Amigo</h2>
                <button type="button" class="modal-cerrar" aria-label="Cerrar modal">
                    <span aria-hidden="true">×</span>
                </button>
            </div>
            <form id="form-amigo" class="modal-formulario">
                <div class="form-grupo">
                    <label for="amigo-nombre">Nombre del amigo</label>
                    <input type="text" id="amigo-nombre" name="nombre" required 
                           aria-required="true" aria-describedby="amigo-nombre-error">
                    <span id="amigo-nombre-error" class="error-mensaje" role="alert"></span>
                </div>
                <div class="modal-acciones">
                    <button type="button" class="btn-cancelar" aria-label="Cancelar">Cancelar</button>
                    <button type="submit" class="btn-guardar" aria-label="Guardar amigo">Guardar</button>
                </div>
            </form>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Event listeners del modal
    const cerrarBtn = modal.querySelector('.modal-cerrar');
    const cancelarBtn = modal.querySelector('.btn-cancelar');
    const form = modal.querySelector('#form-amigo');
    const overlay = modal;
    
    cerrarBtn.addEventListener('click', cerrarModalAmigo);
    cancelarBtn.addEventListener('click', cerrarModalAmigo);
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
            cerrarModalAmigo();
        }
    });
    
    form.addEventListener('submit', (e) => {
        e.preventDefault();
        guardarAmigo();
    });
    
    // Cerrar con Escape
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal.classList.contains('activo')) {
            cerrarModalAmigo();
        }
    });
}

/**
 * Abre el modal para agregar un nuevo amigo
 */
function abrirModalAmigo() {
    const modal = document.getElementById('modal-amigo');
    const titulo = modal.querySelector('#modal-amigo-titulo');
    const form = modal.querySelector('#form-amigo');
    
    // Guardar el foco actual antes de abrir el modal
    guardarFocoAnterior();
    
    indiceAmigoEditando = null;
    titulo.textContent = 'Agregar Amigo';
    form.reset();
    
    // Limpiar mensajes de error
    modal.querySelectorAll('.error-mensaje').forEach(error => {
        error.textContent = '';
    });
    
    modal.classList.add('activo');
    document.body.style.overflow = 'hidden';
    
    // Crear focus trap
    modal.limpiarFocusTrap = crearFocusTrap(modal);
    
    // Focus en el primer campo
    setTimeout(() => {
        modal.querySelector('#amigo-nombre').focus();
    }, 100);
    
    anunciarCambio('Modal para agregar amigo abierto');
}

/**
 * Abre el modal para editar un amigo existente
 * @param {number} index - Índice del amigo a editar
 */
function editarAmigo(index) {
    if (index < 0 || index >= amigos.length) {
        console.error('Índice de amigo inválido');
        return;
    }
    
    const amigo = amigos[index];
    const modal = document.getElementById('modal-amigo');
    const titulo = modal.querySelector('#modal-amigo-titulo');
    const form = modal.querySelector('#form-amigo');
    
    // Guardar el foco actual antes de abrir el modal
    guardarFocoAnterior();
    
    indiceAmigoEditando = index;
    titulo.textContent = 'Editar Amigo';
    
    // Llenar el formulario con los datos del amigo
    form.querySelector('#amigo-nombre').value = amigo.nombre;
    
    // Limpiar mensajes de error
    modal.querySelectorAll('.error-mensaje').forEach(error => {
        error.textContent = '';
    });
    
    modal.classList.add('activo');
    document.body.style.overflow = 'hidden';
    
    // Crear focus trap
    modal.limpiarFocusTrap = crearFocusTrap(modal);
    
    // Focus en el primer campo
    setTimeout(() => {
        modal.querySelector('#amigo-nombre').focus();
    }, 100);
    
    anunciarCambio(`Editando amigo: ${amigo.nombre}`);
}

/**
 * Cierra el modal de amigos
 */
function cerrarModalAmigo() {
    const modal = document.getElementById('modal-amigo');
    
    // Limpiar focus trap si existe
    if (modal.limpiarFocusTrap) {
        modal.limpiarFocusTrap();
        modal.limpiarFocusTrap = null;
    }
    
    modal.classList.remove('activo');
    document.body.style.overflow = '';
    indiceAmigoEditando = null;
    
    // Restaurar el foco al elemento anterior
    restaurarFocoAnterior();
    
    anunciarCambio('Modal cerrado');
}

/**
 * Guarda un amigo (nuevo o editado)
 */
function guardarAmigo() {
    const form = document.getElementById('form-amigo');
    const nombre = form.querySelector('#amigo-nombre').value.trim();
    
    // Validación
    let hayErrores = false;
    
    if (!nombre) {
        mostrarError('amigo-nombre', 'El nombre es requerido');
        hayErrores = true;
    } else {
        limpiarError('amigo-nombre');
    }
    
    // Verificar que no exista otro amigo con el mismo nombre (excepto si es edición)
    const nombreExistente = amigos.findIndex((a, idx) => 
        a.nombre.toLowerCase() === nombre.toLowerCase() && 
        (indiceAmigoEditando === null || a.id !== amigos[indiceAmigoEditando].id)
    );
    
    if (nombreExistente !== -1) {
        mostrarError('amigo-nombre', 'Ya existe un amigo con ese nombre');
        hayErrores = true;
    } else if (!hayErrores) {
        limpiarError('amigo-nombre');
    }
    
    if (hayErrores) {
        mostrarFeedback(null, 'Ha habido un error al guardar el amigo', 'error');
        return;
    }
    
    if (indiceAmigoEditando === null) {
        // Agregar nuevo amigo
        const amigo = {
            id: Date.now(), // ID temporal basado en timestamp
            nombre: nombre
        };
        amigos.push(amigo);
        agregarAmigoAlDOM(amigo);
        anunciarCambio(`Amigo "${nombre}" agregado`);
        mostrarFeedback(null, `Amigo "${nombre}" creado satisfactoriamente`, 'success');
    } else {
        // Editar amigo existente
        const nombreAnterior = amigos[indiceAmigoEditando].nombre;
        const amigoEditado = amigos[indiceAmigoEditando];
        amigoEditado.nombre = nombre;
        
        // Actualizar referencias en gastos
        actualizarReferenciasAmigoEnGastos(nombreAnterior, nombre);
        
        // Actualizar en el DOM (pasar el nombre anterior para buscar correctamente)
        actualizarAmigoEnDOM(amigoEditado, indiceAmigoEditando, nombreAnterior);
        anunciarCambio(`Amigo actualizado`);
        mostrarFeedback(null, `Amigo "${nombre}" actualizado satisfactoriamente`, 'success');
    }
    
    // Cerrar el modal primero para que desaparezca inmediatamente
    cerrarModalAmigo();
    
    // Actualizar opciones de amigos en el modal de gastos
    actualizarOpcionesAmigos();
    
    // Actualizar balances
    actualizarBalancesAmigos();
    
    actualizarTextosAlternativos();
}

/**
 * Actualiza las referencias de un amigo en los gastos cuando se edita el nombre
 * @param {string} nombreAnterior - Nombre anterior del amigo
 * @param {string} nombreNuevo - Nombre nuevo del amigo
 */
function actualizarReferenciasAmigoEnGastos(nombreAnterior, nombreNuevo) {
    gastos.forEach(gasto => {
        // Actualizar "quienPago"
        if (gasto.quienPago === nombreAnterior) {
            gasto.quienPago = nombreNuevo;
        }
        
        // Actualizar en participantes
        const indexParticipante = gasto.participantes.indexOf(nombreAnterior);
        if (indexParticipante !== -1) {
            gasto.participantes[indexParticipante] = nombreNuevo;
        }
    });
    
    // Re-renderizar gastos para actualizar el DOM
    renderizarGastos();
}

/**
 * Calcula el balance de un amigo usando una lista específica de gastos
 * @param {string} nombreAmigo - Nombre del amigo
 * @param {Array} listaGastos - Lista de gastos a usar para el cálculo
 * @returns {number} Balance del amigo
 */
function calcularBalanceAmigoBase(nombreAmigo, listaGastos) {
    let balance = 0;
    listaGastos.forEach(gasto => {
        if (!gasto || typeof gasto.monto !== 'number' || isNaN(gasto.monto)) {
            return;
        }
        
        const tieneParticipantes = gasto.participantes && Array.isArray(gasto.participantes) && gasto.participantes.length > 0;
        
        if (gasto.quienPago === nombreAmigo) {
            balance += gasto.monto;
        }
        
        if (tieneParticipantes && gasto.participantes.includes(nombreAmigo)) {
            const parte = gasto.monto / gasto.participantes.length;
            balance -= parte;
        }
    });
    
    return Math.round(balance * 100) / 100;
}

/**
 * Calcula el balance de un amigo
 * @param {string} nombreAmigo - Nombre del amigo
 * @returns {number} Balance del amigo
 */
function calcularBalanceAmigo(nombreAmigo) {
    let balance = 0;
    gastos.forEach(gasto => {
        // Verificar que el gasto tenga los campos necesarios y sean válidos
        if (!gasto || typeof gasto.monto !== 'number' || isNaN(gasto.monto)) {
            console.warn('Gasto inválido encontrado:', gasto);
            return;
        }
        
        // Verificar si el gasto tiene participantes
        const tieneParticipantes = gasto.participantes && Array.isArray(gasto.participantes) && gasto.participantes.length > 0;
        
        if (gasto.quienPago === nombreAmigo) {
            // Suma el monto total que pagó
            balance += gasto.monto;
        }
        
        if (tieneParticipantes) {
            // Verificar si el amigo participa en este gasto
            if (gasto.participantes.includes(nombreAmigo)) {
                // Resta su parte del gasto (dividido entre todos los participantes)
                const parte = gasto.monto / gasto.participantes.length;
                balance -= parte;
            }
        }
        // Si no tiene participantes pero el amigo pagó, solo se cuenta el crédito (ya sumado arriba)
        // Esto permite que los gastos de "pago de saldo" funcionen correctamente
    });
    
    // Redondear para evitar problemas de precisión de punto flotante
    return Math.round(balance * 100) / 100;
}

/**
 * Elimina un amigo
 * @param {number} index - Índice del amigo a eliminar
 */
function eliminarAmigo(index) {
    if (index < 0 || index >= amigos.length) {
        console.error('Índice de amigo inválido');
        return;
    }
    
    const amigo = amigos[index];
    
    // Calcular el balance del amigo
    const balance = calcularBalanceAmigo(amigo.nombre);
    
    // Verificar si tiene saldo pendiente (balance diferente de 0)
    if (Math.abs(balance) > 0.01) {
        const textoBalance = balance > 0 ? `debe recibir €${balance.toFixed(2)}` : `debe pagar €${Math.abs(balance).toFixed(2)}`;
        mostrarModalConfirmacion(
            `No se puede eliminar "${amigo.nombre}" porque tiene saldo pendiente (${textoBalance}).`,
            () => {},
            true // Solo información, sin botón eliminar
        );
        return;
    }
    
    // Mostrar modal de confirmación
    mostrarModalConfirmacion(
        `¿Estás seguro de que quieres eliminar a "${amigo.nombre}"?`,
        () => {
            try {
                amigos.splice(index, 1);
                eliminarAmigoDelDOM(index);
                
                actualizarOpcionesAmigos();
                actualizarBalancesAmigos();
                actualizarTextosAlternativos();
                anunciarCambio(`Amigo "${amigo.nombre}" eliminado`);
                mostrarFeedback(null, `Amigo "${amigo.nombre}" eliminado satisfactoriamente`, 'success');
            } catch (error) {
                console.error('Error al eliminar el amigo:', error);
                mostrarFeedback(null, 'Ha habido un error al eliminar el amigo', 'error');
            }
        }
    );
}

/**
 * Elimina todos los amigos
 */
function eliminarTodosLosAmigos() {
    if (amigos.length === 0) {
        mostrarFeedback(document.querySelector('#amigos-panel .btn-eliminar-todos'), 'No hay amigos para eliminar', 'error');
        return;
    }
    
    // Verificar si hay amigos con saldo pendiente
    const amigosConSaldo = amigos.filter(amigo => {
        const balance = calcularBalanceAmigo(amigo.nombre);
        return Math.abs(balance) > 0.01;
    });
    
    if (amigosConSaldo.length > 0) {
        mostrarModalConfirmacion(
            `No se pueden eliminar todos los amigos porque ${amigosConSaldo.length} amigo${amigosConSaldo.length !== 1 ? 's tienen' : ' tiene'} saldo pendiente.`,
            () => {},
            true // Solo información, sin botón eliminar
        );
        return;
    }
    
    mostrarModalConfirmacion(
        `¿Estás seguro de que quieres eliminar todos los ${amigos.length} amigos?`,
        () => {
            try {
                amigos = [];
                renderizarAmigos();
                
                actualizarOpcionesAmigos();
                actualizarTextosAlternativos();
                anunciarCambio('Todos los amigos han sido eliminados');
                mostrarFeedback(null, 'Todos los amigos eliminados satisfactoriamente', 'success');
            } catch (error) {
                console.error('Error al eliminar todos los amigos:', error);
                mostrarFeedback(null, 'Ha habido un error al eliminar todos los amigos', 'error');
            }
        }
    );
}

/**
 * Renderiza todos los amigos en el DOM
 */
function renderizarAmigos() {
    const listaAmigos = document.getElementById('lista-amigos');
    if (!listaAmigos) return;
    
    // Limpiar lista
    listaAmigos.innerHTML = '';
    
    // Agregar cada amigo
    amigos.forEach((amigo, index) => {
        agregarAmigoAlDOM(amigo, index);
    });
}

/**
 * Agrega un amigo al DOM
 * @param {Object} amigo - Objeto amigo
 * @param {number} index - Índice del amigo (opcional, se calcula si no se proporciona)
 */
function agregarAmigoAlDOM(amigo, index = null) {
    const listaAmigos = document.getElementById('lista-amigos');
    if (!listaAmigos) return;
    
    if (index === null) {
        index = amigos.length - 1;
    }
    
    // Calcular número de gastos compartidos (gastos donde participa)
    const gastosCompartidos = gastos.filter(gasto => 
        gasto.participantes.includes(amigo.nombre)
    ).length;
    
    // Calcular balance usando la función centralizada
    const balance = calcularBalanceAmigo(amigo.nombre);
    
    // Determinar clase de balance y texto accesible
    let claseBalance = 'neutral';
    let textoBalance = `€${Math.abs(balance).toFixed(2)}`;
    let balanceAccesible = 'Balance neutro: sin saldo pendiente';
    
    // Generar descripción accesible del balance
    const balanceEntero = Math.floor(Math.abs(balance));
    const balanceCentimos = Math.round((Math.abs(balance) - balanceEntero) * 100);
    let cantidadAccesible = `${balanceEntero} euros`;
    if (balanceCentimos > 0) {
        cantidadAccesible += ` con ${balanceCentimos} céntimos`;
    }
    
    if (balance > 0.01) {
        claseBalance = 'positivo';
        textoBalance = `+${textoBalance}`;
        balanceAccesible = `Balance positivo: le deben ${cantidadAccesible}`;
    } else if (balance < -0.01) {
        claseBalance = 'negativo';
        textoBalance = `-${textoBalance}`;
        balanceAccesible = `Balance negativo: debe ${cantidadAccesible}`;
    } else {
        textoBalance = '€0.00';
    }
    
    const li = document.createElement('li');
    li.className = 'item-amigo';
    li.innerHTML = `
        <div class="item-contenido">
            <span class="item-titulo">${escaparHTML(amigo.nombre)}</span>
            <span class="item-detalle">${gastosCompartidos} gasto${gastosCompartidos !== 1 ? 's' : ''} compartido${gastosCompartidos !== 1 ? 's' : ''}</span>
        </div>
        <div class="item-derecha">
            <span class="item-balance ${claseBalance}"><span class="sr-only">${balanceAccesible}</span><span aria-hidden="true">${textoBalance}</span></span>
            <div class="item-acciones" role="group" aria-label="Acciones para ${escaparHTML(amigo.nombre)}">
                <button type="button" class="btn-item btn-editar" aria-label="Editar amigo: ${escaparHTML(amigo.nombre)}">
                    <span aria-hidden="true">✏️</span>
                </button>
                <button type="button" class="btn-item btn-eliminar" aria-label="Eliminar amigo: ${escaparHTML(amigo.nombre)}">
                    <span aria-hidden="true">🗑️</span>
                </button>
            </div>
        </div>
    `;
    
    // Insertar en la posición correcta
    if (index < listaAmigos.children.length) {
        listaAmigos.insertBefore(li, listaAmigos.children[index]);
    } else {
        listaAmigos.appendChild(li);
    }
}

/**
 * Actualiza un amigo en el DOM
 * @param {Object} amigo - Objeto amigo actualizado
 * @param {number} index - Índice del amigo
 * @param {string} nombreAnterior - Nombre anterior del amigo (opcional, para buscar en el DOM)
 */
function actualizarAmigoEnDOM(amigo, index, nombreAnterior = null) {
    const listaAmigos = document.getElementById('lista-amigos');
    if (!listaAmigos) {
        console.warn('No se encontró la lista de amigos');
        return;
    }
    
    // Buscar el elemento: primero por índice, luego por nombre anterior si se proporciona
    let item = null;
    
    // Primero intentar por índice (más confiable)
    if (index >= 0 && index < listaAmigos.children.length) {
        item = listaAmigos.children[index];
        // Verificar que el nombre coincida con el nombre anterior o el nuevo
        const nombreEnDOM = item.querySelector('.item-titulo')?.textContent.trim();
        if (nombreAnterior && nombreEnDOM !== nombreAnterior && nombreEnDOM !== amigo.nombre) {
            // Si no coincide, buscar por nombre anterior
            item = Array.from(listaAmigos.children).find(li => {
                const nombre = li.querySelector('.item-titulo')?.textContent.trim();
                return nombre === nombreAnterior;
            });
        }
    }
    
    // Si no se encontró por índice, buscar por nombre anterior
    if (!item && nombreAnterior) {
        item = Array.from(listaAmigos.children).find(li => {
            const nombre = li.querySelector('.item-titulo')?.textContent.trim();
            return nombre === nombreAnterior;
        });
    }
    
    // Si aún no se encontró, buscar por el nombre nuevo (último recurso)
    if (!item) {
        item = Array.from(listaAmigos.children).find(li => {
            const nombre = li.querySelector('.item-titulo')?.textContent.trim();
            return nombre === amigo.nombre;
        });
    }
    
    // Si aún no se encontró, intentar por índice directamente
    if (!item && index >= 0 && index < listaAmigos.children.length) {
        item = listaAmigos.children[index];
    }
    
    if (!item) {
        console.warn(`No se encontró el elemento del amigo. Índice: ${index}, Nombre anterior: ${nombreAnterior}, Nombre nuevo: ${amigo.nombre}`);
        return;
    }
    
    // Recalcular gastos compartidos y balance
    const gastosCompartidos = gastos.filter(gasto => 
        gasto.participantes && gasto.participantes.includes(amigo.nombre)
    ).length;
    
    const balance = calcularBalanceAmigo(amigo.nombre);
    
    let claseBalance = 'neutral';
    let textoBalance = `€${Math.abs(balance).toFixed(2)}`;
    let balanceAccesible = 'Balance neutro: sin saldo pendiente';
    
    // Generar descripción accesible del balance
    const balanceEntero = Math.floor(Math.abs(balance));
    const balanceCentimos = Math.round((Math.abs(balance) - balanceEntero) * 100);
    let cantidadAccesible = `${balanceEntero} euros`;
    if (balanceCentimos > 0) {
        cantidadAccesible += ` con ${balanceCentimos} céntimos`;
    }
    
    if (balance > 0.01) {
        claseBalance = 'positivo';
        textoBalance = `+${textoBalance}`;
        balanceAccesible = `Balance positivo: le deben ${cantidadAccesible}`;
    } else if (balance < -0.01) {
        claseBalance = 'negativo';
        textoBalance = `-${textoBalance}`;
        balanceAccesible = `Balance negativo: debe ${cantidadAccesible}`;
    } else {
        textoBalance = '€0.00';
    }
    
    // Actualizar el elemento encontrado
    const tituloElement = item.querySelector('.item-titulo');
    if (tituloElement) {
        tituloElement.textContent = amigo.nombre;
    }
    
    const detalleElement = item.querySelector('.item-detalle');
    if (detalleElement) {
        detalleElement.textContent = `${gastosCompartidos} gasto${gastosCompartidos !== 1 ? 's' : ''} compartido${gastosCompartidos !== 1 ? 's' : ''}`;
    }
    
    const balanceElement = item.querySelector('.item-balance');
    if (balanceElement) {
        balanceElement.innerHTML = `<span class="sr-only">${balanceAccesible}</span><span aria-hidden="true">${textoBalance}</span>`;
        balanceElement.className = `item-balance ${claseBalance}`;
    } else {
        console.warn(`No se encontró el elemento de balance para "${amigo.nombre}"`);
    }
    
    // Actualizar aria-labels
    const botonEditar = item.querySelector('.btn-editar');
    const botonEliminar = item.querySelector('.btn-eliminar');
    const textoAltEditar = `Editar amigo: ${amigo.nombre}`;
    const textoAltEliminar = `Eliminar amigo: ${amigo.nombre}`;
    
    botonEditar.setAttribute('aria-label', textoAltEditar);
    botonEditar.querySelector('.sr-only').textContent = textoAltEditar;
    
    botonEliminar.setAttribute('aria-label', textoAltEliminar);
    botonEliminar.querySelector('.sr-only').textContent = textoAltEliminar;
}

/**
 * Elimina un amigo del DOM
 * @param {number} index - Índice del amigo a eliminar
 */
function eliminarAmigoDelDOM(index) {
    const listaAmigos = document.getElementById('lista-amigos');
    if (!listaAmigos || index < 0 || index >= listaAmigos.children.length) {
        return;
    }
    
    listaAmigos.children[index].remove();
}

/**
 * Actualiza los balances de todos los amigos en el DOM
 */
function actualizarBalancesAmigos() {
    // Asegurarse de que todos los amigos tengan su balance actualizado
    amigos.forEach((amigo, index) => {
        try {
            actualizarAmigoEnDOM(amigo, index);
        } catch (error) {
            console.error(`Error al actualizar balance del amigo "${amigo.nombre}" en el índice ${index}:`, error);
            // Intentar buscar el amigo por nombre si falla por índice
            const listaAmigos = document.getElementById('lista-amigos');
            if (listaAmigos) {
                const item = Array.from(listaAmigos.children).find(li => {
                    const nombre = li.querySelector('.item-titulo')?.textContent.trim();
                    return nombre === amigo.nombre;
                });
                if (item) {
                    // Recalcular y actualizar manualmente
                    const balance = calcularBalanceAmigo(amigo.nombre);
                    const gastosCompartidos = gastos.filter(gasto => 
                        gasto.participantes && gasto.participantes.includes(amigo.nombre)
                    ).length;
                    
                    // Actualizar el balance en el DOM
                    const balanceElement = item.querySelector('.item-balance');
                    if (balanceElement) {
                        let claseBalance = 'neutral';
                        let textoBalance = `€${Math.abs(balance).toFixed(2)}`;
                        let balanceAccesible = 'Balance neutro: sin saldo pendiente';
                        
                        const balanceEntero = Math.floor(Math.abs(balance));
                        const balanceCentimos = Math.round((Math.abs(balance) - balanceEntero) * 100);
                        let cantidadAccesible = `${balanceEntero} euros`;
                        if (balanceCentimos > 0) {
                            cantidadAccesible += ` con ${balanceCentimos} céntimos`;
                        }
                        
                        if (balance > 0.01) {
                            claseBalance = 'positivo';
                            textoBalance = `+${textoBalance}`;
                            balanceAccesible = `Balance positivo: le deben ${cantidadAccesible}`;
                        } else if (balance < -0.01) {
                            claseBalance = 'negativo';
                            textoBalance = `-${textoBalance}`;
                            balanceAccesible = `Balance negativo: debe ${cantidadAccesible}`;
                        } else {
                            textoBalance = '€0.00';
                        }
                        
                        balanceElement.innerHTML = `<span class="sr-only">${balanceAccesible}</span><span aria-hidden="true">${textoBalance}</span>`;
                        balanceElement.className = `item-balance ${claseBalance}`;
                    }
                    
                    // Actualizar gastos compartidos
                    const detalleElement = item.querySelector('.item-detalle');
                    if (detalleElement) {
                        detalleElement.textContent = `${gastosCompartidos} gasto${gastosCompartidos !== 1 ? 's' : ''} compartido${gastosCompartidos !== 1 ? 's' : ''}`;
                    }
                }
            }
        }
    });
}

// ============================================
// Modal para Pagar Saldos
// ============================================

/**
 * Crea el modal para pagar saldos
 */
function crearModalPagarSaldos() {
    // Verificar si el modal ya existe
    if (document.getElementById('modal-pagar-saldos')) {
        return;
    }
    
    const modal = document.createElement('div');
    modal.id = 'modal-pagar-saldos';
    modal.className = 'modal';
    modal.setAttribute('role', 'dialog');
    modal.setAttribute('aria-labelledby', 'modal-pagar-saldos-titulo');
    modal.setAttribute('aria-modal', 'true');
    modal.innerHTML = `
        <div class="modal-contenido modal-pagar-saldos-contenido">
            <div class="modal-header">
                <h2 id="modal-pagar-saldos-titulo">Pagar Saldos Pendientes</h2>
                <button type="button" class="modal-cerrar" aria-label="Cerrar modal">
                    <span aria-hidden="true">×</span>
                </button>
            </div>
            <div class="modal-pagar-saldos-cuerpo">
                <p class="modal-pagar-saldos-descripcion">Selecciona cuánto quieres pagar de cada amigo:</p>
                <div id="lista-pagos-saldos" class="lista-pagos-saldos"></div>
            </div>
            <div class="modal-acciones">
                <button type="button" class="btn-cancelar" aria-label="Cancelar">Cancelar</button>
                <button type="button" class="btn-guardar btn-confirmar-pago" aria-label="Confirmar pagos">Confirmar Pagos</button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Event listeners del modal
    const cerrarBtn = modal.querySelector('.modal-cerrar');
    const cancelarBtn = modal.querySelector('.btn-cancelar');
    const confirmarBtn = modal.querySelector('.btn-confirmar-pago');
    const overlay = modal;
    
    cerrarBtn.addEventListener('click', cerrarModalPagarSaldos);
    cancelarBtn.addEventListener('click', cerrarModalPagarSaldos);
    confirmarBtn.addEventListener('click', procesarPagosSaldos);
    
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
            cerrarModalPagarSaldos();
        }
    });
    
    // Cerrar con Escape
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && modal.classList.contains('activo')) {
            cerrarModalPagarSaldos();
        }
    });
}

/**
 * Abre el modal para pagar saldos
 */
function abrirModalPagarSaldos() {
    const modal = document.getElementById('modal-pagar-saldos');
    const listaPagos = document.getElementById('lista-pagos-saldos');
    
    if (!modal) {
        console.error('No se encontró el modal de pagar saldos');
        mostrarFeedback(document.querySelector('.btn-pagar-header, .btn-pagar-footer'), 'Error: No se encontró el modal de pagos', 'error');
        return;
    }
    
    if (!listaPagos) {
        console.error('No se encontró la lista de pagos en el modal');
        mostrarFeedback(document.querySelector('.btn-pagar-header, .btn-pagar-footer'), 'Error: No se encontró la lista de pagos', 'error');
        return;
    }
    
    // Guardar el foco actual antes de abrir el modal
    guardarFocoAnterior();
    
    // Limpiar lista
    listaPagos.innerHTML = '';
    
    // Obtener solo amigos con saldo NEGATIVO (deudores que deben pagar)
    // No tiene sentido mostrar personas con saldo positivo (acreedores que deben recibir)
    const amigosConSaldo = amigos.filter(amigo => {
        if (!amigo || !amigo.nombre) {
            console.warn('Amigo inválido encontrado:', amigo);
            return false;
        }
        const balance = calcularBalanceAmigo(amigo.nombre);
        // Solo mostrar aquellos con saldo negativo (deben dinero)
        return balance < -0.01;
    });
    
    if (amigosConSaldo.length === 0) {
        mostrarFeedback(document.querySelector('.btn-pagar-header, .btn-pagar-footer'), 'No hay saldos pendientes para pagar', 'error');
        return;
    }
    
    // Crear items para cada amigo con saldo
    amigosConSaldo.forEach(amigo => {
        const balance = calcularBalanceAmigo(amigo.nombre);
        const saldoAbsoluto = Math.abs(balance);
        const esDeudor = balance < 0;
        const amigoId = amigo.nombre.replace(/\s+/g, '-').toLowerCase();
        
        const item = document.createElement('div');
        item.className = 'item-pago-saldo';
        item.innerHTML = `
            <div class="item-pago-checkbox">
                <input type="checkbox" 
                       id="checkbox-${amigoId}" 
                       class="checkbox-pagar-saldo" 
                       data-amigo="${escaparHTML(amigo.nombre)}"
                       aria-label="Seleccionar para pagar saldo de ${escaparHTML(amigo.nombre)}">
                <label for="checkbox-${amigoId}" class="sr-only">Seleccionar para pagar</label>
            </div>
            <div class="item-pago-info">
                <span class="item-pago-nombre">${escaparHTML(amigo.nombre)}</span>
                <span class="item-pago-saldo ${esDeudor ? 'negativo' : 'positivo'}">
                    ${esDeudor ? 'Debe:' : 'Le deben:'} €${saldoAbsoluto.toFixed(2)}
                </span>
            </div>
            <div class="item-pago-control" style="display: none;">
                <label for="pago-${amigoId}" class="sr-only">Cantidad a pagar</label>
                <input type="number" 
                       id="pago-${amigoId}" 
                       class="input-pago-saldo" 
                       data-amigo="${escaparHTML(amigo.nombre)}"
                       step="0.01" 
                       min="0" 
                       max="${saldoAbsoluto.toFixed(2)}"
                       value="${saldoAbsoluto.toFixed(2)}"
                       aria-label="Cantidad a pagar de ${escaparHTML(amigo.nombre)}"
                       disabled>
                <span class="moneda-simbolo">€</span>
            </div>
        `;
        
        listaPagos.appendChild(item);
        
        // Agregar listener al checkbox
        const checkbox = item.querySelector('.checkbox-pagar-saldo');
        const controlDiv = item.querySelector('.item-pago-control');
        const input = item.querySelector('.input-pago-saldo');
        
        checkbox.addEventListener('change', (e) => {
            if (e.target.checked) {
                controlDiv.style.display = 'flex';
                input.disabled = false;
                setTimeout(() => input.focus(), 50);
            } else {
                controlDiv.style.display = 'none';
                input.disabled = true;
                input.value = saldoAbsoluto.toFixed(2); // Resetear al valor original
            }
        });
    });
    
    modal.classList.add('activo');
    document.body.style.overflow = 'hidden';
    
    // Crear focus trap
    modal.limpiarFocusTrap = crearFocusTrap(modal);
    
    // Focus en el primer campo
    setTimeout(() => {
        const primerInput = listaPagos.querySelector('input');
        if (primerInput) {
            primerInput.focus();
            primerInput.select();
        }
    }, 100);
    
    anunciarCambio('Modal para pagar saldos abierto');
}

/**
 * Cierra el modal de pagar saldos
 */
function cerrarModalPagarSaldos() {
    const modal = document.getElementById('modal-pagar-saldos');
    if (!modal) return;
    
    // Limpiar focus trap si existe
    if (modal.limpiarFocusTrap) {
        modal.limpiarFocusTrap();
        modal.limpiarFocusTrap = null;
    }
    
    modal.classList.remove('activo');
    document.body.style.overflow = '';
    
    // Restaurar el foco al elemento anterior
    restaurarFocoAnterior();
    
    anunciarCambio('Modal de pagar saldos cerrado');
}

/**
 * Procesa los pagos de saldos
 */
function procesarPagosSaldos() {
    const listaPagos = document.getElementById('lista-pagos-saldos');
    if (!listaPagos) return;
    
    // Obtener solo los checkboxes marcados
    const checkboxesMarcados = listaPagos.querySelectorAll('.checkbox-pagar-saldo:checked');
    
    if (checkboxesMarcados.length === 0) {
        mostrarFeedback(document.querySelector('.btn-confirmar-pago'), 'Por favor, selecciona al menos un amigo para pagar', 'error');
        return;
    }
    
    const pagos = [];
    let hayErrores = false;
    
    checkboxesMarcados.forEach(checkbox => {
        const amigo = checkbox.getAttribute('data-amigo');
        const amigoId = amigo.replace(/\s+/g, '-').toLowerCase();
        const input = document.getElementById(`pago-${amigoId}`);
        
        if (!input) return;
        
        const monto = parseFloat(input.value);
        const balance = calcularBalanceAmigo(amigo);
        const saldoAbsoluto = Math.abs(balance);
        
        if (isNaN(monto) || monto < 0) {
            input.style.borderColor = 'var(--color-destacado)';
            hayErrores = true;
        } else if (monto > saldoAbsoluto + 0.01) {
            input.style.borderColor = 'var(--color-destacado)';
            hayErrores = true;
        } else {
            input.style.borderColor = '';
            if (monto > 0.01) {
                pagos.push({
                    amigo: amigo,
                    monto: monto,
                    balance: balance
                });
            }
        }
    });
    
    if (hayErrores) {
        mostrarFeedback(document.querySelector('.btn-confirmar-pago'), 'Por favor, revisa los montos ingresados', 'error');
        return;
    }
    
    if (pagos.length === 0) {
        mostrarFeedback(document.querySelector('.btn-confirmar-pago'), 'No hay pagos para procesar', 'error');
        return;
    }
    
    // Crear gastos de "pago" que compensen los saldos correctamente
    // CRÍTICO: Calcular gastosBase ANTES de crear cualquier gasto de pago
    // y usar siempre esta referencia para evitar bucles
    const gastosBaseSnapshot = [...gastos.filter(g => !g.titulo || !g.titulo.startsWith('Pago de saldo -'))];
    
    // Almacenar los gastos de pago que vamos a crear para no incluirlos en cálculos intermedios
    const nuevosGastosPago = [];
    
    for (const pago of pagos) {
        const amigo = amigos.find(a => a.nombre === pago.amigo);
        if (!amigo) continue;
        
        // Calcular saldo actual usando SOLO gastos base (sin ningún gasto de pago)
        const saldoActual = calcularBalanceAmigoBase(pago.amigo, gastosBaseSnapshot);
        
        // Solo procesar si tiene saldo negativo
        if (saldoActual >= -0.01) {
            continue;
        }
        
        const montoAPagar = Math.min(pago.monto, Math.abs(saldoActual));
        
        if (montoAPagar <= 0.01) {
            continue;
        }
        
        // Encontrar a quién debe el amigo usando SOLO gastos base
        const acreedores = new Map(); // Map<nombre, monto que le debe>
        
        gastosBaseSnapshot.forEach(gasto => {
            // Si el amigo participó pero no pagó, debe al que pagó
            if (gasto.participantes && gasto.participantes.includes(pago.amigo) && 
                gasto.quienPago !== pago.amigo && gasto.quienPago) {
                const parteDelAmigo = gasto.monto / gasto.participantes.length;
                const acreedor = gasto.quienPago;
                
                if (!acreedores.has(acreedor)) {
                    acreedores.set(acreedor, 0);
                }
                acreedores.set(acreedor, acreedores.get(acreedor) + parteDelAmigo);
            }
        });
        
        // Si no hay acreedores específicos, buscar por saldo positivo usando SOLO gastos base
        if (acreedores.size === 0) {
            amigos.forEach(a => {
                if (a.nombre === pago.amigo) return;
                const saldo = calcularBalanceAmigoBase(a.nombre, gastosBaseSnapshot);
                if (saldo > 0.01) {
                    acreedores.set(a.nombre, saldo);
                }
            });
        }
        
        if (acreedores.size === 0) {
            continue;
        }
        
        // Distribuir el pago proporcionalmente entre los acreedores
        const totalDeuda = Array.from(acreedores.values()).reduce((sum, val) => sum + val, 0);
        if (totalDeuda <= 0.01) {
            continue;
        }
        
        const acreedoresOrdenados = Array.from(acreedores.entries()).sort((a, b) => b[1] - a[1]);
        
        let montoRestante = montoAPagar;
        
        // Crear un gasto por cada acreedor con su parte proporcional
        for (const [acreedor, montoDebido] of acreedoresOrdenados) {
            if (montoRestante <= 0.01) break;
            
            const proporcion = montoDebido / totalDeuda;
            const montoParaEste = Math.min(montoRestante, montoAPagar * proporcion);
            
            if (montoParaEste > 0.01) {
                // Crear gasto donde el deudor paga pero NO participa, solo el acreedor participa
                // Esto compensa: deudor gana +monto, acreedor pierde -monto
                const gastoPago = {
                    id: Date.now() + Math.random() * 1000 + nuevosGastosPago.length,
                    titulo: `Pago de saldo - ${pago.amigo}`,
                    monto: montoParaEste,
                    quienPago: pago.amigo,
                    participantes: [acreedor] // Solo el acreedor, el deudor NO participa
                };
                
                nuevosGastosPago.push(gastoPago);
                montoRestante -= montoParaEste;
            }
        }
        
        // Si quedó monto restante, agregarlo al último gasto creado
        if (montoRestante > 0.01 && nuevosGastosPago.length > 0) {
            const ultimoGasto = nuevosGastosPago[nuevosGastosPago.length - 1];
            if (ultimoGasto && ultimoGasto.titulo === `Pago de saldo - ${pago.amigo}`) {
                ultimoGasto.monto += montoRestante;
            }
        }
    }
    
    // Agregar todos los gastos de pago al array y al DOM de una vez
    nuevosGastosPago.forEach(gastoPago => {
        gastos.push(gastoPago);
        agregarGastoAlDOM(gastoPago);
    });
    
    // Actualizar balances de amigos
    actualizarBalancesAmigos();
    
    actualizarTextosAlternativos();
    
    cerrarModalPagarSaldos();
    anunciarCambio(`${pagos.length} pago${pagos.length !== 1 ? 's' : ''} procesado${pagos.length !== 1 ? 's' : ''} correctamente`);
    mostrarFeedback(null, `${pagos.length} pago${pagos.length !== 1 ? 's' : ''} procesado${pagos.length !== 1 ? 's' : ''} satisfactoriamente`, 'success');
}

/**
 * Paga todos los saldos pendientes (abre modal para seleccionar pagos)
 */
function pagarSaldosPendientes() {
    try {
        // Verificar si hay saldos pendientes (solo deudores con saldo negativo)
        const amigosConSaldo = amigos.filter(amigo => {
            const balance = calcularBalanceAmigo(amigo.nombre);
            return balance < -0.01; // Solo deudores
        });
        
        if (amigosConSaldo.length === 0) {
            mostrarFeedback(document.querySelector('.btn-pagar-header, .btn-pagar-footer'), 'No hay saldos pendientes para pagar', 'error');
            return;
        }
        
        abrirModalPagarSaldos();
    } catch (error) {
        console.error('Error al intentar pagar saldos:', error);
        mostrarFeedback(document.querySelector('.btn-pagar-header, .btn-pagar-footer'), 'Error al abrir el modal de pagos', 'error');
    }
}

