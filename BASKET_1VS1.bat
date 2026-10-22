<# : -------- parte BATCH (PowerShell la ve como un comentario) --------
@echo off
setlocal
title BASKET 1 VS 1
mode con: cols=120 lines=40
color 0F
cls
echo.
echo   [*] BASKET 1 VS 1
echo   [*] Compilando el motor del juego, espera un segundo...
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
using System.Runtime.InteropServices;

public static class Basket
{
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool WriteConsoleW(IntPtr h, string s, int n, out int w, IntPtr r);
    [DllImport("kernel32.dll")] static extern bool FlushConsoleInputBuffer(IntPtr h);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);

    const string E = "\u001b[";
    const char UPB = '\u2580';
    static readonly CultureInfo INV = CultureInfo.InvariantCulture;

    static IntPtr hOut, hIn; static bool win, hadMode, asyncKeys = true; static uint oldMode;
    static int W = 120, H = 40, PW = 120, PH = 80;
    static int[] pix, pix2; static char[] cb, pcb; static int[] cc, cbg, pcc, pcbg; static bool fullDraw = true;
    static StringBuilder sb = new StringBuilder(1 << 18);
    static Random rnd = new Random(11);
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

    // modo de prueba: juegan dos IA y se vuelcan fotogramas
    public static void Dump(int w, int h, string path, double[] times)
    {
        dumping = true; W = w; H = h; Alloc(); Init();
        using (StreamWriter o = new StreamWriter(path, false, new UTF8Encoding(false)))
        {
            double T = 0, dt = 1.0 / 30; int k = 0;
            while (k < times.Length)
            {
                ReadInput(); Frame(dt); Present(); T += dt;
                if (T >= times[k])
                {
                    o.WriteLine("F " + T.ToString("0.00", INV) + " g=" + gstate + " score=" + score[0] + "-" + score[1] + " clock=" + clock.ToString("0.0", INV) + " ball=" + bstate + " owner=" + owner +
                        " fg0=" + st[0, 0] + "/" + st[0, 1] + " fg1=" + st[1, 0] + "/" + st[1, 1] + " 3p=" + st[0, 2] + "," + st[1, 2] + " dunk=" + st[0, 4] + "," + st[1, 4] + " blk=" + st[0, 5] + "," + st[1, 5] + " stl=" + st[0, 6] + "," + st[1, 6] + " bytes=" + sb.Length);
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
        ppm = PH / 6.6; floorY = PH - Math.Max(8, PH * 0.15);
    }

    // ================================================================ teclado
    static bool hL, hR, hUp, hDown, hAct, hTurbo;
    static bool eUp, eDown, eAct, rAct, eEnter, eEsc, eP, eLeft, eRight;
    static bool pUp = true, pDown = true, pAct = true, pEnter = true, pEsc = true, pP = true, pL = true, pR = true;

    static bool Down(int vk) { return (GetAsyncKeyState(vk) & 0x8000) != 0; }

    static void ReadInput()
    {
        if (dumping)
        {
            hL = hR = hUp = hDown = hAct = hTurbo = false;
            eUp = eDown = eAct = rAct = eEsc = eP = eLeft = eRight = false;
            eEnter = gstate == G_TITLE && stT > 1.0;
            return;
        }
        bool up = false, dn = false, ac = false, en = false, es = false, pp = false, l = false, r = false, tb = false;
        if (asyncKeys)
        {
            try
            {
                l = Down(0x25); r = Down(0x27); up = Down(0x26); dn = Down(0x28); ac = Down(0x20); tb = Down(0x10);
                en = Down(0x0D); es = Down(0x1B); pp = Down(0x50);
                FlushConsoleInputBuffer(hIn);
            }
            catch { asyncKeys = false; }
        }
        if (!asyncKeys)
        {
            try
            {
                while (Console.KeyAvailable)
                {
                    ConsoleKey k = Console.ReadKey(true).Key;
                    if (k == ConsoleKey.LeftArrow) l = true; else if (k == ConsoleKey.RightArrow) r = true;
                    else if (k == ConsoleKey.UpArrow) up = true; else if (k == ConsoleKey.DownArrow) dn = true;
                    else if (k == ConsoleKey.Spacebar) ac = true; else if (k == ConsoleKey.Enter) en = true;
                    else if (k == ConsoleKey.Escape) es = true; else if (k == ConsoleKey.P) pp = true;
                }
            }
            catch { }
        }
        eUp = up && !pUp; eDown = dn && !pDown; eAct = ac && !pAct; rAct = !ac && pAct;
        eEnter = en && !pEnter; eEsc = es && !pEsc; eP = pp && !pP; eLeft = l && !pL; eRight = r && !pR;
        hL = l; hR = r; hUp = up; hDown = dn; hAct = ac; hTurbo = tb;
        pUp = up; pDown = dn; pAct = ac; pEnter = en; pEsc = es; pP = pp; pL = l; pR = r;
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
    static double Gauss() { double u = 1 - rnd.NextDouble(), v = rnd.NextDouble(); return Math.Sqrt(-2 * Math.Log(u)) * Math.Cos(2 * Math.PI * v); }

    // ---------------------------------------------------------------- pixeles
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
    static void Panel(int cx, int cy, int cw, int ch, double a, int accent)
    {
        for (int y = cy * 2; y < (cy + ch) * 2; y++)
            for (int x = cx; x < cx + cw; x++) PB(x, y, Rgb(6, 8, 18), a);
        if (accent >= 0) for (int x = cx; x < cx + cw; x++) PS(x, cy * 2, accent);
    }

    // dibujo del mundo (con modo reflejo para el parque brillante)
    static bool mirror; static double ppm = 10, floorY = 69, camX;
    static double SXf(double x) { return (x - camX) * ppm; }
    static double SYf(double y) { return floorY - y * ppm; }
    static void PP(int x, int y, int c)
    {
        if (!mirror) { PS(x, y, c); return; }
        int ry = (int)(floorY + (floorY - y) * 0.5);
        if (ry <= floorY || ry >= PH) return;
        PB(x, ry, c, 0.2);
    }
    // circulo macizo en metros
    static void WDisc(double x, double y, double r, int c)
    {
        double cx = SXf(x), cy = SYf(y), rp = Math.Max(0.55, r * ppm);
        int x0 = (int)Math.Floor(cx - rp), x1 = (int)Math.Ceiling(cx + rp), y0 = (int)Math.Floor(cy - rp), y1 = (int)Math.Ceiling(cy + rp);
        for (int yy = y0; yy <= y1; yy++)
            for (int xx = x0; xx <= x1; xx++)
            {
                double dx = xx + 0.5 - cx, dy = yy + 0.5 - cy;
                if (dx * dx + dy * dy <= rp * rp) PP(xx, yy, c);
            }
    }
    // linea gruesa en metros
    static void WLine(double x0, double y0, double x1, double y1, double w, int c)
    {
        double len = Math.Sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0)) * ppm;
        int n = Math.Max(1, (int)(len * 1.5));
        for (int k = 0; k <= n; k++) { double t = (double)k / n; WDisc(Lp(x0, x1, t), Lp(y0, y1, t), w / 2, c); }
    }
    static void PLine(double x0, double y0, double x1, double y1, int c, double a)
    {
        int n = (int)Math.Max(Math.Abs(x1 - x0), Math.Abs(y1 - y0)) + 1;
        for (int k = 0; k <= n; k++) { double t = (double)k / n; int x = (int)Lp(x0, x1, t), y = (int)Lp(y0, y1, t); if (a >= 1) PP(x, y, c); else PB(x, y, c, a); }
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
    static void TS(int x, int y, string s, int fg) { for (int i = 0; i < s.Length; i++) TC(x + i, y, s[i], fg); }
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
    static readonly Dictionary<char, string[]> BIG = new Dictionary<char, string[]>();
    static readonly Dictionary<char, string> F3 = new Dictionary<char, string>();

    static void InitFonts()
    {
        BIG['B'] = new string[] { "######7 ", "##F==##7", "######FJ", "##F==##7", "######FJ", "L=====J " };
        BIG['A'] = new string[] { " #####7 ", "##F==##7", "#######|", "##F==##|", "##|  ##|", "L=J  L=J" };
        BIG['S'] = new string[] { "#######7", "##F====J", "#######7", "L====##|", "#######|", "L======J" };
        BIG['K'] = new string[] { "##7  ##7", "##| ##FJ", "#####FJ ", "##F=##7 ", "##|  ##7", "L=J  L=J" };
        BIG['E'] = new string[] { "#######7", "##F====J", "#####7  ", "##F==J  ", "#######7", "L======J" };
        BIG['T'] = new string[] { "########7", "L==##F==J", "   ##|   ", "   ##|   ", "   ##|   ", "   L=J   " };
        BIG['1'] = new string[] { " ##7", "###|", "L##|", " ##|", " ##|", " L=J" };
        BIG['V'] = new string[] { "##7   ##7", "##|   ##|", "##|   ##|", "L##7 ##FJ", " L####FJ ", "  L===J  " };
        BIG[' '] = new string[] { "   ", "   ", "   ", "   ", "   ", "   " };

        string[] t = {
            "A.#.|#.#|###|#.#|#.#", "B##.|#.#|##.|#.#|##.", "C.##|#..|#..|#..|.##", "D##.|#.#|#.#|#.#|##.", "E###|#..|##.|#..|###",
            "F###|#..|##.|#..|#..", "G.##|#..|#.#|#.#|.##", "H#.#|#.#|###|#.#|#.#", "I###|.#.|.#.|.#.|###", "J..#|..#|..#|#.#|.#.",
            "K#.#|#.#|##.|#.#|#.#", "L#..|#..|#..|#..|###", "M#.#|###|###|#.#|#.#", "N##.|#.#|#.#|#.#|#.#", "O.#.|#.#|#.#|#.#|.#.",
            "P##.|#.#|##.|#..|#..", "Q.#.|#.#|#.#|##.|.##", "R##.|#.#|##.|#.#|#.#", "S.##|#..|.#.|..#|##.", "T###|.#.|.#.|.#.|.#.",
            "U#.#|#.#|#.#|#.#|###", "V#.#|#.#|#.#|#.#|.#.", "W#.#|#.#|###|###|#.#", "X#.#|#.#|.#.|#.#|#.#", "Y#.#|#.#|.#.|.#.|.#.",
            "Z###|..#|.#.|#..|###", "0###|#.#|#.#|#.#|###", "1.#.|##.|.#.|.#.|###", "2###|..#|###|#..|###", "3###|..#|.##|..#|###",
            "4#.#|#.#|###|..#|..#", "5###|#..|###|..#|###", "6###|#..|###|#.#|###", "7###|..#|.#.|.#.|.#.", "8###|#.#|###|#.#|###",
            "9###|#.#|###|..#|###", "!.#.|.#.|.#.|...|.#.", "-...|...|###|...|...", " ...|...|...|...|...", ":...|.#.|...|.#.|...",
            "+...|.#.|###|.#.|...", "..#.|...|...|...|.#." };
        foreach (string g in t) F3[g[0]] = g.Substring(1).Replace("|", "");
        F3['.'] = "............#..";
    }

    static int BigW(string s, int sc) { int n = 0; foreach (char c in s) n += BIG[c][0].Length; return n * sc; }

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

    // texto grande con contorno negro
    static void F3Out(string s, int x, int y, int sc, int col, int col2)
    {
        for (int oy = -1; oy <= 1; oy++) for (int ox = -1; ox <= 1; ox++) if (ox != 0 || oy != 0) F3Pix(s, x + ox, y + oy, sc, Rgb(0, 0, 0));
        F3Pix(s, x, y, sc, col);
        if (col2 >= 0) { int cx = x; foreach (char ch in s) { string g; if (!F3.TryGetValue(char.ToUpperInvariant(ch), out g)) g = F3[' ']; for (int c = 0; c < 3; c++) if (g[12 + c] == '#') PRect(cx + c * sc, y + 4 * sc, sc, sc, col2); cx += 4 * sc; } }
    }

    // ================================================================ cancha y reglas
    const double COURT = 28, HXL = 1.6, HXR = 26.4, RIMY = 3.05, RIMR = 0.36, BALLR = 0.17, BOARDOFF = 0.55, BY0 = 2.95, BY1 = 4.0, G = 11, THREE = 6.75;
    const int A_NONE = 0, A_SHOOT = 1, A_DUNK = 2, A_FALL = 3, A_REACH = 4;
    const int G_TITLE = 0, G_PLAY = 1, G_END = 2;
    static int gstate; static double stT;
    static int diff = 1, lenIdx = 1;
    static readonly string[] DIFN = { "FACIL", "NORMAL", "DIFICIL" };
    static readonly int[] LENS = { 60, 120, 180 };

    // jugadores: 0 = tu (ataca a la canasta derecha), 1 = CPU (ataca a la izquierda)
    static double[] plx = new double[2], ply = new double[2], plvx = new double[2], plvy = new double[2], runPh = new double[2], stam = new double[2];
    static double[] actT = new double[2], stealCD = new double[2], crossCD = new double[2], crossT = new double[2], meter = new double[2], aiRel = new double[2], fallT = new double[2], reachT = new double[2];
    static double[] aiDec = new double[2], aiBlockT = new double[2], aiBack = new double[2], dunkSlam = new double[2], lastQ = new double[2], qT = new double[2];
    static int[] face = new int[2], act = new int[2], streak = new int[2], score = new int[2];
    static bool[] ground = new bool[2], fire = new bool[2], blockUp = new bool[2];
    static int[,] st = new int[2, 8];   // 0 tc metidos, 1 tc intentados, 2 triples, 3 triples int., 4 mates, 5 tapones, 6 robos, 7 mejor racha
    static readonly string[] TNAME = { "TU", "CPU" };
    static readonly int[] JER = { Rgb(220, 30, 45), Rgb(30, 90, 225) }, JER2 = { Rgb(255, 255, 255), Rgb(255, 210, 0) };
    static readonly int[] SHO = { Rgb(190, 20, 35), Rgb(20, 65, 180) }, SKIN = { Rgb(225, 165, 120), Rgb(130, 85, 55) }, HAIR = { Rgb(60, 35, 20), Rgb(20, 15, 15) }, SHOE = { Rgb(250, 250, 250), Rgb(255, 120, 0) };

    // balon: 0 suelto, 1 en la mano, 2 tiro, 3 mate
    static double bx, by, bvx, bvy, bspin, dribPh, shotT, grabCD, shotFromX;
    static int bstate, owner = -1, shooter = -1, lastTouch = -1, lastPoss = -1;
    static bool shot3, rimTouch, scoredThis, buzzerShot;
    static double clock, shotClock, pauseT, checkT, slowT, shake, excite, flashT;
    static int inboundTeam = -1; static bool overtime;
    static double[] rimShake = new double[2], netSway = new double[2], netStretch = new double[2], boardFlash = new double[2];

    static void Init()
    {
        InitFonts();
        NewGame(); gstate = G_TITLE; stT = 0; clock = 9999;
    }

    static void NewGame()
    {
        for (int i = 0; i < 2; i++)
        {
            plvx[i] = plvy[i] = 0; ply[i] = 0; ground[i] = true; act[i] = A_NONE; stam[i] = 1; streak[i] = 0; fire[i] = false; score[i] = 0; blockUp[i] = false;
            stealCD[i] = crossCD[i] = crossT[i] = fallT[i] = reachT[i] = 0;
            for (int k = 0; k < 8; k++) st[i, k] = 0;
        }
        plx[0] = 12.6; face[0] = 1; plx[1] = 15.4; face[1] = -1;
        clock = LENS[lenIdx]; shotClock = 14; overtime = false; pauseT = 0; inboundTeam = -1; pn = 0; msgT = -10;
        // salto inicial: el balon cae en el centro
        bstate = 0; owner = -1; bx = 14; by = 5.5; bvx = (rnd.NextDouble() - 0.5) * 0.6; bvy = 0; lastTouch = -1; lastPoss = -1; scoredThis = false;
        camX = 14 - PW / ppm / 2;
    }

    // ================================================================ bucle
    static double timeScale = 1;

    static void Frame(double dt)
    {
        gt += dt;
        if (eEsc) { quit = true; return; }
        if (eP && gstate == G_PLAY) paused = !paused;
        slowT = Math.Max(0, slowT - dt);
        timeScale += ((slowT > 0 ? 0.3 : 1) - timeScale) * Math.Min(1, dt * 10);
        if (!paused) Update(dt * timeScale, dt);
        Render(dt);
    }
    static bool paused;

    static void Update(double dt, double rdt)
    {
        stT += rdt;
        UpdParts(dt);
        shake = Math.Max(0, shake - rdt * 2.5);
        excite = Math.Max(0, excite - rdt * 0.35);
        flashT = Math.Max(0, flashT - rdt);
        for (int s = 0; s < 2; s++) { rimShake[s] = Math.Max(0, rimShake[s] - dt * 3); netSway[s] = Math.Max(0, netSway[s] - dt * 1.2); netStretch[s] = Math.Max(0, netStretch[s] - dt * 4); boardFlash[s] = Math.Max(0, boardFlash[s] - dt * 3); }

        if (gstate == G_TITLE)
        {
            if (eLeft) diff = Math.Max(0, diff - 1);
            if (eRight) diff = Math.Min(2, diff + 1);
            if (eUp) lenIdx = Math.Min(2, lenIdx + 1);
            if (eDown) lenIdx = Math.Max(0, lenIdx - 1);
            Sim(dt, true);
            if (eEnter) { NewGame(); gstate = G_PLAY; stT = 0; Msg("A JUGAR!", Rgb(255, 210, 0), 1.6); }
            return;
        }
        if (gstate == G_END)
        {
            Sim(dt, true);
            if (eEnter && stT > 1.5) { gstate = G_TITLE; stT = 0; NewGame(); clock = 9999; }
            return;
        }
        Sim(dt, dumping);
    }

    // ================================================================ simulacion
    static int[] cMove = new int[2]; static bool[] cTurbo = new bool[2], cJump = new bool[2], cActP = new bool[2], cActH = new bool[2], cActR = new bool[2], cDown = new bool[2];

    static int TargetHoop(int i) { return i == 0 ? 1 : 0; }
    static double HoopX(int s) { return s == 0 ? HXL : HXR; }

    static void Sim(double dt, bool aiBoth)
    {
        bool live = pauseT <= 0;
        // controles
        if (aiBoth) AI(0, dt);
        else
        {
            cMove[0] = (hR ? 1 : 0) - (hL ? 1 : 0); cTurbo[0] = hTurbo; cJump[0] = eUp; cActP[0] = eAct; cActH[0] = hAct; cActR[0] = rAct; cDown[0] = eDown;
        }
        AI(1, dt);
        if (!live) for (int i = 0; i < 2; i++) { cActP[i] = cDown[i] = cJump[i] = false; }

        for (int i = 0; i < 2; i++) UpdPlayer(i, dt);
        UpdBall(dt);
        Interactions(dt);

        // relojes
        if (gstate == G_PLAY && live)
        {
            if (!overtime && clock > 0) clock = Math.Max(0, clock - dt);
            if (bstate == 1) { shotClock -= dt; if (shotClock <= 0) { Msg("FIN DE POSESION!", Rgb(255, 120, 60), 1.6); Turnover(1 - owner); } }
            if (!overtime && clock <= 0 && bstate != 2 && bstate != 3) EndRegulation();
        }
        if (pauseT > 0)
        {
            pauseT -= dt;
            if (pauseT <= 0 && inboundTeam >= 0) Inbound(inboundTeam);
        }
        checkT = Math.Max(0, checkT - dt);
        grabCD = Math.Max(0, grabCD - dt);

        // camara
        double vw = PW / ppm;
        double tgt = bx + (owner >= 0 ? face[owner] * 1.6 : 0) - vw / 2;
        tgt = Math.Max(-3.2, Math.Min(COURT + 3.2 - vw, tgt));
        camX += (tgt - camX) * Math.Min(1, dt * 4);
    }

    static void EndRegulation()
    {
        if (score[0] == score[1])
        {
            overtime = true; Msg("EMPATE: MUERTE SUBITA!", Rgb(255, 210, 0), 2.5);
            Inbound(rnd.Next(2));
            return;
        }
        GameOver();
    }

    static void GameOver()
    {
        gstate = G_END; stT = 0; excite = 1;
        Msg(score[0] > score[1] ? "VICTORIA!" : "DERROTA", score[0] > score[1] ? Rgb(255, 215, 0) : Rgb(255, 80, 70), 3);
        if (score[0] > score[1]) for (int k = 0; k < 200; k++) PSpawn(2, rnd.NextDouble() * PW, -rnd.NextDouble() * PH * 0.6, (rnd.NextDouble() - 0.5) * 30, rnd.NextDouble() * 20, 3 + rnd.NextDouble() * 3, CONF[rnd.Next(CONF.Length)], 1);
    }

    static void UpdPlayer(int i, double dt)
    {
        bool has = bstate == 1 && owner == i;
        fallT[i] = Math.Max(0, fallT[i] - dt); reachT[i] = Math.Max(0, reachT[i] - dt);
        stealCD[i] = Math.Max(0, stealCD[i] - dt); crossCD[i] = Math.Max(0, crossCD[i] - dt); crossT[i] = Math.Max(0, crossT[i] - dt);
        if (act[i] == A_FALL && fallT[i] <= 0) act[i] = A_NONE;
        if (act[i] == A_REACH && reachT[i] <= 0) act[i] = A_NONE;
        int mv = cMove[i];
        if (act[i] == A_FALL) mv = 0;
        bool turbo = cTurbo[i] && stam[i] > 0.05 && mv != 0;
        stam[i] = Math.Max(0, Math.Min(1, stam[i] + (turbo ? -0.4 : 0.16) * dt));
        double spd = 5.0 * (turbo ? 1.42 : 1) * (crossT[i] > 0 ? 1.55 : 1) * (has ? 0.93 : 1) * (act[i] == A_REACH ? 0.5 : 1) * (i == 1 ? AISPD[diff] : 1);
        if (fire[i]) spd *= 1.06;
        bool control = act[i] != A_SHOOT && act[i] != A_DUNK && act[i] != A_FALL;
        if (control)
        {
            double tv = mv * spd, acc = ground[i] ? 32 : 9;
            if (plvx[i] < tv) plvx[i] = Math.Min(tv, plvx[i] + acc * dt); else plvx[i] = Math.Max(tv, plvx[i] - acc * dt);
            if (mv != 0) face[i] = mv;
        }
        else if (ground[i]) plvx[i] *= Math.Max(0, 1 - 10 * dt);
        if (!has && control && mv == 0 && bstate == 1 && owner >= 0) face[i] = plx[owner] > plx[i] ? 1 : -1;

        // acciones
        if (control && ground[i])
        {
            if (cJump[i]) { plvy[i] = 5.0; ground[i] = false; blockUp[i] = !has; }
            if (cActP[i])
            {
                if (has) StartShot(i);
                else { plvy[i] = 5.3; ground[i] = false; blockUp[i] = true; }
            }
            if (cDown[i])
            {
                if (has) Crossover(i);
                else TrySteal(i);
            }
        }
        if (act[i] == A_SHOOT)
        {
            actT[i] += dt;
            meter[i] = actT[i] / 0.62;
            bool rel = i == 0 && !dumping && gstate == G_PLAY ? (cActR[i] || !cActH[i]) : meter[i] >= aiRel[i];
            if (rel || meter[i] >= 1.2) Release(i);
        }
        if (act[i] == A_DUNK)
        {
            actT[i] += dt;
            if (dunkSlam[i] > 0)
            {
                dunkSlam[i] -= dt;
                int s = TargetHoop(i);
                plvx[i] = 0; plvy[i] = 0; ply[i] = RIMY - 2.35; plx[i] = HoopX(s) - face[i] * 0.42;
                if (dunkSlam[i] <= 0) { act[i] = A_NONE; plvy[i] = -0.5; }
            }
            else if (has && plvy[i] < 0.9) Slam(i);
            else if (!has && ground[i]) act[i] = A_NONE;
        }

        // fisica
        if (!(act[i] == A_DUNK && dunkSlam[i] > 0))
        {
            plvy[i] -= G * dt;
            ply[i] += plvy[i] * dt;
            plx[i] += plvx[i] * dt;
        }
        if (ply[i] <= 0)
        {
            if (!ground[i] && plvy[i] < -4) { for (int k = 0; k < 4; k++) PSpawn(0, SXf(plx[i]) + (rnd.NextDouble() - 0.5) * 4, floorY, (rnd.NextDouble() - 0.5) * 20, -3, 0.5, Rgb(200, 170, 130), 1.2); }
            ply[i] = 0; plvy[i] = 0;
            if (!ground[i]) { ground[i] = true; blockUp[i] = false; if (act[i] == A_DUNK) act[i] = A_NONE; }
        }
        plx[i] = Math.Max(-1.2, Math.Min(COURT + 1.2, plx[i]));
        if (ground[i]) runPh[i] += Math.Abs(plvx[i]) * dt * 2.3;
        if (fire[i] && rnd.NextDouble() < 0.6) PSpawn(3, SXf(plx[i]) + (rnd.NextDouble() - 0.5) * 3, SYf(ply[i]) - 1, (rnd.NextDouble() - 0.5) * 6, -12 - rnd.NextDouble() * 8, 0.35, Rgb(255, 120, 0), 1);
    }

    static void StartShot(int i)
    {
        int s = TargetHoop(i);
        double d = Math.Abs(HoopX(s) - plx[i]);
        bool toward = Math.Sign(HoopX(s) - plx[i]) == Math.Sign(plvx[i]) || Math.Abs(plvx[i]) < 0.5;
        if (d < 2.6 && toward && d > 0.35)
        {
            // mate: salto hacia el aro
            act[i] = A_DUNK; actT[i] = 0; dunkSlam[i] = 0; ground[i] = false; blockUp[i] = false;
            plvy[i] = 6.1 + (fire[i] ? 0.4 : 0);
            double ta = plvy[i] / G;
            face[i] = HoopX(s) > plx[i] ? 1 : -1;
            plvx[i] = Math.Max(-8, Math.Min(8, ((HoopX(s) - face[i] * 0.42) - plx[i]) / ta));
            return;
        }
        act[i] = A_SHOOT; actT[i] = 0; meter[i] = 0; ground[i] = false; blockUp[i] = false;
        plvy[i] = 4.0; plvx[i] *= 0.3;
        face[i] = HoopX(s) > plx[i] ? 1 : -1;
        if (i == 1 || dumping || gstate != G_PLAY) aiRel[i] = 0.82 + Gauss() * AIERR[diff];
    }

    static void Release(int i)
    {
        int s = TargetHoop(i);
        double zone = fire[i] ? 0.2 : 0.11;
        double q = Cl(1 - Math.Abs(meter[i] - 0.82) / zone);
        act[i] = A_NONE;
        double hx = HoopX(s);
        double sx = bx, sy = by;
        double d = Math.Abs(hx - plx[i]);
        double T = 0.6 + Math.Abs(hx - sx) * 0.055;
        double vx = (hx - sx) / T, vy = (RIMY + 0.02 - sy + 0.5 * G * T * T) / T;
        int o = 1 - i;
        double contest = 0;
        if (Math.Abs(plx[o] - plx[i]) < 1.5 && act[o] != A_FALL) contest = (ground[o] ? 0.035 : 0.075) * (1 - Math.Abs(plx[o] - plx[i]) / 1.5);
        double err = (1 - q) * 0.17 + Math.Max(0, d - 7.2) * 0.025 + contest;
        if (fire[i]) err *= 0.45;
        double e = (rnd.NextDouble() * 2 - 1) * err + Gauss() * 0.006;
        bvx = vx * (1 + e); bvy = vy * (1 + e * 0.4);
        bstate = 2; owner = -1; shooter = i; lastTouch = i; shotT = 0; rimTouch = false; scoredThis = false; grabCD = 0.3;
        shot3 = d > THREE; shotFromX = plx[i];
        buzzerShot = !overtime && clock > 0 && clock < 1.5;
        st[i, 1]++; if (shot3) st[i, 3]++;
        lastQ[i] = q; qT[i] = 1.2;
    }

    static void Slam(int i)
    {
        int s = TargetHoop(i);
        dunkSlam[i] = 0.4;
        bstate = 3; owner = -1; shooter = i; lastTouch = i; shot3 = false; rimTouch = true; scoredThis = false;
        bx = HoopX(s); by = RIMY + 0.3; bvx = 0; bvy = -7.5;
        st[i, 1]++;
        rimShake[s] = 2; shake = 1.2; slowT = 0.45; boardFlash[s] = 1;
        for (int k = 0; k < 24; k++) PSpawn(1, SXf(HoopX(s)), SYf(RIMY), (rnd.NextDouble() - 0.5) * 60, (rnd.NextDouble() - 0.8) * 50, 0.5, 0, 1);
    }

    static void Crossover(int i)
    {
        if (crossCD[i] > 0) return;
        crossCD[i] = 1.3; crossT[i] = 0.35;
        if (cMove[i] == 0) face[i] = -face[i];
        plvx[i] = face[i] * 7;
        int o = 1 - i;
        double dx = Math.Abs(plx[o] - plx[i]);
        if (dx < 1.4 && ground[o] && act[o] == A_NONE && rnd.NextDouble() < (fire[i] ? 0.5 : 0.28))
        {
            act[o] = A_FALL; fallT[o] = 1.3; plvx[o] = 0;
            Msg("ROMPETOBILLOS!", Rgb(255, 120, 255), 1.6); excite = Math.Max(excite, 0.9); slowT = 0.35;
        }
    }

    static void TrySteal(int i)
    {
        if (stealCD[i] > 0) return;
        stealCD[i] = 0.9;
        int o = 1 - i;
        bool ok = bstate == 1 && owner == o && checkT <= 0 && Math.Abs(plx[o] - plx[i]) < 1.15 && act[o] != A_SHOOT && act[o] != A_DUNK && ground[o];
        double ch = 0.3 + (face[o] == (plx[i] > plx[o] ? 1 : -1) ? 0.18 : 0) + (i == 1 ? AISTEAL[diff] : 0) - (crossT[o] > 0 ? 0.2 : 0);
        if (ok && rnd.NextDouble() < ch)
        {
            bstate = 0; owner = -1; lastTouch = i; grabCD = 0.15;
            bvx = face[i] * (2 + rnd.NextDouble()); bvy = 2.5; by = Math.Max(by, 0.8);
            st[i, 6]++;
            Msg("ROBO!", Rgb(0, 230, 255), 1.3); excite = Math.Max(excite, 0.6);
            for (int k = 0; k < 10; k++) PSpawn(1, SXf(bx), SYf(by), (rnd.NextDouble() - 0.5) * 40, -rnd.NextDouble() * 30, 0.4, 0, 1);
        }
        else { act[i] = A_REACH; reachT[i] = 0.45; }
    }

    // ---------------------------------------------------------------- balon
    static void UpdBall(double dt)
    {
        if (bstate == 1)
        {
            int i = owner;
            if (act[i] == A_SHOOT) { bx = plx[i] + face[i] * 0.12; by = ply[i] + 2.32; }
            else if (act[i] == A_DUNK) { bx = plx[i] + face[i] * 0.4; by = ply[i] + 2.3; }
            else if (!ground[i]) { bx = plx[i] + face[i] * 0.3; by = ply[i] + 1.35; }
            else
            {
                dribPh += dt * (6 + Math.Abs(plvx[i]) * 0.9);
                double side = crossT[i] > 0 ? -0.25 : 0.4;
                bx = plx[i] + face[i] * side;
                double c = Math.Abs(Math.Cos(dribPh));
                by = BALLR + (0.9 - BALLR) * c;
                if (c < 0.12 && Frac(dribPh / Math.PI) < 0.1 && Math.Abs(plvx[i]) > 0.5) { }
            }
            bvx = plvx[i]; bvy = 0;
            bspin += plvx[i] * dt * 4;
            return;
        }
        shotT += dt;
        int n = 5; double h = dt / n;
        for (int k = 0; k < n; k++)
        {
            double oy = by;
            bvy -= G * h; bx += bvx * h; by += bvy * h;
            if (by < BALLR)
            {
                by = BALLR;
                if (bvy < 0)
                {
                    if (bstate == 2 && !rimTouch && Math.Abs(bx - HoopX(TargetHoop(shooter))) > 1.0) { Msg("AIRBALL!", Rgb(255, 120, 60), 1.3); }
                    if (bstate == 2 || bstate == 3) bstate = 0;
                    if (bvy < -2) for (int q = 0; q < 3; q++) PSpawn(0, SXf(bx), floorY, (rnd.NextDouble() - 0.5) * 16, -3, 0.4, Rgb(200, 170, 130), 1);
                    bvy = -bvy * 0.72; bvx *= 0.85;
                    if (bvy < 0.7) bvy = 0;
                }
            }
            if (bx < -2.6) { bx = -2.6; bvx = Math.Abs(bvx) * 0.6; }
            if (bx > COURT + 2.6) { bx = COURT + 2.6; bvx = -Math.Abs(bvx) * 0.6; }
            for (int s = 0; s < 2; s++) HoopPhys(s, oy, h);
            if (bstate == 0 && by <= BALLR + 0.001 && bvy == 0) bvx *= 1 - 1.5 * h;
        }
        bspin += bvx * dt * 3;
        if (bstate == 2 && fire[shooter]) PSpawn(3, SXf(bx), SYf(by), (rnd.NextDouble() - 0.5) * 8, (rnd.NextDouble() - 0.5) * 8, 0.3, Rgb(255, 120, 0), 1.4);
    }

    static void HoopPhys(int s, double oy, double h)
    {
        double hx = HoopX(s), bxb = s == 0 ? HXL - BOARDOFF : HXR + BOARDOFF;
        for (int e = -1; e <= 1; e += 2) RimPoint(hx + e * RIMR, RIMY, s);
        // tablero
        if (by > BY0 - BALLR * 0.4 && by < BY1 + BALLR * 0.4)
        {
            double side = s == 0 ? 1 : -1, dd = (bx - bxb) * side;
            if (dd < BALLR && dd > -BALLR * 2.5 && bvx * side < 0)
            {
                bx = bxb + side * BALLR; bvx = -bvx * 0.6; Touch(s, Math.Abs(bvx) > 2.5, false);
            }
        }
        // canasta: cruza el aro hacia abajo por dentro
        if (!scoredThis && oy > RIMY && by <= RIMY && bvy < 0 && Math.Abs(bx - hx) < RIMR - BALLR * 0.55) Scored(s);
        // la red frena y centra el balon
        if (by < RIMY && by > RIMY - 0.55 && Math.Abs(bx - hx) < RIMR)
        {
            bvx += (hx - bx) * 10 * h; bvx *= 1 - 4 * h; if (bvy < -2.5) bvy *= 1 - 3 * h;
            netStretch[s] = 1;
        }
    }

    static void RimPoint(double px, double py, int s)
    {
        double dx = bx - px, dy = by - py, d = Math.Sqrt(dx * dx + dy * dy), r = BALLR + 0.025;
        if (d >= r || d < 1e-6) return;
        double nx = dx / d, ny = dy / d;
        bx = px + nx * r; by = py + ny * r;
        double vn = bvx * nx + bvy * ny;
        if (vn < 0)
        {
            bvx -= 1.55 * vn * nx; bvy -= 1.55 * vn * ny;
            bvx += (rnd.NextDouble() - 0.5) * 0.25;
            Touch(s, -vn > 2.2, true);
        }
    }

    static void Touch(int s, bool hard, bool rim)
    {
        if (!rimTouch && bstate == 2) shotClock = 14;
        rimTouch = true;
        if (bstate == 2) bstate = 0;
        if (rim) rimShake[s] = Math.Max(rimShake[s], hard ? 1 : 0.5);
        else boardFlash[s] = Math.Max(boardFlash[s], 0.6);
        if (hard)
        {
            popTxt = rim ? "CLANK!" : "BANG!"; popT = gt; popX = SXf(bx); popY = SYf(by);
            for (int k = 0; k < 6; k++) PSpawn(1, SXf(bx), SYf(by), (rnd.NextDouble() - 0.5) * 40, (rnd.NextDouble() - 0.7) * 30, 0.3, 0, 1);
        }
    }

    static void Scored(int s)
    {
        scoredThis = true;
        int team = s == 1 ? 0 : 1;
        bool dunk = bstate == 3;
        int pts = dunk ? 2 : (shot3 && shooter == team && bstate == 2 && lastTouch == team) ? 3 : 2;
        score[team] += pts;
        if (shooter == team) { st[team, 0]++; if (pts == 3) st[team, 2]++; if (dunk) st[team, 4]++; }
        streak[team]++; st[team, 7] = Math.Max(st[team, 7], streak[team]);
        if (streak[1 - team] > 0 || fire[1 - team]) { streak[1 - team] = 0; if (fire[1 - team]) { fire[1 - team] = false; } }
        netSway[s] = 1; netStretch[s] = 1; excite = 1; flashT = 0.15;
        string m; int col;
        bool swish = !rimTouch && !dunk;
        if (dunk) { m = fire[team] ? "MATE EN LLAMAS!!" : "MATE!!"; col = Rgb(255, 120, 0); }
        else if (buzzerShot && clock <= 0) { m = "SOBRE LA BOCINA!"; col = Rgb(255, 60, 60); slowT = 0.8; }
        else if (pts == 3) { m = swish ? "TRIPLE LIMPIO!" : "TRIPLE!"; col = Rgb(255, 215, 0); }
        else { m = swish ? "SWISH!" : "CANASTA!"; col = Rgb(120, 255, 140); }
        Msg(m, col, 1.6);
        popTxt = "+" + pts; popT = gt; popX = SXf(HoopX(s)); popY = SYf(RIMY + 0.6);
        if (!fire[team] && streak[team] >= 3) { fire[team] = true; Msg(team == 0 ? "ESTAS EN LLAMAS!" : "LA CPU ESTA EN LLAMAS!", Rgb(255, 100, 0), 2.2); }
        for (int k = 0; k < 40; k++) PSpawn(2, SXf(HoopX(s)) + (rnd.NextDouble() - 0.5) * 6, SYf(RIMY) + 4, (rnd.NextDouble() - 0.5) * 50, -10 - rnd.NextDouble() * 35, 1.5 + rnd.NextDouble(), CONF[rnd.Next(CONF.Length)], 1);
        if (overtime) { pauseT = 1.5; inboundTeam = -1; GameOverDelay = 1.2; }
        else { pauseT = 1.3; inboundTeam = 1 - team; }
        if (!overtime && clock <= 0) { pauseT = 99; inboundTeam = -1; GameOverDelay = 1.4; }
    }
    static double GameOverDelay = -1;

    // saque tras canasta: el que recibe empieza bajo su propio aro
    static void Inbound(int team)
    {
        inboundTeam = -1; pauseT = 0; flashT = 0.2;
        if (team == 1) { plx[1] = COURT - 0.9; face[1] = -1; plx[0] = COURT - 6.5; face[0] = 1; }
        else { plx[0] = 0.9; face[0] = 1; plx[1] = 6.5; face[1] = -1; }
        for (int i = 0; i < 2; i++) { ply[i] = 0; plvx[i] = plvy[i] = 0; ground[i] = true; act[i] = A_NONE; blockUp[i] = false; }
        Grab(team); checkT = 1.0; shotClock = 14;
    }

    static void Turnover(int team)
    {
        bstate = 1; owner = team; lastPoss = team; shotClock = 14; checkT = 0.8;
        if (act[1 - team] == A_SHOOT) act[1 - team] = A_NONE;
    }

    static void Grab(int i)
    {
        bstate = 1; owner = i; lastTouch = i; act[i] = act[i] == A_SHOOT ? A_NONE : act[i];
        if (lastPoss != i) { shotClock = 14; lastPoss = i; }
        scoredThis = false;
    }

    static void Interactions(double dt)
    {
        if (GameOverDelay > 0) { GameOverDelay -= dt; if (GameOverDelay <= 0) { GameOverDelay = -1; GameOver(); } }
        // tapones
        for (int d = 0; d < 2; d++)
        {
            if (ground[d] || !blockUp[d] || act[d] == A_FALL) continue;
            int o = 1 - d;
            double hx = plx[d] + face[d] * 0.15, hy = ply[d] + 2.45;
            bool cand = (bstate == 2 && shooter == o && shotT < 0.45 && bvy > -1.5) || (bstate == 1 && owner == o && (act[o] == A_SHOOT || (act[o] == A_DUNK && plvy[o] > 0)));
            if (!cand) continue;
            double dx = bx - hx, dy = by - hy;
            if (dx * dx + dy * dy < 0.62 * 0.62)
            {
                if (act[o] == A_SHOOT || act[o] == A_DUNK) act[o] = A_NONE;
                bstate = 0; owner = -1; lastTouch = d; grabCD = 0.3;
                bvx = face[d] * (3.5 + rnd.NextDouble() * 2); bvy = 1.5 + rnd.NextDouble() * 2;
                st[d, 5]++;
                Msg("TAPON!", Rgb(255, 60, 60), 1.5); excite = 1; shake = 1; slowT = 0.4;
                for (int k = 0; k < 18; k++) PSpawn(1, SXf(bx), SYf(by), (rnd.NextDouble() - 0.5) * 60, (rnd.NextDouble() - 0.5) * 50, 0.45, 0, 1);
            }
        }
        // choque de cuerpos
        double ddx = plx[1] - plx[0];
        if (Math.Abs(ddx) < 0.72 && act[0] != A_FALL && act[1] != A_FALL && ply[0] < 0.9 && ply[1] < 0.9)
        {
            int c = bstate == 1 ? owner : -1;
            double sg = ddx > 0 ? 1 : ddx < 0 ? -1 : face[0], push = (0.72 - Math.Abs(ddx)) * sg;
            if (c >= 0 && crossT[c] > 0) { }
            else if (c >= 0)
            {
                if (c == 1) plx[1] += push; else plx[0] -= push;
                if (plvx[c] * (c == 1 ? -sg : sg) > 0) plvx[c] *= 0.25;
            }
            else { plx[1] += push / 2; plx[0] -= push / 2; }
        }
        // rebotes y balones sueltos
        if (bstate == 0 && grabCD <= 0)
        {
            int best = -1; double bd = 1e9;
            for (int i = 0; i < 2; i++)
            {
                if (act[i] == A_FALL || act[i] == A_DUNK) continue;
                double reach = ply[i] + (ground[i] ? 2.25 : 2.65);
                double dx = Math.Abs(bx - plx[i]);
                if (dx < 0.6 && by < reach && by > ply[i] + 0.05 && dx < bd) { bd = dx; best = i; }
            }
            if (best >= 0) Grab(best);
        }
    }

    // ---------------------------------------------------------------- IA
    static readonly double[] AIERR = { 0.13, 0.075, 0.045 }, AISPD = { 0.88, 0.97, 1.04 }, AISTEAL = { -0.1, 0, 0.08 }, AIBLK = { 0.38, 0.24, 0.14 };

    static void AI(int i, double dt)
    {
        int o = 1 - i, tgt = TargetHoop(i);
        double hx = HoopX(tgt), ownHx = HoopX(1 - tgt);
        int dir = hx > plx[i] ? 1 : -1;
        cMove[i] = 0; cTurbo[i] = false; cJump[i] = cActP[i] = cDown[i] = false; cActH[i] = true; cActR[i] = false;
        aiDec[i] -= dt; aiBack[i] -= dt;
        if (bstate == 1 && owner == i)
        {
            double dist = Math.Abs(hx - plx[i]);
            bool defAhead = Math.Sign(plx[o] - plx[i]) == dir && Math.Abs(plx[o] - plx[i]) < 1.6 && act[o] != A_FALL;
            bool open = !defAhead;
            if (act[i] != A_NONE) return;
            if (checkT > 0) { cMove[i] = dir; return; }
            bool roll = aiDec[i] <= 0;
            if (roll) aiDec[i] = 0.25 + rnd.NextDouble() * 0.35;
            // tras el paso atras, tira
            if (aiBack[i] > -0.2 && aiBack[i] <= 0) { aiBack[i] = -1; if (dist < 8.2) { cActP[i] = true; return; } }
            if (dist < 2.4 && dist > 0.5 && open) { cActP[i] = true; cMove[i] = dir; return; }
            if (shotClock < 2.0) { cActP[i] = true; return; }
            if (roll && open && dist < 8.0 && dist > 2.4 && rnd.NextDouble() < (dist > THREE ? 0.22 : 0.32)) { cActP[i] = true; return; }
            if (roll && defAhead && dist < 7.4 && rnd.NextDouble() < 0.1) { cActP[i] = true; return; }
            cMove[i] = aiBack[i] > 0 ? -dir : dir;
            cTurbo[i] = open && dist > 8 && stam[i] > 0.4;
            if (defAhead && Math.Abs(plx[o] - plx[i]) < 1.1 && crossCD[i] <= 0 && rnd.NextDouble() < 1.6 * dt) cDown[i] = true;
            else if (defAhead && dist < 9 && dist > 3 && aiBack[i] < -0.9 && rnd.NextDouble() < 0.9 * dt) aiBack[i] = 0.4;
            return;
        }
        if (bstate == 1 && owner == o)
        {
            int odir = HoopX(TargetHoop(o)) > plx[o] ? 1 : -1;
            double guard = plx[o] + odir * 1.0;
            double dx = guard - plx[i];
            if (Math.Abs(dx) > 0.15) cMove[i] = dx > 0 ? 1 : -1;
            cTurbo[i] = Math.Abs(dx) > 3 && stam[i] > 0.3;
            if (ground[i] && Math.Abs(plx[o] - plx[i]) < 1.1 && checkT <= 0 && rnd.NextDouble() < (0.5 + diff * 0.35) * dt) cDown[i] = true;
            if ((act[o] == A_SHOOT || act[o] == A_DUNK) && Math.Abs(plx[o] - plx[i]) < 2.0 && ground[i])
            {
                aiBlockT[i] += dt;
                if (aiBlockT[i] > (i == 1 ? AIBLK[diff] : 0.25)) { cActP[i] = true; aiBlockT[i] = 0; }
            }
            else aiBlockT[i] = 0;
            return;
        }
        // balon suelto o en el aire: a por el rebote
        double tx = bx;
        if (bstate == 2) { int s = TargetHoop(shooter); tx = HoopX(s) + (s == 0 ? 1.2 : -1.2); }
        double ddx = tx - plx[i];
        if (Math.Abs(ddx) > 0.2) cMove[i] = ddx > 0 ? 1 : -1;
        cTurbo[i] = Math.Abs(ddx) > 2.5 && stam[i] > 0.25;
        if (bstate == 0 && ground[i] && by > 2.2 && by < 3.6 && Math.Abs(bx - plx[i]) < 1.0 && bvy < 1) cJump[i] = true;
    }

    // ================================================================ particulas
    // 0 polvo, 1 chispa, 2 confeti, 3 llama, 6 cohete, 7 fuego artificial
    const int PMAX = 1200;
    static double[] qx = new double[PMAX], qy = new double[PMAX], qvx = new double[PMAX], qvy = new double[PMAX], ql = new double[PMAX], qm = new double[PMAX], qs = new double[PMAX];
    static int[] qt = new int[PMAX], qc = new int[PMAX]; static int pn;
    static readonly int[] CONF = { Rgb(255, 40, 60), Rgb(255, 215, 0), Rgb(0, 230, 255), Rgb(120, 255, 80), Rgb(255, 80, 220), Rgb(255, 255, 255), Rgb(255, 140, 0) };

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
                    int c = CONF[rnd.Next(CONF.Length)];
                    for (int k = 0; k < 45; k++) { double a = rnd.NextDouble() * Math.PI * 2, v = 10 + rnd.NextDouble() * 22; PSpawn(7, qx[i], qy[i], Math.Cos(a) * v * 1.4, Math.Sin(a) * v, 0.8 + rnd.NextDouble() * 0.6, c, 1); }
                }
                pn--; qt[i] = qt[pn]; qx[i] = qx[pn]; qy[i] = qy[pn]; qvx[i] = qvx[pn]; qvy[i] = qvy[pn]; ql[i] = ql[pn]; qm[i] = qm[pn]; qc[i] = qc[pn]; qs[i] = qs[pn]; i--;
                continue;
            }
            double g = 0, drag = 1;
            switch (qt[i]) { case 0: g = -2; drag = 3; break; case 1: g = 80; break; case 2: g = 12; drag = 1.5; break; case 3: g = -10; drag = 2; break; case 7: g = 18; drag = 1.2; break; }
            qvy[i] += g * dt; qvx[i] *= 1 - Math.Min(0.9, drag * dt);
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
                case 0: PDisc(qx[i], qy[i], qs[i] * (1 + (1 - f) * 2), qs[i] * (1 + (1 - f) * 1.5) * 0.7, qc[i], 0.4 * f); break;
                case 1: PS(x, y, Lerp(Rgb(255, 90, 0), Rgb(255, 250, 200), f)); PB((int)(qx[i] - qvx[i] * 0.03), (int)(qy[i] - qvy[i] * 0.03), Rgb(255, 160, 40), 0.7 * f); break;
                case 2: PS(x, y, ((int)(ql[i] * 10 + i)) % 3 == 0 ? Scale(qc[i], 0.55) : qc[i]); break;
                case 3: PDisc(qx[i], qy[i], 1.3, 1.3, f > 0.5 ? Lerp(Rgb(255, 90, 0), Rgb(255, 240, 120), (f - 0.5) * 2) : Lerp(Rgb(120, 20, 0), Rgb(255, 90, 0), f * 2), 0.85 * f); break;
                case 6: PS(x, y, Rgb(255, 255, 230)); break;
                case 7: PS(x, y, Scale(qc[i], 0.3 + 0.7 * f)); break;
            }
        }
    }

    // ================================================================ mensajes
    static string msg = ""; static int msgCol; static double msgT = -10, msgDur;
    static string popTxt = ""; static double popT = -10, popX, popY;
    static void Msg(string s, int col, double dur) { msg = s; msgCol = col; msgT = gt; msgDur = dur; }

    // ================================================================ render
    static void Render(double rdt)
    {
        RenderArena();
        HoopBack(0); HoopBack(1);
        // reflejos en el parque
        mirror = true;
        for (int i = 0; i < 2; i++) DrawPlayer(i);
        DrawBall();
        mirror = false;
        // sombras
        for (int i = 0; i < 2; i++) PDisc(SXf(plx[i]), floorY + 0.5, 0.4 * ppm * (1 - Math.Min(0.6, ply[i] * 0.3)), 1.2, Rgb(0, 0, 0), 0.45);
        PDisc(SXf(bx), floorY + 0.5, 0.22 * ppm * (1 - Math.Min(0.7, by * 0.15)), 0.8, Rgb(0, 0, 0), 0.4);
        // jugadores: primero el que no lleva el balon
        int first = owner == 0 ? 1 : 0;
        DrawPlayer(first);
        bool ballBehind = bstate != 1 || owner != first;
        if (!ballBehind) DrawBall();
        DrawPlayer(1 - first);
        if (ballBehind) DrawBall();
        HoopFront(0); HoopFront(1);
        DrawParts();
        for (int i = 0; i < 2; i++) if (act[i] == A_SHOOT) Meter(i);
        if (flashT > 0) for (int k = 0; k < pix.Length; k++) pix[k] = Lerp(pix[k], Rgb(255, 255, 255), flashT * 2);
        if (shake > 0.02) ShakePix(Rd((rnd.NextDouble() - 0.5) * 4 * shake), Rd((rnd.NextDouble() - 0.5) * 3 * shake));

        // interfaz
        Scoreboard();
        MsgPix();
        if (gstate == G_TITLE) TitlePix();
        if (gstate == G_END) EndPix();
        if (paused) { for (int k = 0; k < pix.Length; k++) pix[k] = Lerp(pix[k], Rgb(0, 0, 10), 0.55); F3Out("PAUSA", (W - F3W("PAUSA", 3)) / 2, PH / 2 - 8, 3, Rgb(255, 255, 255), -1); }
        ToCells();
        ScoreText();
        PopText();
        if (gstate == G_PLAY) HudText();
        if (gstate == G_TITLE) TitleText();
        if (gstate == G_END) EndText();
        if (paused) TSC(H / 2 + 3, "P: CONTINUAR     ESC: SALIR", Rgb(255, 255, 255));
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

    // ---------------------------------------------------------------- pabellon
    static double ZY(double z) { return floorY + z * (z < 0 ? 0.85 : (PH - floorY) / 7.5); }

    static void RenderArena()
    {
        int fy = (int)floorY;
        int bandTop = (int)Math.Floor(ZY(-7.5));
        int ribH = 7, ribTop = bandTop - ribH;
        int stTop = Math.Max(4, PH / 10);
        // techo
        for (int y = 0; y < stTop; y++) for (int x = 0; x < PW; x++) pix[y * PW + x] = Lerp(Rgb(8, 8, 20), Rgb(18, 16, 36), (double)y / stTop);
        double cpar = camX * ppm * 0.35;
        for (int k = -2; k < PW / 14 + 3; k++)
        {
            double lx = k * 14 - Frac(cpar / 14) * 14;
            PDisc(lx, 2, 3, 1.5, Rgb(255, 250, 220), 0.6);
            PS((int)lx, 2, Rgb(255, 255, 255));
        }
        // gradas con publico
        double ppar = camX * ppm * 0.5;
        for (int y = stTop; y < ribTop; y++)
        {
            int tier = (y - stTop) / 4, ry = (y - stTop) % 4;
            double depth = (double)(y - stTop) / Math.Max(1, ribTop - stTop);
            int seatC = Lerp(Rgb(20, 22, 45), Rgb(40, 40, 70), depth);
            for (int x = 0; x < PW; x++) pix[y * PW + x] = ry == 3 ? Scale(seatC, 0.6) : seatC;
        }
        for (int tier = 0; tier * 4 + stTop + 3 < ribTop; tier++)
        {
            int baseY = stTop + tier * 4 + 3;
            double depth = (double)(tier * 4) / Math.Max(1, ribTop - stTop);
            double lit = 0.32 + 0.38 * depth + excite * 0.2;
            int p0 = (int)Math.Floor((ppar - 3) / 3);
            for (int p = p0; p <= p0 + PW / 3 + 2; p++)
            {
                double hv = Hash(p, tier, 21);
                if (hv < 0.1) continue;
                int x = (int)(p * 3 - ppar) + (tier % 2);
                double jump = excite * Math.Max(0, Math.Sin(gt * 13 + p * 0.9 + tier * 1.7)) * 2.2 + (Hash(p, tier, (int)(gt * 2)) < 0.08 ? 1 : 0);
                int y = baseY - (int)jump;
                int shirt = CROWD[(int)(Hash(p, tier, 22) * CROWD.Length)], skin = SKINS[(int)(Hash(p, tier, 23) * SKINS.Length)];
                shirt = Scale(shirt, lit); skin = Scale(skin, lit);
                PS(x, y - 2, skin); PS(x, y - 1, shirt); PS(x + 1, y - 1, shirt); PS(x, y, shirt); PS(x + 1, y, Scale(shirt, 0.8));
                if (excite > 0.4 && Hash(p, tier, (int)(gt * 20)) < 0.012 * excite) { PS(x, y - 2, Rgb(255, 255, 255)); PDisc(x + 0.5, y - 2, 2, 1.5, Rgb(255, 255, 255), 0.5); }
                if (excite > 0.6 && Hash(p, tier, 31) < 0.15) PS(x + (Hash(p, tier, 32) < 0.5 ? -1 : 2), y - 2 - (int)jump % 2, skin);
            }
        }
        // pancartas
        for (int k = 0; k < 3; k++)
        {
            double wx = 4 + k * 10;
            int x0 = (int)((wx - camX * 0.5) * ppm * 0.6 + (k * 37) % PW);
            x0 = ((x0 % (PW + 40)) + PW + 40) % (PW + 40) - 20;
            int y0 = stTop + 4 + k % 2 * 6;
            string t = k == 0 ? "DEFENSA" : k == 1 ? "VAMOS" : "MVP";
            int w = F3W(t, 1) + 4;
            PRect(x0, y0, w, 7, k == 1 ? Rgb(120, 120, 130) : Rgb(110, 15, 25));
            F3Pix(t, x0 + 2, y0 + 1, 1, k == 1 ? Rgb(20, 40, 120) : Rgb(170, 170, 175));
        }
        // focos
        for (int k = 0; k < 2; k++)
        {
            double sx = PW * (0.25 + 0.5 * k) + Math.Sin(gt * 0.6 + k * 2) * PW * 0.25;
            double a0 = 0.05 + excite * 0.08;
            for (int y = 0; y < fy; y++)
            {
                double t = (double)y / fy, cx = Lp(PW * 0.5 + (k == 0 ? -10 : 10), sx, t), hw = Lp(1.5, 9, t);
                for (int x = (int)(cx - hw); x <= (int)(cx + hw); x++) PB(x, y, Rgb(255, 245, 220), a0 * (1 - Math.Abs(x + 0.5 - cx) / hw));
            }
        }
        // valla led con texto
        for (int y = ribTop; y < bandTop; y++) for (int x = 0; x < PW; x++) pix[y * PW + x] = Rgb(8, 8, 14);
        string led = excite > 0.7 ? "  CANASTA!!  CANASTA!!  " : "  BASKET 1 VS 1   GRAN FINAL   DEFENSA!   ";
        int lw = led.Length * 4, off = (int)(gt * 18 + camX * ppm * 0.9);
        int ledC = excite > 0.7 ? CONF[((int)(gt * 8)) % CONF.Length] : Scale(Lerp(Rgb(255, 120, 0), Rgb(255, 220, 60), 0.5 + 0.5 * Math.Sin(gt * 2)), 0.55);
        for (int x = 0; x < PW; x++)
        {
            int u = ((x + off) % lw + lw) % lw, ci = u / 4, cx2 = u % 4;
            if (cx2 == 3) continue;
            string g; if (!F3.TryGetValue(led[ci], out g)) continue;
            for (int r = 0; r < 5; r++) if (g[r * 3 + cx2] == '#') PS(x, ribTop + 1 + r, ledC);
        }
        // parque
        for (int y = bandTop; y < PH; y++)
        {
            double z = y < fy ? (y - fy) / 0.85 : (y - fy) / ((PH - floorY) / 7.5);
            double light = 0.78 + 0.22 * Cl((z + 7.5) / 15);
            for (int x = 0; x < PW; x++)
            {
                double wx = camX + (x + 0.5) / ppm;
                int plank = (int)Math.Floor(wx * 2.2 + (y % 2) * 0.5);
                double v = Hash(plank, y, 41);
                int c = Lerp(Rgb(186, 128, 72), Rgb(214, 158, 96), v);
                if (Frac(wx * 2.2 + (y % 2) * 0.5) < 0.08) c = Scale(c, 0.85);
                bool inCourt = wx >= 0 && wx <= COURT && Math.Abs(z) <= 7.5;
                if (!inCourt) c = Lerp(Rgb(110, 40, 40), Rgb(130, 50, 45), v);
                // zona pintada y logo central
                for (int s = 0; s < 2; s++)
                {
                    double bxl = s == 0 ? 0 : COURT, dx = Math.Abs(wx - bxl);
                    if (dx <= 5.8 && Math.Abs(z) < 2.45 && inCourt) c = Lerp(c, s == 0 ? Rgb(30, 70, 180) : Rgb(190, 30, 40), 0.55);
                }
                double cdx = wx - 14, cr = Math.Sqrt(cdx * cdx + z * z);
                if (cr < 1.8) c = Lerp(c, Rgb(120, 20, 30), 0.6);
                c = Scale(c, light);
                // lineas
                double px1 = 1.0 / ppm;
                bool line = false;
                if (inCourt)
                {
                    if (Math.Abs(wx) < px1 * 0.6 || Math.Abs(wx - COURT) < px1 * 0.6 || Math.Abs(wx - 14) < px1 * 0.6) line = true;
                    if (Math.Abs(cr - 1.8) < 0.12) line = true;
                    for (int s = 0; s < 2; s++)
                    {
                        double hx = s == 0 ? HXL : HXR, bxl = s == 0 ? 0 : COURT;
                        if (Math.Abs(z) <= 6.6)
                        {
                            double ax = hx + (s == 0 ? 1 : -1) * Math.Sqrt(Math.Max(0, THREE * THREE - z * z));
                            if (Math.Abs(wx - ax) < px1 * 0.7) line = true;
                        }
                        if (Math.Abs(Math.Abs(z) - 6.6) < 0.25 && Math.Abs(wx - bxl) < 1.6) line = true;
                        double ftx = s == 0 ? 5.8 : COURT - 5.8;
                        if (Math.Abs(wx - ftx) < px1 * 0.6 && Math.Abs(z) < 2.45) line = true;
                        if (Math.Abs(Math.Abs(z) - 2.45) < 0.2 && Math.Abs(wx - bxl) < 5.8) line = true;
                    }
                    if (Math.Abs(Math.Abs(z) - 7.5) < 0.25) line = true;
                }
                if (line) c = Lerp(c, Rgb(250, 250, 250), 0.85 * light);
                pix[y * PW + x] = c;
            }
        }
        // brillo de los focos en el parque
        for (int k = 0; k < 2; k++)
        {
            double sx = PW * (0.25 + 0.5 * k) + Math.Sin(gt * 0.6 + k * 2) * PW * 0.25;
            PDisc(sx, floorY - 1, 12, 2.5, Rgb(255, 245, 220), 0.18 + excite * 0.1);
        }
    }
    static readonly int[] CROWD = { Rgb(220, 30, 45), Rgb(255, 255, 255), Rgb(255, 210, 0), Rgb(30, 90, 225), Rgb(250, 140, 0), Rgb(60, 60, 70), Rgb(0, 170, 120), Rgb(150, 40, 160) };
    static readonly int[] SKINS = { Rgb(240, 200, 160), Rgb(210, 160, 120), Rgb(160, 110, 70), Rgb(110, 70, 45) };

    // ---------------------------------------------------------------- canastas
    static void HoopBack(int s)
    {
        double sd = s == 0 ? -1 : 1;                       // hacia fuera de la pista
        double hx = HoopX(s), bxb = hx + sd * BOARDOFF;
        double base0 = bxb + sd * 1.0, base1 = bxb + sd * 2.4, pole = bxb + sd * 1.8;
        int pad = s == 0 ? Rgb(30, 60, 160) : Rgb(170, 25, 40);
        // base acolchada
        for (double x = Math.Min(base0, base1); x < Math.Max(base0, base1); x += 0.5 / ppm)
            for (double y = 0; y < 0.95; y += 0.5 / ppm) { int px = (int)SXf(x), py = (int)SYf(y); PS(px, py, y > 0.85 ? Scale(pad, 1.3) : pad); }
        WLine(pole, 0.9, pole, 3.75, 0.16, Rgb(150, 150, 165));
        WLine(pole, 3.7, bxb + sd * 0.05, 3.55, 0.12, Rgb(170, 170, 185));
        WLine(pole, 2.6, bxb + sd * 0.05, 3.0, 0.08, Rgb(130, 130, 145));
        // tablero en 3/4: cara de cristal y canto
        double flash = boardFlash[s];
        for (int k = 0; k < (int)(0.42 * ppm) + 1; k++)
        {
            double wx = bxb + sd * (k / ppm);
            int px = (int)SXf(wx);
            int y0 = (int)SYf(BY1) - k / 3, y1 = (int)SYf(BY0) - k / 3;
            for (int py = y0; py <= y1; py++)
            {
                bool frame = py == y0 || py == y1 || k == (int)(0.42 * ppm);
                double fy2 = (double)(py - y0) / Math.Max(1, y1 - y0);
                bool sq = fy2 > 0.45 && fy2 < 0.95 && (k == 1 || k == (int)(0.42 * ppm) - 1) || ((py == (int)Lp(y0, y1, 0.45) || py == (int)Lp(y0, y1, 0.95) - 1) && k >= 1 && k <= (int)(0.42 * ppm) - 1);
                int c = frame ? Rgb(240, 240, 245) : sq ? Rgb(230, 40, 40) : Lerp(Rgb(150, 190, 215), Rgb(255, 255, 255), flash);
                if (frame || sq) PS(px, py, c); else PB(px, py, c, 0.55 + flash * 0.4);
            }
        }
        WLine(bxb, BY0, bxb, BY1, 0.08, Rgb(250, 250, 255));
        // soporte del aro
        WLine(bxb, RIMY, hx + sd * RIMR, RIMY, 0.06, Rgb(200, 90, 30));
        Rim(s, true);
        Net(s, true);
    }

    static void HoopFront(int s) { Net(s, false); Rim(s, false); }

    static void Rim(int s, bool back)
    {
        double hx = HoopX(s), sh = rimShake[s] * Math.Sin(gt * 70) * 1.2;
        for (int k = 0; k < 48; k++)
        {
            double a = Math.PI * 2 * k / 48, sn = Math.Sin(a);
            if ((sn > 0) != back) continue;
            double x = SXf(hx + RIMR * Math.Cos(a)), y = SYf(RIMY) - sn * Math.Max(1, 0.12 * ppm) + sh;
            PS((int)x, (int)y, back ? Rgb(190, 80, 25) : Rgb(255, 120, 35));
        }
    }

    static void Net(int s, bool back)
    {
        double hx = HoopX(s);
        double len = 0.5 + netStretch[s] * 0.18;
        double sway = netSway[s] * Math.Sin(gt * 22) * 0.12;
        for (int k = 0; k < 8; k++)
        {
            double a = Math.PI * 2 * k / 8 + 0.2, sn = Math.Sin(a);
            if ((sn > 0) != back) continue;
            double x0 = SXf(hx + RIMR * Math.Cos(a)), y0 = SYf(RIMY) - sn * Math.Max(1, 0.12 * ppm);
            for (int tw = -1; tw <= 1; tw += 2)
            {
                double a2 = a + tw * 0.75;
                double x1 = SXf(hx + sway + RIMR * 0.5 * Math.Cos(a2)), y1 = SYf(RIMY - len) - Math.Sin(a2) * 0.5;
                PLine(x0, y0, x1, y1, Rgb(240, 240, 245), back ? 0.45 : 0.85);
            }
        }
    }

    // ---------------------------------------------------------------- jugadores
    static double[] jx = new double[11], jy = new double[11];
    // 0 cadera, 1 hombro, 2 cabeza, 3/4 rodilla y pie delanteros, 5/6 traseros, 7/8 codo y mano delanteros, 9/10 traseros
    static void Pose(int i)
    {
        double x = plx[i], y = ply[i]; int f = face[i];
        double sp = Math.Min(1, Math.Abs(plvx[i]) / 5.5), ph = runPh[i];
        bool air = !ground[i];
        double crouch = air ? 0.02 : 0.05 + 0.025 * Math.Sin(gt * 4 + i * 2) + sp * 0.07;
        bool has = bstate == 1 && owner == i;
        bool guarding = !has && bstate == 1 && Math.Abs(plx[owner] - x) < 2.5;
        if (guarding) crouch += 0.12;
        double hipY = y + 0.95 - crouch;
        jx[0] = x; jy[0] = hipY;
        for (int leg = 0; leg < 2; leg++)
        {
            double a, b;
            if (air) { a = leg == 0 ? 0.6 : 0.15; b = leg == 0 ? 1.2 : 0.55; }
            else if (guarding && sp < 0.3) { a = leg == 0 ? 0.35 : -0.35; b = 0.5 + crouch; }
            else { double q = ph + leg * Math.PI; a = Math.Sin(q) * 0.8 * sp + 0.04; b = 0.12 + Math.Max(0, Math.Cos(q)) * 1.1 * sp + crouch * 2.2; }
            double kx = x + Math.Sin(a) * 0.48 * f, ky = hipY - Math.Cos(a) * 0.48;
            double fx = kx + Math.Sin(a - b) * 0.47 * f, fy = ky - Math.Cos(a - b) * 0.47;
            if (!air && fy < y) fy = y;
            jx[3 + leg * 2] = kx; jy[3 + leg * 2] = ky; jx[4 + leg * 2] = fx; jy[4 + leg * 2] = fy;
        }
        double lean = sp * 0.2 * f + (act[i] == A_REACH ? 0.4 * f : 0) + (guarding ? 0.15 * f : 0);
        jx[1] = x + Math.Sin(lean) * 0.6; jy[1] = hipY + Math.Cos(lean) * 0.6;
        jx[2] = jx[1] + Math.Sin(lean) * 0.21; jy[2] = jy[1] + 0.21;
        double sx = jx[1], sy = jy[1] - 0.05;
        double hfx, hfy, hbx, hby;
        if (act[i] == A_SHOOT) { hfx = jx[2] + f * 0.14; hfy = jy[2] + 0.3; hbx = jx[2] + f * 0.04; hby = jy[2] + 0.26; }
        else if (act[i] == A_DUNK) { hfx = sx + f * 0.35; hfy = sy + 0.6; hbx = sx + f * 0.15; hby = sy + 0.55; }
        else if (blockUp[i] && air) { hfx = sx + f * 0.14; hfy = sy + 0.66; hbx = sx + f * 0.02; hby = sy + 0.64; }
        else if (act[i] == A_REACH) { hfx = sx + f * 0.66; hfy = sy - 0.3; hbx = sx - f * 0.2; hby = sy - 0.5; }
        else if (has && air) { hfx = bx - f * 0.05; hfy = by + 0.1; hbx = bx - f * 0.15; hby = by; }
        else if (has) { hfx = bx - f * 0.02; hfy = Math.Max(by + BALLR * 0.8, hipY - 0.12); hbx = sx - f * 0.18; hby = sy - 0.5; }
        else if (guarding) { hfx = sx + f * 0.45; hfy = sy - 0.15; hbx = sx - f * 0.35; hby = sy - 0.05; }
        else { hfx = sx + f * (0.05 + 0.2 * Math.Sin(ph + Math.PI) * sp); hfy = sy - 0.58; hbx = sx + f * (-0.03 + 0.2 * Math.Sin(ph) * sp); hby = sy - 0.58; }
        jx[8] = hfx; jy[8] = hfy; jx[10] = hbx; jy[10] = hby;
        Elbow(sx, sy, hfx, hfy, out jx[7], out jy[7]); Elbow(sx, sy, hbx, hby, out jx[9], out jy[9]);
        if (act[i] == A_FALL)
        {
            double ang = -f * Math.Min(1.45, (1.3 - fallT[i]) * 7);
            double c = Math.Cos(ang), s = Math.Sin(ang);
            for (int k = 0; k < 11; k++) { double dx = jx[k] - x, dy = jy[k] - y; jx[k] = x + dx * c - dy * s; jy[k] = Math.Max(0.05, y + dx * s + dy * c); }
        }
    }

    static void Elbow(double sx, double sy, double hx, double hy, out double ex, out double ey)
    {
        double mx = (sx + hx) / 2, my = (sy + hy) / 2, dx = hx - sx, dy = hy - sy, d = Math.Max(1e-4, Math.Sqrt(dx * dx + dy * dy));
        double L = 0.62, bend = d < L ? Math.Sqrt(Math.Max(0, L * L / 4 - d * d / 4)) : 0;
        double nx = -dy / d, ny = dx / d;
        if (ny > 0) { nx = -nx; ny = -ny; }
        ex = mx + nx * bend; ey = my + ny * bend;
    }

    static void DrawPlayer(int i)
    {
        Pose(i);
        int f = face[i];
        int skin = SKIN[i], jer = JER[i], jer2 = JER2[i], sho = SHO[i], shoe = SHOE[i];
        if (fire[i]) { jer = Lerp(jer, Rgb(255, 140, 0), 0.25 + 0.15 * Math.Sin(gt * 12)); }
        double lw = 0.14;
        int sd = Scale(skin, 0.72);
        // pierna y brazo traseros
        WLine(jx[0], jy[0], jx[5], jy[5], lw, sd); WLine(jx[5], jy[5], jx[6], jy[6], lw, sd);
        WLine(jx[6], jy[6] + 0.03, jx[6] + f * 0.16, jy[6] + 0.03, 0.1, Scale(shoe, 0.75));
        WLine(jx[0], jy[0], Lp(jx[0], jx[5], 0.5), Lp(jy[0], jy[5], 0.5), 0.2, Scale(sho, 0.8));
        WLine(jx[1], jy[1], jx[9], jy[9], lw, sd); WLine(jx[9], jy[9], jx[10], jy[10], lw, sd);
        // torso
        WLine(jx[0], jy[0] + 0.05, jx[1], jy[1], 0.46, jer2);
        WLine(jx[0], jy[0] + 0.07, jx[1], jy[1] - 0.04, 0.36, jer);
        WLine(jx[0], jy[0] - 0.05, jx[0], jy[0] + 0.1, 0.44, sho);
        // pierna delantera
        WLine(jx[0], jy[0], jx[3], jy[3], lw, skin); WLine(jx[3], jy[3], jx[4], jy[4], lw, skin);
        WLine(jx[4], jy[4] + 0.03, jx[4] + f * 0.17, jy[4] + 0.03, 0.11, shoe);
        WLine(jx[0], jy[0], Lp(jx[0], jx[3], 0.5), Lp(jy[0], jy[3], 0.5), 0.22, sho);
        // cabeza
        WDisc(jx[2], jy[2], 0.13, skin);
        WDisc(jx[2] - f * 0.03, jy[2] + 0.06, 0.1, HAIR[i]);
        if (i == 0) WLine(jx[2] - 0.12, jy[2] + 0.03, jx[2] + 0.12, jy[2] + 0.03, 0.05, Rgb(255, 255, 255));
        // brazo delantero
        WLine(jx[1], jy[1], jx[7], jy[7], lw, skin); WLine(jx[7], jy[7], jx[8], jy[8], lw, skin);
        // indicador del jugador
        if (!mirror && i == 0 && gstate == G_PLAY)
        {
            int px = (int)SXf(plx[i]), py = (int)SYf(Math.Max(jy[2], jy[8]) + 0.45);
            int col = ((int)(gt * 3)) % 2 == 0 ? Rgb(255, 230, 0) : Rgb(255, 255, 255);
            PS(px - 1, py, col); PS(px, py, col); PS(px + 1, py, col); PS(px, py + 1, col);
        }
    }

    static void DrawBall()
    {
        double r = Math.Max(1.5, 0.22 * ppm), cx = SXf(bx), cy = SYf(by);
        double ca = Math.Cos(bspin), sa = Math.Sin(bspin);
        int x0 = (int)Math.Floor(cx - r), x1 = (int)Math.Ceiling(cx + r), y0 = (int)Math.Floor(cy - r), y1 = (int)Math.Ceiling(cy + r);
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                double dx = (x + 0.5 - cx) / r, dy = (y + 0.5 - cy) / r;
                if (dx * dx + dy * dy > 1) continue;
                double l = Cl(0.62 - dx * 0.35 - dy * 0.4);
                int c = Lerp(Rgb(150, 55, 10), Rgb(255, 165, 70), l);
                double u = dx * ca + dy * sa;
                if (Math.Abs(u) < 0.2 && r > 2) c = Rgb(60, 25, 5);
                PP(x, y, c);
            }
    }

    // barra de tiro sobre el jugador
    static void Meter(int i)
    {
        int x = (int)SXf(plx[i]) + face[i] * -5, top = (int)SYf(ply[i] + 2.6) - 12, h = 12;
        double zone = fire[i] ? 0.2 : 0.11;
        for (int k = 0; k < h; k++)
        {
            double v = 1.15 * (1 - (double)k / h);
            bool inZone = Math.Abs(v - 0.82) < zone * 0.5;
            int c = v <= meter[i] ? (inZone ? Rgb(0, 255, 120) : Rgb(255, 255, 255)) : (inZone ? Rgb(0, 90, 50) : Rgb(30, 30, 40));
            PS(x, top + k, c); PS(x + 1, top + k, c);
        }
        PS(x - 1, top - 1, Rgb(200, 200, 210)); PS(x + 2, top - 1, Rgb(200, 200, 210));
    }

    // ---------------------------------------------------------------- marcador gigante
    static void Scoreboard()
    {
        int w = 46, x0 = (W - w) / 2;
        Panel(x0, 0, w, 7, 0.92, -1);
        for (int x = x0; x < x0 + w; x++) { bool on = ((x + (int)(gt * 10)) % 4) < 2; PS(x, 0, on ? Rgb(255, 200, 60) : Rgb(80, 60, 20)); PS(x, 13, on ? Rgb(255, 200, 60) : Rgb(80, 60, 20)); }
        PRect(x0 + 1, 2, 14, 11, Scale(JER[0], 0.55)); PRect(x0 + w - 15, 2, 14, 11, Scale(JER[1], 0.55));
        string a = score[0].ToString(), b = score[1].ToString();
        F3Pix(a, x0 + 8 - F3W(a, 2) / 2, 3, 2, Rgb(255, 255, 255));
        F3Pix(b, x0 + w - 8 - F3W(b, 2) / 2, 3, 2, Rgb(255, 255, 255));
        string ck = overtime ? "OT" : gstate == G_TITLE ? "--:--" : ((int)Math.Ceiling(clock) / 60) + ":" + ((int)Math.Ceiling(clock) % 60).ToString("00");
        F3Pix(ck, x0 + w / 2 - F3W(ck, 1) / 2, 3, 1, Rgb(255, 210, 60));
        string sc = gstate == G_PLAY ? ((int)Math.Ceiling(Math.Max(0, shotClock))).ToString() : "";
        F3Pix(sc, x0 + w / 2 - F3W(sc, 1) / 2, 9, 1, shotClock < 4 ? Rgb(255, 50, 50) : Rgb(255, 120, 60));
        if (fire[0] && ((int)(gt * 6)) % 2 == 0) PRect(x0 + 1, 2, 14, 1, Rgb(255, 120, 0));
        if (fire[1] && ((int)(gt * 6)) % 2 == 0) PRect(x0 + w - 15, 2, 14, 1, Rgb(255, 120, 0));
        if (owner >= 0 && gstate == G_PLAY) { int px = owner == 0 ? x0 + 16 : x0 + w - 17; PRect(px, 6, 1, 3, Rgb(255, 255, 255)); }
    }

    static void ScoreText()
    {
        int w = 46, x0 = (W - w) / 2;
        TS(x0 + 2, 1, TNAME[0], Rgb(255, 255, 255));
        TS(x0 + w - 2 - TNAME[1].Length, 1, TNAME[1], Rgb(255, 255, 255));
    }

    static void MsgPix()
    {
        double age = gt - msgT;
        if (msg.Length == 0 || age > msgDur) return;
        int sc = W >= 100 && F3W(msg, 2) < W - 6 ? 2 : 1;
        int tw = F3W(msg, sc), x = (W - tw) / 2, y = 17;
        if (age < 0.12) { y -= (int)((0.12 - age) * 40); }
        int col = ((int)(age * 10)) % 2 == 0 ? msgCol : Lerp(msgCol, Rgb(255, 255, 255), 0.5);
        if (age > msgDur - 0.3 && ((int)(age * 16)) % 2 == 0) return;
        F3Out(msg, x, y, sc, col, Scale(col, 0.6));
    }

    static void PopText()
    {
        double age = gt - popT;
        if (popTxt.Length == 0 || age > 1.0) return;
        int x = (int)popX - popTxt.Length / 2, y = (int)((popY - age * 12) / 2);
        TS(x, y, popTxt, popTxt[0] == '+' ? Rgb(255, 230, 0) : Rgb(255, 255, 255));
    }

    static void HudText()
    {
        int gr = Rgb(170, 175, 190);
        // turbo
        TS(1, H - 3, "TURBO", gr);
        int bw = 14;
        for (int k = 0; k < bw; k++) TC(7 + k, H - 3, '\u2588', k < stam[0] * bw ? (stam[0] > 0.3 ? Rgb(0, 220, 120) : Rgb(255, 120, 40)) : Rgb(40, 40, 50));
        if (fire[0] && ((int)(gt * 5)) % 2 == 0) TS(1, H - 4, "EN LLAMAS!", Rgb(255, 120, 0));
        if (qT[0] > 0 && gt - 0 > 0) { }
        TSC(H - 1, "\u2190 \u2192 MOVER   \u2191 SALTAR   ESPACIO: TIRAR/TAPON   \u2193 QUIEBRO/ROBO   SHIFT: TURBO   P: PAUSA", gr);
        for (int i = 0; i < 2; i++)
        {
            qT[i] = Math.Max(0, qT[i] - 1.0 / 30);
            if (qT[i] > 0 && i == 0)
            {
                string q = lastQ[i] > 0.85 ? "PERFECTO!" : lastQ[i] > 0.5 ? "BIEN" : lastQ[i] > 0.2 ? "REGULAR" : "MAL TIRO";
                int qc2 = lastQ[i] > 0.85 ? Rgb(0, 255, 120) : lastQ[i] > 0.5 ? Rgb(200, 255, 80) : lastQ[i] > 0.2 ? Rgb(255, 200, 0) : Rgb(255, 70, 60);
                TS((int)SXf(plx[i]) - q.Length / 2, (int)(SYf(ply[i] + 2.9) / 2) - 1, q, qc2);
            }
        }
    }

    // ---------------------------------------------------------------- portada y final
    static void TitlePix()
    {
        for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Rgb(5, 3, 15), 0.5);
        int sc = W >= 110 && H >= 34 ? 2 : 1;
        int w = BigW("BASKET", sc);
        BigPix("BASKET", (W - w) / 2, 8, sc, Rgb(255, 170, 60), Rgb(220, 70, 10), Rgb(100, 30, 5), Frac(gt / 3.5) * (w + 40) - 20);
        int vy = 8 + 6 * sc + 1, vw = BigW("1 VS 1", 1);
        BigPix("1 VS 1", (W - vw) / 2, vy, 1, Rgb(255, 255, 255), Rgb(160, 165, 190), Rgb(60, 60, 80), -100);
        Panel(W / 2 - 32, vy + 7, 64, Math.Min(10, H - vy - 8), 0.82, Rgb(255, 140, 0));
    }

    static void TitleText()
    {
        int vy = 8 + 6 * (W >= 110 && H >= 34 ? 2 : 1) + 1, y = vy + 8;
        int wh = Rgb(255, 255, 255), gr = Rgb(170, 175, 190), yl = Rgb(255, 210, 60);
        TSC(y, "DIFICULTAD:  \u2190  " + DIFN[diff].PadRight(7) + "  \u2192", yl);
        TSC(y + 1, "DURACION:    \u2191  " + (LENS[lenIdx] / 60 + " MIN").PadRight(7) + "  \u2193", yl);
        if (((int)(gt * 2.5)) % 2 == 0) TSC(y + 3, ">>  PULSA ENTER PARA JUGAR  <<", wh);
        if (y + 9 < H)
        {
            TSC(y + 5, "\u2190 \u2192 mover    \u2191 saltar / rebote    SHIFT turbo", gr);
            TSC(y + 6, "ESPACIO: manten y suelta en la zona verde para tirar", gr);
            TSC(y + 7, "cerca del aro = MATE  /  en defensa = TAPON", gr);
            TSC(y + 8, "\u2193: quiebro (con balon) / robo (en defensa)", gr);
        }
    }

    static void EndPix()
    {
        for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Rgb(5, 3, 15), 0.45);
        bool won = score[0] > score[1];
        string t = won ? "VICTORIA!" : "DERROTA";
        int sc = W >= 100 ? 3 : 2;
        F3Out(t, (W - F3W(t, sc)) / 2, 18, sc, won ? Rgb(255, 215, 0) : Rgb(255, 80, 70), won ? Rgb(255, 140, 0) : Rgb(150, 30, 30));
        Panel(W / 2 - 28, 18 / 2 + 5 * sc / 2 + 3, 56, 11, 0.85, won ? Rgb(255, 215, 0) : Rgb(255, 80, 70));
        if (won && Frac(stT / 0.6) < 1.0 / 30 / 0.6)
            PSpawn(6, PW * (0.1 + rnd.NextDouble() * 0.8), PH * 0.8, (rnd.NextDouble() - 0.5) * 10, -50 - rnd.NextDouble() * 15, 0.6 + rnd.NextDouble() * 0.3, 0, 1);
    }

    static void EndText()
    {
        int sc = W >= 100 ? 3 : 2, y = 18 / 2 + 5 * sc / 2 + 4, x = W / 2 - 26;
        int wh = Rgb(255, 255, 255), gr = Rgb(170, 175, 190);
        TSC(y, "RESULTADO FINAL:   TU " + score[0] + "  -  " + score[1] + " CPU", Rgb(255, 210, 60));
        TS(x, y + 2, "ESTADISTICAS          TU        CPU", gr);
        string[] lab = { "Tiros de campo", "Triples", "Mates", "Tapones", "Robos", "Mejor racha" };
        for (int k = 0; k < lab.Length; k++)
        {
            string a, b;
            if (k == 0) { a = st[0, 0] + "/" + st[0, 1]; b = st[1, 0] + "/" + st[1, 1]; }
            else if (k == 1) { a = st[0, 2] + "/" + st[0, 3]; b = st[1, 2] + "/" + st[1, 3]; }
            else { int idx = k == 2 ? 4 : k == 3 ? 5 : k == 4 ? 6 : 7; a = st[0, idx].ToString(); b = st[1, idx].ToString(); }
            TS(x, y + 3 + k, lab[k], wh); TS(x + 22, y + 3 + k, a, Rgb(255, 120, 120)); TS(x + 32, y + 3 + k, b, Rgb(120, 170, 255));
        }
        if (((int)(gt * 2)) % 2 == 0 && stT > 1.5) TSC(Math.Min(H - 2, y + 10), "ENTER: VOLVER AL MENU     ESC: SALIR", wh);
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
[Basket]::Run()
exit 0
