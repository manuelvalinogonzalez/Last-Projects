"""
Módulo de gestión de traducciones e internacionalización (i18n).

Este módulo proporciona funcionalidades para:
- Cambiar el idioma de la aplicación
- Traducir mensajes usando gettext
- Formatear monedas según el idioma seleccionado
- Formatear fechas según las convenciones locales
- Obtener símbolos de moneda apropiados

Utiliza la biblioteca estándar de Python `gettext` para la gestión de traducciones
y `locale` para el formateo de números y monedas según las convenciones regionales.
"""

import gettext
import locale
import os
from pathlib import Path

class TranslationManager:
    """
    Gestor de traducciones para la aplicación.
    
    Esta clase maneja la carga y gestión de traducciones utilizando gettext,
    permitiendo cambiar dinámicamente el idioma de la aplicación.
    """
    
    def __init__(self):
        """Inicializa el gestor de traducciones con inglés como idioma por defecto."""
        self.current_language = 'en'  # Idioma por defecto: inglés
        self.current_locale = 'en_US.UTF-8'  # Locale por defecto: inglés (EE.UU)
        self.translator = None  # Objeto translator de gettext (se inicializa en _setup_translations)
        self._setup_translations()
    
    def _setup_translations(self):
        """
        Configura inicialmente las traducciones.
        
        Busca el directorio 'locales' en la raíz del proyecto y configura
        un translator nulo (sin traducciones) como punto de partida.
        Si las traducciones no están disponibles, el sistema funcionará
        mostrando los mensajes en su idioma original.
        """
        base_dir = Path(__file__).parent.parent  # Directorio raíz del proyecto
        locale_dir = base_dir / 'locales'  # Directorio donde se almacenan los archivos .po/.mo
        
        # NullTranslations devuelve el mensaje original sin traducir
        self.translator = gettext.NullTranslations()
        
    def set_language(self, language_code: str, encoding: str = None):
        """
        Establece el idioma activo de la aplicación y carga las traducciones correspondientes.
        
        El método maneja dos formatos de entrada:
        - Locale completo con código de país: 'es_ES', 'pt_PT', 'en_US' usado para monedas, fechas, numeros, etc.
        - Solo código de idioma: 'es', 'pt', 'en' usado para el idioma de la aplicacion
        
        Intenta cargar los archivos de traducción desde el directorio 'locales'.
        Si no encuentra el idioma solicitado, utiliza NullTranslations como fallback.
        """
        # Guardar el locale completo si viene con código de país (ej: es_ES, pt_PT)
        if language_code and '_' in language_code:
            # Si viene con encoding explícito, usarlo; sino, usar UTF-8 por defecto
            self.current_locale = f"{language_code}.{encoding}" if encoding else f"{language_code}.UTF-8"
            # Extraer solo el código de idioma 
            language_code = language_code.split('_')[0]
        else:
            # Si solo viene el código de idioma, construir un locale por defecto
            if language_code == 'es':
                self.current_locale = 'es_ES.UTF-8'  # Español de España
            elif language_code == 'pt':
                self.current_locale = 'pt_PT.UTF-8'  # Portugués de Portugal
            else:
                self.current_locale = 'en_US.UTF-8'  # Inglés de Estados Unidos por defecto

        self.current_language = language_code
        
        # Obtener ruta al directorio de traducciones
        base_dir = Path(__file__).parent.parent
        locale_dir = base_dir / 'locales'
        
        # Intentar cargar las traducciones desde los archivos .mo
        try:
            self.translator = gettext.translation(
                'messages',  # Dominio de traducción (nombre base de los archivos .po/.mo)
                localedir=str(locale_dir),  # Directorio donde buscar las traducciones
                languages=[language_code],  # Lista de idiomas a cargar
                fallback=True  # Si no encuentra el idioma, usar NullTranslations
            )
        except Exception as e:
            # Si no encuentra el idioma, se usa el inglés por defecto (NullTranslations)
            print(f"Warning: Could not load translations for {language_code}: {e}")
            self.translator = gettext.NullTranslations()
    
    
    def get_current_language(self) -> str:
        """
        Obtiene el código del idioma actualmente activo.
        
        Returns:
            Código del idioma (ej: 'es', 'en', 'pt')
        """
        return self.current_language
    
    def get_locale(self) -> str:
        """
        Obtiene el locale completo actualmente configurado.
        
        Returns:
            Locale completo (ej: 'es_ES.UTF-8', 'en_US.UTF-8')
        """
        return self.current_locale
    
    def translate(self, message: str) -> str:
        """
        Traduce un mensaje al idioma actualmente activo.
        
        Returns:
            Mensaje traducido o el original si no hay traducción disponible
        """
        return self.translator.gettext(message)

