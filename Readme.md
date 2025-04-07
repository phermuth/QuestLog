# QuestLog - Bitácora de Misiones para WoW 1.12

-Phermuth
QuestLog es un addon para World of Warcraft versión 1.12 (vanilla) que te permite mantener un registro detallado de todas las misiones que aceptas, completadas o abandonadas, junto con las coordenadas donde las aceptaste y entregaste.

## Características

- Registro automático de todas las misiones aceptadas
- Registro automático de coordenadas al aceptar y entregar misiones
- Diferenciación por colores entre misiones completadas y pendientes
- Opción para añadir coordenadas manualmente a cualquier misión
- Opción para eliminar coordenadas
- Exportación de datos para respaldo
- Botón en el minimapa para acceso rápido

## Instalación

1. Descarga los archivos del addon
2. Extrae la carpeta "QuestLog" en la carpeta "Interface/AddOns" de tu directorio de World of Warcraft
3. Asegúrate de que la estructura de carpetas sea:
   - `World of Warcraft/Interface/AddOns/QuestLog/QuestLog.toc`
   - `World of Warcraft/Interface/AddOns/QuestLog/QuestLog.lua`
   - Junto con todas las carpetas de librerías en `/libs`
4. Inicia o reinicia el juego

## Dependencias

El addon utiliza las siguientes librerías Ace2:
- AceLibrary
- AceOO-2.0
- AceConsole-2.0
- AceEvent-2.0
- AceDB-2.0
- AceAddon-2.0
- AceHook-2.1

Si ya tienes otros addons que usan Ace2, puedes compartir estas librerías.

## Uso

### Comandos de Chat

- `/qlog` o `/questlog` - Abre la ventana principal de QuestLog
- `/qlog add` - Añade una coordenada manual a la misión seleccionada
- `/qlog delete` - Elimina una coordenada de la misión seleccionada
- `/qlog export` - Exporta los datos de todas las misiones registradas

### Interfaz de Usuario

1. **Vista Principal**: Muestra una lista de todas las misiones registradas.
   - Las misiones completadas aparecen en verde
   - Las misiones en curso aparecen en blanco
   - Las misiones abandonadas aparecen en rojo

2. **Panel de Detalles**: Al hacer clic en una misión, se muestra:
   - Nivel de la misión
   - Estado actual
   - Coordenadas donde la aceptaste
   - Coordenadas donde la entregaste (si está completada)
   - Coordenadas adicionales añadidas manualmente

3. **Botones de Acción**:
   - "Añadir Coordenada": Añade tu posición actual como coordenada a la misión seleccionada
   - "Eliminar Coordenada": Te permite eliminar una coordenada de la lista

### Dónde se Guardan los Datos

Todos los datos de QuestLog se guardan en:
`World of Warcraft/WTF/Account/[TU_CUENTA]/SavedVariables/QuestLogDB.lua`

Este archivo se actualiza cuando cierras el juego correctamente.

## Resolución de Problemas

- Si el addon no aparece, comprueba que la estructura de carpetas sea correcta
- Si los datos no se guardan, asegúrate de cerrar el juego correctamente con /exit o el botón de Salir
- Si el botón del minimapa no aparece, prueba a recargar la interfaz con /reload

## Créditos

Este addon fue creado basándose en la estructura de GuiaPhermuth de Phermuth. Adaptado para funcionar como una bitácora de misiones independiente.

## Licencia

Libre para uso personal y modificación.















# Características Avanzadas de QuestLog

## Sistema de Coordenadas

El addon QuestLog registra las coordenadas de cada misión de forma automática en dos momentos:

1. **Coordenadas de Aceptación**: Se registran automáticamente cuando aceptas una misión.
2. **Coordenadas de Entrega**: Se registran cuando entregas una misión completada.

Además, puedes añadir coordenadas manualmente para marcar:
- Ubicaciones de objetivos de misión
- Puntos de interés relacionados con la misión
- Ubicaciones de NPCs importantes
- Cualquier lugar que quieras recordar

### Formato de Coordenadas

Las coordenadas se guardan en formato `(X, Y)` donde:
- X es la posición horizontal en el mapa (0-100)
- Y es la posición vertical en el mapa (0-100)
- También se guarda el nombre de la zona

## Exportación de Datos

La función de exportación crea un archivo de texto con todas tus misiones y sus coordenadas. Esto es útil para:

- Crear guías personalizadas
- Compartir rutas con otros jugadores
- Hacer respaldos de tus datos
- Analizar tus recorridos de leveo

El archivo de exportación se guarda en el directorio:
`World of Warcraft/WTF/Account/[TU_CUENTA]/SavedVariables/`

## Integración con Otros Addons

QuestLog puede complementarse perfectamente con otros addons populares de Vanilla:

- **TomTom/Cartographer**: Para visualizar tus coordenadas guardadas en el mapa
- **pfQuest/QuestHelper**: Para obtener información adicional sobre las misiones
- **AtlasLoot**: Para ver recompensas de misiones de mazmorras

## Personalización del Addon

Si tienes conocimientos de Lua, puedes personalizar el addon editando el archivo QuestLog.lua:

- Cambiar los colores de los diferentes estados de misiones
- Añadir más categorías o filtros
- Modificar el tamaño y posición de las ventanas
- Añadir compatibilidad con otros addons

## Consejos de Uso

- **Coordenadas manuales**: Añade coordenadas manuales para marcar puntos importantes que debes recordar en el futuro.
- **Exportación periódica**: Haz exportaciones periódicas para no perder datos en caso de corrupción de archivos.
- **Misiones abandonadas**: Las misiones abandonadas también se registran, lo que te permite ver tu historial completo.
- **Orden por fecha**: Las misiones se muestran ordenadas por fecha, con las más recientes al principio.

## Próximas Características Planeadas

Estas son algunas características que se podrían implementar en versiones futuras:

1. Filtrado de misiones por zona, nivel o estado
2. Agrupación de misiones por cadenas relacionadas
3. Notas personalizadas para cada misión
4. Cronómetro para medir el tiempo que tardas en completar misiones
5. Estadísticas de misiones (misiones completadas por zona, por nivel, etc.)
6. Integración mejorada con TomTom para mostrar las coordenadas directamente en el mapa