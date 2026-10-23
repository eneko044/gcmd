<# : -------- parte BATCH (PowerShell la ve como un comentario) --------
@echo off
setlocal
title COUNTER CMD
color 0F
cls
echo.
echo   [*] COUNTER CMD
echo   [*] Preparando el motor 3D, espera unos segundos...
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

public static class CounterCmd
{
    // ================================================================ consola de Windows
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool WriteConsoleW(IntPtr h, string s, int n, out int w, IntPtr r);
    [DllImport("kernel32.dll")] static extern bool FlushConsoleInputBuffer(IntPtr h);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
    [StructLayout(LayoutKind.Sequential)] struct POINT { public int X, Y; }
    [StructLayout(LayoutKind.Sequential)] struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
    [DllImport("user32.dll")] static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
    [StructLayout(LayoutKind.Sequential)] struct SRECT { public short L, T, R, B; }
    [StructLayout(LayoutKind.Sequential)] struct CSBI { public short sx, sy, cx, cy; public short attr; public SRECT win; public short mx, my; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct FONTEX { public int cbSize; public int nFont; public short fw, fh; public int family; public int weight; [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string face; }
    [DllImport("kernel32.dll")] static extern bool GetConsoleScreenBufferInfo(IntPtr h, out CSBI i);
    [DllImport("kernel32.dll")] static extern bool SetConsoleScreenBufferSize(IntPtr h, int size);
    [DllImport("kernel32.dll")] static extern bool SetConsoleWindowInfo(IntPtr h, bool abs, ref SRECT r);
    [DllImport("kernel32.dll")] static extern int GetLargestConsoleWindowSize(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool GetCurrentConsoleFontEx(IntPtr h, bool max, ref FONTEX f);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] static extern bool SetCurrentConsoleFontEx(IntPtr h, bool max, ref FONTEX f);

    const string E = "\u001b[";
    const char UPB = '\u2580';
    const string TITLE = "COUNTER CMD";
    static readonly CultureInfo INV = CultureInfo.InvariantCulture;

    static IntPtr hOut, hIn; static bool win, hadMode, hadInMode; static uint oldMode, oldInMode;
    static int W = 120, H = 40, PW = 120, PH = 80;
    static int[] pix; static char[] cb, pcb; static int[] cc, cbg, pcc, pcbg; static bool fullDraw = true;
    static StringBuilder sb = new StringBuilder(1 << 18);
    static Random rnd = new Random(11);
    static volatile bool quit; static bool dumping;
    static double gt, fps, fpsT; static int fpsN;

    // ================================================================ arranque
    public static void Run()
    {
        Setup();
        if (!win && Environment.OSVersion.Platform == PlatformID.Win32NT) { Restore(); Console.WriteLine("Esta consola no soporta colores ANSI (hace falta Windows 10 o superior)."); return; }
        try
        {
            Stopwatch sw = Stopwatch.StartNew(); double last = 0;
            while (!quit)
            {
                double t = sw.Elapsed.TotalSeconds; double dt = Math.Min(0.06, t - last); last = t;
                CheckSize(); ReadInput(); Frame(dt); Present();
                fpsN++; if (t - fpsT > 1) { fps = fpsN / (t - fpsT); fpsN = 0; fpsT = t; }
                int ms = (int)((1.0 / 40 - (sw.Elapsed.TotalSeconds - t)) * 1000);
                if (ms > 1) Thread.Sleep(ms);
            }
        }
        finally { Restore(); }
    }

    static void Setup()
    {
        try
        {
            hOut = GetStdHandle(-11); hIn = GetStdHandle(-10);
            uint m;
            if (GetConsoleMode(hOut, out m)) { oldMode = m; hadMode = true; win = SetConsoleMode(hOut, m | 0x0004 | 0x0001); }
            // sin "edicion rapida": un clic no congela la consola
            if (GetConsoleMode(hIn, out m)) { oldInMode = m; hadInMode = true; SetConsoleMode(hIn, (m & ~0x40u) | 0x80u | 0x10u); }
        }
        catch { win = false; }
        try { Console.Title = TITLE; } catch { }
        try { Console.CursorVisible = false; } catch { }
        try { Console.CancelKeyPress += OnCancel; } catch { }
        FontSetup();
        ReadSize(); Alloc(); Init();
        Out(E + "?25l" + E + "0m" + E + "2J");
    }
    static void OnCancel(object s, ConsoleCancelEventArgs e) { e.Cancel = true; quit = true; }

    static void Restore()
    {
        NetBye();
        Out(E + "0m" + E + "2J" + E + "H" + E + "?25h");
        FontRestore();
        try { Console.CursorVisible = true; } catch { }
        if (hadMode) { try { SetConsoleMode(hOut, oldMode); } catch { } }
        if (hadInMode) { try { SetConsoleMode(hIn, oldInMode); } catch { } }
        try { FlushConsoleInputBuffer(hIn); } catch { }
    }

    // letra mas pequena en la consola clasica = mas resolucion
    static readonly int[] FSIZES = { 6, 8, 10, 12, 14, 16 };
    static int fIdx = 2; static bool fontCtl; static FONTEX origFont; static CSBI origInfo;
    static void FontSetup()
    {
        if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("WT_SESSION"))) return;
        try
        {
            origFont = new FONTEX(); origFont.cbSize = Marshal.SizeOf(typeof(FONTEX));
            if (!GetCurrentConsoleFontEx(hOut, false, ref origFont)) return;
            if (!GetConsoleScreenBufferInfo(hOut, out origInfo)) return;
            fontCtl = true; ApplyFont();
        }
        catch { fontCtl = false; }
    }
    static void ApplyFont()
    {
        if (!fontCtl) return;
        try
        {
            FONTEX f = new FONTEX(); f.cbSize = Marshal.SizeOf(typeof(FONTEX)); f.fh = (short)FSIZES[fIdx]; f.family = 54; f.weight = 400; f.face = "Consolas";
            SetCurrentConsoleFontEx(hOut, false, ref f);
            int big = GetLargestConsoleWindowSize(hOut);
            int c = Math.Max(80, Math.Min(190, (big & 0xFFFF) - 2)), l = Math.Max(26, Math.Min(62, ((big >> 16) & 0xFFFF) - 2));
            SRECT tiny = new SRECT(); tiny.R = 1; tiny.B = 1;
            SetConsoleWindowInfo(hOut, true, ref tiny);
            SetConsoleScreenBufferSize(hOut, (l << 16) | c);
            SRECT r = new SRECT(); r.R = (short)(c - 1); r.B = (short)(l - 1);
            SetConsoleWindowInfo(hOut, true, ref r);
        }
        catch { }
    }
    static void FontRestore()
    {
        if (!fontCtl) return;
        try
        {
            SetCurrentConsoleFontEx(hOut, false, ref origFont);
            SRECT tiny = new SRECT(); tiny.R = 1; tiny.B = 1;
            SetConsoleWindowInfo(hOut, true, ref tiny);
            SetConsoleScreenBufferSize(hOut, (origInfo.sy << 16) | (ushort)origInfo.sx);
            SRECT r = origInfo.win; SetConsoleWindowInfo(hOut, true, ref r);
        }
        catch { }
    }

    static void ReadSize()
    {
        if (dumping) return;
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
        pix = new int[PW * PH];
        cb = new char[W * H]; cc = new int[W * H]; cbg = new int[W * H];
        pcb = new char[W * H]; pcc = new int[W * H]; pcbg = new int[W * H]; fullDraw = true;
        zbuf = new double[PW];
    }

    // ================================================================ teclado y raton
    static readonly int[] WATCH = { 0x01, 0x02, 0x09, 0x0D, 0x10, 0x11, 0x1B, 0x20, 0x25, 0x26, 0x27, 0x28,
        0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x47, 0x48, 0x4D, 0x4E, 0x51, 0x52, 0x53, 0x55, 0x57, 0x5A,
        0x6B, 0x6D, 0xBB, 0xBD, 0x70 };
    static bool[] kNow = new bool[256], kPrev = new bool[256];
    static bool Key(int vk) { return kNow[vk]; }
    static bool Press(int vk) { return kNow[vk] && !kPrev[vk]; }
    static bool mouseOn = true, focused = true; static double mdx, mdy;
    static StringBuilder titleBuf = new StringBuilder(256);
    static bool typing;

    static void ReadInput()
    {
        for (int i = 0; i < 256; i++) kPrev[i] = kNow[i];
        mdx = mdy = 0;
        if (dumping) { for (int i = 0; i < 256; i++) kNow[i] = false; DumpKeys(); return; }
        try
        {
            IntPtr fg = GetForegroundWindow();
            titleBuf.Length = 0; GetWindowText(fg, titleBuf, 256);
            focused = titleBuf.ToString().IndexOf(TITLE, StringComparison.OrdinalIgnoreCase) >= 0;
            foreach (int vk in WATCH) kNow[vk] = focused && (GetAsyncKeyState(vk) & 0x8000) != 0;
            // el raton gira la vista: lo devolvemos al centro de la ventana cada fotograma
            if (focused && mouseOn && WantMouse())
            {
                RECT r; POINT p;
                if (GetWindowRect(fg, out r) && GetCursorPos(out p))
                {
                    int cx = (r.L + r.R) / 2, cy = (r.T + r.B) / 2;
                    mdx = p.X - cx; mdy = p.Y - cy;
                    if (Math.Abs(mdx) > 400 || Math.Abs(mdy) > 400) { mdx = 0; mdy = 0; }
                    SetCursorPos(cx, cy);
                }
            }
            if (!typing) FlushConsoleInputBuffer(hIn);
        }
        catch { }
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
    static double Lp(double a, double b, double t) { return a + (b - a) * t; }
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
    static double AngDiff(double a, double b) { double d = a - b; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; return d; }

    // ---------------------------------------------------------------- pixeles (2 por celda en vertical)
    static void PS(int x, int y, int c) { if ((uint)x < (uint)PW && (uint)y < (uint)PH) pix[y * PW + x] = c; }
    static void PB(int x, int y, int c, double a) { if ((uint)x < (uint)PW && (uint)y < (uint)PH) { int i = y * PW + x; pix[i] = Lerp(pix[i], c, a); } }
    static void PRect(int x, int y, int w, int h, int c) { for (int yy = y; yy < y + h; yy++) for (int xx = x; xx < x + w; xx++) PS(xx, yy, c); }
    static void PRectB(int x, int y, int w, int h, int c, double a) { for (int yy = y; yy < y + h; yy++) for (int xx = x; xx < x + w; xx++) PB(xx, yy, c, a); }
    static void PDisc(double cx, double cy, double r, int c, double a)
    {
        int x0 = (int)Math.Floor(cx - r), x1 = (int)Math.Ceiling(cx + r), y0 = (int)Math.Floor(cy - r), y1 = (int)Math.Ceiling(cy + r);
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                double dx = (x + 0.5 - cx) / r, dy = (y + 0.5 - cy) / r, d = dx * dx + dy * dy;
                if (d <= 1) PB(x, y, c, a * (1 - d * 0.6));
            }
    }
    static void PLine(double x0, double y0, double x1, double y1, int c, double a)
    {
        int n = (int)Math.Max(Math.Abs(x1 - x0), Math.Abs(y1 - y0)) + 1;
        for (int k = 0; k <= n; k++) { double t = (double)k / n; PB((int)Math.Round(Lp(x0, x1, t)), (int)Math.Round(Lp(y0, y1, t)), c, a); }
    }
    static void Panel(int cx, int cy, int cw, int ch, double a, int accent)
    {
        for (int y = cy * 2; y < (cy + ch) * 2; y++)
            for (int x = cx; x < cx + cw; x++) PB(x, y, Rgb(8, 10, 16), a);
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
        BIG['A'] = new string[] { " #####7 ", "##F==##7", "#######|", "##F==##|", "##|  ##|", "L=J  L=J" };
        BIG['S'] = new string[] { "#######7", "##F====J", "#######7", "L====##|", "#######|", "L======J" };
        BIG['C'] = new string[] { " ######7", "##F====J", "##|     ", "##|     ", "L######7", " L=====J" };
        BIG['I'] = new string[] { "##7", "##|", "##|", "##|", "##|", "L=J" };
        BIG['T'] = new string[] { "########7", "L==##F==J", "   ##|   ", "   ##|   ", "   ##|   ", "   L=J   " };
        BIG['R'] = new string[] { "######7 ", "##F==##7", "######FJ", "##F==##7", "##|  ##|", "L=J  L=J" };
        BIG['K'] = new string[] { "##7  ##7", "##| ##FJ", "#####FJ ", "##F##7  ", "##| L##7", "L=J  L=J" };
        BIG['E'] = new string[] { "#######7", "##F====J", "#####7  ", "##F==J  ", "#######7", "L======J" };
        BIG['O'] = new string[] { " ######7 ", "##F===##7", "##|   ##|", "##|   ##|", "L######FJ", " L=====J " };
        BIG['U'] = new string[] { "##7   ##7", "##|   ##|", "##|   ##|", "##|   ##|", "L######FJ", " L=====J " };
        BIG['N'] = new string[] { "###7   ##7", "####7  ##|", "##F##7 ##|", "##|L##7##|", "##| L####|", "L=J  L===J" };
        BIG['M'] = new string[] { "###7   ###7", "####7 ####|", "##F####F##|", "##|L##FJ##|", "##| L=J ##|", "L=J     L=J" };
        BIG['D'] = new string[] { "######7 ", "##F==##7", "##|  ##|", "##|  ##|", "######FJ", "L=====J " };
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
            "$.##|##.|.#.|.##|##.", "+...|.#.|###|.#.|...", "/..#|..#|.#.|#..|#.." };
        foreach (string g in t) F3[g[0]] = g.Substring(1).Replace("|", "");
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

    // ================================================================ el mapa (estilo desierto)
    //  # arenisca   % piedra oscura   = ladrillo   X cajas   . suelo   a zona A   b zona B   t base T   c base CT
    static readonly string[] MAP = {
        "##################################",
        "############==========############",
        "##bbbbbbbbb#=cccccccc=#aaaaaaaaa##",
        "##bbbbbbbbb..cccccccX..aaaaaaaaa##",
        "##bbXXbbbbb..cccccccc..aaaXXaaaa##",
        "##bbXbbbbbb..cccccccc..aaaXaaaaa##",
        "##bbbbbbbbb#=cccccccc=#aaaaaaaaa##",
        "##bbbbbbXbb#===....===#aaaaaaXaa##",
        "##bbbbbbbbb####....####aaaaaaaaa##",
        "##Xbbbbbbbb####....####aaaaaaaaX##",
        "###%..%%%%%%%%#...........#....###",
        "###%..%%%%%%%%#...........#....###",
        "###%..%%%%%%%%#%..%########....###",
        "###%...............########....###",
        "###%...............########....###",
        "###%..%%%%%%%%#....########%..%###",
        "###%..%%%%%%%%#....########%..%###",
        "###%..%%%%%%%%#....########....###",
        "###%.........%#.X..########....###",
        "###%...X.....%#....########..X.###",
        "###%.........%#....########....###",
        "###%%%%%%%...%#....########....###",
        "##########...##....#####.......###",
        "##########...##....####........###",
        "##########...##....####........###",
        "##########.ttttt..ttttt...########",
        "###########ttttttttttttt##########",
        "###########ttttttttttXtt##########",
        "###########ttXtttttttttt##########",
        "###########ttttttttttttt##########",
        "###########ttttttttttttt##########",
        "###########ttttttttttttt##########",
        "##################################",
        "##################################" };
    static int MW, MH; static char[] tiles;
    static char Tile(int x, int y) { return (x < 0 || y < 0 || x >= MW || y >= MH) ? '#' : tiles[y * MW + x]; }
    static bool Solid(int x, int y) { char c = Tile(x, y); return c == '#' || c == '%' || c == '=' || c == 'X'; }
    static bool SolidAt(double x, double y) { return Solid((int)Math.Floor(x), (int)Math.Floor(y)); }
    static bool IsSite(int x, int y, char s) { return Tile(x, y) == s; }

    // ---------------------------------------------------------------- texturas procedurales
    const int TSZ = 32;
    static int[][] tex = new int[10][];
    const int TX_SAND = 0, TX_STONE = 1, TX_BRICK = 2, TX_CRATE = 3, TX_FLOOR = 4, TX_SITE = 5, TX_TSPAWN = 6, TX_CTSPAWN = 7;
    static readonly double SUNX = 0.55, SUNY = -0.62, SUNEL = 0.85;   // el sol (direccion en el plano y elevacion)
    static float[] shadowMap; const int SHR = 8;

    static int Noisy(int c, double n) { return Scale(c, 0.86 + n * 0.28); }
    static double VNoise(double x, double y, int s)
    {
        int ix = (int)Math.Floor(x), iy = (int)Math.Floor(y); double fx = x - ix, fy = y - iy;
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
        double a = Hash(ix, iy, s), b = Hash(ix + 1, iy, s), c = Hash(ix, iy + 1, s), d = Hash(ix + 1, iy + 1, s);
        return Lp(Lp(a, b, fx), Lp(c, d, fx), fy);
    }

    static void BuildTextures()
    {
        for (int t = 0; t < tex.Length; t++) tex[t] = new int[TSZ * TSZ];
        for (int y = 0; y < TSZ; y++)
            for (int x = 0; x < TSZ; x++)
            {
                int i = y * TSZ + x;
                double n = Hash(x, y, 1), n2 = VNoise(x / 6.0, y / 6.0, 3);
                // arenisca: bloques grandes con juntas
                {
                    int row = y / 8, off = (row % 2) * 8, bx = (x + off) % 16, by = y % 8;
                    bool joint = by == 0 || bx == 0;
                    int c = Lerp(Rgb(214, 182, 128), Rgb(190, 152, 100), n2);
                    if (Hash((x + off) / 16, row, 9) > 0.6) c = Lerp(c, Rgb(226, 196, 142), 0.5);
                    c = Noisy(c, n);
                    if (joint) c = Scale(c, 0.72);
                    else if (by == 1 || bx == 1) c = Scale(c, 1.08);
                    if (y > 26) c = Lerp(c, Rgb(150, 115, 75), (y - 26) / 10.0);   // suciedad abajo
                    tex[TX_SAND][i] = c;
                }
                // piedra oscura
                {
                    int row = y / 6, off = (row % 2) * 5, bx = (x + off) % 10, by = y % 6;
                    int c = Lerp(Rgb(132, 120, 104), Rgb(104, 96, 86), Hash((x + off) / 10, row, 4));
                    c = Noisy(c, n);
                    if (by == 0 || bx == 0) c = Scale(c, 0.65);
                    tex[TX_STONE][i] = c;
                }
                // ladrillo de la base CT (yeso azulado con ladrillo a la vista)
                {
                    int row = y / 4, off = (row % 2) * 4, bx = (x + off) % 8, by = y % 4;
                    int c = Lerp(Rgb(168, 92, 70), Rgb(140, 74, 58), Hash((x + off) / 8, row, 5));
                    if (by == 0 || bx == 0) c = Rgb(190, 180, 165);
                    double pl = VNoise(x / 9.0, y / 7.0, 8);
                    if (pl > 0.42 && y < 24) c = Lerp(Rgb(170, 186, 196), Rgb(150, 166, 180), n2);  // yeso
                    tex[TX_BRICK][i] = Noisy(c, n);
                }
                // caja de madera
                {
                    int c = Lerp(Rgb(170, 120, 62), Rgb(140, 96, 48), Frac(y * 0.37 + Hash(0, x / 3, 6)) * 0.6 + n * 0.2);
                    if ((x / 8) % 2 == 0) c = Scale(c, 0.93);
                    bool frame = x < 3 || x > 28 || y < 3 || y > 28;
                    bool diag = Math.Abs(x - y) < 3 || Math.Abs(x + y - 31) < 3;
                    if (frame || diag) c = Lerp(Rgb(120, 82, 40), Rgb(100, 68, 34), n);
                    if ((x == 3 || x == 28 || y == 3 || y == 28)) c = Scale(c, 0.6);
                    if (frame && (x == 1 || x == 30) && (y == 1 || y == 30)) c = Rgb(70, 70, 75);
                    tex[TX_CRATE][i] = c;
                }
                // suelos
                {
                    double big = VNoise(x / 10.0, y / 10.0, 11);
                    tex[TX_FLOOR][i] = Noisy(Lerp(Rgb(200, 168, 116), Rgb(178, 146, 98), big), n);
                    bool j = x % 16 == 0 || y % 16 == 0;
                    int st = Lerp(Rgb(176, 160, 136), Rgb(156, 142, 120), Hash(x / 16, y / 16, 12));
                    tex[TX_SITE][i] = Noisy(j ? Scale(st, 0.7) : st, n);
                    tex[TX_TSPAWN][i] = Noisy(Lerp(Rgb(190, 150, 100), Rgb(168, 128, 84), VNoise(x / 5.0, y / 5.0, 13)), n);
                    bool j2 = x % 8 == 0 || y % 8 == 0;
                    tex[TX_CTSPAWN][i] = Noisy(j2 ? Rgb(120, 118, 112) : Rgb(150, 148, 140), n);
                }
            }
    }

