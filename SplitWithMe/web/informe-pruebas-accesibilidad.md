# Informe de Pruebas Exploratorias de Accesibilidad WAI-ARIA

## SplitWithMe - Aplicación de Compartición de Gastos

**Fecha:** Diciembre 2025  
**Versión:** 1.0  
**Normativa:** WAI-ARIA 1.2, WCAG 2.1

---

## 1. Introducción

Este documento describe las pruebas exploratorias realizadas para validar la accesibilidad de la interfaz web de SplitWithMe según las normas WAI-ARIA y WCAG 2.1.

---

## 2. Listado de Pruebas Exploratorias

### 2.1. Navegación por Teclado

| ID | Prueba | Criterio WCAG | Resultado Esperado |
|----|--------|---------------|-------------------|
| NAV-01 | Navegar con Tab por todos los elementos interactivos | 2.1.1 Teclado | El foco se mueve secuencialmente por botones, enlaces e inputs |
| NAV-02 | Usar Skip Link para saltar al contenido principal | 2.4.1 Evitar Bloques | Al presionar Tab y luego Enter, el foco salta al contenido principal |
| NAV-03 | Navegar entre tabs con flechas izquierda/derecha | 2.1.1 Teclado | Las flechas cambian entre paneles Gastos/Amigos |
| NAV-04 | Cerrar modales con tecla Escape | 2.1.1 Teclado | El modal se cierra y el foco vuelve al elemento que lo abrió |
| NAV-05 | Focus trap dentro de modales | 2.4.3 Orden del Foco | Tab/Shift+Tab mantienen el foco dentro del modal abierto |
| NAV-06 | Indicador visual de foco | 2.4.7 Foco Visible | Todos los elementos focusables muestran un indicador visible |

### 2.2. Lectores de Pantalla

| ID | Prueba | Criterio WCAG | Resultado Esperado |
|----|--------|---------------|-------------------|
| SR-01 | Anuncio de cambio de panel | 4.1.3 Mensajes de Estado | El lector anuncia "Mostrando panel de [nombre]" |
| SR-02 | Lectura de gastos con monto | 1.1.1 Contenido No Textual | El lector dice "Monto: X euros con Y céntimos" |
| SR-03 | Lectura de balances de amigos | 1.1.1 Contenido No Textual | El lector indica si es positivo/negativo y la cantidad |
| SR-04 | Anuncio de apertura/cierre de modales | 4.1.3 Mensajes de Estado | El lector anuncia cuando se abre/cierra un modal |
| SR-05 | Identificación de botones de acción | 4.1.2 Nombre, Función, Valor | Botones tienen labels descriptivos (ej: "Editar gasto: Cena") |
| SR-06 | Lectura de errores de validación | 3.3.1 Identificación de Errores | Los errores se anuncian inmediatamente |
| SR-07 | Estructura de encabezados | 1.3.1 Información y Relaciones | Hay un h1 oculto y h2 visibles correctamente estructurados |

### 2.3. Semántica y Estructura ARIA

| ID | Prueba | Criterio WCAG | Resultado Esperado |
|----|--------|---------------|-------------------|
| ARIA-01 | Roles de landmark correctos | 1.3.1 Información y Relaciones | main, banner, navigation identificados correctamente |
| ARIA-02 | Roles de tabs/tabpanel | 4.1.2 Nombre, Función, Valor | tablist, tab, tabpanel con aria-selected correcto |
| ARIA-03 | Roles de diálogos modales | 4.1.2 Nombre, Función, Valor | role="dialog" y aria-modal="true" en modales |
| ARIA-04 | aria-labelledby en secciones | 1.3.1 Información y Relaciones | Secciones vinculadas a sus encabezados |
| ARIA-05 | aria-describedby en inputs | 3.3.2 Etiquetas o Instrucciones | Campos de formulario vinculados a mensajes de error |
| ARIA-06 | aria-hidden en iconos decorativos | 1.1.1 Contenido No Textual | SVGs e iconos emoji ocultos para lectores de pantalla |
| ARIA-07 | aria-live para anuncios | 4.1.3 Mensajes de Estado | Región aria-live polite para anuncios dinámicos |
| ARIA-08 | aria-invalid en validación | 3.3.1 Identificación de Errores | Campos inválidos marcados con aria-invalid="true" |

