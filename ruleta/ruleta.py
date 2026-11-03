#!/usr/bin/env python3
"""
RULETA LAB - laboratorio de ruleta europea ficticia (solo Python estandar).

Reproduce una ruleta europea real (37 casillas, 0 unico, pagos oficiales y
limites de mesa tipicos) y hace dos experimentos:

  entrenar     Gira la ruleta N rondas. Varios modelos intentan predecir el
               siguiente numero / color aprendiendo de las rondas anteriores.
               Cada ronda se registra (numero, aciertos de cada modelo,
               estadisticas acumuladas) en un CSV y al final se genera un
               informe JSON.
  estrategias  Simulacion Monte Carlo de estrategias de apuesta (martingala,
               Fibonacci, D'Alembert, Labouchere, James Bond, apuesta audaz...)
               con banca, objetivo y limites de mesa reales.
  optimo       Aprende por programacion dinamica la apuesta optima para cada banca
               (maxima probabilidad de llegar al objetivo).
  patrones     Busca entre miles de dibujos (caballos, cuadros, cruces, diagonales,
               sectores, cada N numeros, escaleras 2-3-4...) los que mas salen y
               comprueba si siguen funcionando en tiradas nuevas.
               --datos fichero.txt analiza tiradas reales de un casino.
  escalada     Empieza con poco dinero (--banca 5), juega la apuesta audaz sin
               techo y apunta el maximo alcanzado en 1.000.000 de partidas.
  dibujo       Observa 1.000.000 de tiradas, busca el dibujo (de 2 en 2, de 4 en
               4, mezcla, una zona, de 6 en 6) que mas sale, lo comprueba con
               otras 1.000.000 y lo pinta sobre el tapete (salida/dibujos_*.svg).
  todo         Todo lo anterior y un informe conjunto: salida/informe_para_claude.json

Ejemplos:
  python ruleta.py todo
  python ruleta.py entrenar --rondas 2000 --ver
  python ruleta.py entrenar --sesgo          (rueda trucada: grupo de control)
  python ruleta.py estrategias --mesa francesa --banca 100 --objetivo 150
"""
import argparse
import bisect
import csv
import json
import math
import os
import random
import statistics
import sys
import time
from collections import Counter

# --------------------------------------------------------------------------
# La rueda
# --------------------------------------------------------------------------
# Orden real de los numeros en el cilindro de la ruleta europea.
WHEEL = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
         5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
POS = {n: i for i, n in enumerate(WHEEL)}
REDS = frozenset({1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36})
BLACKS = frozenset(range(1, 37)) - REDS
N = 37


def color(n):
    return "verde" if n == 0 else ("rojo" if n in REDS else "negro")


def docena(n):
    return 0 if n == 0 else (n - 1) // 12 + 1


def columna(n):
    return 0 if n == 0 else (n - 1) % 3 + 1


# Limites de mesa. Son valores TIPICOS: cada casino publica los suyos en la
# mesa, se pueden cambiar aqui. Los pagos y probabilidades son los oficiales.
MESAS = {
    "casino_es": dict(
        nombre="Casino fisico (Espana), ruleta europea",
        min_interior=1.0, min_exterior=5.0,
        max_pleno=100.0, max_exterior=3000.0, partage=False),
    "francesa": dict(
        nombre="Ruleta francesa (europea + regla La Partage en suertes sencillas)",
        min_interior=1.0, min_exterior=5.0,
        max_pleno=100.0, max_exterior=3000.0, partage=True),
    "online": dict(
        nombre="Ruleta europea online (RNG)",
        min_interior=0.10, min_exterior=0.10,
        max_pleno=100.0, max_exterior=5000.0, partage=False),
}


# --------------------------------------------------------------------------
# Apuestas: el pago se deduce del numero de casillas cubiertas
#   pleno 35:1, caballo 17:1, transversal 11:1, cuadro 8:1, seisena 5:1,
#   docena/columna 2:1, suertes sencillas (rojo, par, pasa...) 1:1
# --------------------------------------------------------------------------
class Bet:
    __slots__ = ("nombre", "numeros", "importe", "exterior", "sencilla", "mult")

    def __init__(self, nombre, numeros, importe):
        self.nombre = nombre
        self.numeros = frozenset(numeros)
        self.importe = float(importe)
        k = len(self.numeros)
        self.mult = 36 // k - 1                   # premio neto por euro
        self.exterior = k >= 12                   # docenas, columnas, sencillas
        self.sencilla = k == 18

    def esperanza(self, partage):
        """Ganancia esperada exacta de esta apuesta (negativa)."""
        if partage and self.sencilla:
            return -self.importe / (2 * N)
        return -self.importe / N

    def neto(self, n, partage):
        if n in self.numeros:
            return self.importe * self.mult
        if partage and self.sencilla and n == 0:
            return -self.importe / 2              # La Partage: pierdes la mitad
        return -self.importe


ROJO, NEGRO = REDS, BLACKS
PAR = frozenset(range(2, 37, 2))
IMPAR = frozenset(range(1, 37, 2))
FALTA = frozenset(range(1, 19))
PASA = frozenset(range(19, 37))
DOC = {1: frozenset(range(1, 13)), 2: frozenset(range(13, 25)), 3: frozenset(range(25, 37))}
SEISENA_13_18 = frozenset(range(13, 19))


def ajustar(bets, mesa, banca):
    """Aplica limites de mesa y banca. Devuelve lista lista para jugar,
    [] si el jugador decide no apostar, o None si no puede (ruina)."""
    if not bets:
        return []
    for b in bets:
        lo = mesa["min_exterior"] if b.exterior else mesa["min_interior"]
        hi = mesa["max_exterior"] if b.exterior else mesa["max_pleno"] * len(b.numeros)
        b.importe = round(min(max(b.importe, lo), hi), 2)
    total = sum(b.importe for b in bets)
    if total > banca + 1e-9:                      # no llega: apuesta lo que le queda
        f = banca / total
        ok = []
        for b in bets:
            lo = mesa["min_exterior"] if b.exterior else mesa["min_interior"]
            b.importe = math.floor(b.importe * f * 100) / 100
            if b.importe >= lo:
                ok.append(b)
        return ok or None
    return bets


# --------------------------------------------------------------------------
# Generador de tiradas
# --------------------------------------------------------------------------
class Rueda:
    def __init__(self, rng, sesgo=None):
        self.rng = rng
        self.pesos = None
        if sesgo:
            self.pesos = [sesgo.get(n, 1.0) for n in range(N)]

    def girar(self):
        if self.pesos is None:
            return self.rng.randrange(N)
        return self.rng.choices(range(N), weights=self.pesos)[0]


# Rueda trucada de control: un sector fisico (5 casillas vecinas alrededor del
# 17) sale un 60% mas. Es el tipo de defecto mecanico que se ha llegado a
# explotar en ruedas antiguas; sirve para comprobar que los modelos SI
# detectan patrones cuando existen.
SESGO_CONTROL = {WHEEL[(POS[17] + d) % N]: 1.6 for d in range(-2, 3)}


# --------------------------------------------------------------------------
# Estadistica (sin scipy)
# --------------------------------------------------------------------------
def _gammaincc(a, x):
    """Q(a, x) regularizada (Numerical Recipes)."""
    if x <= 0:
        return 1.0
    gln = math.lgamma(a)
    if x < a + 1:
        s = d = 1.0 / a
        ap = a
        for _ in range(500):
            ap += 1
            d *= x / ap
            s += d
            if abs(d) < abs(s) * 1e-12:
                break
        return 1.0 - s * math.exp(-x + a * math.log(x) - gln)
    b = x + 1 - a
    c = 1e300
    d = 1 / b
    h = d
    for i in range(1, 500):
        an = -i * (i - a)
        b += 2
        d = an * d + b
        d = 1e-300 if abs(d) < 1e-300 else d
        c = b + an / c
        c = 1e-300 if abs(c) < 1e-300 else c
        d = 1 / d
        h *= d * c
        if abs(d * c - 1) < 1e-12:
            break
    return math.exp(-x + a * math.log(x) - gln) * h


def chi2_uniformidad(cuentas, total):
    if total == 0:
        return 0.0, 1.0
    e = total / N
    chi = sum((c - e) ** 2 / e for c in cuentas)
    return chi, _gammaincc((N - 1) / 2, chi / 2)


def test_binomial(aciertos, n, p):
    if n == 0:
        return 0.0, 1.0
    z = (aciertos - n * p) / math.sqrt(n * p * (1 - p))
    return z, math.erfc(abs(z) / math.sqrt(2))


# --------------------------------------------------------------------------
# Modelos que intentan predecir el siguiente numero (apuesta a pleno)
# --------------------------------------------------------------------------
class Modelo:
    nombre = ""
    desc = ""

    def predecir(self):
        raise NotImplementedError

    def aprender(self, n):
        pass


class Azar(Modelo):
    nombre, desc = "azar", "Numero al azar (linea base)"

    def __init__(self, rng):
        self.rng = rng

    def predecir(self):
        return self.rng.randrange(N)


class Caliente(Modelo):
    nombre, desc = "caliente", "El numero que mas ha salido (frecuencias)"

    def __init__(self):
        self.c = [0] * N
        self.best = 0

    def predecir(self):
        return self.best

    def aprender(self, n):
        self.c[n] += 1
        if self.c[n] > self.c[self.best]:
            self.best = n


