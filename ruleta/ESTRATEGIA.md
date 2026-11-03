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

## 5. La estrategia "perfecta" (lo mejor que permiten las matematicas)

No existe ninguna estrategia que gane a la larga. Las tres simulaciones lo
confirman: la esperanza es negativa con cualquier combinacion de apuestas, y
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

Lo unico que ha batido de verdad a la ruleta son defectos fisicos de la
rueda (como el grupo de control de este experimento) o medir la bola en
vuelo. Los casinos actuales revisan y rotan las ruedas, y la ruleta online
usa un generador aleatorio sin defectos fisicos que explotar.
