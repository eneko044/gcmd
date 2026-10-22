<# : -------- parte BATCH (PowerShell la ve como un comentario) --------
@echo off
setlocal
title HOLA GENTZANE
mode con: cols=120 lines=40
color 0A
cls
echo.
echo   [*] Iniciando GENTZANE.EXE ...
echo   [*] Compilando motor grafico, espera un segundo...
set "GZ_SELF=%~f0"
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$s=[IO.File]::ReadAllText($env:GZ_SELF); Invoke-Expression $s"
if errorlevel 1 (
    echo.
    echo   [!] Algo ha fallado. Hace falta Windows 10 o superior.
    pause
)
for /f %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
<nul set /p "=%ESC%[0m%ESC%[?25h"
color 07
cls
endlocal
exit /b
#>
# -------- parte POWERSHELL: compila y lanza el motor de animacion --------
$ErrorActionPreference = 'Stop'
$code = @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;

public static class GentzaneShow
{
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool WriteConsoleW(IntPtr h, string s, int n, out int w, IntPtr r);

    const string E = "\u001b[";
    const char FULL = '\u2588', DARK = '\u2593', MED = '\u2592', LIGHT = '\u2591', DOT = '\u00b7';
    const string GLY = "0123456789ABCDEF<>/\\|=+*#$%&@?!{}[]";
    static readonly CultureInfo INV = CultureInfo.InvariantCulture;

    static IntPtr hOut; static bool win; static uint oldMode; static bool hadMode;
    static int W = 120, H = 40;
    static char[] cb; static int[] cc, cbg;
    static char[] tmpC; static int[] tmpF, tmpB;
    static double[] mask;
    static int bg;
    static Random rnd = new Random(1234);
    static StringBuilder sb = new StringBuilder(1 << 17);
    static volatile bool quit;
    static bool dumping;
    static double now;
    static int scene; static double st;

    // ================================================================ arranque
    public static void Run()
    {
        Setup();
        if (!win && Environment.OSVersion.Platform == PlatformID.Win32NT)
        {
            Console.WriteLine("Esta consola no soporta secuencias ANSI (hace falta Windows 10 o superior).");
            return;
        }
        try
        {
            Stopwatch sw = Stopwatch.StartNew();
            double last = 0;
            while (!quit)
            {
                double t = sw.Elapsed.TotalSeconds;
                double dt = Math.Min(0.1, t - last); last = t;
                CheckSize();
                int k = Key();
                if (k >= 0)
                {
                    if (scene < 3) Goto(3);
                    else if (k == (int)ConsoleKey.Escape) break;
                    else if (k == (int)ConsoleKey.Enter) Press();
                }
                Step(dt);
                Present();
                int ms = (int)((1.0 / 30 - (sw.Elapsed.TotalSeconds - t)) * 1000);
                if (ms > 1) Thread.Sleep(ms);
            }
        }
        finally { Restore(); }
    }

    // modo de prueba: simula la animacion y vuelca fotogramas a un fichero
    public static double autoPress = -1;

    public static void Dump(int w, int h, string path, double[] times)
    {
        dumping = true; W = w; H = h; Alloc(); Goto(1);
        using (StreamWriter o = new StreamWriter(path, false, new UTF8Encoding(false)))
        {
            double T = 0, dt = 1.0 / 30; int k = 0;
            while (k < times.Length)
            {
                if (autoPress >= 0 && scene == 3 && st >= autoPress) Press();
                Step(dt); T += dt;
                if (T >= times[k])
                {
                    o.WriteLine("F " + T.ToString("0.00", INV) + " scene=" + scene);
                    for (int y = 0; y < H; y++) o.WriteLine(new string(cb, y * W, W));
                    for (int y = 0; y < H; y++)
                    {
                        StringBuilder l = new StringBuilder();
                        for (int x = 0; x < W; x++) { int i = y * W + x; l.Append(cc[i].ToString("x6")).Append(cbg[i] < 0 ? bg.ToString("x6") : cbg[i].ToString("x6")); }
                        o.WriteLine(l.ToString());
                    }
                    k++;
                }
            }
        }
    }

    static void Setup()
    {
        try
        {
            hOut = GetStdHandle(-11);
            uint m;
            if (GetConsoleMode(hOut, out m))
            {
                oldMode = m; hadMode = true;
                win = SetConsoleMode(hOut, m | 0x0004 | 0x0001);
            }
        }
        catch { win = false; }
        try { Console.CursorVisible = false; } catch { }
        try { Console.CancelKeyPress += OnCancel; } catch { }
        ReadSize(); Alloc();
        Out(E + "?25l" + E + "0m" + E + "2J");
        Goto(1);
    }

    static void OnCancel(object s, ConsoleCancelEventArgs e) { e.Cancel = true; quit = true; }

    static void Restore()
    {
        Out(E + "0m" + E + "2J" + E + "H" + E + "?25h");
        try { Console.CursorVisible = true; } catch { }
        if (hadMode) { try { SetConsoleMode(hOut, oldMode); } catch { } }
    }

    static int Key()
    {
        try { if (Console.KeyAvailable) return (int)Console.ReadKey(true).Key; } catch { }
        return -1;
    }

    static void ReadSize()
    {
        try { W = Math.Max(60, Console.WindowWidth); H = Math.Max(24, Console.WindowHeight); }
        catch { W = 120; H = 40; }
    }

    static void CheckSize()
    {
        int ow = W, oh = H; ReadSize();
        if (ow != W || oh != H) { Alloc(); Out(E + "0m" + E + "2J"); }
    }

    static void Alloc()
    {
        cb = new char[W * H]; cc = new int[W * H]; cbg = new int[W * H]; mask = new double[W * H];
        tmpC = new char[W]; tmpF = new int[W]; tmpB = new int[W];
        rh = new double[W]; rs = new double[W]; rl = new int[W]; rg = new char[W * H];
        for (int x = 0; x < W; x++) { NewDrop(x); rh[x] = -rnd.NextDouble() * H * 1.3; }
        for (int i = 0; i < W * H; i++) rg[i] = Gl();
    }

    static void Goto(int n)
    {
        scene = n; st = 0;
        ps = 0; rate = 1; cine = 0; fxStep = 0; netExit = -1; crashT = -1; pn = 0; nextBurst = 2.0; lastHop = -1; pressT = -1; urlOpened = false;
    }

    static void Step(double dt)
    {
        UpdRain(dt); UpdParts(scene == 2 ? dt * rate : dt);
        bg = 0;
        for (int i = 0; i < cb.Length; i++) { cb[i] = ' '; cc[i] = 0; cbg[i] = -1; }
        if (scene == 1) S1(dt); else if (scene == 2) S2(dt); else S3(dt);
    }

    // ================================================================ salida
    static void Out(string s)
    {
        if (dumping) return;
        if (win)
        {
            int w;
            for (int p = 0; p < s.Length; p += 16000)
                WriteConsoleW(hOut, s.Substring(p, Math.Min(16000, s.Length - p)), Math.Min(16000, s.Length - p), out w, IntPtr.Zero);
        }
        else { Console.Out.Write(s); Console.Out.Flush(); }
    }

    static void Present()
    {
        sb.Length = 0;
        int lf = -1, lb = -1;
        for (int y = 0; y < H; y++)
        {
            sb.Append(E).Append(y + 1).Append(";1H");
            int wm = (y == H - 1) ? W - 1 : W;
            for (int x = 0; x < wm; x++)
            {
                int i = y * W + x;
                int b = cbg[i] < 0 ? bg : cbg[i];
                if (b != lb) { sb.Append(E).Append("48;2;").Append((b >> 16) & 255).Append(';').Append((b >> 8) & 255).Append(';').Append(b & 255).Append('m'); lb = b; }
                char c = cb[i];
                if (c != ' ')
                {
                    int f = cc[i] & 0xF8F8F8;
                    if (f != lf) { sb.Append(E).Append("38;2;").Append((f >> 16) & 255).Append(';').Append((f >> 8) & 255).Append(';').Append(f & 255).Append('m'); lf = f; }
                }
                sb.Append(c);
            }
        }
        Out(sb.ToString());
    }

