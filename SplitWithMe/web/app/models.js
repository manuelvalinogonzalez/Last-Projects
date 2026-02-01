// Configuración de la API
const API_BASE_URL = "http://localhost:8000";
const REQUEST_TIMEOUT = 10000;

async function fetchAPI(url, options = {}) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), REQUEST_TIMEOUT);
    
    try {
        const response = await fetch(url, {
            ...options,
            signal: controller.signal,
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            }
        });
        
        clearTimeout(timeoutId);
        
        if (!response.ok) {
            const errorText = await response.text();
            let errorMessage = `Error HTTP ${response.status}`;
            
            if (response.status === 400) {
                errorMessage = "Datos inválidos";
            } else if (response.status === 404) {
                errorMessage = "Recurso no encontrado";
            } else if (response.status === 409) {
                errorMessage = "Conflicto: " + errorText;
            } else if (response.status === 500) {
                errorMessage = "Error interno del servidor";
            } else if (response.status === 503) {
                errorMessage = "Servicio no disponible. Intenta más tarde";
            }
            
            throw new Error(errorMessage);
        }
        
        return response;
    } catch (error) {
        clearTimeout(timeoutId);
        
        if (error.name === 'AbortError') {
            throw new Error("El servidor tardó demasiado en responder. Inténtalo de nuevo");
        } else if (error.message.includes('Failed to fetch') || error.message.includes('NetworkError')) {
            throw new Error("No se puede conectar al servidor. Verifica que el servidor esté ejecutándose en http://localhost:8000");
        }
        
        throw error;
    }
}

class Amigo {
    constructor(id, nombre, credit_balance = 0.0, debit_balance = 0.0) {
        this.id = id;
        this.nombre = nombre;
        this.credit_balance = credit_balance;
        this.debit_balance = debit_balance;
    }
    
    saldo() {
        return this.credit_balance - this.debit_balance;
    }
    
    actualizar_saldo(importe) {
        this.credit_balance += importe;
    }
    
    to_dict() {
        return {
            id: this.id,
            name: this.nombre
        };
    }
}

class Gasto {
    constructor(id, descripcion, monto, fecha, pagador_id = null, 
                deudores_ids = null, credit_balance = 0.0, num_friends = 1) {
        this.id = id;
        this.descripcion = descripcion;
        this.monto = monto;
        this.fecha = fecha;
        this.pagador_id = pagador_id;
        this.deudores_ids = deudores_ids || [];
        this.credit_balance = credit_balance;
        this.num_friends = num_friends;
    }
    
    split() {
        if (this.num_friends > 0) {
            return this.monto / this.num_friends;
        }
        return 0.0;
    }
    
    to_dict() {
        return {
            id: this.id,
            description: this.descripcion,
            amount: this.monto,
            date: this.fecha
        };
    }
}

// ============================================
// Funciones de Conversión (JSON ↔ Objetos)
// ============================================

function amigo_from_dict(data) {
    return new Amigo(
        data.id,
        data.name,
        data.credit_balance || 0.0,
        data.debit_balance || 0.0
    );
}

function gasto_from_dict(data) {
    return new Gasto(
        data.id,
        data.description,
        data.amount,
        data.date,
        data.pagador_id || null,
        data.deudores_ids || [],
        data.credit_balance || 0.0,
        data.num_friends || 1
    );
}

// ============================================
// Modelo Principal
// ============================================

class Main {
    constructor(id = 1, nombre = "Grupo Principal") {
        this.id = id;
        this.nombre = nombre;
        this.amigos = [];
        this.gastos = [];
    }
    
    // ============================================
    // MÉTODOS DE AMIGOS
    // ============================================
    
    async cargar_amigos() {
        try {
            const response = await fetchAPI(`${API_BASE_URL}/friends/`);
            const amigos_data = await response.json();
            
            this.amigos = amigos_data.map(a => amigo_from_dict(a));
            return this.amigos;
        } catch (error) {
            if (error.message.includes('Error HTTP 500')) {
                throw new Error("Error interno del servidor al cargar amigos");
            } else if (error.message.includes('Error HTTP 503')) {
                throw new Error("Servicio no disponible. Intenta más tarde");
            }
            throw error;
        }
    }
    
