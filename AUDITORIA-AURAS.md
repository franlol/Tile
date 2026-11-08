# Auditoría de indicadores y combate

Fecha: 8 de noviembre de 2026. Cliente observado: WoW Forever 1.60.1, build 70862.

## Conclusión

El cliente ha registrado denegaciones de acceso en las tres rutas de lectura
que utiliza el addon: por índices, listas completas e IDs de instancia. Un
`pcall` impide que el error interrumpa el addon, pero no obtiene las auras ni
convierte una consulta denegada en una consulta válida.

La adaptación nativa cubre algunos indicadores, no todo el addon. Las vistas
de prueba usan auras ficticias y no demuestran que una configuración funcione
con auras restringidas en combate.

## Cobertura actual

| Indicador/configuración | Ruta | Comportamiento y límites |
| --- | --- | --- |
| Disipable, borde o tinte, sin resaltados ni umbrales | Nativa | Misma ruta en combate y fuera; filtra por lo que puedes disipar o por tipos de cualquier clase. |
| Debuffs genéricos, sin lista negra, umbrales ni resaltados, con barrido de reloj o sin barrido | Nativa | Iconos, tamaño, dirección, separación, borde por tipo, cargas y tiempo. El juego decide el orden. |
| Exclusión de debuffs mostrados por otros indicadores | Sin adaptar en la lista nativa | No se puede recuperar del contenedor la identidad de las auras para mantener la tabla `claimed`. Se informa en las opciones. |
| Tooltip de los iconos nativos y textos con color de clase | Sin adaptar | El tooltip propio del addon no recibe datos secretos del contenedor. El color de clase no se actualiza en esos textos. |
| Debuffs con lista negra, resaltados, avisos o barridos alternativos activos | Lectura directa | La configuración vuelve a depender de las consultas que el cliente puede denegar. Ahora se explica al seleccionar el indicador. |
| HoTs y escudos como auras | Lectura directa | La selección por hechizos y estilos todavía no se ha trasladado a contenedores nativos. |
| Defensivos como auras | Lectura directa | Mismo límite que HoTs. |
| Debuff de banda | Lectura directa | Depende de IDs y prioridades. No se debe sustituir por «cualquier debuff» como si fuese equivalente. |
| Auras personalizadas: icono, varios iconos, cuadrado, barra, texto, borde o tinte | Lectura directa, salvo los casos nativos anteriores | El aspecto visual no determina si se pueden leer los datos. |
| Modo «Le falta» | Lectura directa | Solo puede demostrar ausencia con una consulta completa y datos identificables. Ante lectura fallida, parcial o truncada se oculta el aviso. |
| Barras de cantidad absorbida y curación entrante | Datos de unidad | No dependen de enumerar auras. No equivale a identificar el hechizo de un escudo. |
| Bebiendo/comiendo u otros con «solo fuera de combate» | Fuera de combate por configuración | Su ausencia en combate es intencionada. Las restricciones también pueden existir dentro de una instancia, fuera de combate. |

El tipo de debuff (por ejemplo, Poison) no identifica el hechizo. La API nativa
admite seleccionar tipos y dibujar auras sin entregarnos sus datos. Su código
restringe la selección por ID de auras perjudiciales sobre unidades amistosas,
salvo hechizos expresamente no secretos. En cambio, permite selección por ID
de beneficios sobre el jugador y miembros del grupo. Esto hace viable una
adaptación futura de HoTs/defensivos, pero no valida automáticamente prioridades,
rangos, estilos por hechizo ni el modo «Le falta».

Fuentes contrastadas:

- [Filtros y restricciones de identidad de Blizzard](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua).
- [Elementos que puede dibujar un botón nativo](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua).

El repositorio upstream ayuda a interpretar el diseño de la API, pero no es una
prueba de que cada detalle coincida con el build 70862. Esa parte requiere una
prueba en este cliente.

## Fallos corregidos en esta revisión

1. La caché de auras distingue una consulta válida vacía de una lectura fallida,
   parcial o truncada. «Le falta» deja de inferir ausencia cuando no puede saberlo.
2. Al retirar o reutilizar un widget se oculta su contenedor nativo y se desconecta
   de la unidad. La limpieza también se aplica a una construcción parcial fallida.
3. Los callbacks nativos reciben una copia de la configuración aplicada. Un frame
   que Blizzard cree más tarde no toma accidentalmente opciones todavía pendientes
   de aplicar durante el combate.