    // sombras del sol en el suelo (se calculan una vez)
    static void BuildShadows()
    {
        shadowMap = new float[MW * SHR * MH * SHR];
        double len = 1.0 / Math.Tan(SUNEL);
        double l = Math.Sqrt(SUNX * SUNX + SUNY * SUNY), dx = SUNX / l, dy = SUNY / l;
        for (int y = 0; y < MH * SHR; y++)
            for (int x = 0; x < MW * SHR; x++)
            {
                double wx = (x + 0.5) / SHR, wy = (y + 0.5) / SHR;
                float s = 1;
                if (!SolidAt(wx, wy))
                {
                    for (double d = 0.05; d < len; d += 0.05)
                        if (SolidAt(wx + dx * d, wy + dy * d)) { s = 0.55f + 0.2f * (float)(d / len); break; }
                    // oclusion ambiental: rincones mas oscuros
                    int tx = (int)wx, ty = (int)wy; double fx = wx - tx, fy = wy - ty; double ao = 1;
                    if (Solid(tx - 1, ty)) ao = Math.Min(ao, 0.7 + 0.3 * Cl(fx / 0.35));
                    if (Solid(tx + 1, ty)) ao = Math.Min(ao, 0.7 + 0.3 * Cl((1 - fx) / 0.35));
                    if (Solid(tx, ty - 1)) ao = Math.Min(ao, 0.7 + 0.3 * Cl(fy / 0.35));
                    if (Solid(tx, ty + 1)) ao = Math.Min(ao, 0.7 + 0.3 * Cl((1 - fy) / 0.35));
                    s *= (float)ao;
                }
                shadowMap[y * MW * SHR + x] = s;
            }
    }
    static float ShadowAt(double x, double y)
    {
        int ix = (int)(x * SHR), iy = (int)(y * SHR);
        if (ix < 0 || iy < 0 || ix >= MW * SHR || iy >= MH * SHR) return 1;
        return shadowMap[iy * MW * SHR + ix];
    }

    // letras pintadas de las zonas de bomba
    static int SiteLetter(int tx, int ty)
    {
        if (Tile(tx, ty) == 'X' || !Solid(tx, ty)) return 0;
        for (int k = 0; k < 4; k++)
        {
            int nx = tx + (k == 0 ? 1 : k == 1 ? -1 : 0), ny = ty + (k == 2 ? 1 : k == 3 ? -1 : 0);
            char c = Tile(nx, ny);
            if ((c == 'a' || c == 'b') && Hash(tx, ty, 77) < 0.16) return c;
        }
        return 0;
    }

    // ================================================================ camara y render 3D (raycasting)
    static double camX, camY, camA, camPitch, camH = 0.5, fov = 1.25;
    static double focal, horizon;
    static double[] zbuf = new double[1];
    static readonly int HAZE = Rgb(236, 206, 160);

    static int SkyCol(int y, double ang)
    {
        double t = Cl((horizon - y) / (PH * 0.9));
        int c = Lerp(Rgb(246, 214, 160), Rgb(96, 150, 214), Math.Pow(t, 0.7));
        c = Lerp(c, Rgb(40, 84, 160), Cl((t - 0.6) * 1.5));
        // sol
        double sa = Math.Atan2(SUNY, SUNX), d = Math.Abs(AngDiff(ang, sa));
        double sy = horizon - Math.Tan(SUNEL * 0.5) * focal;
        double dd = Math.Sqrt(d * d * focal * focal + (y - sy) * (y - sy));
        if (dd < PH * 0.6) c = Lerp(c, Rgb(255, 240, 200), Math.Pow(1 - dd / (PH * 0.6), 3) * 0.8);
        if (dd < PH * 0.05) c = Rgb(255, 252, 235);
        // nubes
        double cl = VNoise(ang * 6 + gt * 0.01, (horizon - y) / (PH * 0.12), 21);
        if (cl > 0.62 && t > 0.08) c = Lerp(c, Rgb(255, 250, 245), Cl((cl - 0.62) * 3) * 0.7);
        return c;
    }

    static void Render3D()
    {
        focal = (PW / 2.0) / Math.Tan(fov / 2);
        horizon = PH / 2.0 + Math.Tan(camPitch) * focal;
        double dx = Math.Cos(camA), dy = Math.Sin(camA), plx = -dy, ply = dx;
        int hz = (int)Math.Floor(horizon);
        for (int x = 0; x < PW; x++)
        {
            double cxs = (x + 0.5 - PW / 2.0) / focal;
            double rx = dx + plx * cxs, ry = dy + ply * cxs;
            int mx = (int)Math.Floor(camX), my = (int)Math.Floor(camY);
            double ddx = Math.Abs(1 / (rx == 0 ? 1e-9 : rx)), ddy = Math.Abs(1 / (ry == 0 ? 1e-9 : ry));
            int sx, sy; double sdx, sdy;
            if (rx < 0) { sx = -1; sdx = (camX - mx) * ddx; } else { sx = 1; sdx = (mx + 1 - camX) * ddx; }
            if (ry < 0) { sy = -1; sdy = (camY - my) * ddy; } else { sy = 1; sdy = (my + 1 - camY) * ddy; }
            int side = 0; int guard = 0;
            while (guard++ < 200)
            {
                if (sdx < sdy) { sdx += ddx; mx += sx; side = 0; } else { sdy += ddy; my += sy; side = 1; }
                if (Solid(mx, my)) break;
            }
            double pd = side == 0 ? sdx - ddx : sdy - ddy;
            if (pd < 0.02) pd = 0.02;
            zbuf[x] = pd;
            double wu = side == 0 ? camY + pd * ry : camX + pd * rx; wu -= Math.Floor(wu);
            if ((side == 0 && rx > 0) || (side == 1 && ry < 0)) wu = 1 - wu;
            char tc = Tile(mx, my);
            int[] tx = tc == '%' ? tex[TX_STONE] : tc == '=' ? tex[TX_BRICK] : tc == 'X' ? tex[TX_CRATE] : tex[TX_SAND];
            int letter = SiteLetter(mx, my);
            // luz del sol segun la cara
            double nx = side == 0 ? -sx : 0, ny = side == 1 ? -sy : 0;
            double lit = 0.62 + 0.38 * Math.Max(0, (nx * SUNX + ny * SUNY) / Math.Sqrt(SUNX * SUNX + SUNY * SUNY));
            double fog = 1 - Math.Exp(-pd * 0.045);
            double top = horizon - (1 - camH) * focal / pd, bot = horizon + camH * focal / pd;
            int y0 = Math.Max(0, (int)Math.Ceiling(top)), y1 = Math.Min(PH - 1, (int)Math.Floor(bot));
            double ang = camA + Math.Atan(cxs);
            for (int y = 0; y < Math.Min(y0, PH); y++) pix[y * PW + x] = SkyCol(y, ang);
            int ux = Math.Min(TSZ - 1, (int)(wu * TSZ));
            for (int y = y0; y <= y1; y++)
            {
                double v = (y + 0.5 - top) / (bot - top);
                int vy = Math.Min(TSZ - 1, Math.Max(0, (int)(v * TSZ)));
                int c = tx[vy * TSZ + ux];
                if (letter != 0 && v > 0.18 && v < 0.62 && wu > 0.2 && wu < 0.8)
                {
                    string g = F3[letter == 'a' ? 'A' : 'B'];
                    int gx = (int)((wu - 0.2) / 0.6 * 3), gy = (int)((v - 0.18) / 0.44 * 5);
                    if (gx >= 0 && gx < 3 && gy >= 0 && gy < 5 && g[gy * 3 + gx] == '#') c = Lerp(c, Rgb(200, 40, 30), 0.85);
                }
                double ao = 1 - 0.25 * Math.Max(0, (v - 0.85) / 0.15);
                c = Scale(c, lit * ao);
                pix[y * PW + x] = Lerp(c, HAZE, fog);
            }
            // suelo con texturas y sombras
            for (int y = Math.Max(0, Math.Max(y1 + 1, hz + 1)); y < PH; y++)
            {
                double rd = camH * focal / (y + 0.5 - horizon);
                double fx = camX + rx * rd, fy = camY + ry * rd;
                int tx2 = (int)Math.Floor(fx), ty2 = (int)Math.Floor(fy);
                char fc = Tile(tx2, ty2);
                int[] ft = fc == 'a' || fc == 'b' ? tex[TX_SITE] : fc == 't' ? tex[TX_TSPAWN] : fc == 'c' ? tex[TX_CTSPAWN] : tex[TX_FLOOR];
                int u = (int)((fx - tx2) * TSZ) & (TSZ - 1), vv = (int)((fy - ty2) * TSZ) & (TSZ - 1);
                int c = ft[vv * TSZ + u];
                c = Scale(c, ShadowAt(fx, fy));
                double f2 = 1 - Math.Exp(-rd * 0.045);
                pix[y * PW + x] = Lerp(c, HAZE, f2);
            }
        }
    }

    // proyecta un punto del mundo a la pantalla: devuelve la profundidad (<=0 si esta detras)
    static double Project(double wx, double wy, double wz, out double sx, out double sy)
    {
        double dx = wx - camX, dy = wy - camY;
        double c = Math.Cos(camA), s = Math.Sin(camA);
        double depth = dx * c + dy * s, lat = -dx * s + dy * c;
        sx = 0; sy = 0;
        if (depth <= 0.05) return -1;
        sx = PW / 2.0 + lat / depth * focal;
        sy = horizon - (wz - camH) / depth * focal;
        return depth;
    }

    // ---------------------------------------------------------------- sprites de los soldados
    const int SPW = 24, SPH = 40;
    static int[][] sprites;   // [equipo*10 + vista*5 + pose]  pose: 0 quieto 1 andar 2 andar 3 disparar ; 4 = muerto
    static int SprIdx(int team, int view, int pose) { return team * 10 + view * 5 + pose; }

    static void BuildSprites()
    {
        sprites = new int[20][];
        for (int team = 0; team < 2; team++)
            for (int view = 0; view < 2; view++)
                for (int pose = 0; pose < 5; pose++)
                {
                    int[] s = new int[SPW * SPH];
                    for (int i = 0; i < s.Length; i++) s[i] = -1;
                    if (pose == 4) DrawDead(s, team); else DrawSoldier(s, team, view, pose);
                    sprites[SprIdx(team, view, pose)] = s;
                }
    }
    static void SP(int[] s, int x, int y, int c) { if (x >= 0 && y >= 0 && x < SPW && y < SPH) s[y * SPW + x] = c; }
    static void SR(int[] s, int x0, int y0, int w, int h, int c) { for (int y = y0; y < y0 + h; y++) for (int x = x0; x < x0 + w; x++) SP(s, x, y, c); }
    static void SDisc(int[] s, double cx, double cy, double r, int c) { for (int y = (int)(cy - r - 1); y <= cy + r + 1; y++) for (int x = (int)(cx - r - 1); x <= cx + r + 1; x++) if ((x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy) <= r * r) SP(s, x, y, c); }

    static void DrawSoldier(int[] s, int team, int view, int pose)
    {
        bool ct = team == 1;
        int skin = Rgb(206, 156, 116), boot = Rgb(38, 32, 28);
        int shirt = ct ? Rgb(52, 74, 112) : Rgb(150, 122, 74), vest = ct ? Rgb(38, 52, 78) : Rgb(96, 84, 58);
        int pants = ct ? Rgb(44, 56, 80) : Rgb(104, 92, 66), head = ct ? Rgb(46, 58, 72) : Rgb(40, 38, 36);
        int gun = Rgb(34, 34, 38);
        int l1 = pose == 1 ? -2 : pose == 2 ? 2 : 0;
        // piernas
        SR(s, 8, 25, 3, 11 + Math.Min(0, l1), pants); SR(s, 13, 25, 3, 11 - Math.Max(0, l1), pants);
        SR(s, 8, 36 + Math.Min(0, l1), 4, 3, boot); SR(s, 13, 36 - Math.Max(0, l1), 4, 3, boot);
        SR(s, 7, 23, 10, 3, Scale(pants, 0.9));
        // cuerpo
        SR(s, 6, 11, 12, 13, shirt);
        SR(s, 7, 12, 10, 10, vest);
        for (int y = 12; y < 22; y += 3) SR(s, 8, y, 8, 1, Scale(vest, 0.8));
        // cabeza
        SDisc(s, 12, 6.5, 4.2, view == 0 ? skin : head);
        if (ct) { SDisc(s, 12, 4.8, 4.6, head); SR(s, 7, 5, 10, 1, Scale(head, 0.75)); }
        else SDisc(s, 12, 5.5, 4.3, head);   // pasamontanas
        if (view == 0)
        {
            if (ct) { SR(s, 9, 6, 6, 2, Rgb(20, 22, 26)); SR(s, 10, 6, 1, 1, Rgb(120, 180, 220)); }
            else { SR(s, 9, 6, 6, 2, skin); SP(s, 10, 6, Rgb(30, 20, 15)); SP(s, 13, 6, Rgb(30, 20, 15)); }
        }
        SR(s, 10, 10, 4, 2, view == 0 ? skin : head);
        if (view == 1) { SR(s, 8, 12, 8, 9, ct ? Rgb(60, 66, 74) : Rgb(80, 70, 48)); SR(s, 9, 13, 6, 1, Scale(vest, 0.6)); }
        // brazos y arma
        if (view == 0)
        {
            SR(s, 4, 12, 3, 8, shirt); SR(s, 17, 12, 3, 8, shirt);
            SR(s, 6, 18, 12, 3, gun); SR(s, 10, 16, 4, 6, gun);
            SR(s, 5, 19, 3, 2, skin); SR(s, 16, 18, 3, 2, skin);
            if (pose == 3) { SDisc(s, 12, 19, 3, Rgb(255, 230, 120)); SDisc(s, 12, 19, 1.5, Rgb(255, 255, 230)); }
        }
        else
        {
            SR(s, 4, 12, 3, 9, shirt); SR(s, 17, 12, 3, 9, shirt);
            SR(s, 3, 20, 3, 2, skin); SR(s, 18, 20, 3, 2, skin);
            SR(s, 18, 14, 2, 8, gun);
        }
    }
    static void DrawDead(int[] s, int team)
    {
        bool ct = team == 1;
        int shirt = ct ? Rgb(52, 74, 112) : Rgb(150, 122, 74), pants = ct ? Rgb(44, 56, 80) : Rgb(104, 92, 66), head = ct ? Rgb(46, 58, 72) : Rgb(40, 38, 36);
        SR(s, 2, 34, 20, 4, Rgb(120, 24, 20));           // sangre
        SR(s, 4, 33, 9, 4, shirt); SR(s, 13, 34, 8, 3, pants); SDisc(s, 3, 34.5, 2.2, head);
        SR(s, 21, 35, 3, 2, Rgb(38, 32, 28));
        SR(s, 8, 37, 9, 1, Rgb(34, 34, 38));
    }

    // dibuja un sprite (billboard) con su profundidad
    static void DrawBillboard(int[] img, int iw, int ih, double wx, double wy, double wz0, double hgt, double wid, double tint, int flash)
    {
        double sx, sy, sy2;
        double depth = Project(wx, wy, wz0 + hgt, out sx, out sy);
        if (depth <= 0) return;
        double dummy; Project(wx, wy, wz0, out dummy, out sy2);
        double sw = wid / depth * focal, sh = sy2 - sy;
        int x0 = (int)Math.Floor(sx - sw / 2), x1 = (int)Math.Ceiling(sx + sw / 2), y0 = (int)Math.Floor(sy), y1 = (int)Math.Ceiling(sy2);
        double fog = 1 - Math.Exp(-depth * 0.045);
        for (int x = Math.Max(0, x0); x <= Math.Min(PW - 1, x1); x++)
        {
            if (zbuf[x] < depth) continue;
            int u = (int)((x + 0.5 - (sx - sw / 2)) / sw * iw); if (u < 0 || u >= iw) continue;
            for (int y = Math.Max(0, y0); y <= Math.Min(PH - 1, y1); y++)
            {
                int v = (int)((y + 0.5 - sy) / sh * ih); if (v < 0 || v >= ih) continue;
                int c = img[v * iw + u]; if (c < 0) continue;
                c = Scale(c, tint);
                if (flash > 0) c = Lerp(c, Rgb(255, 60, 40), 0.5);
                pix[y * PW + x] = Lerp(c, HAZE, fog);
            }
        }
    }

    // ---------------------------------------------------------------- particulas en el mundo
    class Part { public double x, y, z, vx, vy, vz, life, max, size; public int col, kind; }
    static List<Part> parts = new List<Part>();
    static void Spawn(int kind, double x, double y, double z, double vx, double vy, double vz, double life, int col, double size)
    {
        if (parts.Count > 600) return;
        Part p = new Part(); p.kind = kind; p.x = x; p.y = y; p.z = z; p.vx = vx; p.vy = vy; p.vz = vz; p.life = p.max = life; p.col = col; p.size = size;
        parts.Add(p);
    }
    // 0 chispa  1 sangre  2 humo  3 fuego  4 polvo
    static void UpdParts(double dt)
    {
        for (int i = parts.Count - 1; i >= 0; i--)
        {
            Part p = parts[i];
            p.life -= dt;
            if (p.life <= 0) { parts.RemoveAt(i); continue; }
            if (p.kind == 2) { p.vz += 0.25 * dt; p.vx *= 1 - dt; p.vy *= 1 - dt; p.size += dt * 0.25; }
            else if (p.kind == 3) { p.vz += 0.6 * dt; p.vx *= 1 - 2 * dt; p.vy *= 1 - 2 * dt; }
            else p.vz -= 6 * dt;
            double nx = p.x + p.vx * dt, ny = p.y + p.vy * dt;
            if (SolidAt(nx, p.y)) p.vx = -p.vx * 0.3; else p.x = nx;
            if (SolidAt(p.x, ny)) p.vy = -p.vy * 0.3; else p.y = ny;
            p.z += p.vz * dt;
            if (p.z < 0) { p.z = 0; p.vz = -p.vz * 0.3; p.vx *= 0.6; p.vy *= 0.6; }
        }
    }
    static void DrawParts()
    {
        foreach (Part p in parts)
        {
            double sx, sy, d = Project(p.x, p.y, p.z, out sx, out sy);
            if (d <= 0) continue;
            int ix = (int)sx; if (ix < 0 || ix >= PW || zbuf[ix] < d - 0.05) continue;
            double a = p.life / p.max;
            double r = Math.Max(0.6, p.size / d * focal);
            int c = p.col;
            if (p.kind == 3) c = Lerp(Rgb(255, 250, 200), Rgb(230, 80, 20), 1 - a);
            double alpha = p.kind == 2 ? 0.55 * a : p.kind == 3 ? 0.9 * a : Math.Min(1, a * 2);
            if (r < 1.2) PB(ix, (int)sy, c, alpha); else PDisc(sx, sy, r, c, alpha);
        }
    }

