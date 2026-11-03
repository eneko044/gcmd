# Resultados del experimento RULETA LAB

Ruleta europea ficticia con las mismas probabilidades y pagos que una real
(37 casillas, un solo cero, pleno 35:1 ... suertes sencillas 1:1) y limites
de mesa tipicos de un casino espanol (minimo 1 EUR por pleno, 5 EUR en
apuestas exteriores, maximo 100 EUR por pleno). Todo se reproduce con
`python ruleta.py todo` (semilla 2026); los datos completos estan en
`salida/informe_para_claude.json`.

## 1. Las reglas del juego (exactas, no simuladas)

| Apuesta | Paga | Probabilidad | Ventaja de la casa |
|---|---|---|---|
| Pleno (1 numero) | 35:1 | 2,70 % | **2,70 %** |
| Caballo, transversal, cuadro, seisena | 17:1 ... 5:1 | 5,4 % ... 16,2 % | **2,70 %** |
| Docena / columna | 2:1 | 32,4 % | **2,70 %** |
| Rojo/negro, par/impar, falta/pasa | 1:1 | 48,6 % | **2,70 %** |
| Sencilla con regla *La Partage* (ruleta francesa) | 1:1 | 48,6 % | **1,35 %** |

Todas las apuestas pierden lo mismo por euro apostado. La unica excepcion
son las suertes sencillas en mesas con La Partage o En Prison, donde si sale
el 0 solo pierdes la mitad.

## 2. ¿Puede un modelo aprender a predecir el numero?

Siete modelos apostaron a pleno durante 100.000 rondas, aprendiendo ronda a
ronda: azar, numero caliente, numero frio, repetir el ultimo, cadena de
Markov, sector del cilindro y una red neuronal (softmax online). Otros tres
modelos apostaron a color (seguir la racha, ir contra la racha y color
caliente).

| Modelo | Rueda justa: acierto | Rueda trucada (control): acierto |
|---|---|---|
| Esperado por azar | 2,70 % | 2,70 % |
| Caliente | 2,82 % (p=0,02, ver nota) | **3,93 %** (z=23,9) |
| Markov | 2,64 % | **3,92 %** |
| Sector | 2,65 % | **3,95 %** |
| Red neuronal | 2,69 % | **3,95 %** |
| Frio ("le toca") | 2,77 % | 2,52 % (peor que el azar) |
| Colores (los 3) | 48,4–48,8 % (azar: 48,65 %) | igual que el azar |

* **Grupo de control**: en la rueda trucada (5 casillas vecinas salen un 60 %
  mas) cuatro modelos detectan el sesgo y ganan dinero (ROI +41 %). Esto
  demuestra que los modelos funcionan: si hubiera un patron, lo encontrarian.
* **Rueda justa**: ningun modelo supera al azar. El 2,82 % del modelo
  caliente es suerte. Repetido con 40 semillas nuevas da z combinado = 0,27
  (18 de 40 por encima del azar). Con la semilla 1, hasta el modelo que
  elige al azar sale "significativo" (p=0,03). Al hacer muchos tests, algun
  falso positivo es inevitable.
* La "falacia del jugador" (apostar al numero frio o ir contra la racha) no
  funciona: cada tirada es independiente.

## 3. Estrategias de apuesta: 10.000 sesiones cada una

Banca 100 EUR, objetivo 150 EUR (te retiras al llegar), maximo 200 rondas.

**Mesa europea normal (ventaja 2,70 %)**

| Estrategia | Llega al objetivo | Se arruina | Perdida esperada por sesion | Apostado por sesion | Va ganando tras 100 sesiones | Tras 1.000 |
|---|---|---|---|---|---|---|
| **Apuesta audaz** | **64,7 %** | 35,3 % | **-2,74 EUR** | 101 EUR | **35 %** | 11 % |
| Labouchere | 63,6 % | 36,4 % | -4,23 | 156 | 28 % | 3 % |
| Martingala | 62,6 % | 37,4 % | -6,30 | 233 | 19 % | 0,3 % |
| D'Alembert | 60,7 % | 39,3 % | -7,63 | 283 | 15 % | 0,1 % |
| Fibonacci | 60,1 % | 39,8 % | -9,87 | 365 | 9 % | 0 % |
| Paroli | 55,8 % | 42,2 % | -12,89 | 477 | 4,5 % | 0 % |
| James Bond | 53,4 % | 46,5 % | -16,39 | 606 | 1,5 % | 0 % |
| Plana a pleno / numero caliente | 46–47 % | 18,5 % | -3,5 | 130 | 30 % | 5 % |
| Plana a rojo | 35,3 % | 25,1 % | -18,89 | 699 | 0,1 % | 0 % |
| Dos docenas | 44,2 % | 45,2 % | -24,34 | 900 | 0 % | 0 % |