class Frio(Modelo):
    nombre, desc = "frio", "El numero que lleva mas tiempo sin salir (le 'toca')"

    def __init__(self):
        self.visto = [-1] * N
        self.t = 0

    def predecir(self):
        return min(range(N), key=self.visto.__getitem__)

    def aprender(self, n):
        self.visto[n] = self.t
        self.t += 1


class Repetir(Modelo):
    nombre, desc = "repetir", "Repite el ultimo numero"

    def __init__(self):
        self.ult = 0

    def predecir(self):
        return self.ult

    def aprender(self, n):
        self.ult = n


class Markov(Modelo):
    nombre, desc = "markov", "Cadena de Markov: que suele salir despues del ultimo numero"

    def __init__(self):
        self.t = [[0] * N for _ in range(N)]
        self.ult = None

    def predecir(self):
        if self.ult is None:
            return 0
        fila = self.t[self.ult]
        return max(range(N), key=fila.__getitem__)

    def aprender(self, n):
        if self.ult is not None:
            self.t[self.ult][n] += 1
        self.ult = n


class Sector(Modelo):
    nombre, desc = "sector", "Sector caliente del cilindro (numero + 2 vecinos a cada lado)"

    def __init__(self):
        self.c = [0] * N  # por posicion en la rueda

    def predecir(self):
        mejor, bs = 0, -1
        for i in range(N):
            s = sum(self.c[(i + d) % N] for d in range(-2, 3))
            if s > bs:
                mejor, bs = i, s
        return WHEEL[mejor]

    def aprender(self, n):
        self.c[POS[n]] += 1


class RedNeuronal(Modelo):
    nombre, desc = "red_neuronal", "Regresion softmax online sobre los 3 ultimos numeros"

    def __init__(self, lr=0.02):
        self.lr = lr
        nf = 3 * N + 1
        self.W = [[0.0] * N for _ in range(nf)]   # W[feature][clase]
        self.hist = []

    def _feats(self):
        f = [3 * N]
        for k, n in enumerate(reversed(self.hist[-3:])):
            f.append(k * N + n)
        return f

    def _logits(self, f):
        z = [0.0] * N
        for j in f:
            w = self.W[j]
            for c in range(N):
                z[c] += w[c]
        return z

    def predecir(self):
        z = self._logits(self._feats())
        return max(range(N), key=z.__getitem__)

    def aprender(self, n):
        f = self._feats()
        z = self._logits(f)
        m = max(z)
        e = [math.exp(v - m) for v in z]
        s = sum(e)
        for c in range(N):
            g = e[c] / s - (1.0 if c == n else 0.0)
            if g:
                d = self.lr * g
                for j in f:
                    self.W[j][c] -= d
        self.hist.append(n)
        if len(self.hist) > 3:
            self.hist.pop(0)


# Modelos de color (apuesta a rojo/negro)
class ColorModelo:
    nombre = ""
    desc = ""

    def __init__(self):
        self.h = []

    def aprender(self, n):
        self.h.append(color(n))
        if len(self.h) > 50:
            self.h.pop(0)


class SeguirRacha(ColorModelo):
    nombre, desc = "seguir_racha", "Apuesta al color que acaba de salir"

    def predecir(self):
        for c in reversed(self.h):
            if c != "verde":
                return c
        return "rojo"


class ContraRacha(ColorModelo):
    nombre, desc = "contra_racha", "Tras 3+ iguales apuesta al contrario ('ya toca')"

    def predecir(self):
        u = [c for c in self.h if c != "verde"][-3:]
        if len(u) == 3 and len(set(u)) == 1:
            return "negro" if u[0] == "rojo" else "rojo"
        return u[-1] if u else "rojo"


class ColorCaliente(ColorModelo):
    nombre, desc = "color_caliente", "Color mas frecuente en las ultimas 20 tiradas"

    def predecir(self):
        u = self.h[-20:]
        return "rojo" if u.count("rojo") >= u.count("negro") else "negro"


# --------------------------------------------------------------------------
# Experimento 1: entrenar / evaluar modelos ronda a ronda
# --------------------------------------------------------------------------
C = {"rojo": "\033[41;97m", "negro": "\033[40;97m", "verde": "\033[42;30m",
     "ok": "\033[92m", "ko": "\033[90m", "r": "\033[0m", "b": "\033[1m"}