### 2.4. Contraste y Visualización

| ID | Prueba | Criterio WCAG | Resultado Esperado |
|----|--------|---------------|-------------------|
| VIS-01 | Contraste de texto normal | 1.4.3 Contraste (Mínimo) | Ratio mínimo 4.5:1 para texto normal |
| VIS-02 | Contraste de texto grande | 1.4.3 Contraste (Mínimo) | Ratio mínimo 3:1 para texto grande |
| VIS-03 | Contraste en modo oscuro | 1.4.3 Contraste (Mínimo) | Contraste adecuado en preferencia de esquema oscuro |
| VIS-04 | Modo de alto contraste | 1.4.11 Contraste No Textual | Bordes y controles visibles en prefers-contrast: more |
| VIS-05 | Indicadores de estado (positivo/negativo) | 1.4.1 Uso del Color | Los balances no dependen solo del color |

### 2.5. Movimiento y Animaciones

| ID | Prueba | Criterio WCAG | Resultado Esperado |
|----|--------|---------------|-------------------|
| MOV-01 | Reducción de movimiento | 2.3.3 Animación desde Interacciones | Animaciones deshabilitadas con prefers-reduced-motion |
| MOV-02 | Transiciones de panel | 2.3.1 Tres Destellos o por Debajo del Umbral | Sin parpadeos ni transiciones peligrosas |

### 2.6. Formularios y Validación

| ID | Prueba | Criterio WCAG | Resultado Esperado |
|----|--------|---------------|-------------------|
| FORM-01 | Labels asociados a inputs | 1.3.1 Información y Relaciones | Todos los inputs tienen label asociado |
| FORM-02 | Campos requeridos marcados | 3.3.2 Etiquetas o Instrucciones | aria-required="true" en campos obligatorios |
| FORM-03 | Mensajes de error descriptivos | 3.3.1 Identificación de Errores | Errores indican qué campo y qué problema |
| FORM-04 | Grupos de checkboxes con fieldset | 1.3.1 Información y Relaciones | Fieldset con legend para participantes |
| FORM-05 | Select accesible | 4.1.2 Nombre, Función, Valor | Select de "Pagado por" navegable con teclado |

### 2.7. Interactividad Dinámica

| ID | Prueba | Criterio WCAG | Resultado Esperado |
|----|--------|---------------|-------------------|
| DIN-01 | Agregar gasto dinámicamente | 4.1.3 Mensajes de Estado | Se anuncia "Gasto [nombre] agregado" |
| DIN-02 | Eliminar elemento | 4.1.3 Mensajes de Estado | Se anuncia confirmación y resultado |
| DIN-03 | Actualización de balances | 4.1.3 Mensajes de Estado | Los cambios en balances son perceptibles |
| DIN-04 | Restauración de foco al cerrar modal | 2.4.3 Orden del Foco | El foco vuelve al botón que abrió el modal |

---

## 3. Resultados de las Pruebas

### 3.1. Resumen de Resultados

| Categoría | Total Pruebas | Pasadas | Fallidas | Parciales |
|-----------|---------------|---------|----------|-----------|
| Navegación por Teclado | 6 | 6 | 0 | 0 |
| Lectores de Pantalla | 7 | 7 | 0 | 0 |
| Semántica ARIA | 8 | 8 | 0 | 0 |
| Contraste y Visualización | 5 | 5 | 0 | 0 |
| Movimiento y Animaciones | 2 | 2 | 0 | 0 |
| Formularios y Validación | 5 | 5 | 0 | 0 |
| Interactividad Dinámica | 4 | 4 | 0 | 0 |
| **TOTAL** | **37** | **37** | **0** | **0** |

### 3.2. Detalle de Pruebas Realizadas