**Mesa francesa con La Partage (ventaja 1,35 % en sencillas)**: la apuesta
audaz llega al objetivo el **66,3 %** de las veces y pierde de media
**-1,37 EUR por sesion**. Despues de 100 sesiones vas ganando el 42 % de las
veces; despues de 1.000 sesiones, el 27 %.

La ventaja efectiva medida es exactamente 2,70 % (o 1,35 %) en **todas** las
estrategias. Ninguna progresion cambia la ventaja de la casa. Lo unico que
cambia es **cuanto dinero mueves**, y la perdida esperada es siempre
`ventaja × total apostado`.

## 4. La estrategia optima, calculada (no adivinada)

El modo `optimo` resuelve el problema por programacion dinamica. Para cada
banca posible prueba todas las apuestas permitidas (sencilla, docena o pleno,
con cualquier importe dentro de los limites) y elige la que maximiza la
probabilidad de llegar al objetivo:

| Mesa, de 100 a 150 EUR | Optima exacta | Apuesta audaz a rojo | Plana minima a rojo | Sin ventaja de la casa |
|---|---|---|---|---|
| Europea | 65,38 % | 64,85 % | 47,96 % | 66,67 % |
| Francesa (La Partage) | 65,79 % | 65,75 % | 55,91 % | 66,67 % |

Coincide con el teorema de Dubins y Savage: en un juego desfavorable, la
forma de maximizar la probabilidad de alcanzar una meta es la **apuesta
audaz**, apostar lo minimo necesario para llegar de un solo golpe. Cuantas
menos tiradas, menos veces cobra la casa su 2,7 %.

## 5. Buscar "dibujos" que salgan mas

Pregunta: si en las tiradas se ve que ciertos numeros o formas salen mas, ¿se
puede montar una estrategia que gane menos pero de forma mas segura con un
dibujo concreto (parejas, trios, cuadros, cada X numeros, escaleras de 2, 3
y 4 numeros...)?

El modo `patrones` lo prueba con **1.808 dibujos distintos**: los 37 plenos,
todos los caballos, transversales, cuadros y seisenas, diagonales, cruces,
docenas, columnas, "cada 2, 3... 9 numeros", "terminados en X", sectores del
cilindro de 3 a 17 casillas, vecinos del cero, tercio, huerfanos y 1.360
combinaciones de 2 a 18 numeros. Se apuesta 1 EUR a cada numero del dibujo.
El metodo es el de cualquier modelo serio: **buscar el dibujo en unas
tiradas y comprobarlo en tiradas nuevas que no ha visto**.

**A) Pocas tiradas (lo que apuntaria una persona en el casino)**: busco en
500 tiradas y compruebo en 100.000 nuevas.

| Dibujo encontrado | Beneficio en las 500 tiradas | En 100.000 tiradas nuevas |
|---|---|---|
| Combinacion de 5 numeros (el mejor) | **+41,1 %** | **-2,54 %** |
| Caballo 19-22 | +54,8 % | -4,10 % |
| Transversal 19-21 | +41,6 % | -1,88 % |
| Seisena 19-24 | +27,2 % | -2,54 % |
| Media de los 10 mejores | +34,8 % | **-2,46 %** |
| Media de los 200 mejores | +16,0 % | **-2,65 %** |

Con 500 tiradas, 83 dibujos parecen "estadisticamente significativos" y
algunos dan mas de un +40 %. Pero es casualidad: en tiradas nuevas **todos**
caen a la ventaja de la casa (-2,7 %). Al probar 1.800 dibujos siempre habra
alguno que haya salido mucho; eso no predice nada.

**B) Muchas tiradas (100.000 + 100.000)**: el mejor dibujo en entrenamiento
ni siquiera es positivo (-1,9 %) y en prueba queda en -2,85 %.

**C) Aprendizaje continuo**: cada 1.000 tiradas el modelo juega el dibujo
que mejor va hasta ese momento. Resultado real: **-2,45 %**. Si en vez de
elegir por fiabilidad (z) elige por beneficio, va a por los plenos con mas
suerte y pierde el -7,4 %.

