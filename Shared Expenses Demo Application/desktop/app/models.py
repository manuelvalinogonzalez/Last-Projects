"""
Módulo del modelo de datos de la aplicación de gastos compartidos.

Contiene las clases que representan las entidades de negocio (Amigo, Gasto, Main)
y gestiona toda la comunicación con la API REST del servidor.

Responsabilidades del modelo:
- Definir las entidades de datos (Amigo, Gasto)
- Gestionar la comunicación HTTP con la API (GET, POST, PUT, DELETE)
- Convertir datos entre formato JSON (API) y objetos Python
- Manejar errores de red y HTTP
- Mantener sincronización entre datos locales y remotos
- Calcular saldos y distribuir pagos

La clase Main actúa como el modelo principal que representa un grupo
de amigos compartiendo gastos, y contiene métodos para gestionar
amigos, gastos y cálculos de saldos.
"""

import requests
from datetime import datetime
from requests.exceptions import ConnectionError, Timeout


# Configuración de la API

# URL base de la API REST del servidor
# Por defecto apunta a localhost:8000 (servidor local)
API_BASE_URL = "http://localhost:8000"

# Timeout para peticiones HTTP (en segundos)
# Si una petición tarda más de este tiempo, se lanza una excepción Timeout
REQUEST_TIMEOUT = 10



# Entidades de Datos

class Amigo:
    """
    Representa a un amigo en el grupo de gastos compartidos.
    
    Esta clase encapsula la información de un amigo, incluyendo su saldo
    que se calcula como la diferencia entre créditos y débitos.
    
    Atributos:
        id: Identificador único del amigo (asignado por la API)
        nombre: Nombre del amigo
        credit_balance: Saldo a favor (lo que le deben otros)
        debit_balance: Saldo en contra (lo que debe a otros)
    """
    
    def __init__(self, id: int, nombre: str, credit_balance: float = 0.0, debit_balance: float = 0.0):
        """
        Inicializa un nuevo amigo.
        
        """
        self.id = id
        self.nombre = nombre
        self.credit_balance = credit_balance  # Lo que le deben
        self.debit_balance = debit_balance    # Lo que debe
    
    def saldo(self) -> float:
        """
        Calcula el saldo neto del amigo.
        
        Returns:
            Saldo neto: credit_balance - debit_balance
        """
        return self.credit_balance - self.debit_balance
    
    def actualizar_saldo(self, importe: float):
        """
        Actualiza el saldo a favor del amigo.
        
        """
        self.credit_balance += importe
    
    def to_dict(self) -> dict:
        """
        Convierte el objeto Amigo a un diccionario (dato que almacena pares clave-valor) para enviar a la API.
        
        Returns:
            Diccionario con los datos del amigo en formato JSON
        """
        return {
            #diccionario
            "id": self.id,
            "name": self.nombre
        }


class Gasto:
    """
    Representa un gasto compartido entre varios amigos.
    
    Esta clase encapsula la información de un gasto, incluyendo quién lo pagó,
    quiénes participaron, y cómo se divide el monto entre los participantes.
    
    Atributos:
        id: Identificador único del gasto (asignado por la API)
        descripcion: Descripción del gasto
        monto: Cantidad total del gasto
        fecha: Fecha del gasto (formato YYYY-MM-DD)
        pagador_id: ID del amigo que pagó el gasto
        deudores_ids: Lista de IDs de amigos que participaron (deben su parte)
        credit_balance: Saldo de crédito asociado (para el pagador)
        num_friends: Número de participantes en el gasto
    """
    
    def __init__(self, id: int, descripcion: str, monto: float, 
                 fecha: str, pagador_id = None,
                 deudores_ids = None,
                 credit_balance: float = 0.0, num_friends: int = 1):
        """
        Inicializa un nuevo gasto.
    
        """
        self.id = id
        self.descripcion = descripcion
        self.monto = monto
        self.fecha = fecha
        self.pagador_id = pagador_id  # Quien pagó
        self.deudores_ids = deudores_ids or []  # Quienes participaron
        self.credit_balance = credit_balance
        self.num_friends = num_friends  # Número de participantes
    
    def split(self) -> float:
        """
        Calcula cuánto debe pagar cada participante del gasto.
        
        Divide el monto total entre el número de participantes.
        
        Returns:
            Monto por persona (monto / num_friends)
            Si num_friends es 0, retorna 0.0 para evitar división por cero
        """
        if self.num_friends > 0:
            return self.monto / self.num_friends
        return 0.0
    
    def to_dict(self) -> dict:
        """
        Convierte el objeto Gasto a un diccionario para enviar a la API.
        
        Returns:
            Diccionario con los datos del gasto en formato JSON
        """
        return {
            "id": self.id,
            "description": self.descripcion,
            "amount": self.monto,
            "date": self.fecha
        }


