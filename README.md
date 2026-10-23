# HOLA GENTZANE

Animacion ASCII estilo hacker para el `cmd` de Windows.

Doble clic en **`HOLA_GENTZANE.bat`** (Windows 10/11).

1. Secuencia de "hackeo" con lluvia de codigo estilo Matrix.
2. Canasta en 3D sobre un suelo en perspectiva: el balon (una esfera 3D que gira) bota, se calcula la trayectoria, encesta con camara lenta y sale disparado hacia la pantalla.
3. **HOLA GENTZANE** en letras ASCII con sombra 3D, colores neon animados, fuegos artificiales de caracteres y un balon botando encima de las letras.

4. Boton 3D **COMENZAR LA VALIDACIÓN**: al pulsar ENTER se hunde y aparece una ventana de aviso ("Se buena porfa :)") con cuenta atras de 5 segundos. Al llegar a 0 se abre la carpeta de Google Drive (en Chrome si esta instalado; si no, en el navegador por defecto).

Cualquier tecla salta la intro, ENTER pulsa el boton y ESC sale.

---

# F1 GRAND PRIX

Juego de carreras de Formula 1 para el `cmd` de Windows. Doble clic en **`F1_GRAND_PRIX.bat`** (Windows 10/11).

- Carretera pseudo-3D (estilo arcade clasico) pintada con medios bloques de color: curvas, subidas, bajadas, pianos rojos y blancos, grava y niebla en el horizonte.
- Atardecer con sol, nubes, montanas, ciudad con ventanas encendidas y arboles con efecto parallax.
- Tribunas con publico animado, vallas publicitarias, muros de neumaticos y portico de salida con semaforo.
- Pones tu nombre y hay **multijugador en red local**: quien abra el .bat en la misma red aparece en la sala online y correis juntos en tiempo real (puerto UDP 47777). Si el Firewall no deja ver a los demas y no eres administrador: en la sala cada uno ve su **codigo** (su IP); tus amigos pulsan **U** y lo escriben, y la conexion directa funciona sin permisos.
- Hasta 8 coches: los huecos los rellenan pilotos con IA (adelantan, frenan en las curvas y esquivan), salida con las 5 luces rojas de F1, 3 vueltas.
- Torre de tiempos, luces de cambio, telemetria (velocidad, marcha, acelerador, freno, ERS), minimapa, vuelta rapida y clasificacion final con banderas a cuadros y fuegos artificiales.
- Efectos: chispas, humo de neumaticos, tierra al salirte, temblor de camara, lineas de velocidad y turbo ERS.

**Controles:** flechas arriba/abajo para acelerar y frenar, izquierda/derecha para girar, ESPACIO para el turbo ERS, P para pausar y ESC para salir.

---

# BASKET 1 VS 1

Juego de baloncesto arcade 1 contra 1 para el `cmd` de Windows. Doble clic en **`BASKET_1VS1.bat`** (Windows 10/11).

- Pista completa en vista lateral con parque brillante (reflejos), lineas de la cancha, publico animado que salta con las canastas, flashes, focos, pancartas, valla LED y marcador gigante.
- Fisica real del balon: rebota en el aro, el tablero y el suelo; la red lo frena y ondea.
- Tiro en suspension con barra de precision (suelta ESPACIO en la zona verde), triples, mates cerca del aro, tapones, robos, quiebros que pueden tirar al rival, turbo con resistencia y modo "en llamas" tras 3 canastas seguidas.
- Reloj de partido (1, 2 o 3 minutos), reloj de posesion de 14 s, muerte subita si hay empate, 3 niveles de dificultad y estadisticas al final.

**Controles:** flechas izquierda/derecha para moverte, arriba para saltar, ESPACIO para tirar/machacar o taponar, abajo para quiebro (con balon) o robo (en defensa), SHIFT para turbo, P pausa y ESC salir.

---

# CAMARA ASCII

Convierte la webcam en un dibujo ASCII en tiempo real dentro del `cmd`. Doble clic en **`CAMARA_ASCII.bat`** (Windows 10/11). Usa Media Foundation, lo mismo que la app Camara de Windows: no hay que instalar nada.

- 7 modos: ASCII detallado, ASCII en color, boceto a lapiz, Matrix, alta definicion (medios bloques a todo color), braille (en Windows Terminal) y neon (bordes).
- Cada caracter se elige por **forma** (cada celda se divide en 2x4 zonas y se busca el caracter que mejor encaja), con niveles automaticos, enfoque y suavizado para que no parpadee.
- En la consola clasica reduce la letra y agranda la ventana para tener muchas mas celdas; `+`/`-` cambian el nivel de detalle.

**Teclas:** flechas izquierda/derecha (o 1-7) cambian de modo, arriba/abajo el contraste, RePag/AvPag el brillo, M espejo, V voltear, F foto congelada, S guardar el dibujo como .txt en el escritorio, K cambiar de camara, ESC salir.

Si sale un aviso de privacidad: Configuracion > Privacidad > Camara > "Permitir que las aplicaciones de escritorio accedan a la camara".

## OFICINA_3D.bat

Un personaje sentado en su oficina, en 3D renderizado dentro de la consola (sombras del sol por la ventana, flexo, brillo del monitor...). Hay mesa, ordenador, teclado, raton, taza, folios, impresora, papelera, planta, estanteria, reloj, cuadro y mas. Todo tiene colisiones y fisicas. Se controla con **tus manos y la webcam**:

- Deteccion basada en las tecnicas clasicas de OpenCV: histograma de color de tu piel frente al del fondo (back projection), deteccion de movimiento por diferencia de fotogramas y seguimiento de cada mano con mean-shift/CamShift. Los dedos se cuentan con circulos alrededor de la palma.
- Calibracion: al empezar, deja la camara sin manos y pulsa ESPACIO; despues pon las manos abiertas en el recuadro y pulsa ESPACIO.
- Mueves la mano: se mueve la del personaje. Acercarla a la camara = mas lejos en la mesa. Inclinar la cabeza = el personaje se inclina.
- Puno = coger, abrir la mano = soltar o lanzar (segun la velocidad). Un dedo = pulsar botones y teclear.
- Enciende el ordenador con el boton de la torre, escribe en NOTAS, coge el raton para mover el cursor (dejarlo quieto encima de un boton = clic), dibuja en PAINT, IMPRIMIR saca un folio por la impresora, el interruptor del flexo, arruga folios (mantenlos cogidos 1 s) y tiralos a la papelera...

**Teclas:** T cambia entre camara y teclado (mano izq. A D W S Q E, Z puno, X dedo; mano der. J L I K U O, M puno, N dedo; flechas = inclinarse), C recalibrar, G invertir izquierda/derecha (si los brazos van al reves), TAB ver la camara, F1-F4 vistas, R recoger los objetos, H ayuda, +/- detalle, ESC salir.
