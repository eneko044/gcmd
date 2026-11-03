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
  todo         Todo lo anterior y un informe conjunto: salida/informe_para_claude.json

Ejemplos:
  python ruleta.py todo
  python ruleta.py entrenar --rondas 2000 --ver
  python ruleta.py entrenar --sesgo          (rueda trucada: grupo de control)
  python ruleta.py estrategias --mesa francesa --banca 100 --objetivo 150
"""
import argparse
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
    informe = dict(teoria=t, modelos_rueda_justa=m1, modelos_rueda_sesgada_control=m2,
                   estrategias=es, estrategia_optima=op)
    ruta = os.path.join(args.salida, "informe_para_claude.json")
    with open(ruta, "w", encoding="utf-8") as fj:
        json.dump(informe, fj, ensure_ascii=False, indent=2)
    print(f"\n{C['b']}Informe completo: {ruta}{C['r']}  <- pasaselo a Claude")


def main():
    ap = argparse.ArgumentParser(description="Laboratorio de ruleta europea ficticia")
    ap.add_argument("modo", nargs="?", default="todo", choices=["todo", "entrenar", "estrategias", "optimo"])
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
    ap.add_argument("--salida", default=os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                                     "salida"))
    args = ap.parse_args()
    if os.name == "nt":
        os.system("")  # activa colores ANSI en la consola de Windows
    {"todo": todo, "entrenar": entrenar, "estrategias": estrategias, "optimo": optimo}[args.modo](args)


if __name__ == "__main__":
    main()