    // trazadoras de las balas
    class Tracer { public double x0, y0, z0, x1, y1, z1, life; public int col; }
    static List<Tracer> tracers = new List<Tracer>();
    static void AddTracer(double x0, double y0, double z0, double x1, double y1, double z1, int col)
    {
        Tracer t = new Tracer(); t.x0 = x0; t.y0 = y0; t.z0 = z0; t.x1 = x1; t.y1 = y1; t.z1 = z1; t.life = 0.09; t.col = col; tracers.Add(t);
    }
    static void DrawTracers(double dt)
    {
        for (int i = tracers.Count - 1; i >= 0; i--)
        {
            Tracer t = tracers[i]; t.life -= dt;
            if (t.life <= 0) { tracers.RemoveAt(i); continue; }
            // recortamos al plano cercano
            const int N = 24;
            double px = 0, py = 0; bool have = false;
            for (int k = 0; k <= N; k++)
            {
                double f = (double)k / N;
                double wx = Lp(t.x0, t.x1, f), wy = Lp(t.y0, t.y1, f), wz = Lp(t.z0, t.z1, f), sx, sy;
                double d = Project(wx, wy, wz, out sx, out sy);
                if (d <= 0) { have = false; continue; }
                int ix = (int)sx;
                bool vis = ix >= 0 && ix < PW && zbuf[ix] > d;
                if (have && vis) PLine(px, py, sx, sy, t.col, 0.75 * t.life / 0.09);
                px = sx; py = sy; have = vis;
            }
        }
    }

    // ================================================================ armas
    const int W_KNIFE = 0, W_GLOCK = 1, W_USP = 2, W_DEAGLE = 3, W_MP5 = 4, W_AK = 5, W_M4 = 6, W_AWP = 7, W_HE = 8, W_C4 = 9;
    static readonly string[] WN = { "CUCHILLO", "GLOCK", "USP", "DEAGLE", "MP5", "AK-47", "M4A1", "AWP", "GRANADA", "C4" };
    static readonly int[] WPRICE = { 0, 200, 200, 700, 1500, 2700, 3100, 4750, 300, 0 };
    static readonly int[] WDMG = { 55, 28, 34, 62, 27, 36, 33, 115, 0, 0 };
    static readonly double[] WRATE = { 0.55, 0.15, 0.17, 0.36, 0.08, 0.1, 0.09, 1.45, 1, 1 };
    static readonly int[] WMAG = { 0, 20, 12, 7, 30, 30, 30, 10, 1, 1 };
    static readonly int[] WRES = { 0, 120, 24, 35, 120, 90, 90, 30, 0, 0 };
    static readonly double[] WSPREAD = { 0, 0.012, 0.009, 0.018, 0.016, 0.011, 0.009, 0.0015, 0, 0 };
    static readonly double[] WMOVE = { 0, 0.02, 0.02, 0.04, 0.025, 0.06, 0.05, 0.14, 0, 0 };
    static readonly double[] WKICK = { 0, 0.012, 0.011, 0.045, 0.008, 0.02, 0.015, 0.06, 0, 0 };
    static readonly bool[] WAUTO = { false, false, false, false, true, true, true, false, false, false };
    static readonly double[] WRELOAD = { 0, 2.0, 2.1, 2.2, 2.5, 2.4, 2.9, 3.5, 0, 0 };
    static readonly int[] WREWARD = { 1500, 300, 300, 300, 600, 300, 300, 100, 300, 0 };
    static readonly double[] WSPEED = { 1.05, 1.0, 1.0, 0.97, 0.97, 0.88, 0.9, 0.8, 1.0, 0.95 };
    static int SlotOf(int w) { return w == W_KNIFE ? 2 : w <= W_DEAGLE ? 1 : w <= W_AWP ? 0 : w == W_HE ? 3 : 4; }

    // ================================================================ jugadores (tu, otros humanos y bots)
    class Ent
    {
        public string key, name; public int kind, team;          // kind: 0 tu, 1 humano de otro PC, 2 bot
        public double x, y, a, pitch, vx, vy, walk;
        public int hp, armor, money = 800;
        public bool alive, crouch;
        public int prim = -1, sec = W_GLOCK, nades, cur = W_GLOCK, lastW = W_KNIFE;
        public int[] clip = new int[10], res = new int[10];
        public double cool, reload, hurtT, shotT, recoil, plantP, defuseP;
        public int shots, kills, deaths;
        public bool hasBomb;
        // red
        public double nx, ny, na, npitch, nT = -9; public long nid;
        // bots
        public List<int> path = new List<int>(); public int goal = -1; public double think, react, aimErr = 0.1, strafe, holdT, burst;
        public Ent target; public double lastSeenX, lastSeenY, lastSeenT = -99; public double lookA;
        public int role;
    }
    static List<Ent> ents = new List<Ent>();
    static Ent me;
    const double EYE = 0.62, EYEC = 0.44, PRAD = 0.24, PHGT = 0.9;
    static int myTeam = 0;   // 0 terroristas, 1 antiterroristas
    static readonly string[] TEAMN = { "TERRORISTAS", "ANTITERRORISTAS" };
    static readonly int[] TEAMC = { Rgb(240, 170, 60), Rgb(90, 160, 255) };

    static Ent FindEnt(string key) { foreach (Ent e in ents) if (e.key == key) return e; return null; }
    static double Eye(Ent e) { return e.crouch ? EYEC : EYE; }

    static void GiveDefault(Ent e)
    {
        e.sec = e.team == 0 ? W_GLOCK : W_USP;
        e.clip[e.sec] = WMAG[e.sec]; e.res[e.sec] = WRES[e.sec];
        e.cur = e.prim >= 0 ? e.prim : e.sec;
    }
    static void Refill(Ent e)
    {
        for (int w = 1; w <= W_AWP; w++) { e.clip[w] = WMAG[w]; e.res[w] = WRES[w]; }
    }

    // ================================================================ partida y rondas
    const int PH_FREEZE = 0, PH_LIVE = 1, PH_END = 2, PH_OVER = 3;
    static int round, phase, scoreT, scoreCT, lastWinner = -1, roundsToWin = 8;
    static double phaseT;
    static string roundMsg = "";
    static int bombState;   // 0 en la mochila, 1 en el suelo, 2 plantada, 3 explotada, 4 desactivada
    static double bombX, bombY, bombT; static string bombCarrier = "";
    const double BOMBTIME = 40, PLANTTIME = 3.2, DEFUSETIME = 5.0, FREEZE = 5, ROUNDTIME = 115, ENDTIME = 5;
    static bool inGame; static int matchId;
    static List<string> feed = new List<string>(); static List<double> feedT = new List<double>(); static List<int> feedC = new List<int>();

    static void AddFeed(string s, int c) { feed.Add(s); feedT.Add(gt); feedC.Add(c); if (feed.Count > 6) { feed.RemoveAt(0); feedT.RemoveAt(0); feedC.RemoveAt(0); } }

    static List<int> spawnT = new List<int>(), spawnCT = new List<int>(), siteA = new List<int>(), siteB = new List<int>(), floorTiles = new List<int>();
    static void IndexMap()
    {
        MW = MAP[0].Length; MH = MAP.Length; tiles = new char[MW * MH];
        for (int y = 0; y < MH; y++) for (int x = 0; x < MW; x++) tiles[y * MW + x] = MAP[y][x];
        for (int i = 0; i < tiles.Length; i++)
        {
            char c = tiles[i];
            if (c == 't') spawnT.Add(i); else if (c == 'c') spawnCT.Add(i); else if (c == 'a') siteA.Add(i); else if (c == 'b') siteB.Add(i);
            if (c == '.' || c == 't' || c == 'c' || c == 'a' || c == 'b') floorTiles.Add(i);
        }
    }

    // empieza una partida nueva con los humanos dados (clave, nombre, equipo) y bots hasta 5 contra 5
    static void NewMatch(List<string> keys, List<string> names, List<int> teams, int seed, int mid)
    {
        ents.Clear(); parts.Clear(); tracers.Clear(); nades.Clear(); feed.Clear(); feedT.Clear(); feedC.Clear();
        matchId = mid; rnd = new Random(seed);
        int[] cnt = new int[2];
        for (int i = 0; i < keys.Count; i++)
        {
            Ent e = new Ent(); e.key = keys[i]; e.name = names[i]; e.team = teams[i];
            e.kind = keys[i] == MyKey() ? 0 : 1; e.nT = gt;
            long id; if (keys[i].Length > 1 && long.TryParse(keys[i].Substring(1), out id)) e.nid = id;
            ents.Add(e); cnt[e.team]++;
            if (e.kind == 0) { me = e; myTeam = e.team; }
        }
        string[] BOTN = { "LOBO", "HALCON", "COBRA", "TIGRE", "ZORRO", "PUMA", "OSO", "RAYO", "TITAN", "FANTASMA", "VIBORA", "JAGUAR" };
        int bn = 0;
        for (int t = 0; t < 2; t++)
            while (cnt[t] < 5)
            {
                Ent b = new Ent(); b.key = "B" + bn; b.name = "BOT " + BOTN[(bn + seed) % BOTN.Length]; b.kind = 2; b.team = t; bn++;
                b.aimErr = 0.05 + rnd.NextDouble() * 0.05; b.role = cnt[t];
                ents.Add(b); cnt[t]++;
            }
        foreach (Ent e in ents) { e.money = 800; e.kills = e.deaths = 0; e.prim = -1; e.armor = 0; e.nades = 0; e.alive = false; }
        scoreT = scoreCT = 0; round = 0; lastWinner = -1; inGame = true;
        if (IsHost()) StartRound(1);
    }

    static void StartRound(int r)
    {
        round = r; phase = PH_FREEZE; phaseT = FREEZE;
        bombState = 0; bombT = BOMBTIME; nades.Clear();
        // el anfitrion elige quien lleva la bomba
        if (IsHost())
        {
            List<Ent> ts = new List<Ent>(); foreach (Ent e in ents) if (e.team == 0) ts.Add(e);
            Ent c = null;
            foreach (Ent e in ts) if (e.kind != 2 && rnd.NextDouble() < 0.5) { c = e; break; }
            if (c == null && ts.Count > 0) c = ts[rnd.Next(ts.Count)];
            bombCarrier = c != null ? c.key : "";
            planSite = rnd.Next(2); tStage = planSite * 2 + rnd.Next(2); tRush = false;
        }
        int[] idx = new int[2];
        List<Ent> order = new List<Ent>(ents); order.Sort(delegate(Ent p, Ent q) { return string.CompareOrdinal(p.key, q.key); });
        foreach (Ent e in order)
        {
            if (e.kind == 1) continue;   // los demas humanos se colocan solos
            Respawn(e, idx[e.team]++);
        }
        foreach (Ent e in ents) e.hasBomb = e.key == bombCarrier;
        parts.Clear(); tracers.Clear();
        roundMsg = "";
        if (IsHost()) { foreach (Ent e in ents) if (e.kind == 2 || (dumping && e.kind == 0)) BotBuy(e); }
        if (me != null) { buyOpen = me.alive && !dumping; }
        Announce("RONDA " + round, Rgb(255, 255, 255));
    }

    static void Respawn(Ent e, int slot)
    {
        List<int> sp = e.team == 0 ? spawnT : spawnCT;
        int t = sp[(slot * 7 + round * 3) % sp.Count];
        // buscamos una baldosa libre
        for (int k = 0; k < sp.Count; k++)
        {
            int c = sp[(slot * 7 + round * 3 + k * 5) % sp.Count];
            bool busy = false;
            foreach (Ent o in ents) if (o != e && o.alive && (int)o.x == c % MW && (int)o.y == c / MW) busy = true;
            if (!busy) { t = c; break; }
        }
        bool wasAlive = e.alive && round > 1;
        e.x = t % MW + 0.5; e.y = t / MW + 0.5; e.a = e.team == 0 ? -Math.PI / 2 : Math.PI / 2; e.pitch = 0;
        e.vx = e.vy = 0; e.hp = 100; e.alive = true; e.crouch = false; e.plantP = e.defuseP = 0; e.reload = 0; e.cool = 0;
        if (!wasAlive) { e.prim = -1; e.armor = 0; e.nades = 0; }
        GiveDefault(e); Refill(e);
        e.cur = e.prim >= 0 ? e.prim : e.sec;
        e.path.Clear(); e.goal = -1; e.target = null; e.holdT = 0;
        e.lookA = e.a;
    }

    static int AliveCount(int team) { int n = 0; foreach (Ent e in ents) if (e.team == team && e.alive) n++; return n; }

    static void EndRound(int winner, string why)
    {
        if (phase != PH_LIVE) return;
        phase = PH_END; phaseT = ENDTIME; lastWinner = winner;
        if (winner == 0) scoreT++; else scoreCT++;
        roundMsg = why;
        OnRoundEnd(winner, why);
        if (scoreT >= roundsToWin || scoreCT >= roundsToWin) { phase = PH_OVER; phaseT = 10; }
        NetRoundNow();
    }

    // dinero al acabar la ronda (cada ordenador se paga a si mismo; el anfitrion paga a los bots)
    static int paidRound = -1;
    static void OnRoundEnd(int winner, string why)
    {
        if (paidRound == round) return;
        paidRound = round;
        foreach (Ent e in ents)
        {
            if (e.kind == 1) continue;
            if (e.kind == 2 && !IsHost()) continue;
            e.money = Math.Min(16000, e.money + (e.team == winner ? 3250 : 1400));
        }
        Announce((winner == 0 ? "GANAN LOS TERRORISTAS" : "GANAN LOS ANTITERRORISTAS"), TEAMC[winner]);
        AddFeed(why, TEAMC[winner]);
    }

    static string annText = ""; static int annCol; static double annT = -9;
    static void Announce(string s, int c) { annText = s; annCol = c; annT = gt; }

    // logica de la ronda (solo el anfitrion decide)
    static void HostRoundLogic(double dt)
    {
        if (phase == PH_FREEZE) { if (phaseT <= 0) { phase = PH_LIVE; phaseT = ROUNDTIME; NetRoundNow(); } return; }
        if (phase == PH_LIVE)
        {
            HostTeamPlan();
            if (bombState == 2)
            {
                bombT -= dt;
                if (bombT <= 0) { bombState = 3; Explode(bombX, bombY, 7.5, 260, null, W_C4); EndRound(0, "LA BOMBA HA EXPLOTADO"); return; }
            }
            if (AliveCount(1) == 0) { EndRound(0, "ANTITERRORISTAS ELIMINADOS"); return; }
            if (AliveCount(0) == 0 && bombState != 2) { EndRound(1, "TERRORISTAS ELIMINADOS"); return; }
            if (phaseT <= 0 && bombState != 2) { EndRound(1, "SE ACABO EL TIEMPO"); return; }
            // si muere quien lleva la bomba, cae al suelo
            if (bombState == 0)
            {
                Ent c = FindEnt(bombCarrier);
                if (c == null || !c.alive)
                {
                    if (c != null) { bombX = c.x; bombY = c.y; } else { bombX = spawnT[0] % MW + 0.5; bombY = spawnT[0] / MW + 0.5; }
                    bombState = 1; bombCarrier = ""; NetRoundNow();
                }
            }
            if (bombState == 1)
                foreach (Ent e in ents)
                    if (e.alive && e.team == 0 && (e.kind != 1) && Math.Abs(e.x - bombX) < 0.6 && Math.Abs(e.y - bombY) < 0.6) { HostPick(e.key); break; }
            return;
        }
        if (phase == PH_END && phaseT <= 0) { StartRound(round + 1); NetRoundNow(); }
        if (phase == PH_OVER && phaseT <= 0) { inGame = false; state = ST_LOBBY; stT = 0; NetRoundNow(); }
    }
    static void HostPick(string key) { if (bombState != 1) return; bombCarrier = key; bombState = 0; foreach (Ent e in ents) e.hasBomb = e.key == key; NetRoundNow(); }
    static void HostPlant(string key, double x, double y)
    {
        if (phase != PH_LIVE || bombState == 2) return;
        bombState = 2; bombX = x; bombY = y; bombT = BOMBTIME; bombCarrier = "";
        foreach (Ent e in ents) e.hasBomb = false;
        Ent p = FindEnt(key);
        AddFeed((p != null ? p.name : "?") + " HA PLANTADO LA BOMBA", TEAMC[0]);
        Announce("BOMBA PLANTADA", Rgb(255, 80, 60));
        NetRoundNow();
    }
    static void HostDefuse(string key)
    {
        if (phase != PH_LIVE || bombState != 2) return;
        bombState = 4;
        Ent p = FindEnt(key);
        EndRound(1, (p != null ? p.name : "?") + " HA DESACTIVADO LA BOMBA");
    }

    // ================================================================ disparos y danos
    // rayo contra paredes: distancia en el plano
    static double WallDist(double x, double y, double dx, double dy, double maxD)
    {
        int mx = (int)Math.Floor(x), my = (int)Math.Floor(y);
        double ddx = Math.Abs(1 / (dx == 0 ? 1e-9 : dx)), ddy = Math.Abs(1 / (dy == 0 ? 1e-9 : dy));
        int sx, sy; double sdx, sdy;
        if (dx < 0) { sx = -1; sdx = (x - mx) * ddx; } else { sx = 1; sdx = (mx + 1 - x) * ddx; }
        if (dy < 0) { sy = -1; sdy = (y - my) * ddy; } else { sy = 1; sdy = (my + 1 - y) * ddy; }
        double d = 0;
        while (d < maxD)
        {
            if (sdx < sdy) { d = sdx; sdx += ddx; mx += sx; } else { d = sdy; sdy += ddy; my += sy; }
            if (Solid(mx, my)) return d;
        }
        return maxD;
    }
    static bool LOS(double x0, double y0, double x1, double y1)
    {
        double dx = x1 - x0, dy = y1 - y0, l = Math.Sqrt(dx * dx + dy * dy);
        if (l < 1e-6) return true;
        return WallDist(x0, y0, dx / l, dy / l, l) >= l - 0.01;
    }

    static double Spread(Ent e)
    {
        int w = e.cur;
        double sp = WSPREAD[w] + WMOVE[w] * Cl(Math.Sqrt(e.vx * e.vx + e.vy * e.vy) / 2.5) + e.recoil * 0.6;
        if (e.crouch) sp *= 0.6;
        if (w == W_AWP && !(e == me && scoped)) sp += 0.08;
        return sp;
    }

    static double Gauss() { double u = 1 - rnd.NextDouble(), v = rnd.NextDouble(); return Math.Sqrt(-2 * Math.Log(u)) * Math.Cos(2 * Math.PI * v); }

    static void Fire(Ent e)
    {
        int w = e.cur;
        if (w == W_HE) { ThrowNade(e); return; }
        if (w == W_C4) return;
        if (w == W_KNIFE) { Stab(e); return; }
        if (e.clip[w] <= 0) { if (e.res[w] > 0) StartReload(e); else if (e == me) Announce("SIN BALAS", Rgb(255, 120, 80)); return; }
        e.clip[w]--; e.cool = WRATE[w]; e.shotT = gt; e.shots++;
        double sp = Spread(e);
        double a = e.a + Gauss() * sp, pt = e.pitch + Gauss() * sp * 0.7;
        e.recoil = Math.Min(0.08, e.recoil + WKICK[w]);
        if (e == me) { kickP += WKICK[w] * 0.7; kickY += (rnd.NextDouble() - 0.5) * WKICK[w] * 0.5; muzzle = 0.06; }
        Shoot(e, a, pt, WDMG[w], w, true);
    }

