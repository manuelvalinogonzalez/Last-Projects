# Diseño del Software

Este documento describe el diseño del sistema, incluyendo los diagramas estático y dinámicos
para una aplicacion que utiliza el patron MVC (Modelo, Vista, Controlador).

---

# Diagrama Estático
```mermaid
---
config:
  layout: elk
---
classDiagram
direction TB
    class Main {
	    +int id
	    +str nombre
	    +List~Amigo~ amigos
	    +List~Gasto~ gastos
	    +add_amigo(nombre)
	    +eliminar_amigo(amigo_id)
	    +add_gasto(descripcion, monto, pagador_id, deudores_montos)
		+eliminar_gasto(gasto_id)
	    +update_expense(expense_id, nuevos_datos)
	    +calcular_saldos()
    }
    class TranslationManager{
        +str current_language
        +dict translations
        +translate(message)
    }
    class ConcurrencyService{
        +List~Thread~ threads
        +int active_operations
        +execute_async(func, callback, error_callback, delay)
        +has_active_operations()
        +wait_for_completion(timeout)
    }
    class Amigo {
	    +int id
	    +str nombre
	    +float credit_balance
	    +float debit_balance
	    +saldo()
	    +actualizar_saldo(importe)
    }
    class Gasto {
	    +int id
	    +str descripcion
	    +float monto
	    +date fecha
	    +int pagador_id
	    +List~int~ deudores_ids
	    +float credit_balance
	    +int num_friends
    }
    class PantallaInicialView {
	    +mostrar_pantalla_inicial(grupo)
	    +mostrar_dialogo_add_amigo()
        +mostrar_dialogo_gasto(amigos, gasto_a_editar)
        +mostrar_dialogo_pagar_saldo(amigo_nombre)
        +on_eliminar_amigo()
	    +on_add_gasto()
	    +on_eliminar_gasto()
        +on_editar_gasto()
	    +on_actualizar_gasto()
        +on_pagar_saldo()
    }
    class ErrorView {
	    +mostrar_error(mensaje)
    }
    class Application {
	    +do_activate()
        +on_quit()
    }
    class MainController {
	    -models.Main modelo
	    -views.PantallaInicialView vista
	    -concurrency_service.ConcurrencyService concurrency_service
	    -float delay_servidor
	    +iniciar()
	    +mostrar_detalles()
	    +actualizar_datos()
	    +add_amigo(nombre)
	    +eliminar_amigo(amigo_id)
	    +add_gasto(datos)
	    +eliminar_gasto(gasto_id)
	    +actualizar_gasto(gasto_id, datos)
        +pagar_saldo(amigo_id, importe)
    }
    Main "1" -- "0..*" Amigo : contiene
    Main "1" -- "0..*" Gasto : registra
    Main "1..*" --> "1" Amigo : pagador
    Main "1" --> "1..*" Amigo : deudores
    MainController "1" --> "1" ConcurrencyService : usa
    MainController "1" --> "1" PantallaInicialView : controla
    MainController "1" --> "1" Main : gestiona
    MainController "1" --> "1" TranslationManager : traduce
```


# Diagramas Dinámicos

## Secuencia para Añadir un Amigo

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Concurrency as "concurrency_service: ConcurrencyService"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Clic en botón "Añadir amigo"
    activate Vista
    Vista->>Vista: mostrar_dialogo_add_amigo()
    Vista-->>Usuario: Muestra diálogo para introducir nombre
    Usuario->>Vista: Introduce nombre y pulsa "Añadir"
    deactivate Vista

    Vista->>Controlador: on_add_amigo_callback(nombre)
    activate Controlador
    
    Controlador->>Vista: mostrar_loading("Añadiendo amigo...")
    Vista-->>Usuario: Muestra spinner y deshabilita UI
    
    Controlador->>Concurrency: execute_async(crear_amigo, callbacks, delay)
    activate Concurrency
    
    par Operación asíncrona simple
        Concurrency->>Concurrency: time.sleep(delay) # Simular delay del servidor
        Concurrency->>Modelo: add_amigo(nombre)
        activate Modelo
        Modelo->>API: POST /friends/
        
        alt Éxito
            API-->>Modelo: Created - Nuevo amigo creado
            Modelo-->>Concurrency: return amigo
            Concurrency-->>Controlador: callback(on_success)
            Controlador->>Vista: ocultar_loading()
            Controlador->>Vista: actualizar_datos()
            Controlador->>Vista: mostrar_info("Amigo añadido correctamente")
            activate Vista
            Vista-->>Usuario: Actualiza la lista de amigos en la UI
            deactivate Vista
            
        else Error
            API-->>Modelo: Error (conexión, timeout, validación, etc.)
            Modelo-->>Concurrency: raise Exception(error_message)
            Concurrency-->>Controlador: error_callback(error)
            Controlador->>Vista: ocultar_loading()
            Controlador->>Vista: mostrar_error("Error al añadir amigo: " + error_message)
            activate Vista
            Vista-->>Usuario: Muestra mensaje de error
            deactivate Vista
        end
        
        deactivate Modelo
        
    and Usuario puede interactuar
        Usuario->>Vista: Puede hacer otras acciones (UI responsiva)
        Note over Vista: La interfaz permanece responsiva<br/>durante la operación simple
    end
    
    deactivate Concurrency
    deactivate Controlador