    async add_amigo(nombre) {
        try {
            const amigo_data = { name: nombre };
            
            const response = await fetchAPI(`${API_BASE_URL}/friends/`, {
                method: 'POST',
                body: JSON.stringify(amigo_data)
            });
            
            const amigo = amigo_from_dict(await response.json());
            this.amigos.push(amigo);
            return amigo;
        } catch (error) {
            if (error.message.includes('Error HTTP 400')) {
                throw new Error("Datos inválidos. Verifica el nombre del amigo");
            } else if (error.message.includes('Error HTTP 409')) {
                throw new Error("Ya existe un amigo con ese nombre");
            } else if (error.message.includes('Error HTTP 500')) {
                throw new Error("Error interno del servidor");
            }
            throw error;
        }
    }
    
    async eliminar_amigo(amigo_id) {
        try {
            await fetchAPI(`${API_BASE_URL}/friends/${amigo_id}`, {
                method: 'DELETE'
            });
            
            this.amigos = this.amigos.filter(a => a.id !== amigo_id);
        } catch (error) {
            if (error.message.includes('Error HTTP 409')) {
                throw new Error("No se puede eliminar el amigo porque tiene saldo pendiente");
            } else if (error.message.includes('Error HTTP 404')) {
                throw new Error("El amigo no existe");
            } else if (error.message.includes('Error HTTP 500')) {
                throw new Error("Error interno del servidor");
            }
            throw error;
        }
    }
    
    async obtener_amigo(amigo_id) {
        try {
            const response = await fetchAPI(`${API_BASE_URL}/friends/${amigo_id}`);
            return amigo_from_dict(await response.json());
        } catch (error) {
            throw error;
        }
    }
    
    async actualizar_amigo_desde_api(amigo_id) {
        try {
            const amigo_actualizado = await this.obtener_amigo(amigo_id);
            
            const index = this.amigos.findIndex(a => a.id === amigo_id);
            if (index !== -1) {
                this.amigos[index] = amigo_actualizado;
            }
            return amigo_actualizado;
        } catch (error) {
            throw new Error(`Error al actualizar amigo desde API: ${error.message}`);
        }
    }
    
    // ============================================
    // MÉTODOS DE GASTOS
    // ============================================
    
    async cargar_gastos() {
        try {
            const response = await fetchAPI(`${API_BASE_URL}/expenses/`);
            const gastos_data = await response.json();
            
            this.gastos = [];
            
            for (const g of gastos_data) {
                const gasto = gasto_from_dict(g);
                
                try {
                    const participantes_ids = await this.obtener_participantes_gasto(gasto.id);
                    gasto.num_friends = participantes_ids.length;
                    
                    let pagador_id = null;
                    for (const participante_id of participantes_ids) {
                        try {
                            const response_participante = await fetchAPI(
                                `${API_BASE_URL}/expenses/${gasto.id}/friends/${participante_id}`
                            );
                            const participante_data = await response_participante.json();
                            
                            if (participante_data.credit_balance > 0) {
                                pagador_id = participante_id;
                                break;
                            }
                        } catch (e) {
                            continue;
                        }
                    }
                    
                    gasto.pagador_id = pagador_id;
                    gasto.deudores_ids = participantes_ids;
                } catch (e) {
                    // Si no se pueden obtener los participantes, mantener el valor original
                }
                
                this.gastos.push(gasto);
            }
            
            return this.gastos;
        } catch (error) {
            if (error.message.includes('Error HTTP 500')) {
                throw new Error("Error interno del servidor al cargar gastos");
            } else if (error.message.includes('Error HTTP 503')) {
                throw new Error("Servicio no disponible. Intenta más tarde");
            }
            throw error;
        }
    }
    