4. La evaluación de compatibilidad es común a construcción, opciones y auditoría.
   Un resaltado o umbral que no está implementado no se ignora para aparentar
   compatibilidad nativa. El motivo para usar la lectura directa queda visible.
5. Se conservan los ajustes interiores de posición de los textos de cargas y tiempo
   de la lista nativa y se pasa una tabla de opciones al registro del temporizador.
6. Se comprueba si el nombre de aura es secreto antes de manipularlo; el texto
   «lanzador» evita usar unidades de origen secretas. La predicción de curación no
   evalúa como condición un máximo de vida que pueda ser secreto.

Los cambios anteriores de la sesión ya habían separado el tinte y su intensidad
del color que actualiza Blizzard, igualado los recursos del degradado y el icono
de tipo entre vista previa y dibujo nativo, y adaptado la lista genérica de debuffs.

## Diagnóstico

- `/mf auditoria`: imprime la evaluación del perfil activo y guarda en
  `MendFramesDB.indicatorAudit` todos los perfiles y la ruta real de los widgets
  visibles, incluidos errores de creación. `/reload` escribe esos datos al archivo.
- `/mf disipar`: inspección breve de los contenedores propios de Disipable y Debuffs.
- Las opciones de cada indicador explican su ruta y sus límites. Un fallo de creación
  nativa se registra por widget; no debe confundirse una capacidad prevista con una
  creación realmente lograda.

## Verificación realizada y pendiente

`node tests/run-aura-audit.cjs` analiza como Lua 5.1 todos los archivos Lua del TOC
y ejecuta pruebas de comportamiento en un cliente simulado. Las dependencias de
prueba tienen versión y SHA-256 fijados y se guardan en el directorio temporal.
Los archivos de prueba no se cargan dentro de WoW.

Se comprueban selección por tipo sin capacidad de disipación, recursos visuales
compartidos, intensidad, lista nativa, transiciones de combate, retirada de widgets,
configuración diferida, clasificación de opciones incompatibles, API no disponible,
lecturas fallidas/parciales/truncadas, ausencia real y errores de construcción.

Las pruebas no reproducen la seguridad de WoW, las imágenes finales, los eventos
reales ni los datos del servidor. HoTs, defensivos y debuffs de banda continúan
pendientes de adaptación; no están declarados como resueltos.

Para una prueba manual gradual:

1. Recargar y comprobar un veneno en la misma unidad durante y después del combate.
2. Comprobar por separado Disipable y la lista Debuffs: icono, borde, tamaño, dirección,
   separación, degradado, intensidad, cargas y tiempo.
3. Cambiar posición/color fuera de combate, retirar un indicador y cambiar de perfil;
   verificar que no quedan dibujos anteriores activos.
4. Configurar un beneficio conocido en «Le falta», entrar en combate y comprobar que
   una consulta denegada no genera una falsa alarma de ausencia.
5. Ejecutar `/mf auditoria` para revisar el estado de las otras categorías antes de
   migrarlas una a una. No confundir un marco de prueba con un marco real.

## Siguiente trabajo delimitado

### Consistencia de la vista previa (revisión posterior)

La muestra del jugador utiliza ahora su clase real, en lugar de combinar su
nombre con la clase ficticia WARRIOR. El color del marco, sus textos y los
textos de tiempo/cargas de los indicadores usan el mismo resolvedor. Cada fila
simulada transmite su propia clase a los iconos múltiples y al modo «Le falta»;
las mascotas conservan el color que usa su marco. Los modos blanco y personalizado
conservan su semántica y su opacidad. Un token de clase oculto se descarta sin
recuperarlo accidentalmente mediante una expresión `and/or`.

La muestra de tipos de debuff elige uno de los tipos habilitados. Ya no oculta un
indicador configurado solo para venenos por intentar simular siempre magia.
Se añadieron 16 comprobaciones de consistencia de color que ejecutan los módulos
reales de medios, marcos e indicadores dentro del cliente simulado.

Esta corrección de la vista previa no elimina la limitación de color de clase en
los textos del contenedor nativo de Debuffs, indicada en la tabla de cobertura.

### Adaptaciones pendientes

Primero adaptar HoTs/defensivos de beneficios presentes con una selección nativa
por ID que respete su configuración. Después abordar otros aspectos de dibujo.
Las prioridades de debuffs de banda, listas negras y exclusiones requieren una
decisión específica compatible con las restricciones del cliente; no se resolverán
leyendo datos prohibidos ni ocultando la pérdida de esas funciones.