#### NAV-01: Navegación con Tab ✅ PASADA
- **Método:** Navegar por la aplicación usando solo la tecla Tab
- **Observación:** Todos los botones, inputs y elementos interactivos son accesibles secuencialmente
- **Resultado:** El orden de tabulación es lógico y completo

#### NAV-02: Skip Link ✅ PASADA
- **Método:** Al cargar la página, presionar Tab y luego Enter
- **Observación:** El enlace "Saltar al contenido principal" aparece visible al recibir foco
- **Resultado:** El foco se mueve correctamente al contenido principal

#### NAV-03: Navegación entre tabs ✅ PASADA
- **Método:** Con foco en un tab, usar flechas izquierda/derecha
- **Observación:** Las flechas alternan entre Gastos y Amigos
- **Resultado:** Implementación correcta del patrón WAI-ARIA para tabs

#### NAV-04: Cerrar modales con Escape ✅ PASADA
- **Método:** Abrir un modal y presionar Escape
- **Observación:** El modal se cierra inmediatamente
- **Resultado:** Funcionalidad implementada en todos los modales

#### NAV-05: Focus trap en modales ✅ PASADA
- **Método:** Abrir modal y navegar con Tab/Shift+Tab repetidamente
- **Observación:** El foco se mantiene dentro del modal
- **Resultado:** Focus trap correctamente implementado

#### NAV-06: Indicador visual de foco ✅ PASADA
- **Método:** Navegar con teclado observando indicadores visuales
- **Observación:** Todos los elementos muestran outline azul de 3px
- **Resultado:** Indicadores visibles y consistentes

#### SR-01: Anuncio de cambio de panel ✅ PASADA
- **Método:** Cambiar de panel con lector de pantalla activo
- **Observación:** Se anuncia "Mostrando panel de Gastos/Amigos"
- **Resultado:** Región aria-live funciona correctamente

#### SR-02: Lectura de gastos ✅ PASADA
- **Método:** Navegar a un ítem de gasto con lector de pantalla
- **Observación:** Se lee título, quién pagó, y monto con descripción accesible
- **Resultado:** Información completa y comprensible

#### SR-03: Lectura de balances ✅ PASADA
- **Método:** Navegar a balances de amigos con lector de pantalla
- **Observación:** Se indica "Balance positivo: le deben X euros" o "Balance negativo: debe X euros"
- **Resultado:** Contexto completo sin depender del color

#### SR-04: Anuncio de modales ✅ PASADA
- **Método:** Abrir y cerrar modales con lector de pantalla
- **Observación:** Se anuncia apertura y cierre de modales
- **Resultado:** Mensajes de estado correctos

#### SR-05: Identificación de botones ✅ PASADA
- **Método:** Navegar a botones de editar/eliminar
- **Observación:** Se lee "Editar gasto: [nombre]" o "Eliminar amigo: [nombre]"
- **Resultado:** Labels descriptivos y contextuales

#### SR-06: Lectura de errores ✅ PASADA
- **Método:** Enviar formulario con errores
- **Observación:** Los errores tienen role="alert" y se anuncian
- **Resultado:** Errores identificados correctamente

#### SR-07: Estructura de encabezados ✅ PASADA
- **Método:** Revisar jerarquía de encabezados
- **Observación:** h1 oculto para el título de la app, h2 para secciones
- **Resultado:** Estructura jerárquica correcta

#### ARIA-01 a ARIA-08 ✅ TODAS PASADAS
- **Observación:** Todos los roles ARIA implementados correctamente
- **Detalles:**
  - Landmarks: main, banner, navigation presentes
  - Tabs: role="tablist", role="tab", role="tabpanel" con aria-selected
  - Modales: role="dialog", aria-modal="true", aria-labelledby
  - Regiones live: aria-live="polite", aria-atomic="true"

#### VIS-01 a VIS-05 ✅ TODAS PASADAS
- **Método:** Verificar contraste con herramientas y modos de visualización
- **Observación:** Contraste adecuado en todos los modos
- **Resultado:** Cumple con ratio 4.5:1 mínimo