    // ================================================================ utilidades
    static int Rgb(int r, int g, int b)
    {
        r = r < 0 ? 0 : r > 255 ? 255 : r; g = g < 0 ? 0 : g > 255 ? 255 : g; b = b < 0 ? 0 : b > 255 ? 255 : b;
        return (r << 16) | (g << 8) | b;
    }
    static int Rgb(double r, double g, double b) { return Rgb((int)r, (int)g, (int)b); }
    static int Scale(int c, double f) { return Rgb(((c >> 16) & 255) * f, ((c >> 8) & 255) * f, (c & 255) * f); }
    static int Lerp(int a, int b, double t)
    {
        t = Cl(t);
        return Rgb(((a >> 16) & 255) + (((b >> 16) & 255) - ((a >> 16) & 255)) * t,
                   ((a >> 8) & 255) + (((b >> 8) & 255) - ((a >> 8) & 255)) * t,
                   (a & 255) + ((b & 255) - (a & 255)) * t);
    }
    static double Cl(double v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
    static double Sm(double v) { v = Cl(v); return v * v * (3 - 2 * v); }
    static double Lp(double a, double b, double t) { return a + (b - a) * t; }
    static int Rd(double v) { return (int)Math.Floor(v + 0.5); }
    static int Mod(int a, int m) { int r = a % m; return r < 0 ? r + m : r; }
    static char Gl() { return GLY[rnd.Next(GLY.Length)]; }
    static double Hash(int x, int y, int s)
    {
        unchecked
        {
            uint h = (uint)(x * 374761393 + y * 668265263 + s * 982451653);
            h = (h ^ (h >> 13)) * 1274126177u; h ^= h >> 16;
            return (h & 0xFFFFFF) / 16777216.0;
        }
    }

    // "materializar": lo que se dibuja con esto activo aparece celda a celda como codigo
    static bool rvOn; static double rvStart, rvRow, rvJit; static int rvY0, rvSeed;
    static void RevealOn(double start, int y0, double row, double jit, int seed) { rvOn = true; rvStart = start; rvY0 = y0; rvRow = row; rvJit = jit; rvSeed = seed; }
    static void RevealOff() { rvOn = false; }

    static bool Rv(int x, int y, ref char c, ref int col)
    {
        if (!rvOn) return true;
        double rt = rvStart + (y - rvY0) * rvRow + Hash(x, y, rvSeed) * rvJit;
        if (now < rt - 0.35) return false;
        if (now < rt) { if (c != ' ') c = Gl(); col = Rgb(120, 255, 150); }
        else if (now < rt + 0.3) col = Lerp(Rgb(255, 255, 255), col, (now - rt) / 0.3);
        return true;
    }

    static void Put(int x, int y, char c, int col)
    {
        if (x < 0 || y < 0 || x >= W || y >= H) return;
        if (!Rv(x, y, ref c, ref col)) return;
        int i = y * W + x; cb[i] = c; cc[i] = col;
    }

    static void PutB(int x, int y, char c, int col, int back)
    {
        if (x < 0 || y < 0 || x >= W || y >= H) return;
        if (!Rv(x, y, ref c, ref col)) return;
        int i = y * W + x; cb[i] = c; cc[i] = col; cbg[i] = back;
    }

    static void Text(int x, int y, string s, int col) { for (int i = 0; i < s.Length; i++) Put(x + i, y, s[i], col); }
    static void TextT(int x, int y, string s, int col) { for (int i = 0; i < s.Length; i++) if (s[i] != ' ') Put(x + i, y, s[i], col); }

    static void Shade(int x, int y, double f)
    {
        if (x < 0 || y < 0 || x >= W || y >= H) return;
        int i = y * W + x;
        cc[i] = Scale(cc[i], f);
        cbg[i] = Scale(cbg[i] < 0 ? bg : cbg[i], f);
    }

    // escribe un texto letra a letra; devuelve true cuando ha terminado
    static bool Type(int x, int y, string s, double t0, double cps, int col)
    {
        if (now < t0) return false;
        int n = Math.Min(s.Length, (int)((now - t0) * cps));
        Text(x, y, s.Substring(0, n), col);
        if (n < s.Length) { Put(x + n, y, FULL, col); return false; }
        return true;
    }

    // ================================================================ lluvia matrix
    static double[] rh, rs; static int[] rl; static char[] rg;

    static void NewDrop(int x) { rh[x] = -rnd.NextDouble() * H * 0.5 - 1; rs[x] = 7 + rnd.NextDouble() * 20; rl[x] = 4 + rnd.Next(Math.Max(5, H * 2 / 3)); }

    static void UpdRain(double dt)
    {
        for (int x = 0; x < W; x++) { rh[x] += rs[x] * dt; if (rh[x] - rl[x] > H) NewDrop(x); }
        int n = W * H / 40 + 1;
        for (int k = 0; k < n; k++) rg[rnd.Next(W * H)] = Gl();
    }

    static void DrawRain(double inten, int maxY, bool useMask)
    {
        if (inten <= 0) return;
        for (int x = 0; x < W; x++)
        {
            int hy = (int)Math.Floor(rh[x]); int L = rl[x];
            for (int i = 0; i <= L; i++)
            {
                int y = hy - i;
                if (y < 0) break;
                if (y >= maxY || y >= H) continue;
                int idx = y * W + x;
                double f = useMask ? inten * mask[idx] : inten;
                if (f < 0.03) continue;
                int c;
                if (i == 0) c = Rgb(170 * f, 255 * f, 190 * f);
                else { double k = 1 - (double)i / (L + 1); k *= k; c = Rgb(0, (30 + 225 * k) * f, (8 + 50 * k) * f); }
                cb[idx] = rg[idx]; cc[idx] = c;
            }
        }
    }

    // ================================================================ particulas
    const int PMAX = 700;
    static double[] px = new double[PMAX], py = new double[PMAX], pvx = new double[PMAX], pvy = new double[PMAX], pl = new double[PMAX], pm = new double[PMAX];
    static int[] pc = new int[PMAX], pt = new int[PMAX]; static char[] pch = new char[PMAX]; static int pn;
    static double[] boomX = new double[16], boomY = new double[16]; static int nBoom;
    const string CONF = "*+o~%#&$@";

    static void Spawn(double x, double y, double vx, double vy, double life, int col) { SpawnT(0, x, y, vx, vy, life, col); }

    static void SpawnT(int type, double x, double y, double vx, double vy, double life, int col)
    {
        if (pn >= PMAX) return;
        px[pn] = x; py[pn] = y; pvx[pn] = vx; pvy[pn] = vy; pl[pn] = life; pm[pn] = life; pc[pn] = col;
        pt[pn] = type; pch[pn] = CONF[rnd.Next(CONF.Length)]; pn++;
    }

    static void Burst(double x, double y, int n, double sp, int col)
    {
        for (int k = 0; k < n; k++)
        {
            double a = rnd.NextDouble() * Math.PI * 2, v = sp * (0.35 + 0.65 * rnd.NextDouble());
            Spawn(x, y, Math.Cos(a) * v * 2, Math.Sin(a) * v - sp * 0.25, 0.6 + rnd.NextDouble() * 0.8, col);
        }
    }

    static void UpdParts(double dt)
    {
        nBoom = 0;
        for (int i = 0; i < pn; i++)
        {
            pl[i] -= dt;
            if (pl[i] <= 0)
            {
                if (pt[i] == 4 && nBoom < 16) { boomX[nBoom] = px[i]; boomY[nBoom] = py[i]; nBoom++; }
                pn--; px[i] = px[pn]; py[i] = py[pn]; pvx[i] = pvx[pn]; pvy[i] = pvy[pn]; pl[i] = pl[pn]; pm[i] = pm[pn]; pc[i] = pc[pn];
                pt[i] = pt[pn]; pch[i] = pch[pn]; i--;
                continue;
            }
            double g = pt[i] == 1 ? -6 : pt[i] == 2 ? 4 : pt[i] == 3 ? 22 : pt[i] == 4 ? 0 : 12;
            pvy[i] += g * dt; pvx[i] *= 1 - (pt[i] == 2 ? 1.5 : 0.8) * dt;
            if (pt[i] == 2) { pvy[i] *= 1 - 1.2 * dt; px[i] += Math.Sin(pl[i] * 9 + i) * 6 * dt; }
            px[i] += pvx[i] * dt; py[i] += pvy[i] * dt;
            if (pt[i] == 4) SpawnT(3, px[i], py[i] + 0.5, (rnd.NextDouble() - 0.5) * 3, 2, 0.25, Rgb(255, 200, 80));
        }
        // los cohetes que se acaban explotan
        for (int k = 0; k < nBoom; k++)
        {
            int c = NEON[rnd.Next(NEON.Length)];
            Burst(boomX[k], boomY[k], 45, 13, c);
            for (int j = 0; j < 12; j++) SpawnT(3, boomX[k], boomY[k], (rnd.NextDouble() - 0.5) * 30, (rnd.NextDouble() - 0.5) * 12, 0.4, Rgb(255, 255, 255));
        }
    }

    // fire = true: solo el fuego (va detras del balon); false: todo lo demas
    static void DrawParts(bool fire)
    {
        for (int i = 0; i < pn; i++)
        {
            if ((pt[i] == 1) != fire) continue;
            double f = pl[i] / pm[i];
            int x = (int)Math.Floor(px[i]), y = (int)Math.Floor(py[i]);
            switch (pt[i])
            {
                case 1:
                    Put(x, y, f > 0.75 ? '@' : f > 0.5 ? '*' : f > 0.3 ? '^' : '\'',
                        f > 0.5 ? Lerp(Rgb(255, 110, 0), Rgb(255, 245, 140), (f - 0.5) * 2) : Lerp(Rgb(80, 10, 0), Rgb(255, 110, 0), f * 2));
                    break;
                case 2: Put(x, y, f < 0.15 ? '.' : pch[i], Scale(pc[i], 0.4 + 0.6 * Math.Min(1, f * 3))); break;
                case 3: Put(x, y, f > 0.5 ? '*' : '.', Lerp(Rgb(255, 140, 20), Rgb(255, 255, 220), f)); break;
                case 4: Put(x, y, '|', Rgb(255, 255, 200)); Put(x, y - 1, '^', Rgb(255, 255, 255)); break;
                default:
                    Put(x, y, f > 0.7 ? '*' : f > 0.4 ? '+' : f > 0.2 ? DOT : '.', Scale(pc[i], 0.25 + 0.75 * f));
                    break;
            }
        }
    }

    // anillo en perspectiva (onda expansiva)
    static void Ring(double cx, double cy, double rx, double ry, char c, int col)
    {
        int n = (int)(rx * 7) + 12;
        for (int k = 0; k < n; k++)
        {
            double a = Math.PI * 2 * k / n;
            Put(Rd(cx + rx * Math.Cos(a) - 0.5), Rd(cy + ry * Math.Sin(a) - 0.5), c, col);
        }
    }

    // mueve toda la imagen (temblor de pantalla)
    static void ShiftAll(int dx, int dy)
    {
        if (dx == 0 && dy == 0) return;
        char[] c2 = (char[])cb.Clone(); int[] f2 = (int[])cc.Clone(), b2 = (int[])cbg.Clone();
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x, sx = x - dx, sy = y - dy;
                if (sx >= 0 && sy >= 0 && sx < W && sy < H) { int j = sy * W + sx; cb[i] = c2[j]; cc[i] = f2[j]; cbg[i] = b2[j]; }
                else { cb[i] = ' '; cbg[i] = -1; }
            }
    }