```

## Secuencia para Actualizar un Gasto

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Selecciona gasto y pulsa "Editar gasto"
    activate Vista
    Vista->>Controlador: on_actualizar_gasto_callback(gasto_id)
    deactivate Vista
    activate Controlador

    Controlador->>Modelo: obtener_participantes_gasto(gasto_id)
    activate Modelo
    Modelo->>API: GET /expenses/{id}/friends
    API-->>Modelo: Devuelve IDs de participantes
    deactivate Modelo

    Controlador->>Vista: mostrar_dialogo_editar(gasto, participantes_ids)
    activate Vista
    Vista-->>Usuario: Muestra diálogo con datos precargados
    Usuario->>Vista: Modifica datos y pulsa "Guardar"
    deactivate Vista

    Vista->>Controlador: on_actualizar_gasto_callback(gasto_id, datos)
    Controlador->>Modelo: update_gasto(gasto_id, nuevos_datos)
    activate Modelo
    Modelo->>API: PUT /expenses/{id} (con nuevos datos)
    API-->>Modelo: OK
    deactivate Modelo

    Controlador->>Controlador: self.actualizar_datos()
    Controlador->>Vista: mostrar_pantalla_inicial(modelo)
    activate Vista
    Vista-->>Usuario: Actualiza el gasto en la UI
    deactivate Vista
    deactivate Controlador
```

## Secuencia para Eliminar un Gasto

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Selecciona gasto y pulsa "Eliminar gasto"
    activate Vista
    Vista->>Controlador: on_eliminar_gasto_callback(gasto_id)
    deactivate Vista
    activate Controlador

    Controlador->>Modelo: eliminar_gasto(gasto_id)
    activate Modelo
    Modelo->>API: DELETE /expenses/{gasto_id}
    API-->>Modelo: No Content
    deactivate Modelo

    Controlador->>Controlador: self.actualizar_datos()
    Controlador->>Vista: mostrar_pantalla_inicial(modelo)
    activate Vista
    Vista-->>Usuario: Elimina el gasto de la UI
    deactivate Vista
    deactivate Controlador
```

## Secuencia para Pagar Saldo

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Selecciona amigo y pulsa "Pagar saldo"
    activate Vista
    Vista->>Vista: mostrar_dialogo_pagar_saldo()
    Vista-->>Usuario: Muestra diálogo para introducir importe
    Usuario->>Vista: Introduce importe y pulsa "Pagar"
    deactivate Vista

    Vista->>Controlador: on_pagar_saldo_callback(amigo_id, importe_str)
    activate Controlador
    Controlador->>Controlador: Valida que el importe es > 0
    Controlador->>Modelo: pagar_saldo(amigo_id, importe)
    activate Modelo

    Modelo->>API: GET /friends/{id}/expenses
    activate API
    API-->>Modelo: Lista de gastos del amigo
    deactivate API

    loop para cada gasto con deuda
        Modelo->>API: PUT /expenses/{id}/friends/{id} (con el pago parcial)
        activate API
        API-->>Modelo: OK
        deactivate API
    end

    Modelo-->>Controlador: 
    deactivate Modelo

    Controlador->>Controlador: self.actualizar_datos()
    Controlador->>Vista: mostrar_pantalla_inicial(modelo)
    activate Vista
    Vista-->>Usuario: Actualiza saldos en la UI
    deactivate Vista
    deactivate Controlador
```

