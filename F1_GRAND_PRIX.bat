<# : -------- parte BATCH (PowerShell la ve como un comentario) --------
@echo off
setlocal
title F1 GRAND PRIX - Online LAN
mode con: cols=120 lines=40
color 0F
cls
echo.
echo   [*] F1 GRAND PRIX
echo   [*] Compilando el motor de carreras, espera un segundo...
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
# -------- parte POWERSHELL: compila y lanza el juego --------
$ErrorActionPreference = 'Stop'
$code = @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Diagnostics;
using System.Globalization;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Net.NetworkInformation;
using System.Runtime.InteropServices;

public static class F1Game
{
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool WriteConsoleW(IntPtr h, string s, int n, out int w, IntPtr r);
    [DllImport("kernel32.dll")] static extern bool FlushConsoleInputBuffer(IntPtr h);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);

    class Sprite
    {
        public int w, h; public int[] px; public double ww;
        public Sprite(int w_, int h_, double ww_) { w = w_; h = h_; ww = ww_; px = new int[w_ * h_]; for (int i = 0; i < px.Length; i++) px[i] = -1; }
    }
    class Spr
    {
        public Sprite s; public double off; public bool hit;
        public Spr(Sprite s_, double o, bool h_) { s = s_; off = o; hit = h_; }
    }

    const string E = "\u001b[";
    const char UPB = '\u2580';
    static readonly CultureInfo INV = CultureInfo.InvariantCulture;

    static IntPtr hOut, hIn; static bool win, hadMode, asyncKeys = true; static uint oldMode;
    static int W = 120, H = 40, PW = 120, PH = 80;
    static int[] pix, pix2; static char[] cb, pcb; static int[] cc, cbg, pcc, pcbg; static bool fullDraw = true;
    static StringBuilder sb = new StringBuilder(1 << 18);
    static Random rnd = new Random(7);
    static volatile bool quit; static bool dumping;
    static double gt;

    // ================================================================ arranque
    public static void Run()
    {
        Setup();
        if (!win && Environment.OSVersion.Platform == PlatformID.Win32NT)
        {
            Console.WriteLine("Esta consola no soporta colores ANSI (hace falta Windows 10 o superior).");
            return;
        }
        try
        {
            Stopwatch sw = Stopwatch.StartNew();
            double last = 0;
            while (!quit)
            {
                double t = sw.Elapsed.TotalSeconds;
                double dt = Math.Min(0.05, t - last); last = t;
                CheckSize(); ReadInput(); Frame(dt); Present();
                int ms = (int)((1.0 / 30 - (sw.Elapsed.TotalSeconds - t)) * 1000);
                if (ms > 1) Thread.Sleep(ms);
            }
        }
        finally { Restore(); }
    }

    // modo de prueba: juega solo (piloto automatico) y vuelca fotogramas
    public static void Dump(int w, int h, string path, double[] times)
    {
        dumping = true; W = w; H = h; Alloc(); Init();
        using (StreamWriter o = new StreamWriter(path, false, new UTF8Encoding(false)))
        {
            double T = 0, dt = 1.0 / 30; int k = 0;
            while (k < times.Length && !quit)
            {
                ReadInput(); Frame(dt); Present(); T += dt;
                if (testRT) Thread.Sleep(33);
                if (T >= times[k])
                {
                    int pos = PosOf(0) + 1;
                    o.WriteLine("F " + T.ToString("0.00", INV) + " state=" + state + " lap=" + claps[0] + " pos=" + pos + " kmh=" + (int)Kmh() + " x=" + cx[0].ToString("0.00", INV) + " race=" + raceT.ToString("0.0", INV) + " bytes=" + sb.Length + " online=" + RemoteHumans() + " host=" + IsHost() + " peers=" + peers.Count);
                    for (int y = 0; y < H; y++) o.WriteLine(new string(cb, y * W, W));
                    for (int y = 0; y < H; y++)
                    {
                        StringBuilder l = new StringBuilder();
                        for (int x = 0; x < W; x++) { int i = y * W + x; l.Append(cc[i].ToString("x6")).Append(cbg[i].ToString("x6")); }
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
            hOut = GetStdHandle(-11); hIn = GetStdHandle(-10);
            uint m;
            if (GetConsoleMode(hOut, out m)) { oldMode = m; hadMode = true; win = SetConsoleMode(hOut, m | 0x0004 | 0x0001); }
        }
        catch { win = false; }
        try { Console.CursorVisible = false; } catch { }
        try { Console.CancelKeyPress += OnCancel; } catch { }
        ReadSize(); Alloc(); Init();
        Out(E + "?25l" + E + "0m" + E + "2J");
    }

    static void OnCancel(object s, ConsoleCancelEventArgs e) { e.Cancel = true; quit = true; }

    static void Restore()
    {
        NetBye();
        Out(E + "0m" + E + "2J" + E + "H" + E + "?25h");
        try { Console.CursorVisible = true; } catch { }
        if (hadMode) { try { SetConsoleMode(hOut, oldMode); } catch { } }
        try { FlushConsoleInputBuffer(hIn); } catch { }
    }

    static void ReadSize()
    {
        try { W = Math.Max(80, Console.WindowWidth); H = Math.Max(26, Console.WindowHeight); }
        catch { W = 120; H = 40; }
    }

    static void CheckSize()
    {
        int ow = W, oh = H; ReadSize();
        if (ow != W || oh != H) { Alloc(); Out(E + "0m" + E + "2J"); }
    }

    static void Alloc()
    {
        PW = W; PH = H * 2;
        pix = new int[PW * PH]; pix2 = new int[PW * PH];
        cb = new char[W * H]; cc = new int[W * H]; cbg = new int[W * H];
        pcb = new char[W * H]; pcc = new int[W * H]; pcbg = new int[W * H]; fullDraw = true;
    }

    // ================================================================ teclado
    static bool kUp, kDown, kLeft, kRight, kBoost, kEnter, kEsc, kPause;
    static bool pEnter = true, pEsc = true, pPause = true;

    static bool Down(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

    static void ReadInput()
    {
        if (dumping)
        {
            kUp = kDown = kLeft = kRight = kBoost = kEsc = kPause = false;
            kEnter = (state == ST_TITLE && stT > 1.0) || (state == ST_LOBBY && LobbyHost() && stT > 2 && (LobbyIds().Count >= testN || stT > 15));
            return;
        }
        bool en = false, es = false, pa = false;
        if (asyncKeys)
        {
            try
            {
                kUp = Down(0x26); kDown = Down(0x28); kLeft = Down(0x25); kRight = Down(0x27); kBoost = Down(0x20);
                en = Down(0x0D); es = Down(0x1B); pa = Down(0x50);
                if (state != ST_NAME) FlushConsoleInputBuffer(hIn);
            }
            catch { asyncKeys = false; }
        }
        if (!asyncKeys && state != ST_NAME)
        {
            kUp = kDown = kLeft = kRight = kBoost = false;
            try
            {
                while (Console.KeyAvailable)
                {
                    ConsoleKey k = Console.ReadKey(true).Key;
                    if (k == ConsoleKey.Enter) en = true; else if (k == ConsoleKey.Escape) es = true; else if (k == ConsoleKey.P) pa = true;
                    else if (k == ConsoleKey.UpArrow) kUp = true; else if (k == ConsoleKey.DownArrow) kDown = true;
                    else if (k == ConsoleKey.LeftArrow) kLeft = true; else if (k == ConsoleKey.RightArrow) kRight = true;
                    else if (k == ConsoleKey.Spacebar) kBoost = true;
                }
            }
            catch { }
            pEnter = pEsc = pPause = false;
        }
        kEnter = en && !pEnter; kEsc = es && !pEsc; kPause = pa && !pPause;
        pEnter = en; pEsc = es; pPause = pa;
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
        if (t <= 0) return a; if (t >= 1) return b;
        int ar = (a >> 16) & 255, ag = (a >> 8) & 255, ab = a & 255;
        return Rgb(ar + (((b >> 16) & 255) - ar) * t, ag + (((b >> 8) & 255) - ag) * t, ab + ((b & 255) - ab) * t);
    }
    static int Add(int a, int b) { return Rgb(((a >> 16) & 255) + ((b >> 16) & 255), ((a >> 8) & 255) + ((b >> 8) & 255), (a & 255) + (b & 255)); }
    static double Cl(double v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
    static double Sm(double v) { v = Cl(v); return v * v * (3 - 2 * v); }
    static double Lp(double a, double b, double t) { return a + (b - a) * t; }
    static int Rd(double v) { return (int)Math.Floor(v + 0.5); }
    static double Frac(double v) { return v - Math.Floor(v); }
    static double Hash(int x, int y, int s)
    {
        unchecked
        {
            uint h = (uint)(x * 374761393 + y * 668265263 + s * 982451653);
            h = (h ^ (h >> 13)) * 1274126177u; h ^= h >> 16;
            return (h & 0xFFFFFF) / 16777216.0;
        }
    }
    static string Fmt(double t)
    {
        if (t < 0 || t > 5999) return "-:--.---";
        int m = (int)(t / 60); double s = t - m * 60;
        return m + ":" + s.ToString("00.000", INV);
    }

    // ---------------------------------------------------------------- pixeles (2 por celda en vertical)
    static void PS(int x, int y, int c) { if ((uint)x < (uint)PW && (uint)y < (uint)PH) pix[y * PW + x] = c; }
    static void PB(int x, int y, int c, double a) { if ((uint)x < (uint)PW && (uint)y < (uint)PH) { int i = y * PW + x; pix[i] = Lerp(pix[i], c, a); } }
    static void PRect(int x, int y, int w, int h, int c) { for (int yy = y; yy < y + h; yy++) for (int xx = x; xx < x + w; xx++) PS(xx, yy, c); }
    static void PDisc(double cx, double cy, double rx, double ry, int c, double a)
    {
        int x0 = (int)Math.Floor(cx - rx), x1 = (int)Math.Ceiling(cx + rx), y0 = (int)Math.Floor(cy - ry), y1 = (int)Math.Ceiling(cy + ry);
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                double dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry, d = dx * dx + dy * dy;
                if (d <= 1) PB(x, y, c, a * (1 - d * 0.5));
            }
    }
    static void PLine(double x0, double y0, double x1, double y1, int c, double a)
    {
        int n = (int)Math.Max(Math.Abs(x1 - x0), Math.Abs(y1 - y0)) + 1;
        for (int k = 0; k <= n; k++) { double t = (double)k / n; PB((int)Lp(x0, x1, t), (int)Lp(y0, y1, t), c, a * (0.3 + 0.7 * t)); }
    }
    // panel oscuro translucido (en coordenadas de celda)
    static void Panel(int cx, int cy, int cw, int ch, double a, int accent)
    {
        for (int y = cy * 2; y < (cy + ch) * 2; y++)
            for (int x = cx; x < cx + cw; x++) PB(x, y, Rgb(6, 8, 18), a);
        if (accent >= 0) for (int x = cx; x < cx + cw; x++) PS(x, cy * 2, accent);
    }

    // ---------------------------------------------------------------- celdas y texto
    static void ToCells()
    {
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int t = pix[(2 * y) * PW + x] & 0xF8F8F8, b = pix[(2 * y + 1) * PW + x] & 0xF8F8F8, i = y * W + x;
                if (t == b) { cb[i] = ' '; cc[i] = 0; cbg[i] = b; }
                else { cb[i] = UPB; cc[i] = t; cbg[i] = b; }
            }
    }

    static void TC(int x, int y, char ch, int fg)
    {
        if (x < 0 || y < 0 || x >= W || y >= H) return;
        int i = y * W + x;
        if (cb[i] == UPB) cbg[i] = Lerp(cc[i], cbg[i], 0.5);
        cb[i] = ch; cc[i] = fg;
    }
    static void TS(int x, int y, string s, int fg) { for (int i = 0; i < s.Length; i++) if (s[i] != ' ') TC(x + i, y, s[i], fg); else TC(x + i, y, ' ', fg); }
    static void TSC(int y, string s, int fg) { TS((W - s.Length) / 2, y, s, fg); }

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

    // solo se envian las celdas que han cambiado desde el fotograma anterior
    static void Present()
    {
        sb.Length = 0;
        int lf = -1, lb = -1;
        for (int y = 0; y < H; y++)
        {
            bool jump = true;
            int wm = (y == H - 1) ? W - 1 : W;
            for (int x = 0; x < wm; x++)
            {
                int i = y * W + x, b = cbg[i] & 0xF8F8F8, f = cc[i] & 0xF8F8F8;
                char c = cb[i];
                if (!fullDraw && c == pcb[i] && b == pcbg[i] && (c == ' ' || f == pcc[i])) { jump = true; continue; }
                pcb[i] = c; pcbg[i] = b; pcc[i] = f;
                if (jump) { sb.Append(E).Append(y + 1).Append(';').Append(x + 1).Append('H'); jump = false; }
                bool nb = b != lb, nf = c != ' ' && f != lf;
                if (nb || nf)
                {
                    sb.Append(E);
                    if (nf) { sb.Append("38;2;").Append((f >> 16) & 255).Append(';').Append((f >> 8) & 255).Append(';').Append(f & 255); lf = f; }
                    if (nf && nb) sb.Append(';');
                    if (nb) { sb.Append("48;2;").Append((b >> 16) & 255).Append(';').Append((b >> 8) & 255).Append(';').Append(b & 255); lb = b; }
                    sb.Append('m');
                }
                sb.Append(c);
            }
        }
        fullDraw = false;
        if (sb.Length > 0) Out(sb.ToString());
    }

    // ---------------------------------------------------------------- fuentes
    // fuente grande "ANSI Shadow":  # = bloque,  el resto = sombra 3D
    static readonly Dictionary<char, string[]> BIG = new Dictionary<char, string[]>();
    static readonly Dictionary<char, string> F3 = new Dictionary<char, string>();

    static void InitFonts()
    {
        BIG['F'] = new string[] { "#######7", "##F====J", "#####7  ", "##F==J  ", "##|     ", "L=J     " };
        BIG['1'] = new string[] { " ##7", "###|", "L##|", " ##|", " ##|", " L=J" };
        BIG['G'] = new string[] { " ######7 ", "##F====J ", "##|  ###7", "##|   ##|", "L######FJ", " L=====J " };
        BIG['R'] = new string[] { "######7 ", "##F==##7", "######FJ", "##F==##7", "##|  ##|", "L=J  L=J" };
        BIG['A'] = new string[] { " #####7 ", "##F==##7", "#######|", "##F==##|", "##|  ##|", "L=J  L=J" };
        BIG['N'] = new string[] { "###7   ##7", "####7  ##|", "##F##7 ##|", "##|L##7##|", "##| L####|", "L=J  L===J" };
        BIG['D'] = new string[] { "######7 ", "##F==##7", "##|  ##|", "##|  ##|", "######FJ", "L=====J " };
        BIG['P'] = new string[] { "######7 ", "##F==##7", "######FJ", "##F===J ", "##|     ", "L=J     " };
        BIG['I'] = new string[] { "##7", "##|", "##|", "##|", "##|", "L=J" };
        BIG['X'] = new string[] { "##7  ##7", "L##7##FJ", " L###FJ ", " ##F##7 ", "##FJ ##7", "L=J  L=J" };
        BIG['O'] = new string[] { " ######7 ", "##F===##7", "##|   ##|", "##|   ##|", "L######FJ", " L=====J " };
        BIG['!'] = new string[] { "##7", "##|", "##|", "L=J", "##7", "L=J" };
        BIG['M'] = new string[] { "###7   ###7", "####7 ####|", "##F####F##|", "##|L##FJ##|", "##| L=J ##|", "L=J     L=J" };
        BIG['E'] = new string[] { "#######7", "##F====J", "#####7  ", "##F==J  ", "#######7", "L======J" };
        BIG['T'] = new string[] { "########7", "L==##F==J", "   ##|   ", "   ##|   ", "   ##|   ", "   L=J   " };
        BIG['U'] = new string[] { "##7   ##7", "##|   ##|", "##|   ##|", "##|   ##|", "L######FJ", " L=====J " };
        BIG['S'] = new string[] { "#######7", "##F====J", "#######7", "L====##|", "#######|", "L======J" };
        BIG[' '] = new string[] { "   ", "   ", "   ", "   ", "   ", "   " };

        string[] t = {
            "A.#.|#.#|###|#.#|#.#", "B##.|#.#|##.|#.#|##.", "C.##|#..|#..|#..|.##", "D##.|#.#|#.#|#.#|##.", "E###|#..|##.|#..|###",
            "F###|#..|##.|#..|#..", "G.##|#..|#.#|#.#|.##", "H#.#|#.#|###|#.#|#.#", "I###|.#.|.#.|.#.|###", "J..#|..#|..#|#.#|.#.",
            "K#.#|#.#|##.|#.#|#.#", "L#..|#..|#..|#..|###", "M#.#|###|###|#.#|#.#", "N##.|#.#|#.#|#.#|#.#", "O.#.|#.#|#.#|#.#|.#.",
            "P##.|#.#|##.|#..|#..", "Q.#.|#.#|#.#|##.|.##", "R##.|#.#|##.|#.#|#.#", "S.##|#..|.#.|..#|##.", "T###|.#.|.#.|.#.|.#.",
            "U#.#|#.#|#.#|#.#|###", "V#.#|#.#|#.#|#.#|.#.", "W#.#|#.#|###|###|#.#", "X#.#|#.#|.#.|#.#|#.#", "Y#.#|#.#|.#.|.#.|.#.",
            "Z###|..#|.#.|#..|###", "0###|#.#|#.#|#.#|###", "1.#.|##.|.#.|.#.|###", "2###|..#|###|#..|###", "3###|..#|.##|..#|###",
            "4#.#|#.#|###|..#|..#", "5###|#..|###|..#|###", "6###|#..|###|#.#|###", "7###|..#|.#.|.#.|.#.", "8###|#.#|###|#.#|###",
            "9###|#.#|###|..#|###", "!.#.|.#.|.#.|...|.#.", "-...|...|###|...|...", "#.#.|###|.#.|###|.#.", " ...|...|...|...|...",
            "/..#|..#|.#.|#..|#..", ":...|.#.|...|.#.|...", "+...|.#.|###|.#.|..." };
        foreach (string g in t) F3[g[0]] = g.Substring(1).Replace("|", "");
    }

    static int BigW(string s, int sc) { int n = 0; foreach (char c in s) n += BIG[c][0].Length; return n * sc; }

    // texto grande pintado en pixeles: cx,cy en celdas; cada caracter ocupa sc columnas x 2*sc pixeles
    static void BigPix(string s, int cx, int cy, int sc, int top, int bot, int shadow, double shine)
    {
        int ox = cx;
        foreach (char ch in s)
        {
            string[] g = BIG[ch];
            for (int r = 0; r < 6; r++)
                for (int k = 0; k < g[r].Length; k++)
                {
                    char m = g[r][k];
                    if (m == ' ') continue;
                    for (int sy = 0; sy < 2 * sc; sy++)
                        for (int sx = 0; sx < sc; sx++)
                        {
                            int px = ox + k * sc + sx, py = cy * 2 + r * 2 * sc + sy;
                            int col;
                            if (m == '#')
                            {
                                col = Lerp(top, bot, (double)(r * 2 * sc + sy) / (12 * sc));
                                if (shine >= 0) { double d = Math.Abs(px - cx + (py - cy * 2) * 0.6 - shine); if (d < 5) col = Lerp(col, Rgb(255, 255, 255), (1 - d / 5) * 0.8); }
                            }
                            else col = shadow;
                            PS(px, py, col);
                        }
                }
            ox += g[0].Length * sc;
        }
    }

    static int F3W(string s, int sc) { return s.Length * 4 * sc - sc; }

    static void F3Pix(string s, int x, int y, int sc, int col)
    {
        foreach (char ch0 in s)
        {
            char ch = char.ToUpperInvariant(ch0);
            string g; if (!F3.TryGetValue(ch, out g)) g = F3[' '];
            for (int r = 0; r < 5; r++) for (int c = 0; c < 3; c++) if (g[r * 3 + c] == '#') PRect(x + c * sc, y + r * sc, sc, sc, col);
            x += 4 * sc;
        }
    }

    static void F3Spr(Sprite sp, string s, int x, int y, int col)
    {
        foreach (char ch in s)
        {
            string g; if (!F3.TryGetValue(ch, out g)) g = F3[' '];
            for (int r = 0; r < 5; r++) for (int c = 0; c < 3; c++) if (g[r * 3 + c] == '#') SP(sp, x + c, y + r, col);
            x += 4;
        }
    }

    // ================================================================ pista
    const double SEG = 200, ROADW = 2000, CAMH = 1000, CAMDEPTH = 0.84, CARW = 700, CENTRI = 0.3, MAXSPD = 12000;
    const int RUMBLE = 3, DRAWD = 170, LAPS = 3, NCAR = 8;
    static readonly double PLAYERZ = CAMH * CAMDEPTH;
    static int NSeg; static double[] segCurve, segY; static List<Spr>[] segSpr; static double trackLen;
    static double[] mapX, mapY; static double mapAspect;
    static int t1Seg, hairSeg, chicSeg;
    static List<double> bc = new List<double>(), by2 = new List<double>();

    static double LastY() { return by2.Count == 0 ? 0 : by2[by2.Count - 1]; }
    static void AddSeg(double c, double y) { bc.Add(c); by2.Add(y); }
    static double EaseIn(double a, double b, double p) { return a + (b - a) * p * p; }
    static double EaseInOut(double a, double b, double p) { return a + (b - a) * (-Math.Cos(p * Math.PI) / 2 + 0.5); }

    static void AddRoad(int enter, int hold, int leave, double curve, double hill)
    {
        double sy = LastY(), ey = sy + hill * SEG; int total = enter + hold + leave;
        for (int n = 0; n < enter; n++) AddSeg(EaseIn(0, curve, (double)n / enter), EaseInOut(sy, ey, (double)n / total));
        for (int n = 0; n < hold; n++) AddSeg(curve, EaseInOut(sy, ey, (double)(enter + n) / total));
        for (int n = 0; n < leave; n++) AddSeg(EaseInOut(curve, 0, (double)n / leave), EaseInOut(sy, ey, (double)(enter + hold + n) / total));
    }

    static void BuildTrack()
    {
        const int S = 25, M = 50, L = 100;
        bc.Clear(); by2.Clear();
        AddRoad(M, M, M, 0, 0);                 // recta de meta
        AddRoad(M, M, M, 0, 0);
        t1Seg = bc.Count;
        AddRoad(S, M, S, 5, 0);                 // curva 1: derecha cerrada
        AddRoad(S, S, S, -3, 15);               // curva 2: izquierda subiendo
        AddRoad(M, M, M, 0, 10);
        AddRoad(M, M, M, 3, -10);               // curva larga
        chicSeg = bc.Count;
        AddRoad(S, S, S, -4, 0);                // chicane
        AddRoad(S, S, S, 4, 0);
        AddRoad(S, S, S, -2, 0);
        AddRoad(M, M, M, 0, -15);               // bajada
        hairSeg = bc.Count;
        AddRoad(S, M, S, 6, 0);                 // horquilla
        AddRoad(M, M, M, 0, 20);                // recta en subida
        AddRoad(M, L, M, 2.5, -10);             // curva rapida
        AddRoad(S, S, S, -4, 0);
        AddRoad(S, M, S, 5, 0);
        AddRoad(M, M, M, 0, -LastY() / SEG);    // vuelta a meta
        for (int k = 0; k < 6; k++) AddSeg(0, 0);
        NSeg = bc.Count;
        segCurve = bc.ToArray();
        segY = new double[NSeg + 1];
        for (int i = 0; i < NSeg; i++) segY[i + 1] = by2[i];
        segY[0] = 0; segY[NSeg] = 0;
        trackLen = NSeg * SEG;
        segSpr = new List<Spr>[NSeg];
        for (int i = 0; i < NSeg; i++) segSpr[i] = new List<Spr>();
    }

    static void BuildMap()
    {
        double sum = 0; for (int i = 0; i < NSeg; i++) sum += segCurve[i];
        double k = 2 * Math.PI / sum, h = 0, x = 0, y = 0;
        mapX = new double[NSeg + 1]; mapY = new double[NSeg + 1];
        for (int i = 0; i <= NSeg; i++)
        {
            mapX[i] = x; mapY[i] = y;
            if (i < NSeg) { h += segCurve[i] * k; x += Math.Sin(h); y -= Math.Cos(h); }
        }
        double ex = mapX[NSeg], ey = mapY[NSeg];
        double minx = 1e9, maxx = -1e9, miny = 1e9, maxy = -1e9;
        for (int i = 0; i <= NSeg; i++)
        {
            mapX[i] -= ex * i / NSeg; mapY[i] -= ey * i / NSeg;
            minx = Math.Min(minx, mapX[i]); maxx = Math.Max(maxx, mapX[i]); miny = Math.Min(miny, mapY[i]); maxy = Math.Max(maxy, mapY[i]);
        }
        double rx = Math.Max(1, maxx - minx), ry = Math.Max(1, maxy - miny);
        mapAspect = rx / ry;
        for (int i = 0; i <= NSeg; i++) { mapX[i] = (mapX[i] - minx) / rx; mapY[i] = (mapY[i] - miny) / ry; }
    }

    static int SegAt(double z) { int i = (int)Math.Floor(z / SEG) % NSeg; return i < 0 ? i + NSeg : i; }
    static double Wrap(double z) { z %= trackLen; return z < 0 ? z + trackLen : z; }
    static double Wrapd(double d) { d = Wrap(d); return d > trackLen / 2 ? d - trackLen : d; }

    // ================================================================ sprites del circuito
    static Sprite sTree, sTree2, sTires, sStand, sGantry; static Sprite[] sBoards, sMarks;
    static readonly int[] CROWD = { Rgb(230, 30, 40), Rgb(255, 255, 255), Rgb(255, 210, 0), Rgb(30, 90, 220), Rgb(250, 140, 0), Rgb(40, 40, 50), Rgb(240, 200, 170), Rgb(0, 170, 120) };

    static void SP(Sprite s, int x, int y, int c) { if (x >= 0 && y >= 0 && x < s.w && y < s.h) s.px[y * s.w + x] = c; }

    static void BuildSprites()
    {
        // pino
        sTree = new Sprite(16, 26, 1700);
        for (int y = 20; y < 26; y++) { SP(sTree, 7, y, Rgb(95, 60, 30)); SP(sTree, 8, y, Rgb(70, 42, 22)); }
        for (int y = 0; y < 21; y++)
        {
            double hw = 0.8 + (y % 7) * 0.95 + y / 5.0;
            for (int x = 0; x < 16; x++)
            {
                double d = x + 0.5 - 8;
                if (Math.Abs(d) >= hw) continue;
                double l = Cl(0.5 - d / (hw * 2) + (Hash(x, y, 3) - 0.5) * 0.3);
                SP(sTree, x, y, Lerp(Rgb(12, 60, 32), Rgb(60, 150, 70), l));
            }
        }
        // arbol redondo
        sTree2 = new Sprite(18, 24, 1900);
        for (int y = 15; y < 24; y++) { SP(sTree2, 8, y, Rgb(100, 65, 35)); SP(sTree2, 9, y, Rgb(72, 45, 24)); }
        for (int y = 0; y < 18; y++)
            for (int x = 0; x < 18; x++)
            {
                double dx = (x + 0.5 - 9) / 8.6, dy = (y + 0.5 - 9) / 8.6, d = dx * dx + dy * dy;
                if (d > 1 - Hash(x, y, 4) * 0.15) continue;
                double l = Cl(0.55 - dx * 0.35 - dy * 0.35 + (Hash(x, y, 5) - 0.5) * 0.35);
                SP(sTree2, x, y, Lerp(Rgb(20, 70, 30), Rgb(110, 175, 60), l));
            }
        // muro de neumaticos
        sTires = new Sprite(24, 8, 1300);
        for (int row = 0; row < 2; row++)
            for (int k = 0; k < 6; k++)
                for (int y = 0; y < 4; y++)
                    for (int x = 0; x < 4; x++)
                    {
                        if ((x == 0 || x == 3) && (y == 0 || y == 3)) continue;
                        bool inner = x > 0 && x < 3 && y > 0 && y < 3;
                        int band = (k + row) % 2 == 0 ? Rgb(230, 30, 35) : Rgb(240, 240, 240);
                        SP(sTires, k * 4 + x, row * 4 + y, inner ? Rgb(15, 15, 18) : (y == 1 || y == 2) ? band : Rgb(35, 35, 40));
                    }
        // vallas publicitarias
        string[] txt = { "F1 GP", "TURBO", "RACING", "SPEED", "VAMOS!", "ERS" };
        int[] bgs = { Rgb(200, 10, 30), Rgb(15, 25, 60), Rgb(255, 190, 0), Rgb(0, 150, 110), Rgb(110, 20, 160), Rgb(0, 90, 220) };
        int[] fgs = { Rgb(255, 255, 255), Rgb(255, 255, 255), Rgb(20, 20, 20), Rgb(255, 255, 255), Rgb(255, 230, 0), Rgb(255, 255, 255) };
        sBoards = new Sprite[txt.Length];
        for (int b = 0; b < txt.Length; b++)
        {
            int tw = F3W(txt[b], 1), w = tw + 6, h = 14;
            Sprite s = new Sprite(w, h, w * 85);
            for (int y = 0; y < 9; y++) for (int x = 0; x < w; x++) SP(s, x, y, (y == 0 || y == 8 || x == 0 || x == w - 1) ? Rgb(235, 235, 240) : bgs[b]);
            F3Spr(s, txt[b], 3, 2, fgs[b]);
            for (int y = 9; y < h; y++) { SP(s, 2, y, Rgb(120, 120, 130)); SP(s, w - 3, y, Rgb(120, 120, 130)); }
            sBoards[b] = s;
        }
        // tribuna con publico
        sStand = new Sprite(72, 30, 7500);
        for (int x = 0; x < 72; x++)
        {
            for (int y = 0; y < 3; y++) SP(sStand, x, y, (x / 4) % 2 == 0 ? Rgb(230, 230, 235) : Rgb(200, 20, 30));
            SP(sStand, x, 3, Rgb(40, 40, 48));
            for (int y = 4; y < 23; y++)
            {
                int c = (y - 4) % 3 == 2 ? Rgb(95, 95, 105) : (Hash(x, y, 9) < 0.12 ? Rgb(30, 60, 160) : -2);
                SP(sStand, x, y, c);
            }
            for (int y = 23; y < 30; y++) SP(sStand, x, y, y == 29 ? Rgb(90, 90, 100) : Rgb(18, 20, 32));
        }
        foreach (int px0 in new int[] { 1, 35, 70 }) for (int y = 4; y < 23; y++) SP(sStand, px0, y, Rgb(150, 150, 160));
        F3Spr(sStand, "GRAND PRIX", 36 - F3W("GRAND PRIX", 1) / 2, 24, Rgb(255, 255, 255));
        // portico de salida con semaforo
        sGantry = new Sprite(100, 36, 5800);
        for (int y = 10; y < 36; y++)
            for (int x = 0; x < 4; x++) { SP(sGantry, x, y, x == 0 ? Rgb(90, 90, 100) : Rgb(160, 160, 172)); SP(sGantry, 99 - x, y, x == 0 ? Rgb(90, 90, 100) : Rgb(160, 160, 172)); }
        for (int y = 0; y < 12; y++)
            for (int x = 0; x < 100; x++)
                SP(sGantry, x, y, y == 0 ? Rgb(220, 20, 30) : y == 11 ? (((x / 2) + (y / 2)) % 2 == 0 ? Rgb(240, 240, 240) : Rgb(10, 10, 10)) : Rgb(28, 28, 34));
        F3Spr(sGantry, "GRAND PRIX", 50 - F3W("GRAND PRIX", 1) / 2, 1, Rgb(255, 255, 255));
        for (int k = 0; k < 5; k++)
        {
            int x0 = 50 - 24 + k * 10;
            for (int y = 7; y < 11; y++) for (int x = x0; x < x0 + 7; x++) SP(sGantry, x, y, Rgb(5, 5, 6));
            for (int y = 8; y < 10; y++) { SP(sGantry, x0 + 1, y, -10 - k); SP(sGantry, x0 + 2, y, -10 - k); SP(sGantry, x0 + 4, y, -10 - k); SP(sGantry, x0 + 5, y, -10 - k); }
        }
        // carteles de distancia
        string[] mk = { "300", "200", "100" };
        sMarks = new Sprite[3];
        for (int m = 0; m < 3; m++)
        {
            Sprite s = new Sprite(15, 12, 800);
            for (int y = 0; y < 8; y++) for (int x = 0; x < 15; x++) SP(s, x, y, (y == 0 || y == 7 || x == 0 || x == 14) ? Rgb(20, 20, 20) : Rgb(245, 245, 245));
            F3Spr(s, mk[m], 2, 2, Rgb(20, 20, 20));
            for (int y = 8; y < 12; y++) SP(s, 7, y, Rgb(110, 110, 120));
            sMarks[m] = s;
        }
    }

    static void AddS(int seg, Sprite s, double off, bool hit) { segSpr[((seg % NSeg) + NSeg) % NSeg].Add(new Spr(s, off, hit)); }

    static void PlaceSprites()
    {
        Random r = new Random(42);
        AddS(4, sGantry, 0, false);
        AddS(20, sStand, -1.6, true); AddS(20, sStand, 1.6, true);
        AddS(48, sStand, -1.6, true); AddS(48, sStand, 1.6, true);
        AddS(76, sStand, 1.6, true);
        int bi = 0;
        for (int s = 110; s < 290; s += 22) { AddS(s, sBoards[bi % sBoards.Length], (bi % 2 == 0) ? -1.3 : 1.3, true); bi++; }
        foreach (int c in new int[] { t1Seg, hairSeg, chicSeg })
            for (int m = 0; m < 3; m++) AddS(c - 45 + m * 15, sMarks[m], 1.25, true);
        for (int i = 0; i < NSeg; i++)
        {
            double c = segCurve[i];
            if (Math.Abs(c) >= 2.5 && i % 5 == 0) AddS(i, sTires, -Math.Sign(c) * 1.3, true);
            if (i > 100 && i % 5 == 0 && i % 22 != 0)
            {
                double side = r.Next(2) == 0 ? -1 : 1;
                AddS(i, r.Next(3) == 0 ? sTree2 : sTree, side * (1.9 + r.NextDouble() * 2.6), true);
                if (r.Next(3) == 0) AddS(i, r.Next(2) == 0 ? sTree2 : sTree, -side * (2.2 + r.NextDouble() * 3), true);
            }
            if (i > 300 && i % 60 == 30) AddS(i, sBoards[(i / 60) % sBoards.Length], (i / 60) % 2 == 0 ? 1.35 : -1.35, true);
        }
    }

    // ================================================================ coches
    static double[] cz = new double[NCAR], cx = new double[NCAR], cspd = new double[NCAR], ctop = new double[NCAR], cline = new double[NCAR];
    static double[] cdelay = new double[NCAR], cfin = new double[NCAR], cbest = new double[NCAR], clast = new double[NCAR];
    static int[] claps = new int[NCAR], cmain = new int[NCAR], csec = new int[NCAR], chelm = new int[NCAR]; static bool[] cbrk = new bool[NCAR];
    // indice 0 = este jugador; el resto son jugadores de la red (ckind 1) o pilotos IA (ckind 2)
    static string[] cname = new string[NCAR], cfull = new string[NCAR], cteam = new string[NCAR];
    static int[] ckind = new int[NCAR], cslot = new int[NCAR]; static long[] cnid = new long[NCAR]; static bool[] cgone = new bool[NCAR];
    static double[] nProg = new double[NCAR], nX = new double[NCAR], nSpd = new double[NCAR], nTime = new double[NCAR];
    static readonly string[] BOTN = { "ZAP", "NEO", "KOI", "RAY", "VEX", "ORB", "TAO", "LUX" };
    static readonly string[] TEAMS = { "SCARLET RACING", "NEON MOTORS", "PAPAYA GP", "BLUE THUNDER", "VERDE RT", "ROSA RACING", "POLAR TEAM", "SOLAR GP" };
    static readonly double[] TOPS = { 0.95, 0.94, 0.93, 0.92, 0.91, 0.9, 0.89, 0.88 };
    static int[][] COLS;
    static int[] order = new int[NCAR];

    // coche visto desde detras (mitad izquierda; la derecha es simetrica)
    static readonly string[] CARL = {
        "....WWWWWWWWWWWWWWWW", "....Wwwwwwwwwwwwwwww", "....WWWWWWWWWWWWWWWW", "....XXXXXXXXXXXXXXXX",
        "....X.............GG", "....X............RHH", ".KKKKKK.........rRRR", "KKKKKKKK.......rRRRR",
        "KKKKKKKK.....rRRRRww", "KKKKKKKK...rRRRRRRww", "KKKKKKKK..rRRRRRRRRE", "KKKKKKKKGGGGGGGGGGGG",
        "KKKKKKKK..DDDDDDDDDL", "KKKKKKKK..DD.DD.DD.L", "KKKKKKKK..DDDDDDDDDD", "KKKKKKKK............",
        ".KKKKKK.............", "...................." };
    static string[] CAR;

    static void InitCars()
    {
        CAR = new string[CARL.Length];
        for (int r = 0; r < CARL.Length; r++)
        {
            char[] a = CARL[r].ToCharArray(); Array.Reverse(a);
            CAR[r] = CARL[r] + new string(a);
        }
        COLS = new int[][] {
            new int[] { Rgb(225, 15, 25), Rgb(245, 245, 245), Rgb(255, 215, 0) },
            new int[] { Rgb(0, 200, 180), Rgb(30, 35, 40), Rgb(240, 240, 240) },
            new int[] { Rgb(255, 135, 0), Rgb(20, 25, 45), Rgb(0, 160, 255) },
            new int[] { Rgb(25, 35, 130), Rgb(255, 200, 0), Rgb(230, 30, 40) },
            new int[] { Rgb(0, 120, 80), Rgb(210, 255, 0), Rgb(255, 255, 255) },
            new int[] { Rgb(255, 90, 180), Rgb(30, 90, 220), Rgb(255, 255, 255) },
            new int[] { Rgb(235, 235, 245), Rgb(0, 110, 255), Rgb(255, 60, 60) },
            new int[] { Rgb(255, 210, 0), Rgb(25, 25, 25), Rgb(0, 200, 120) } };
    }

    static int CarCol(char ch, int ci, int v, double phase, bool brake, bool boostGlow)
    {
        switch (ch)
        {
            case 'W': return csec[ci];
            case 'w': return cmain[ci];
            case 'X': return Rgb(30, 30, 35);
            case 'G': return Rgb(140, 140, 152);
            case 'R': return cmain[ci];
            case 'r': return Scale(cmain[ci], 0.62);
            case 'H': return chelm[ci];
            case 'E': return boostGlow ? Lerp(Rgb(80, 160, 255), Rgb(255, 255, 255), 0.5 + 0.5 * Math.Sin(gt * 40)) : Rgb(55, 55, 60);
            case 'D': return Rgb(26, 26, 30);
            case 'L': return brake ? Rgb(255, 30, 30) : (boostGlow && ((int)(gt * 8)) % 2 == 0 ? Rgb(255, 60, 60) : Rgb(80, 5, 5));
            case 'K': return ((v + (int)phase) % 3 == 0) ? Rgb(52, 52, 58) : Rgb(20, 20, 23);
            default: return csec[ci];
        }
    }

    static void DrawCar(double x0, double y0, double w, double h, int ci, double phase, double topShift, bool brake, bool boostGlow, double fog, int clipY)
    {
        if (w < 2.5) { if (w > 0.6) { PS((int)(x0 + w / 2), (int)(y0 + h), Lerp(FOG, cmain[ci], fog)); } return; }
        PDisc(x0 + w / 2, y0 + h * 0.93, w * 0.56, Math.Max(0.8, h * 0.1), Rgb(0, 0, 0), 0.55 * fog);
        int xa = Math.Max(0, (int)Math.Floor(x0)), xb = Math.Min(PW - 1, (int)Math.Ceiling(x0 + w)), ya = Math.Max(0, (int)Math.Floor(y0)), yb = Math.Min(Math.Min(PH - 1, clipY - 1), (int)Math.Ceiling(y0 + h));
        for (int py = ya; py <= yb; py++)
        {
            int v = (int)((py + 0.5 - y0) / h * 18);
            if (v < 0 || v >= 18) continue;
            string row = CAR[v];
            for (int px = xa; px <= xb; px++)
            {
                double u = (px + 0.5 - x0) / w * 40;
                if (v < 11) u -= topShift;
                int ui = (int)Math.Floor(u);
                if (ui < 0 || ui >= 40) continue;
                char ch = row[ui];
                if (ch == '.') continue;
                int c = CarCol(ch, ci, v, phase, brake, boostGlow);
                if (fog < 0.999) c = Lerp(FOG, c, fog);
                pix[py * PW + px] = c;
            }
        }
    }

    // ================================================================ estado de carrera
    const int ST_TITLE = 0, ST_COUNT = 1, ST_RACE = 2, ST_FINISH = 3, ST_NAME = 4, ST_LOBBY = 5;
    static int state; static double stT, raceT, lightsOutT; static bool paused;
    static double steerVis, energy = 1, rpm, thrVis, brkVis, shake, dist, crashCool, lastLapT = -1, bestLapT = -1;
    static bool boosting, onKerb, offRoad, braking; static int prevPos, finishPos;
    static string msg = ""; static int msgCol; static double msgT = -10, msgDur;

    static void Init()
    {
        InitFonts(); BuildTrack(); BuildSprites(); PlaceSprites(); BuildMap(); InitCars();
        for (int n = 0; n < DRAWD; n++) bucket[n] = new List<int>();
        LoadName(); NetStart();
        NewRace(new long[] { myId }, rnd.Next()); state = ST_TITLE; stT = 0;
    }

    static void Msg(string s, int col, double dur) { msg = s; msgCol = col; msgT = gt; msgDur = dur; }

    // reparte la parrilla: mismos huecos en todos los ordenadores gracias a la semilla compartida
    static void NewRace(long[] humans, int seed)
    {
        Random r = new Random(seed);
        int[] perm = { 0, 1, 2, 3, 4, 5, 6, 7 };
        for (int k = 7; k > 0; k--) { int j = r.Next(k + 1); int t = perm[k]; perm[k] = perm[j]; perm[j] = t; }
        long[] slotHuman = new long[NCAR];
        bool meIn = false;
        for (int k = 0; k < humans.Length && k < NCAR; k++) { slotHuman[perm[k]] = humans[k]; if (humans[k] == myId) meIn = true; }
        if (!meIn) slotHuman[perm[0]] = myId;
        lightsOutT = 1.0 + 4 * 0.9 + 0.6 + r.NextDouble();
        int next = 1;
        for (int sl = 0; sl < NCAR; sl++)
        {
            long hid = slotHuman[sl];
            int c = hid == myId ? 0 : next++;
            cslot[c] = sl; cnid[c] = hid; ckind[c] = hid == myId ? 0 : hid != 0 ? 1 : 2; cgone[c] = false;
            cmain[c] = COLS[sl][0]; csec[c] = COLS[sl][1]; chelm[c] = COLS[sl][2]; ctop[c] = MAXSPD * TOPS[sl];
            cteam[c] = TEAMS[sl];
            if (ckind[c] == 2) { cname[c] = BOTN[sl]; cfull[c] = BOTN[sl] + " (IA)"; }
            else { string nm = c == 0 ? myName : PeerName(hid); cfull[c] = nm; cname[c] = Code(nm); }
            cz[c] = trackLen - (3 + sl * 4) * SEG; cx[c] = sl % 2 == 0 ? -0.45 : 0.45;
            cspd[c] = 0; claps[c] = -1; cfin[c] = -1; cbest[c] = 1e9; clast[c] = 0;
            cline[c] = (r.NextDouble() - 0.5) * 0.7; cdelay[c] = 0.15 + r.NextDouble() * 0.35; cbrk[c] = false;
            nProg[c] = -1e12; nX[c] = cx[c]; nSpd[c] = 0; nTime[c] = -1;
        }
        raceT = 0; energy = 1; shake = 0; pn = 0; lastLapT = -1; bestLapT = -1; paused = false; boosting = false;
        msg = ""; crashCool = 0;
        SortOrder(); prevPos = PosOf(0);
    }

    static void StartCountdown(long[] humans, int seed, int raceId)
    {
        NewRace(humans, seed); curRace = raceId; state = ST_COUNT; stT = 0;
    }

    static void BackToLobby()
    {
        curRace = 0; state = ST_LOBBY; stT = 0;
        NewRace(new long[] { myId }, rnd.Next());
    }

    static double Prog(int i) { return cfin[i] >= 0 ? 1e9 - cfin[i] : claps[i] * trackLen + cz[i]; }
    static double Kmh() { return cspd[0] / MAXSPD * 330; }

    static void SortOrder()
    {
        for (int i = 0; i < NCAR; i++) order[i] = i;
        Array.Sort(order, delegate(int a, int b) { return Prog(b).CompareTo(Prog(a)); });
    }
    static int PosOf(int c) { for (int k = 0; k < NCAR; k++) if (order[k] == c) return k; return 0; }

    static void Advance(int i, double d)
    {
        cz[i] += d;
        while (cz[i] >= trackLen) { cz[i] -= trackLen; claps[i]++; OnCross(i); }
    }

    static void OnCross(int i)
    {
        if (state != ST_RACE && state != ST_FINISH) { clast[i] = raceT; return; }
        if (claps[i] >= 1)
        {
            double lt = raceT - clast[i];
            if (lt < cbest[i]) cbest[i] = lt;
            if (i == 0 && state == ST_RACE)
            {
                lastLapT = lt;
                bool fastest = bestLapT < 0 || lt < bestLapT;
                if (fastest) bestLapT = lt;
                if (claps[0] < LAPS)
                {
                    if (fastest && claps[0] >= 2) Msg("VUELTA RAPIDA  " + Fmt(lt), Rgb(200, 90, 255), 2.5);
                    else Msg(claps[0] == LAPS - 1 ? "ULTIMA VUELTA!" : "VUELTA " + (claps[0] + 1) + "/" + LAPS + "   " + Fmt(lt), claps[0] == LAPS - 1 ? Rgb(255, 255, 255) : Rgb(0, 230, 255), 2.5);
                }
            }
        }
        clast[i] = raceT;
        if (claps[i] == LAPS && cfin[i] < 0) cfin[i] = raceT;
        if (i == 0 && state == ST_RACE && claps[0] == LAPS)
        {
            SortOrder(); finishPos = PosOf(0) + 1;
            state = ST_FINISH; stT = 0; boosting = false;
            Msg(finishPos == 1 ? "VICTORIA!" : finishPos <= 3 ? "PODIO! P" + finishPos : "META  P" + finishPos, finishPos <= 3 ? Rgb(255, 215, 0) : Rgb(255, 255, 255), 4);
            for (int k = 0; k < 160; k++)
                PSpawn(2, rnd.NextDouble() * PW, -rnd.NextDouble() * PH * 0.5, (rnd.NextDouble() - 0.5) * 30, rnd.NextDouble() * 20, 3 + rnd.NextDouble() * 3, NEONS[rnd.Next(NEONS.Length)], 1);
        }
    }


    // ================================================================ nombre del jugador
    static string myName = "PILOTO", nameBuf = "";

    static string NamePath() { return Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "F1GrandPrix"), "nombre.txt"); }

    static void LoadName()
    {
        string t = Environment.GetEnvironmentVariable("F1_TEST_NAME");
        if (!string.IsNullOrEmpty(t)) { myName = t; return; }
        try { string n = CleanName(File.ReadAllText(NamePath())); if (n.Length > 0) myName = n; } catch { }
    }

    static string CleanName(string n)
    {
        StringBuilder b = new StringBuilder();
        foreach (char ch in n.ToUpperInvariant())
            if ((char.IsLetterOrDigit(ch) || ch == ' ' || ch == '-' || ch == '_') && b.Length < 12) b.Append(ch);
        return b.ToString().Trim();
    }

    static string Code(string n)
    {
        StringBuilder b = new StringBuilder();
        foreach (char ch in n) if (char.IsLetterOrDigit(ch)) { b.Append(char.ToUpperInvariant(ch)); if (b.Length == 3) break; }
        while (b.Length < 3) b.Append('X');
        return b.ToString();
    }

    static void NameInput()
    {
        if (dumping) { if (stT > 0.5) ConfirmName(); return; }
        try
        {
            while (Console.KeyAvailable)
            {
                ConsoleKeyInfo k = Console.ReadKey(true);
                if (k.Key == ConsoleKey.Enter) { if (CleanName(nameBuf).Length > 0) { ConfirmName(); return; } }
                else if (k.Key == ConsoleKey.Backspace) { if (nameBuf.Length > 0) nameBuf = nameBuf.Substring(0, nameBuf.Length - 1); }
                else
                {
                    char ch = char.ToUpperInvariant(k.KeyChar);
                    if ((char.IsLetterOrDigit(ch) || ch == ' ' || ch == '-' || ch == '_') && nameBuf.Length < 12) nameBuf += ch;
                }
            }
        }
        catch { }
    }

    static void ConfirmName()
    {
        string n = CleanName(nameBuf);
        if (n.Length > 0) myName = n;
        if (!dumping) try { Directory.CreateDirectory(Path.GetDirectoryName(NamePath())); File.WriteAllText(NamePath(), myName); } catch { }
        state = ST_LOBBY; stT = 0;
        helloT = 0;
    }

    // ================================================================ red local (UDP broadcast)
    class Peer { public string name = "PILOTO"; public char st = 'T'; public double last; }
    const int PORT = 47777;
    static UdpClient udp; static List<IPEndPoint> targets = new List<IPEndPoint>();
    static string netErr = "", myIp = "";
    static long myId; static int curRace;
    static Dictionary<long, Peer> peers = new Dictionary<long, Peer>();
    static double helloT, carT, aiT, startT; static int startRepeat; static string startMsg = "";
    static bool testRT; static int testN = 2;

    static void NetStart()
    {
        myId = BitConverter.ToInt64(Guid.NewGuid().ToByteArray(), 0) & 0x7FFFFFFFFFFFL;
        string tp = Environment.GetEnvironmentVariable("F1_TEST_PORT"), tpe = Environment.GetEnvironmentVariable("F1_TEST_PEERS");
        testRT = Environment.GetEnvironmentVariable("F1_TEST_RT") == "1";
        string tn = Environment.GetEnvironmentVariable("F1_TEST_N"); if (!string.IsNullOrEmpty(tn)) testN = int.Parse(tn);
        try
        {
            udp = new UdpClient();
            udp.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            udp.Client.Bind(new IPEndPoint(IPAddress.Any, string.IsNullOrEmpty(tp) ? PORT : int.Parse(tp)));
            udp.EnableBroadcast = true;
            try { udp.Client.IOControl(-1744830452, new byte[] { 0, 0, 0, 0 }, null); } catch { }
        }
        catch { udp = null; netErr = "RED NO DISPONIBLE: se jugara sin conexion"; return; }
        if (!string.IsNullOrEmpty(tpe))
        {
            foreach (string q in tpe.Split(',')) targets.Add(new IPEndPoint(IPAddress.Loopback, int.Parse(q)));
            myIp = "127.0.0.1";
            return;
        }
        targets.Add(new IPEndPoint(IPAddress.Broadcast, PORT));
        try
        {
            foreach (NetworkInterface ni in NetworkInterface.GetAllNetworkInterfaces())
            {
                if (ni.OperationalStatus != OperationalStatus.Up || ni.NetworkInterfaceType == NetworkInterfaceType.Loopback) continue;
                foreach (UnicastIPAddressInformation ua in ni.GetIPProperties().UnicastAddresses)
                {
                    try
                    {
                        if (ua.Address.AddressFamily != AddressFamily.InterNetwork || ua.IPv4Mask == null) continue;
                        byte[] a = ua.Address.GetAddressBytes(), m = ua.IPv4Mask.GetAddressBytes(), b = new byte[4];
                        for (int k = 0; k < 4; k++) b[k] = (byte)(a[k] | ~m[k]);
                        targets.Add(new IPEndPoint(new IPAddress(b), PORT));
                        if (myIp.Length == 0 && a[0] != 169) myIp = ua.Address.ToString();
                    }
                    catch { }
                }
            }
        }
        catch { }
    }

    static void NetSend(string msg)
    {
        if (udp == null) return;
        byte[] b = Encoding.UTF8.GetBytes(msg);
        foreach (IPEndPoint ep in targets) { try { udp.Send(b, b.Length, ep); } catch { } }
    }

    static void NetBye() { if (udp != null) { NetSend("F1GP|BYE|" + myId); try { udp.Close(); } catch { } udp = null; } }

    static char StChar()
    {
        switch (state) { case ST_NAME: return 'N'; case ST_LOBBY: return 'L'; case ST_COUNT: case ST_RACE: return 'R'; case ST_FINISH: return 'F'; default: return 'T'; }
    }

    static string D(double v) { return v.ToString("0.###", INV); }
    static double P(string s) { double v; double.TryParse(s, NumberStyles.Float, INV, out v); return v; }

    static void NetTick(double dt)
    {
        if (udp == null) return;
        try
        {
            while (udp.Available > 0)
            {
                IPEndPoint ep = new IPEndPoint(IPAddress.Any, 0);
                byte[] b = udp.Receive(ref ep);
                Handle(Encoding.UTF8.GetString(b));
            }
        }
        catch { }
        helloT -= dt; carT -= dt; aiT -= dt; startT -= dt;
        if (helloT <= 0) { helloT = state == ST_LOBBY ? 0.35 : 1.0; NetSend("F1GP|HELLO|" + myId + "|" + myName + "|" + StChar()); }
        if (startRepeat > 0 && startT <= 0) { startT = 0.12; startRepeat--; NetSend(startMsg); }
        bool racing = state == ST_COUNT || state == ST_RACE || state == ST_FINISH;
        if (racing && curRace != 0 && RemoteHumans() > 0)
        {
            if (carT <= 0)
            {
                carT = 0.05;
                NetSend("F1GP|CAR|" + myId + "|" + curRace + "|" + D(cz[0]) + "|" + claps[0] + "|" + D(cx[0]) + "|" + D(cspd[0]) + "|" + ((braking ? 1 : 0) | (boosting ? 2 : 0)) + "|" + D(cfin[0]) + "|" + D(cbest[0]));
            }
            if (aiT <= 0 && IsHost())
            {
                aiT = 0.066;
                StringBuilder a = new StringBuilder();
                for (int i = 1; i < NCAR; i++)
                {
                    if (ckind[i] != 2) continue;
                    if (a.Length > 0) a.Append(';');
                    a.Append(cslot[i]).Append(':').Append(D(cz[i])).Append(':').Append(claps[i]).Append(':').Append(D(cx[i])).Append(':').Append(D(cspd[i])).Append(':').Append(cbrk[i] ? 1 : 0).Append(':').Append(D(cfin[i])).Append(':').Append(D(cbest[i]));
                }
                NetSend("F1GP|AI|" + myId + "|" + curRace + "|" + a);
            }
        }
        List<long> dead = new List<long>();
        foreach (KeyValuePair<long, Peer> kv in peers) if (gt - kv.Value.last > 6) dead.Add(kv.Key);
        foreach (long id in dead) peers.Remove(id);
    }

    static void Handle(string m)
    {
        string[] p = m.Split('|');
        if (p.Length < 3 || p[0] != "F1GP") return;
        long id; if (!long.TryParse(p[2], out id) || id == myId) return;
        Peer pe;
        if (p[1] == "BYE") { peers.Remove(id); for (int i = 1; i < NCAR; i++) if (ckind[i] == 1 && cnid[i] == id) cgone[i] = true; return; }
        if (!peers.TryGetValue(id, out pe)) { pe = new Peer(); peers[id] = pe; }
        pe.last = gt;
        switch (p[1])
        {
            case "HELLO":
                if (p.Length >= 5) { string n = CleanName(p[3]); if (n.Length > 0) pe.name = n; if (p[4].Length > 0) pe.st = p[4][0]; }
                break;
            case "START":
                if (p.Length >= 6 && state == ST_LOBBY)
                {
                    int race = (int)P(p[3]);
                    List<long> ids = new List<long>();
                    foreach (string q in p[5].Split(',')) { long v; if (long.TryParse(q, out v)) ids.Add(v); }
                    if (race != curRace && ids.Contains(myId)) StartCountdown(ids.ToArray(), (int)P(p[4]), race);
                }
                break;
            case "CAR":
                if (p.Length >= 11 && (int)P(p[3]) == curRace)
                    for (int i = 1; i < NCAR; i++)
                        if (ckind[i] == 1 && cnid[i] == id)
                        {
                            nProg[i] = (int)P(p[5]) * trackLen + P(p[4]); nX[i] = P(p[6]); nSpd[i] = P(p[7]); nTime[i] = gt;
                            int fl = (int)P(p[8]); cbrk[i] = (fl & 1) != 0;
                            double f = P(p[9]); if (f >= 0) cfin[i] = f;
                            cbest[i] = P(p[10]); cgone[i] = false;
                        }
                break;
            case "AI":
                if (p.Length >= 5 && (int)P(p[3]) == curRace && !IsHost())
                    foreach (string e in p[4].Split(';'))
                    {
                        string[] f = e.Split(':');
                        if (f.Length < 8) continue;
                        int sl = (int)P(f[0]);
                        for (int i = 1; i < NCAR; i++)
                            if (ckind[i] == 2 && cslot[i] == sl)
                            {
                                nProg[i] = (int)P(f[2]) * trackLen + P(f[1]); nX[i] = P(f[3]); nSpd[i] = P(f[4]); nTime[i] = gt;
                                cbrk[i] = f[5] == "1"; double fi = P(f[6]); if (fi >= 0) cfin[i] = fi; cbest[i] = P(f[7]);
                            }
                    }
                break;
        }
    }

    // los coches de otros ordenadores se mueven con lo ultimo recibido, prediciendo un poco hacia delante
    static void NetDrive(int i, double dt)
    {
        if (cgone[i] || nTime[i] < 0) return;
        double age = Math.Min(0.6, gt - nTime[i]);
        double pred = nProg[i] + nSpd[i] * age;
        int lp = (int)Math.Floor(pred / trackLen);
        claps[i] = lp; cz[i] = pred - lp * trackLen;
        cx[i] += (nX[i] - cx[i]) * Math.Min(1, dt * 12);
        cspd[i] = nSpd[i];
        if (ckind[i] == 1 && gt - nTime[i] > 5) cgone[i] = true;
    }

    static string PeerName(long id) { Peer pe; return peers.TryGetValue(id, out pe) ? pe.name : "PILOTO"; }

    static int RemoteHumans() { int n = 0; for (int i = 1; i < NCAR; i++) if (ckind[i] == 1 && !cgone[i]) n++; return n; }

    // el anfitrion (el de id mas bajo) es quien mueve a los pilotos IA para todos
    static bool IsHost()
    {
        if (state != ST_COUNT && state != ST_RACE && state != ST_FINISH) return true;
        for (int i = 1; i < NCAR; i++) if (ckind[i] == 1 && !cgone[i] && cnid[i] < myId) return false;
        return true;
    }

    static double LeadHuman()
    {
        double m = Prog(0);
        for (int i = 1; i < NCAR; i++) if (ckind[i] == 1 && !cgone[i]) m = Math.Max(m, Prog(i));
        return m;
    }

    static List<long> LobbyIds()
    {
        List<long> l = new List<long>(); l.Add(myId);
        foreach (KeyValuePair<long, Peer> kv in peers) if (kv.Value.st == 'L' && gt - kv.Value.last < 3) l.Add(kv.Key);
        l.Sort();
        return l;
    }

    static bool LobbyHost() { return LobbyIds()[0] == myId; }

    static void HostStart()
    {
        List<long> ids = LobbyIds();
        while (ids.Count > NCAR) ids.RemoveAt(ids.Count - 1);
        int seed = rnd.Next(1, 1 << 30), race = rnd.Next(1, 1 << 30);
        StringBuilder l = new StringBuilder();
        foreach (long v in ids) { if (l.Length > 0) l.Append(','); l.Append(v); }
        startMsg = "F1GP|START|" + myId + "|" + race + "|" + seed + "|" + l;
        startRepeat = 8; startT = 0;
        StartCountdown(ids.ToArray(), seed, race);
    }

    // ---------------------------------------------------------------- pantalla del nombre
    static void NamePix()
    {
        for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Rgb(5, 3, 15), 0.5);
        int w = BigW("F1", 1);
        BigPix("F1", (W - w) / 2, 2, 1, Rgb(255, 70, 50), Rgb(170, 0, 15), Rgb(90, 0, 10), Frac(gt / 3) * (w + 30) - 15);
        int y = Math.Max(10, H / 2 - 5);
        Panel(W / 2 - 25, y, 50, 9, 0.85, Rgb(225, 15, 25));
        for (int py = (y + 4) * 2; py < (y + 5) * 2; py++) for (int px = W / 2 - 16; px < W / 2 + 16; px++) PB(px, py, Rgb(255, 255, 255), 0.12);
    }

    static void NameText()
    {
        int y = Math.Max(10, H / 2 - 5);
        TSC(y + 1, "PILOTO, COMO TE LLAMAS?", Rgb(255, 215, 0));
        TSC(y + 2, "Escribe tu nombre (maximo 12 letras)", Rgb(180, 180, 195));
        string shown = nameBuf + (((int)(gt * 3)) % 2 == 0 ? "_" : " ");
        TS(W / 2 - 15, y + 4, shown, Rgb(255, 255, 255));
        TSC(y + 6, "ENTER: CONTINUAR     BORRAR: corregir", Rgb(230, 230, 240));
        TSC(y + 7, "ESC: salir", Rgb(150, 155, 175));
    }

    // ---------------------------------------------------------------- sala online
    static void LobbyPix()
    {
        for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Rgb(5, 3, 15), 0.5);
        int h = Math.Min(H - 3, 26);
        Panel(W / 2 - 34, 1, 68, h, 0.85, Rgb(0, 200, 255));
        Panel(W / 2 - 31, 6, 62, Math.Min(9, H - 15), 0.5, -1);
    }

    static void LobbyText()
    {
        int x = W / 2 - 32, wh = Rgb(255, 255, 255), gr = Rgb(150, 155, 175);
        TSC(2, "SALA ONLINE  -  RED LOCAL", Rgb(0, 230, 255));
        if (udp == null) TSC(3, netErr, Rgb(255, 90, 70));
        else TSC(3, "Tu IP: " + (myIp.Length > 0 ? myIp : "?") + "     Puerto UDP " + PORT, gr);
        TS(x + 2, 5, "PILOTO          ESTADO", Rgb(255, 215, 0));
        List<long> ids = new List<long>(); ids.Add(myId);
        foreach (long k in peers.Keys) ids.Add(k);
        ids.Sort();
        List<long> lobby = LobbyIds();
        int row = 0, maxRows = Math.Min(9, H - 15);
        foreach (long id in ids)
        {
            if (row >= maxRows) break;
            bool me = id == myId;
            Peer pe = null; if (!me) peers.TryGetValue(id, out pe);
            char st = me ? 'L' : pe.st;
            string nm = me ? myName : pe.name;
            string stt = st == 'L' ? "EN LA SALA" : st == 'R' ? "CORRIENDO" : st == 'F' ? "EN META" : "EN EL MENU";
            int sc = st == 'L' ? Rgb(0, 255, 120) : st == 'R' || st == 'F' ? Rgb(255, 170, 0) : gr;
            int y = 6 + row;
            TS(x + 2, y, (me ? "\u25ba " : "  ") + nm, me ? Rgb(255, 230, 0) : wh);
            TS(x + 18, y, stt, sc);
            if (lobby[0] == id) TS(x + 31, y, "ANFITRION", Rgb(255, 215, 0));
            if (me) TS(x + 42, y, "(TU)", Rgb(255, 230, 0));
            row++;
        }
        int fy = 6 + maxRows + 1;
        TSC(fy, "En la sala: " + lobby.Count + "/" + NCAR + "  (el resto seran pilotos IA)", wh);
        if (LobbyHost())
        {
            if (((int)(gt * 2.5)) % 2 == 0) TSC(fy + 2, ">>  ENTER: EMPEZAR LA CARRERA  <<", Rgb(255, 255, 255));
        }
        else TSC(fy + 2, "Esperando a que " + PeerName(lobby[0]) + " empiece la carrera...", Rgb(255, 215, 0));
        TSC(fy + 4, "Abrid este mismo .bat en la misma red (WiFi o cable).", gr);
        TSC(fy + 5, "Si no sale nadie: permite PowerShell en el Firewall.", gr);
        TSC(fy + 6, "ESC: salir", gr);
    }

    // ================================================================ bucle
    static void Frame(double dt)
    {
        gt += dt;
        if (kEsc) { quit = true; return; }
        NetTick(dt);
        if (kPause && state == ST_RACE)
        {
            if (RemoteHumans() > 0) Msg("EN ONLINE NO SE PUEDE PAUSAR", Rgb(255, 200, 0), 1.5);
            else paused = !paused;
        }
        if (!paused) Update(dt);
        Render();
    }

    static void Update(double dt)
    {
        stT += dt;
        UpdParts(dt);
        shake = Math.Max(0, shake - dt * 2.2);
        crashCool = Math.Max(0, crashCool - dt);
        switch (state)
        {
            case ST_TITLE:
                UpdatePlayer(dt, true, 0.95); UpdateAI(dt); SortOrder();
                if (kEnter) { state = ST_NAME; stT = 0; nameBuf = myName == "PILOTO" ? "" : myName; }
                break;
            case ST_NAME:
                UpdatePlayer(dt, true, 0.95); UpdateAI(dt); SortOrder();
                NameInput();
                break;
            case ST_LOBBY:
                UpdatePlayer(dt, true, 0.95); UpdateAI(dt); SortOrder();
                if (kEnter && LobbyHost()) HostStart();
                break;
            case ST_COUNT:
                UpdatePlayer(dt, dumping, 1); UpdateAI(dt); SortOrder();
                if (stT >= lightsOutT) { state = ST_RACE; stT = 0; raceT = 0; }
                break;
            case ST_RACE:
                raceT += dt;
                UpdatePlayer(dt, dumping, 1.2); UpdateAI(dt); SortOrder();
                int p = PosOf(0);
                if (raceT > 3 && p != prevPos && state == ST_RACE)
                {
                    if (p < prevPos) Msg("ADELANTAMIENTO!  P" + (p + 1), Rgb(0, 255, 120), 1.6);
                    else Msg("PIERDES UNA POSICION  P" + (p + 1), Rgb(255, 80, 60), 1.4);
                }
                prevPos = p;
                break;
            case ST_FINISH:
                raceT += dt;
                UpdatePlayer(dt, true, 0.55); UpdateAI(dt); SortOrder();
                if (finishPos <= 3 && Frac(stT / 0.7) < dt / 0.7)
                    PSpawn(6, PW * (0.1 + rnd.NextDouble() * 0.8), PH * 0.55, (rnd.NextDouble() - 0.5) * 10, -45 - rnd.NextDouble() * 15, 0.6 + rnd.NextDouble() * 0.3, Rgb(255, 255, 220), 1);
                if (kEnter && stT > 1.5) BackToLobby();
                break;
        }
    }

    static double CurveAhead(int s, int look)
    {
        double ca = 0;
        for (int k = 0; k < look; k++) { double c = segCurve[(s + k) % NSeg]; if (Math.Abs(c) > Math.Abs(ca)) ca = c; }
        return ca;
    }

    static void AutoKeys(out bool up, out bool down, out bool left, out bool right, out bool boost, double maxPct)
    {
        int s = SegAt(cz[0]); double spct = cspd[0] / MAXSPD;
        double ca = CurveAhead(s, 8 + (int)(spct * 45));
        double vlim = Math.Abs(ca) < 0.5 ? 2 : Math.Sqrt(0.8 / (Math.Abs(ca) * CENTRI));
        vlim = Math.Min(vlim, maxPct);
        double want = -Math.Sign(ca) * Math.Min(1, Math.Abs(ca) / 5) * 0.3;
        for (int j = 1; j < NCAR; j++)
        {
            double dz = Wrapd(cz[j] - cz[0]);
            if (dz > 0 && dz < SEG * 8 && cspd[j] < cspd[0] + 600 && Math.Abs(cx[j] - want) < 0.42) want = cx[j] > 0 ? cx[j] - 0.62 : cx[j] + 0.62;
        }
        want = Math.Max(-0.75, Math.Min(0.75, want));
        left = cx[0] > want + 0.03; right = cx[0] < want - 0.03;
        up = spct < vlim; down = spct > vlim + 0.06;
        boost = Math.Abs(ca) < 0.5 && spct > 0.55 && energy > 0.35 && maxPct > 1;
    }

    static void UpdatePlayer(double dt, bool auto, double maxPct)
    {
        bool up, down, left, right, boost;
        if (auto) AutoKeys(out up, out down, out left, out right, out boost, maxPct);
        else { up = kUp; down = kDown; left = kLeft; right = kRight; boost = kBoost; }
        thrVis += ((up ? 1 : 0) - thrVis) * Math.Min(1, dt * 12);
        brkVis += ((down ? 1 : 0) - brkVis) * Math.Min(1, dt * 12);
        braking = down;
        if (state == ST_COUNT)
        {
            cspd[0] = 0; boosting = false;
            rpm = up ? 0.8 + 0.15 * Math.Sin(gt * 35) : 0.22 + 0.03 * Math.Sin(gt * 20);
            return;
        }
        double spct = cspd[0] / MAXSPD;
        int s = SegAt(cz[0]); double curve = segCurve[s];
        double dx = dt * 2.0 * Math.Min(1, spct * 1.15);
        if (left) cx[0] -= dx; else if (right) cx[0] += dx;
        steerVis += ((left ? -1 : right ? 1 : 0) - steerVis) * Math.Min(1, dt * 9);
        cx[0] -= dx * spct * curve * CENTRI;

        boosting = boost && up && energy > 0.02;
        if (boosting) energy = Math.Max(0, energy - dt * 0.22);
        else energy = Math.Min(1, energy + dt * (down ? 0.16 : 0.035));
        double top = MAXSPD * (boosting ? 1.12 : 1.0);
        if (up) cspd[0] += MAXSPD / 4.0 * (1 - 0.55 * spct) * (boosting ? 1.5 : 1) * dt;
        else if (down) cspd[0] -= MAXSPD * 1.15 * dt;
        else cspd[0] -= MAXSPD / 7 * dt;
        if (cspd[0] > top) cspd[0] = Math.Max(top, cspd[0] - MAXSPD / 3 * dt);

        double ax = Math.Abs(cx[0]);
        onKerb = ax > 0.97 && ax < 1.16; offRoad = ax >= 1.16;
        if (offRoad)
        {
            if (cspd[0] > MAXSPD / 4) cspd[0] -= MAXSPD * 0.8 * dt;
            shake = Math.Max(shake, 0.3 * spct + 0.05);
        }
        if (onKerb && spct > 0.3) shake = Math.Max(shake, 0.15);

        // choques contra el decorado
        if (ax > 1.2 && crashCool <= 0)
        {
            for (int q = 0; q < 2 && crashCool <= 0; q++)
                foreach (Spr sp in segSpr[(s + q) % NSeg])
                {
                    if (!sp.hit) continue;
                    double half = sp.s.ww / 2 / ROADW;
                    double c = sp.off < -0.01 ? sp.off - half : sp.off > 0.01 ? sp.off + half : sp.off;
                    if (Math.Abs(cx[0] - c) < half * 0.85 + 0.15) { Crash(); break; }
                }
        }
        // choques con otros coches
        for (int j = 1; j < NCAR; j++)
        {
            double dz = Wrapd(cz[j] - cz[0]), ddx = cx[j] - cx[0];
            if (Math.Abs(ddx) >= 0.33 || cgone[j]) continue;
            if (dz > 0 && dz < 170 && cspd[0] > cspd[j])
            {
                cspd[0] = cspd[j] * 0.82; cz[0] = Wrap(cz[j] - 170);
                Bump();
            }
            else if (dz <= 0 && dz > -170 && cspd[j] > cspd[0] && ckind[j] == 2 && IsHost()) cspd[j] = cspd[0] * 0.9;
        }
        cx[0] = Math.Max(-2.6, Math.Min(2.6, cx[0]));
        cspd[0] = Math.Max(0, cspd[0]);
        Advance(0, cspd[0] * dt);
        dist += cspd[0] * dt;

        double kmh = Kmh();
        double[] gl = { 0, 95, 130, 165, 200, 235, 270, 305, 400 };
        int g = 1; while (g < 8 && kmh >= gl[g]) g++;
        gear = g;
        rpm = Cl(0.5 + 0.5 * (kmh - gl[g - 1]) / (gl[g] - gl[g - 1]));
        if (g == 8) rpm = Cl(0.55 + 0.45 * (kmh - 305) / 60);

        // efectos
        double carW = Math.Round(PW * 0.34), carH = carW * 18 / 40;
        double carX = PW / 2.0 - carW / 2, carY = PH - carH - Math.Max(2, PH / 40);
        double tyL = carX + carW * 0.1, tyR = carX + carW * 0.9, tyY = carY + carH * 0.9;
        if ((state == ST_RACE && raceT < 1.6 && up && spct < 0.45) || (down && spct > 0.6 && rnd.NextDouble() < 0.5))
            for (int k = 0; k < 2; k++) { PSpawn(0, tyL + (rnd.NextDouble() - 0.5) * 4, tyY, -8 - rnd.NextDouble() * 10, 10 + rnd.NextDouble() * 10, 0.9, Rgb(220, 220, 225), 2.2); PSpawn(0, tyR + (rnd.NextDouble() - 0.5) * 4, tyY, 8 + rnd.NextDouble() * 10, 10 + rnd.NextDouble() * 10, 0.9, Rgb(220, 220, 225), 2.2); }
        if (offRoad && spct > 0.05)
            for (int k = 0; k < 3; k++) PSpawn(4, (k % 2 == 0 ? tyL : tyR) + (rnd.NextDouble() - 0.5) * 5, tyY, (rnd.NextDouble() - 0.5) * 30, -10 - rnd.NextDouble() * 20, 0.7, k == 0 ? Rgb(60, 150, 50) : Rgb(170, 140, 90), 1.6);
        if ((spct > 0.82 && rnd.NextDouble() < 0.35) || (onKerb && spct > 0.4 && rnd.NextDouble() < 0.6))
            for (int k = 0; k < 4; k++) PSpawn(1, carX + carW * (0.35 + rnd.NextDouble() * 0.3), carY + carH * 0.86, (rnd.NextDouble() - 0.5) * 70, 30 + rnd.NextDouble() * 50, 0.35 + rnd.NextDouble() * 0.2, 0, 1);
        if (boosting)
            for (int k = 0; k < 3; k++) PSpawn(3, carX + carW / 2 + (rnd.NextDouble() - 0.5) * 2, carY + carH * 0.6, (rnd.NextDouble() - 0.5) * 8, 12 + rnd.NextDouble() * 12, 0.3, 0, 1.5);
    }
    static int gear = 1;

    static void Crash()
    {
        cspd[0] = MAXSPD / 7; shake = 1.2; crashCool = 1.2;
        double carW = Math.Round(PW * 0.34), carH = carW * 18 / 40, carY = PH - carH - Math.Max(2, PH / 40);
        for (int k = 0; k < 40; k++) PSpawn(5, PW / 2.0 + (rnd.NextDouble() - 0.5) * carW, carY + carH * 0.5, (rnd.NextDouble() - 0.5) * 80, -20 - rnd.NextDouble() * 40, 1 + rnd.NextDouble(), k % 3 == 0 ? cmain[0] : Rgb(25, 25, 28), 1);
        for (int k = 0; k < 30; k++) PSpawn(1, PW / 2.0 + (rnd.NextDouble() - 0.5) * carW, carY + carH * 0.7, (rnd.NextDouble() - 0.5) * 120, -10 - rnd.NextDouble() * 50, 0.5, 0, 1);
        if (state == ST_RACE) Msg("CHOQUE!", Rgb(255, 50, 40), 1.4);
    }

    static void Bump()
    {
        shake = Math.Max(shake, 0.8);
        double carW = Math.Round(PW * 0.34), carH = carW * 18 / 40, carY = PH - carH - Math.Max(2, PH / 40);
        for (int k = 0; k < 18; k++) PSpawn(1, PW / 2.0 + (rnd.NextDouble() - 0.5) * carW * 0.6, carY + 2, (rnd.NextDouble() - 0.5) * 90, -20 - rnd.NextDouble() * 40, 0.4, 0, 1);
        if (state == ST_RACE && crashCool <= 0) { Msg("CONTACTO!", Rgb(255, 160, 0), 1.0); crashCool = 0.6; }
    }

    static void UpdateAI(double dt)
    {
        bool host = IsHost();
        for (int i = 1; i < NCAR; i++)
        {
            if (ckind[i] == 1 || (ckind[i] == 2 && !host)) { NetDrive(i, dt); continue; }
            if (state == ST_COUNT) { cspd[i] = 0; continue; }
            if (state == ST_RACE && raceT < cdelay[i]) continue;
            int s = SegAt(cz[i]);
            double ca = CurveAhead(s, 30);
            double tgt = ctop[i] * (1 - Math.Min(0.3, Math.Abs(ca) * 0.042));
            if (state == ST_RACE || state == ST_FINISH)
            {
                double d = (Prog(i) - LeadHuman()) / trackLen;
                if (cfin[0] < 0) { if (d > 0) tgt *= 1 - Math.Min(0.07, d * 0.6); else tgt *= 1 + Math.Min(0.05, -d * 0.4); }
            }
            if (cfin[i] >= 0) tgt = ctop[i] * 0.5;
            bool acc = cspd[i] < tgt;
            if (acc) cspd[i] = Math.Min(tgt, cspd[i] + MAXSPD / 4.4 * (1 - 0.5 * cspd[i] / MAXSPD) * dt);
            else cspd[i] = Math.Max(tgt, cspd[i] - MAXSPD / 1.6 * dt);
            cbrk[i] = !acc && cspd[i] - tgt > 1;
            double want = cline[i] - Math.Sign(ca) * Math.Min(1, Math.Abs(ca) / 5) * 0.4;
            for (int j = 0; j < NCAR; j++)
            {
                if (j == i) continue;
                double dz = Wrapd(cz[j] - cz[i]);
                if (dz > 0 && dz < SEG * 6 && cspd[j] < cspd[i] && Math.Abs(cx[j] - want) < 0.42) want = cx[j] > 0 ? cx[j] - 0.6 : cx[j] + 0.6;
            }
            want = Math.Max(-0.8, Math.Min(0.8, want));
            cx[i] += Math.Max(-dt * 0.9, Math.Min(dt * 0.9, want - cx[i]));
            Advance(i, cspd[i] * dt);
        }
    }

    // ================================================================ particulas (en pixeles)
    // 0 humo, 1 chispa, 2 confeti, 3 llama ERS, 4 tierra/hierba, 5 trozos, 6 cohete, 7 fuego artificial
    const int PMAX = 1200;
    static double[] qx = new double[PMAX], qy = new double[PMAX], qvx = new double[PMAX], qvy = new double[PMAX], ql = new double[PMAX], qm = new double[PMAX], qs = new double[PMAX];
    static int[] qt = new int[PMAX], qc = new int[PMAX]; static int pn;
    static readonly int[] NEONS = { Rgb(255, 40, 60), Rgb(255, 215, 0), Rgb(0, 230, 255), Rgb(120, 255, 80), Rgb(255, 80, 220), Rgb(255, 255, 255), Rgb(255, 140, 0) };

    static void PSpawn(int type, double x, double y, double vx, double vy, double life, int col, double size)
    {
        if (pn >= PMAX) return;
        qt[pn] = type; qx[pn] = x; qy[pn] = y; qvx[pn] = vx; qvy[pn] = vy; ql[pn] = life; qm[pn] = life; qc[pn] = col; qs[pn] = size; pn++;
    }

    static void UpdParts(double dt)
    {
        for (int i = 0; i < pn; i++)
        {
            ql[i] -= dt;
            if (ql[i] <= 0)
            {
                if (qt[i] == 6)
                {
                    int c = NEONS[rnd.Next(NEONS.Length)];
                    for (int k = 0; k < 50; k++)
                    {
                        double a = rnd.NextDouble() * Math.PI * 2, v = 10 + rnd.NextDouble() * 25;
                        PSpawn(7, qx[i], qy[i], Math.Cos(a) * v * 1.4, Math.Sin(a) * v, 0.8 + rnd.NextDouble() * 0.7, c, 1);
                    }
                }
                pn--; qt[i] = qt[pn]; qx[i] = qx[pn]; qy[i] = qy[pn]; qvx[i] = qvx[pn]; qvy[i] = qvy[pn]; ql[i] = ql[pn]; qm[i] = qm[pn]; qc[i] = qc[pn]; qs[i] = qs[pn]; i--;
                continue;
            }
            double g = 0, drag = 1;
            switch (qt[i]) { case 0: g = -4; drag = 2; break; case 1: g = 90; break; case 2: g = 12; drag = 1.5; break; case 3: g = 0; drag = 3; break; case 4: g = 60; break; case 5: g = 70; break; case 7: g = 18; drag = 1.2; break; }
            qvy[i] += g * dt; qvx[i] *= 1 - Math.Min(0.9, drag * dt); if (qt[i] == 0 || qt[i] == 2 || qt[i] == 7) qvy[i] *= 1 - Math.Min(0.9, drag * dt * 0.5);
            if (qt[i] == 2) qx[i] += Math.Sin(ql[i] * 7 + i) * 8 * dt;
            qx[i] += qvx[i] * dt; qy[i] += qvy[i] * dt;
            if (qt[i] == 6) PSpawn(1, qx[i], qy[i] + 1, (rnd.NextDouble() - 0.5) * 6, 8, 0.25, 0, 1);
        }
    }

    static void DrawParts()
    {
        for (int i = 0; i < pn; i++)
        {
            double f = ql[i] / qm[i];
            int x = (int)Math.Floor(qx[i]), y = (int)Math.Floor(qy[i]);
            switch (qt[i])
            {
                case 0: PDisc(qx[i], qy[i], qs[i] * (1 + (1 - f) * 2.5), qs[i] * (1 + (1 - f) * 2.5) * 0.8, qc[i], 0.42 * f); break;
                case 1:
                    PS(x, y, Lerp(Rgb(255, 90, 0), Rgb(255, 250, 200), f));
                    PB((int)(qx[i] - qvx[i] * 0.03), (int)(qy[i] - qvy[i] * 0.03), Rgb(255, 160, 40), 0.7 * f);
                    break;
                case 2: PS(x, y, ((int)(ql[i] * 10 + i)) % 3 == 0 ? Scale(qc[i], 0.55) : qc[i]); break;
                case 3: PDisc(qx[i], qy[i], 1.4, 1.2, Lerp(Rgb(40, 80, 255), Rgb(200, 240, 255), f), 0.85 * f); break;
                case 4: PDisc(qx[i], qy[i], qs[i], qs[i], qc[i], 0.75 * f); break;
                case 5: PS(x, y, qc[i]); break;
                case 6: PS(x, y, Rgb(255, 255, 230)); PS(x, y - 1, Rgb(255, 255, 255)); break;
                case 7: PS(x, y, Scale(qc[i], 0.3 + 0.7 * f)); if (f > 0.5) PB(x - (int)(qvx[i] * 0.04), y - (int)(qvy[i] * 0.04), qc[i], 0.5 * f); break;
            }
        }
    }

    // ================================================================ render del mundo
    static readonly int FOG = Rgb(225, 135, 105);
    static double skyOff;
    static double[] prX1 = new double[DRAWD], prY1 = new double[DRAWD], prS1 = new double[DRAWD], prX2 = new double[DRAWD], prY2 = new double[DRAWD], prS2 = new double[DRAWD], prFog = new double[DRAWD];
    static int[] prSeg = new int[DRAWD], prClip = new int[DRAWD]; static bool[] prOk = new bool[DRAWD];
    static List<int>[] bucket = new List<int>[DRAWD];

    static int SkyCol(double t)
    {
        if (t < 0.5) return Lerp(Rgb(14, 8, 42), Rgb(72, 26, 108), t / 0.5);
        if (t < 0.82) return Lerp(Rgb(72, 26, 108), Rgb(205, 72, 110), (t - 0.5) / 0.32);
        return Lerp(Rgb(205, 72, 110), Rgb(255, 165, 95), (t - 0.82) / 0.18);
    }

    static void RenderSky()
    {
        int hz = PH / 2;
        for (int y = 0; y < PH; y++)
        {
            int c = y < hz ? SkyCol((double)y / hz) : Rgb(20, 95, 45);
            for (int x = 0; x < PW; x++) pix[y * PW + x] = c;
        }
        // estrellas arriba
        for (int k = 0; k < PW / 3; k++)
        {
            int sx = (int)(Hash(k, 1, 77) * PW), sy = (int)(Hash(k, 2, 77) * hz * 0.4);
            double tw = 0.5 + 0.5 * Math.Sin(gt * 3 + k);
            PB(sx, sy, Rgb(255, 255, 255), 0.25 + 0.35 * tw);
        }
        // sol con brillo
        double period = PW * 2.2;
        double scx = Frac((PW * 0.7 - skyOff * 0.15) / period) * period - PW * 0.4, scy = hz - PH * 0.17, sr = PH * 0.1;
        for (int y = Math.Max(0, (int)(scy - sr * 2.6)); y < hz; y++)
            for (int x = Math.Max(0, (int)(scx - sr * 2.6)); x < Math.Min(PW, (int)(scx + sr * 2.6)); x++)
            {
                double dx = x + 0.5 - scx, dy = (y + 0.5 - scy), d = Math.Sqrt(dx * dx + dy * dy) / sr;
                if (d < 1)
                {
                    if (dy > 0 && ((int)(dy * 1.2)) % 3 == 2) continue;
                    pix[y * PW + x] = Lerp(Rgb(255, 245, 160), Rgb(255, 80, 110), (dy / sr + 1) / 2);
                }
                else if (d < 2.6) PB(x, y, Rgb(255, 170, 120), 0.35 * Math.Pow(1 - (d - 1) / 1.6, 2));
            }
        // nubes
        for (int k = 0; k < 5; k++)
        {
            double cxl = Frac(Hash(k, 3, 7) + (gt * 0.6 - skyOff * 0.2) / (PW * 3)) * PW * 1.6 - PW * 0.3;
            double cyl = hz * (0.25 + Hash(k, 4, 7) * 0.45), rx = 9 + Hash(k, 5, 7) * 14;
            PDisc(cxl, cyl, rx, 1.6, Rgb(255, 150, 170), 0.35);
            PDisc(cxl + rx * 0.3, cyl - 1, rx * 0.6, 1.4, Rgb(255, 190, 190), 0.3);
        }
        // montanas
        for (int x = 0; x < PW; x++)
        {
            double u = (x + skyOff * 0.25) * 0.05;
            double mh = PH * 0.12 * (0.6 + 0.25 * Math.Sin(u + 1.3) + 0.15 * Math.Sin(u * 2.3 + 0.5) + 0.08 * Math.Sin(u * 5.1));
            int top = (int)(hz - mh);
            for (int y = Math.Max(0, top); y < hz; y++) pix[y * PW + x] = Lerp(Rgb(95, 45, 120), Rgb(175, 90, 135), (double)(y - top) / Math.Max(1, mh));
        }
        // ciudad con ventanas encendidas
        for (int x = 0; x < PW; x++)
        {
            double v = x + skyOff * 0.5;
            int b = (int)Math.Floor(v / 7);
            if (Hash(b, 1, 5) < 0.3) continue;
            int bh = (int)(3 + Hash(b, 0, 5) * PH * 0.1);
            int lx = (int)Math.Floor(v) - b * 7;
            if (lx == 6) continue;
            for (int y = hz - bh; y < hz; y++)
            {
                bool wnd = lx % 2 == 1 && (y - hz) % 2 == 0 && Hash(b * 7 + lx, y, 6) > 0.55;
                PS(x, y, wnd ? Rgb(255, 205, 120) : Rgb(42, 28, 72));
            }
        }
        // arboleda
        for (int x = 0; x < PW; x++)
        {
            double v = x + skyOff;
            int th = (int)(2 + 2.2 * (0.5 + 0.5 * Math.Sin(v * 0.7)) + Hash((int)Math.Floor(v / 3), 0, 8) * 2);
            for (int y = hz - th; y < hz; y++) PS(x, y, Rgb(22, 58, 42));
        }
    }

    static void RoadRow(int py, double cx0, double w, int i, double fog, double t)
    {
        bool light = (i / RUMBLE) % 2 == 0;
        int grass = light ? Rgb(28, 150, 58) : Rgb(20, 128, 48);
        int road = light ? Rgb(92, 92, 100) : Rgb(86, 86, 94);
        int kerb = light ? Rgb(225, 25, 35) : Rgb(245, 245, 245);
        double kw = w / 6.5, gw = Math.Abs(segCurve[i]) >= 2.5 ? w * 0.5 : 0, lw = Math.Max(0.55, w / 40);
        int gside = -Math.Sign(segCurve[i]);
        bool start = i < 2, gridMark = i >= NSeg - 36 && (i % 4 == 1);
        int row = py * PW;
        for (int px = 0; px < PW; px++)
        {
            double d = px + 0.5 - cx0, ad = Math.Abs(d);
            int c;
            if (ad < w)
            {
                if (start) { int k = (int)Math.Floor((d + w) / (w / 10)); int r2 = t < 0.5 ? 0 : 1; c = (k + r2) % 2 == 0 ? Rgb(245, 245, 245) : Rgb(15, 15, 15); }
                else if (ad > w - lw * 1.3) c = Rgb(240, 240, 240);
                else if (gridMark && ad > w * 0.25 && ad < w * 0.62) c = Rgb(230, 230, 230);
                else
                {
                    c = road;
                    if (ad < w * 0.22) c = Scale(c, 0.85);
                    int nz = (int)((Hash((int)((d / w) * 30), i, 2) - 0.5) * 10);
                    c = Add(c, Rgb(nz > 0 ? nz : 0, nz > 0 ? nz : 0, nz > 0 ? nz : 0));
                }
            }
            else if (ad < w + kw) c = kerb;
            else if (gw > 0 && Math.Sign(d) == gside && ad < w + kw + gw) c = ((int)(Hash((int)(d / w * 40), i, 3) * 3)) == 0 ? Rgb(190, 165, 115) : Rgb(212, 186, 135);
            else
            {
                c = grass;
                if (((int)Math.Floor(d / (w * 0.8))) % 2 == 0) c = Scale(c, 0.93);
            }
            if (fog < 0.999) c = Lerp(FOG, c, fog);
            pix[row + px] = c;
        }
    }

    static void RenderWorld(double depth)
    {
        RenderSky();
        double camZ = Wrap(cz[0] - PLAYERZ);
        int baseSeg = SegAt(camZ); double basePct = Frac(camZ / SEG);
        int ps = SegAt(cz[0]); double pp = Frac(cz[0] / SEG);
        double camY = CAMH + Lp(segY[ps], segY[ps + 1], pp);
        double camX = cx[0] * ROADW;
        double x = 0, dx = -(segCurve[baseSeg] * basePct);
        int maxy = PH;
        for (int n = 0; n < DRAWD; n++)
        {
            int i = (baseSeg + n) % NSeg;
            double loopZ = baseSeg + n >= NSeg ? trackLen : 0;
            double z1 = i * SEG + loopZ - camZ, z2 = z1 + SEG;
            prSeg[n] = i; prClip[n] = maxy; prFog[n] = Math.Exp(-Math.Pow((double)n / DRAWD, 2) * 3.0);
            double s1 = z1 > 1 ? depth / z1 : depth, s2 = depth / Math.Max(1, z2);
            double X1 = PW / 2.0 + s1 * (x - camX) * PW / 2, Y1 = PH / 2.0 - s1 * (segY[i] - camY) * PH / 2, W1 = s1 * ROADW * PW / 2;
            double X2 = PW / 2.0 + s2 * (x + dx - camX) * PW / 2, Y2 = PH / 2.0 - s2 * (segY[i + 1] - camY) * PH / 2, W2 = s2 * ROADW * PW / 2;
            x += dx; dx += segCurve[i];
            prX1[n] = X1; prY1[n] = Y1; prS1[n] = s1; prX2[n] = X2; prY2[n] = Y2; prS2[n] = s2; prOk[n] = z1 > 1;
            if (z1 <= 1 || Y2 >= Y1 || Y2 >= maxy) continue;
            int yTop = Math.Max(0, (int)Math.Ceiling(Y2)), yBot = Math.Min(Math.Min(maxy - 1, PH - 1), (int)Math.Ceiling(Y1) - 1);
            for (int py = yTop; py <= yBot; py++)
            {
                double t = Cl((Y1 - (py + 0.5)) / (Y1 - Y2));
                RoadRow(py, X1 + (X2 - X1) * t, W1 + (W2 - W1) * t, i, prFog[n], t);
            }
            maxy = Math.Min(maxy, yTop);
        }
        // decorado y coches de atras hacia delante
        for (int n = 0; n < DRAWD; n++) bucket[n].Clear();
        for (int c = 1; c < NCAR; c++)
        {
            int n = (SegAt(cz[c]) - baseSeg + NSeg) % NSeg;
            if (n >= 1 && n < DRAWD && !cgone[c]) bucket[n].Add(c);
        }
        for (int n = DRAWD - 1; n >= 1; n--)
        {
            if (!prOk[n]) continue;
            int i = prSeg[n];
            foreach (Spr sp in segSpr[i])
            {
                double sc = prS1[n], sx = prX1[n] + sc * sp.off * ROADW * PW / 2;
                DrawSprite(sp.s, sc, sx, prY1[n], sp.off < -0.01 ? -1 : sp.off > 0.01 ? 0 : -0.5, prClip[n], prFog[n]);
            }
            foreach (int c in bucket[n])
            {
                double pct = Frac(cz[c] / SEG), sc = Lp(prS1[n], prS2[n], pct);
                double xx = Lp(prX1[n], prX2[n], pct) + sc * cx[c] * ROADW * PW / 2, yy = Lp(prY1[n], prY2[n], pct);
                double w = sc * CARW * PW / 2, h = w * 18 / 40;
                DrawCar(xx - w / 2, yy - h, w, h, c, cz[c] / 60, 0, cbrk[c], false, prFog[n], prClip[n]);
            }
        }
    }

    static bool LightOn(int k)
    {
        if (state != ST_COUNT) return false;
        return stT >= 1.0 + k * 0.9;
    }

    static void DrawSprite(Sprite s, double sc, double x, double y, double ax, int clip, double fog)
    {
        double dw = s.ww * sc * PW / 2, dh = dw * s.h / s.w;
        if (dw < 1) return;
        double x0 = x + dw * ax, y0 = y - dh;
        int xa = Math.Max(0, (int)Math.Floor(x0)), xb = Math.Min(PW - 1, (int)Math.Ceiling(x0 + dw) - 1);
        int ya = Math.Max(0, (int)Math.Floor(y0)), yb = Math.Min(Math.Min(PH - 1, clip - 1), (int)Math.Ceiling(y) - 1);
        int tick = (int)(gt * 5);
        for (int py = ya; py <= yb; py++)
        {
            int v = (int)((py + 0.5 - y0) / dh * s.h);
            if (v < 0 || v >= s.h) continue;
            int row = v * s.w;
            for (int px = xa; px <= xb; px++)
            {
                int u = (int)((px + 0.5 - x0) / dw * s.w);
                if (u < 0 || u >= s.w) continue;
                int c = s.px[row + u];
                if (c == -1) continue;
                if (c == -2) c = CROWD[(int)(Hash(u, v, tick + u % 3) * CROWD.Length)];
                else if (c <= -10) c = LightOn(-10 - c) ? Rgb(255, 25, 25) : Rgb(55, 8, 8);
                if (fog < 0.999) c = Lerp(FOG, c, fog);
                pix[py * PW + px] = c;
            }
        }
    }

    static void ShakePix(int dx, int dy)
    {
        if (dx == 0 && dy == 0) return;
        Array.Copy(pix, pix2, pix.Length);
        for (int y = 0; y < PH; y++)
            for (int x = 0; x < PW; x++)
            {
                int sx = Math.Max(0, Math.Min(PW - 1, x - dx)), sy = Math.Max(0, Math.Min(PH - 1, y - dy));
                pix[y * PW + x] = pix2[sy * PW + sx];
            }
    }

    // ================================================================ render general
    static void Render()
    {
        double spct = cspd[0] / MAXSPD;
        double depth = CAMDEPTH / (1 + 0.14 * spct + (boosting ? 0.1 : 0));
        int s = SegAt(cz[0]);
        if (!paused) skyOff += segCurve[s] * spct * 0.9;
        RenderWorld(depth);

        // coche del jugador
        double carW = Math.Round(PW * 0.34), carH = carW * 18 / 40;
        double bounce = (onKerb || offRoad) && spct > 0.1 ? (rnd.Next(2)) : 0;
        if (state == ST_COUNT && thrVis > 0.5) bounce = rnd.Next(2) * 0.6;
        double carX = PW / 2.0 - carW / 2 + steerVis * 1.5, carY = PH - carH - Math.Max(2, PH / 40) + bounce;
        DrawCar(carX, carY, carW, carH, 0, dist / 70, steerVis * 1.6, braking && spct > 0.02, boosting, 1, PH);
        DrawParts();

        // lineas de velocidad
        double sl = Cl((spct - 0.6) / 0.4) + (boosting ? 0.6 : 0);
        if (sl > 0 && state != ST_TITLE)
            for (int k = 0; k < 26; k++)
            {
                double a = Hash(k, 1, 9) * Math.PI * 2, ph = Frac(Hash(k, 2, 9) + gt * (1.0 + spct * 2.2));
                double r = Lp(0.5, 1.15, ph) * PW * 0.55, len = 4 + 10 * ph;
                double ux = Math.Cos(a), uy = Math.Sin(a) * 0.62;
                PLine(PW / 2.0 + ux * r, PH / 2.0 + uy * r, PW / 2.0 + ux * (r + len), PH / 2.0 + uy * (r + len), boosting ? Rgb(150, 210, 255) : Rgb(255, 255, 255), 0.3 * sl * ph);
            }
        if (boosting)
            for (int y = 0; y < PH; y++)
                for (int x = 0; x < 7; x++) { double a = (1 - x / 7.0) * 0.35 * (0.7 + 0.3 * Math.Sin(gt * 20)); PB(x, y, Rgb(0, 120, 255), a); PB(PW - 1 - x, y, Rgb(0, 120, 255), a); }

        if (shake > 0.02) ShakePix(Rd((rnd.NextDouble() - 0.5) * 4 * shake), Rd((rnd.NextDouble() - 0.5) * 3 * shake));

        // interfaz
        if (state == ST_TITLE) TitlePix();
        else if (state == ST_NAME) NamePix();
        else if (state == ST_LOBBY) LobbyPix();
        else if (state == ST_FINISH) { HudPix(false); FinishPix(); }
        else HudPix(true);
        if (state == ST_COUNT) CountPix();
        if (paused) PausePix();
        MsgPix();
        ToCells();
        if (state == ST_TITLE) TitleText();
        else if (state == ST_NAME) NameText();
        else if (state == ST_LOBBY) LobbyText();
        else { HudText(state != ST_FINISH); if (state == ST_FINISH) FinishText(); }
        if (state == ST_COUNT) CountText();
        if (paused) PauseText();
        MsgText();
    }

    // ---------------------------------------------------------------- HUD
    static int MsgRow() { return Math.Max(3, H / 2 - 8); }

    static void MsgPix()
    {
        double age = gt - msgT;
        if (msg.Length == 0 || age > msgDur) return;
        int w = msg.Length + 8, x = (W - w) / 2 + (int)((1 - Sm(age / 0.25)) * W * 0.6), y = MsgRow();
        Panel(x, y - 1, w, 3, 0.75, msgCol);
        for (int px = x; px < x + w; px++) PS(px, (y + 2) * 2 - 1, msgCol);
    }
    static void MsgText()
    {
        double age = gt - msgT;
        if (msg.Length == 0 || age > msgDur) return;
        int w = msg.Length + 8, x = (W - w) / 2 + (int)((1 - Sm(age / 0.25)) * W * 0.6);
        bool blink = age > msgDur - 0.6 && ((int)(age * 8)) % 2 == 0;
        if (!blink) TS(x + 4, MsgRow(), msg, msgCol);
    }

    static void HudPix(bool full)
    {
        if (full) HudTop();
        HudDash();
    }

    static void HudTop()
    {
        // torre de tiempos
        Panel(1, 1, 21, NCAR + 2, 0.72, Rgb(225, 15, 25));
        for (int k = 0; k < NCAR; k++)
        {
            int c = order[k], y = (2 + k) * 2;
            if (c == 0) for (int yy = y; yy < y + 2; yy++) for (int x = 1; x < 22; x++) PB(x, yy, Rgb(170, 10, 20), 0.45);
            PRect(4, y, 1, 2, cmain[c]);
        }
        // tiempos
        Panel(W - 26, 1, 25, 5, 0.72, Rgb(0, 200, 255));
        // minimapa
        int mx0 = W - 26, my0 = 7, mw = 25, mh = 10;
        Panel(mx0, my0, mw, mh, 0.72, Rgb(0, 200, 255));
        double bw = mw - 4, bh = mh * 2 - 5;
        double sx = Math.Min(bw, bh * mapAspect), sy = sx / mapAspect;
        double ox = mx0 + 2 + (bw - sx) / 2, oy = my0 * 2 + 3 + (bh - sy) / 2;
        for (int i = 0; i < NSeg; i += 2) PS((int)(ox + mapX[i] * sx), (int)(oy + mapY[i] * sy), Rgb(190, 190, 205));
        PRect((int)(ox + mapX[0] * sx) - 1, (int)(oy + mapY[0] * sy), 3, 1, Rgb(255, 255, 255));
        for (int c = NCAR - 1; c >= 0; c--)
        {
            int i = SegAt(cz[c]);
            int px = (int)(ox + mapX[i] * sx), py = (int)(oy + mapY[i] * sy);
            if (c == 0) { int col = ((int)(gt * 6)) % 2 == 0 ? Rgb(255, 255, 255) : Rgb(255, 30, 40); PRect(px - 1, py - 1, 3, 3, col); }
            else PRect(px, py, 2, 2, cmain[c]);
        }
        // luces de cambio
        Panel(W / 2 - 16, 0, 32, 2, 0.75, -1);
        for (int k = 0; k < 15; k++)
        {
            double th = (k + 1) / 15.0;
            bool on = rpm >= 0.3 + th * 0.68;
            int col = k < 5 ? Rgb(0, 230, 70) : k < 10 ? Rgb(255, 30, 30) : Rgb(60, 120, 255);
            if (rpm > 0.97 && ((int)(gt * 14)) % 2 == 0) { col = Rgb(60, 120, 255); on = true; }
            int x = W / 2 - 15 + k * 2;
            PRect(x, 1, 1, 2, on ? col : Rgb(28, 28, 36));
        }
    }

    static void HudDash()
    {
        // salpicadero
        int dx0 = 1, dy0 = H - 9;
        Panel(dx0, dy0, 38, 8, 0.75, Rgb(225, 15, 25));
        int kmh = (int)Kmh();
        string ks = kmh.ToString().PadLeft(3);
        for (int k = 0; k < 3; k++) if (ks[k] != ' ') F3Pix(ks[k].ToString(), dx0 + 2 + k * 8, (dy0 + 1) * 2, 2, Rgb(255, 255, 255));
        int bh2 = 10, by0 = (dy0 + 1) * 2;
        PRect(dx0 + 27, by0, 1, bh2, Rgb(25, 40, 25)); PRect(dx0 + 27, by0 + bh2 - (int)(bh2 * thrVis), 1, (int)(bh2 * thrVis), Rgb(0, 230, 80));
        PRect(dx0 + 29, by0, 1, bh2, Rgb(45, 20, 20)); PRect(dx0 + 29, by0 + bh2 - (int)(bh2 * brkVis), 1, (int)(bh2 * brkVis), Rgb(255, 40, 40));
        for (int y = by0 - 1; y < by0 + bh2 + 1; y++) for (int x = dx0 + 31; x < dx0 + 38; x++) PB(x, y, Rgb(150, 10, 20), 0.5);
        F3Pix(state == ST_COUNT ? "N" : gear.ToString(), dx0 + 32, by0, 2, rpm > 0.95 ? Rgb(120, 170, 255) : Rgb(255, 255, 255));
        int ex = dx0 + 6, ey = (dy0 + 7) * 2, ewid = 18;
        PRect(ex, ey, ewid, 2, Rgb(15, 25, 45));
        int ef = (int)(ewid * energy);
        PRect(ex, ey, ef, 2, boosting ? Lerp(Rgb(0, 200, 255), Rgb(255, 255, 255), 0.5 + 0.5 * Math.Sin(gt * 30)) : Rgb(0, 120, 255));
        // posicion
        int qx0 = W - 22, qy0 = H - 9;
        Panel(qx0, qy0, 21, 8, 0.75, Rgb(255, 215, 0));
        F3Pix("P" + (PosOf(0) + 1), qx0 + 2, (qy0 + 1) * 2, 2, PosOf(0) == 0 ? Rgb(255, 215, 0) : Rgb(255, 255, 255));
    }

    static string Gap(int k)
    {
        int c = order[k];
        if (k == 0) return state == ST_FINISH && cfin[c] >= 0 ? "META" : "LIDER";
        int l = order[0];
        if (cfin[c] >= 0 && cfin[l] >= 0) return "+" + (cfin[c] - cfin[l]).ToString("0.000", INV);
        double d = Prog(l) - Prog(c);
        if (cfin[l] >= 0) d = LAPS * trackLen - (claps[c] * trackLen + cz[c]);
        if (d > trackLen) return "+" + (int)(d / trackLen) + " V";
        return "+" + (d / (MAXSPD * 0.85)).ToString("0.000", INV);
    }

    static void HudText(bool full)
    {
        if (full) HudTopText();
        HudDashText();
    }

    static void HudTopText()
    {
        int wh = Rgb(255, 255, 255), gr = Rgb(170, 175, 190);
        int lap = Math.Max(1, Math.Min(LAPS, claps[0] + 1));
        TS(2, 1, "VUELTA " + lap + "/" + LAPS, wh);
        TS(15, 1, "F1 GP", Rgb(255, 60, 60));
        for (int k = 0; k < NCAR; k++)
        {
            int c = order[k], y = 2 + k;
            int nc = c == 0 ? Rgb(255, 230, 0) : ckind[c] == 1 ? Rgb(0, 230, 255) : wh;
            if (cgone[c]) nc = Rgb(110, 110, 120);
            TS(2, y, (k + 1).ToString(), nc);
            TS(6, y, cname[c], nc);
            string g = cgone[c] ? "DESC." : Gap(k);
            TS(21 - g.Length, y, g, k == 0 ? Rgb(0, 230, 255) : gr);
        }
        int tx = W - 25;
        TS(tx, 1, "TIEMPO", gr); TS(tx + 9, 1, Fmt(state == ST_COUNT ? 0 : raceT), wh);
        TS(tx, 2, "VUELTA", gr); TS(tx + 9, 2, claps[0] >= 0 && state != ST_COUNT ? Fmt(raceT - clast[0]) : Fmt(0), wh);
        TS(tx, 3, "ULTIMA", gr); TS(tx + 9, 3, Fmt(lastLapT), wh);
        TS(tx, 4, "MEJOR", gr); TS(tx + 9, 4, Fmt(bestLapT), Rgb(200, 110, 255));
        TS(W - 25, 7, "CIRCUITO", Rgb(0, 220, 255));
        int on = RemoteHumans();
        if (on > 0) TS(W / 2 - 9, 3, "ONLINE: " + (on + 1) + " JUGADORES", Rgb(0, 230, 255));
        TS(W / 2 - 4, 2, "RPM " + (int)(4000 + rpm * 11000), Rgb(150, 150, 165));
    }

    static void HudDashText()
    {
        int wh = Rgb(255, 255, 255), gr = Rgb(170, 175, 190);
        int dx0 = 1, dy0 = H - 9;
        TS(dx0 + 1, dy0, "TELEMETRIA", Rgb(255, 90, 90));
        TS(dx0 + 2, dy0 + 6, "KM/H", gr);
        TS(dx0 + 26, dy0 + 6, "A F", gr);
        TS(dx0 + 31, dy0 + 6, "MARCHA", gr);
        TS(dx0 + 1, dy0 + 7, "ERS", boosting ? Rgb(120, 220, 255) : gr);
        TS(dx0 + 25, dy0 + 7, ((int)(energy * 100)).ToString().PadLeft(3) + "%", wh);
        if (boosting && ((int)(gt * 6)) % 2 == 0) TS(dx0 + 30, dy0 + 7, "DEPLOY", Rgb(120, 220, 255));
        int qx0 = W - 22, qy0 = H - 9;
        TS(qx0 + 1, qy0, "POSICION", Rgb(255, 215, 0));
        TS(qx0 + 16, qy0 + 3, "/" + NCAR, wh);
        int p = PosOf(0);
        if (p > 0) { int a = order[p - 1]; TS(qx0 + 1, qy0 + 6, "DELANTE " + cname[a] + " " + Gap2(a), Rgb(255, 120, 100)); }
        if (p < NCAR - 1) { int b = order[p + 1]; TS(qx0 + 1, qy0 + 7, "DETRAS  " + cname[b] + " " + Gap2(b), Rgb(120, 255, 150)); }
        if (offRoad && state == ST_RACE && ((int)(gt * 4)) % 2 == 0) TSC(MsgRow() + 3, "!! FUERA DE PISTA !!", Rgb(255, 200, 0));
    }

    static string Gap2(int c)
    {
        double d = Math.Abs(Prog(c) - Prog(0));
        if (cfin[c] >= 0 || cfin[0] >= 0) return "";
        return (d / (MAXSPD * 0.85)).ToString("0.0", INV);
    }

    // ---------------------------------------------------------------- semaforo
    static void CountPix()
    {
        int x0 = W / 2 - 21, y0 = 4;
        Panel(x0, y0, 42, 7, 0.85, Rgb(60, 60, 70));
        for (int k = 0; k < 5; k++)
        {
            int hx = x0 + 2 + k * 8;
            PRect(hx, y0 * 2 + 2, 6, 10, Rgb(12, 12, 14));
            bool on = LightOn(k);
            for (int l = 0; l < 2; l++)
            {
                double cxp = hx + 3, cyp = y0 * 2 + 4.5 + l * 5;
                if (on) PDisc(cxp, cyp, 5, 4, Rgb(255, 40, 30), 0.35);
                PDisc(cxp, cyp, 2.3, 2.1, on ? Rgb(255, 30, 25) : Rgb(60, 10, 10), 1);
                if (on) PS((int)cxp - 1, (int)cyp - 1, Rgb(255, 200, 190));
            }
        }
    }
    static void CountText()
    {
        TSC(3, "PREPARADOS...", Rgb(255, 255, 255));
        TSC(12, "Mant\u00e9n \u2191 para revolucionar el motor", Rgb(200, 200, 215));
    }

    // ---------------------------------------------------------------- portada
    static void TitlePix()
    {
        for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Rgb(5, 3, 15), 0.45);
        int sc = H >= 38 ? 3 : 2;
        int fw = BigW("F1", sc);
        double shine = Frac(gt / 3.5) * (fw + 40) - 20;
        BigPix("F1", (W - fw) / 2, 1, sc, Rgb(255, 70, 50), Rgb(170, 0, 15), Rgb(90, 0, 10), shine);
        int gy = 1 + 6 * sc + 1, gw = BigW("GRAND PRIX", 1);
        BigPix("GRAND PRIX", (W - gw) / 2, gy, 1, Rgb(255, 255, 255), Rgb(150, 155, 175), Rgb(60, 60, 80), Frac(gt / 3.5 + 0.3) * (gw + 40) - 20);
        int py = gy + 8;
        Panel(W / 2 - 37, py - 1, 74, 2, 0.7, -1);
        Panel(W / 2 - 34, py + 3, 68, 5, 0.75, Rgb(225, 15, 25));
    }
    static void TitleText()
    {
        int gy = 1 + 6 * (H >= 38 ? 3 : 2) + 1, py = gy + 7;
        TSC(py, "- MULTIJUGADOR EN RED LOCAL  -  3 VUELTAS  -  8 COCHES  -", Rgb(255, 210, 120));
        if (((int)(gt * 2.5)) % 2 == 0) TSC(py + 1, ">>  PULSA ENTER PARA JUGAR  <<", Rgb(255, 255, 255));
        TSC(py + 4, "\u2191 ACELERAR     \u2193 FRENAR     \u2190 \u2192 GIRAR", Rgb(230, 230, 240));
        TSC(py + 5, "ESPACIO: TURBO ERS     P: PAUSA     ESC: SALIR", Rgb(230, 230, 240));
        TSC(py + 6, "Frena antes de las curvas cerradas o te iras a la hierba!", Rgb(150, 155, 175));
    }

    // ---------------------------------------------------------------- pausa
    static void PausePix()
    {
        for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Rgb(0, 0, 10), 0.55);
        int w = BigW("PAUSA", 1);
        BigPix("PAUSA", (W - w) / 2, H / 2 - 6, 1, Rgb(255, 255, 255), Rgb(160, 160, 190), Rgb(60, 60, 80), -100);
    }
    static void PauseText() { TSC(H / 2 + 2, "P: CONTINUAR     ESC: SALIR", Rgb(255, 255, 255)); }

    // ---------------------------------------------------------------- meta
    static void Flag(int x0, int y0, double t)
    {
        for (int pyl = y0; pyl < y0 + 26; pyl++) PS(x0 - 1, pyl, Rgb(200, 200, 210));
        for (int i = 0; i < 16; i++)
            for (int j = 0; j < 12; j++)
            {
                double wv = Math.Sin(i * 0.5 - t * 7) * 1.6 * (i / 16.0);
                double shade = 0.75 + 0.25 * Math.Cos(i * 0.5 - t * 7);
                int c = ((i / 2) + (j / 2)) % 2 == 0 ? Rgb(245, 245, 245) : Rgb(15, 15, 15);
                PS(x0 + i, (int)(y0 + j + wv), Scale(c, shade));
            }
    }

    static int[] fin = new int[NCAR]; static double[] finT = new double[NCAR];

    static void FinishOrder()
    {
        for (int i = 0; i < NCAR; i++)
        {
            fin[i] = i;
            finT[i] = cfin[i] >= 0 ? cfin[i] : raceT + (LAPS * trackLen - (claps[i] * trackLen + cz[i])) / Math.Max(cspd[i], MAXSPD * 0.6);
        }
        Array.Sort(fin, delegate(int a, int b) { return finT[a].CompareTo(finT[b]); });
    }

    static void FinishPix()
    {
        for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Rgb(5, 3, 15), 0.35);
        int w = BigW("META", 1), x = (W - w) / 2;
        BigPix("META", x, 1, 1, Rgb(255, 255, 255), Rgb(170, 170, 190), Rgb(60, 60, 80), Frac(gt / 2.5) * (w + 40) - 20);
        Flag(x - 22, 2, gt); Flag(x + w + 6, 2, gt + 1);
        if (stT > 1.0) Panel(W / 2 - 33, 9, 66, NCAR + 2, 0.82, Rgb(255, 215, 0));
    }

    static void FinishText()
    {
        if (stT <= 1.0) return;
        FinishOrder();
        int x = W / 2 - 32, y = 9;
        TS(x + 1, y, "POS  PILOTO        EQUIPO          TIEMPO      MEJOR", Rgb(255, 215, 0));
        for (int k = 0; k < NCAR; k++)
        {
            int c = fin[k]; int col = c == 0 ? Rgb(255, 230, 0) : ckind[c] == 1 ? Rgb(0, 230, 255) : Rgb(235, 235, 245);
            string t = cfin[c] >= 0 ? (k == 0 ? Fmt(cfin[c]) : "+" + (cfin[c] - cfin[fin[0]]).ToString("0.000", INV)) : cgone[c] ? "ABANDONO" : "EN PISTA";
            TS(x + 2, y + 1 + k, (k + 1).ToString(), col);
            TC(x + 5, y + 1 + k, '\u2588', cmain[c]);
            TS(x + 7, y + 1 + k, cfull[c].Length > 12 ? cfull[c].Substring(0, 12) : cfull[c], col);
            TS(x + 21, y + 1 + k, cteam[c], col);
            TS(x + 37, y + 1 + k, t, col);
            TS(x + 49, y + 1 + k, cbest[c] < 1e8 ? Fmt(cbest[c]) : "-", Rgb(200, 110, 255));
        }
        string res = finishPos == 1 ? "*** " + myName + " GANA EL GRAN PREMIO! ***" : finishPos <= 3 ? "*** PODIO PARA " + myName + "! ***" : "Buen intento, " + myName + "! A por la victoria en la proxima.";
        TSC(y + NCAR + 3, res, finishPos <= 3 ? Rgb(255, 215, 0) : Rgb(255, 255, 255));
        if (((int)(gt * 2)) % 2 == 0) TSC(Math.Min(H - 11, y + NCAR + 5), "ENTER: VOLVER A LA SALA     ESC: SALIR", Rgb(255, 255, 255));
    }
}
'@
try {
    Add-Type -TypeDefinition $code -Language CSharp
} catch {
    Write-Host ""
    Write-Host "  Error compilando el juego:" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}
[F1Game]::Run()
exit 0