#### MOV-01 y MOV-02 ✅ PASADAS
- **Método:** Activar prefers-reduced-motion y verificar
- **Observación:** Animaciones deshabilitadas, sin parpadeos
- **Resultado:** Respeta preferencias del usuario

#### FORM-01 a FORM-05 ✅ TODAS PASADAS
- **Método:** Revisar formularios con herramientas de inspección
- **Observación:** Labels, fieldsets, aria-required correctos
- **Resultado:** Formularios completamente accesibles

#### DIN-01 a DIN-04 ✅ TODAS PASADAS
- **Método:** Realizar operaciones CRUD y verificar anuncios
- **Observación:** Todos los cambios se anuncian correctamente
- **Resultado:** Contenido dinámico accesible

---

## 4. Herramientas Utilizadas

1. **Navegación manual por teclado** - Tab, Shift+Tab, flechas, Enter, Escape
2. **NVDA / VoiceOver** - Lectores de pantalla
3. **DevTools de navegador** - Inspector de accesibilidad
4. **axe DevTools** - Extensión para auditoría automática
5. **WAVE** - Web Accessibility Evaluation Tool
6. **Color Contrast Analyzer** - Verificación de contraste

---

## 5. Correcciones Implementadas

Durante el proceso de pruebas, se implementaron las siguientes correcciones:

### 5.1. HTML
- ✅ Añadido Skip Link para saltar al contenido principal
- ✅ Añadida región aria-live persistente para anuncios
- ✅ Añadido header con h1 oculto para estructura semántica
- ✅ Cambiado navegación mobile a patrón de tabs (role="tablist", role="tab")
- ✅ Añadido role="tabpanel" a las secciones
- ✅ Eliminados atributos aria-label vacíos redundantes en SVGs
- ✅ Añadido focusable="false" a SVGs decorativos
- ✅ Añadidos aria-label descriptivos a balances (+/-/neutral)
- ✅ Añadidos role="group" a grupos de botones de acción
- ✅ Corregidos botones con textos alternativos vacíos

### 5.2. CSS
- ✅ Estilos para Skip Link (visible solo al recibir foco)
- ✅ Mejorado :focus-visible para todos los elementos interactivos
- ✅ Estilos de focus adaptados para modo oscuro
- ✅ Estilos de focus para modo de alto contraste

### 5.3. JavaScript
- ✅ Implementado focus trap en todos los modales
- ✅ Guardado y restauración de foco al abrir/cerrar modales
- ✅ Función anunciarCambio() usa región aria-live persistente
- ✅ Navegación por teclado en tabs (flechas, Home, End)
- ✅ Actualización de aria-selected y tabindex en cambio de tabs
- ✅ Gestión de aria-hidden en paneles al cambiar

---

## 6. Conclusiones

La aplicación SplitWithMe cumple con las normas de accesibilidad WAI-ARIA 1.2 y WCAG 2.1 nivel AA. Se han implementado todas las mejoras necesarias para garantizar que los usuarios que dependen de tecnologías asistivas puedan utilizar la aplicación de manera efectiva.

### Aspectos destacados:
- ✅ Navegación completa por teclado
- ✅ Compatible con lectores de pantalla
- ✅ Semántica ARIA correcta
- ✅ Gestión adecuada del foco
- ✅ Anuncios de cambios dinámicos
- ✅ Contraste visual adecuado
- ✅ Respeto por preferencias de usuario (movimiento reducido, esquema de color)

---

## 7. Anexo: Checklist de Verificación Rápida

- [x] Skip link funcional
- [x] Estructura de encabezados jerárquica
- [x] Todos los elementos interactivos accesibles por teclado
- [x] Indicador de foco visible
- [x] Imágenes y iconos tienen texto alternativo o están ocultos
- [x] Formularios con labels asociados
- [x] Errores identificados claramente
- [x] Modales con focus trap
- [x] Cambios dinámicos anunciados
- [x] Contraste suficiente
- [x] Sin dependencia exclusiva del color
- [x] Animaciones respetan prefers-reduced-motion