# Funciones de Conversión (JSON ↔ Objetos Python)

def amigo_from_dict(data: dict) -> Amigo:
    """
    Convierte un diccionario JSON (de la API) a un objeto Amigo.
    
    Esta función se usa cuando se reciben datos de la API y se necesitan
    convertir a objetos Python para trabajar con ellos en la aplicación.
    
    Returns:
        Objeto Amigo con los datos del diccionario
    
    Ejemplo:
        data = {"id": 1, "name": "Juan", "credit_balance": 50.0, "debit_balance": 20.0}
        amigo = amigo_from_dict(data)
    """
    return Amigo(
        id=data.get("id"),
        nombre=data.get("name"),
        credit_balance=data.get("credit_balance", 0.0),  # Valor por defecto 0.0 si no existe
        debit_balance=data.get("debit_balance", 0.0)     # Valor por defecto 0.0 si no existe
    )


def gasto_from_dict(data: dict) -> Gasto:
    """
    Convierte un diccionario JSON (de la API) a un objeto Gasto.
    
    Esta función se usa cuando se reciben datos de la API y se necesitan
    convertir a objetos Python para trabajar con ellos en la aplicación.

    Returns:
        Objeto Gasto con los datos del diccionario
    
    Ejemplo:
        data = {"id": 1, "description": "Cena", "amount": 100.0, "date": "2024-01-15"}
        gasto = gasto_from_dict(data)
    """
    return Gasto(
        id=data.get("id"),
        descripcion=data.get("description"),
        monto=data.get("amount"),
        fecha=data.get("date"),
        pagador_id=data.get("pagador_id"),
        credit_balance=data.get("credit_balance", 0.0),  # Valor por defecto 0.0 si no existe
        num_friends=data.get("num_friends", 1)          # Valor por defecto 1 si no existe
    )


# Modelo Principal