    // dispara un rayo: paredes, suelo y jugadores (cilindros con cabeza)
    static void Shoot(Ent e, double a, double pt, int dmg, int w, bool fx)
    {
        double dx = Math.Cos(a), dy = Math.Sin(a), slope = Math.Tan(pt), ez = Eye(e);
        double wd = WallDist(e.x, e.y, dx, dy, 40);
        double fd = slope < -1e-4 ? ez / -slope : 1e9;
        double cd = slope > 1e-4 ? (1.0 - ez) / slope * 3 : 1e9;   // el cielo (las balas se pierden)
        Ent hit = null; double hd = Math.Min(wd, Math.Min(fd, cd)); bool head = false;
        foreach (Ent o in ents)
        {
            if (o == e || !o.alive || o.team == e.team) continue;
            double ox = o.x - e.x, oy = o.y - e.y;
            double t = ox * dx + oy * dy; if (t < 0) continue;
            double px = ox - dx * t, py = oy - dy * t, d2 = px * px + py * py;
            if (d2 > PRAD * PRAD) continue;
            double tin = t - Math.Sqrt(PRAD * PRAD - d2);
            if (tin > hd) continue;
            double z = ez + slope * tin, top = o.crouch ? PHGT * 0.72 : PHGT;
            if (z < 0 || z > top) continue;
            hit = o; hd = tin; head = z > top - 0.17;
        }
        double hx = e.x + dx * hd, hy = e.y + dy * hd, hz = ez + slope * hd;
        if (fx)
        {
            double gx = e.x + dx * 0.3 + Math.Cos(a + 1.2) * 0.12, gy = e.y + dy * 0.3 + Math.Sin(a + 1.2) * 0.12;
            AddTracer(gx, gy, ez - 0.08, hx, hy, hz, Rgb(255, 230, 150));
        }
        if (hit != null)
        {
            for (int k = 0; k < 7; k++) Spawn(1, hx, hy, hz, (rnd.NextDouble() - 0.5) * 1.5 + dx * 0.8, (rnd.NextDouble() - 0.5) * 1.5 + dy * 0.8, rnd.NextDouble() * 1.5, 0.5, Rgb(170 + rnd.Next(60), 10, 10), 0.025);
            double fall = w == W_AWP ? 1 : Math.Pow(0.985, hd);
            int dm = (int)(dmg * fall * (head ? 4 : 1));
            if (e == me && dmg > 0) { hitMark = gt; hitHead = head; }
            if (dmg > 0) Damage(hit, dm, e, w, head);
        }
        else if (hd < 39)
        {
            int dust = hd == fd ? Rgb(200, 170, 120) : Rgb(220, 200, 160);
            for (int k = 0; k < 5; k++) Spawn(0, hx - dx * 0.03, hy - dy * 0.03, hz, (rnd.NextDouble() - 0.5) * 1.2 - dx * 0.8, (rnd.NextDouble() - 0.5) * 1.2 - dy * 0.8, rnd.NextDouble() * 1.4, 0.35, k < 2 ? Rgb(255, 220, 120) : dust, 0.02);
            Spawn(2, hx - dx * 0.05, hy - dy * 0.05, hz, -dx * 0.2, -dy * 0.2, 0.1, 0.8, dust, 0.03);
        }
    }

    static void Stab(Ent e)
    {
        e.cool = WRATE[W_KNIFE]; e.shotT = gt;
        foreach (Ent o in ents)
        {
            if (o == e || !o.alive || o.team == e.team) continue;
            double dx = o.x - e.x, dy = o.y - e.y, d = Math.Sqrt(dx * dx + dy * dy);
            if (d > 1.0) continue;
            if (Math.Abs(AngDiff(Math.Atan2(dy, dx), e.a)) > 0.6) continue;
            // por la espalda hace mucho mas dano
            bool back = Math.Abs(AngDiff(o.a, e.a)) < 0.9;
            if (e == me) { hitMark = gt; hitHead = back; }
            for (int k = 0; k < 8; k++) Spawn(1, o.x, o.y, 0.6, (rnd.NextDouble() - 0.5) * 1.5, (rnd.NextDouble() - 0.5) * 1.5, rnd.NextDouble(), 0.5, Rgb(190, 10, 10), 0.025);
            Damage(o, back ? 180 : WDMG[W_KNIFE], e, W_KNIFE, back);
            return;
        }
    }

    static void StartReload(Ent e)
    {
        int w = e.cur;
        if (w < W_GLOCK || w > W_AWP || e.reload > 0 || e.clip[w] >= WMAG[w] || e.res[w] <= 0) return;
        e.reload = WRELOAD[w];
    }
    static void UpdWeapon(Ent e, double dt)
    {
        e.cool -= dt; e.recoil = Math.Max(0, e.recoil - dt * 0.12);
        if (e.reload > 0)
        {
            e.reload -= dt;
            if (e.reload <= 0) { int w = e.cur; int need = WMAG[w] - e.clip[w], take = Math.Min(need, e.res[w]); e.clip[w] += take; e.res[w] -= take; }
        }
    }
    static void Switch(Ent e, int w)
    {
        if (w == e.cur) return;
        if (w < 0) return;
        if (w == W_HE && e.nades <= 0) return;
        if (w == W_C4 && !e.hasBomb) return;
        e.lastW = e.cur; e.cur = w; e.reload = 0; e.cool = Math.Max(e.cool, 0.35);
        if (e == me) { scoped = false; drawT = gt; }
    }

    // dano: si el objetivo es de este ordenador se aplica aqui; si no, se avisa por la red
    static void Damage(Ent t, int dmg, Ent from, int w, bool head)
    {
        if (t.kind == 0 || (t.kind == 2 && IsHost()) || !Online()) ApplyDamage(t, dmg, from != null ? from.key : "", w, head);
        else SendHit(t, dmg, from, w, head);
    }
    static void ApplyDamage(Ent t, int dmg, string fromKey, int w, bool head)
    {
        if (!t.alive) return;
        if (t.armor > 0 && w != W_KNIFE)
        {
            int ab = (int)(dmg * (w == W_AWP ? 0.15 : 0.45));
            ab = Math.Min(ab, t.armor); t.armor -= ab; dmg -= ab;
        }
        t.hp -= Math.Max(1, dmg); t.hurtT = gt;
        if (t == me)
        {
            hurtFlash = 0.35; Ent f = FindEnt(fromKey);
            if (f != null) { hurtDirT = gt; hurtDir = Math.Atan2(f.y - me.y, f.x - me.x); }
        }
        if (t.kind == 2) { Ent f = FindEnt(fromKey); if (f != null && t.target == null) { t.lastSeenX = f.x; t.lastSeenY = f.y; t.lastSeenT = gt; t.lookA = Math.Atan2(f.y - t.y, f.x - t.x); } }
        if (t.hp <= 0) { t.hp = 0; Kill(t, fromKey, w, head); NetKill(t.key, fromKey, w, head); }
    }
    static void Kill(Ent t, string fromKey, int w, bool head)
    {
        if (!t.alive) return;
        t.alive = false; t.hp = 0; t.deaths++; t.plantP = t.defuseP = 0;
        if (t == me) { scoped = false; buyOpen = false; killerKey = fromKey; }
        Ent f = FindEnt(fromKey);
        if (f != null && f != t)
        {
            f.kills++;
            bool pay = f.kind == 0 || (f.kind == 2 && IsHost());
            if (pay) f.money = Math.Min(16000, f.money + WREWARD[w]);
            if (f == me) { Announce(head ? "HEADSHOT!" : "ELIMINADO: " + t.name, head ? Rgb(255, 80, 60) : Rgb(255, 255, 255)); }
        }
        AddFeed((f != null ? f.name : "?") + "  [" + WN[w] + (head ? " +HS" : "") + "]  " + t.name, f != null ? TEAMC[f.team] : Rgb(200, 200, 200));
        if (t.hasBomb && IsHost()) { bombX = t.x; bombY = t.y; bombState = 1; bombCarrier = ""; t.hasBomb = false; NetRoundNow(); }
        for (int k = 0; k < 14; k++) Spawn(1, t.x, t.y, 0.5, (rnd.NextDouble() - 0.5) * 2, (rnd.NextDouble() - 0.5) * 2, rnd.NextDouble() * 1.5, 0.8, Rgb(160 + rnd.Next(60), 10, 10), 0.03);
    }

    // ================================================================ granadas
    class Nade { public double x, y, z, vx, vy, vz, t; public string owner; public bool real; }
    static List<Nade> nades = new List<Nade>();
    static void ThrowNade(Ent e)
    {
        if (e.nades <= 0) return;
        e.nades--; e.cool = 1.0; e.shotT = gt;
        double sp = 7.5, ca = Math.Cos(e.pitch);
        Nade n = new Nade(); n.x = e.x + Math.Cos(e.a) * 0.3; n.y = e.y + Math.Sin(e.a) * 0.3; n.z = Eye(e);
        n.vx = Math.Cos(e.a) * ca * sp + e.vx; n.vy = Math.Sin(e.a) * ca * sp + e.vy; n.vz = Math.Sin(e.pitch) * sp + 2.2;
        n.t = 1.7; n.owner = e.key; n.real = true;
        nades.Add(n);
        NetNade(n);
        if (e.nades <= 0) Switch(e, e.prim >= 0 ? e.prim : e.sec);
    }
    static void UpdNades(double dt)
    {
        for (int i = nades.Count - 1; i >= 0; i--)
        {
            Nade n = nades[i];
            n.t -= dt;
            n.vz -= 9.8 * dt;
            double nx = n.x + n.vx * dt, ny = n.y + n.vy * dt;
            if (SolidAt(nx, n.y)) n.vx = -n.vx * 0.5; else n.x = nx;
            if (SolidAt(n.x, ny)) n.vy = -n.vy * 0.5; else n.y = ny;
            n.z += n.vz * dt;
            if (n.z < 0.05) { n.z = 0.05; n.vz = -n.vz * 0.4; n.vx *= 0.7; n.vy *= 0.7; }
            if (n.z > 1.4) { n.z = 1.4; n.vz = -Math.Abs(n.vz) * 0.3; }
            if (n.t <= 0)
            {
                nades.RemoveAt(i);
                Ent o = FindEnt(n.owner);
                Explode(n.x, n.y, 3.6, 100, n.real ? o : null, W_HE);
            }
        }
    }
    // explosion: efectos para todos; el dano lo calcula quien lanzo (o el anfitrion para la bomba)
    static void Explode(double x, double y, double radius, int maxDmg, Ent owner, int w)
    {
        int nfx = w == W_C4 ? 90 : 45;
        for (int k = 0; k < nfx; k++)
        {
            double a = rnd.NextDouble() * Math.PI * 2, s = rnd.NextDouble() * (w == W_C4 ? 5 : 3);
            Spawn(3, x, y, 0.2 + rnd.NextDouble() * 0.4, Math.Cos(a) * s, Math.Sin(a) * s, rnd.NextDouble() * 2, 0.5 + rnd.NextDouble() * 0.4, 0, 0.06 + rnd.NextDouble() * 0.08);
            Spawn(2, x, y, 0.2, Math.Cos(a) * s * 0.4, Math.Sin(a) * s * 0.4, rnd.NextDouble() * 0.6, 2.5, Rgb(90, 85, 80), 0.08);
        }
        double md = Math.Sqrt((me != null ? (me.x - x) * (me.x - x) + (me.y - y) * (me.y - y) : 99));
        shake = Math.Max(shake, Cl(1 - md / (radius * 2.5)) * (w == W_C4 ? 1.5 : 0.8));
        if (w == W_C4 && md < 30) whiteFlash = Math.Max(whiteFlash, Cl(1.2 - md / 25));
        bool doDmg = (w == W_C4 && IsHost()) || (owner != null && (owner.kind == 0 || (owner.kind == 2 && IsHost())));
        if (!doDmg) return;
        foreach (Ent e in ents)
        {
            if (!e.alive) continue;
            double d = Math.Sqrt((e.x - x) * (e.x - x) + (e.y - y) * (e.y - y));
            if (d > radius || !LOS(x, y, e.x, e.y)) continue;
            if (owner != null && e.team == owner.team && e != owner) continue;
            Damage(e, (int)(maxDmg * (1 - d / radius)), owner, w, false);
        }
    }

    // ================================================================ movimiento con colisiones
    static void MoveEnt(Ent e, double wx, double wy, bool walkKey, double dt)
    {
        double maxS = 3.1 * WSPEED[e.cur] * (e.crouch ? 0.45 : walkKey ? 0.55 : 1);
        if (e == me && scoped) maxS *= 0.55;
        double l = Math.Sqrt(wx * wx + wy * wy);
        double tx = l > 0 ? wx / l * maxS : 0, ty = l > 0 ? wy / l * maxS : 0;
        double acc = 1 - Math.Exp(-dt * (l > 0 ? 12 : 9));
        e.vx += (tx - e.vx) * acc; e.vy += (ty - e.vy) * acc;
        double nx = e.x + e.vx * dt, ny = e.y + e.vy * dt;
        if (!Blocked(nx, e.y)) e.x = nx; else e.vx = 0;
        if (!Blocked(e.x, ny)) e.y = ny; else e.vy = 0;
        double sp = Math.Sqrt(e.vx * e.vx + e.vy * e.vy);
        e.walk += sp * dt * 2.2;
        // los jugadores se empujan un poco entre ellos
        foreach (Ent o in ents)
        {
            if (o == e || !o.alive) continue;
            double dx = e.x - o.x, dy = e.y - o.y, d = Math.Sqrt(dx * dx + dy * dy);
            if (d < 0.42 && d > 1e-4)
            {
                double push = (0.42 - d) * 0.5;
                double px = e.x + dx / d * push, py = e.y + dy / d * push;
                if (!Blocked(px, e.y)) e.x = px; if (!Blocked(e.x, py)) e.y = py;
            }
        }
    }
    static bool Blocked(double x, double y)
    {
        double r = PRAD * 0.9;
        return SolidAt(x - r, y - r) || SolidAt(x + r, y - r) || SolidAt(x - r, y + r) || SolidAt(x + r, y + r);
    }

    // ================================================================ tienda
    static bool buyOpen;
    static bool CanBuy() { return me != null && me.alive && phase != PH_END && phase != PH_OVER && (phase == PH_FREEZE || ROUNDTIME - phaseT < 20) && InSpawn(me); }
    static bool InSpawn(Ent e) { char c = Tile((int)e.x, (int)e.y); return e.team == 0 ? c == 't' : c == 'c'; }
    static readonly int[] SHOP = { W_DEAGLE, W_MP5, -2, -3, W_AWP, 10, W_HE };   // -2 fusil de tu bando, -3 la otra pistola
    static int ShopItem(int k, int team)
    {
        int it = SHOP[k];
        if (it == -2) return team == 0 ? W_AK : W_M4;
        if (it == -3) return team == 0 ? W_USP : W_GLOCK;
        return it;
    }
    static int ItemPrice(int it) { return it == 10 ? 1000 : WPRICE[it]; }
    static string ItemName(int it) { return it == 10 ? "CHALECO + CASCO" : WN[it]; }
    static bool Buy(Ent e, int it)
    {
        int price = ItemPrice(it);
        if (e.money < price) return false;
        if (it == 10) { if (e.armor >= 100) return false; e.armor = 100; }
        else if (it == W_HE) { if (e.nades >= 1) return false; e.nades = 1; }
        else if (SlotOf(it) == 0) { if (e.prim == it) return false; e.prim = it; e.clip[it] = WMAG[it]; e.res[it] = WRES[it]; Switch(e, it); }
        else { if (e.sec == it) return false; e.sec = it; e.clip[it] = WMAG[it]; e.res[it] = WRES[it]; Switch(e, it); }
        e.money -= price;
        return true;
    }

    // ================================================================ bots (los mueve el anfitrion)
    static int planSite, tStage; static bool tRush;
    // puntos de reunion antes de entrar a cada zona: A por long, A por la pasarela, B por los tuneles, B por la ventana
    static readonly int[,] STAGES = { { 28, 13 }, { 20, 10 }, { 4, 12 }, { 8, 13 } };
    static void HostTeamPlan()
    {
        if (phase != PH_LIVE || tRush) return;
        int sx = STAGES[tStage, 0], sy = STAGES[tStage, 1], near = 0, alive = 0;
        foreach (Ent e in ents) if (e.team == 0 && e.alive) { alive++; if (Math.Abs(e.x - sx) < 4 && Math.Abs(e.y - sy) < 4) near++; }
        if (near >= Math.Min(3, alive) || ROUNDTIME - phaseT > 30) { tRush = true; foreach (Ent e in ents) if (e.kind == 2 && e.team == 0) { e.path.Clear(); e.think = 0; e.holdT = 0; } }
    }
    static int[] bfsPrev; static int[] bfsQ;
    static void FindPath(Ent b, int goal)
    {
        int n = MW * MH; if (bfsPrev == null) { bfsPrev = new int[n]; bfsQ = new int[n]; }
        for (int i = 0; i < n; i++) bfsPrev[i] = -2;
        int s = (int)b.y * MW + (int)b.x;
        int qh = 0, qt = 0; bfsQ[qt++] = s; bfsPrev[s] = -1;
        while (qh < qt)
        {
            int c = bfsQ[qh++]; if (c == goal) break;
            int cx = c % MW, cy = c / MW;
            for (int k = 0; k < 4; k++)
            {
                int nx = cx + (k == 0 ? 1 : k == 1 ? -1 : 0), ny = cy + (k == 2 ? 1 : k == 3 ? -1 : 0);
                if (Solid(nx, ny)) continue;
                int ni = ny * MW + nx; if (bfsPrev[ni] != -2) continue;
                bfsPrev[ni] = c; bfsQ[qt++] = ni;
            }
        }
        b.path.Clear(); b.goal = goal;
        if (bfsPrev[goal] == -2) return;
        for (int c = goal; c != -1 && c != s; c = bfsPrev[c]) b.path.Add(c);
        b.path.Reverse();
    }
    static int RandTile(List<int> l) { return l[rnd.Next(l.Count)]; }
    static int TileAt(int x, int y) { return y * MW + x; }

    static void BotBuy(Ent b)
    {
        int rifle = b.team == 0 ? W_AK : W_M4;
        if (b.prim < 0)
        {
            if (b.money >= WPRICE[rifle] + 300 || (b.money >= WPRICE[rifle] && rnd.NextDouble() < 0.6)) Buy(b, rnd.NextDouble() < 0.12 && b.money >= WPRICE[W_AWP] ? W_AWP : rifle);
            else if (b.money >= WPRICE[W_MP5] + 600 && rnd.NextDouble() < 0.5) Buy(b, W_MP5);
            else if (b.money >= 900 && rnd.NextDouble() < 0.4) Buy(b, W_DEAGLE);
        }
        if (b.money >= 1000 && b.armor < 100) Buy(b, 10);
        if (b.money >= 300 && rnd.NextDouble() < 0.5) Buy(b, W_HE);
        b.cur = b.prim >= 0 ? b.prim : b.sec;
    }

    static void BotThink(Ent b)
    {
        // elige a donde ir
        int goal;
        if (b.team == 0)
        {
            if (bombState == 2) goal = TileAt((int)bombX + rnd.Next(-3, 4), (int)bombY + rnd.Next(-3, 4));
            else if (bombState == 1) goal = TileAt((int)bombX, (int)bombY);
            else
            {
                List<int> site = planSite == 0 ? siteA : siteB;
                if (!tRush) goal = TileAt(STAGES[tStage, 0] + rnd.Next(-1, 2), STAGES[tStage, 1] + rnd.Next(-1, 2));
                else goal = RandTile(site);
                if (b.hasBomb && tRush) goal = site[site.Count / 2 + (b.role % 3)];
            }
        }
        else
        {
            if (bombState == 2) goal = TileAt((int)bombX, (int)bombY);
            else { int r = b.role % 5; goal = r < 2 ? RandTile(siteA) : r < 4 ? RandTile(siteB) : TileAt(16 + rnd.Next(2), 9 + rnd.Next(4)); }
        }
        if (Solid(goal % MW, goal / MW)) goal = RandTile(floorTiles);
        FindPath(b, goal);
    }

    static Ent BotSee(Ent b)
    {
        Ent best = null; double bd = 1e9;
        foreach (Ent o in ents)
        {
            if (!o.alive || o.team == b.team) continue;
            double dx = o.x - b.x, dy = o.y - b.y, d = Math.Sqrt(dx * dx + dy * dy);
            if (d > 22) continue;
            double ad = Math.Abs(AngDiff(Math.Atan2(dy, dx), b.a));
            if (ad > 1.25 && d > 3.5) continue;
            if (!LOS(b.x, b.y, o.x, o.y)) continue;
            if (d < bd) { bd = d; best = o; }
        }
        return best;
    }