    // ================================================================ efectos
    static void Glitch(double a)
    {
        if (a <= 0.01) return;
        int sh = (int)(a * 16);
        for (int y = 0; y < H; y++)
        {
            if (rnd.NextDouble() >= a * 0.45) continue;
            int s = rnd.Next(-sh - 1, sh + 2);
            int tint = rnd.Next(2) == 0 ? Rgb(255, 0, 90) : Rgb(0, 255, 230);
            for (int x = 0; x < W; x++) { int i = y * W + x; tmpC[x] = cb[i]; tmpF[x] = cc[i]; tmpB[x] = cbg[i]; }
            for (int x = 0; x < W; x++)
            {
                int i = y * W + x, sx = x - s;
                if (sx >= 0 && sx < W) { cb[i] = tmpC[sx]; cc[i] = Lerp(tmpF[sx], tint, 0.5); cbg[i] = tmpB[sx]; }
                else { cb[i] = ' '; cbg[i] = -1; }
            }
        }
        int n = (int)(W * H * a * 0.05);
        for (int k = 0; k < n; k++)
        {
            int i = rnd.Next(W * H);
            cb[i] = Gl(); cc[i] = rnd.Next(2) == 0 ? Rgb(255, 0, 110) : Rgb(0, 255, 220);
        }
        if (rnd.NextDouble() < a * 0.7)
        {
            int y = rnd.Next(H), x0 = rnd.Next(W), len = 6 + rnd.Next(30);
            char ch = rnd.Next(2) == 0 ? MED : LIGHT; int col = rnd.Next(2) == 0 ? Rgb(255, 0, 150) : Rgb(0, 230, 255);
            for (int x = x0; x < x0 + len && x < W; x++) { cb[y * W + x] = ch; cc[y * W + x] = col; }
        }
    }

    static void Hud(string tag)
    {
        int c = Rgb(0, 150, 175), h = Rgb(0, 230, 255);
        string tl = "\u250c\u2500[ GENTZANE.EXE ]\u2500\u2500[ " + tag + " ]";
        Text(0, 0, tl, c);
        Text(4, 0, "GENTZANE.EXE", h);
        string tr = "[ " + DateTime.Now.ToString("HH:mm:ss", INV) + " ]\u2500\u2510";
        Text(W - tr.Length, 0, tr, c);
        int cpu = 90 + (int)(now * 7) % 10;
        string bl = "\u2514\u2500[ CPU " + cpu + "% | MEM 0x" + ((int)(now * 977) & 0xFFFF).ToString("X4") + " | NET: OK ]";
        Text(0, H - 1, bl, c);
        string br = "[ AES-256 :: ONLINE ]\u2500\u2518";
        Text(W - 1 - br.Length, H - 1, br, c);
    }

    // suelo 3D en perspectiva estilo "tron"
    static void DrawFloor(int hz, double reveal, double scroll, int lineCol, int glowCol, int bgNear, int bgFar)
    {
        int vx = W / 2, rows = H - hz;
        if (rows <= 0) return;
        double S = 1.25; int maxN = (int)(W / S) + 2;
        for (int y = Math.Max(0, hz); y < H; y++)
        {
            int ry = y - hz;
            if (ry > reveal * rows) break;
            double f = (double)ry / rows;
            int bgc = Lerp(bgFar, bgNear, Math.Sqrt(f));
            int fg = Scale(Lerp(glowCol, lineCol, Math.Min(1, f * 1.6)), 0.5 + 0.5 * f);
            for (int x = 0; x < W; x++) { int i = y * W + x; cb[i] = ' '; cbg[i] = bgc; }
            if (ry == 0) { for (int x = 0; x < W; x++) { int i = y * W + x; cb[i] = '_'; cc[i] = glowCol; } continue; }
            double za = 48.0 / ry + scroll, zb = 48.0 / (ry + 1) + scroll;
            if (ry == 1 || Math.Floor(za / 3.0) != Math.Floor(zb / 3.0))
                for (int x = 0; x < W; x++) { int i = y * W + x; cb[i] = '_'; cc[i] = Scale(fg, 0.85); }
            if (ry < 2) continue;
            for (int n = -maxN; n <= maxN; n++)
            {
                double xm = vx + n * S * (ry + 0.5);
                if (xm < -1 || xm > W) continue;
                Put(Rd(xm - 0.5), y, n == 0 ? '|' : n < 0 ? '/' : '\\', fg);
            }
        }
    }