    async add_gasto(descripcion, monto, pagador_id, deudores_ids) {
        let gasto_id = null;
        
        try {
            // Paso 1: Crear el gasto básico en la API
            const fecha_actual = new Date().toISOString().split('T')[0];
            
            const gasto_data = {
                description: descripcion,
                amount: monto,
                date: fecha_actual
            };
            
            const response = await fetchAPI(`${API_BASE_URL}/expenses/`, {
                method: 'POST',
                body: JSON.stringify(gasto_data)
            });
            
            const gasto = gasto_from_dict(await response.json());
            gasto_id = gasto.id;
            gasto.pagador_id = pagador_id;
            
            // Paso 2: Añadir todos los participantes/deudores al gasto
            for (const deudor_id of deudores_ids) {
                try {
                    await fetchAPI(`${API_BASE_URL}/expenses/${gasto.id}/friends?friend_id=${deudor_id}`, {
                        method: 'POST'
                    });
                } catch (e) {
                    throw new Error(`Error al añadir participante ${deudor_id}: ${e.message}`);
                }
            }
            
            // Paso 3: Calcular el crédito del pagador
            let credito_pagador;
            if (deudores_ids.includes(pagador_id)) {
                // Caso 1: El pagador también participó
                const monto_por_persona = monto / deudores_ids.length;
                const monto_otros = monto - monto_por_persona;
                credito_pagador = monto_otros;
            } else {
                // Caso 2: El pagador no participó
                credito_pagador = monto;
            }
            
            // Paso 4: Añadir al pagador al gasto y asignarle su crédito
            try {
                if (!deudores_ids.includes(pagador_id)) {
                    await fetchAPI(`${API_BASE_URL}/expenses/${gasto.id}/friends?friend_id=${pagador_id}`, {
                        method: 'POST'
                    });
                }
                
                await fetchAPI(`${API_BASE_URL}/expenses/${gasto.id}/friends/${pagador_id}?amount=${credito_pagador}`, {
                    method: 'PUT'
                });
            } catch (e) {
                throw new Error(`Error al configurar pagador: ${e.message}`);
            }
            
            // Paso 5: Ajustar los créditos/deudas de los deudores
            if (!deudores_ids.includes(pagador_id)) {
                // Caso: Pagador no participó
                const monto_por_deudor = -monto / deudores_ids.length;
                for (const deudor_id of deudores_ids) {
                    try {
                        await fetchAPI(`${API_BASE_URL}/expenses/${gasto.id}/friends/${deudor_id}?amount=${monto_por_deudor}`, {
                            method: 'PUT'
                        });
                    } catch (e) {
                        throw new Error(`Error al actualizar crédito de deudor ${deudor_id}: ${e.message}`);
                    }
                }
            } else {
                // Caso: Pagador también participó
                const monto_por_persona = monto / deudores_ids.length;
                for (const deudor_id of deudores_ids) {
                    if (deudor_id !== pagador_id) {
                        try {
                            await fetchAPI(`${API_BASE_URL}/expenses/${gasto.id}/friends/${deudor_id}?amount=${-monto_por_persona}`, {
                                method: 'PUT'
                            });
                        } catch (e) {
                            throw new Error(`Error al actualizar crédito de deudor ${deudor_id}: ${e.message}`);
                        }
                    }
                }
            }
            
            gasto.deudores_ids = deudores_ids;
            this.gastos.push(gasto);
            return gasto;
            
        } catch (error) {
            // Manejo de errores con rollback
            if (gasto_id) {
                try {
                    await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}`, {
                        method: 'DELETE'
                    });
                } catch (e) {
                    // Si falla el rollback, no hay nada más que hacer
                }
            }
            
            if (error.message.includes('Error HTTP 404')) {
                throw new Error("Uno o más participantes no existen");
            } else if (error.message.includes('Error HTTP 400')) {
                throw new Error("Datos inválidos para el gasto");
            } else if (error.message.includes('Error HTTP 500')) {
                throw new Error("Error interno del servidor");
            }
            
            throw error;
        }
    }
    
    async eliminar_gasto(gasto_id) {
        try {
            await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}`, {
                method: 'DELETE'
            });
            
            this.gastos = this.gastos.filter(g => g.id !== gasto_id);
        } catch (error) {
            if (error.message.includes('Error HTTP 404')) {
                throw new Error("El gasto no existe");
            } else if (error.message.includes('Error HTTP 500')) {
                throw new Error("Error interno del servidor");
            }
            throw error;
        }
    }
    