# Instancia global del gestor de traducciones
# Se crea una única instancia compartida en toda la aplicación
translation_manager = TranslationManager()

# Funciones de conveniencia para acceso global al gestor de traducciones

def set_language(language_code: str, encoding: str = None):
    """
    Función de conveniencia para cambiar el idioma de la aplicación.

    """
    translation_manager.set_language(language_code, encoding)

def get_current_language() -> str:
    """
    Función de conveniencia para obtener el idioma actual.
    
    Returns:
        Código del idioma activo
    """
    return translation_manager.get_current_language()

def get_locale() -> str:
    """
    Función de conveniencia para obtener el locale actual.
    
    Returns:
        Locale completo configurado
    """
    return translation_manager.get_locale()

def _(message: str) -> str:
    """
    Función de traducción abreviada (convención estándar de gettext).
    
    Esta función permite usar la sintaxis estándar de gettext: _("Mensaje")
    para traducir mensajes de forma sencilla.
    
    Returns:
        Mensaje traducido o el original si no hay traducción disponible
    
    Ejemplo:
        texto = _("Hello")  # Devuelve "Hola" si el idioma es español
    """
    return translation_manager.translate(message)


# Funciones de formateo según el idioma actual


def format_currency(amount: float) -> str:
    """
    Formatea un valor numérico como moneda según el idioma actual.
    
    Intenta usar el locale del sistema para un formateo preciso.
    Si falla, usa un formateo manual basado en el idioma:
    - Español/Portugués: formato europeo con euro (€)
    - Inglés: formato americano con dólar ($)
    
    Returns:
        String con la moneda formateada (ej: "1.234,56 €", "$1,234.56")
    
    Nota:
        El locale se configura temporalmente y se restaura al valor anterior
        para no afectar otras partes de la aplicación.
    """
    try:
        # Establecer el locale para formateo numérico y monetario
        current_locale = translation_manager.get_locale()
        
        # Guardar el locale actual para restaurarlo después
        # Se configura el locale temporalmente para formatear la moneda según el idioma seleccionado
        old_locale = locale.setlocale(locale.LC_MONETARY, None)
        try:
            # Configurar el locale para formateo monetario
            locale.setlocale(locale.LC_MONETARY, current_locale)
            
            # Formatear la moneda con separadores de miles (grouping=True)
            formatted = locale.currency(amount, grouping=True)
            return formatted
        finally:
            # Restaurar locale anterior para no afectar otras partes de la aplicación
            locale.setlocale(locale.LC_MONETARY, old_locale)
    except Exception as e:
        # Fallback: formato manual por idioma si falla la configuración del locale
        lang = translation_manager.current_language
        if lang == 'pt':
            # Portugués: coma como separador decimal, punto para miles, símbolo €
            return f"{amount:.2f} €".replace('.', ',')
        elif lang == 'es':
            # Español: formato similar, símbolo €
            return f"{amount:.2f} €"
        else:
            # Inglés (y otros): formato americano, símbolo $
            return f"${amount:.2f}"

def format_date(date_str: str) -> str:
    """
    Formatea una fecha según las convenciones del idioma actual.
    
    Espera una fecha en formato ISO (YYYY-MM-DD) y la convierte:
    - Español/Portugués: formato día/mes/año (DD/MM/YYYY)
    - Inglés: formato mes/día/año (MM/DD/YYYY)
    
    Returns:
        Fecha formateada según el idioma o la fecha original si hay error
    
    Ejemplo:
        format_date("2024-03-15") -> "15/03/2024" (es) o "03/15/2024" (en)
    """
    try:
        from datetime import datetime
        # Parsear la fecha desde formato ISO
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
        
        # Formatear según el idioma actual
        lang = translation_manager.current_language
        if lang == 'es':
            # Formato español: día/mes/año
            return date_obj.strftime("%d/%m/%Y")
        elif lang == 'pt':
            # Formato portugués: día/mes/año (igual que español)
            return date_obj.strftime("%d/%m/%Y")
        else:
            # Formato inglés/americano: mes/día/año
            return date_obj.strftime("%m/%d/%Y")
    except Exception:
        # Fallback: devolver el original si hay error en el parseo
        return date_str

def get_currency_symbol() -> str:
    """
    Obtiene el símbolo de moneda apropiado según el idioma actual.
    
    Returns:
        Símbolo de moneda: '€' para español/portugués, '$' para inglés y otros
    
    Ejemplo:
        get_currency_symbol() -> "€" (si idioma es es o pt)
        get_currency_symbol() -> "$" (si idioma es en u otro)
    """
    lang = translation_manager.current_language
    if lang in ['es', 'pt']:
        return '€'  # Euro para español y portugués
    else:
        return '$'  # Dólar para inglés y otros idiomas