## Secuencia para Añadir un Gasto

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Clic en botón "Añadir gasto"
    activate Vista

    Vista->>Controlador: on_add_gasto_callback()
    deactivate Vista
    activate Controlador

    Controlador->>Controlador: Verificar que hay amigos
    Controlador->>Vista: mostrar_dialogo_gasto(amigos)
    activate Vista
    Vista-->>Usuario: Muestra diálogo para introducir datos del gasto
    Usuario->>Vista: Introduce descripción, monto, pagador y participantes
    Vista->>Controlador: on_add_gasto_callback(descripcion, monto_str, pagador_id, deudores_ids)
    deactivate Vista

    Controlador->>Controlador: Validar monto > 0 y participantes
    Controlador->>Modelo: add_gasto(descripcion, monto, pagador_id, deudores_ids)
    activate Modelo

    Modelo->>API: POST /expenses/ (crear gasto)
    API-->>Modelo: Gasto creado con ID
    Modelo->>API: POST /expenses/{id}/friends (añadir participantes)
    API-->>Modelo: Participantes añadidos
    Modelo->>API: PUT /expenses/{id}/friends/{pagador_id} (asignar crédito)
    API-->>Modelo: Crédito asignado
    deactivate Modelo

    Controlador->>Controlador: self.actualizar_datos()
    Controlador->>Vista: mostrar_pantalla_inicial(modelo)
    activate Vista
    Vista-->>Usuario: Actualiza la lista de gastos en la UI
    deactivate Vista

    deactivate Controlador
```

## Secuencia para Eliminar un Amigo

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Selecciona amigo y pulsa "Eliminar amigo"
    activate Vista
    Vista->>Controlador: on_eliminar_amigo_callback(amigo_id)
    deactivate Vista
    activate Controlador

    Controlador->>Modelo: obtener_amigo(amigo_id)
    activate Modelo
    Modelo->>API: GET /friends/{id}
    API-->>Modelo: Datos del amigo con saldos actualizados
    deactivate Modelo

    Controlador->>Controlador: Verificar si saldo == 0 (con tolerancia)

    alt Saldo es efectivamente 0
        Controlador->>Modelo: eliminar_amigo(amigo_id)
        activate Modelo
        Modelo->>API: DELETE /friends/{amigo_id}
        API-->>Modelo: No Content
        deactivate Modelo
        
        Controlador->>Controlador: self.actualizar_datos()
        Controlador->>Vista: mostrar_pantalla_inicial(modelo)
        activate Vista
        Vista-->>Usuario: Amigo eliminado de la UI
        deactivate Vista
    else Saldo no es 0
        Controlador->>Vista: mostrar_error("No se puede eliminar porque tiene saldo pendiente")
        activate Vista
        Vista-->>Usuario: Muestra mensaje de error con el saldo
        deactivate Vista
    end

    deactivate Controlador
```

## Secuencia para Borrar Todos los Gastos

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Pulsa botón "Borrar todos"
    activate Vista
    Vista->>Controlador: on_borrar_todos_gastos_callback()
    deactivate Vista
    activate Controlador

    Controlador->>Modelo: Obtener lista de gastos
    activate Modelo
    Modelo-->>Controlador: Lista de IDs de gastos
    deactivate Modelo

    alt Hay gastos para eliminar
        loop Para cada gasto
            Controlador->>Modelo: eliminar_gasto(gasto_id)
            activate Modelo
            Modelo->>API: DELETE /expenses/{gasto_id}
            API-->>Modelo: No Content
            deactivate Modelo
        end
        
        Controlador->>Controlador: self.actualizar_datos()
        Controlador->>Vista: mostrar_pantalla_inicial(modelo)
        activate Vista
        Vista-->>Usuario: Todos los gastos eliminados de la UI
        deactivate Vista
        
        Controlador->>Vista: mostrar_info("Se eliminaron X gastos correctamente")
        activate Vista
        Vista-->>Usuario: Muestra mensaje de confirmación
        deactivate Vista
    else No hay gastos
        Controlador->>Vista: mostrar_info("No hay gastos para eliminar")
        activate Vista
        Vista-->>Usuario: Muestra mensaje informativo
        deactivate Vista
    end

    deactivate Controlador