**D) Dibujos dinamicos** que cambian en cada tirada segun lo que sale
(ultimos numeros, vecinos del ultimo, lado opuesto del cilindro, calientes,
frios, docena del ultimo y **escaleras 2-3-4** y 1-2-3-4-6-8, que suben un
escalon al fallar y vuelven al primero al acertar). En 100.000 tiradas
nuevas, los 19 dan entre -1,3 % y -5,0 %, todos compatibles con -2,7 %.

**E) Grupo de control (rueda trucada)**: el mismo buscador encuentra el
sector defectuoso ("sector de 5 centrado en 17": +42,6 % en entrenamiento y
**+43,8 % en tiradas nuevas**). El aprendizaje continuo gana un +43 % y los
dibujos "calientes" y la escalera 2-3-4 de calientes ganan entre un +6 % y un +27 %. El
metodo funciona: si existiera un dibujo real, lo encontraria. En la rueda
justa no lo encuentra porque no existe.

**F) Ganar poco pero a menudo**: cubrir mas numeros solo cambia la forma de
perder, no cuanto pierdes por euro.

| Numeros cubiertos | Aciertas | Ganas si acierta | Pierdes si falla | Vas ganando tras 1.000 tiradas |
|---|---|---|---|---|
| 1 | 2,7 % | 35 EUR | 1 EUR | 45 % |
| 4 | 10,8 % | 32 | 4 | 36 % |
| 12 | 32,4 % | 24 | 12 | 27 % |
| 18 | 48,6 % | 18 | 18 | 19 % |
| 30 | 81,1 % | 6 | 30 | 3 % |
| 32 | 86,5 % | 4 | 32 | 1 % |
| 35 | 94,6 % | 1 | 35 | 0 % |

Cubrir 32 numeros "gana" el 86 % de las tiradas, pero cada fallo se lleva 8
aciertos y a las 1.000 tiradas solo va por delante el 1 %. Paradojicamente,
cuantos **menos** numeros cubres, mas probable es ir ganando tras muchas
tiradas: apuestas menos dinero por tirada y un solo acierto de 35:1 compensa
muchos fallos.

## 6. La estrategia "perfecta" (lo mejor que permiten las matematicas)

No existe ninguna estrategia que gane a la larga. Las cuatro pruebas (modelos,
estrategias, programacion dinamica y busqueda de dibujos) lo confirman: la esperanza es negativa con cualquier combinacion de apuestas, y
cuantas mas sesiones repites, mas cerca del 100 % esta la probabilidad de ir
perdiendo. Lo mas que se puede hacer es perder lo menos posible:

1. **Mesa**: ruleta francesa con *La Partage* o *En Prison*, apostando solo
   a suertes sencillas (rojo/negro, par/impar, falta/pasa). Asi la ventaja
   de la casa baja a la mitad (1,35 %). Nunca ruleta americana (doble cero,
   5,26 %).
2. **Fija la meta antes de sentarte**, por ejemplo +50 % de la banca, y lleva
   solo el dinero que aceptas perder entero.
3. **Apuesta audaz**: apuesta a rojo exactamente lo que te falta para la meta
   (`min(banca, meta - banca)`). Con 100 EUR y meta 150: 50 EUR a rojo; si
   pierdes, 50 a rojo; si vuelves a 100, otra vez 50. Lo normal es que se
   acabe en 2–4 tiradas.
4. **Al llegar a la meta o a 0, te levantas.** Sin excepciones.

Con esto, cada sesion es un 66 % de ganar +50 EUR contra un 34 % de perder
los 100. La perdida media es de ~1,4 EUR por sesion, frente a 6–25 EUR con
martingala, Fibonacci, James Bond, etc. Aun asi la media es negativa, asi
que repetirlo muchas veces garantiza perder: tras 1.000 sesiones solo un 27 %
va por delante, y ese porcentaje sigue bajando hacia 0.

Si quieres jugar con un dibujo que te guste (por ejemplo, una escalera de 2-3-4
numeros), la forma menos mala es cubrir **pocos numeros** con apuestas pequenas
y con una meta fija. Asi pierdes el mismo 2,7 % por euro, pero apuestas menos
por tirada y un acierto de 35:1 te deja por delante durante mas tiempo.