    // balon 3D: esfera iluminada con costuras que giran
    static void Ball(double cx, double cy, double R, double rot)
    {
        const double A = 2.0;
        int x0 = (int)Math.Floor(cx - R * A) - 1, x1 = (int)Math.Ceiling(cx + R * A) + 1;
        int y0 = (int)Math.Floor(cy - R) - 1, y1 = (int)Math.Ceiling(cy + R) + 1;
        if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0; if (x1 > W - 1) x1 = W - 1; if (y1 > H - 1) y1 = H - 1;
        double ca = Math.Cos(rot), sa = Math.Sin(rot), cbt = Math.Cos(0.55), sbt = Math.Sin(0.55);
        double sw = Math.Max(0.07, Math.Min(0.16, 0.42 / R));
        const string ramp = "-=+*#%@@";
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                double nx = (x + 0.5 - cx) / (R * A), ny = (y + 0.5 - cy) / R, rr = nx * nx + ny * ny;
                if (rr > 1) continue;
                double nz = Math.Sqrt(1 - rr);
                double dif = Math.Max(0, -0.45 * nx - 0.55 * ny + 0.70 * nz);
                double b = Cl(0.13 + 0.75 * dif + 0.55 * Math.Pow(dif, 22));
                double py2 = ny * ca - nz * sa, pz = ny * sa + nz * ca;
                double qx = nx * cbt - py2 * sbt, qy = nx * sbt + py2 * cbt, qz = pz;
                bool seam = Math.Abs(qx) < sw || Math.Abs(qy) < sw || Math.Abs(Math.Abs(qz) - 0.72) < sw * 0.8;
                char c; int col;
                if (seam) { c = rr > 0.82 ? ':' : '#'; col = Rgb(40 + 40 * b, 14 + 14 * b, 4); }
                else
                {
                    c = ramp[(int)(b * (ramp.Length - 1))];
                    if (rr > 0.8)
                    {
                        if (Math.Abs(ny) < 0.45) c = nx < 0 ? '(' : ')';
                        else if (Math.Abs(nx) < 0.4) c = ny < 0 ? '-' : '_';
                        else c = (nx < 0) == (ny < 0) ? '/' : '\\';
                    }
                    col = Rgb(70 + 185 * b + 60 * Math.Pow(dif, 22), 22 + 110 * b + 90 * Math.Pow(dif, 22), 4 + 25 * b + 60 * Math.Pow(dif, 22));
                }
                Put(x, y, c, col);
            }
    }

    static void BallShadow(double cx, int gy, double R, double height)
    {
        double k = Cl(1 - height / 16.0);
        double hw = R * 2 * (0.6 + 0.5 * k);
        for (int x = (int)Math.Floor(cx - hw); x <= (int)Math.Ceiling(cx + hw); x++)
        {
            double d = Math.Abs(x + 0.5 - cx) / hw;
            if (d > 1) continue;
            Shade(x, gy, 1 - 0.85 * k * (1 - d * d));
        }
    }

    // ================================================================ ESCENA 1: hackeo
    static void S1(double dt)
    {
        st += dt; now = st;
        DrawRain(Math.Min(0.6, st * 0.35), H, false);

        int bw = Math.Min(W - 6, 70), bh = 10;
        int bx = (W - bw) / 2, by = Math.Max(2, (H - bh) / 2 - 1);
        double open = Sm(st / 0.5);
        int cw = Math.Max(2, (int)(bw * open)), cx0 = bx + (bw - cw) / 2;
        int g = Rgb(0, 255, 120), gd = Rgb(0, 170, 80), wh = Rgb(220, 255, 230);
        for (int y = by; y < by + bh; y++)
            for (int x = cx0; x < cx0 + cw; x++)
            {
                char c = ' ';
                bool top = y == by, bot = y == by + bh - 1, l = x == cx0, r = x == cx0 + cw - 1;
                if (top && l) c = '\u2554'; else if (top && r) c = '\u2557'; else if (bot && l) c = '\u255a'; else if (bot && r) c = '\u255d';
                else if (top || bot) c = '\u2550'; else if (l || r) c = '\u2551';
                PutB(x, y, c, gd, Rgb(0, 14, 6));
            }
        if (open < 1) return;
        Text(bx + 3, by, " root@gentzane:~ ", g);
        Text(bx + bw - 12, by, " [ - x ] ", gd);

        int tx = bx + 3, ty = by + 2, lw = bw - 6;
        string ok = " [ OK ]";
        string l1 = "> estableciendo conexion cifrada "; l1 = l1.PadRight(lw - ok.Length, '.');
        string l2 = "> saltando firewall "; l2 = l2.PadRight(lw - ok.Length, '.');
        Type(tx, ty, "> ssh root@gentzane.mainframe -p 31337", 0.6, 45, g);
        if (Type(tx, ty + 1, l1, 1.5, 70, g) && now > 2.3) Text(tx + l1.Length, ty + 1, ok, wh);
        if (Type(tx, ty + 2, l2, 2.4, 70, g) && now > 3.1) Text(tx + l2.Length, ty + 2, ok, wh);
        if (Type(tx, ty + 3, "> descifrando claves ", 3.2, 60, g))
        {
            double p = Cl((now - 3.6) / 1.3);
            int bl = lw - 28, fill = (int)(bl * p);
            int x = tx + 21;
            Put(x, ty + 3, '[', g);
            for (int k = 0; k < bl; k++) Put(x + 1 + k, ty + 3, k < fill ? FULL : LIGHT, k < fill ? g : gd);
            Put(x + 1 + bl, ty + 3, ']', g);
            Text(x + 3 + bl, ty + 3, ((int)(p * 100)).ToString().PadLeft(3) + "%", wh);
        }
        if (now > 5.0)
        {
            bool blink = ((int)(now * 6)) % 2 == 0;
            Text(tx, ty + 4, "> ", g);
            Text(tx + 2, ty + 4, "*** ACCESO CONCEDIDO ***", blink ? Rgb(255, 255, 255) : Rgb(0, 255, 140));
        }
        Type(tx, ty + 5, "> cargando modulo baloncesto_3d.dll ...", 5.5, 50, g);

        Hud("HACK");
        if (st > 6.4) Glitch((st - 6.4) / 0.5);
        if (st > 6.9) Goto(2);
    }

    // ================================================================ ESCENA 2: canasta 3D
    static double ps, rate, netExit, crashT;
    static int hcx, bdy, fr, bot, rimY, rimA, netTop, netRows, hz, gH, gN, startX;
    static double R0, R1, fx0, fy0, fxT, fyT, fvx, fvy, fg, ftf, tLand, xLand;
    const double T_SHOT = 6.4, KNET = 20;

    static void Layout2()
    {
        hcx = W * 3 / 4;
        bdy = H >= 34 ? 3 : 2;
        fr = H >= 38 ? 8 : (H >= 32 ? 7 : 6);
        bot = bdy + 3 + fr - 1;
        rimY = bot + 3; rimA = H >= 34 ? 12 : 11;
        netTop = rimY + 2; netRows = H >= 36 ? 6 : 4;
        hz = Math.Max(H - 11, netTop + netRows + 1);
        gH = hz + 3; gN = H - 2;
        startX = Math.Max(12, W / 7);
        R0 = H >= 36 ? 3.2 : 2.6; R1 = H >= 36 ? 2.2 : 1.8;
        // tiro parabolico que pasa por el centro del aro
        ftf = 1.5;
        fx0 = startX; fy0 = gN - R0 - 3;
        fyT = rimY - 0.3;
        double ya = bdy + 1.5;
        fvx = 0; fxT = hcx - 0.5;
        double a = 0.5 * ftf * ftf, b = Math.Sqrt(2 * (fy0 - ya)) * ftf, c = fy0 - fyT;
        double sq = Math.Sqrt(Math.Max(0, b * b - 4 * a * c)) , s = (b + sq) / (2 * a);
        fg = s * s; fvy = -Math.Sqrt(2 * fg * (fy0 - ya));
        fvx = (fxT - fx0) / ftf; fxT -= fvx / KNET; fvx = (fxT - fx0) / ftf;
        double vyT = fvy + fg * ftf, dy = (gH - R1) - fyT;
        double tf2 = (-vyT + Math.Sqrt(vyT * vyT + 2 * fg * dy)) / fg;
        tLand = T_SHOT + ftf + tf2;
        xLand = fxT + fvx / KNET * (1 - Math.Exp(-KNET * tf2));
    }

    static double RAt(double d) { return d >= 0 ? Lp(R0, R1, d) : R0 * Math.Pow(1 + 1.6 * -d, 2); }
    static double GAt(double d) { return Lp(gN, gH, d); }

    static readonly double[] bT = { 0, 0.8, 1.45, 2.3 };
    static readonly double[] bD = { 1, 0.55, 0.05, -1.8 };
    static readonly double[] bHt = { 8, 6, 9 };

    // devuelve la fase: 0 nada, 1 bote, 2 vuelo, 3 cae por la red, 4 rebota hacia la camara
    static int BallAt(double s, out double x, out double y, out double R, out double rot, out double d)
    {
        x = fx0; y = gN - R0; R = R0; rot = s * 2; d = 0;
        if (s < 2.8) return 0;
        if (s < T_SHOT)
        {
            double rest = gN - R0;
            if (s < 3.3) y = rest;
            else if (s < 5.5) y = rest - 4.5 * Math.Abs(Math.Sin(Math.PI * (s - 3.3) / 0.55));
            else y = Lp(rest, fy0, Sm((s - 5.5) / 0.9));
            return 1;
        }
        double t = s - T_SHOT;
        if (t < ftf)
        {
            x = fx0 + fvx * t; y = fy0 + fvy * t + 0.5 * fg * t * t;
            d = (x - fx0) / (fxT - fx0); R = RAt(d); rot = T_SHOT * 2 + t * 10;
            return 2;
        }
        if (s < tLand)
        {
            double u = t - ftf;
            x = fxT + fvx / KNET * (1 - Math.Exp(-KNET * u));
            y = fyT + (fvy + fg * ftf) * u + 0.5 * fg * u * u;
            d = 1; R = R1; rot = T_SHOT * 2 + ftf * 10 + u * 4;
            return 3;
        }
        double tau = s - tLand;
        int k = 0;
        while (k < 2 && tau > bT[k + 1]) k++;
        double v = Cl((tau - bT[k]) / (bT[k + 1] - bT[k]));
        double[] bx = { xLand, hcx - 22, W * 0.5 + 8, W * 0.5 };
        d = Lp(bD[k], bD[k + 1], v); R = RAt(d);
        x = Lp(bx[k], bx[k + 1], Sm(v));
        double hgt = bHt[k] * 4 * v * (1 - v) * (k == 2 ? 1 : R / R1 * 0.8);
        y = GAt(d) - R - hgt;
        rot = T_SHOT * 2 + ftf * 10 + tau * 6;
        return 4;
    }

    static void DrawPole()
    {
        for (int y = rimY - 1; y < netTop + netRows + 1; y++)
        {
            int hw = y <= netTop ? rimA : rimA - (y - netTop) - 1;
            for (int x = hcx - hw; x < hcx + hw; x++) Put(x, y, ' ', 0);
        }
        int a = Rgb(130, 135, 150), b2 = Rgb(85, 90, 105), c = Rgb(50, 52, 62);
        for (int y = bot + 1; y < gH; y++) { Put(hcx + 4, y, FULL, a); Put(hcx + 5, y, DARK, b2); Put(hcx + 6, y, MED, c); }
        for (int x = hcx; x <= hcx + 10; x++) PutB(x, gH, x == hcx || x == hcx + 10 ? '/' : '_', a, Rgb(40, 42, 50));
    }

    static double boardFlash;

    static void DrawBoard()
    {
        int bw = 34, bx = hcx - 18, by = bdy;
        int frame = Lerp(Rgb(225, 232, 245), Rgb(255, 215, 60), boardFlash), side = Rgb(120, 128, 145), sideBg = Rgb(26, 28, 36), glass = Rgb(8, 14, 24), streak = Rgb(55, 105, 135), topBg = Rgb(38, 42, 54);
        for (int x = bx + 3; x <= bx + bw + 1; x++) Put(x, by, '_', frame);
        Put(bx + 2, by + 1, '/', frame);
        for (int x = bx + 3; x <= bx + bw; x++) PutB(x, by + 1, ' ', frame, topBg);
        Put(bx + bw + 1, by + 1, '/', frame); Put(bx + bw + 2, by + 1, '|', frame);
        Put(bx + 1, by + 2, '/', frame);
        for (int x = bx + 2; x <= bx + bw - 1; x++) PutB(x, by + 2, '_', frame, topBg);
        Put(bx + bw, by + 2, '/', frame); PutB(bx + bw + 1, by + 2, MED, side, sideBg); Put(bx + bw + 2, by + 2, '|', frame);
        for (int y = by + 3; y < bot; y++)
        {
            Put(bx + 1, y, '|', frame);
            for (int x = bx + 2; x <= bx + bw - 1; x++)
            {
                int d = (x - bx) - (bot - y);
                PutB(x, y, d == 4 || d == 6 || d == 7 || d == 24 ? '/' : ' ', streak, glass);
            }
            Put(bx + bw, y, '|', frame); PutB(bx + bw + 1, y, MED, side, sideBg); Put(bx + bw + 2, y, '|', frame);
        }
        Put(bx + 1, bot, '|', frame);
        for (int x = bx + 2; x <= bx + bw - 1; x++) PutB(x, bot, '_', frame, glass);
        Put(bx + bw, bot, '|', frame); Put(bx + bw + 1, bot, '/', frame);
        // cuadrado del tablero
        int sqc = Lerp(Rgb(255, 90, 40), Rgb(255, 255, 160), boardFlash), l = hcx - 8, r = hcx + 7;
        for (int x = l + 1; x < r; x++) { Put(x, bot - 4, '_', sqc); Put(x, bot - 1, '_', sqc); }
        for (int y = bot - 3; y <= bot - 1; y++) { Put(l, y, '|', sqc); Put(r, y, '|', sqc); }
        // soporte del aro
        Put(hcx - 1, bot + 1, '|', Rgb(170, 175, 190)); Put(hcx, bot + 1, '|', Rgb(170, 175, 190));
    }

    static void DrawRimBack(int col)
    {
        string s = ".-" + new string('~', 2 * rimA - 6) + "-.";
        Text(hcx - rimA + 1, rimY - 1, s, col);
    }

    static void DrawRimFront(int col)
    {
        Put(hcx - rimA, rimY, '(', col); Put(hcx + rimA - 1, rimY, ')', col);
        string s = "'-." + new string('_', 2 * rimA - 8) + ".-'";
        Text(hcx - rimA + 1, rimY + 1, s, col);
    }

    static void DrawNet(int rows, double sway, double bulgeY, double bulge, int col)
    {
        double cx = hcx - 0.5;
        int inner = Scale(col, 0.7);
        for (int r = 0; r < rows; r++)
        {
            int y = netTop + r;
            double shift = sway * Math.Sin(r * 0.8) * (r + 1) / rows;
            double hw = (rimA - 2) - r;
            if (bulge > 0) hw += bulge * Math.Exp(-Math.Pow((y - bulgeY) / 1.6, 2));
            int xl = Rd(cx - hw + shift), xr = Rd(cx + hw + shift) - 1;
            int so = Rd(shift);
            for (int x = xl + 1; x < xr; x++)
            {
                Put(x, y, Mod(x - so - r, 2) == 0 ? '\\' : '/', inner);
            }
            Put(xl, y, '\\', col); Put(xr, y, '/', col);
        }
    }

    static readonly string[] SWISH = {
        " ___ __      __ ___ ___ _  _ _ ",
        "/ __|\\ \\    / /|_ _/ __| || | |",
        "\\__ \\ \\ \\/\\/ /  | |\\__ \\ __ |_|",
        "|___/  \\_/\\_/  |___|___/_||_(_)" };

    static void S2(double dt)
    {
        st += dt; ps += dt * rate; double s = ps; now = s;
        Layout2();
        DrawRain(0.3, hz, false);
        DrawFloor(hz, Cl(s / 1.4), 0, Rgb(0, 170, 255), Rgb(0, 255, 220), Rgb(0, 8, 22), Rgb(0, 40, 60));

        double bx, by, R, rot, d;
        int ph = BallAt(s, out bx, out by, out R, out rot, out d);
        double tSw = T_SHOT + ftf, eS = s - tSw;
        double flash = (s > tSw && s < tSw + 0.25) ? 1 - (s - tSw) / 0.25 : 0;
        boardFlash = eS > 0 && eS < 0.8 ? (1 - eS / 0.8) * (0.6 + 0.4 * Math.Sin(eS * 40)) : 0;
        if (eS > 0 && eS < 0.3) bg = Lerp(Rgb(90, 70, 0), 0, eS / 0.3);
        netRainbow = eS > 0 && eS < 1.2 ? eS : -1;
        int rimF = Lerp(Rgb(255, 100, 30), Rgb(255, 255, 255), flash), rimB = Lerp(Rgb(165, 55, 20), Rgb(255, 230, 200), flash);
        int netC = netRainbow >= 0 ? Neon(netRainbow * 2) : Lerp(Rgb(215, 215, 228), Rgb(255, 255, 255), flash);

        // red: se estira con el balon y luego se balancea
        int rows = netRows; double bulge = 0, sway = 0;
        if (ph == 3 && by > netTop - 2)
        {
            if (by < netTop + netRows + 1) { rows = netRows + 2; bulge = 1.8; }
            else if (netExit < 0) netExit = s;
        }
        if (netExit >= 0) { double e = s - netExit; sway = 2.5 * Math.Exp(-e * 2.2) * Math.Sin(e * 13); if (e < 0.25) rows = netRows + 1; }
        if (ph >= 4 && netExit < 0) netExit = s;

        bool hoop = s > 0.8;
        if (hoop) { RevealOn(0.8, bdy, 0.07, 0.45, 7); DrawPole(); DrawBoard(); DrawRimBack(rimB); RevealOff(); }

        bool front = ph == 4 || ph == 1;
        if (ph >= 1)
        {
            double hgt = GAt(d) - (by + R);
            if (ph < 4 || d > -0.2) BallShadow(bx, (int)Math.Round(GAt(d)), R, hgt);
            // estela de fuego del balon
            if (ph == 2 || (ph == 3 && by < netTop))
                for (int k = 0; k < 5; k++)
                {
                    double a = rnd.NextDouble() * Math.PI * 2, rr = Math.Sqrt(rnd.NextDouble()) * 0.9;
                    SpawnT(1, bx + Math.Cos(a) * R * 2 * rr, by + Math.Sin(a) * R * rr, -fvx * 0.15 + (rnd.NextDouble() - 0.5) * 6, (rnd.NextDouble() - 0.5) * 3, 0.3 + rnd.NextDouble() * 0.35, 0);
                }
            if (ph == 2)
                for (int k = 6; k >= 1; k--)
                {
                    double tt = s - T_SHOT - k * 0.035;
                    if (tt < 0) continue;
                    double tx = fx0 + fvx * tt, ty = fy0 + fvy * tt + 0.5 * fg * tt * tt;
                    Put(Rd(tx), Rd(ty), k < 3 ? 'o' : DOT, Scale(Rgb(255, 120, 20), 0.9 - k * 0.12));
                }
        }
        DrawParts(true);
        if (ph >= 1 && !front) { RevealOn(2.8, 0, 0, 0.5, 3); Ball(bx, by, R, rot); RevealOff(); }
        if (hoop) { RevealOn(0.8, bdy, 0.07, 0.45, 7); DrawRimFront(rimF); DrawNet(rows, sway, by, bulge, netC); RevealOff(); }
        if (ph >= 1 && front) { RevealOn(2.8, 0, 0, 0.5, 3); Ball(bx, by, R, rot); RevealOff(); }

        // ---- efectos de la canasta
        if (eS >= 0 && fxStep == 0)
        {
            fxStep = 1;
            for (int k = 0; k < 50; k++)
            {
                double a = Math.PI * 2 * rnd.NextDouble(), v = 8 + rnd.NextDouble() * 16;
                SpawnT(3, hcx - 0.5 + Math.Cos(a) * rimA, rimY + Math.Sin(a) * 1.2, Math.Cos(a) * v * 2, Math.Sin(a) * v - 6, 0.5 + rnd.NextDouble() * 0.5, 0);
            }
            for (int side = -1; side <= 1; side += 2)
                for (int k = 0; k < 55; k++)
                    SpawnT(2, hcx - 0.5 + side * (rimA + 1), rimY, side * (4 + rnd.NextDouble() * 22), -(10 + rnd.NextDouble() * 16), 1.6 + rnd.NextDouble() * 1.2, NEON[rnd.Next(NEON.Length)]);
        }
        double[] rocketT = { 0.05, 0.3, 0.55, 0.8 };
        double[] rocketX = { 0.12, 0.42, 0.62, 0.95 };
        while (fxStep >= 1 && fxStep <= 4 && eS >= rocketT[fxStep - 1])
        {
            double sy0 = hz + 2, ty0 = 3 + rnd.Next(Math.Max(1, hz / 3)), v = 30;
            SpawnT(4, W * rocketX[fxStep - 1], sy0, 0, -v, (sy0 - ty0) / v, 0);
            fxStep++;
        }
        if (eS > 0 && eS < 1.0)
        {
            double r1 = eS * 50, r2 = (eS - 0.12) * 50;
            Ring(hcx - 0.5, rimY, r1, r1 * 0.22, 'o', Lerp(Rgb(255, 255, 255), Rgb(0, 200, 255), eS));
            if (r2 > 0) Ring(hcx - 0.5, rimY, r2, r2 * 0.22, DOT, Lerp(Rgb(255, 230, 120), Rgb(255, 0, 150), eS));
        }
        DrawParts(false);
        // +2 que sube flotando
        if (eS > 0 && eS < 1.6)
        {
            int c2 = Lerp(Rgb(255, 255, 255), Rgb(255, 210, 0), eS * 3);
            if (eS > 1.2) c2 = Scale(c2, 1 - (eS - 1.2) / 0.4);
            int px2 = hcx + rimA + 3, py2 = rimY - 2 - (int)(eS * 5);
            for (int k = 0; k < 6; k++) Put(px2 + k, py2 + 2, FULL, c2);
            for (int k = 0; k < 5; k++) { Put(px2 + 2, py2 + k, FULL, c2); Put(px2 + 3, py2 + k, FULL, c2); }
            string[] dg2 = DIG[2].Split('|');
            for (int r = 0; r < 5; r++)
                for (int k = 0; k < 3; k++)
                    if (dg2[r][k] == '#') { Put(px2 + 8 + k * 2, py2 + r, FULL, c2); Put(px2 + 9 + k * 2, py2 + r, FULL, c2); }
        }

        // trayectoria calculada
        if (s > 4.8 && s < T_SHOT + 0.6)
        {
            int n = 46, vis = (int)(n * Cl((s - 4.8) / 1.1));
            double fade = s > T_SHOT ? 1 - (s - T_SHOT) / 0.6 : 1;
            for (int k = 0; k < vis; k++)
            {
                double tt = ftf * k / (n - 1);
                if (s > T_SHOT && tt < s - T_SHOT) continue;
                double tx = fx0 + fvx * tt, ty = fy0 + fvy * tt + 0.5 * fg * tt * tt;
                Put(Rd(tx), Rd(ty), k % 5 == 0 ? '+' : DOT, Scale(Rgb(0, 210, 255), fade * (0.6 + 0.4 * Math.Sin(k * 0.5 - s * 8))));
            }
        }
        // mira de objetivo
        if (s > 5.3 && s < T_SHOT + 0.9 && ((int)(s * 8)) % 2 == 0)
        {
            int rc = Rgb(255, 40, 70), l = hcx - rimA - 3, r = hcx + rimA + 2, t = rimY - 3, b = rimY + 3;
            Text(l, t, "\u250c\u2500", rc); Text(r - 1, t, "\u2500\u2510", rc); Text(l, b, "\u2514\u2500", rc); Text(r - 1, b, "\u2500\u2518", rc);
            Text(r + 2, t, "TARGET LOCK", rc);
        }
        // SWISH!
        if (s > tSw && s < tSw + 2.2)
        {
            double e = s - tSw;
            int sx = hcx - 18 - SWISH[0].Length - 4, sy = bdy + 5;
            double fade = e > 1.7 ? 1 - (e - 1.7) / 0.5 : 1;
            int sw = SWISH[0].Length; double half = sw / 2.0, open = Cl(e / 0.18);
            for (int y = sy - 2; y <= sy + 6; y++)
                for (int x = sx - 2; x < sx + sw + 2; x++) Put(x, y, ' ', 0);
            for (int j = 0; j < sw; j++)
            {
                if (Math.Abs(j + 0.5 - half) > open * half + 0.5) continue;
                int yo = e > 0.18 && e < 1.6 ? Rd(Math.Sin(e * 9) * 0.7) : 0;
                int col = e < 0.2 ? Rgb(255, 255, 255) : Lerp(Neon(j * 0.025 - e * 1.2), Rgb(255, 255, 255), Math.Max(0, 0.5 - e));
                col = Scale(col, fade);
                for (int i = 0; i < SWISH.Length; i++)
                    if (SWISH[i][j] != ' ') Put(sx + j, sy + i + yo, SWISH[i][j], col);
            }
            if (e > 0.25 && ((int)(e * 10)) % 2 == 0)
            {
                Put(sx - 2, sy - 1, '*', Rgb(255, 255, 160)); Put(sx + sw + 1, sy + 4, '*', Rgb(255, 255, 160));
                Put(sx + sw + 1, sy - 1, '+', Rgb(255, 255, 255)); Put(sx - 2, sy + 4, '+', Rgb(255, 255, 255));
            }
            TextT(sx + 1, sy + 5, "+2 PUNTOS // CANASTA LIMPIA", Scale(Lerp(Rgb(255, 255, 255), Rgb(0, 255, 150), e), fade));
        }

        // registro de la izquierda
        int lg = Rgb(0, 230, 130), lw = Rgb(220, 255, 235);
        Type(2, 2, "> render3d --escena=cancha", 0.1, 45, lg);
        if (Type(2, 3, "> cargando canasta.obj ......", 0.9, 45, lg) && now > 2.6) Text(31, 3, "[ OK ]", lw);
        if (Type(2, 4, "> spawn balon.obj ...........", 2.7, 45, lg) && now > 3.4) Text(31, 4, "[ OK ]", lw);
        if (s > 4.6)
        {
            bool done = s > 6.0;
            string v0 = done ? "8.42" : (5 + rnd.NextDouble() * 5).ToString("0.00", INV);
            string an = done ? "52.0" : (30 + rnd.NextDouble() * 40).ToString("0.0", INV);
            Text(2, 5, "> trayectoria: v0=" + v0 + " m/s  ang=" + an, done ? lw : lg);
        }
        if (s > T_SHOT - 0.1 && s < tSw && ((int)(s * 6)) % 2 == 0) Text(2, 6, "> LANZANDO...", Rgb(255, 200, 0));
        if (s > tSw) Type(2, 6, "> resultado: CANASTA (+2)    ", tSw, 40, Rgb(0, 255, 150));

        // marcador
        if (s > 1.5 && W >= 100)
        {
            int score = eS < 0 ? 0 : eS < 0.35 ? rnd.Next(6) : 2;
            double sf = eS > 0 && eS < 0.9 ? 1 - eS / 0.9 : 0;
            RevealOn(1.5, 8, 0.05, 0.4, 19);
            Scoreboard(2, 8, score, sf, s);
            RevealOff();
        }

        if (eS > 0 && eS < 0.4)
        {
            double k = 1 - eS / 0.4;
            ShiftAll(Rd(Math.Sin(eS * 120) * 2 * k), Rd(Math.Cos(eS * 97) * k));
        }

        Hud("3D MODE");

        // camara lenta al pasar por el aro, con bandas de cine
        rate = ((ph == 2 && s > tSw - 0.18) || ph == 3) ? 0.25 : 1;
        cine += ((rate < 1 ? 1 : 0) - cine) * Math.Min(1, dt * 7);
        int bars = Rd(cine * 3);
        for (int y = 0; y < bars; y++)
            for (int x = 0; x < W; x++) { PutB(x, y, ' ', 0, 0); PutB(x, H - 1 - y, ' ', 0, 0); }
        if (bars >= 2)
        {
            Text(2, 0, ((int)(st * 3)) % 2 == 0 ? "(*) REC" : "( ) REC", Rgb(255, 50, 50));
            string sm = "S L O W   M O T I O N   x0.25";
            Text((W - sm.Length) / 2, H - 2, sm, Rgb(230, 230, 230));
        }
        if (st < 0.4) Glitch((0.4 - st) * 2);
        // el balon "choca" contra la pantalla
        if (ph == 4 && R > H * 0.8 && crashT < 0) crashT = s;
        if (crashT >= 0)
        {
            double e = s - crashT;
            bg = Lerp(Rgb(255, 255, 255), 0, e / 0.35);
            Glitch(Math.Min(1, 0.4 + e * 2));
            if (e > 0.6) Goto(3);
        }
    }

    static double cine, netRainbow = -1; static int fxStep;

    static void Scoreboard(int x, int y, int score, double flash, double t)
    {
        int w = 20, h = 8, fr2 = Rgb(0, 160, 200), led = Lerp(Rgb(255, 40, 40), Rgb(255, 255, 255), flash), off = Rgb(55, 8, 8);
        for (int r = 0; r < h; r++)
            for (int c = 0; c < w; c++)
            {
                bool t0 = r == 0, b0 = r == h - 1, l0 = c == 0, r0 = c == w - 1;
                char ch = t0 && l0 ? '\u2554' : t0 && r0 ? '\u2557' : b0 && l0 ? '\u255a' : b0 && r0 ? '\u255d' : t0 || b0 ? '\u2550' : l0 || r0 ? '\u2551' : ' ';
                PutB(x + c, y + r, ch, fr2, Rgb(4, 6, 12));
            }
        Text(x + 5, y, " MARCADOR ", Rgb(0, 230, 255));
        string[] d0 = DIG[0].Split('|'), d1 = DIG[Math.Min(5, score)].Split('|');
        for (int r = 0; r < 5; r++)
            for (int k = 0; k < 3; k++)
            {
                int c0 = d0[r][k] == '#' ? led : off, c1 = d1[r][k] == '#' ? led : off;
                Put(x + 3 + k * 2, y + 2 + r, FULL, c0); Put(x + 4 + k * 2, y + 2 + r, FULL, c0);
                Put(x + 11 + k * 2, y + 2 + r, FULL, c1); Put(x + 12 + k * 2, y + 2 + r, FULL, c1);
            }
    }

    // ================================================================ ESCENA 3: HOLA GENTZANE
    // fuente "ANSI Shadow":  # = bloque,  7 F L J = esquinas,  = y | = lineas dobles
    static readonly string[] FH = { "##7  ##7", "##|  ##|", "#######|", "##F==##|", "##|  ##|", "L=J  L=J" };
    static readonly string[] FO = { " ######7 ", "##F===##7", "##|   ##|", "##|   ##|", "L######FJ", " L=====J " };
    static readonly string[] FL = { "##7     ", "##|     ", "##|     ", "##|     ", "#######7", "L======J" };
    static readonly string[] FA = { " #####7 ", "##F==##7", "#######|", "##F==##|", "##|  ##|", "L=J  L=J" };
    static readonly string[] FG = { " ######7 ", "##F====J ", "##|  ###7", "##|   ##|", "L######FJ", " L=====J " };
    static readonly string[] FE = { "#######7", "##F====J", "#####7  ", "##F==J  ", "#######7", "L======J" };
    static readonly string[] FN = { "###7   ##7", "####7  ##|", "##F##7 ##|", "##|L##7##|", "##| L####|", "L=J  L===J" };
    static readonly string[] FT = { "########7", "L==##F==J", "   ##|   ", "   ##|   ", "   ##|   ", "   L=J   " };
    static readonly string[] FZ = { "#######7", "L==###FJ", "  ###FJ ", " ###FJ  ", "#######7", "L======J" };

    static string[] Glyph(char c)
    {
        switch (c)
        {
            case 'H': return FH; case 'O': return FO; case 'L': return FL; case 'A': return FA; case 'G': return FG;
            case 'E': return FE; case 'N': return FN; case 'T': return FT; default: return FZ;
        }
    }

    static char MapCh(char c)
    {
        switch (c)
        {
            case '#': return FULL; case '7': return '\u2557'; case 'F': return '\u2554'; case 'L': return '\u255a';
            case 'J': return '\u255d'; case '=': return '\u2550'; case '|': return '\u2551'; default: return c;
        }
    }

    static int WordW(string w) { int n = 0; foreach (char c in w) n += Glyph(c)[0].Length; return n; }

    static readonly int[] NEON = { Rgb(0, 255, 120), Rgb(0, 230, 255), Rgb(130, 90, 255), Rgb(255, 0, 200), Rgb(255, 150, 0) };
    static int Neon(double p)
    {
        p -= Math.Floor(p); p *= NEON.Length;
        int i = (int)p; return Lerp(NEON[i], NEON[(i + 1) % NEON.Length], p - i);
    }

    static double nextBurst; static int lastHop;

    static void DrawWord(string word, int left, int top, double t0, double t, int seed, int flashLetter, double flashAmt)
    {
        int ox = left, total = WordW(word);
        for (int li = 0; li < word.Length; li++)
        {
            string[] gl = Glyph(word[li]);
            for (int r = 0; r < 6; r++)
                for (int k = 0; k < gl[r].Length; k++)
                {
                    char raw = gl[r][k];
                    if (raw == ' ') continue;
                    int x = ox + k, y = top + r;
                    double rt = t0 + (double)(x - left) / total * 1.4 + Hash(x, y, seed) * 0.6;
                    if (t < rt - 0.5) continue;
                    char c = MapCh(raw);
                    bool block = raw == '#';
                    int col = Neon(x * 0.012 + y * 0.035 - t * 0.22);
                    if (!block) col = Lerp(Scale(col, 0.45), Rgb(0, 40, 60), 0.35);
                    double swp = ((t - 3.0) % 4.5) * (W + 60) / 1.3 - 30;
                    double sd = Math.Abs(x + (y - top) * 2 - swp);
                    if (t > 3.0 && sd < 4) col = Lerp(col, Rgb(255, 255, 255), (1 - sd / 4) * (block ? 0.85 : 0.4));
                    if (li == flashLetter && flashAmt > 0) col = Lerp(col, Rgb(255, 255, 255), flashAmt);
                    if (t < rt) { c = Gl(); col = Rgb(110, 255, 150); }
                    else if (t < rt + 0.4) col = Lerp(Rgb(255, 255, 255), col, (t - rt) / 0.4);
                    Put(x, y, c, col);
                }
            ox += gl[0].Length;
        }
    }

    static void S3(double dt)
    {
        st += dt; now = st; double t = st;
        int fz = H - 8;
        int w1 = WordW("HOLA"), w2 = WordW("GENTZANE");
        int l1 = (W - w1) / 2, l2 = (W - w2) / 2;
        int top1 = Math.Max(5, (fz - 19) / 2 + 4), top2 = top1 + 7, subY = top2 + 8;

        // atenua la lluvia detras del texto
        int mx0 = l2 - 3, mx1 = l2 + w2 + 3, my0 = top1 - 4, my1 = subY + 1;
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                double dx = Math.Max(0, Math.Max(mx0 - x, x - mx1)) / 2.0, dy = Math.Max(0, Math.Max(my0 - y, y - my1));
                mask[y * W + x] = 0.1 + 0.9 * Cl(Math.Sqrt(dx * dx + dy * dy) / 5);
            }
        DrawRain(0.9, fz, true);
        DrawFloor(fz, Cl(t / 0.8), t * 5, Rgb(190, 0, 255), Rgb(255, 60, 200), Rgb(10, 0, 22), Rgb(55, 0, 60));

        // fuegos artificiales de caracteres
        if (t > nextBurst)
        {
            nextBurst = t + 0.45 + rnd.NextDouble() * 0.5;
            double bx = rnd.Next(2) == 0 ? rnd.Next(2, Math.Max(3, l2 - 4)) : rnd.Next(Math.Min(W - 3, l2 + w2 + 4), W - 2);
            if (rnd.Next(3) == 0) bx = rnd.Next(4, W - 4);
            Burst(bx, 2 + rnd.Next(Math.Max(1, fz - 6)), 28, 9, NEON[rnd.Next(NEON.Length)]);
        }
        DrawParts(false);

        // balon botando sobre las letras de HOLA
        int flash = -1; double flashAmt = 0;
        if (t > 3.3)
        {
            double R = H >= 34 ? 1.8 : 1.5, rest = top1 - R - 0.1;
            double[] cxs = new double[4]; int ox = l1;
            for (int i = 0; i < 4; i++) { int gw = Glyph("HOLA"[i])[0].Length; cxs[i] = ox + (gw - 1) / 2.0; ox += gw; }
            int[] seq = { 0, 1, 2, 3, 2, 1 };
            double bxp, byp, rot = t * 5;
            if (t < 3.8) { bxp = cxs[0]; byp = Lp(-R - 2, rest, Math.Pow((t - 3.3) / 0.5, 2)); }
            else
            {
                double hp = 0.55, ht = (t - 3.8) / hp; int k = (int)ht; double u = ht - k;
                int from = seq[k % 6], to = seq[(k + 1) % 6];
                double jump = Math.Min(3.5, rest - R - 1);
                bxp = Lp(cxs[from], cxs[to], u); byp = rest - jump * 4 * u * (1 - u);
                if (u < 0.3) { flash = from; flashAmt = 1 - u / 0.3; }
                if (k != lastHop) { lastHop = k; Burst(cxs[from], top1, 10, 5, Rgb(255, 170, 40)); }
            }
            Ball(bxp, byp, R, rot);
        }

        DrawWord("HOLA", l1, top1, 0.3, t, 11, flash, flashAmt);
        DrawWord("GENTZANE", l2, top2, 1.1, t, 23, -1, 0);

        string sub = ">> CANASTA PERFECTA  ::  +2 PUNTOS PARA GENTZANE <<";
        Type((W - sub.Length) / 2, subY, sub, 3.6, 32, Rgb(120, 255, 210));
        if (t > BTN_T)
        {
            int bw = BTN.Length + 12, bx = (W - bw) / 2 - 1, by = subY + 2;
            double press = 0;
            if (pressT >= 0)
            {
                double e = t - pressT;
                press = e < 0.1 ? e / 0.1 : e < 0.45 ? 1 : 1 - Cl((e - 0.45) / 0.15);
                if (e < 0.05 && lastBurst != pressT) { lastBurst = pressT; Burst(bx + bw / 2.0, by + 1, 60, 14, Rgb(0, 255, 140)); Burst(bx + bw / 2.0, by + 1, 30, 10, Rgb(255, 255, 255)); }
            }
            double bflash = pressT >= 0 && t - pressT < 0.25 ? 1 - (t - pressT) / 0.25 : 0;
            RevealOn(BTN_T, by, 0.08, 0.45, 41);
            Button3D(bx, by, bw, BTN, press, bflash, t);
            RevealOff();
            if (pressT < 0 && t > BTN_T + 0.8 && ((int)(t * 2)) % 2 == 0)
            {
                string hint = "[ ENTER: comenzar   |   ESC: salir ]";
                Text((W - hint.Length) / 2, Math.Min(H - 3, by + 5), hint, Rgb(200, 190, 230));
            }
        }

        Hud("ONLINE");
        if (t < 0.6) Glitch((0.6 - t) * 1.4);
        if (pressT >= 0 && t > pressT + 0.6) Dialog(t - pressT - 0.6);
    }

    // ================================================================ boton 3D + ventana de aviso
    const double BTN_T = 5.2;
    const string BTN = "COMENZAR LA VALIDACI\u00d3N";
    const string URL = "https://drive.google.com/drive/u/0/folders/1MrvRT9LkWErw4pDbmMoIXZZiJk9SVc9o";
    static double pressT = -1, lastBurst = -2; static bool urlOpened;

    static void Press()
    {
        if (scene == 3 && pressT < 0 && st > BTN_T + 0.3) pressT = st;
    }

    // boton con volumen: al pulsarlo la cara baja y tapa el lateral
    static void Button3D(int x, int y, int w, string label, double press, double flash, double t)
    {
        int dpx = Rd((1 - press) * 2), dpy = press < 0.5 ? 1 : 0;
        int fx = x + 2 - dpx, fy = y + 1 - dpy;
        double pulse = pressT < 0 ? 0.5 + 0.5 * Math.Sin(t * 4) : 0;
        for (int r = 0; r < 3; r++)
            for (int c = 0; c < w; c++)
                PutB(fx + dpx + c, fy + dpy + r, ' ', 0, r == 2 ? Rgb(0, 55, 32) : Rgb(0, 95, 55));
        int top = Lerp(Rgb(110, 255, 175), Rgb(255, 255, 255), flash);
        int mid = Lerp(Lerp(Rgb(0, 200, 110), Rgb(70, 255, 165), pulse), Rgb(255, 255, 255), flash);
        int lo = Lerp(Rgb(0, 150, 85), Rgb(230, 255, 240), flash);
        for (int r = 0; r < 3; r++)
            for (int c = 0; c < w; c++)
                PutB(fx + c, fy + r, r == 0 ? '\u2580' : ' ', Rgb(200, 255, 225), r == 0 ? top : r == 1 ? mid : lo);
        int lx = fx + (w - label.Length) / 2;
        for (int i = 0; i < label.Length; i++) PutB(lx + i, fy + 1, label[i], Rgb(0, 30, 15), mid);
        if (pressT < 0)
        {
            int a = ((int)(t * 6)) % 3, g = Rgb(0, 255, 140);
            Text(x - 6 + a, fy + 1, ">>", g);
            Text(x + w + 6 - a, fy + 1, "<<", g);
        }
    }

    static readonly string[] DIG = {
        "###|# #|# #|# #|###", " # |## | # | # |###", "###|  #|###|#  |###",
        "###|  #|###|  #|###", "# #|# #|###|  #|  #", "###|#  |###|  #|###" };

    static void OpenUrl()
    {
        if (dumping) return;
        try { Process.Start(new ProcessStartInfo("chrome", URL) { UseShellExecute = true }); return; } catch { }
        try { Process.Start(URL); } catch { }
    }

    // ventana de aviso estilo Windows clasico con cuenta atras de 5 segundos
    static void Dialog(double e)
    {
        for (int i = 0; i < cb.Length; i++) { cc[i] = Scale(cc[i], 0.3); cbg[i] = Scale(cbg[i] < 0 ? bg : cbg[i], 0.3); }
        int dw = Math.Min(W - 4, 64), dh = 16;
        double open = Sm(e / 0.25);
        int cw = Math.Max(4, (int)(dw * open)), ch = Math.Max(3, (int)(dh * open));
        int dx = (W - cw) / 2, dy = Math.Max(1, (H - ch) / 2);
        int grey = Rgb(192, 192, 192), lite = Rgb(255, 255, 255), dark = Rgb(64, 64, 64), blk = Rgb(0, 0, 0);
        for (int y = dy + 1; y <= dy + ch; y++) for (int x = dx + 2; x <= dx + cw + 1; x++) Shade(x, y, 0.35);
        for (int y = dy; y < dy + ch; y++)
            for (int x = dx; x < dx + cw; x++)
            {
                bool t0 = y == dy, b0 = y == dy + ch - 1, l0 = x == dx, r0 = x == dx + cw - 1;
                char c = ' '; int col = blk;
                if (t0 && l0) { c = '\u250c'; col = lite; } else if (t0 && r0) { c = '\u2510'; col = dark; }
                else if (b0 && l0) { c = '\u2514'; col = lite; } else if (b0 && r0) { c = '\u2518'; col = dark; }
                else if (t0) { c = '\u2500'; col = lite; } else if (b0) { c = '\u2500'; col = dark; }
                else if (l0) { c = '\u2502'; col = lite; } else if (r0) { c = '\u2502'; col = dark; }
                PutB(x, y, c, col, grey);
            }
        if (open < 1) return;

        // barra de titulo
        for (int x = dx + 1; x < dx + dw - 1; x++) PutB(x, dy + 1, ' ', lite, Lerp(Rgb(0, 0, 128), Rgb(16, 132, 208), (double)(x - dx) / dw));
        Text(dx + 2, dy + 1, "/!\\ AVISO DEL SISTEMA - GENTZANE.EXE", lite);
        string[] wb = { " _ ", "[ ]", " X " };
        for (int i = 0; i < 3; i++) for (int k = 0; k < 3; k++) PutB(dx + dw - 12 + i * 4 + k, dy + 1, wb[i][k], blk, grey);

        // icono de advertencia
        int ix = dx + 3, iy = dy + 3, yel = Rgb(255, 205, 0);
        for (int r = 0; r < 5; r++)
        {
            int l = ix + 4 - r, rr = ix + 5 + r;
            Put(l, iy + r, r == 4 ? '/' : '/', Rgb(150, 110, 0)); Put(rr, iy + r, '\\', Rgb(150, 110, 0));
            for (int x = l + 1; x < rr; x++) PutB(x, iy + r, r == 4 ? '_' : ' ', Rgb(150, 110, 0), yel);
        }
        Put(ix + 4, iy + 2, '!', blk); Put(ix + 5, iy + 2, '!', blk); Put(ix + 4, iy + 3, '.', blk); Put(ix + 5, iy + 3, '.', blk);

        // textos
        int rem = Math.Max(0, (int)Math.Ceiling(5 - e));
        int tx = dx + 17;
        string msg = "Se buena porfa :)";
        for (int i = 0; i < msg.Length; i++)
            Put(tx + i, dy + 4, msg[i], Lerp(Rgb(170, 0, 90), Rgb(230, 0, 60), 0.5 + 0.5 * Math.Sin(e * 6 - i * 0.5)));
        if (((int)(e * 3)) % 2 == 0) Put(tx + msg.Length + 2, dy + 4, '\u2665', Rgb(220, 0, 40));
        Text(tx, dy + 6, "Validacion de GENTZANE en curso...", blk);
        Text(tx, dy + 7, "No cierres esta ventana.", dark);
        Text(tx, dy + 9, rem > 0 ? "Redirigiendo a Google Drive en " + rem + " s" : "Abriendo Google Drive...  ", Rgb(0, 0, 128));

        // numero grande de la cuenta atras
        string[] dg = DIG[Math.Min(5, rem)].Split('|');
        int nx = dx + dw - 10;
        for (int r = 0; r < 5; r++)
            for (int k = 0; k < 3; k++)
                if (dg[r][k] == '#') { Put(nx + k * 2, dy + 3 + r, FULL, Rgb(200, 0, 0)); Put(nx + k * 2 + 1, dy + 3 + r, FULL, Rgb(200, 0, 0)); }

        // barra de progreso por segmentos
        int px0 = dx + 3, pw = dw - 6, fill = (int)(pw * Cl(e / 5));
        for (int k = 0; k < pw; k++)
            PutB(px0 + k, dy + 11, k < fill && k % 3 != 2 ? FULL : ' ', Rgb(0, 0, 128), lite);
        Put(px0 - 1, dy + 11, '\u2502', dark); Put(px0 + pw, dy + 11, '\u2502', lite);

        // boton Aceptar
        string ok = "[    Aceptar    ]";
        Text(dx + (dw - ok.Length) / 2, dy + 13, ok, blk);

        if (e >= 5 && !urlOpened) { urlOpened = true; OpenUrl(); }
        if (e >= 6.5) quit = true;
    }
}
'@
try {
    Add-Type -TypeDefinition $code -Language CSharp
} catch {
    Write-Host ""
    Write-Host "  Error compilando el motor grafico:" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}
[GentzaneShow]::Run()
exit 0