```

## Secuencia para Añadir un Amigo con Concurrencia

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Concurrency as "concurrency_service: ConcurrencyService"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Clic en botón "Añadir amigo"
    activate Vista
    Vista->>Vista: mostrar_dialogo_add_amigo()
    Vista-->>Usuario: Muestra diálogo para introducir nombre
    Usuario->>Vista: Introduce nombre y pulsa "Añadir"
    deactivate Vista

    Vista->>Controlador: on_add_amigo_callback(nombre)
    activate Controlador
    
    Controlador->>Vista: mostrar_loading("Añadiendo amigo...")
    Vista-->>Usuario: Muestra spinner y deshabilita UI
    
    Controlador->>Concurrency: execute_async(crear_amigo, callbacks, delay=2.0)
    activate Concurrency
    
    par Operación asíncrona
        Concurrency->>Concurrency: time.sleep(2.0) # Simular delay del servidor
        Concurrency->>Modelo: add_amigo(nombre)
        activate Modelo
        Modelo->>API: POST /friends/
        API-->>Modelo: Nuevo amigo creado
        deactivate Modelo
    and Usuario puede interactuar
        Usuario->>Vista: Puede hacer otras acciones (UI responsiva)
        Note over Vista: La interfaz permanece responsiva<br/>durante la operación
    end
    
    Concurrency->>Vista: callback(on_success)
    Vista->>Vista: ocultar_loading()
    Vista->>Vista: mostrar_pantalla_inicial(modelo)
    Vista-->>Usuario: Actualiza UI con nuevo amigo
    deactivate Concurrency
    deactivate Controlador
```

## Secuencia para Actualizar Datos con Concurrencia

```mermaid
sequenceDiagram
    participant Usuario
    participant Vista as "vista: PantallaInicialView"
    participant Controlador as "controlador: MainController"
    participant Concurrency as "concurrency_service: ConcurrencyService"
    participant Modelo as "modelo: Main"
    participant API as "API Servidor"

    Usuario->>Vista: Clic en botón "Actualizar"
    activate Vista
    Vista->>Controlador: on_actualizar_callback()
    deactivate Vista
    activate Controlador
    
    Controlador->>Vista: mostrar_loading("Cargando datos...")
    Vista-->>Usuario: Muestra spinner y deshabilita UI
    
    Controlador->>Concurrency: execute_async(cargar_datos, callbacks, delay)
    activate Concurrency
    
    par Operación asíncrona
        Concurrency->>Concurrency: time.sleep(delay) # Simular delay del servidor
        Concurrency->>Modelo: cargar_amigos()
        activate Modelo
        Modelo->>API: GET /friends/
        
        alt Éxito cargando amigos
            API-->>Modelo: OK - Lista de amigos
            
            Modelo->>API: GET /expenses/
            
            alt Éxito cargando gastos
                API-->>Modelo: OK - Lista de gastos
                Modelo-->>Concurrency: return True
                Concurrency-->>Controlador: callback(on_success)
                Controlador->>Vista: ocultar_loading()
                Controlador->>Vista: mostrar_pantalla_inicial(modelo)
                activate Vista
                Vista-->>Usuario: Actualiza UI con datos cargados
                deactivate Vista
                
            else Error cargando gastos
                API-->>Modelo: Error cargando gastos
                Modelo-->>Concurrency: raise Exception("Error al cargar gastos")
                Concurrency-->>Controlador: error_callback(error)
                Controlador->>Vista: ocultar_loading()
                Controlador->>Vista: mostrar_error("Error al cargar gastos. Inténtalo de nuevo.")
                activate Vista
                Vista-->>Usuario: Muestra mensaje de error
                deactivate Vista
            end
            
        else Error cargando amigos
            API-->>Modelo: Error cargando amigos
            Modelo-->>Concurrency: raise Exception("Error al cargar amigos")
            Concurrency-->>Controlador: error_callback(error)
            Controlador->>Vista: ocultar_loading()
            Controlador->>Vista: mostrar_error("Error al cargar amigos. Inténtalo de nuevo.")
            activate Vista
            Vista-->>Usuario: Muestra mensaje de error
            deactivate Vista
        end
        
        deactivate Modelo
        
    and Usuario puede interactuar
        Usuario->>Vista: Puede hacer otras acciones (UI responsiva)
        Note over Vista: La interfaz permanece responsiva<br/>durante la carga
    end
    
    deactivate Concurrency
    deactivate Controlador

```