def entrenar(args):
    rng = random.Random(args.semilla)
    sesgo = SESGO_CONTROL if args.sesgo else None
    rueda = Rueda(rng, sesgo)
    modelos = [Azar(random.Random(args.semilla + 1)), Caliente(), Frio(), Repetir(),
               Markov(), Sector(), RedNeuronal()]
    cmodelos = [SeguirRacha(), ContraRacha(), ColorCaliente()]
    st = {m.nombre: dict(aciertos=0, beneficio=0.0) for m in modelos}
    cst = {m.nombre: dict(aciertos=0, beneficio=0.0) for m in cmodelos}
    cuentas = [0] * N
    rachas = {"rojo": 0, "negro": 0, "verde": 0}
    racha_max = {"rojo": 0, "negro": 0, "verde": 0}
    ultimo_color, racha = None, 0
    ausencia_max = 0
    visto = [-1] * N

    os.makedirs(args.salida, exist_ok=True)
    tag = "sesgada" if args.sesgo else "justa"
    ruta_csv = os.path.join(args.salida, f"rondas_{tag}.csv")
    f = open(ruta_csv, "w", newline="", encoding="utf-8")
    w = csv.writer(f, delimiter=";")
    cab = ["ronda", "numero", "color", "paridad", "docena", "columna"]
    for m in modelos:
        cab += [f"{m.nombre}_pred", f"{m.nombre}_acierto", f"{m.nombre}_tasa_%"]
    for m in cmodelos:
        cab += [f"{m.nombre}_pred", f"{m.nombre}_acierto"]
    cab += ["chi2", "p_uniformidad", "numero_mas_salido", "numero_mas_ausente"]
    w.writerow(cab)

    cada = args.cada or max(1, args.rondas // 20)
    t0 = time.time()
    print(f"\n{C['b']}== ENTRENAMIENTO: {args.rondas} rondas, rueda {tag} =={C['r']}")

    for r in range(1, args.rondas + 1):
        preds = [m.predecir() for m in modelos]
        cpreds = [m.predecir() for m in cmodelos]
        n = rueda.girar()
        col = color(n)

        fila = [r, n, col, "-" if n == 0 else ("par" if n % 2 == 0 else "impar"),
                docena(n), columna(n)]
        lin = []
        for m, p in zip(modelos, preds):
            ok = p == n
            s = st[m.nombre]
            s["aciertos"] += ok
            s["beneficio"] += 35 if ok else -1
            fila += [p, int(ok), round(100 * s["aciertos"] / r, 3)]
            lin.append(f"{C['ok'] if ok else C['ko']}{m.nombre}:{p:>2}{'*' if ok else ' '}{C['r']}")
            m.aprender(n)
        for m, p in zip(cmodelos, cpreds):
            ok = p == col
            s = cst[m.nombre]
            s["aciertos"] += ok
            s["beneficio"] += 1 if ok else -1
            fila += [p, int(ok)]
            m.aprender(n)

        cuentas[n] += 1
        visto[n] = r
        if col == ultimo_color:
            racha += 1
        else:
            ultimo_color, racha = col, 1
        racha_max[col] = max(racha_max[col], racha)
        chi, pval = chi2_uniformidad(cuentas, r)
        mas = max(range(N), key=cuentas.__getitem__)
        aus = min(range(N), key=visto.__getitem__)
        ausencia_max = max(ausencia_max, r - max(visto[aus], 0))
        fila += [round(chi, 3), round(pval, 5), mas, aus]
        w.writerow(fila)

        if args.ver:
            print(f"R{r:>6} {C[col]} {n:>2} {C['r']} " + " ".join(lin) +
                  f"  | chi2 p={pval:.3f}")
            if args.pausa:
                time.sleep(args.pausa)
        elif r % cada == 0 or r == args.rondas:
            mejor = max(st, key=lambda k: st[k]["aciertos"])
            print(f"  ronda {r:>8}  mas salido={mas:>2}  p_uniformidad={pval:.3f}  "
                  f"mejor modelo ahora: {mejor} ({100 * st[mejor]['aciertos'] / r:.2f}% "
                  f"vs 2.70% esperado)")
    f.close()

    R = args.rondas
    res_modelos = []
    for m in modelos:
        s = st[m.nombre]
        z, p = test_binomial(s["aciertos"], R, 1 / N)
        res_modelos.append(dict(
            modelo=m.nombre, descripcion=m.desc, aciertos=s["aciertos"],
            tasa_pct=round(100 * s["aciertos"] / R, 3), esperado_azar_pct=round(100 / N, 3),
            z=round(z, 2), p_valor=round(p, 4),
            beneficio_1eur_por_ronda=round(s["beneficio"], 2),
            roi_pct=round(100 * s["beneficio"] / R, 2)))
    res_color = []
    for m in cmodelos:
        s = cst[m.nombre]
        z, p = test_binomial(s["aciertos"], R, 18 / N)
        res_color.append(dict(
            modelo=m.nombre, descripcion=m.desc, aciertos=s["aciertos"],
            tasa_pct=round(100 * s["aciertos"] / R, 3), esperado_azar_pct=round(1800 / N, 3),
            z=round(z, 2), p_valor=round(p, 4),
            beneficio_1eur_por_ronda=round(s["beneficio"], 2),
            roi_pct=round(100 * s["beneficio"] / R, 2)))
    chi, pval = chi2_uniformidad(cuentas, R)
    informe = dict(
        rueda=tag, rondas=R, semilla=args.semilla,
        sesgo=({str(k): v for k, v in SESGO_CONTROL.items()} if args.sesgo else None),
        frecuencias={str(n): cuentas[n] for n in range(N)},
        chi2=round(chi, 2), p_uniformidad=round(pval, 4),
        racha_max_color=racha_max, ausencia_max_rondas=ausencia_max,
        modelos_pleno=res_modelos, modelos_color=res_color,
        csv=ruta_csv, segundos=round(time.time() - t0, 1))
    with open(os.path.join(args.salida, f"modelos_{tag}.json"), "w", encoding="utf-8") as fj:
        json.dump(informe, fj, ensure_ascii=False, indent=2)

    print(f"\n  {'modelo':<14}{'aciertos':>9}{'tasa':>9}{'azar':>8}{'z':>7}{'p':>8}{'ROI':>9}")
    for x in res_modelos + res_color:
        print(f"  {x['modelo']:<14}{x['aciertos']:>9}{x['tasa_pct']:>8.2f}%"
              f"{x['esperado_azar_pct']:>7.2f}%{x['z']:>7.2f}{x['p_valor']:>8.3f}{x['roi_pct']:>8.2f}%")
    print(f"  Uniformidad de la rueda: chi2={chi:.1f}  p={pval:.4f} "
          f"({'parece justa' if pval > 0.01 else 'SESGO DETECTADO'})")
    print(f"  CSV ronda a ronda: {ruta_csv}")
    return informe


# --------------------------------------------------------------------------
# Experimento 2: estrategias de apuesta (Monte Carlo)
# --------------------------------------------------------------------------
class Estrategia:
    nombre = ""
    desc = ""

    def reset(self, banca, objetivo, mesa):
        self.mesa, self.objetivo = mesa, objetivo
        self.ue = mesa["min_exterior"]
        self.ui = mesa["min_interior"]

    def apuestas(self, banca):
        return []

    def resultado(self, neto, n):
        pass


class NoJugar(Estrategia):
    nombre, desc = "no_jugar", "No apostar (referencia)"


class PlanoRojo(Estrategia):
    nombre, desc = "plano_rojo", "Siempre la minima a rojo"

    def apuestas(self, banca):
        return [Bet("rojo", ROJO, self.ue)]


class PlanoPleno(Estrategia):
    nombre, desc = "plano_pleno", "Siempre la minima a pleno al 17"

    def apuestas(self, banca):
        return [Bet("pleno 17", {17}, self.ui)]


class DosDocenas(Estrategia):
    nombre, desc = "dos_docenas", "Minima a 2a y 3a docena (cubre 24 numeros)"

    def apuestas(self, banca):
        return [Bet("doc2", DOC[2], self.ue), Bet("doc3", DOC[3], self.ue)]


class Martingala(Estrategia):
    nombre, desc = "martingala", "Rojo; dobla tras perder, vuelve a la minima al ganar"

    def reset(self, *a):
        super().reset(*a)
        self.k = 0

    def apuestas(self, banca):
        return [Bet("rojo", ROJO, self.ue * 2 ** self.k)]

    def resultado(self, neto, n):
        self.k = 0 if neto > 0 else self.k + 1


class DAlembert(Estrategia):
    nombre, desc = "dalembert", "Rojo; +1 unidad tras perder, -1 tras ganar"

    def reset(self, *a):
        super().reset(*a)
        self.u = 1

    def apuestas(self, banca):
        return [Bet("rojo", ROJO, self.ue * self.u)]

    def resultado(self, neto, n):
        self.u = max(1, self.u - 1) if neto > 0 else self.u + 1


class Fibonacci(Estrategia):
    nombre, desc = "fibonacci", "Rojo; avanza en Fibonacci al perder, retrocede 2 al ganar"
    FIB = [1, 1, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987, 1597]

    def reset(self, *a):
        super().reset(*a)
        self.i = 0

    def apuestas(self, banca):
        return [Bet("rojo", ROJO, self.ue * self.FIB[min(self.i, len(self.FIB) - 1)])]

    def resultado(self, neto, n):
        self.i = max(0, self.i - 2) if neto > 0 else self.i + 1


class Labouchere(Estrategia):
    nombre, desc = "labouchere", "Rojo; lista 1-2-3-4, apuesta extremos, tacha al ganar"

    def reset(self, *a):
        super().reset(*a)
        self.l = [1, 2, 3, 4]

    def apuestas(self, banca):
        if not self.l:
            self.l = [1, 2, 3, 4]
        u = self.l[0] + (self.l[-1] if len(self.l) > 1 else 0)
        return [Bet("rojo", ROJO, self.ue * u)]

    def resultado(self, neto, n):
        u = self.l[0] + (self.l[-1] if len(self.l) > 1 else 0)
        if neto > 0:
            self.l = self.l[1:-1]
        else:
            self.l.append(u)


class Paroli(Estrategia):
    nombre, desc = "paroli", "Rojo; dobla tras ganar (max 3 seguidas), minima al perder"

    def reset(self, *a):
        super().reset(*a)
        self.k = 0

    def apuestas(self, banca):
        return [Bet("rojo", ROJO, self.ue * 2 ** self.k)]

    def resultado(self, neto, n):
        self.k = (self.k + 1) % 3 if neto > 0 else 0


class JamesBond(Estrategia):
    nombre, desc = "james_bond", "14 a pasa (19-36), 5 a seisena 13-18, 1 al 0"

    def apuestas(self, banca):
        k = max(self.ue / 14, self.ui)
        return [Bet("pasa", PASA, 14 * k), Bet("seisena", SEISENA_13_18, 5 * k),
                Bet("cero", {0}, 1 * k)]


class SeguirCaliente(Estrategia):
    nombre, desc = "seguir_caliente", "Minima a pleno al numero que mas sale en la sesion"

    def reset(self, *a):
        super().reset(*a)
        self.c = Counter()

    def apuestas(self, banca):
        n = self.c.most_common(1)[0][0] if self.c else 17
        return [Bet(f"pleno {n}", {n}, self.ui)]

    def resultado(self, neto, n):
        self.c[n] += 1


class Audaz(Estrategia):
    nombre, desc = ("apuesta_audaz",
                    "Rojo; apuesta justo lo que falta para el objetivo (o todo si no llega)")

    def apuestas(self, banca):
        return [Bet("rojo", ROJO, max(self.ue, min(banca, self.objetivo - banca)))]


ESTRATEGIAS = [NoJugar, PlanoRojo, PlanoPleno, DosDocenas, Martingala, DAlembert,
               Fibonacci, Labouchere, Paroli, JamesBond, SeguirCaliente, Audaz]


def sesion(est, mesa, rueda, banca0, objetivo, max_rondas):
    banca, apostado, rondas, ev = banca0, 0.0, 0, 0.0
    est.reset(banca0, objetivo, mesa)
    partage = mesa["partage"]
    ruina = False
    while rondas < max_rondas and banca < objetivo - 1e-9:
        bets = ajustar(est.apuestas(banca), mesa, banca)
        if bets is None:
            ruina = True
            break
        if not bets:
            break
        n = rueda.girar()
        neto = sum(b.neto(n, partage) for b in bets)
        apostado += sum(b.importe for b in bets)
        ev += sum(b.esperanza(partage) for b in bets)
        banca = round(banca + neto, 2)
        rondas += 1
        est.resultado(neto, n)
    if not ruina and banca < min(mesa["min_interior"], mesa["min_exterior"]):
        ruina = True
    return banca - banca0, apostado, rondas, banca >= objetivo - 1e-9, ruina, ev


def estrategias(args):
    mesa = MESAS[args.mesa]
    rng = random.Random(args.semilla)
    rueda = Rueda(rng)
    print(f"\n{C['b']}== ESTRATEGIAS: {mesa['nombre']} =={C['r']}")
    print(f"  banca {args.banca} EUR, objetivo {args.objetivo} EUR, max {args.max_rondas} "
          f"rondas por sesion, {args.sesiones} sesiones por estrategia")
    print(f"  {'estrategia':<16}{'objetiv':>8}{'ruina':>8}{'EV/ses':>9}{'apuesta':>9}"
          f"{'ventaja':>8}{'gana10':>8}{'gana100':>8}{'gana1k':>8}")
    res = []
    for cls in ESTRATEGIAS:
        est = cls()
        t = time.time()
        netos, apost, rond, evt = [], 0.0, 0, 0.0
        obj = rui = 0
        for _ in range(args.sesiones):
            ne, ap, ro, ok, ru, ev = sesion(est, mesa, rueda, args.banca, args.objetivo,
                                            args.max_rondas)
            netos.append(ne)
            apost += ap
            rond += ro
            obj += ok
            rui += ru
            evt += ev
        S = args.sesiones
        netos.sort()
        media = sum(netos) / S
        mu = evt / S                      # esperanza exacta por sesion (sin ruido)
        sd = statistics.pstdev(netos)

        def p_ganando(k):                 # P(ir ganando tras k sesiones), aprox. normal
            if sd == 0:
                return 0.0
            return round(50 * math.erfc(-(k * mu) / (sd * math.sqrt(2 * k))), 1)

        res.append(dict(
            estrategia=est.nombre, descripcion=est.desc,
            p_objetivo_pct=round(100 * obj / S, 2), p_ruina_pct=round(100 * rui / S, 2),
            p_acaba_ganando_pct=round(100 * sum(x > 0 for x in netos) / S, 2),
            resultado_medio_simulado=round(media, 2), esperanza_exacta_sesion=round(mu, 3),
            desviacion_sesion=round(sd, 2),
            mediana=round(netos[S // 2], 2),
            peor_5pct=round(netos[S // 20], 2), mejor_5pct=round(netos[-S // 20], 2),
            apostado_medio=round(apost / S, 2), rondas_medias=round(rond / S, 1),
            ventaja_casa_efectiva_pct=round(-100 * evt / apost, 3) if apost else 0.0,
            esperanza_100_sesiones=round(100 * mu, 1),
            p_ganando_tras_10_sesiones_pct=p_ganando(10),
            p_ganando_tras_100_sesiones_pct=p_ganando(100),
            p_ganando_tras_1000_sesiones_pct=p_ganando(1000)))
        x = res[-1]
        print(f"  {x['estrategia']:<16}{x['p_objetivo_pct']:>7.1f}%{x['p_ruina_pct']:>7.1f}%"
              f"{x['esperanza_exacta_sesion']:>9.2f}{x['apostado_medio']:>9.1f}"
              f"{x['ventaja_casa_efectiva_pct']:>7.2f}%{x['p_ganando_tras_10_sesiones_pct']:>7.1f}%"
              f"{x['p_ganando_tras_100_sesiones_pct']:>7.1f}%"
              f"{x['p_ganando_tras_1000_sesiones_pct']:>7.1f}%  [{time.time() - t:.0f}s]")
    informe = dict(mesa=args.mesa, limites=mesa, banca=args.banca, objetivo=args.objetivo,
                   max_rondas=args.max_rondas, sesiones=args.sesiones, semilla=args.semilla,
                   resultados=res)
    os.makedirs(args.salida, exist_ok=True)
    ruta = os.path.join(args.salida, f"estrategias_{args.mesa}")
    with open(ruta + ".json", "w", encoding="utf-8") as fj:
        json.dump(informe, fj, ensure_ascii=False, indent=2)
    with open(ruta + ".csv", "w", newline="", encoding="utf-8") as fc:
        w = csv.DictWriter(fc, fieldnames=list(res[0].keys()), delimiter=";")
        w.writeheader()
        w.writerows(res)
    print(f"  Guardado en {ruta}.json / .csv")
    return informe


def teoria():
    """Esperanza exacta de cada tipo de apuesta en la ruleta europea."""
    filas = []
    for nombre, k in [("pleno", 1), ("caballo", 2), ("transversal", 3), ("cuadro", 4),
                      ("seisena", 6), ("docena/columna", 12), ("sencilla (rojo, par...)", 18)]:
        p = k / N
        mult = 36 // k - 1
        filas.append(dict(apuesta=nombre, numeros=k, paga=f"{mult}:1",
                          prob_pct=round(100 * p, 3),
                          ventaja_casa_pct=round(100 * (1 - p * (mult + 1)), 3)))
    filas.append(dict(apuesta="sencilla con La Partage", numeros=18, paga="1:1",
                      prob_pct=round(1800 / N, 3), ventaja_casa_pct=round(100 * 0.5 / N, 3)))
    return filas


# --------------------------------------------------------------------------
# Experimento 3: estrategia optima por programacion dinamica
# --------------------------------------------------------------------------
def optimo(args):
    """Aprende, para cada banca posible, la apuesta que maximiza la
    probabilidad de alcanzar el objetivo (iteracion de valores, rejilla de 1 EUR)."""
    mesa = MESAS[args.mesa]
    T = int(round(args.objetivo))
    B = int(round(args.banca))
    partage = mesa["partage"]
    lo_e = max(1, math.ceil(mesa["min_exterior"]))
    lo_i = max(1, math.ceil(mesa["min_interior"]))
    tipos = [("sencilla (rojo/negro...)", 18, lo_e, mesa["max_exterior"]),
             ("docena/columna", 12, lo_e, mesa["max_exterior"]),
             ("pleno", 1, lo_i, mesa["max_pleno"])]
    V = [0.0] * (T + 1)
    V[T] = 1.0

    def val(x):                                   # x puede ser fraccionario (La Partage)
        if x >= T:
            return 1.0
        if x <= 0:
            return 0.0
        i = int(x)
        return V[i] + (x - i) * (V[min(i + 1, T)] - V[i])

    pol = [None] * (T + 1)
    t0 = time.time()
    for it in range(2000):
        delta = 0.0
        for x in range(T - 1, 0, -1):
            mejor, acc = 0.0, None
            for nombre, k, lo, hi in tipos:
                p = k / N
                mult = 36 // k - 1
                for a in range(lo, int(min(x, hi)) + 1):
                    v = p * val(x + a * mult)
                    if partage and k == 18:
                        v += (1 / N) * val(x - a / 2) + (18 / N) * val(x - a)
                    else:
                        v += (1 - p) * val(x - a)
                    if v > mejor + 1e-12:
                        mejor, acc = v, (nombre, a)
            delta = max(delta, abs(mejor - V[x]))
            V[x], pol[x] = mejor, acc
        if delta < 1e-10:
            break

    # Referencia: apuesta audaz a sencilla y apuesta plana minima (cadena exacta)
    def politica(fn):
        W = [0.0] * (T + 1)
        W[T] = 1.0

        def w(x):
            if x >= T:
                return 1.0
            if x <= 0:
                return 0.0
            i = int(x)
            return W[i] + (x - i) * (W[min(i + 1, T)] - W[i])
        for _ in range(20000):
            d = 0.0
            for x in range(T - 1, 0, -1):
                a = fn(x)
                if a is None or a > x:
                    nv = 0.0
                else:
                    nv = (18 / N) * w(x + a)
                    nv += ((1 / N) * w(x - a / 2) + (18 / N) * w(x - a)) if partage \
                        else (19 / N) * w(x - a)
                d = max(d, abs(nv - W[x]))
                W[x] = nv
            if d < 1e-11:
                break
        return W

    audaz = politica(lambda x: max(lo_e, min(x, T - x)) if x >= lo_e else None)
    plana = politica(lambda x: lo_e if x >= lo_e else None)

    print(f"\n{C['b']}== ESTRATEGIA OPTIMA (programacion dinamica): {mesa['nombre']} =={C['r']}")
    print(f"  Objetivo: pasar de {B} EUR a {T} EUR.  Calculado en {it + 1} iteraciones, "
          f"{time.time() - t0:.1f}s")
    print(f"  P(objetivo) politica optima:      {100 * V[B]:6.2f}%")
    print(f"  P(objetivo) apuesta audaz a rojo:  {100 * audaz[B]:6.2f}%")
    print(f"  P(objetivo) plana minima a rojo:   {100 * plana[B]:6.2f}%  (sin limite de rondas)")
    print(f"  Juego justo sin casa (referencia): {100 * B / T:6.2f}%")
    print("  Politica optima aprendida (banca -> apuesta):")
    muestra = sorted(set([B] + list(range(lo_e, T, max(1, T // 15)))))
    tabla = []
    for x in muestra:
        if pol[x]:
            tabla.append(dict(banca=x, apuesta=pol[x][0], importe=pol[x][1],
                              p_objetivo_pct=round(100 * V[x], 2),
                              p_objetivo_audaz_pct=round(100 * audaz[x], 2)))
            print(f"    banca {x:>5} EUR -> {pol[x][1]:>4} EUR a {pol[x][0]:<26}"
                  f"P(objetivo) {100 * V[x]:6.2f}%  (audaz {100 * audaz[x]:6.2f}%)")
    informe = dict(mesa=args.mesa, banca=B, objetivo=T,
                   p_optima_pct=round(100 * V[B], 3), p_audaz_pct=round(100 * audaz[B], 3),
                   p_plana_pct=round(100 * plana[B], 3), p_juego_justo_pct=round(100 * B / T, 3),
                   politica=tabla)
    os.makedirs(args.salida, exist_ok=True)
    with open(os.path.join(args.salida, f"optimo_{args.mesa}.json"), "w", encoding="utf-8") as fj:
        json.dump(informe, fj, ensure_ascii=False, indent=2)
    return informe


# --------------------------------------------------------------------------
# Experimento 4: buscar "dibujos" de numeros que salgan mas (pattern mining)
# --------------------------------------------------------------------------
# Se apuesta 1 EUR a cada numero del dibujo (minimo de pleno en casino), asi
# que un dibujo de k numeros cuesta k EUR por tirada y si acierta cobra 36.
VOISINS = [22, 18, 29, 7, 28, 12, 35, 3, 26, 0, 32, 15, 19, 4, 21, 2, 25]
TIERS = [27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33]
ORPHELINS = [1, 20, 14, 31, 9, 17, 34, 6]
JEU_ZERO = [12, 35, 3, 26, 0, 32, 15]


def catalogo_patrones(rng, azar_por_k=80):
    pats = {}

    def add(nombre, nums):
        s = frozenset(nums)
        if 0 < len(s) < N and s not in pats:
            pats[s] = nombre

    for n in range(N):
        add(f"pleno {n}", [n])
    for n in range(1, 37):
        if n % 3:
            add(f"caballo {n}-{n + 1}", [n, n + 1])
        if n <= 33:
            add(f"caballo {n}-{n + 3}", [n, n + 3])
    for z in (1, 2, 3):
        add(f"caballo 0-{z}", [0, z])
    add("transversal 0-1-2", [0, 1, 2])
    add("transversal 0-2-3", [0, 2, 3])
    add("cuadro 0-1-2-3", [0, 1, 2, 3])
    for r in range(12):
        a = 3 * r + 1
        add(f"transversal {a}-{a + 2}", range(a, a + 3))
        if r < 11:
            add(f"seisena {a}-{a + 5}", range(a, a + 6))
        if r < 10:
            add(f"diagonal {a}-{a + 4}-{a + 8}", [a, a + 4, a + 8])
            add(f"diagonal {a + 2}-{a + 4}-{a + 6}", [a + 2, a + 4, a + 6])
    for n in range(1, 33):
        if n % 3:
            add(f"cuadro {n}-{n + 1}-{n + 3}-{n + 4}", [n, n + 1, n + 3, n + 4])
    for n in range(5, 33, 3):
        add(f"cruz en {n}", [n, n - 1, n + 1, n - 3, n + 3])
    for d in (1, 2, 3):
        add(f"docena {d}", DOC[d])
        add(f"columna {d}", [n for n in range(1, 37) if columna(n) == d])
    for nombre, s in (("rojo", ROJO), ("negro", NEGRO), ("par", PAR), ("impar", IMPAR),
                      ("falta 1-18", FALTA), ("pasa 19-36", PASA)):
        add(nombre, s)
    for k in range(2, 10):
        for o in range(k):
            add(f"cada {k} numeros (resto {o})", [n for n in range(1, 37) if n % k == o])
    for d in range(10):
        add(f"terminados en {d}", [n for n in range(N) if n % 10 == d])
    for w in (3, 5, 7, 9, 13, 17):
        for i in range(N):
            add(f"sector de {w} en el cilindro centrado en {WHEEL[i]}",
                [WHEEL[(i + j) % N] for j in range(-(w // 2), w // 2 + 1)])
    add("vecinos del cero", VOISINS)
    add("tercio del cilindro", TIERS)
    add("huerfanos", ORPHELINS)
    add("juego cero", JEU_ZERO)
    for k in range(2, 19):
        for t in range(azar_por_k):
            add(f"combinacion de {k} #{t}", rng.sample(range(N), k))
    return [(nombre, s) for s, nombre in pats.items()]


def _eval_estatico(s, cuentas, R):
    k = len(s)
    H = sum(cuentas[n] for n in s)
    p = k / N
    roi = (36 * H - k * R) / (k * R)
    z = (H - R * p) / math.sqrt(R * p * (1 - p))
    return roi, z, H


# Dibujos que cambian segun lo que va saliendo
class Adaptativo:
    nombre, desc = "", ""

    def __init__(self):
        self.h = []
        self.win = [0] * N            # cuentas de las ultimas 200 tiradas

    def ver(self, n, gano):
        self.h.append(n)
        self.win[n] += 1
        if len(self.h) > 200:
            self.win[self.h.pop(0)] -= 1

    def _top(self, k, frios=False):
        orden = sorted(range(N), key=lambda x: (self.win[x], x), reverse=not frios)
        return orden[:k]

    def _sector(self, centro, k):
        i = POS[centro]
        return [WHEEL[(i + j) % N] for j in range(-(k // 2), k - k // 2)]


class UltimosK(Adaptativo):
    def __init__(self, k):
        super().__init__()
        self.k = k
        self.nombre = f"ultimos_{k}_distintos"
        self.desc = f"Cubre los {k} ultimos numeros distintos que han salido"

    def cubrir(self):
        out = []
        for n in reversed(self.h):
            if n not in out:
                out.append(n)
            if len(out) == self.k:
                break
        return out


class VecinosUltimo(Adaptativo):
    def __init__(self, k):
        super().__init__()
        self.k = k
        self.nombre = f"vecinos_ultimo_{k}"
        self.desc = f"Sector de {k} casillas del cilindro alrededor del ultimo numero"

    def cubrir(self):
        return self._sector(self.h[-1], self.k) if self.h else []


class Espejo(Adaptativo):
    nombre, desc = "espejo_5", "Sector de 5 casillas en el lado opuesto del cilindro al ultimo numero"

    def cubrir(self):
        if not self.h:
            return []
        return self._sector(WHEEL[(POS[self.h[-1]] + 18) % N], 5)


class Calientes(Adaptativo):
    def __init__(self, k, frios=False):
        super().__init__()
        self.k, self.frios = k, frios
        self.nombre = f"{'frios' if frios else 'calientes'}_{k}"
        self.desc = (f"Los {k} numeros que {'menos' if frios else 'mas'} han salido "
                     f"en las ultimas 200 tiradas")

    def cubrir(self):
        return self._top(self.k, self.frios) if len(self.h) >= 37 else []


class MismaDocena(Adaptativo):
    nombre, desc = "docena_del_ultimo", "Cubre la docena del ultimo numero (12 numeros)"

    def cubrir(self):
        if not self.h or self.h[-1] == 0:
            return []
        return list(DOC[docena(self.h[-1])])


class Escalera(Adaptativo):
    """Dibujo en escalera: 2 numeros, si falla 3, si falla 4 ... y al acertar vuelve a 2."""

    def __init__(self, pasos, modo):
        super().__init__()
        self.pasos, self.modo, self.i = pasos, modo, 0
        txt = "-".join(map(str, pasos))
        self.nombre = f"escalera_{txt}_{modo}"
        self.desc = (f"Cubre {txt} numeros ({'mas calientes' if modo == 'calientes' else 'vecinos del ultimo'})"
                     f": sube un escalon al fallar, vuelve al primero al acertar")

    def cubrir(self):
        k = self.pasos[self.i]
        if self.modo == "calientes":
            return self._top(k) if len(self.h) >= 37 else []
        return self._sector(self.h[-1], k) if self.h else []

    def ver(self, n, gano):
        super().ver(n, gano)
        if gano is not None:
            self.i = 0 if gano else min(self.i + 1, len(self.pasos) - 1)


def adaptativos():
    return ([UltimosK(k) for k in (1, 3, 6, 12)] +
            [VecinosUltimo(k) for k in (3, 5, 9)] + [Espejo()] +
            [Calientes(k) for k in (1, 3, 6, 12)] +
            [Calientes(k, frios=True) for k in (3, 6, 12)] + [MismaDocena()] +
            [Escalera([2, 3, 4], "calientes"), Escalera([2, 3, 4], "vecinos"),
             Escalera([1, 2, 3, 4, 6, 8], "calientes")])


def _binom_cola(n, p, umbral):
    """P(X > umbral), X ~ Bin(n, p), exacta en escala logaritmica."""
    m = math.floor(umbral) + 1
    if m <= 0:
        return 1.0
    if m > n:
        return 0.0
    lp, lq = math.log(p), math.log1p(-p)
    tot = 0.0
    for x in range(m, n + 1):
        tot += math.exp(math.lgamma(n + 1) - math.lgamma(x + 1) - math.lgamma(n - x + 1)
                        + x * lp + (n - x) * lq)
    return min(1.0, tot)


def _cargar_tiradas(ruta):
    nums = []
    with open(ruta, encoding="utf-8") as f:
        for tok in f.read().replace(";", " ").replace(",", " ").split():
            if tok.isdigit() and 0 <= int(tok) <= 36:
                nums.append(int(tok))
    if len(nums) < 200:
        sys.exit(f"{ruta}: hacen falta al menos 200 tiradas (encontradas {len(nums)})")
    return nums


def patrones(args):
    rng = random.Random(args.semilla)
    if args.datos:
        tiradas = _cargar_tiradas(args.datos)
        tag = "datos_" + os.path.splitext(os.path.basename(args.datos))[0]
    else:
        rueda = Rueda(random.Random(args.semilla + 31), SESGO_CONTROL if args.sesgo else None)
        prueba_n = args.rondas_prueba or args.rondas
        tiradas = [rueda.girar() for _ in range(args.rondas + prueba_n)]
        tag = f"{'sesgada' if args.sesgo else 'justa'}_{args.rondas}"
    mitad = len(tiradas) // 2 if args.datos else args.rondas
    entreno, prueba = tiradas[:mitad], tiradas[mitad:]
    R1, R2 = len(entreno), len(prueba)
    c1, c2 = [0] * N, [0] * N
    for n in entreno:
        c1[n] += 1
    for n in prueba:
        c2[n] += 1

    cat = catalogo_patrones(rng)
    print(f"\n{C['b']}== PATRONES / DIBUJOS: rueda {tag} =={C['r']}")
    print(f"  {len(cat)} dibujos distintos. Se buscan en {R1} tiradas (entrenamiento) y se "
          f"comprueban en {R2} tiradas nuevas (prueba). 1 EUR por numero cubierto.")

    filas = []
    for nombre, s in cat:
        r1, z1, _ = _eval_estatico(s, c1, R1)
        r2, z2, _ = _eval_estatico(s, c2, R2)
        filas.append(dict(dibujo=nombre, numeros=sorted(s), k=len(s), roi_entreno_pct=round(100 * r1, 2),
                          z_entreno=round(z1, 2), roi_prueba_pct=round(100 * r2, 2),
                          z_prueba=round(z2, 2)))
    pos = sum(f["z_entreno"] > 1.96 for f in filas)
    print(f"  En entrenamiento {pos} dibujos ({100 * pos / len(filas):.1f}%) salen 'significativos' "
          f"(z>1.96). Por puro azar se esperan ~2.5%.")

    def top(clave, cuantos):
        return sorted(filas, key=lambda f: f[clave], reverse=True)[:cuantos]

    print(f"\n  Los 15 mejores dibujos en ENTRENAMIENTO y que pasa con ellos en tiradas NUEVAS:")
    print(f"  {'dibujo':<46}{'k':>3}{'ROI entreno':>13}{'z':>7}{'ROI prueba':>12}{'z':>7}")
    for f in top("z_entreno", 15):
        print(f"  {f['dibujo'][:46]:<46}{f['k']:>3}{f['roi_entreno_pct']:>12.2f}%{f['z_entreno']:>7.2f}"
              f"{f['roi_prueba_pct']:>11.2f}%{f['z_prueba']:>7.2f}")
    resumen_top = {}
    for q in (1, 10, 50, 200):
        t = top("z_entreno", q)
        resumen_top[f"top_{q}"] = dict(
            roi_entreno_medio_pct=round(statistics.mean(f["roi_entreno_pct"] for f in t), 2),
            roi_prueba_medio_pct=round(statistics.mean(f["roi_prueba_pct"] for f in t), 2))
    print("\n  Media de los mejores:   " + "   ".join(
        f"top {q}: entreno {v['roi_entreno_medio_pct']:+.2f}% -> prueba {v['roi_prueba_medio_pct']:+.2f}%"
        for q, v in zip((1, 10, 50, 200), resumen_top.values())))

    # Aprendizaje continuo: cada 1000 tiradas elige el mejor dibujo hasta ahora y lo juega
    B = 1000
    bloques = [tiradas[i:i + B] for i in range(0, len(tiradas), B)]
    acum = [0] * N
    vistos = 0
    wf = {"mejor_z": [0.0, 0.0], "mejor_roi": [0.0, 0.0]}
    elegidos = Counter()
    for b, bloque in enumerate(bloques):
        cb = [0] * N
        for n in bloque:
            cb[n] += 1
        if b >= 5:
            mz = max(cat, key=lambda p: _eval_estatico(p[1], acum, vistos)[1])
            mr = max(cat, key=lambda p: _eval_estatico(p[1], acum, vistos)[0])
            for clave, (nombre, s) in (("mejor_z", mz), ("mejor_roi", mr)):
                k = len(s)
                H = sum(cb[n] for n in s)
                wf[clave][0] += 36 * H - k * len(bloque)
                wf[clave][1] += k * len(bloque)
            elegidos[mz[0]] += 1
        for n in range(N):
            acum[n] += cb[n]
        vistos += len(bloque)
    print(f"\n  Aprendizaje continuo (cada {B} tiradas juega el dibujo que mejor va hasta ese momento):")
    wf_res = {}
    for clave, (ben, ap) in wf.items():
        wf_res[clave] = round(100 * ben / ap, 2) if ap else 0.0
        print(f"    eligiendo por {clave:<10} ROI real = {wf_res[clave]:+.2f}%")
    print("    dibujos que mas veces eligio: " + ", ".join(f"{n} ({c})" for n, c in elegidos.most_common(4)))

    # Dibujos que cambian segun lo que sale, jugados en las tiradas de prueba
    print(f"\n  Dibujos dinamicos (cambian cada tirada segun lo que va saliendo), en {R2} tiradas nuevas:")
    print(f"  {'dibujo':<36}{'acierta':>9}{'ROI':>9}{'z':>7}")
    ad_res = []
    for a in adaptativos():
        for n in entreno[-200:]:
            a.ver(n, None)
        ben = ap = jug = acier = 0
        esper = 0.0
        for n in prueba:
            cub = a.cubrir()
            gano = None
            if cub:
                k = len(cub)
                gano = n in cub
                ben += (36 if gano else 0) - k
                ap += k
                jug += 1
                acier += gano
                esper += k / N
            a.ver(n, gano)
        z = (acier - esper) / math.sqrt(max(esper * (1 - esper / max(jug, 1)), 1e-9))
        roi = 100 * ben / ap if ap else 0.0
        ad_res.append(dict(dibujo=a.nombre, descripcion=a.desc, tiradas_jugadas=jug,
                           tasa_acierto_pct=round(100 * acier / max(jug, 1), 2),
                           roi_pct=round(roi, 2), z=round(z, 2)))
        print(f"  {a.nombre:<36}{100 * acier / max(jug, 1):>8.2f}%{roi:>8.2f}%{z:>7.2f}")

    # Ganar poco pero a menudo: cubrir mas numeros
    print("\n  Cubrir mas numeros = aciertas mas a menudo pero cobras menos (1 EUR por numero):")
    print(f"  {'numeros':>8}{'acierta':>9}{'gana si acierta':>17}{'pierde si falla':>17}"
          f"{'EV/tirada':>11}   P(ir ganando tras 50 / 200 / 1000 tiradas)")
    compromiso = []
    for k in (1, 2, 3, 4, 6, 8, 12, 18, 24, 30, 32, 35, 36):
        p = k / N
        pg = [_binom_cola(n, p, k * n / 36) for n in (50, 200, 1000)]
        compromiso.append(dict(numeros=k, prob_acierto_pct=round(100 * p, 2), gana_si_acierta=36 - k,
                               pierde_si_falla=k, ev_por_tirada=round(-k / N, 3),
                               p_ganando_50_pct=round(100 * pg[0], 1),
                               p_ganando_200_pct=round(100 * pg[1], 1),
                               p_ganando_1000_pct=round(100 * pg[2], 1)))
        print(f"  {k:>8}{100 * p:>8.1f}%{36 - k:>14} EUR{k:>14} EUR{-k / N:>10.3f}"
              f"   {100 * pg[0]:5.1f}% / {100 * pg[1]:5.1f}% / {100 * pg[2]:5.1f}%")

    informe = dict(rueda=tag, tiradas_entreno=R1, tiradas_prueba=R2, num_dibujos=len(filas),
                   significativos_en_entreno=pos, resumen_mejores=resumen_top,
                   mejores_15=top("z_entreno", 15), aprendizaje_continuo_roi_pct=wf_res,
                   mas_elegidos=elegidos.most_common(10), dinamicos=ad_res,
                   cubrir_mas_numeros=compromiso)
    os.makedirs(args.salida, exist_ok=True)
    with open(os.path.join(args.salida, f"patrones_{tag}.json"), "w", encoding="utf-8") as fj:
        json.dump(informe, fj, ensure_ascii=False, indent=2)
    with open(os.path.join(args.salida, f"patrones_{tag}.csv"), "w", newline="", encoding="utf-8") as fc:
        w = csv.DictWriter(fc, fieldnames=list(filas[0].keys()), delimiter=";")
        w.writeheader()
        for f in sorted(filas, key=lambda f: f["z_entreno"], reverse=True):
            w.writerow({**f, "numeros": " ".join(map(str, f["numeros"]))})
    print(f"  Guardado en {args.salida}/patrones_{tag}.json / .csv")
    return informe


# --------------------------------------------------------------------------
# Experimento 5: empezar con poco dinero y ver hasta donde se llega
# --------------------------------------------------------------------------
def _partida_audaz(rng, banca, mesa, max_tiradas, guardar=False):
    """Apuesta audaz sin techo: todo a rojo (hasta el maximo de la mesa) en cada
    tirada. Devuelve (pico, tiradas, saldo_final, historial)."""
    lo, hi, partage = mesa["min_exterior"], mesa["max_exterior"], mesa["partage"]
    pico, t, hist = banca, 0, []
    while banca >= lo and t < max_tiradas:
        a = min(banca, hi)
        n = rng.randrange(N)
        if n in REDS:
            banca += a
        elif n == 0 and partage:
            banca -= a / 2
        else:
            banca -= a
        t += 1
        if guardar:
            hist.append((t, a, n, banca))
        if banca > pico:
            pico = banca
    return pico, t, banca, hist


def escalada(args):
    mesa = MESAS[args.mesa]
    rng = random.Random(args.semilla)
    B = args.banca
    print(f"\n{C['b']}== ESCALADA: empezar con {B:g} EUR ({mesa['nombre']}) =={C['r']}")
    print(f"  Estrategia: apuesta audaz sin techo -> todo el saldo a rojo en cada tirada "
          f"(maximo de mesa {mesa['max_exterior']:g} EUR).")

    def contar(hist, titulo):
        print(f"\n  {titulo}")
        for t, a, n, b in hist:
            res = "GANA" if n in REDS else ("CERO, recupera la mitad" if n == 0 and mesa["partage"]
                                            else "pierde")
            print(f"    tirada {t:>3}: {a:>9,.2f} EUR a rojo -> sale {n:>2} {color(n):<5} "
                  f"{res:<24} saldo {b:>11,.2f} EUR")

    # 1) Una partida en directo
    pico, t, fin, hist = _partida_audaz(rng, B, mesa, args.max_rondas, guardar=True)
    contar(hist, "Partida en directo (intento 1):")
    print(f"    -> maximo alcanzado: {pico:,.2f} EUR en {t} tiradas; termina con {fin:,.2f} EUR")

    # 2) Repetirla muchas veces
    S = args.intentos
    t0 = time.time()
    picos = []
    tot_final = 0.0
    record = (0, None)
    for i in range(S):
        st = rng.getstate()
        p, _, f, _ = _partida_audaz(rng, B, mesa, args.max_rondas)
        picos.append(p)
        tot_final += f
        if p > record[0]:
            record = (p, st, i + 1)
    picos.sort()
    umbrales = sorted({B * 2 ** k for k in range(1, 16)} | {100, 1000, 10000, 100000})
    dist = []
    print(f"\n  {S:,} partidas empezando con {B:g} EUR ({time.time() - t0:.0f}s):")
    print(f"    {'llegar a':>12}  {'probabilidad':>12}   {'1 de cada':>12}")
    for u in umbrales:
        if u <= B:
            continue
        c = S - bisect.bisect_left(picos, u - 1e-9)
        pr = c / S
        dist.append(dict(llegar_a=u, partidas=c, prob_pct=round(100 * pr, 5)))
        print(f"    {u:>12,.0f}  {100 * pr:>11.4f}%   "
              f"{(f'{1 / pr:,.0f}' if pr else 'ninguna'):>12}")
    mediana = picos[S // 2]
    invertido = S * B
    print(f"    mitad de las partidas no pasa de {mediana:,.2f} EUR de maximo")

    # 3) La mejor partida de todas, tirada a tirada
    rec, st, idx = record
    rng2 = random.Random()
    rng2.setstate(st)
    _, t, fin, hist = _partida_audaz(rng2, B, mesa, args.max_rondas, guardar=True)
    contar(hist[:40], f"RECORD: la mejor de {S:,} partidas (partida n.{idx:,}):")
    if len(hist) > 40:
        print(f"    ... ({len(hist) - 40} tiradas mas)")
    print(f"    -> MAXIMO: {rec:,.2f} EUR (x{rec / B:,.0f}); si no se retira, acaba con {fin:,.2f} EUR")
    print(f"\n  Cuentas de las {S:,} partidas: puestos {invertido:,.0f} EUR, "
          f"recuperados {tot_final:,.0f} EUR -> la casa gana {invertido - tot_final:,.0f} EUR "
          f"({100 * (invertido - tot_final) / invertido:.1f}% de lo puesto).")
    print("  (Esto si nadie se retira en su maximo. Retirarse en un objetivo fijo es lo que "
          "convierte el pico en dinero real.)")
    informe = dict(mesa=args.mesa, banca_inicial=B, partidas=S, estrategia="apuesta audaz sin techo a rojo",
                   record_eur=round(rec, 2), record_partida=idx, record_tiradas=t,
                   record_historial=[dict(tirada=a, apuesta=b, numero=c, saldo=round(d, 2))
                                     for a, b, c, d in hist[:200]],
                   mediana_maximo=mediana, distribucion=dist,
                   puesto_total=invertido, recuperado_total=round(tot_final, 2))
    os.makedirs(args.salida, exist_ok=True)
    with open(os.path.join(args.salida, f"escalada_{args.mesa}_{B:g}eur.json"), "w",
              encoding="utf-8") as fj:
        json.dump(informe, fj, ensure_ascii=False, indent=2)
    return informe


# --------------------------------------------------------------------------
# Experimento 6: el "dibujo" en el tapete con mas probabilidad de acertar
# --------------------------------------------------------------------------
def apuestas_interiores():
    """Todas las apuestas legales de 2, 3, 4 y 6 numeros sobre el tapete."""
    out = []
    for n in range(1, 37):
        if n % 3:
            out.append(("caballo", frozenset({n, n + 1})))
        if n <= 33:
            out.append(("caballo", frozenset({n, n + 3})))
        if n % 3 and n <= 32:
            out.append(("cuadro", frozenset({n, n + 1, n + 3, n + 4})))
    for r in range(12):
        a = 3 * r + 1
        out.append(("transversal", frozenset(range(a, a + 3))))
        if r < 11:
            out.append(("seisena", frozenset(range(a, a + 6))))
    return out


def nombre_apuesta(tipo, s):
    return f"{tipo} {'-'.join(map(str, sorted(s)))}"


def buscar_dibujo(cuentas, composicion, zona=None, ancho=400):
    """Busqueda en haz: elige apuestas que no se pisen, con la composicion pedida
    (p.ej. {'cuadro': 3, 'caballo': 2}), que mas tiradas observadas cubran."""
    todas = [(t, s) for t, s in apuestas_interiores()
             if t in composicion and (zona is None or s <= zona)]
    peso = {i: sum(cuentas[n] for n in s) for i, (t, s) in enumerate(todas)}
    haz = [(0, frozenset(), (), dict(composicion), -1)]
    for _ in range(sum(composicion.values())):
        nuevo = []
        for sc, cub, elegidas, resto, ult in haz:
            for i in range(ult + 1, len(todas)):
                t, s = todas[i]
                if resto.get(t, 0) <= 0 or cub & s:
                    continue
                r2 = dict(resto)
                r2[t] -= 1
                nuevo.append((sc + peso[i], cub | s, elegidas + (i,), r2, i))
        if not nuevo:
            break
        nuevo.sort(key=lambda x: -x[0])
        haz = nuevo[:ancho]
    mejor = haz[0]
    return [todas[i] for i in mejor[2]]


def _evaluar_dibujo(apuestas, cuentas, R):
    """Aciertos y beneficio con 1 ficha de 1 EUR por apuesta."""
    cubre = set().union(*[s for _, s in apuestas])
    hits = sum(cuentas[n] for n in cubre)
    cobro = sum(cuentas[n] * sum(36 // len(s) for _, s in apuestas if n in s) for n in cubre)
    coste = len(apuestas) * R
    return hits, cobro - coste


def _tapete_ascii(cuentas, R, marcados=frozenset()):
    lineas = []
    for fila in (3, 2, 1):
        celdas = []
        for c in range(12):
            n = 3 * c + fila
            pct = 100 * cuentas[n] / R
            celdas.append(f"{'[' if n in marcados else ' '}{n:>2} {pct:4.2f}%{']' if n in marcados else ' '}")
        lineas.append("    " + "|".join(celdas))
    lineas.insert(0, f"    cero: {100 * cuentas[0] / R:.2f}%")
    return "\n".join(lineas)


def _svg_tapete(paneles, ruta):
    W, H, Z, M = 52, 46, 40, 20
    ancho = M * 2 + Z + 12 * W
    alto_panel = 3 * H + 92
    alto = len(paneles) * alto_panel + 20
    col = {"rojo": "#c0392b", "negro": "#222", "verde": "#1e8449"}
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{ancho}" height="{alto}" '
         f'viewBox="0 0 {ancho} {alto}" font-family="DejaVu Sans, Arial, sans-serif">',
         f'<rect width="{ancho}" height="{alto}" fill="#0b3d2e"/>']

    def es(t):          # formato espanol solo en los numeros: 1.000.000 y 2,70%
        import re
        tr = str.maketrans({",": ".", ".": ","})
        return re.sub(r"\d[\d,.]*\d", lambda m: m.group(0).translate(tr), t)

    def centro(n, x0, y0):
        if n == 0:
            return x0 + Z / 2, y0 + 1.5 * H
        c, r = (n - 1) // 3, 2 - (n - 1) % 3
        return x0 + Z + c * W + W / 2, y0 + r * H + H / 2

    for k, p in enumerate(paneles):
        y0 = 10 + k * alto_panel + 48
        x0 = M
        o.append(f'<text x="{M}" y="{y0 - 30}" fill="#fff" font-size="16" font-weight="bold">'
                 f'{es(p["titulo"])}</text>')
        o.append(f'<text x="{M}" y="{y0 - 11}" fill="#cfe9dc" font-size="12">{es(p["sub"])}</text>')
        cub = p.get("cubre")
        frec = p.get("frec")
        for n in range(N):
            if n == 0:
                x, y, w, h = x0, y0, Z, 3 * H
            else:
                c, r = (n - 1) // 3, 2 - (n - 1) % 3
                x, y, w, h = x0 + Z + c * W, y0 + r * H, W, H
            activo = cub is None or n in cub
            op = 1.0 if activo else 0.18
            o.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{col[color(n)]}" '
                     f'fill-opacity="{op}" stroke="#e8e8e8" stroke-width="1"/>')
            cx, cy = x + w / 2, y + h / 2
            o.append(f'<text x="{cx}" y="{cy + (-3 if frec else 5)}" fill="#fff" fill-opacity="{max(op, .45)}" '
                     f'font-size="14" font-weight="bold" text-anchor="middle">{n}</text>')
            if frec:
                d = frec[n] - 100 / N
                tono = "#ffd166" if d > 0 else "#9ad1ff"
                o.append(f'<text x="{cx}" y="{cy + 12}" fill="{tono}" font-size="9.5" '
                         f'text-anchor="middle">{es(f"{frec[n]:.3f}")}%</text>')
        for t, s in p.get("apuestas", []):
            if t in ("seisena", "transversal"):
                cmin = (min(s) - 1) // 3
                cx = x0 + Z + (cmin + (1 if t == "seisena" else 0.5)) * W
                cy = y0 + 3 * H
            else:
                pts = [centro(n, x0, y0) for n in s]
                cx = sum(a for a, _ in pts) / len(pts)
                cy = sum(b for _, b in pts) / len(pts)
            o.append(f'<circle cx="{cx}" cy="{cy}" r="11" fill="#f1c40f" stroke="#7d5a00" '
                     f'stroke-width="2.5" stroke-dasharray="3 2"/>')
            o.append(f'<text x="{cx}" y="{cy + 4}" font-size="10" font-weight="bold" '
                     f'text-anchor="middle" fill="#3b2a00">1</text>')
        if p.get("pie"):
            o.append(f'<text x="{M}" y="{y0 + 3 * H + 30}" fill="#fff" font-size="12">{es(p["pie"])}</text>')
    o.append("</svg>")
    with open(ruta, "w", encoding="utf-8") as f:
        f.write("\n".join(o))


def dibujo(args):
    rng = random.Random(args.semilla + 77)
    rueda = Rueda(rng, SESGO_CONTROL if args.sesgo else None)
    R = args.rondas
    obs, chk = [0] * N, [0] * N
    for _ in range(R):
        obs[rueda.girar()] += 1
    for _ in range(R):
        chk[rueda.girar()] += 1
    tag = "sesgada" if args.sesgo else "justa"
    frec = [100 * c / R for c in obs]
    print(f"\n{C['b']}== DIBUJO EN EL TAPETE: {R:,} tiradas observadas + {R:,} de comprobacion "
          f"(rueda {tag}) =={C['r']}")
    print("  Donde ha caido la bola (porcentaje de veces que sale cada numero; azar = 2,70%):")
    print(_tapete_ascii(obs, R))
    orden = sorted(range(N), key=lambda n: -obs[n])
    _, pval = chi2_uniformidad(obs, R)
    print(f"  Test de uniformidad: p = {pval:.3f} "
          f"({'diferencias normales del azar' if pval > 0.01 else 'SESGO DETECTADO'})")
    print(f"  Mas salidos: {', '.join(f'{n} ({frec[n]:.3f}%)' for n in orden[:6])}")
    print(f"  Menos salidos: {', '.join(f'{n} ({frec[n]:.3f}%)' for n in orden[-6:])}")

    F = args.fichas
    lo, hi = (int(x) for x in args.zona.split("-"))
    zona = frozenset(range(lo, hi + 1))
    nz = max(1, F - 1)
    planes = [
        ("De 2 en 2 (caballos)", {"caballo": F}, None),
        ("De 4 en 4 (cuadros)", {"cuadro": F}, None),
        ("Mezcla de 4 en 4 y de 2 en 2", {"cuadro": F - F // 2, "caballo": F // 2}, None),
        (f"Tu zona {lo}-{hi}: cuadros + caballos", {"cuadro": (nz + 1) // 2, "caballo": nz // 2}, zona),
        ("Maxima probabilidad: de 6 en 6 (seisenas)", {"seisena": min(F, 6)}, None),
    ]
    res = []
    paneles = [dict(titulo=f"Donde cae la bola en {R:,} tiradas",
                    sub="Porcentaje de cada numero. Amarillo: por encima del 2.703% esperado; azul: por debajo.",
                    frec=frec, pie=(f"Mas salido: {orden[0]} ({frec[orden[0]]:.3f}%). Menos: {orden[-1]} "
                                    f"({frec[orden[-1]]:.3f}%). Uniformidad: p = {pval:.2f}, "
                                    + ("diferencias de puro azar." if pval > 0.01 else "RUEDA SESGADA.")))]
    print(f"\n  Los mejores dibujos con {F} fichas de 1 EUR (elegidos con las tiradas observadas "
          f"y comprobados con tiradas nuevas):")
    print(f"  {'dibujo':<44}{'fichas':>7}{'numeros':>8}{'acierta (obs)':>14}{'acierta (nuevas)':>17}"
          f"{'teorico':>9}{'ROI nuevas':>12}")
    for titulo, comp, z in planes:
        ap = buscar_dibujo(obs, comp, z)
        if not ap:
            continue
        cubre = frozenset().union(*[s for _, s in ap])
        f = len(ap)
        h1, _ = _evaluar_dibujo(ap, obs, R)
        h2, ben2 = _evaluar_dibujo(ap, chk, R)
        teo = len(cubre) / N
        cobros = sorted({sum(36 // len(s) for _, s in ap if n in s) for n in cubre})
        res.append(dict(dibujo=titulo, fichas=f, apuestas=[nombre_apuesta(t, s) for t, s in ap],
                        numeros=sorted(cubre), num_numeros=len(cubre),
                        acierto_observado_pct=round(100 * h1 / R, 3),
                        acierto_comprobacion_pct=round(100 * h2 / R, 3),
                        acierto_teorico_pct=round(100 * teo, 3),
                        roi_comprobacion_pct=round(100 * ben2 / (f * R), 3),
                        cobro_si_acierta_eur=cobros))
        x = res[-1]
        print(f"  {titulo[:44]:<44}{f:>7}{len(cubre):>8}{x['acierto_observado_pct']:>13.2f}%"
              f"{x['acierto_comprobacion_pct']:>16.2f}%{100 * teo:>8.2f}%{x['roi_comprobacion_pct']:>11.2f}%")
        print(f"      fichas en: {', '.join(x['apuestas'])}")
        gan = " o ".join(f"+{c - f}" for c in cobros)
        print(f"      si sale uno de sus {len(cubre)} numeros cobras {' o '.join(map(str, cobros))} EUR "
              f"(ganas {gan} EUR); si no, pierdes {f} EUR")
        paneles.append(dict(
            titulo=f"{titulo} - {f} fichas, {len(cubre)} numeros",
            sub=(f"Acierta el {x['acierto_comprobacion_pct']:.2f}% de las tiradas nuevas "
                 f"(teorico {100 * teo:.2f}%). Si acierta: ganas {gan} EUR. Si falla: -{f} EUR."),
            cubre=cubre, apuestas=ap,
            pie=f"Resultado en {R:,} tiradas nuevas: {x['roi_comprobacion_pct']:+.2f}% de lo apostado "
                f"(la casa: -2.70%)."))
    os.makedirs(args.salida, exist_ok=True)
    svg = os.path.join(args.salida, f"dibujos_{tag}.svg")
    _svg_tapete(paneles, svg)
    print(f"\n  Probabilidad de acertar = numeros cubiertos / 37, sea cual sea la forma del dibujo.")
    print(f"  Imagen del tapete con los dibujos: {svg}")
    informe = dict(rueda=tag, tiradas_observadas=R, tiradas_comprobacion=R,
                   frecuencias_pct={str(n): round(frec[n], 4) for n in range(N)},
                   mas_salidos=orden[:6], menos_salidos=orden[-6:], fichas=F, zona=args.zona,
                   dibujos=res, imagen=svg)
    with open(os.path.join(args.salida, f"dibujos_{tag}.json"), "w", encoding="utf-8") as fj:
        json.dump(informe, fj, ensure_ascii=False, indent=2)
    return informe


def todo(args):
    t = teoria()
    m1 = entrenar(args)
    a2 = argparse.Namespace(**vars(args))
    a2.sesgo, a2.ver = True, False
    m2 = entrenar(a2)
    es, op = {}, {}
    for mesa in ("casino_es", "francesa"):
        a3 = argparse.Namespace(**vars(args))
        a3.mesa = mesa
        es[mesa] = estrategias(a3)
        op[mesa] = optimo(a3)
    a4 = argparse.Namespace(**vars(args))
    a4.sesgo = False
    p1 = patrones(a4)
    a4.rondas, a4.rondas_prueba = 500, 100_000
    p0 = patrones(a4)
    a4.rondas, a4.rondas_prueba, a4.sesgo = args.rondas, 0, True
    p2 = patrones(a4)
    informe = dict(teoria=t, modelos_rueda_justa=m1, modelos_rueda_sesgada_control=m2,
                   estrategias=es, estrategia_optima=op,
                   patrones_rueda_justa=p1, patrones_500_tiradas_vs_100000_nuevas=p0,
                   patrones_rueda_sesgada_control=p2)
    ruta = os.path.join(args.salida, "informe_para_claude.json")
    with open(ruta, "w", encoding="utf-8") as fj:
        json.dump(informe, fj, ensure_ascii=False, indent=2)
    print(f"\n{C['b']}Informe completo: {ruta}{C['r']}  <- pasaselo a Claude")


def main():
    ap = argparse.ArgumentParser(description="Laboratorio de ruleta europea ficticia")
    ap.add_argument("modo", nargs="?", default="todo", choices=["todo", "entrenar", "estrategias", "optimo", "patrones", "escalada", "dibujo"])
    ap.add_argument("--rondas", type=int, default=100_000)
    ap.add_argument("--sesgo", action="store_true", help="rueda trucada de control")
    ap.add_argument("--ver", action="store_true", help="muestra cada ronda en pantalla")
    ap.add_argument("--pausa", type=float, default=0.0, help="segundos entre rondas con --ver")
    ap.add_argument("--cada", type=int, default=0, help="cada cuantas rondas imprimir progreso")
    ap.add_argument("--mesa", default="casino_es", choices=list(MESAS))
    ap.add_argument("--banca", type=float, default=100.0)
    ap.add_argument("--objetivo", type=float, default=150.0)
    ap.add_argument("--max-rondas", type=int, default=200)
    ap.add_argument("--sesiones", type=int, default=10_000)
    ap.add_argument("--semilla", type=int, default=2026)
    ap.add_argument("--rondas-prueba", type=int, default=0,
                    help="patrones: tiradas nuevas para comprobar (por defecto = --rondas)")
    ap.add_argument("--intentos", type=int, default=1_000_000, help="escalada: partidas a simular")
    ap.add_argument("--fichas", type=int, default=5, help="dibujo: fichas de 1 EUR por tirada")
    ap.add_argument("--zona", default="19-30", help="dibujo: zona del tapete, p.ej. 19-30")
    ap.add_argument("--datos", help="archivo con tiradas reales (numeros 0-36) para el modo patrones")
    ap.add_argument("--salida", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                     "salida"))
    args = ap.parse_args()
    if os.name == "nt":
        os.system("")  # activa colores ANSI en la consola de Windows
    {"todo": todo, "entrenar": entrenar, "estrategias": estrategias, "optimo": optimo, "patrones": patrones, "escalada": escalada, "dibujo": dibujo}[args.modo](args)


if __name__ == "__main__":
    main()