    static void UpdateBot(Ent b, double dt)
    {
        if (!b.alive) return;
        UpdWeapon(b, dt);
        if (phase == PH_FREEZE) { b.vx = b.vy = 0; return; }
        if (phase != PH_LIVE) { MoveEnt(b, 0, 0, false, dt); return; }
        b.think -= dt;
        Ent seen = BotSee(b);
        if (seen != null)
        {
            if (b.target != seen) { b.target = seen; b.react = 0.28 + rnd.NextDouble() * 0.35; }
            b.lastSeenX = seen.x; b.lastSeenY = seen.y; b.lastSeenT = gt;
        }
        else b.target = null;
        double wx = 0, wy = 0; bool walkK = false;
        if (b.target != null)
        {
            Ent t = b.target;
            double dx = t.x - b.x, dy = t.y - b.y, d = Math.Sqrt(dx * dx + dy * dy);
            double want = Math.Atan2(dy, dx) + Math.Sin(gt * 3.1 + b.key.Length) * b.aimErr * Math.Min(1, d / 8);
            double ad = AngDiff(want, b.a);
            b.a += Math.Max(-dt * 7, Math.Min(dt * 7, ad));
            double tz = (t.crouch ? 0.5 : 0.68) + (rnd.NextDouble() < 0.25 ? 0.18 : 0);
            b.pitch = Math.Atan2(tz - Eye(b), d);
            b.react -= dt;
            if (b.cur == W_KNIFE || (b.cur == W_HE)) Switch(b, b.prim >= 0 ? b.prim : b.sec);
            if (b.clip[b.cur] <= 0) StartReload(b);
            // dispara a rafagas cortas
            b.burst -= dt;
            if (b.burst < -0.3) b.burst = 0.25 + rnd.NextDouble() * 0.35;
            if (b.react <= 0 && Math.Abs(ad) < 0.09 && b.cool <= 0 && b.reload <= 0 && (b.burst > 0 || !WAUTO[b.cur])) Fire(b);
            // se mueve a los lados para no ser un blanco facil
            b.strafe -= dt;
            if (b.strafe < -1.2) b.strafe = 1.2 * (rnd.NextDouble() < 0.5 ? 1 : -1) + (rnd.NextDouble() - 0.5);
            double side = b.strafe > 0 ? 1 : -1;
            if (d > 3 && b.cur != W_AWP) { wx = -Math.Sin(b.a) * side; wy = Math.Cos(b.a) * side; walkK = true; }
            b.crouch = b.cur == W_AWP || (d > 10 && b.key.GetHashCode() % 3 == 0);
            b.path.Clear();
        }
        else
        {
            b.crouch = false;
            if (b.reload <= 0 && b.clip[b.cur] < WMAG[b.cur] / 2) StartReload(b);
            // a por la bomba / defender / plantar
            if (b.team == 0 && b.hasBomb && IsSite((int)b.x, (int)b.y, planSite == 0 ? 'a' : 'b') && phase == PH_LIVE)
            {
                Switch(b, W_C4); b.plantP += dt; b.vx = b.vy = 0;
                if (b.plantP >= PLANTTIME) { b.plantP = 0; HostPlant(b.key, b.x, b.y); Switch(b, b.prim >= 0 ? b.prim : b.sec); }
                return;
            }
            if (b.team == 1 && bombState == 2 && Math.Abs(b.x - bombX) < 0.9 && Math.Abs(b.y - bombY) < 0.9)
            {
                b.defuseP += dt; b.vx = b.vy = 0; b.crouch = true;
                if (b.defuseP >= DEFUSETIME) { b.defuseP = 0; HostDefuse(b.key); }
                return;
            }
            b.plantP = 0; b.defuseP = 0;
            if (gt - b.lastSeenT < 4 && b.lastSeenT > 0)
            {
                int lt = TileAt((int)b.lastSeenX, (int)b.lastSeenY);
                if (b.goal != lt) FindPath(b, lt);
            }
            else if (b.think <= 0 || (b.path.Count == 0 && b.holdT <= 0))
            {
                b.think = 4 + rnd.NextDouble() * 6;
                if (b.path.Count == 0) { BotThink(b); b.holdT = 2 + rnd.NextDouble() * 4; }
            }
            if (b.path.Count > 0)
            {
                // atajo: si se ve un punto mas adelante del camino, ir directo
                while (b.path.Count > 1)
                {
                    int n1 = b.path[1];
                    if (LOS(b.x, b.y, n1 % MW + 0.5, n1 / MW + 0.5) && Clear(b.x, b.y, n1 % MW + 0.5, n1 / MW + 0.5)) b.path.RemoveAt(0); else break;
                }
                int n0 = b.path[0];
                double tx = n0 % MW + 0.5 - b.x, ty = n0 / MW + 0.5 - b.y, dd = Math.Sqrt(tx * tx + ty * ty);
                if (dd < 0.3) b.path.RemoveAt(0);
                wx = tx; wy = ty;
                double wa = Math.Atan2(ty, tx);
                b.a += Math.Max(-dt * 5, Math.Min(dt * 5, AngDiff(wa, b.a)));
                b.pitch *= 0.9;
            }
            else
            {
                b.holdT -= dt;
                // vigila mirando alrededor
                b.lookA += Math.Sin(gt * 0.7 + b.key.Length * 2) * dt * 0.8;
                b.a += AngDiff(b.lookA, b.a) * Math.Min(1, dt * 3);
            }
            if (b.prim < 0 && b.cur != b.sec) Switch(b, b.sec);
        }
        MoveEnt(b, wx, wy, walkK, dt);
    }
    // el camino es ancho para el cuerpo del bot
    static bool Clear(double x0, double y0, double x1, double y1)
    {
        double dx = x1 - x0, dy = y1 - y0, l = Math.Sqrt(dx * dx + dy * dy);
        if (l < 1e-6) return true;
        double px = -dy / l * PRAD, py = dx / l * PRAD;
        return LOS(x0 + px, y0 + py, x1 + px, y1 + py) && LOS(x0 - px, y0 - py, x1 - px, y1 - py);
    }

    // ================================================================ estados de pantalla
    const int ST_TITLE = 0, ST_NAME = 1, ST_LOBBY = 2, ST_JOIN = 3, ST_GAME = 4;
    static int state = ST_TITLE; static double stT;