Lo unico que ha batido de verdad a la ruleta son defectos fisicos de la
rueda (como el grupo de control de este experimento) o medir la bola en
vuelo. Los casinos actuales revisan y rotan las ruedas, y la ruleta online
usa un generador aleatorio sin defectos fisicos que explotar.

## 7. Escalada: empezar con 5 EUR y ver hasta donde se llega

`python ruleta.py escalada --banca 5 --mesa francesa --max-rondas 100000`

Estrategia: apuesta audaz sin techo, es decir, todo el saldo a rojo en cada
tirada (desde 5.120 EUR el maximo de la mesa limita la apuesta a 3.000 EUR).
Se repite 1.000.000 de veces y se apunta el maximo que alcanza cada partida.

* **Partida en directo**: 5 -> 10 (rojo) -> 0 (negro). Maximo: 10 EUR.
* **Record de 1.000.000 de partidas**: 10 rojos seguidos (5 -> 5.120 EUR),
  despues 10.000 tiradas de 3.000 EUR con un pico de **415.240 EUR**...
  y como no se retiro, acabo en 0 EUR.

| Llegar a | Probabilidad | 1 de cada |
|---|---|---|
| 10 EUR | 48,6 % | 2 |
| 40 EUR | 11,8 % | 8 |
| 100 EUR | 2,9 % | 35 |
| 1.000 EUR | 0,35 % | 287 |
| 10.000 EUR | 0,04 % | 2.667 |
| 100.000 EUR | 0,002 % | 47.619 |

La mitad de las partidas no pasa nunca de los 5 EUR iniciales. Entre el
millon de jugadores se pusieron 5.000.000 EUR y se recuperaron 68.395 EUR: la
casa se queda el 98,6 %. El maximo solo es dinero real si **te retiras al
llegar a una meta fija**, y la probabilidad de llegar a una meta X empezando
con 5 EUR es como mucho 5/X (el valor de un juego justo), un poco menos por
la ventaja de la casa.

## 8. El "dibujo" en el tapete con mas probabilidad de salir

`python ruleta.py dibujo --rondas 1000000 --fichas 5 --zona 19-30`
(imagen: `salida/dibujos_justa.png`)

Se observan 1.000.000 de tiradas para ver donde cae la bola. Con eso se
busca el mejor dibujo de cada tipo con 5 fichas de 1 EUR (sin que las fichas
se pisen) y se comprueba en otro 1.000.000 de tiradas nuevas.

Donde cae la bola: todos los numeros salen entre el 2,66 % y el 2,74 %
(esperado: 2,70 %). El test de uniformidad da p = 0,24, asi que son
diferencias de puro azar.

| Dibujo (5 fichas) | Numeros | Acierta (tiradas nuevas) | Teorico | Si acierta | Resultado |
|---|---|---|---|---|---|
| De 2 en 2 (caballos) | 10 | 26,99 % | 27,03 % | +13 EUR | -2,83 % |
| Mezcla de 4 en 4 y de 2 en 2 | 16 | 43,18 % | 43,24 % | +4 o +13 EUR | -2,92 % |
| De 4 en 4 (cuadros) | 20 | 54,08 % | 54,05 % | +4 EUR | -2,66 % |
| Zona 19-30 (2 cuadros + 2 caballos, 4 fichas) | 12 | 32,42 % | 32,43 % | +5 o +14 EUR | -2,73 % |
| **De 6 en 6 (seisenas)** | **30** | **81,08 %** | 81,08 % | +1 EUR | -2,71 % |

* **El dibujo que mas sale en cada tirada son las seisenas** (de 6 en 6):
  con 5 fichas cubres 30 numeros y aciertas el 81 % de las tiradas. Pero
  cuando aciertas ganas solo +1 EUR, y cuando fallas pierdes 5.
* La probabilidad de acertar depende **solo de cuantos numeros cubres**
  (numeros / 37), no de la forma del dibujo ni de la zona. Los dibujos
  elegidos con los numeros "mas salidos" aciertan en tiradas nuevas lo mismo
  que dice la teoria.
* Todos pierden lo mismo por euro: alrededor del -2,7 %.
* Grupo de control (`--sesgo`): en la rueda trucada el buscador encuentra los
  numeros defectuosos (2, 6, 17, 25, 34) y el dibujo de 2 en 2 gana un
  **+17 %** en tiradas nuevas. Si la ruleta tuviera numeros preferidos, el
  dibujo los encontraria.