    async obtener_participantes_gasto(gasto_id) {
        try {
            const response = await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}/friends`);
            const participantes_data = await response.json();
            
            const participantes_ids = [];
            for (const p of participantes_data) {
                if (typeof p === 'object' && p !== null) {
                    if (p.friend_id !== undefined) {
                        participantes_ids.push(p.friend_id);
                    } else if (p.id !== undefined) {
                        participantes_ids.push(p.id);
                    }
                } else if (typeof p === 'number') {
                    participantes_ids.push(p);
                }
            }
            
            return participantes_ids;
        } catch (error) {
            throw error;
        }
    }
    
    async update_gasto(gasto_id, nuevos_datos) {
        try {
            const gasto_actual = this.gastos.find(g => g.id === gasto_id);
            
            if (!gasto_actual) {
                throw new Error("Gasto no encontrado");
            }
            
            // Verificar si el monto cambió
            const monto_anterior = gasto_actual.monto;
            const monto_nuevo = nuevos_datos.monto !== undefined ? nuevos_datos.monto : monto_anterior;
            
            // Verificar si los participantes cambiaron
            const participantes_actuales = await this.obtener_participantes_gasto(gasto_id);
            const nuevos_participantes = nuevos_datos.participantes_ids || participantes_actuales;
            
            // Preparar los datos básicos del gasto para actualizar
            const gasto_data = {
                id: gasto_id,
                description: nuevos_datos.descripcion || gasto_actual.descripcion,
                amount: monto_nuevo,
                date: nuevos_datos.fecha || gasto_actual.fecha
            };
            
            // PUT /expenses/{id} - Actualizar datos básicos del gasto
            await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}`, {
                method: 'PUT',
                body: JSON.stringify(gasto_data)
            });
            
            // Si los participantes cambiaron, actualizar la lista de participantes
            const participantes_actuales_set = new Set(participantes_actuales);
            const nuevos_participantes_set = new Set(nuevos_participantes);
            const participantes_cambiaron = participantes_actuales_set.size !== nuevos_participantes_set.size ||
                [...participantes_actuales_set].some(id => !nuevos_participantes_set.has(id));
            