class Main:
    """
    Modelo principal que representa un grupo de amigos compartiendo gastos.
    
    Esta clase actúa como el modelo central del MVC, gestionando:
    - La lista de amigos del grupo
    - La lista de gastos compartidos
    - La comunicación con la API REST del servidor
    - Las operaciones CRUD (Create, Read, Update, Delete) sobre amigos y gastos
    - Los cálculos de saldos y distribución de pagos
    
    Atributos:
        id: Identificador del grupo (por defecto 1)
        nombre: Nombre del grupo (por defecto "Grupo Principal")
        amigos: Lista de objetos Amigo que participan en el grupo
        gastos: Lista de objetos Gasto compartidos en el grupo
    """
    
    def __init__(self, id: int = 1, nombre: str = "Grupo Principal"):
        """
        Inicializa el modelo principal del grupo.

        """
        self.id = id
        self.nombre = nombre
        self.amigos: list[Amigo] = []  # Lista de amigos del grupo
        self.gastos: list[Gasto] = []  # Lista de gastos compartidos
    
    # MÉTODOS DE AMIGOS
    
    def cargar_amigos(self) -> list[Amigo]:
        """
        Carga la lista de amigos desde la API REST.
        
        Realiza una petición GET a /friends/ para obtener todos los amigos
        del grupo y actualiza la lista local.
        
        Returns:
            Lista de objetos Amigo cargados desde la API
        
        Ejemplo:
            amigos = modelo.cargar_amigos()
            # Ahora modelo.amigos contiene todos los amigos
        """
        try:
            # Realizar petición GET a la API
            response = requests.get(f"{API_BASE_URL}/friends/", timeout=REQUEST_TIMEOUT)
            # Lanza excepción si el código de estado HTTP no es 2xx (200, 201, etc.)
            response.raise_for_status()
            
            # Convertir la respuesta JSON a una lista de diccionarios Python
            amigos_data = response.json()
            
            # Convertir cada diccionario a un objeto Amigo y actualizar la lista
            self.amigos = [amigo_from_dict(a) for a in amigos_data]
            return self.amigos
            
        except ConnectionError:
            # Error de conexión: el servidor no está disponible o no se puede alcanzar
            raise Exception("No se puede conectar al servidor. Verifica que el servidor esté ejecutándose en http://localhost:8000")
        except Timeout:
            # Timeout: el servidor tardó más de REQUEST_TIMEOUT segundos en responder
            raise Exception("El servidor tardó demasiado en responder. Inténtalo de nuevo más tarde")
        except requests.exceptions.RequestException as e:
            # Otros errores HTTP (500, 503, etc.)
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 500:
                    raise Exception("Error interno del servidor al cargar amigos")
                elif e.response.status_code == 503:
                    raise Exception("Servicio no disponible. Intenta más tarde")
            raise Exception(f"Error al cargar amigos: {str(e)}")
    
    def add_amigo(self, nombre: str) -> Amigo:
        """
        Agrega un nuevo amigo al grupo mediante una petición POST a la API.
        
        Returns:
            Objeto Amigo creado con el ID asignado por la API
        
        Raises:
            Exception: Si hay error de conexión, timeout o HTTP
                - ConnectionError: No se puede conectar al servidor
                - Timeout: El servidor tardó demasiado en responder
                - RequestException: Error HTTP (400, 409, 500, etc.)
        
        Nota:
            El amigo se añade tanto en el servidor como en la lista local.
        """
        try:
            # Preparar los datos del amigo en formato JSON
            amigo_data = {
                "name": nombre
            }
            
            # Realizar petición POST para crear el amigo
            response = requests.post(f"{API_BASE_URL}/friends/", json=amigo_data, timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            
            # Convertir la respuesta a objeto Amigo y añadirlo a la lista local
            amigo = amigo_from_dict(response.json())
            self.amigos.append(amigo)
            return amigo
            
        except ConnectionError:
            raise Exception("No se puede conectar al servidor. Verifica que el servidor esté ejecutándose")
        except Timeout:
            raise Exception("El servidor tardó demasiado en responder. Inténtalo de nuevo")
        except requests.exceptions.RequestException as e:
            # Manejar códigos HTTP específicos
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 400:
                    raise Exception("Datos inválidos. Verifica el nombre del amigo")
                elif e.response.status_code == 409:
                    raise Exception("Ya existe un amigo con ese nombre")
                elif e.response.status_code == 500:
                    raise Exception("Error interno del servidor")
            raise Exception(f"Error al añadir amigo: {str(e)}")
    
    def eliminar_amigo(self, amigo_id: int):
        """
        Elimina un amigo del grupo mediante una petición DELETE a la API.
        
        Raises:
            Exception: Si hay error de conexión, timeout o HTTP
                - ConnectionError: No se puede conectar al servidor
                - Timeout: El servidor tardó demasiado en responder
                - RequestException: Error HTTP (404, 409, 500, etc.)
                409: El amigo tiene saldo pendiente y no se puede eliminar
        
        Nota:
            El amigo se elimina tanto del servidor como de la lista local.
        """
        try:
            # Realizar petición DELETE para eliminar el amigo
            response = requests.delete(f"{API_BASE_URL}/friends/{amigo_id}", timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            
            # Eliminar de la lista local (filtrar por ID)
            self.amigos = [a for a in self.amigos if a.id != amigo_id]
            
        except ConnectionError:
            raise Exception("No se puede conectar al servidor. Verifica que el servidor esté ejecutándose")
        except Timeout:
            raise Exception("El servidor tardó demasiado en responder. Inténtalo de nuevo")
        except requests.exceptions.RequestException as e:
            # Manejar códigos HTTP específicos
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 409:
                    raise Exception("No se puede eliminar el amigo porque tiene saldo pendiente")
                elif e.response.status_code == 404:
                    raise Exception("El amigo no existe")
                elif e.response.status_code == 500:
                    raise Exception("Error interno del servidor")
            raise Exception(f"Error al eliminar amigo: {str(e)}")
    
    def obtener_amigo(self, amigo_id: int) -> Amigo:
        """
        Obtiene los datos de un amigo específico desde la API.
        
        
        Returns:
            Objeto Amigo con los datos actualizados desde la API
        
        Raises:
            Exception: Si hay error de conexión, timeout o HTTP
                - ConnectionError: No se puede conectar al servidor
                - Timeout: El servidor tardó demasiado en responder
                - RequestException: Otros errores HTTP
        """
        try:
            # Realizar petición GET para obtener el amigo
            response = requests.get(f"{API_BASE_URL}/friends/{amigo_id}", timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            
            # Convertir la respuesta a objeto Amigo
            return amigo_from_dict(response.json())
            
        except ConnectionError:
            raise Exception("No se puede conectar al servidor")
        except Timeout:
            raise Exception("El servidor tardó demasiado en responder")
        except requests.exceptions.RequestException as e:
            raise Exception(f"Error al obtener amigo: {str(e)}")
    
    def actualizar_amigo_desde_api(self, amigo_id: int) -> Amigo:
        """
        Actualiza los datos de un amigo específico desde la API.
        
        Obtiene los datos actualizados del amigo desde el servidor y
        actualiza la entrada correspondiente en la lista local.
        
        Returns:
            Objeto Amigo con los datos actualizados
        
        Raises:
            Exception: Si hay error al obtener o actualizar el amigo
        """
        try:
            # Obtener el amigo actualizado desde la API
            amigo_actualizado = self.obtener_amigo(amigo_id)
            
            # Actualizar en la lista local (buscar por ID y reemplazar)
            for i, amigo in enumerate(self.amigos):
                if amigo.id == amigo_id:
                    self.amigos[i] = amigo_actualizado
                    break
            return amigo_actualizado
            
        except Exception as e:
            raise Exception(f"Error al actualizar amigo desde API: {str(e)}")
    
    
    # MÉTODOS DE GASTOS
    
    def cargar_gastos(self) -> list[Gasto]:
        """
        Carga la lista de gastos desde la API REST.
        
        Realiza una petición GET a /expenses/ para obtener todos los gastos
        del grupo. Para cada gasto, también obtiene los participantes y
        identifica al pagador (quien tiene crédito > 0).
        
        Returns:
            Lista de objetos Gasto cargados desde la API con información completa
        
        Raises:
            Exception: Si hay error de conexión, timeout o HTTP
                - ConnectionError: No se puede conectar al servidor
                - Timeout: El servidor tardó demasiado en responder
                - RequestException: Error HTTP (500, 503, etc.)
        
        Nota:
            Este método hace múltiples peticiones HTTP:
            1. GET /expenses/ - Obtiene todos los gastos
            2. GET /expenses/{id}/friends - Para cada gasto, obtiene participantes
            3. GET /expenses/{id}/friends/{friend_id} - Para identificar al pagador
        """
        try:
            # Realizar petición GET para obtener todos los gastos
            response = requests.get(f"{API_BASE_URL}/expenses/", timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            gastos_data = response.json()
            
            # Limpiar la lista local antes de cargar nuevos datos
            self.gastos = []
            
            # Procesar cada gasto de la respuesta
            for g in gastos_data:
                # Convertir el diccionario JSON a objeto Gasto
                gasto = gasto_from_dict(g)
                
                # Enriquecer el gasto con información adicional desde la API
                try:
                    # Obtener los IDs de los participantes del gasto
                    participantes_ids = self.obtener_participantes_gasto(gasto.id)
                    gasto.num_friends = len(participantes_ids)  # Actualizar número de participantes
                    
                    # Identificar al pagador (quien tiene crédito > 0)
                    # El pagador es el que pagó el gasto y tiene saldo a favor
                    pagador_id = None
                    for participante_id in participantes_ids:
                        try:
                            # Obtener información del participante para verificar su crédito
                            response_participante = requests.get(
                                f"{API_BASE_URL}/expenses/{gasto.id}/friends/{participante_id}", 
                                timeout=REQUEST_TIMEOUT
                            )
                            response_participante.raise_for_status()
                            participante_data = response_participante.json()
                            
                            # Si tiene crédito > 0, es el pagador
                            if participante_data.get("credit_balance", 0) > 0:
                                pagador_id = participante_id
                                break
                        except requests.exceptions.RequestException:
                            # Si hay un error con este participante, continuar con el siguiente
                            continue
                    
                    gasto.pagador_id = pagador_id
                    
                except requests.exceptions.RequestException:
                    # Si no se pueden obtener los participantes, mantener el valor original
                    # (no es crítico, el gasto se puede mostrar sin esta información)
                    pass
                
                # Añadir el gasto a la lista local
                self.gastos.append(gasto)
            
            return self.gastos
            
        except ConnectionError:
            raise Exception("No se puede conectar al servidor. Verifica que el servidor esté ejecutándose")
        except Timeout:
            raise Exception("El servidor tardó demasiado en responder. Inténtalo de nuevo")
        except requests.exceptions.RequestException as e:
            # Manejar códigos HTTP específicos
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 500:
                    raise Exception("Error interno del servidor al cargar gastos")
                elif e.response.status_code == 503:
                    raise Exception("Servicio no disponible. Intenta más tarde")
            raise Exception(f"Error al cargar gastos: {str(e)}")
    
    def add_gasto(self, descripcion: str, monto: float, 
                  pagador_id: int, deudores_ids: list[int]) -> Gasto:
        """
        Agrega un nuevo gasto al grupo mediante múltiples peticiones a la API.
        
        Este método realiza una operación compleja en varios pasos:
        1. Crea el gasto básico (POST /expenses/)
        2. Añade los participantes/deudores (POST /expenses/{id}/friends)
        3. Calcula y asigna créditos al pagador y deudas a los deudores
        4. Si algo falla, intenta hacer rollback eliminando el gasto creado

        Returns:
            Objeto Gasto creado con el ID asignado por la API
        
        Raises:
            Exception: Si hay error en cualquier paso del proceso
                - ConnectionError: No se puede conectar al servidor
                - Timeout: El servidor tardó demasiado en responder
                - RequestException: Error HTTP (400, 404, 500, etc.)
        
        Nota:
            Si falla después de crear el gasto, se intenta hacer rollback
            eliminando el gasto creado para mantener la consistencia.
        """
        gasto_id = None  # Guardar ID para posible rollback en caso de error
        try:
            # Paso 1: Crear el gasto básico en la API
            fecha_actual = datetime.now().strftime("%Y-%m-%d")  # Fecha actual en formato ISO
            
            gasto_data = {
                "description": descripcion,
                "amount": monto,
                "date": fecha_actual
            }
            
            # POST /expenses/ - Crear el gasto
            response = requests.post(f"{API_BASE_URL}/expenses/", json=gasto_data, timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            
            # Convertir la respuesta a objeto Gasto
            gasto = gasto_from_dict(response.json())
            gasto_id = gasto.id  # Guardar ID para posible rollback si falla algo después
            gasto.pagador_id = pagador_id  # Asignar el pagador_id al objeto local
            
            # Paso 2: Añadir todos los participantes/deudores al gasto
            # POST /expenses/{id}/friends - Añadir cada participante
            for deudor_id in deudores_ids:
                try:
                    requests.post(
                        f"{API_BASE_URL}/expenses/{gasto.id}/friends",
                        params={"friend_id": deudor_id}
                    ).raise_for_status()
                except requests.exceptions.RequestException as e:
                    raise Exception(f"Error al añadir participante {deudor_id}: {str(e)}")
            
            # Paso 3: Calcular el crédito del pagador
            # El crédito depende de si el pagador está entre los participantes o no
            if pagador_id in deudores_ids:
                # Caso 1: El pagador también participó
                # Solo recibe crédito por la parte que deben los demás (no la suya)
                monto_por_persona = monto / len(deudores_ids)
                monto_otros = monto - monto_por_persona  # Lo que deben los demás
                credito_pagador = monto_otros
            else:
                # Caso 2: El pagador no participó (pagó todo pero no consumió)
                # Recibe crédito por el monto total
                credito_pagador = monto
            
            # Paso 4: Añadir al pagador al gasto y asignarle su crédito
            try:
                # Solo añadir el pagador si no está ya en la lista de deudores
                if pagador_id not in deudores_ids:
                    requests.post(
                        f"{API_BASE_URL}/expenses/{gasto.id}/friends",
                        params={"friend_id": pagador_id}
                    ).raise_for_status()
                
                # Actualizar el crédito del pagador (PUT /expenses/{id}/friends/{friend_id})
                # Esto marca que el pagador tiene crédito (le deben dinero)
                requests.put(
                    f"{API_BASE_URL}/expenses/{gasto.id}/friends/{pagador_id}",
                    params={"amount": credito_pagador}
                ).raise_for_status()
            except requests.exceptions.RequestException as e:
                raise Exception(f"Error al configurar pagador: {str(e)}")
            
            # Paso 5: Ajustar los créditos/deudas de los deudores
            if pagador_id not in deudores_ids:
                # Caso: Pagador no participó
                # Los deudores deben su parte del monto (negativo = deuda)
                monto_por_deudor = -monto / len(deudores_ids)
                for deudor_id in deudores_ids:
                    try:
                        # PUT /expenses/{id}/friends/{friend_id} - Actualizar deuda del deudor
                        requests.put(
                            f"{API_BASE_URL}/expenses/{gasto.id}/friends/{deudor_id}",
                            params={"amount": monto_por_deudor}  # Negativo = debe
                        ).raise_for_status()
                    except requests.exceptions.RequestException as e:
                        raise Exception(f"Error al actualizar crédito de deudor {deudor_id}: {str(e)}")
            else:
                # Caso: Pagador también participó
                # Los demás participantes deben su parte (negativo)
                monto_por_persona = monto / len(deudores_ids)
                for deudor_id in deudores_ids:
                    if deudor_id != pagador_id:  # No actualizar al pagador otra vez (ya tiene crédito)
                        try:
                            # PUT /expenses/{id}/friends/{friend_id} - Actualizar deuda
                            requests.put(
                                f"{API_BASE_URL}/expenses/{gasto.id}/friends/{deudor_id}",
                                params={"amount": -monto_por_persona}  # Negativo = debe
                            ).raise_for_status()
                        except requests.exceptions.RequestException as e:
                            raise Exception(f"Error al actualizar crédito de deudor {deudor_id}: {str(e)}")
            
            # Añadir el gasto a la lista local
            self.gastos.append(gasto)
            return gasto
        except ConnectionError:
            # Manejo de errores con rollback: si se creó el gasto, intentar eliminarlo
            # Esto mantiene la consistencia en caso de error parcial
            if gasto_id:
                try:
                    # Intentar eliminar el gasto creado (rollback)
                    requests.delete(f"{API_BASE_URL}/expenses/{gasto_id}", timeout=REQUEST_TIMEOUT)
                except:
                    pass  # Si falla el rollback, no hay nada más que hacer
            raise Exception("No se puede conectar al servidor. Verifica que el servidor esté ejecutándose")
            
        except Timeout:
            # Manejo de timeout con rollback
            if gasto_id:
                try:
                    # Intentar eliminar el gasto creado (rollback)
                    requests.delete(f"{API_BASE_URL}/expenses/{gasto_id}", timeout=REQUEST_TIMEOUT)
                except:
                    pass
            raise Exception("El servidor tardó demasiado en responder. El gasto podría no haberse creado correctamente")
            
        except requests.exceptions.RequestException as e:
            # Manejo de otros errores HTTP con rollback
            if gasto_id:
                try:
                    # Intentar eliminar el gasto creado (rollback)
                    requests.delete(f"{API_BASE_URL}/expenses/{gasto_id}", timeout=REQUEST_TIMEOUT)
                except:
                    pass  # Si falla el rollback, no hay nada que hacer
            
            # Proporcionar mensaje de error más específico según el código HTTP
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 404:
                    raise Exception("Uno o más participantes no existen")
                elif e.response.status_code == 400:
                    raise Exception("Datos inválidos para el gasto")
                elif e.response.status_code == 500:
                    raise Exception("Error interno del servidor")
            raise Exception(f"Error al añadir gasto: {str(e)}")
    
    def eliminar_gasto(self, gasto_id: int):
        """
        Elimina un gasto del grupo mediante una petición DELETE a la API.

        Raises:
            Exception: Si hay error de conexión, timeout o HTTP
                - ConnectionError: No se puede conectar al servidor
                - Timeout: El servidor tardó demasiado en responder
                - RequestException: Error HTTP (404, 500, etc.)
        
        Nota:
            El gasto se elimina tanto del servidor como de la lista local.
        """
        try:
            # Realizar petición DELETE para eliminar el gasto
            response = requests.delete(f"{API_BASE_URL}/expenses/{gasto_id}", timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            
            # Eliminar de la lista local (filtrar por ID)
            lista_aux = []
            for g in self.gastos:
                if g.id != gasto_id:
                    lista_aux.append(g)
            self.gastos = lista_aux
            
        except ConnectionError:
            raise Exception("No se puede conectar al servidor")
        except Timeout:
            raise Exception("El servidor tardó demasiado en responder")
        except requests.exceptions.RequestException as e:
            # Manejar códigos HTTP específicos
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 404:
                    raise Exception("El gasto no existe")
                elif e.response.status_code == 500:
                    raise Exception("Error interno del servidor")
            raise Exception(f"Error al eliminar gasto: {str(e)}")
    
    def obtener_participantes_gasto(self, gasto_id: int) -> list[int]:
        """
        Obtiene los IDs de los participantes de un gasto desde la API.
        
        Returns:
            Lista de IDs de amigos que participan en el gasto
        
        Raises:
            Exception: Si hay error de conexión, timeout o HTTP
        
        Nota:
            Maneja diferentes estructuras de respuesta de la API:
            - Lista de diccionarios con "friend_id" o "id"
            - Lista directa de enteros (IDs)
        """
        try:
            # Realizar petición GET para obtener los participantes
            response = requests.get(f"{API_BASE_URL}/expenses/{gasto_id}/friends", timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            participantes_data = response.json()
            
            # Manejar diferentes estructuras de respuesta de la API
            # La API puede devolver diferentes formatos según la versión
            participantes_ids = []
            for p in participantes_data:
                if isinstance(p, dict):
                    # Si es un diccionario, buscar friend_id o id
                    if "friend_id" in p:
                        participantes_ids.append(p["friend_id"])
                    elif "id" in p:
                        participantes_ids.append(p["id"])
                elif isinstance(p, int):
                    # Si es directamente un ID (entero)
                    participantes_ids.append(p)
            
            return participantes_ids
            
        except ConnectionError:
            raise Exception("No se puede conectar al servidor")
        except Timeout:
            raise Exception("El servidor tardó demasiado en responder")
        except requests.exceptions.RequestException as e:
            raise Exception(f"Error al obtener participantes del gasto: {str(e)}")
    
    def update_gasto(self, gasto_id: int, nuevos_datos: dict):
        """
        Actualiza un gasto existente en la API.
        
        Este método realiza una actualización compleja que puede incluir:
        - Actualizar datos básicos (descripción, monto, fecha)
        - Cambiar la lista de participantes
        - Recalcular saldos si el monto o participantes cambiaron
        
        Raises:
            Exception: Si hay error de conexión, timeout o HTTP
                - ConnectionError: No se puede conectar al servidor
                - Timeout: El servidor tardó demasiado en responder
                - RequestException: Error HTTP (404, 400, 500, etc.)
        
        Nota:
            Si el monto o los participantes cambian, se recalculan automáticamente
            los saldos de todos los participantes.
        """
        try:
            # Buscar el gasto actual en la lista local
            gasto_actual = None
            for g in self.gastos:
                if g.id == gasto_id:
                    gasto_actual = g
                    break

            if not gasto_actual:
                raise Exception("Gasto no encontrado")
            
            # Verificar si el monto cambió (necesario para recalcular saldos)
            monto_anterior = gasto_actual.monto
            monto_nuevo = nuevos_datos.get("monto", monto_anterior)
            
            # Verificar si los participantes cambiaron (necesario para recalcular saldos)
            participantes_actuales = self.obtener_participantes_gasto(gasto_id)
            nuevos_participantes = nuevos_datos.get("participantes_ids", participantes_actuales)
            
            # Preparar los datos básicos del gasto para actualizar
            gasto_data = {
                "id": gasto_id,
                "description": nuevos_datos.get("descripcion", gasto_actual.descripcion),
                "amount": monto_nuevo,
                "date": nuevos_datos.get("fecha", gasto_actual.fecha)
            }
            
            # PUT /expenses/{id} - Actualizar datos básicos del gasto
            response = requests.put(f"{API_BASE_URL}/expenses/{gasto_id}", json=gasto_data, timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            
            # Si los participantes cambiaron, actualizar la lista de participantes
            if set(participantes_actuales) != set(nuevos_participantes):
                # Eliminar participantes que ya no están en la nueva lista
                for participante_id in participantes_actuales:
                    if participante_id not in nuevos_participantes:
                        try:
                            # DELETE /expenses/{id}/friends/{friend_id} - Eliminar participante
                            requests.delete(f"{API_BASE_URL}/expenses/{gasto_id}/friends/{participante_id}").raise_for_status()
                        except requests.exceptions.RequestException as e:
                            # Registrar el error pero continuar 
                            print(f"Advertencia: No se pudo eliminar participante {participante_id}: {str(e)}")
                            continue
                
                # Añadir nuevos participantes que no estaban antes
                for participante_id in nuevos_participantes:
                    if participante_id not in participantes_actuales:
                        try:
                            # POST /expenses/{id}/friends - Añadir participante
                            requests.post(
                                f"{API_BASE_URL}/expenses/{gasto_id}/friends",
                                params={"friend_id": participante_id}
                            ).raise_for_status()
                        except requests.exceptions.RequestException as e:
                            # Registrar el error pero continuar (
                            print(f"Advertencia: No se pudo añadir participante {participante_id}: {str(e)}")
                            continue
            
            # Si el monto cambió o los participantes cambiaron, recalcular saldos
            if monto_anterior != monto_nuevo or set(participantes_actuales) != set(nuevos_participantes):
                # Obtener el pagador (puede venir en los datos o usar el actual)
                pagador_id = nuevos_datos.get("pagador_id", gasto_actual.pagador_id)
                
                # Si no hay pagador especificado, buscar el que tiene crédito > 0
                if not pagador_id:
                    for participante_id in nuevos_participantes:
                        try:
                            # GET /expenses/{id}/friends/{friend_id} - Obtener info del participante
                            response = requests.get(f"{API_BASE_URL}/expenses/{gasto_id}/friends/{participante_id}")
                            response.raise_for_status()
                            participante_data = response.json()
                            # Si tiene crédito > 0, es el pagador
                            if participante_data.get("credit_balance", 0) > 0:
                                pagador_id = participante_id
                                break
                        except requests.exceptions.RequestException as e:
                            print(f"Advertencia: No se pudo obtener info de participante {participante_id}: {str(e)}")
                            continue
                
                # Recalcular créditos para todos los participantes
                for participante_id in nuevos_participantes:
                    try:
                        if participante_id == pagador_id:
                            # Calcular crédito del pagador
                            if pagador_id in nuevos_participantes:
                                # Caso: Pagador también participó
                                # Solo recibe crédito por la parte de los demás
                                monto_por_persona = monto_nuevo / len(nuevos_participantes)
                                monto_otros = monto_nuevo - monto_por_persona
                                nuevo_credito = monto_otros
                            else:
                                # Caso: Pagador no participó
                                # Recibe crédito por el monto total
                                nuevo_credito = monto_nuevo
                        else:
                            # Los demás participantes no tienen crédito (solo deuda)
                            nuevo_credito = 0
                        
                        # PUT /expenses/{id}/friends/{friend_id} - Actualizar crédito
                        requests.put(
                            f"{API_BASE_URL}/expenses/{gasto_id}/friends/{participante_id}",
                            params={"amount": nuevo_credito}
                        ).raise_for_status()
                    except requests.exceptions.RequestException as e:
                        print(f"Advertencia: No se pudo actualizar crédito de participante {participante_id}: {str(e)}")
                        continue  # Continuar con el siguiente participante
            
            # Actualizar en la lista local con los nuevos datos
            if gasto_actual:
                gasto_actual.descripcion = gasto_data["description"]
                gasto_actual.monto = gasto_data["amount"]
                gasto_actual.fecha = gasto_data["date"]
                gasto_actual.pagador_id = pagador_id
                gasto_actual.deudores_ids = nuevos_participantes
                
        except ConnectionError:
            raise Exception("No se puede conectar al servidor")
        except Timeout:
            raise Exception("El servidor tardó demasiado en responder. Los cambios podrían no haberse guardado")
        except requests.exceptions.RequestException as e:
            # Proporcionar mensajes de error más específicos según el código HTTP
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 404:
                    raise Exception("El gasto o uno de los participantes no existe")
                elif e.response.status_code == 400:
                    raise Exception("Datos inválidos para actualizar el gasto")
                elif e.response.status_code == 500:
                    raise Exception("Error interno del servidor")
            raise Exception(f"Error al actualizar gasto: {str(e)}")
    
    # MÉTODOS DE CÁLCULO
    
    def calcular_saldos(self) -> dict[int, float]:
        """
        Calcula los saldos de todos los amigos del grupo.
        
        Returns:
            Diccionario que mapea ID de amigo a su saldo neto
            - Clave: ID del amigo (int)
            - Valor: Saldo neto (float)
                - Positivo: le deben dinero
                - Negativo: debe dinero
                - Cero: está al día
        """
        saldos = {}
        for amigo in self.amigos:
            saldos[amigo.id] = amigo.saldo()  # credit_balance - debit_balance
        return saldos
    
    def pagar_saldo(self, amigo_id: int, importe: float):
        """
        Registra un pago realizado por un amigo para saldar su deuda.
        
        Este método distribuye el pago entre los gastos pendientes del amigo,
        aplicando el pago primero a los gastos más antiguos hasta agotar el importe.

        Flujo:
        1. Obtiene todos los gastos del amigo desde la API
        2. Para cada gasto con deuda pendiente:
           - Calcula cuánto debe en ese gasto
           - Aplica el pago (hasta agotar el importe)
           - Actualiza el crédito del amigo en ese gasto
        3. Recarga los datos de amigos para actualizar saldos
        
        Raises:
            Exception: Si hay error de conexión, timeout o HTTP
                - ConnectionError: No se puede conectar al servidor
                - Timeout: El servidor tardó demasiado en responder
                - RequestException: Error HTTP (404, 400, 500, etc.)
        
        Nota:
            El pago se distribuye automáticamente entre los gastos pendientes.
            Si el importe es mayor que la deuda total, el exceso se aplica
            como crédito adicional.
        """
        try:
            # Paso 1: Obtener todos los gastos del amigo desde la API
            # GET /friends/{id}/expenses - Obtener gastos donde participa el amigo
            response = requests.get(f"{API_BASE_URL}/friends/{amigo_id}/expenses", timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            gastos_amigo = response.json()
            
            # Paso 2: Distribuir el pago entre los gastos pendientes
            # Se aplica el pago a cada gasto hasta agotar el importe
            importe_restante = importe
            for gasto_data in gastos_amigo:
                # Si ya se agotó el importe, no procesar más gastos
                if importe_restante <= 0:
                    break
                
                gasto_id = gasto_data["id"]
                # Calcular la deuda pendiente en este gasto
                # deuda = débito - crédito (positivo = debe dinero)
                deuda = gasto_data["debit_balance"] - gasto_data["credit_balance"]
                
                if deuda > 0:
                    # Calcular cuánto se puede pagar de este gasto
                    # (el mínimo entre lo que queda del pago y la deuda)
                    pago = min(importe_restante, deuda)
                    
                    # PUT /expenses/{id}/friends/{friend_id} - Actualizar crédito del amigo
                    # Al aumentar el crédito, se reduce la deuda
                    requests.put(
                        f"{API_BASE_URL}/expenses/{gasto_id}/friends/{amigo_id}",
                        params={"amount": pago},  # Aumentar crédito = reducir deuda
                        timeout=REQUEST_TIMEOUT
                    )
                    importe_restante -= pago  # Reducir el importe restante
            
            # Paso 3: Recargar los datos de amigos para actualizar los saldos
            # Esto asegura que los saldos mostrados en la UI estén actualizados
            self.cargar_amigos()
            
        except ConnectionError:
            raise Exception("No se puede conectar al servidor")
        except Timeout:
            raise Exception("El servidor tardó demasiado en responder. El pago podría no haberse registrado correctamente")
        except requests.exceptions.RequestException as e:
            # Manejar códigos HTTP específicos
            if hasattr(e, 'response') and e.response is not None:
                if e.response.status_code == 404:
                    raise Exception("El amigo o sus gastos no existen")
                elif e.response.status_code == 400:
                    raise Exception("Datos de pago inválidos")
                elif e.response.status_code == 500:
                    raise Exception("Error interno del servidor")
            raise Exception(f"Error al registrar pago: {str(e)}")


