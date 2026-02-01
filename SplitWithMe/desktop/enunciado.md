# Curso 25/26. Práctica 1. Interfaces gráficas para aplicaciones de escritorio

## Welcome :wave:

- **Who is this for**: Grupos de prácticas de la asignatura _IPM_.

- **What you'll learn**: Implementación de interfaces gráficas,
  patrones arquitectónicos para el manejo del estado con interfaces
  gráficas, uso y necesidad de la concurrencia en interfaces
  gráficas, internacionalización de intefaces gráficas.

- **What you'll build**: Construiréis una aplicación con una interface
  gráfica de escritorio.

  La aplicación es la misma para la cual diseñaste la interfaz en la
  práctica individual.
  
- **Prerequisites**: Asumimos que os resultan familiares el lenguaje de
  programación _python_ y la librería _Gtk+_.

- **How long**: Este assigment está formado por tres pasos o
  _tareas_. La duración estimada de cada tarea es de una semana
  lectiva.


<details id=1>
<summary><h2>Tarea 1: Diseño software e implementación</h2></summary>

### :wrench: Esta tarea tiene las siguientes partes:

  1. Define el conjunto de casos de uso y el diseño correspondiente
     de la interfaz para desarrollar en esta práctica.
  
     En esta ocasión no incluyas las opciones de añadir, editar,
	 borrar participantes de la B.D. Asume que estos aspectos de la
	 aplicación los desarrolla otro equipo de trabajo.
	 
	 Construye el diseño a partir de lo aprendido en la práctica
     individual y la puesta en común del trabajo de los miembros del
     equipo de desarrollo.
	 	 
     Añade el diseño al repositorio en un fichero `diseño-iu.pdf` en
	 formato _PDF_.

  2. Busca un patrón arquitectónico que cumpla estos requisitos:
  
     - El componente de la _vista_ es totalmente independiente del
       _estado/modelo_.
	   
     - Es adecuado para la aplicación que estás desarrollando, y para
	   la librería de widgets y el lenguaje de programación.
	 
  3. Realiza el diseño software basándote en el patrón seleccionado.
  
	  - Usa el lenguaje _UML_.
	  
	  - Incluye los diagramas de la parte estática y de la parte
        dinámica.
		
	  - El diseño sw tiene que permitir implementar todos los casos de
        uso de la aplicación.
	  
	  - Añade el diseño sw al repositorio en un fichero `diseño_sw.md`
        en formato _markdown_ [Github Flavored
        Markdown](https://docs.github.com/es/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax).
		
		Describe los diagramas UML usando
        [_Mermaid_](https://github.blog/2022-02-14-include-diagrams-markdown-files-mermaid/).
		
  4. Implementa la aplicación siguiendo los diseños previos.
	 
	   - Usa el lenguaje de programación es python.
	   
	   - Usa la librería gráfica es GTK, versión 4.
	   
	   - Divide el código en módulos siguiendo la arquitectura de la
         aplicación.
	   
	   - Usa el servidor que está disponible en el [repositorio del
         servidor](https://github.com/nbarreira/splitwithme).
		 
	   - Implementa los _scripts_ necesarios para popular la BD del
         servidor con datos de prueba.
	   

### :books: Objetivos de aprendizaje:

  - Patrones arquitectónicos en IGUs.
  
  - Uso de librerías para construir IGUs.
  
  - Programación dirigida por eventos


</details>


<details id=2>
<summary><h2>Tarea 2: Gestión de la concurrencia y la E/S en IGUs</h2></summary>

### :wrench: Esta tarea tiene las siguientes partes:

  1. Identifica las operaciones que pueden resultar erroneas.
  
     > :warning: No confundir con los errores que comete la usuaria.

	 > **TIP:** Muy probablemente son las peticiones al servidor.
	 
  2. Modifica la aplicación para gestionar esos errores e informar a
     la usuaria.

     Actualiza el diseño de la interfaz y el diseño sw según sea
     necesario, e implementa los cambios.

  3. Identifica las operaciones de E/S que pueden bloquear la
     interface.
	 
	 > **TIP:** Siguen siendo las peticiones al servidor.
	 
  4. Modifica la aplicación para que ejecute concurrentemente las
     operaciones bloqueantes.

     Actualiza el diseño de la interfaz y el diseño sw según sea
     necesario, e implementa los cambios.


### :books: Objetivos de aprendizaje:

  - Naturaleza concurrente de las interfaces.
  
  - Uso de la concurrencia.
  
  - Gestión de errores en la E/S.
  
</details>



<details id=3>
<summary><h2>Tarea 3: Internacionalización</h2></summary>

### :wrench: Esta tarea tiene las siguientes partes:

  1. Internacionaliza la interface de usuaria para que se adapte a la
     configuración del _locale_ de la usuaria.
	 
  2. Localiza la interface a un idioma distinto del original.
  
     Este paso sirve para validar el paso anterior. La calidad de la
     traducción no un objetivo de la práctica.
	 
  3. Internacionaliza la aplicación para mostrar las cantidades
     monetarias según la configuración de la usuaria.

     Si la aplicación muestra fechas, haz lo propio con las fechas.


### :books: Objetivos de aprendizaje:

  - Internacionalización de IGUs.

</details>


<details id=X>
<summary><h2>Finish</h2></summary>

_Congratulations friend, you've completed this assignment!_

Antes de dar por finalizada una tarea o la propia práctica, clona el
repositorio de Github y comprueba que:

  - Contiene todos los documentos solicitados y el código completo de
    la aplicación.
  
  - La aplicación funciona correctamente.

</details>