    // ================================================================ nombre del jugador
    static string myName = "JUGADOR", nameBuf = "";
    static string DataDir() { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "CounterCmd"); }
    static void LoadName()
    {
        try { string n = CleanName(File.ReadAllText(Path.Combine(DataDir(), "nombre.txt"))); if (n.Length > 0) { myName = n; nameBuf = n; } } catch { }
        try { string t = File.ReadAllText(Path.Combine(DataDir(), "equipo.txt")).Trim(); myTeam = t == "1" ? 1 : 0; } catch { }
    }
    static void SaveFile(string f, string v) { if (dumping) return; try { Directory.CreateDirectory(DataDir()); File.WriteAllText(Path.Combine(DataDir(), f), v); } catch { } }
    static string CleanName(string n)
    {
        StringBuilder b = new StringBuilder();
        foreach (char ch in n.ToUpperInvariant())
            if ((char.IsLetterOrDigit(ch) || ch == ' ' || ch == '-' || ch == '_') && b.Length < 12) b.Append(ch);
        return b.ToString().Trim();
    }
    static void TextInput(bool ip)
    {
        try
        {
            while (Console.KeyAvailable)
            {
                ConsoleKeyInfo k = Console.ReadKey(true);
                if (k.Key == ConsoleKey.Enter) { if (ip) ConfirmIp(); else ConfirmName(); return; }
                if (k.Key == ConsoleKey.Escape) { state = ST_LOBBY; stT = 0; return; }
                string buf = ip ? ipBuf : nameBuf;
                if (k.Key == ConsoleKey.Backspace) { if (buf.Length > 0) buf = buf.Substring(0, buf.Length - 1); }
                else if (ip) { if ((char.IsDigit(k.KeyChar) || k.KeyChar == '.') && buf.Length < 15) buf += k.KeyChar; }
                else { char ch = char.ToUpperInvariant(k.KeyChar); if ((char.IsLetterOrDigit(ch) || ch == ' ' || ch == '-' || ch == '_') && buf.Length < 12) buf += ch; }
                if (ip) ipBuf = buf; else nameBuf = buf;
            }
        }
        catch { }
    }
    static void ConfirmName()
    {
        string n = CleanName(nameBuf);
        if (n.Length == 0) return;
        myName = n; SaveFile("nombre.txt", myName);
        state = ST_LOBBY; stT = 0; helloT = 0;
    }

    // ================================================================ red local (UDP)
    class Peer { public string name = "JUGADOR"; public char st = 'T'; public int team; public double last; }
    const int PORT = 47790;
    static UdpClient udp; static List<IPEndPoint> targets = new List<IPEndPoint>();
    static string netErr = "", myIp = ""; static bool myIpGw;
    static long myId;
    static Dictionary<long, Peer> peers = new Dictionary<long, Peer>();
    static double helloT, stateT, botsT, roundNetT, startT; static int startRepeat, roundRepeat; static string startMsg = "";
    static List<IPEndPoint> uni = new List<IPEndPoint>(); static HashSet<string> myAddrs = new HashSet<string>(); static int myPort = PORT;
    static string ipBuf = "";
    static int hitSeq; static HashSet<string> seenHits = new HashSet<string>();

    static string MyKey() { return "P" + myId; }

    static void NetStart()
    {
        myId = BitConverter.ToInt64(Guid.NewGuid().ToByteArray(), 0) & 0x7FFFFFFFFFFFL;
        if (dumping) return;
        try
        {
            udp = new UdpClient();
            udp.Client.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
            myAddrs.Add("127.0.0.1");
            udp.Client.Bind(new IPEndPoint(IPAddress.Any, myPort));
            udp.EnableBroadcast = true;
            try { udp.Client.IOControl(-1744830452, new byte[] { 0, 0, 0, 0 }, null); } catch { }
        }
        catch { udp = null; netErr = "RED NO DISPONIBLE: se jugara solo contra bots"; return; }
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
                        myAddrs.Add(ua.Address.ToString());
                        bool gw = ni.GetIPProperties().GatewayAddresses.Count > 0;
                        if (a[0] != 169 && (myIp.Length == 0 || (gw && !myIpGw))) { myIp = ua.Address.ToString(); myIpGw = gw; }
                    }
                    catch { }
                }
            }
        }
        catch { }
        string ip = "";
        try { ip = File.ReadAllText(Path.Combine(DataDir(), "ip.txt")).Trim(); } catch { }
        IPAddress pa; if (ip.Length > 0 && IPAddress.TryParse(ip, out pa)) { AddUni(new IPEndPoint(pa, PORT)); ipBuf = ip; }
    }

    static void NetSend(string msg)
    {
        if (udp == null) return;
        byte[] b = Encoding.UTF8.GetBytes(msg);
        foreach (IPEndPoint ep in targets) { try { udp.Send(b, b.Length, ep); } catch { } }
        foreach (IPEndPoint ep in uni) { try { udp.Send(b, b.Length, ep); } catch { } }
    }
    static void AddUni(IPEndPoint ep)
    {
        if (ep == null || ep.AddressFamily != AddressFamily.InterNetwork || ep.Port <= 0) return;
        if (ep.Port == myPort && myAddrs.Contains(ep.Address.ToString())) return;
        foreach (IPEndPoint u in uni) if (u.Port == ep.Port && u.Address.Equals(ep.Address)) return;
        if (uni.Count < 24) uni.Add(ep);
    }
    static string KnownList()
    {
        StringBuilder b = new StringBuilder();
        foreach (IPEndPoint u in uni) { if (b.Length > 0) b.Append(';'); b.Append(u.Address).Append(':').Append(u.Port); }
        return b.ToString();
    }
    static void ConfirmIp()
    {
        IPAddress ip;
        if (IPAddress.TryParse(ipBuf.Trim(), out ip) && ip.AddressFamily == AddressFamily.InterNetwork)
        {
            AddUni(new IPEndPoint(ip, PORT)); helloT = 0;
            SaveFile("ip.txt", ipBuf.Trim());
            Announce("CONECTANDO CON " + ipBuf.Trim() + "...", Rgb(0, 230, 255));
            state = ST_LOBBY; stT = 0;
        }
        else Announce("CODIGO NO VALIDO (ejemplo: 192.168.1.23)", Rgb(255, 80, 60));
    }
    static void NetBye() { if (udp != null) { NetSend("CCMD|BYE|" + myId); try { udp.Close(); } catch { } udp = null; } }

    static string D(double v) { return v.ToString("0.###", INV); }
    static double P(string s) { double v; double.TryParse(s, NumberStyles.Float, INV, out v); return v; }
    static int PI(string s) { int v; int.TryParse(s, NumberStyles.Integer, INV, out v); return v; }

    static char StChar() { return state == ST_GAME ? 'G' : state == ST_LOBBY || state == ST_JOIN ? 'L' : state == ST_NAME ? 'N' : 'T'; }

    static bool Online()
    {
        foreach (Ent e in ents) if (e.kind == 1 && gt - e.nT < 5) return true;
        return false;
    }
    // el anfitrion es el humano con el id mas bajo que siga conectado
    static bool IsHost()
    {
        if (!inGame) return true;
        foreach (Ent e in ents) if (e.kind == 1 && e.nid < myId && gt - e.nT < 4) return false;
        return true;
    }

    static int Flags(Ent e) { return (e.crouch ? 1 : 0) | (e.plantP > 0 ? 2 : 0) | (e.defuseP > 0 ? 4 : 0) | (e == me && scoped ? 8 : 0) | (e.hasBomb ? 16 : 0); }

    static void NetTick(double dt)
    {
        if (udp == null) return;
        try
        {
            int guard = 0;
            while (udp.Available > 0 && guard++ < 400)
            {
                IPEndPoint ep = new IPEndPoint(IPAddress.Any, 0);
                byte[] b = udp.Receive(ref ep);
                Handle(Encoding.UTF8.GetString(b), ep);
            }
        }
        catch { }
        helloT -= dt; stateT -= dt; botsT -= dt; roundNetT -= dt; startT -= dt;
        if (helloT <= 0) { helloT = state == ST_LOBBY ? 0.35 : 1.0; NetSend("CCMD|HELLO|" + myId + "|" + myName + "|" + StChar() + "|" + myTeam + "|" + KnownList()); }
        if (startRepeat > 0 && startT <= 0) { startT = 0.12; startRepeat--; NetSend(startMsg); }
        if (inGame && state == ST_GAME && Online())
        {
            if (stateT <= 0 && me != null)
            {
                stateT = 0.05;
                NetSend("CCMD|ST|" + myId + "|" + matchId + "|" + D(me.x) + "|" + D(me.y) + "|" + D(me.a) + "|" + D(me.pitch) + "|" + me.hp + "|" + me.armor + "|" + (me.alive ? 1 : 0) + "|" + me.cur + "|" + Flags(me) + "|" + me.shots + "|" + me.kills + "|" + me.deaths + "|" + me.money + "|" + round);
            }
            if (IsHost())
            {
                if (botsT <= 0)
                {
                    botsT = 0.066;
                    StringBuilder a = new StringBuilder();
                    foreach (Ent e in ents)
                    {
                        if (e.kind != 2) continue;
                        if (a.Length > 0) a.Append(';');
                        a.Append(e.key).Append(':').Append(D(e.x)).Append(':').Append(D(e.y)).Append(':').Append(D(e.a)).Append(':').Append(D(e.pitch)).Append(':')
                         .Append(e.hp).Append(':').Append(e.alive ? 1 : 0).Append(':').Append(e.cur).Append(':').Append(Flags(e)).Append(':').Append(e.shots).Append(':').Append(e.kills).Append(':').Append(e.deaths).Append(':').Append(e.money);
                    }
                    NetSend("CCMD|BOTS|" + myId + "|" + matchId + "|" + a);
                }
                if (roundNetT <= 0 || roundRepeat > 0) { roundNetT = 0.25; if (roundRepeat > 0) roundRepeat--; NetSend(RoundMsg()); }
            }
        }
        List<long> dead = new List<long>();
        foreach (KeyValuePair<long, Peer> kv in peers) if (gt - kv.Value.last > 6) dead.Add(kv.Key);
        foreach (long id in dead) peers.Remove(id);
    }

    static string RoundMsg()
    {
        return "CCMD|ROUND|" + myId + "|" + matchId + "|" + round + "|" + phase + "|" + D(phaseT) + "|" + scoreT + "|" + scoreCT + "|" + bombState + "|" + D(bombX) + "|" + D(bombY) + "|" + D(bombT) + "|" + bombCarrier + "|" + lastWinner + "|" + roundMsg + "|" + planSite;
    }
    static void NetRoundNow() { roundRepeat = 3; roundNetT = 0; }

    static void SendHit(Ent t, int dmg, Ent from, int w, bool head)
    {
        hitSeq++;
        string m = "CCMD|HIT|" + myId + "|" + matchId + "|" + t.key + "|" + dmg + "|" + (from != null ? from.key : "") + "|" + w + "|" + (head ? 1 : 0) + "|" + hitSeq;
        NetSend(m); NetSend(m);
    }
    static void NetKill(string victim, string from, int w, bool head)
    {
        if (!Online()) return;
        string m = "CCMD|KILL|" + myId + "|" + matchId + "|" + victim + "|" + from + "|" + w + "|" + (head ? 1 : 0);
        NetSend(m); NetSend(m);
    }
    static void NetNade(Nade n)
    {
        if (!Online()) return;
        NetSend("CCMD|NADE|" + myId + "|" + matchId + "|" + D(n.x) + "|" + D(n.y) + "|" + D(n.z) + "|" + D(n.vx) + "|" + D(n.vy) + "|" + D(n.vz) + "|" + n.owner);
    }
    static void NetPlant(double x, double y) { if (IsHost()) HostPlant(MyKey(), x, y); else { string m = "CCMD|PLANT|" + myId + "|" + matchId + "|" + D(x) + "|" + D(y); NetSend(m); NetSend(m); } }
    static void NetDefuse() { if (IsHost()) HostDefuse(MyKey()); else { string m = "CCMD|DEFUSE|" + myId + "|" + matchId; NetSend(m); NetSend(m); } }
    static double pickT;
    static void NetPick() { if (IsHost()) HostPick(MyKey()); else if (gt - pickT > 0.3) { pickT = gt; NetSend("CCMD|PICK|" + myId + "|" + matchId); } }

    static void Handle(string m, IPEndPoint from)
    {
        string[] p = m.Split('|');
        if (p.Length < 3 || p[0] != "CCMD") return;
        long id; if (!long.TryParse(p[2], out id) || id == myId) return;
        if (p[1] != "BYE") AddUni(new IPEndPoint(from.Address, from.Port));
        Peer pe;
        if (p[1] == "BYE") { peers.Remove(id); Ent g = FindEnt("P" + id); if (g != null) g.nT = -99; return; }
        if (!peers.TryGetValue(id, out pe)) { pe = new Peer(); peers[id] = pe; }
        pe.last = gt;
        int mid = p.Length > 3 ? PI(p[3]) : 0;
        switch (p[1])
        {
            case "HELLO":
                if (p.Length >= 6) { string n = CleanName(p[3]); if (n.Length > 0) pe.name = n; if (p[4].Length > 0) pe.st = p[4][0]; pe.team = p[5] == "1" ? 1 : 0; }
                if (p.Length >= 7)
                    foreach (string e in p[6].Split(';'))
                    {
                        int c = e.LastIndexOf(':'); IPAddress ip; int port;
                        if (c > 0 && IPAddress.TryParse(e.Substring(0, c), out ip) && int.TryParse(e.Substring(c + 1), out port)) AddUni(new IPEndPoint(ip, port));
                    }
                break;
            case "START":
                if (p.Length >= 6 && state == ST_LOBBY && mid != matchId)
                {
                    List<string> keys = new List<string>(), names = new List<string>(); List<int> teams = new List<int>();
                    foreach (string q in p[5].Split(','))
                    {
                        string[] f = q.Split(':'); if (f.Length < 3) continue;
                        keys.Add(f[0]); teams.Add(f[1] == "1" ? 1 : 0); names.Add(f[2]);
                    }
                    if (keys.Contains(MyKey())) { NewMatch(keys, names, teams, PI(p[4]), mid); foreach (Ent e in ents) if (e.kind == 1) e.nT = gt; state = ST_GAME; stT = 0; }
                }
                break;
            case "ST":
                if (p.Length >= 19 && mid == matchId && inGame)
                {
                    Ent e = FindEnt("P" + id); if (e == null) break;
                    e.nx = P(p[4]); e.ny = P(p[5]); e.na = P(p[6]); e.npitch = P(p[7]);
                    if (gt - e.nT > 1 || !e.alive) { e.x = e.nx; e.y = e.ny; }
                    e.nT = gt;
                    e.hp = PI(p[8]); e.armor = PI(p[9]);
                    bool al = p[10] == "1";
                    if (al && !e.alive && PI(p[18]) == round) { e.alive = true; }
                    if (!al) e.alive = false;
                    e.cur = PI(p[11]); int fl = PI(p[12]);
                    e.crouch = (fl & 1) != 0; e.plantP = (fl & 2) != 0 ? 1 : 0; e.defuseP = (fl & 4) != 0 ? 1 : 0;
                    int shots = PI(p[13]);
                    if (shots > e.shots && e.alive && gt - e.nT < 1) { e.shotT = gt; if (e.cur != W_KNIFE && e.cur != W_HE) Shoot(e, e.na, e.npitch, 0, e.cur, true); }
                    e.shots = shots; e.kills = PI(p[14]); e.deaths = PI(p[15]); e.money = PI(p[16]);
                }
                break;
            case "BOTS":
                if (p.Length >= 5 && mid == matchId && inGame && !IsHost())
                    foreach (string q in p[4].Split(';'))
                    {
                        string[] f = q.Split(':'); if (f.Length < 13) continue;
                        Ent e = FindEnt(f[0]); if (e == null) continue;
                        e.nx = P(f[1]); e.ny = P(f[2]); e.na = P(f[3]); e.npitch = P(f[4]);
                        if (gt - e.nT > 1) { e.x = e.nx; e.y = e.ny; }
                        e.nT = gt;
                        e.hp = PI(f[5]); bool al = f[6] == "1";
                        if (!al && e.alive) e.alive = false; else if (al) e.alive = true;
                        e.cur = PI(f[7]); int fl = PI(f[8]); e.crouch = (fl & 1) != 0; e.plantP = (fl & 2) != 0 ? 1 : 0; e.defuseP = (fl & 4) != 0 ? 1 : 0;
                        int shots = PI(f[9]);
                        if (shots > e.shots && e.alive) { e.shotT = gt; if (e.cur != W_KNIFE && e.cur != W_HE) Shoot(e, e.na, e.npitch, 0, e.cur, true); }
                        e.shots = shots; e.kills = PI(f[10]); e.deaths = PI(f[11]); e.money = PI(f[12]);
                    }
                break;
            case "HIT":
                if (p.Length >= 10 && mid == matchId && inGame)
                {
                    string hk = id + "/" + p[9];
                    if (seenHits.Contains(hk)) break;
                    seenHits.Add(hk); if (seenHits.Count > 3000) seenHits.Clear();
                    Ent t = FindEnt(p[4]); if (t == null) break;
                    if (t == me || (t.kind == 2 && IsHost())) ApplyDamage(t, PI(p[5]), p[6], PI(p[7]), p[8] == "1");
                }
                break;
            case "KILL":
                if (p.Length >= 8 && mid == matchId && inGame)
                {
                    Ent t = FindEnt(p[4]); if (t == null || t == me) break;
                    if (t.alive) Kill(t, p[5], PI(p[6]), p[7] == "1");
                }
                break;
            case "ROUND":
                if (p.Length >= 17 && mid == matchId && inGame && !IsHost())
                {
                    int r = PI(p[4]), ph = PI(p[5]);
                    if (r > round) StartRound(r);
                    if (r == round)
                    {
                        if ((ph == PH_END || ph == PH_OVER) && phase != PH_END && phase != PH_OVER) { lastWinner = PI(p[14]); roundMsg = p[15]; OnRoundEnd(lastWinner, roundMsg); }
                        phase = ph; phaseT = P(p[6]); scoreT = PI(p[7]); scoreCT = PI(p[8]);
                        int bs = PI(p[9]);
                        if (bs == 2 && bombState != 2) { Announce("BOMBA PLANTADA", Rgb(255, 80, 60)); }
                        if (bs == 3 && bombState != 3) Explode(P(p[10]), P(p[11]), 7.5, 260, null, W_C4);
                        bombState = bs; bombX = P(p[10]); bombY = P(p[11]); bombT = P(p[12]); bombCarrier = p[13];
                        foreach (Ent e in ents) e.hasBomb = e.key == bombCarrier;
                        lastWinner = PI(p[14]); roundMsg = p[15]; planSite = PI(p[16]);
                    }
                }
                break;
            case "PLANT":
                if (p.Length >= 6 && mid == matchId && inGame && IsHost()) HostPlant("P" + id, P(p[4]), P(p[5]));
                break;
            case "DEFUSE":
                if (mid == matchId && inGame && IsHost()) HostDefuse("P" + id);
                break;
            case "PICK":
                if (mid == matchId && inGame && IsHost()) { Ent e = FindEnt("P" + id); if (e != null && e.alive && e.team == 0) HostPick(e.key); }
                break;
            case "NADE":
                if (p.Length >= 11 && mid == matchId && inGame)
                {
                    Nade n = new Nade(); n.x = P(p[4]); n.y = P(p[5]); n.z = P(p[6]); n.vx = P(p[7]); n.vy = P(p[8]); n.vz = P(p[9]); n.owner = p[10]; n.t = 1.65; n.real = false;
                    nades.Add(n);
                }
                break;
        }
    }

    // interpolacion de los jugadores de otros ordenadores
    static void NetSmooth(Ent e, double dt)
    {
        if (e.nT < 0) return;
        double k = Math.Min(1, dt * 14);
        e.x += (e.nx - e.x) * k; e.y += (e.ny - e.y) * k;
        e.a += AngDiff(e.na, e.a) * k; e.pitch += (e.npitch - e.pitch) * k;
        double sp = Math.Sqrt((e.nx - e.x) * (e.nx - e.x) + (e.ny - e.y) * (e.ny - e.y));
        e.walk += Math.Min(3, sp * 30) * dt * 2.2;
        e.vx = (e.nx - e.x) * 10; e.vy = (e.ny - e.y) * 10;
    }

    static List<long> LobbyIds()
    {
        List<long> l = new List<long>(); l.Add(myId);
        foreach (KeyValuePair<long, Peer> kv in peers) if (kv.Value.st == 'L' && gt - kv.Value.last < 3) l.Add(kv.Key);
        l.Sort();
        return l;
    }
    static bool LobbyHost() { return LobbyIds()[0] == myId; }
    static string PeerName(long id) { Peer pe; return peers.TryGetValue(id, out pe) ? pe.name : "JUGADOR"; }
    static int PeerTeam(long id) { if (id == myId) return myTeam; Peer pe; return peers.TryGetValue(id, out pe) ? pe.team : 0; }

    static void HostStart()
    {
        List<long> ids = LobbyIds();
        int[] cnt = new int[2];
        List<string> keys = new List<string>(), names = new List<string>(); List<int> teams = new List<int>();
        StringBuilder l = new StringBuilder();
        foreach (long v in ids)
        {
            int t = PeerTeam(v);
            if (cnt[t] >= 5) t = 1 - t;
            if (cnt[t] >= 5) continue;
            cnt[t]++;
            string n = v == myId ? myName : PeerName(v);
            keys.Add("P" + v); names.Add(n); teams.Add(t);
            if (l.Length > 0) l.Append(',');
            l.Append("P" + v).Append(':').Append(t).Append(':').Append(n);
        }
        int seed = rnd.Next(1, 1 << 30), mid = rnd.Next(1, 1 << 30);
        startMsg = "CCMD|START|" + myId + "|" + mid + "|" + seed + "|" + l;
        startRepeat = 10; startT = 0;
        NewMatch(keys, names, teams, seed, mid);
        foreach (Ent e in ents) if (e.kind == 1) e.nT = gt;
        state = ST_GAME; stT = 0;
    }

    // ================================================================ estado del jugador y de la pantalla
    static bool scoped, showScore, paused, showHelp;
    static double kickP, kickY, muzzle, drawT, hitMark = -9, hurtFlash, hurtDir, hurtDirT = -9, whiteFlash, shake;
    static bool hitHead; static string killerKey = ""; static int specIdx;
    static double bobT;

    static void Init()
    {
        InitFonts(); IndexMap(); BuildTextures(); BuildShadows(); BuildSprites();
        LoadName();
        NetStart();
        state = ST_TITLE; stT = 0;
        if (dumping) { myName = "TESTER"; nameBuf = myName; if (Environment.GetEnvironmentVariable("CC_MENU") == null) HostStart(); }
    }

    // ================================================================ bucle
    static void Frame(double dt)
    {
        gt += dt; stT += dt;
        typing = state == ST_NAME || state == ST_JOIN;
        NetTick(dt);
        if ((Press(0x6B) || Press(0xBB)) && fontCtl) { fIdx = Math.Max(0, fIdx - 1); ApplyFont(); }
        if ((Press(0x6D) || Press(0xBD)) && fontCtl) { fIdx = Math.Min(FSIZES.Length - 1, fIdx + 1); ApplyFont(); }
        switch (state)
        {
            case ST_TITLE:
                if (Press(0x0D)) { state = myName.Length > 0 && nameBuf.Length > 0 ? ST_LOBBY : ST_NAME; stT = 0; }
                if (Press(0x1B)) { quit = true; return; }
                MenuRender(dt); return;
            case ST_NAME:
                TextInput(false); MenuRender(dt); return;
            case ST_JOIN:
                TextInput(true); MenuRender(dt); return;
            case ST_LOBBY:
                if (Press(0x25) || Press(0x31)) { myTeam = 0; SaveFile("equipo.txt", "0"); }
                if (Press(0x27) || Press(0x32)) { myTeam = 1; SaveFile("equipo.txt", "1"); }
                if (Press(0x0D) && LobbyHost() && stT > 0.3) HostStart();
                if (Press(0x55)) { state = ST_JOIN; stT = 0; }
                if (Press(0x4E)) { state = ST_NAME; stT = 0; }
                if (Press(0x1B)) { quit = true; return; }
                MenuRender(dt); return;
        }
        // ---- en partida
        if (Press(0x1B))
        {
            if (buyOpen) buyOpen = false;
            else if (paused) { inGame = false; state = ST_LOBBY; stT = 0; paused = false; return; }
            else paused = true;
        }
        if (paused && Press(0x0D)) paused = false;
        if (Press(0x4D)) { mouseOn = !mouseOn; Announce(mouseOn ? "RATON ACTIVADO" : "RATON DESACTIVADO (M)", Rgb(200, 200, 200)); }
        if (Press(0x70) || Press(0x48)) showHelp = !showHelp;
        showScore = Key(0x09);
        phaseT -= dt;
        if (IsHost()) HostRoundLogic(dt);
        else if (phase == PH_OVER && phaseT < -3) { inGame = false; state = ST_LOBBY; stT = 0; return; }
        if (!inGame) return;
        foreach (Ent e in ents)
        {
            if (e.kind == 2 && IsHost()) UpdateBot(e, dt);
            else if (e.kind == 1 || e.kind == 2) NetSmooth(e, dt);
        }
        UpdateMe(dt);
        UpdNades(dt); UpdParts(dt);
        shake = Math.Max(0, shake - dt * 2.5); hurtFlash = Math.Max(0, hurtFlash - dt); whiteFlash = Math.Max(0, whiteFlash - dt * 0.6);
        muzzle = Math.Max(0, muzzle - dt);
        kickP *= Math.Exp(-dt * 7); kickY *= Math.Exp(-dt * 7);
        GameRender(dt);
    }

    static bool WantMouse() { return state == ST_GAME && !paused && !buyOpen && !showScore; }

    // ================================================================ tu jugador
    static void UpdateMe(double dt)
    {
        if (me == null) return;
        if (dumping) { if (me.alive) UpdateBot(me, dt); return; }
        if (!me.alive)
        {
            // espectador: cambia de companero con clic o espacio
            if (Press(0x01) || Press(0x20)) specIdx++;
            return;
        }
        UpdWeapon(me, dt);
        bool frozen = phase == PH_FREEZE || phase == PH_OVER || paused;
        // mirar
        double sens = 0.0028 * (scoped ? 0.3 : 1);
        if (!paused && !buyOpen)
        {
            me.a += mdx * sens; me.pitch -= mdy * sens;
            double tr = 2.4 * (scoped ? 0.3 : 1) * dt;
            if (Key(0x25)) me.a -= tr; if (Key(0x27)) me.a += tr;
            if (Key(0x26)) me.pitch += tr * 0.6; if (Key(0x28)) me.pitch -= tr * 0.6;
            me.pitch = Math.Max(-0.62, Math.Min(0.62, me.pitch));
        }
        // moverse
        double fx = Math.Cos(me.a), fy = Math.Sin(me.a), rx = -fy, ry = fx, wx = 0, wy = 0;
        if (!frozen)
        {
            if (Key(0x57)) { wx += fx; wy += fy; }
            if (Key(0x53)) { wx -= fx; wy -= fy; }
            if (Key(0x44)) { wx += rx; wy += ry; }
            if (Key(0x41)) { wx -= rx; wy -= ry; }
        }
        me.crouch = Key(0x11) || Key(0x43);
        bool planting = false, defusing = false;
        // plantar / desactivar con E
        if (Key(0x45) && phase == PH_LIVE)
        {
            if (me.team == 0 && me.hasBomb && (IsSite((int)me.x, (int)me.y, 'a') || IsSite((int)me.x, (int)me.y, 'b')))
            {
                planting = true; if (me.cur != W_C4) Switch(me, W_C4);
                me.plantP += dt; wx = wy = 0;
                if (me.plantP >= PLANTTIME) { me.plantP = 0; me.hasBomb = false; NetPlant(me.x, me.y); Switch(me, me.prim >= 0 ? me.prim : me.sec); me.money += 300; }
            }
            else if (me.team == 1 && bombState == 2 && Math.Abs(me.x - bombX) < 1.0 && Math.Abs(me.y - bombY) < 1.0)
            {
                defusing = true; me.defuseP += dt; wx = wy = 0; me.crouch = true;
                if (me.defuseP >= DEFUSETIME) { me.defuseP = 0; NetDefuse(); }
            }
        }
        if (!planting) me.plantP = 0;
        if (!defusing) me.defuseP = 0;
        MoveEnt(me, wx, wy, Key(0x10), dt);
        // coger la bomba del suelo
        if (me.team == 0 && bombState == 1 && Math.Abs(me.x - bombX) < 0.6 && Math.Abs(me.y - bombY) < 0.6) NetPick();
        // tienda
        if (Press(0x42)) { if (CanBuy()) buyOpen = !buyOpen; else Announce(phase == PH_LIVE ? "YA NO SE PUEDE COMPRAR" : "VE A TU BASE PARA COMPRAR", Rgb(255, 160, 60)); }
        if (buyOpen && !CanBuy()) buyOpen = false;
        if (buyOpen)
        {
            for (int k = 0; k < SHOP.Length; k++)
                if (Press(0x31 + k))
                {
                    int it = ShopItem(k, me.team);
                    if (Buy(me, it)) Announce("COMPRADO: " + ItemName(it), Rgb(120, 255, 120));
                    else Announce(me.money < ItemPrice(it) ? "NO TIENES DINERO SUFICIENTE" : "YA LO TIENES", Rgb(255, 120, 80));
                }
            return;
        }
        // armas
        if (Press(0x31)) Switch(me, me.prim);
        if (Press(0x32)) Switch(me, me.sec);
        if (Press(0x33)) Switch(me, W_KNIFE);
        if (Press(0x34)) Switch(me, W_HE);
        if (Press(0x35)) Switch(me, W_C4);
        if (Press(0x51)) Switch(me, me.lastW == W_KNIFE || me.lastW == me.prim || me.lastW == me.sec ? me.lastW : me.sec);
        if (Press(0x52)) StartReload(me);
        if (Press(0x02) || Press(0x5A)) { if (me.cur == W_AWP) scoped = !scoped; }
        if (me.cur != W_AWP) scoped = false;
        if (me.reload > 0) scoped = false;
        bool trig = Key(0x01) || Key(0x20), trigP = Press(0x01) || Press(0x20);
        if (!frozen && !planting && !defusing && me.cool <= 0 && me.reload <= 0 && gt - drawT > 0.35)
        {
            if (WAUTO[me.cur] ? trig : trigP)
            {
                Fire(me);
                if (me.cur == W_AWP && scoped) { scoped = false; reScope = true; }
            }
        }
        if (reScope && me.cool <= 0.1 && me.cur == W_AWP) { scoped = true; reScope = false; }
        if (me.cur == W_C4 && !me.hasBomb) Switch(me, me.prim >= 0 ? me.prim : me.sec);
    }
    static bool reScope;

    // ================================================================ render en partida
    static Ent CamEnt()
    {
        if (me != null && me.alive) return me;
        List<Ent> al = new List<Ent>();
        foreach (Ent e in ents) if (e.alive && e.team == myTeam) al.Add(e);
        if (al.Count == 0) foreach (Ent e in ents) if (e.alive) al.Add(e);
        if (al.Count == 0) return me;
        return al[((specIdx % al.Count) + al.Count) % al.Count];
    }

    static void GameRender(double dt)
    {
        Ent ce = CamEnt();
        bool first = ce == me && me.alive;
        double sp = Math.Sqrt(ce.vx * ce.vx + ce.vy * ce.vy);
        bobT += sp * dt * 2.4;
        double bob = first ? Math.Sin(bobT * 2) * 0.012 * Cl(sp / 2) : 0;
        camX = ce.x; camY = ce.y;
        if (!first) { camX -= Math.Cos(ce.a) * 0.05; camY -= Math.Sin(ce.a) * 0.05; }
        double eye = Eye(ce);
        camH += (eye + bob - camH) * Math.Min(1, dt * 12);
        camA = ce.a + (first ? kickY : 0) + (rnd.NextDouble() - 0.5) * shake * 0.03;
        camPitch = ce.pitch + (first ? kickP : 0) + (rnd.NextDouble() - 0.5) * shake * 0.03;
        fov = first && scoped ? 0.32 : 1.25;
        Render3D();
        // sprites ordenados de lejos a cerca
        List<KeyValuePair<double, Ent>> list = new List<KeyValuePair<double, Ent>>();
        foreach (Ent e in ents) { if (e == ce) continue; double d = (e.x - camX) * (e.x - camX) + (e.y - camY) * (e.y - camY); list.Add(new KeyValuePair<double, Ent>(d, e)); }
        list.Sort(delegate(KeyValuePair<double, Ent> p, KeyValuePair<double, Ent> q) { return q.Key.CompareTo(p.Key); });
        tags.Clear();
        // bomba
        if (bombState == 1 || bombState == 2) DrawBomb();
        foreach (KeyValuePair<double, Ent> kv in list) DrawEnt(kv.Value);
        foreach (Nade n in nades) { double sx, sy, d = Project(n.x, n.y, n.z, out sx, out sy); if (d > 0 && (int)sx >= 0 && (int)sx < PW && zbuf[(int)sx] > d) { PDisc(sx, sy, Math.Max(1, 0.05 / d * focal), Rgb(50, 70, 40), 1); } }
        DrawParts();
        DrawTracers(dt);
        if (first && !(scoped)) DrawViewModel(dt);
        if (first && scoped) ScopeOverlay();
        Effects();
        HudPix();
        ToCells();
        HudText();
    }

    class Tag { public int x, y, c; public string s; }
    static List<Tag> tags = new List<Tag>();

    static void DrawEnt(Ent e)
    {
        bool front = Math.Abs(AngDiff(e.a, Math.Atan2(camY - e.y, camX - e.x))) < Math.PI / 2;
        int pose;
        if (!e.alive) pose = 4;
        else if (gt - e.shotT < 0.08) pose = 3;
        else if (Math.Sqrt(e.vx * e.vx + e.vy * e.vy) > 0.3) pose = 1 + ((int)(e.walk * 2) % 2);
        else pose = 0;
        int[] img = sprites[SprIdx(e.team, front ? 0 : 1, pose)];
        double h = e.alive ? (e.crouch ? PHGT * 0.75 : PHGT) : PHGT;
        int flash = e.alive && gt - e.hurtT < 0.12 ? 1 : 0;
        DrawBillboard(img, SPW, SPH, e.x, e.y, 0, h, h * SPW / SPH, 1, flash);
        if (!e.alive) return;
        // nombre encima de los companeros
        double sx, sy, d = Project(e.x, e.y, h + 0.12, out sx, out sy);
        if (d > 0 && d < 30 && (int)sx >= 0 && (int)sx < PW && zbuf[(int)sx] > d - 0.3)
        {
            if (e.team == myTeam) { Tag t = new Tag(); t.x = (int)sx; t.y = (int)(sy / 2); t.s = e.name; t.c = TEAMC[e.team]; tags.Add(t); }
            if (e.hasBomb && e.team == myTeam) { Tag t = new Tag(); t.x = (int)sx; t.y = (int)(sy / 2) - 1; t.s = "[C4]"; t.c = Rgb(255, 90, 60); tags.Add(t); }
        }
    }

    static void DrawBomb()
    {
        double sx, sy, sx2, sy2;
        double d = Project(bombX, bombY, 0.12, out sx, out sy);
        if (d <= 0) return;
        Project(bombX, bombY, 0, out sx2, out sy2);
        double w = 0.32 / d * focal, h = Math.Max(1, sy2 - sy);
        for (int x = (int)(sx - w / 2); x <= sx + w / 2; x++)
        {
            if (x < 0 || x >= PW || zbuf[x] < d) continue;
            for (int y = (int)sy; y <= sy2; y++)
            {
                double u = (x - (sx - w / 2)) / w, v = (y - sy) / h;
                int c = u < 0.15 || u > 0.85 ? Rgb(90, 80, 60) : Rgb(150, 130, 90);
                if (u > 0.3 && u < 0.7 && v < 0.5) c = Rgb(40, 60, 40);
                PS(x, y, c);
            }
        }
        if (bombState == 2)
        {
            double rate = bombT < 10 ? 6 : bombT < 20 ? 3 : 1.5;
            if (Frac(gt * rate) < 0.35) { PDisc(sx, sy, Math.Max(1.2, 0.05 / d * focal), Rgb(255, 30, 20), 1); PDisc(sx, sy, Math.Max(2, 0.2 / d * focal), Rgb(255, 40, 30), 0.35); }
        }
    }

    // ---------------------------------------------------------------- arma en primera persona
    static void Beam(double ax, double ay, double aw, double bx, double by, double bw, int top, int bot)
    {
        double dx = bx - ax, dy = by - ay, l = Math.Sqrt(dx * dx + dy * dy); if (l < 1) return;
        double ux = dx / l, uy = dy / l, nx = -uy, ny = ux;
        if (ny > 0) { nx = -nx; ny = -ny; }   // la normal apunta hacia arriba (la cara con luz)
        double m = Math.Max(aw, bw) / 2 + 1;
        int x0 = (int)(Math.Min(ax, bx) - m), x1 = (int)(Math.Max(ax, bx) + m), y0 = (int)(Math.Min(ay, by) - m), y1 = (int)(Math.Max(ay, by) + m);
        for (int y = Math.Max(0, y0); y <= Math.Min(PH - 1, y1); y++)
            for (int x = Math.Max(0, x0); x <= Math.Min(PW - 1, x1); x++)
            {
                double px = x + 0.5 - ax, py = y + 0.5 - ay;
                double t = (px * ux + py * uy) / l; if (t < 0 || t > 1) continue;
                double s = px * nx + py * ny, hw = Lp(aw, bw, t) / 2;
                if (Math.Abs(s) > hw) continue;
                double k = (s / hw + 1) / 2;   // 1 arriba
                int c = Lerp(bot, top, k);
                if (k > 0.82) c = Lerp(c, Rgb(255, 255, 255), 0.18);
                if (Math.Abs(s) > hw - 0.9) c = Scale(c, 0.7);
                pix[y * PW + x] = c;
            }
    }
    static void PtOn(double ax, double ay, double bx, double by, double t, double off, out double x, out double y)
    {
        double dx = bx - ax, dy = by - ay, l = Math.Sqrt(dx * dx + dy * dy), nx = -dy / l, ny = dx / l;
        if (ny > 0) { nx = -nx; ny = -ny; }
        x = ax + dx * t + nx * off; y = ay + dy * t + ny * off;
    }

    static void DrawViewModel(double dt)
    {
        int w = me.cur;
        double S = Math.Min(PH, PW * 0.62);
        double sp = Math.Sqrt(me.vx * me.vx + me.vy * me.vy);
        double bx = Math.Sin(bobT) * S * 0.02 * Cl(sp / 2), by = Math.Abs(Math.Cos(bobT)) * S * 0.02 * Cl(sp / 2);
        double rec = (gt - me.shotT < 0.12 ? (1 - (gt - me.shotT) / 0.12) : 0) * S * 0.05;
        double low = me.reload > 0 ? Math.Sin(Math.Min(1, (WRELOAD[w] - me.reload) / WRELOAD[w]) * Math.PI) * S * 0.35 : 0;
        double rise = Math.Max(0, 1 - (gt - drawT) / 0.3) * S * 0.4;
        bool pist = w <= W_DEAGLE;
        double ax = PW / 2.0 + S * (pist ? 0.4 : 0.56) + bx + rec * 0.6, ay = PH - S * (pist ? 0.04 : -0.02) + by + rec * 0.3 + low + rise;
        double L = w == W_AWP ? 1.08 : w == W_AK || w == W_M4 ? 1.0 : w == W_MP5 ? 0.85 : w == W_DEAGLE ? 0.75 : 0.7;
        double tx = PW / 2.0 + S * (pist ? 0.1 : 0.15) + bx, ty = PH / 2.0 + S * (pist ? 0.26 : 0.2) + by + low + rise;
        double ex = Lp(ax, tx, L), ey = Lp(ay, ty, L);
        int sleeve = me.team == 0 ? Rgb(150, 122, 74) : Rgb(52, 74, 112), glove = me.team == 0 ? Rgb(60, 52, 44) : Rgb(34, 36, 40), skin = Rgb(206, 156, 116);
        double mx, my;
        if (w == W_KNIFE)
        {
            double kx = PW / 2.0 + S * 0.48 + bx, ky = PH + S * 0.02 + by + rise;
            double swing = gt - me.shotT < 0.25 ? Math.Sin((gt - me.shotT) / 0.25 * Math.PI) : 0;
            double tipX = kx - S * (0.28 + swing * 0.25), tipY = ky - S * (0.42 + swing * 0.1);
            Beam(kx + S * 0.25, PH + S * 0.3, S * 0.2, kx, ky, S * 0.12, Scale(sleeve, 1.1), Scale(sleeve, 0.7));
            Beam(kx, ky, S * 0.06, Lp(kx, tipX, 0.3), Lp(ky, tipY, 0.3), S * 0.05, Rgb(40, 40, 44), Rgb(20, 20, 22));
            Beam(Lp(kx, tipX, 0.3), Lp(ky, tipY, 0.3), S * 0.06, tipX, tipY, S * 0.005, Rgb(235, 238, 245), Rgb(140, 145, 155));
            PDisc(kx, ky, S * 0.07, glove, 1);
            return;
        }
        if (w == W_HE || w == W_C4)
        {
            double hx = PW / 2.0 + S * 0.42 + bx, hy = PH - S * 0.12 + by + rise;
            Beam(hx + S * 0.3, PH + S * 0.3, S * 0.2, hx + S * 0.05, hy + S * 0.05, S * 0.12, Scale(sleeve, 1.1), Scale(sleeve, 0.7));
            if (w == W_HE)
            {
                PDisc(hx, hy - S * 0.06, S * 0.09, Rgb(60, 80, 50), 1); PDisc(hx - S * 0.03, hy - S * 0.09, S * 0.03, Rgb(140, 160, 120), 0.6);
                PRect((int)(hx - S * 0.02), (int)(hy - S * 0.17), (int)(S * 0.04) + 1, (int)(S * 0.03) + 1, Rgb(150, 150, 150));
            }
            else
            {
                double cx = PW / 2.0 + bx, cy = PH - S * 0.14 + by + rise;
                PRect((int)(cx - S * 0.18), (int)(cy - S * 0.1), (int)(S * 0.36), (int)(S * 0.2), Rgb(150, 128, 88));
                PRect((int)(cx - S * 0.1), (int)(cy - S * 0.07), (int)(S * 0.2), (int)(S * 0.06), Rgb(30, 60, 30));
                if (Frac(gt * 2) < 0.5) PRect((int)(cx - S * 0.08), (int)(cy - S * 0.06), (int)(S * 0.12), Math.Max(1, (int)(S * 0.03)), Rgb(80, 255, 80));
                for (int k = 0; k < 6; k++) PRect((int)(cx - S * 0.1 + (k % 3) * S * 0.07), (int)(cy + S * 0.01 + (k / 3) * S * 0.04), (int)(S * 0.05), (int)(S * 0.03), Rgb(60, 60, 60));
                if (me.plantP > 0) PDisc(cx + S * 0.12, cy - S * 0.05, S * 0.02, Frac(gt * 4) < 0.5 ? Rgb(255, 40, 30) : Rgb(80, 0, 0), 1);
                PDisc(cx - S * 0.2, cy + S * 0.02, S * 0.07, glove, 1);
            }
            PDisc(hx + S * 0.04, hy, S * 0.075, glove, 1);
            return;
        }
        bool pistol = w <= W_DEAGLE;
        int metal = Rgb(48, 50, 56), metalT = Rgb(96, 100, 110);
        int furn = w == W_AK ? Rgb(150, 82, 38) : metal, furnT = w == W_AK ? Rgb(200, 120, 60) : metalT;
        if (w == W_AWP) { furn = Rgb(70, 92, 60); furnT = Rgb(110, 140, 95); }
        // brazo derecho
        Beam(ax + S * 0.3, PH + S * 0.35, S * 0.24, ax - S * 0.02, ay - S * 0.06, S * 0.14, Scale(sleeve, 1.15), Scale(sleeve, 0.65));
        // cuerpo del arma
        PtOn(ax, ay, ex, ey, 0.55, 0, out mx, out my);
        Beam(ax, ay, S * (pistol ? 0.16 : 0.17), mx, my, S * (pistol ? 0.12 : 0.11), furnT, furn);
        if (!pistol)
        {
            double hx0, hy0, hx1, hy1;
            PtOn(ax, ay, ex, ey, 0.5, -S * 0.01, out hx0, out hy0); PtOn(ax, ay, ex, ey, 0.82, -S * 0.005, out hx1, out hy1);
            Beam(hx0, hy0, S * 0.085, hx1, hy1, S * 0.06, furnT, furn);
            // cargador
            double gx, gy; PtOn(ax, ay, ex, ey, 0.42, 0, out gx, out gy);
            double cx = gx + S * (w == W_AK ? 0.06 : 0.03), cy = gy + S * 0.2;
            Beam(gx, gy, S * 0.07, cx, cy, S * 0.06, w == W_AK ? Rgb(190, 110, 50) : Rgb(70, 72, 78), w == W_AK ? Rgb(120, 66, 30) : Rgb(36, 38, 42));
        }
        // canon
        double bx0, by0; PtOn(ax, ay, ex, ey, pistol ? 0.5 : 0.78, S * 0.015, out bx0, out by0);
        Beam(bx0, by0, S * (pistol ? 0.1 : 0.035), ex, ey, S * (pistol ? 0.08 : 0.026), metalT, metal);
        if (w == W_AWP)
        {
            double s0x, s0y, s1x, s1y;
            PtOn(ax, ay, ex, ey, 0.32, S * 0.085, out s0x, out s0y); PtOn(ax, ay, ex, ey, 0.66, S * 0.06, out s1x, out s1y);
            Beam(s0x, s0y, S * 0.085, s1x, s1y, S * 0.07, Rgb(70, 74, 80), Rgb(22, 24, 26));
            PDisc(s1x, s1y, S * 0.03, Rgb(120, 170, 255), 0.6);
        }
        else
        {
            double fx2, fy2; PtOn(ax, ay, ex, ey, 0.97, S * (pistol ? 0.035 : 0.03), out fx2, out fy2);
            PRect((int)fx2, (int)(fy2 - S * 0.02), Math.Max(1, (int)(S * 0.012)), Math.Max(1, (int)(S * 0.025)), Rgb(20, 20, 22));
        }
        // mano izquierda (rifles) y guante derecho
        if (!pistol)
        {
            double lx, ly; PtOn(ax, ay, ex, ey, 0.68, -S * 0.04, out lx, out ly);
            Beam(PW / 2.0 + S * 0.05, PH + S * 0.3, S * 0.2, lx, ly + S * 0.04, S * 0.11, Scale(sleeve, 1.1), Scale(sleeve, 0.6));
            PDisc(lx, ly, S * 0.06, glove, 1);
        }
        PDisc(ax - S * 0.01, ay - S * 0.07, S * 0.085, glove, 1);
        PDisc(ax - S * 0.04, ay - S * 0.11, S * 0.03, skin, 0.4);
        // fogonazo
        if (gt - me.shotT < 0.05)
        {
            double r = S * (pistol ? 0.045 : 0.06) * (0.8 + rnd.NextDouble() * 0.4);
            PDisc(ex, ey, r * 1.8, Rgb(255, 170, 40), 0.35);
            PDisc(ex, ey, r, Rgb(255, 230, 120), 0.9);
            PDisc(ex, ey, r * 0.45, Rgb(255, 255, 230), 1);
            for (int k = 0; k < 5; k++) { double a = rnd.NextDouble() * Math.PI * 2; PLine(ex, ey, ex + Math.Cos(a) * r * 2.2, ey + Math.Sin(a) * r * 2.2, Rgb(255, 210, 90), 0.6); }
        }
    }

    static void ScopeOverlay()
    {
        double cx = PW / 2.0, cy = PH / 2.0, r = Math.Min(PW, PH) * 0.47;
        for (int y = 0; y < PH; y++)
            for (int x = 0; x < PW; x++)
            {
                double d = Math.Sqrt((x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy));
                if (d > r) pix[y * PW + x] = Rgb(6, 6, 6);
                else if (d > r - 2) pix[y * PW + x] = Lerp(pix[y * PW + x], 0, 0.7);
            }
        for (int x = (int)(cx - r); x < cx + r; x++) PS(x, (int)cy, 0);
        for (int y = (int)(cy - r); y < cy + r; y++) PS((int)cx, y, 0);
    }

    static void Effects()
    {
        if (hurtFlash > 0)
            for (int y = 0; y < PH; y++)
                for (int x = 0; x < PW; x++)
                {
                    double dx = (x - PW / 2.0) / (PW / 2.0), dy = (y - PH / 2.0) / (PH / 2.0), v = Cl(dx * dx + dy * dy - 0.3);
                    if (v > 0) PB(x, y, Rgb(200, 0, 0), v * hurtFlash * 1.6);
                }
        if (whiteFlash > 0) for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Rgb(255, 250, 235), Cl(whiteFlash));
        if (me != null && !me.alive && state == ST_GAME) for (int i = 0; i < pix.Length; i++) pix[i] = Lerp(pix[i], Scale(pix[i], 0.6), 0.5);
    }

    // ---------------------------------------------------------------- HUD en pixeles
    static void HudPix()
    {
        Ent ce = CamEnt();
        int cx = PW / 2, cy = PH / 2;
        // punto de mira dinamico
        if (me.alive && !scoped && me.cur != W_HE && me.cur != W_C4)
        {
            int gap = 2 + (int)(Spread(me) * focal * 0.8), len = 3;
            int col = Rgb(80, 255, 120);
            for (int k = 0; k < len; k++) { PS(cx - gap - k, cy, col); PS(cx + gap + k, cy, col); PS(cx, cy - gap - k, col); PS(cx, cy + gap + k, col); }
            PS(cx, cy, Rgb(255, 255, 255));
        }
        // marca de impacto
        if (gt - hitMark < 0.18)
        {
            int c = hitHead ? Rgb(255, 60, 40) : Rgb(255, 255, 255);
            for (int k = 3; k < 7; k++) { PS(cx - k, cy - k, c); PS(cx + k, cy - k, c); PS(cx - k, cy + k, c); PS(cx + k, cy + k, c); }
        }
        // de donde te disparan
        if (gt - hurtDirT < 1.0 && me.alive)
        {
            double rel = AngDiff(hurtDir, me.a) - Math.PI / 2;
            double a0 = gt - hurtDirT;
            for (double t = -0.35; t <= 0.35; t += 0.02)
            {
                double aa = rel + t;
                PB((int)(cx + Math.Cos(aa) * PH * 0.3), (int)(cy + Math.Sin(aa) * PH * 0.3), Rgb(255, 30, 20), (1 - a0) * (1 - Math.Abs(t) / 0.35));
                PB((int)(cx + Math.Cos(aa) * PH * 0.31), (int)(cy + Math.Sin(aa) * PH * 0.31), Rgb(255, 30, 20), (1 - a0) * (1 - Math.Abs(t) / 0.35));
            }
        }
        Radar(ce);
        // barras inferiores
        Panel(0, H - 3, W, 3, 0.55, -1);
        // progreso de plantar / desactivar
        double prog = me.plantP > 0 ? me.plantP / PLANTTIME : me.defuseP > 0 ? me.defuseP / DEFUSETIME : 0;
        if (prog > 0)
        {
            int bw = W / 3, bx = (W - bw) / 2, by = (H / 2 + 6) * 2;
            PRectB(bx - 1, by - 1, bw + 2, 4, Rgb(0, 0, 0), 0.7);
            PRect(bx, by, (int)(bw * prog), 2, me.plantP > 0 ? Rgb(255, 120, 40) : Rgb(80, 180, 255));
        }
        if (buyOpen) Panel(W / 2 - 24, 4, 48, SHOP.Length + 6, 0.85, TEAMC[myTeam]);
        if (showScore) Panel(W / 2 - 38, 3, 76, 18, 0.88, Rgb(255, 255, 255));
        if (paused) Panel(W / 2 - 22, H / 2 - 4, 44, 8, 0.88, Rgb(255, 200, 0));
        if (showHelp) Panel(W / 2 - 30, 3, 60, 19, 0.9, Rgb(0, 200, 255));
        if (gt - annT < 2.2 && annText.Length > 0)
        {
            int bw = annText.Length * 2 * 4;
            if (bw < PW - 4 && annText.Length <= 26) { int x0 = (PW - bw) / 2; F3Pix(annText, x0 + 1, (int)(PH * 0.2) + 1, 2, Rgb(0, 0, 0)); F3Pix(annText, x0, (int)(PH * 0.2), 2, annCol); }
        }
        if (phase == PH_OVER)
        {
            bool win = lastWinner == myTeam;
            string t = win ? "VICTORIA" : "DERROTA";
            int sc = Math.Max(2, PW / 60), bw = F3W(t, sc), x0 = (PW - bw) / 2;
            F3Pix(t, x0 + sc, (int)(PH * 0.3) + sc, sc, 0); F3Pix(t, x0, (int)(PH * 0.3), sc, win ? Rgb(255, 215, 0) : Rgb(255, 70, 50));
        }
    }

    // radar giratorio como el del juego original
    static void Radar(Ent ce)
    {
        int R = Math.Max(14, Math.Min(Math.Min(PH / 5, PW / 9), 28)), ox = R + 2, oy = R + 3;
        double scale = 9.0 / R;   // baldosas por pixel
        double ca = Math.Cos(ce.a + Math.PI / 2), sa = Math.Sin(ce.a + Math.PI / 2);
        for (int y = -R; y <= R; y++)
            for (int x = -R; x <= R; x++)
            {
                double d = Math.Sqrt(x * x + y * y);
                if (d > R) continue;
                double wx = ce.x + (x * ca - y * sa) * scale, wy = ce.y + (x * sa + y * ca) * scale;
                char t = Tile((int)Math.Floor(wx), (int)Math.Floor(wy));
                int c;
                if (Solid((int)Math.Floor(wx), (int)Math.Floor(wy))) c = t == 'X' ? Rgb(110, 84, 50) : Rgb(40, 38, 34);
                else c = t == 'a' || t == 'b' ? Rgb(150, 110, 80) : t == 't' ? Rgb(130, 115, 70) : t == 'c' ? Rgb(80, 105, 140) : Rgb(150, 138, 110);
                if (d > R - 1.2) c = Rgb(200, 200, 200);
                PB(ox + x, oy + y, c, 0.82);
            }
        // letras de las zonas
        foreach (char site in new char[] { 'a', 'b' })
        {
            List<int> l = site == 'a' ? siteA : siteB; int t0 = l[l.Count / 2];
            double sx, sy; if (RadarPos(ce, t0 % MW + 0.5, t0 / MW + 0.5, ox, oy, R, scale, out sx, out sy)) F3Pix(site == 'a' ? "A" : "B", (int)sx - 1, (int)sy - 2, 1, Rgb(255, 80, 60));
        }
        foreach (Ent e in ents)
        {
            if (!e.alive || e == ce) continue;
            bool visible = e.team == myTeam || Spotted(e);
            if (!visible) continue;
            double sx, sy;
            if (RadarPos(ce, e.x, e.y, ox, oy, R, scale, out sx, out sy)) { PDisc(sx, sy, 1.6, TEAMC[e.team], 1); if (e.team != myTeam) PS((int)sx, (int)sy, Rgb(255, 40, 40)); }
        }
        if (bombState == 1 || bombState == 2 || (myTeam == 0 && bombState == 0))
        {
            double bx = bombX, by = bombY;
            if (bombState == 0) { Ent c = FindEnt(bombCarrier); if (c == null) bx = -99; else { bx = c.x; by = c.y; } }
            double sx, sy;
            if (bx > -50 && (myTeam == 0 || bombState == 2) && RadarPos(ce, bx, by, ox, oy, R, scale, out sx, out sy) && Frac(gt * 2) < 0.7) PRect((int)sx - 1, (int)sy - 1, 3, 3, Rgb(255, 60, 40));
        }
        // tu flecha
        PS(ox, oy - 2, Rgb(255, 255, 255)); PS(ox - 1, oy - 1, Rgb(255, 255, 255)); PS(ox, oy - 1, Rgb(255, 255, 255)); PS(ox + 1, oy - 1, Rgb(255, 255, 255));
        PS(ox - 1, oy, Rgb(255, 255, 255)); PS(ox + 1, oy, Rgb(255, 255, 255)); PS(ox, oy, Rgb(255, 255, 255));
    }
    static bool RadarPos(Ent ce, double wx, double wy, int ox, int oy, int R, double scale, out double sx, out double sy)
    {
        double dx = (wx - ce.x) / scale, dy = (wy - ce.y) / scale;
        double ca = Math.Cos(-(ce.a + Math.PI / 2)), sa = Math.Sin(-(ce.a + Math.PI / 2));
        double rx = dx * ca - dy * sa, ry = dx * sa + dy * ca;
        sx = ox + rx; sy = oy + ry;
        return rx * rx + ry * ry < (R - 2) * (R - 2);
    }
    // un enemigo sale en el radar si algun companero lo ve
    static bool Spotted(Ent e)
    {
        foreach (Ent o in ents)
        {
            if (!o.alive || o.team == e.team) continue;
            double dx = e.x - o.x, dy = e.y - o.y, d2 = dx * dx + dy * dy;
            if (d2 > 400) continue;
            if (Math.Abs(AngDiff(Math.Atan2(dy, dx), o.a)) > 1.1 && d2 > 9) continue;
            if (LOS(o.x, o.y, e.x, e.y)) return true;
        }
        return false;
    }

    // ---------------------------------------------------------------- HUD de texto
    static string Clock(double t) { if (t < 0) t = 0; int s = (int)Math.Ceiling(t); return (s / 60) + ":" + (s % 60).ToString("00"); }

    static void HudText()
    {
        int wh = Rgb(255, 255, 255), gr = Rgb(160, 165, 180), yl = Rgb(255, 215, 0);
        foreach (Tag t in tags) TS(t.x - t.s.Length / 2, t.y, t.s, t.c);
        // marcador arriba
        string tl = phase == PH_FREEZE ? Clock(phaseT) : phase == PH_LIVE ? (bombState == 2 ? "BOMBA" : Clock(phaseT)) : "--:--";
        int tx = W / 2;
        TS(tx - 9 - scoreT.ToString().Length, 0, "T " + scoreT, TEAMC[0]);
        TS(tx - 3, 0, tl, bombState == 2 && Frac(gt * 2) < 0.5 ? Rgb(255, 60, 40) : wh);
        TS(tx + 5, 0, scoreCT + " CT", TEAMC[1]);
        TS(tx - 9, 1, "vivos " + AliveCount(0) + "  RONDA " + round + "  vivos " + AliveCount(1), gr);
        // kill feed
        for (int i = 0; i < feed.Count; i++)
        {
            if (gt - feedT[i] > 7) continue;
            string s = feed[i]; TS(W - s.Length - 1, 1 + i, s, feedC[i]);
        }
        // barra inferior
        Ent ce = CamEnt();
        if (me.alive)
        {
            int hc = me.hp > 50 ? wh : me.hp > 25 ? yl : Rgb(255, 60, 50);
            TS(2, H - 2, "+ " + me.hp, hc); TS(10, H - 2, "ESCUDO " + me.armor, Rgb(120, 190, 255));
            TS(24, H - 2, "$ " + me.money, Rgb(120, 255, 120));
            string wn = WN[me.cur];
            string am = me.cur >= W_GLOCK && me.cur <= W_AWP ? me.clip[me.cur] + " / " + me.res[me.cur] : me.cur == W_HE ? "x" + me.nades : "";
            if (me.reload > 0) am = "RECARGANDO...";
            TS(W - wn.Length - am.Length - 4, H - 2, wn, wh); TS(W - am.Length - 2, H - 2, am, me.cur >= W_GLOCK && me.cur <= W_AWP && me.clip[me.cur] == 0 ? Rgb(255, 60, 50) : yl);
            StringBuilder inv = new StringBuilder();
            if (me.prim >= 0) inv.Append("1:" + WN[me.prim] + "  "); inv.Append("2:" + WN[me.sec] + "  3:CUCHILLO");
            if (me.nades > 0) inv.Append("  4:GRANADA"); if (me.hasBomb) inv.Append("  5:C4");
            TS(W - inv.Length - 2, H - 3, inv.ToString(), gr);
            if (me.hasBomb) TS(2, H - 3, "LLEVAS LA BOMBA: ve a la zona A o B y manten E", Rgb(255, 140, 60));
            else if (me.team == 1 && bombState == 2) TS(2, H - 3, "DESACTIVA LA BOMBA: acercate y manten E", Rgb(120, 190, 255));
        }
        else
        {
            Ent k = FindEnt(killerKey);
            TSC(H - 3, "HAS MUERTO" + (k != null ? "  -  te elimino " + k.name : ""), Rgb(255, 80, 60));
            if (ce != me) TSC(H - 2, "Viendo a " + ce.name + "  (clic o espacio para cambiar)", gr);
        }
        if (me.plantP > 0) TSC(H / 2 + 5, "PLANTANDO LA BOMBA...", Rgb(255, 140, 60));
        if (me.defuseP > 0) TSC(H / 2 + 5, "DESACTIVANDO...", Rgb(120, 190, 255));
        if (phase == PH_FREEZE) TSC(H / 2 - 6, "LA RONDA EMPIEZA EN " + (int)Math.Ceiling(phaseT) + "   -   B: TIENDA", yl);
        else if (CanBuy() && !buyOpen && ROUNDTIME - phaseT < 20) TS(2, H - 4, "B: tienda", gr);
        if (phase == PH_END || phase == PH_OVER)
        {
            string s = lastWinner == 0 ? "GANAN LOS TERRORISTAS" : "GANAN LOS ANTITERRORISTAS";
            TSC(H / 2 - 7, s, TEAMC[Math.Max(0, lastWinner)]); TSC(H / 2 - 6, roundMsg, wh);
            if (phase == PH_OVER) TSC(H / 2 + 3, "PARTIDA TERMINADA  " + scoreT + " - " + scoreCT, yl);
        }
        if (bombState == 2 && phase == PH_LIVE && Frac(gt) < 0.6) TSC(3, "*** BOMBA PLANTADA ***", Rgb(255, 70, 50));
        if (gt - annT < 2.2 && annText.Length > 26) TSC(H / 4, annText, annCol);
        if (!focused && !dumping) TSC(H / 2 + 8, "(haz clic en esta ventana para jugar)", gr);
        if (buyOpen) BuyText();
        if (showScore) ScoreText();
        if (showHelp) HelpText();
        if (paused) { TSC(H / 2 - 2, "PAUSA", yl); TSC(H / 2, "ENTER: seguir      ESC: salir a la sala", wh); TSC(H / 2 + 1, "(en online la partida sigue)", gr); }
        TS(W - 9, 0, (int)Math.Round(fps) + " fps", Rgb(110, 115, 130));
        if (!showHelp && gt < 25 && state == ST_GAME) TS(2, H - 4 - (CanBuy() ? 1 : 0), "F1 o H: controles", gr);
    }

    static void BuyText()
    {
        int x = W / 2 - 22, y = 5;
        TS(x, y, "TIENDA  -  " + TEAMN[myTeam], TEAMC[myTeam]);
        TS(x + 30, y, "$ " + me.money, Rgb(120, 255, 120));
        for (int k = 0; k < SHOP.Length; k++)
        {
            int it = ShopItem(k, myTeam), pr = ItemPrice(it);
            bool ok = me.money >= pr;
            string have = (it == me.prim || it == me.sec || (it == 10 && me.armor >= 100) || (it == W_HE && me.nades > 0)) ? "  (lo tienes)" : "";
            TS(x + 1, y + 2 + k, (k + 1) + "  " + ItemName(it) + have, ok ? Rgb(255, 255, 255) : Rgb(110, 110, 120));
            TS(x + 36, y + 2 + k, "$" + pr, ok ? Rgb(120, 255, 120) : Rgb(150, 70, 70));
        }
        TS(x + 1, y + 3 + SHOP.Length, "Pulsa el numero para comprar.  B: cerrar", Rgb(160, 165, 180));
    }

    static void ScoreText()
    {
        int x = W / 2 - 36;
        TS(x, 4, "MARCADOR      T " + scoreT + "  -  " + scoreCT + " CT        ronda " + round + "   (gana quien llegue a " + roundsToWin + ")", Rgb(255, 255, 255));
        for (int t = 0; t < 2; t++)
        {
            int y = 6 + t * 7;
            TS(x, y, TEAMN[t], TEAMC[t]); TS(x + 34, y, "BAJAS  MUERTES  DINERO", Rgb(160, 165, 180));
            List<Ent> l = new List<Ent>(); foreach (Ent e in ents) if (e.team == t) l.Add(e);
            l.Sort(delegate(Ent p, Ent q) { return q.kills.CompareTo(p.kills); });
            int r = 0;
            foreach (Ent e in l)
            {
                int c = e == me ? Rgb(255, 230, 0) : e.alive ? Rgb(235, 235, 240) : Rgb(120, 120, 130);
                TS(x + 1, y + 1 + r, (e.alive ? "  " : "x ") + e.name + (e.hasBomb && t == myTeam ? " [C4]" : ""), c);
                TS(x + 36, y + 1 + r, e.kills.ToString(), c); TS(x + 43, y + 1 + r, e.deaths.ToString(), c);
                if (t == myTeam) TS(x + 50, y + 1 + r, "$" + e.money, c);
                r++;
            }
        }
    }

    static void HelpText()
    {
        int x = W / 2 - 28, y = 4, wh = Rgb(235, 235, 240), cy = Rgb(0, 220, 255);
        string[] L = {
            "CONTROLES", "",
            "W A S D ............ moverse        SHIFT: andar en silencio",
            "RATON .............. apuntar        (M activa/desactiva el raton)",
            "FLECHAS ............ girar y mirar arriba/abajo sin raton",
            "CLIC IZQ o ESPACIO . disparar       CLIC DER o Z: mira del AWP",
            "R .................. recargar       CTRL o C: agacharse",
            "1 2 3 4 5 .......... arma principal, pistola, cuchillo, granada, C4",
            "Q .................. arma anterior",
            "B .................. tienda (en tu base al empezar la ronda)",
            "E (mantener) ....... plantar la bomba en A/B o desactivarla",
            "TAB ................ marcador       ESC: pausa / salir",
            "+ / - .............. mas o menos resolucion (consola clasica)", "",
            "TERRORISTAS: plantad la bomba en A o B o eliminad a todos.",
            "ANTITERRORISTAS: impedidlo o desactivad la bomba.",
            "F1 o H: cerrar" };
        for (int i = 0; i < L.Length; i++) TS(x, y + i, L[i], i == 0 ? cy : wh);
    }

    // ================================================================ menus (titulo, nombre, sala)
    static double flyT;
    static void MenuRender(double dt)
    {
        // de fondo, un vuelo por el mapa
        flyT += dt * 0.05;
        double[] px = { 16.5, 16.5, 28.5, 27, 20, 8, 4.5, 11, 16.5 }, py = { 28, 16, 20, 5, 10.5, 6, 15, 19, 28 };
        int n = px.Length - 1; double f = Frac(flyT) * n; int i = (int)f; double t = f - i;
        double st = t * t * (3 - 2 * t);
        camX = Lp(px[i], px[i + 1], st); camY = Lp(py[i], py[i + 1], st);
        double ta = Math.Atan2(py[i + 1] - py[i], px[i + 1] - px[i]);
        double na = Math.Atan2(py[(i + 2) % (n + 1) == 0 ? 1 : Math.Min(n, i + 2)] - py[i + 1], px[Math.Min(n, i + 2)] - px[i + 1]);
        camA = ta + AngDiff(na, ta) * Cl((t - 0.6) / 0.4) + Math.Sin(gt * 0.3) * 0.2;
        camPitch = Math.Sin(gt * 0.2) * 0.05; camH = 0.55; fov = 1.25;
        Render3D();
        for (int k = 0; k < pix.Length; k++) pix[k] = Lerp(pix[k], Rgb(10, 8, 6), state == ST_TITLE ? 0.25 : 0.55);
        int sc = W >= 150 ? 2 : 1;
        int w1 = BigW("COUNTER", sc), w2 = BigW("CMD", sc);
        double shine = Frac(gt / 3) * (w1 + 40) - 20;
        BigPix("COUNTER", (W - w1) / 2, 1, sc, Rgb(255, 210, 90), Rgb(220, 110, 20), Rgb(70, 30, 0), shine);
        BigPix("CMD", (W - w2) / 2, 1 + 7 * sc, sc, Rgb(120, 200, 255), Rgb(40, 90, 200), Rgb(10, 20, 60), shine - 10);
        int top = 2 + 14 * sc;
        if (state == ST_NAME || state == ST_JOIN) Panel(W / 2 - 26, Math.Min(H - 10, top), 52, 9, 0.85, Rgb(255, 170, 40));
        if (state == ST_LOBBY) { Panel(W / 2 - 40, Math.Min(H - 18, top - 1), 39, 13, 0.82, TEAMC[0]); Panel(W / 2 + 1, Math.Min(H - 18, top - 1), 39, 13, 0.82, TEAMC[1]); }
        ToCells();
        int wh = Rgb(255, 255, 255), gr = Rgb(170, 170, 185), yl = Rgb(255, 215, 0);
        int y = Math.Min(H - 10, top);
        if (state == ST_TITLE)
        {
            TSC(y, "Shooter tactico por equipos en tu consola", wh);
            TSC(y + 2, "Terroristas contra antiterroristas  -  bomba  -  tienda  -  online en red local", gr);
            if (Frac(gt * 0.8) < 0.65) TSC(y + 5, ">>  PULSA ENTER  <<", yl);
            TSC(y + 7, "ESC: salir", gr);
        }
        else if (state == ST_NAME)
        {
            TSC(y + 1, "SOLDADO, COMO TE LLAMAS?", yl);
            TSC(y + 2, "Escribe tu nombre (maximo 12 letras)", gr);
            TS(W / 2 - 10, y + 4, nameBuf + (Frac(gt * 1.5) < 0.5 ? "_" : " "), wh);
            TSC(y + 6, "ENTER: continuar", wh);
        }
        else if (state == ST_JOIN)
        {
            TSC(y + 1, "UNIRSE A UN AMIGO", Rgb(0, 230, 255));
            TSC(y + 2, "Escribe el codigo (IP) que sale en su sala", gr);
            TS(W / 2 - 8, y + 4, ipBuf + (Frac(gt * 1.5) < 0.5 ? "_" : " "), wh);
            TSC(y + 6, "ENTER: conectar     ESC: volver", wh);
            TSC(y + 7, "No hace falta ser administrador", gr);
        }
        else if (state == ST_LOBBY) LobbyText(Math.Min(H - 18, top - 1));
        if (gt - annT < 2.5 && annText.Length > 0) TSC(H - 2, annText, annCol);
    }

    static void LobbyText(int y)
    {
        int wh = Rgb(255, 255, 255), gr = Rgb(170, 170, 185), yl = Rgb(255, 215, 0);
        List<long> ids = LobbyIds();
        for (int t = 0; t < 2; t++)
        {
            int x = t == 0 ? W / 2 - 38 : W / 2 + 3;
            TS(x, y + 1, (myTeam == t ? "> " : "  ") + TEAMN[t] + (myTeam == t ? " <" : ""), TEAMC[t]);
            int r = 0;
            foreach (long id in ids)
            {
                if (PeerTeam(id) != t || r >= 5) continue;
                string n = id == myId ? myName : PeerName(id);
                TS(x + 2, y + 3 + r, n + (id == myId ? "  (TU)" : "") + (ids[0] == id ? "  *anfitrion" : ""), id == myId ? Rgb(255, 230, 0) : wh);
                r++;
            }
            for (; r < 5; r++) TS(x + 2, y + 3 + r, "BOT", Rgb(110, 110, 120));
        }
        TS(W / 2 - 38, y + 9, t0Help(), gr);
        int fy = y + 13;
        TSC(fy, "FLECHAS IZQ / DER (o 1 / 2): elegir bando", wh);
        if (LobbyHost()) { if (Frac(gt * 0.8) < 0.65) TSC(fy + 1, ">>  ENTER: EMPEZAR LA PARTIDA  <<", yl); }
        else TSC(fy + 1, "Esperando a que " + PeerName(ids[0]) + " empiece la partida...", yl);
        if (udp == null) TSC(fy + 3, netErr, Rgb(255, 90, 70));
        else TSC(fy + 3, "TU CODIGO:  " + (myIp.Length > 0 ? myIp : "?") + "     tus amigos pulsan U y lo escriben", Rgb(0, 230, 255));
        TSC(fy + 4, "U: unirme a un amigo     N: cambiar nombre     ESC: salir", gr);
    }
    static string t0Help() { return "Los huecos se rellenan con bots (5 contra 5)"; }

    // ================================================================ modo de prueba
    static void DumpKeys() { if (Environment.GetEnvironmentVariable("CC_MENU") != null && gt > 2 && gt < 2.05) kNow[0x0D] = true; }
    public static void Dump(int w, int h, string path, double[] times)
    {
        dumping = true; W = w; H = h; Alloc(); Init();
        using (StreamWriter o = new StreamWriter(path, false, new UTF8Encoding(false)))
        {
            double T = 0, dt = 1.0 / 30; int k = 0;
            Stopwatch sw = Stopwatch.StartNew(); int frames = 0;
            while (k < times.Length)
            {
                ReadInput(); Frame(dt); T += dt; frames++;
                if (T >= times[k])
                {
                    o.WriteLine("F " + T.ToString("0.00", INV) + " state=" + state + " round=" + round + " phase=" + phase + " score=" + scoreT + "-" + scoreCT + " aliveT=" + AliveCount(0) + " aliveCT=" + AliveCount(1) + " bomb=" + bombState + " me=" + (me != null ? me.hp + "hp " + WN[me.cur] + " $" + me.money : "-") + " ms=" + (sw.Elapsed.TotalMilliseconds / frames).ToString("0.0", INV) + " msg=" + roundMsg);
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
[CounterCmd]::Run()
exit 0