            if (participantes_cambiaron) {
                // Eliminar participantes que ya no están en la nueva lista
                for (const participante_id of participantes_actuales) {
                    if (!nuevos_participantes.includes(participante_id)) {
                        try {
                            await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}/friends/${participante_id}`, {
                                method: 'DELETE'
                            });
                        } catch (e) {
                            console.warn(`Advertencia: No se pudo eliminar participante ${participante_id}: ${e.message}`);
                            continue;
                        }
                    }
                }
                
                // Añadir nuevos participantes que no estaban antes
                for (const participante_id of nuevos_participantes) {
                    if (!participantes_actuales.includes(participante_id)) {
                        try {
                            await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}/friends?friend_id=${participante_id}`, {
                                method: 'POST'
                            });
                        } catch (e) {
                            console.warn(`Advertencia: No se pudo añadir participante ${participante_id}: ${e.message}`);
                            continue;
                        }
                    }
                }
            }
            
            // Si el monto cambió o los participantes cambiaron, recalcular saldos
            if (monto_anterior !== monto_nuevo || participantes_cambiaron) {
                // Obtener el pagador
                let pagador_id = nuevos_datos.pagador_id || gasto_actual.pagador_id;
                
                // Si no hay pagador especificado, buscar el que tiene crédito > 0
                if (!pagador_id) {
                    for (const participante_id of nuevos_participantes) {
                        try {
                            const response = await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}/friends/${participante_id}`);
                            const participante_data = await response.json();
                            if (participante_data.credit_balance > 0) {
                                pagador_id = participante_id;
                                break;
                            }
                        } catch (e) {
                            console.warn(`Advertencia: No se pudo obtener info de participante ${participante_id}: ${e.message}`);
                            continue;
                        }
                    }
                }
                
                // Recalcular créditos para todos los participantes
                for (const participante_id of nuevos_participantes) {
                    try {
                        let nuevo_credito;
                        if (participante_id === pagador_id) {
                            // Calcular crédito del pagador
                            if (nuevos_participantes.includes(pagador_id)) {
                                // Caso: Pagador también participó
                                const monto_por_persona = monto_nuevo / nuevos_participantes.length;
                                const monto_otros = monto_nuevo - monto_por_persona;
                                nuevo_credito = monto_otros;
                            } else {
                                // Caso: Pagador no participó
                                nuevo_credito = monto_nuevo;
                            }
                        } else {
                            // Los demás participantes no tienen crédito (solo deuda)
                            nuevo_credito = 0;
                        }
                        
                        await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}/friends/${participante_id}?amount=${nuevo_credito}`, {
                            method: 'PUT'
                        });
                    } catch (e) {
                        console.warn(`Advertencia: No se pudo actualizar crédito de participante ${participante_id}: ${e.message}`);
                        continue;
                    }
                }
            }
            
            // Actualizar en la lista local con los nuevos datos
            gasto_actual.descripcion = gasto_data.description;
            gasto_actual.monto = gasto_data.amount;
            gasto_actual.fecha = gasto_data.date;
            gasto_actual.pagador_id = nuevos_datos.pagador_id || gasto_actual.pagador_id;
            gasto_actual.deudores_ids = nuevos_participantes;
            
        } catch (error) {
            if (error.message.includes('Error HTTP 404')) {
                throw new Error("El gasto o uno de los participantes no existe");
            } else if (error.message.includes('Error HTTP 400')) {
                throw new Error("Datos inválidos para actualizar el gasto");
            } else if (error.message.includes('Error HTTP 500')) {
                throw new Error("Error interno del servidor");
            }
            throw error;
        }
    }
    
    // ============================================
    // MÉTODOS DE CÁLCULO
    // ============================================
    
    calcular_saldos() {
        const saldos = {};
        for (const amigo of this.amigos) {
            saldos[amigo.id] = amigo.saldo();
        }
        return saldos;
    }
    
    async pagar_saldo(amigo_id, importe) {
        try {
            // Paso 1: Obtener todos los gastos del amigo desde la API
            const response = await fetchAPI(`${API_BASE_URL}/friends/${amigo_id}/expenses`);
            const gastos_amigo = await response.json();
            
            // Paso 2: Distribuir el pago entre los gastos pendientes
            let importe_restante = importe;
            for (const gasto_data of gastos_amigo) {
                if (importe_restante <= 0) {
                    break;
                }
                
                const gasto_id = gasto_data.id;
                const deuda = gasto_data.debit_balance - gasto_data.credit_balance;
                
                if (deuda > 0) {
                    const pago = Math.min(importe_restante, deuda);
                    
                    await fetchAPI(`${API_BASE_URL}/expenses/${gasto_id}/friends/${amigo_id}?amount=${pago}`, {
                        method: 'PUT'
                    });
                    importe_restante -= pago;
                }
            }
            
            // Paso 3: Recargar los datos de amigos para actualizar los saldos
            await this.cargar_amigos();
            
        } catch (error) {
            if (error.message.includes('Error HTTP 404')) {
                throw new Error("El amigo o sus gastos no existen");
            } else if (error.message.includes('Error HTTP 400')) {
                throw new Error("Datos de pago inválidos");
            } else if (error.message.includes('Error HTTP 500')) {
                throw new Error("Error interno del servidor");
            }
            throw error;
        }
    }
}

if (typeof module !== 'undefined' && module.exports) {
    module.exports = { Amigo, Gasto, Main, amigo_from_dict, gasto_from_dict };
}
