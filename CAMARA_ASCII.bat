<# : -------- parte BATCH (PowerShell la ve como un comentario) --------
@echo off
setlocal
title CAMARA ASCII
color 0F
cls
echo.
echo   [*] CAMARA ASCII
echo   [*] Preparando el motor, espera un segundo...
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
# -------- parte POWERSHELL: compila y lanza el programa --------
$ErrorActionPreference = 'Stop'
$code = @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;

public static class CamAscii
{
    // ================================================================ Media Foundation (la camara de Windows)
    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("2cd2d921-c447-44a7-a13c-4adabfc247e3")]
    public interface IMFAttributes
    {
        [PreserveSig] int GetItem(ref Guid k, IntPtr v);
        [PreserveSig] int GetItemType(ref Guid k, out int t);
        [PreserveSig] int CompareItem(ref Guid k, IntPtr v, out int r);
        [PreserveSig] int Compare(IntPtr a, int t, out int r);
        [PreserveSig] int GetUINT32(ref Guid k, out int v);
        [PreserveSig] int GetUINT64(ref Guid k, out long v);
        [PreserveSig] int GetDouble(ref Guid k, out double v);
        [PreserveSig] int GetGUID(ref Guid k, out Guid v);
        [PreserveSig] int GetStringLength(ref Guid k, out int n);
        [PreserveSig] int GetString(ref Guid k, IntPtr s, int n, out int l);
        [PreserveSig] int GetAllocatedString(ref Guid k, out IntPtr s, out int l);
        [PreserveSig] int GetBlobSize(ref Guid k, out int n);
        [PreserveSig] int GetBlob(ref Guid k, IntPtr b, int n, out int l);
        [PreserveSig] int GetAllocatedBlob(ref Guid k, out IntPtr b, out int n);
        [PreserveSig] int GetUnknown(ref Guid k, ref Guid riid, out IntPtr p);
        [PreserveSig] int SetItem(ref Guid k, IntPtr v);
        [PreserveSig] int DeleteItem(ref Guid k);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32(ref Guid k, int v);
        [PreserveSig] int SetUINT64(ref Guid k, long v);
        [PreserveSig] int SetDouble(ref Guid k, double v);
        [PreserveSig] int SetGUID(ref Guid k, ref Guid v);
        [PreserveSig] int SetString(ref Guid k, [MarshalAs(UnmanagedType.LPWStr)] string v);
        [PreserveSig] int SetBlob(ref Guid k, IntPtr b, int n);
        [PreserveSig] int SetUnknown(ref Guid k, IntPtr p);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out int n);
        [PreserveSig] int GetItemByIndex(int i, out Guid k, IntPtr v);
        [PreserveSig] int CopyAllItems(IntPtr dest);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("7FEE9E9A-4A89-47a6-899C-B6A53A70FB67")]
    public interface IMFActivate
    {
        [PreserveSig] int GetItem(ref Guid k, IntPtr v);
        [PreserveSig] int GetItemType(ref Guid k, out int t);
        [PreserveSig] int CompareItem(ref Guid k, IntPtr v, out int r);
        [PreserveSig] int Compare(IntPtr a, int t, out int r);
        [PreserveSig] int GetUINT32(ref Guid k, out int v);
        [PreserveSig] int GetUINT64(ref Guid k, out long v);
        [PreserveSig] int GetDouble(ref Guid k, out double v);
        [PreserveSig] int GetGUID(ref Guid k, out Guid v);
        [PreserveSig] int GetStringLength(ref Guid k, out int n);
        [PreserveSig] int GetString(ref Guid k, IntPtr s, int n, out int l);
        [PreserveSig] int GetAllocatedString(ref Guid k, out IntPtr s, out int l);
        [PreserveSig] int GetBlobSize(ref Guid k, out int n);
        [PreserveSig] int GetBlob(ref Guid k, IntPtr b, int n, out int l);
        [PreserveSig] int GetAllocatedBlob(ref Guid k, out IntPtr b, out int n);
        [PreserveSig] int GetUnknown(ref Guid k, ref Guid riid, out IntPtr p);
        [PreserveSig] int SetItem(ref Guid k, IntPtr v);
        [PreserveSig] int DeleteItem(ref Guid k);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32(ref Guid k, int v);
        [PreserveSig] int SetUINT64(ref Guid k, long v);
        [PreserveSig] int SetDouble(ref Guid k, double v);
        [PreserveSig] int SetGUID(ref Guid k, ref Guid v);
        [PreserveSig] int SetString(ref Guid k, [MarshalAs(UnmanagedType.LPWStr)] string v);
        [PreserveSig] int SetBlob(ref Guid k, IntPtr b, int n);
        [PreserveSig] int SetUnknown(ref Guid k, IntPtr p);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out int n);
        [PreserveSig] int GetItemByIndex(int i, out Guid k, IntPtr v);
        [PreserveSig] int CopyAllItems(IntPtr dest);
        [PreserveSig] int ActivateObject(ref Guid riid, out IntPtr ppv);
        [PreserveSig] int ShutdownObject();
        [PreserveSig] int DetachObject();
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("44ae0fa8-ea31-4109-8d2e-4cae4997c555")]
    public interface IMFMediaType
    {
        [PreserveSig] int GetItem(ref Guid k, IntPtr v);
        [PreserveSig] int GetItemType(ref Guid k, out int t);
        [PreserveSig] int CompareItem(ref Guid k, IntPtr v, out int r);
        [PreserveSig] int Compare(IntPtr a, int t, out int r);
        [PreserveSig] int GetUINT32(ref Guid k, out int v);
        [PreserveSig] int GetUINT64(ref Guid k, out long v);
        [PreserveSig] int GetDouble(ref Guid k, out double v);
        [PreserveSig] int GetGUID(ref Guid k, out Guid v);
        [PreserveSig] int GetStringLength(ref Guid k, out int n);
        [PreserveSig] int GetString(ref Guid k, IntPtr s, int n, out int l);
        [PreserveSig] int GetAllocatedString(ref Guid k, out IntPtr s, out int l);
        [PreserveSig] int GetBlobSize(ref Guid k, out int n);
        [PreserveSig] int GetBlob(ref Guid k, IntPtr b, int n, out int l);
        [PreserveSig] int GetAllocatedBlob(ref Guid k, out IntPtr b, out int n);
        [PreserveSig] int GetUnknown(ref Guid k, ref Guid riid, out IntPtr p);
        [PreserveSig] int SetItem(ref Guid k, IntPtr v);
        [PreserveSig] int DeleteItem(ref Guid k);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32(ref Guid k, int v);
        [PreserveSig] int SetUINT64(ref Guid k, long v);
        [PreserveSig] int SetDouble(ref Guid k, double v);
        [PreserveSig] int SetGUID(ref Guid k, ref Guid v);
        [PreserveSig] int SetString(ref Guid k, [MarshalAs(UnmanagedType.LPWStr)] string v);
        [PreserveSig] int SetBlob(ref Guid k, IntPtr b, int n);
        [PreserveSig] int SetUnknown(ref Guid k, IntPtr p);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out int n);
        [PreserveSig] int GetItemByIndex(int i, out Guid k, IntPtr v);
        [PreserveSig] int CopyAllItems(IntPtr dest);
        [PreserveSig] int GetMajorType(out Guid g);
        [PreserveSig] int IsCompressedFormat(out int b);
        [PreserveSig] int IsEqual(IntPtr t, out int f);
        [PreserveSig] int GetRepresentation(Guid g, out IntPtr p);
        [PreserveSig] int FreeRepresentation(Guid g, IntPtr p);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("045FA593-8799-42b8-BC8D-8968C6453507")]
    public interface IMFMediaBuffer
    {
        [PreserveSig] int Lock(out IntPtr p, out int max, out int cur);
        [PreserveSig] int Unlock();
        [PreserveSig] int GetCurrentLength(out int n);
        [PreserveSig] int SetCurrentLength(int n);
        [PreserveSig] int GetMaxLength(out int n);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("c40a00f2-b93a-4d80-ae8c-5a1c634f58e4")]
    public interface IMFSample
    {
        [PreserveSig] int GetItem(ref Guid k, IntPtr v);
        [PreserveSig] int GetItemType(ref Guid k, out int t);
        [PreserveSig] int CompareItem(ref Guid k, IntPtr v, out int r);
        [PreserveSig] int Compare(IntPtr a, int t, out int r);
        [PreserveSig] int GetUINT32(ref Guid k, out int v);
        [PreserveSig] int GetUINT64(ref Guid k, out long v);
        [PreserveSig] int GetDouble(ref Guid k, out double v);
        [PreserveSig] int GetGUID(ref Guid k, out Guid v);
        [PreserveSig] int GetStringLength(ref Guid k, out int n);
        [PreserveSig] int GetString(ref Guid k, IntPtr s, int n, out int l);
        [PreserveSig] int GetAllocatedString(ref Guid k, out IntPtr s, out int l);
        [PreserveSig] int GetBlobSize(ref Guid k, out int n);
        [PreserveSig] int GetBlob(ref Guid k, IntPtr b, int n, out int l);
        [PreserveSig] int GetAllocatedBlob(ref Guid k, out IntPtr b, out int n);
        [PreserveSig] int GetUnknown(ref Guid k, ref Guid riid, out IntPtr p);
        [PreserveSig] int SetItem(ref Guid k, IntPtr v);
        [PreserveSig] int DeleteItem(ref Guid k);
        [PreserveSig] int DeleteAllItems();
        [PreserveSig] int SetUINT32(ref Guid k, int v);
        [PreserveSig] int SetUINT64(ref Guid k, long v);
        [PreserveSig] int SetDouble(ref Guid k, double v);
        [PreserveSig] int SetGUID(ref Guid k, ref Guid v);
        [PreserveSig] int SetString(ref Guid k, [MarshalAs(UnmanagedType.LPWStr)] string v);
        [PreserveSig] int SetBlob(ref Guid k, IntPtr b, int n);
        [PreserveSig] int SetUnknown(ref Guid k, IntPtr p);
        [PreserveSig] int LockStore();
        [PreserveSig] int UnlockStore();
        [PreserveSig] int GetCount(out int n);
        [PreserveSig] int GetItemByIndex(int i, out Guid k, IntPtr v);
        [PreserveSig] int CopyAllItems(IntPtr dest);
        [PreserveSig] int GetSampleFlags(out int f);
        [PreserveSig] int SetSampleFlags(int f);
        [PreserveSig] int GetSampleTime(out long t);
        [PreserveSig] int SetSampleTime(long t);
        [PreserveSig] int GetSampleDuration(out long t);
        [PreserveSig] int SetSampleDuration(long t);
        [PreserveSig] int GetBufferCount(out int n);
        [PreserveSig] int GetBufferByIndex(int i, out IMFMediaBuffer b);
        [PreserveSig] int ConvertToContiguousBuffer(out IMFMediaBuffer b);
        [PreserveSig] int AddBuffer(IMFMediaBuffer b);
        [PreserveSig] int RemoveBufferByIndex(int i);
        [PreserveSig] int RemoveAllBuffers();
        [PreserveSig] int GetTotalLength(out int n);
        [PreserveSig] int CopyToBuffer(IMFMediaBuffer b);
    }

    [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("70ae66f2-c809-4e4f-8915-bdcb406b7993")]
    public interface IMFSourceReader
    {
        [PreserveSig] int GetStreamSelection(int s, out int sel);
        [PreserveSig] int SetStreamSelection(int s, int sel);
        [PreserveSig] int GetNativeMediaType(int s, int i, out IMFMediaType t);
        [PreserveSig] int GetCurrentMediaType(int s, out IMFMediaType t);
        [PreserveSig] int SetCurrentMediaType(int s, IntPtr reserved, IMFMediaType t);
        [PreserveSig] int SetCurrentPosition(ref Guid fmt, IntPtr pos);
        [PreserveSig] int ReadSample(int s, int flags, out int actual, out int sflags, out long ts, out IMFSample sample);
        [PreserveSig] int Flush(int s);
        [PreserveSig] int GetServiceForStream(int s, ref Guid svc, ref Guid riid, out IntPtr p);
        [PreserveSig] int GetPresentationAttribute(int s, ref Guid k, IntPtr v);
    }

    [DllImport("mfplat.dll")] static extern int MFStartup(int version, int flags);
    [DllImport("mfplat.dll")] static extern int MFShutdown();
    [DllImport("mfplat.dll")] static extern int MFCreateAttributes(out IMFAttributes a, int n);
    [DllImport("mfplat.dll")] static extern int MFCreateMediaType(out IMFMediaType t);
    [DllImport("mf.dll")] static extern int MFEnumDeviceSources(IMFAttributes a, out IntPtr arr, out int n);
    [DllImport("mfreadwrite.dll")] static extern int MFCreateSourceReaderFromMediaSource(IntPtr src, IMFAttributes a, out IMFSourceReader r);

    static readonly Guid SRC_TYPE = new Guid("c60ac5fe-252a-478f-a0ef-bc8fa5f7cad3");
    static readonly Guid SRC_VIDCAP = new Guid("8ac3587a-4ae7-42d8-99e0-0a6013eef90f");
    static readonly Guid FRIENDLY = new Guid("60d0e559-52f8-4fa2-bbce-acdb34a8ec01");
    static readonly Guid VIDPROC = new Guid("fb394f3d-ccf1-42ee-bbb3-f9b845d5681d");
    static readonly Guid MT_MAJOR = new Guid("48eba18e-f8c9-4687-bf11-0a74c9f96a8f");
    static readonly Guid MT_SUB = new Guid("f7e34c9a-42e8-4714-b74b-cb29d72c35e5");
    static readonly Guid MT_SIZE = new Guid("1652c33d-d6b2-4012-b834-72030849a37d");
    static readonly Guid MT_STRIDE = new Guid("644b4e48-1e02-4516-b0eb-c01ca9d49ac6");
    static readonly Guid VIDEO = new Guid("73646976-0000-0010-8000-00AA00389B71");
    static readonly Guid RGB32 = new Guid("00000016-0000-0010-8000-00AA00389B71");
    static readonly Guid IID_SOURCE = new Guid("279a808d-aec7-40c8-9c6b-a6b492c78a66");
    const int FIRST_VIDEO = unchecked((int)0xFFFFFFFC);

    // ================================================================ consola
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool WriteConsoleW(IntPtr h, string s, int n, out int w, IntPtr r);
    [DllImport("kernel32.dll")] static extern bool FlushConsoleInputBuffer(IntPtr h);

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
    static IntPtr hOut, hIn; static bool win, hadMode; static uint oldMode;
    static int W = 120, H = 40;
    static char[] cb, pcb; static int[] cc, cbg, pcc, pcbg; static bool fullDraw = true;
    static StringBuilder sb = new StringBuilder(1 << 18);
    static volatile bool quit; static bool testing;

    // ================================================================ arranque
    public static void Run()
    {
        Setup();
        if (!win && Environment.OSVersion.Platform == PlatformID.Win32NT)
        {
            Console.WriteLine("Esta consola no soporta colores ANSI (hace falta Windows 10 o superior).");
            return;
        }
        Thread cap = new Thread(CapThread);
        cap.IsBackground = true;
        cap.SetApartmentState(ApartmentState.MTA);
        cap.Start();
        try
        {
            Stopwatch sw = Stopwatch.StartNew();
            double last = 0, fpsT = 0; int fpsN = 0;
            while (!quit)
            {
                double t = sw.Elapsed.TotalSeconds;
                gt = t;
                Keys();
                CheckSize();
                bool fresh = GrabFrame();
                if (fresh || dirty || t - last > 0.25)
                {
                    last = t; dirty = false;
                    Draw();
                    Present();
                    if (fresh) { fpsN++; }
                }
                if (t - fpsT >= 1) { fps = fpsN / (t - fpsT); fpsN = 0; fpsT = t; dirty = true; }
                Thread.Sleep(fresh ? 1 : 8);
            }
        }
        finally { capRun = false; Restore(); }
    }

    // prueba sin camara: dibuja una imagen RGB32 en todos los modos
    public static void Test(int w, int h, string raw, int iw, int ih, string outPath)
    {
        testing = true; W = w; H = h; Alloc(); InitGlyphs();
        byte[] b = File.ReadAllBytes(raw);
        img = b; iw_ = iw; ih_ = ih; istride = iw * 4;
        using (StreamWriter o = new StreamWriter(outPath, false, new UTF8Encoding(false)))
        {
            for (int m = 0; m < MODES.Length; m++)
            {
                mode = m; prevValid = false;
                for (int k = 0; k < 4; k++) { Process(); }
                Draw();
                o.WriteLine("F " + m + " " + MODES[m]);
                for (int y = 0; y < H; y++) o.WriteLine(new string(cb, y * W, W));
                for (int y = 0; y < H; y++)
                {
                    StringBuilder l = new StringBuilder();
                    for (int x = 0; x < W; x++) { int i = y * W + x; l.Append(cc[i].ToString("x6")).Append(cbg[i].ToString("x6")); }
                    o.WriteLine(l.ToString());
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
        FontSetup();
        ReadSize(); Alloc(); InitGlyphs();
        Out(E + "?25l" + E + "0m" + E + "2J");
    }

    static void OnCancel(object s, ConsoleCancelEventArgs e) { e.Cancel = true; quit = true; }

    static void Restore()
    {
        Out(E + "0m" + E + "2J" + E + "H" + E + "?25h");
        FontRestore();
        try { Console.CursorVisible = true; } catch { }
        if (hadMode) { try { SetConsoleMode(hOut, oldMode); } catch { } }
        try { FlushConsoleInputBuffer(hIn); } catch { }
    }

    static void ReadSize()
    {
        try { W = Math.Max(40, Console.WindowWidth); H = Math.Max(15, Console.WindowHeight); }
        catch { W = 120; H = 40; }
    }

    static void CheckSize()
    {
        int ow = W, oh = H; ReadSize();
        if (ow != W || oh != H) { Alloc(); Out(E + "0m" + E + "2J"); dirty = true; }
    }

    static void Alloc()
    {
        cb = new char[W * H]; cc = new int[W * H]; cbg = new int[W * H];
        pcb = new char[W * H]; pcc = new int[W * H]; pcbg = new int[W * H]; fullDraw = true;
    }

    // ---------------------------------------------------------------- tamano de letra (consola clasica)
    static bool fontCtl; static FONTEX origFont; static CSBI origInfo;
    static readonly int[] FSIZES = { 5, 6, 8, 10, 12, 14, 16, 20 };
    static int fIdx = 3;

    static void FontSetup()
    {
        if (!string.IsNullOrEmpty(Environment.GetEnvironmentVariable("WT_SESSION"))) return;
        try
        {
            origFont = new FONTEX(); origFont.cbSize = Marshal.SizeOf(typeof(FONTEX));
            if (!GetCurrentConsoleFontEx(hOut, false, ref origFont)) return;
            if (!GetConsoleScreenBufferInfo(hOut, out origInfo)) return;
            fontCtl = true;
            ApplyFont();
        }
        catch { fontCtl = false; }
    }

    static void ApplyFont()
    {
        if (!fontCtl) return;
        try
        {
            FONTEX f = new FONTEX(); f.cbSize = Marshal.SizeOf(typeof(FONTEX));
            f.fw = 0; f.fh = (short)FSIZES[fIdx]; f.family = 54; f.weight = 400; f.face = "Consolas";
            SetCurrentConsoleFontEx(hOut, false, ref f);
            int big = GetLargestConsoleWindowSize(hOut);
            int c = Math.Max(40, (big & 0xFFFF) - 2), l = Math.Max(15, ((big >> 16) & 0xFFFF) - 2);
            Resize(c, l);
        }
        catch { }
    }

    static void Resize(int c, int l)
    {
        SRECT tiny = new SRECT(); tiny.L = 0; tiny.T = 0; tiny.R = 1; tiny.B = 1;
        SetConsoleWindowInfo(hOut, true, ref tiny);
        SetConsoleScreenBufferSize(hOut, (l << 16) | c);
        SRECT r = new SRECT(); r.L = 0; r.T = 0; r.R = (short)(c - 1); r.B = (short)(l - 1);
        SetConsoleWindowInfo(hOut, true, ref r);
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
            SRECT r = origInfo.win;
            SetConsoleWindowInfo(hOut, true, ref r);
        }
        catch { }
    }

    // ================================================================ captura (hilo aparte)
    static volatile bool capRun = true;
    static volatile int camReq = 0, camCur = -1, camCount = 0;
    static volatile string camName = "", camErr = "", camRes = "";
    static readonly object fLock = new object();
    static byte[] shFrame; static int shLen, shW, shH, shStride; static volatile int shId;

    static string Hex(int hr) { return "0x" + hr.ToString("X8"); }

    static void CapThread()
    {
        int hr = MFStartup(0x20070, 0);
        if (hr < 0) { camErr = "No se pudo iniciar Media Foundation (" + Hex(hr) + ")."; return; }
        while (capRun)
        {
            int want = camReq;
            IMFActivate act = null; IMFSourceReader reader = null;
            try { reader = Open(want, out act); }
            catch (Exception ex) { camErr = "Error al abrir la camara: " + ex.Message; }
            if (reader == null)
            {
                for (int k = 0; k < 40 && capRun && camReq == want; k++) Thread.Sleep(50);
                continue;
            }
            camCur = want; camErr = "";
            int w = 0, h = 0, stride = 0;
            ReadFormat(reader, out w, out h, out stride);
            while (capRun && camReq == want)
            {
                int ai, fl; long ts; IMFSample s;
                hr = reader.ReadSample(FIRST_VIDEO, 0, out ai, out fl, out ts, out s);
                if (hr < 0) { camErr = "Se ha perdido la camara (" + Hex(hr) + "). Puede que otra aplicacion la este usando."; break; }
                if ((fl & 0x20) != 0) ReadFormat(reader, out w, out h, out stride);
                if ((fl & 0x3) != 0) { camErr = "La camara ha dejado de enviar imagen."; break; }
                if (s == null) continue;
                IMFMediaBuffer b;
                if (s.ConvertToContiguousBuffer(out b) >= 0 && b != null)
                {
                    IntPtr p; int mx, cur;
                    if (b.Lock(out p, out mx, out cur) >= 0)
                    {
                        lock (fLock)
                        {
                            if (shFrame == null || shFrame.Length < cur) shFrame = new byte[cur];
                            Marshal.Copy(p, shFrame, 0, cur);
                            shLen = cur; shW = w; shH = h; shStride = stride != 0 ? stride : w * 4;
                            if (Math.Abs(shStride) * h > cur) shStride = cur / Math.Max(1, h) * Math.Sign(shStride);
                            shId++;
                        }
                        b.Unlock();
                    }
                    Marshal.ReleaseComObject(b);
                }
                Marshal.ReleaseComObject(s);
            }
            try { Marshal.ReleaseComObject(reader); } catch { }
            if (act != null) { try { act.ShutdownObject(); Marshal.ReleaseComObject(act); } catch { } }
            if (camErr.Length > 0) for (int k = 0; k < 40 && capRun && camReq == want; k++) Thread.Sleep(50);
        }
        try { MFShutdown(); } catch { }
    }

    static IMFSourceReader Open(int index, out IMFActivate chosen)
    {
        chosen = null;
        IMFAttributes a; int hr = MFCreateAttributes(out a, 1);
        if (hr < 0) { camErr = "Error de Media Foundation (" + Hex(hr) + ")."; return null; }
        Guid k = SRC_TYPE, v = SRC_VIDCAP;
        a.SetGUID(ref k, ref v);
        IntPtr arr; int n;
        hr = MFEnumDeviceSources(a, out arr, out n);
        Marshal.ReleaseComObject(a);
        if (hr < 0) { camErr = "No se pudieron buscar camaras (" + Hex(hr) + ")."; return null; }
        camCount = n;
        if (n == 0) { camErr = "No se ha encontrado ninguna camara conectada."; Marshal.FreeCoTaskMem(arr); return null; }
        index = ((index % n) + n) % n;
        for (int i = 0; i < n; i++)
        {
            IntPtr p = Marshal.ReadIntPtr(arr, i * IntPtr.Size);
            if (i == index) chosen = (IMFActivate)Marshal.GetObjectForIUnknown(p);
            Marshal.Release(p);
        }
        Marshal.FreeCoTaskMem(arr);
        Guid fn = FRIENDLY; IntPtr ps; int len;
        if (chosen.GetAllocatedString(ref fn, out ps, out len) >= 0) { camName = Marshal.PtrToStringUni(ps, len); Marshal.FreeCoTaskMem(ps); }
        Guid iid = IID_SOURCE; IntPtr src;
        hr = chosen.ActivateObject(ref iid, out src);
        if (hr < 0)
        {
            if (hr == unchecked((int)0x80070005))
                camErr = "Windows no deja usar la camara. Ve a Configuracion > Privacidad > Camara y activa 'Permitir que las aplicaciones de escritorio accedan a la camara'.";
            else camErr = "No se pudo abrir la camara '" + camName + "' (" + Hex(hr) + "). Cierra otras apps que la usen (Teams, Zoom...).";
            return null;
        }
        IMFAttributes ra; MFCreateAttributes(out ra, 1);
        Guid vp = VIDPROC; ra.SetUINT32(ref vp, 1);
        IMFSourceReader r;
        hr = MFCreateSourceReaderFromMediaSource(src, ra, out r);
        Marshal.Release(src); Marshal.ReleaseComObject(ra);
        if (hr < 0) { camErr = "No se pudo leer la camara (" + Hex(hr) + ")."; return null; }
        // el formato nativo mas cercano a 640 de ancho (rapido y suficiente)
        int best = -1; long bestSize = 0; double bestScore = 1e9;
        for (int i = 0; i < 400; i++)
        {
            IMFMediaType nt;
            if (r.GetNativeMediaType(FIRST_VIDEO, i, out nt) < 0 || nt == null) break;
            Guid sz = MT_SIZE; long fs;
            if (nt.GetUINT64(ref sz, out fs) >= 0)
            {
                int w = (int)(fs >> 32);
                double sc = Math.Abs(w - 640) + (w > 1280 ? 3000 : 0);
                if (sc < bestScore) { bestScore = sc; best = i; bestSize = fs; }
            }
            Marshal.ReleaseComObject(nt);
        }
        if (best >= 0)
        {
            IMFMediaType nt;
            if (r.GetNativeMediaType(FIRST_VIDEO, best, out nt) >= 0) { r.SetCurrentMediaType(FIRST_VIDEO, IntPtr.Zero, nt); Marshal.ReleaseComObject(nt); }
        }
        hr = SetRgb(r, bestSize);
        if (hr < 0) hr = SetRgb(r, 0);
        if (hr < 0) { camErr = "La camara no admite conversion a imagen RGB (" + Hex(hr) + ")."; Marshal.ReleaseComObject(r); return null; }
        return r;
    }

    static int SetRgb(IMFSourceReader r, long size)
    {
        IMFMediaType mt; MFCreateMediaType(out mt);
        Guid k1 = MT_MAJOR, v1 = VIDEO, k2 = MT_SUB, v2 = RGB32, k3 = MT_SIZE;
        mt.SetGUID(ref k1, ref v1); mt.SetGUID(ref k2, ref v2);
        if (size != 0) mt.SetUINT64(ref k3, size);
        int hr = r.SetCurrentMediaType(FIRST_VIDEO, IntPtr.Zero, mt);
        Marshal.ReleaseComObject(mt);
        return hr;
    }

    static void ReadFormat(IMFSourceReader r, out int w, out int h, out int stride)
    {
        w = 640; h = 480; stride = 0;
        IMFMediaType t;
        if (r.GetCurrentMediaType(FIRST_VIDEO, out t) < 0 || t == null) return;
        Guid sz = MT_SIZE, st = MT_STRIDE; long fs; int s;
        if (t.GetUINT64(ref sz, out fs) >= 0) { w = (int)(fs >> 32); h = (int)(fs & 0xFFFFFFFF); }
        if (t.GetUINT32(ref st, out s) >= 0) stride = s;
        Marshal.ReleaseComObject(t);
        camRes = w + "x" + h;
    }

    // ================================================================ teclado y estado
    static readonly string[] MODES = { "ASCII DETALLADO", "ASCII EN COLOR", "BOCETO A LAPIZ", "MATRIX", "ALTA DEFINICION", "BRAILLE", "NEON" };
    static int mode;
    static bool mirrorX = true, flipY, frozen, dirty = true;
    static double contrast = 1.15, bright = 0, gt, fps;
    static string note = ""; static double noteT = -10;

    static void Note(string s) { note = s; noteT = gt; dirty = true; }

    static void Keys()
    {
        try
        {
            while (Console.KeyAvailable)
            {
                ConsoleKeyInfo k = Console.ReadKey(true);
                dirty = true;
                switch (k.Key)
                {
                    case ConsoleKey.Escape: quit = true; break;
                    case ConsoleKey.RightArrow: case ConsoleKey.Tab: mode = (mode + 1) % MODES.Length; prevValid = false; break;
                    case ConsoleKey.LeftArrow: mode = (mode + MODES.Length - 1) % MODES.Length; prevValid = false; break;
                    case ConsoleKey.UpArrow: contrast = Math.Min(2.5, contrast + 0.1); Note("CONTRASTE " + (int)(contrast * 100) + "%"); break;
                    case ConsoleKey.DownArrow: contrast = Math.Max(0.5, contrast - 0.1); Note("CONTRASTE " + (int)(contrast * 100) + "%"); break;
                    case ConsoleKey.PageUp: bright = Math.Min(0.4, bright + 0.05); Note("BRILLO " + (int)(bright * 100)); break;
                    case ConsoleKey.PageDown: bright = Math.Max(-0.4, bright - 0.05); Note("BRILLO " + (int)(bright * 100)); break;
                    case ConsoleKey.M: mirrorX = !mirrorX; Note(mirrorX ? "ESPEJO ACTIVADO" : "ESPEJO DESACTIVADO"); break;
                    case ConsoleKey.V: flipY = !flipY; Note("IMAGEN VOLTEADA"); break;
                    case ConsoleKey.F: case ConsoleKey.Spacebar: frozen = !frozen; Note(frozen ? "FOTO CONGELADA (F para seguir)" : "EN DIRECTO"); break;
                    case ConsoleKey.S: Save(); break;
                    case ConsoleKey.K: camReq = camCur + 1; Note("CAMBIANDO DE CAMARA..."); break;
                    case ConsoleKey.OemPlus: case ConsoleKey.Add: Detail(-1); break;
                    case ConsoleKey.OemMinus: case ConsoleKey.Subtract: Detail(1); break;
                    default:
                        if (k.KeyChar >= '1' && k.KeyChar <= '7') { mode = k.KeyChar - '1'; prevValid = false; }
                        else if (k.KeyChar == '+') Detail(-1);
                        else if (k.KeyChar == '-') Detail(1);
                        break;
                }
            }
        }
        catch { }
    }

    static void Detail(int d)
    {
        if (!fontCtl) { Note("En Windows Terminal usa Ctrl + '-' para mas detalle (Ctrl + '+' para menos)"); return; }
        fIdx = Math.Max(0, Math.Min(FSIZES.Length - 1, fIdx + d));
        ApplyFont();
        Note("TAMANO DE LETRA " + FSIZES[fIdx] + " px");
    }

    // ================================================================ procesado de imagen
    static byte[] img; static int iw_, ih_, istride, lastId = -1;
    static int cols, rows, ox, oy, sw, sh;
    static float[] L, Rr, Gg, Bb, N, Ed, Ex, Ey, tmp; static bool prevValid;
    static double lo = 0.05, hi = 0.95;

    static bool GrabFrame()
    {
        if (frozen) return false;
        lock (fLock)
        {
            if (shId == lastId || shFrame == null) return false;
            if (img == null || img.Length < shLen) img = new byte[shLen];
            Buffer.BlockCopy(shFrame, 0, img, 0, shLen);
            iw_ = shW; ih_ = shH; istride = shStride; lastId = shId;
        }
        Process();
        return true;
    }

    static void Layout()
    {
        int areaH = H - 1;
        double asp = (double)iw_ / Math.Max(1, ih_);
        int c = W, r = (int)(c / (asp * 2));
        if (r > areaH) { r = areaH; c = (int)Math.Round(r * asp * 2); }
        c = Math.Max(4, Math.Min(W, c)); r = Math.Max(2, Math.Min(areaH, r));
        if (c != cols || r != rows) prevValid = false;
        cols = c; rows = r; ox = (W - cols) / 2; oy = (areaH - rows) / 2;
        sw = cols * 2; sh = rows * 4;
        int n = sw * sh;
        if (L == null || L.Length != n) { L = new float[n]; Rr = new float[n]; Gg = new float[n]; Bb = new float[n]; N = new float[n]; Ed = new float[n]; Ex = new float[n]; Ey = new float[n]; tmp = new float[n]; prevValid = false; }
    }

    static void Process()
    {
        if (img == null || iw_ <= 0 || ih_ <= 0) return;
        Layout();
        double fx = (double)iw_ / sw, fy = (double)ih_ / sh;
        int nu = Math.Max(1, Math.Min(3, (int)Math.Round(fx))), nv = Math.Max(1, Math.Min(3, (int)Math.Round(fy)));
        float keep = prevValid ? 0.45f : 0f;
        int st = Math.Abs(istride);
        bool bottomUp = istride < 0;
        int[] hist = new int[64];
        for (int y = 0; y < sh; y++)
            for (int x = 0; x < sw; x++)
            {
                double r = 0, g = 0, b = 0;
                for (int j = 0; j < nv; j++)
                {
                    int yy = (int)((y + (j + 0.5) / nv) * fy);
                    if (yy >= ih_) yy = ih_ - 1;
                    if (flipY) yy = ih_ - 1 - yy;
                    int row = (bottomUp ? ih_ - 1 - yy : yy) * st;
                    for (int i = 0; i < nu; i++)
                    {
                        int xx = (int)((x + (i + 0.5) / nu) * fx);
                        if (xx >= iw_) xx = iw_ - 1;
                        if (mirrorX) xx = iw_ - 1 - xx;
                        int p = row + xx * 4;
                        if (p + 2 >= img.Length) continue;
                        b += img[p]; g += img[p + 1]; r += img[p + 2];
                    }
                }
                double k = 1.0 / (255.0 * nu * nv);
                float R = (float)(r * k), G = (float)(g * k), B = (float)(b * k);
                int idx = y * sw + x;
                float l = 0.299f * R + 0.587f * G + 0.114f * B;
                // suavizado en el tiempo para que no parpadee
                L[idx] = L[idx] * keep + l * (1 - keep);
                Rr[idx] = Rr[idx] * keep + R * (1 - keep); Gg[idx] = Gg[idx] * keep + G * (1 - keep); Bb[idx] = Bb[idx] * keep + B * (1 - keep);
                hist[Math.Min(63, (int)(L[idx] * 64))]++;
            }
        prevValid = true;
        // niveles automaticos
        int tot = sw * sh, acc = 0; double nlo = 0, nhi = 1;
        for (int i = 0; i < 64; i++) { acc += hist[i]; if (acc >= tot * 0.01) { nlo = i / 64.0; break; } }
        acc = 0;
        for (int i = 63; i >= 0; i--) { acc += hist[i]; if (acc >= tot * 0.01) { nhi = (i + 1) / 64.0; break; } }
        lo += (nlo - lo) * 0.25; hi += (nhi - hi) * 0.25;
        double rng = Math.Max(0.1, hi - lo);
        for (int i = 0; i < tot; i++)
        {
            double v = (L[i] - lo) / rng;
            v = (v - 0.5) * contrast + 0.5 + bright;
            N[i] = (float)(v < 0 ? 0 : v > 1 ? 1 : v);
        }
        // mas detalle: mascara de enfoque
        for (int y = 0; y < sh; y++)
            for (int x = 0; x < sw; x++)
            {
                float s = 0; int c = 0;
                for (int dy = -1; dy <= 1; dy++)
                {
                    int yy = y + dy; if (yy < 0 || yy >= sh) continue;
                    for (int dx = -1; dx <= 1; dx++) { int xx = x + dx; if (xx < 0 || xx >= sw) continue; s += N[yy * sw + xx]; c++; }
                }
                tmp[y * sw + x] = s / c;
            }
        for (int i = 0; i < tot; i++) { float v = N[i] + 0.9f * (N[i] - tmp[i]); N[i] = v < 0 ? 0 : v > 1 ? 1 : v; }
        // bordes (Sobel)
        for (int y = 1; y < sh - 1; y++)
            for (int x = 1; x < sw - 1; x++)
            {
                int i = y * sw + x;
                float gx = (N[i - sw + 1] + 2 * N[i + 1] + N[i + sw + 1]) - (N[i - sw - 1] + 2 * N[i - 1] + N[i + sw - 1]);
                float gy = (N[i + sw - 1] + 2 * N[i + sw] + N[i + sw + 1]) - (N[i - sw - 1] + 2 * N[i - sw] + N[i - sw + 1]);
                Ex[i] = gx; Ey[i] = gy; Ed[i] = (float)Math.Sqrt(gx * gx + gy * gy) * 0.35f;
            }
    }

    // ---------------------------------------------------------------- caracteres por forma (2x4 zonas)
    const string GLY = "00000000339B562265AA000036PSTP3213PICW5880QCAS0597P3NY673355000007D6F419705E3G9123JK11000067KL00000045930000770000005522062HI29099ONON55A53H6L68C91LJB77C96N5N9509FMKS03C9MC5M948ASENL55DD0KC930AANMON66A9LMER74007755220077459300BFFF0000EEEE0000GBGF00AA2K962125NRTOD955JJRQ33D9SOOO747CM0N538E6LMON82CCRCN578BDQBL0308CM5NP4776SRLK33CCABDE776A0K6L9377XFNM3470L0N668A9YXML33A6ZMLY3499MLNM55CANPO43099MLNM5DE8PNOL33ABQ86P75GGABAB2276LKNL5576KJII2266SRUT3377IJLK4377KJAB22CF1LN77968F4F49860J13G09872G2G8955CB0000000000HG9101000000BGQU7680QIOL6600FCM53808IQMN6600HHUJ472DKHC72100IKNOEJ80PIJI3324C8BG78069C1HDB80LEPK33F1G3E80600PNPQ4400JIJI3300IHML5500KHOLJ600IKMN5J00FFJ03000HAEM7540RBH61600DDLM6600DDJI2200EEUS3300EEJI3300EDHIH400AJIA771CAAI83F34898989C29A7IF40030BE00";
    static float[] gv = new float[95 * 8], gm = new float[95];

    static void InitGlyphs()
    {
        for (int c = 0; c < 95; c++)
        {
            float s = 0;
            for (int k = 0; k < 8; k++)
            {
                char ch = GLY[c * 8 + k];
                int v = ch <= '9' ? ch - '0' : ch - 'A' + 10;
                gv[c * 8 + k] = v / 35f; s += v / 35f;
            }
            gm[c] = s / 8;
        }
        // se reescala para que el caracter mas denso valga 1 (ningun caracter llena su celda)
        float mx = 0; for (int c = 0; c < 95; c++) mx = Math.Max(mx, gm[c]);
        for (int c = 0; c < 95; c++) { gm[c] /= mx; for (int k = 0; k < 8; k++) gv[c * 8 + k] /= mx; }
        // escala de tonos para las zonas lisas, ordenada por densidad real
        System.Collections.Generic.List<int> ids = new System.Collections.Generic.List<int>();
        foreach (char ch in " .'`,:;-~^\"=+*!?<>/|()[]{}#%&8@$") ids.Add(ch - 32);
        ids.Sort(delegate(int a, int b) { return gm[a].CompareTo(gm[b]); });
        ramp = new int[ids.Count]; rampV = new float[ids.Count];
        for (int i = 0; i < ids.Count; i++) { ramp[i] = ids[i]; rampV[i] = gm[ids[i]]; }
    }
    static int[] ramp; static float[] rampV;

    static float[] dz = new float[8];

    static char Match()
    {
        float dm = 0; for (int k = 0; k < 8; k++) dm += dz[k]; dm /= 8;
        float var = 0; for (int k = 0; k < 8; k++) { float t = dz[k] - dm; var += t * t; }
        // zona lisa: caracter de la escala de tonos (sin rayas); con detalle: el de forma mas parecida
        if (var < 0.035)
        {
            int lo2 = 0, hi2 = rampV.Length - 1;
            while (lo2 < hi2) { int m = (lo2 + hi2) / 2; if (rampV[m] < dm) lo2 = m + 1; else hi2 = m; }
            if (lo2 > 0 && Math.Abs(rampV[lo2 - 1] - dm) < Math.Abs(rampV[lo2] - dm)) lo2--;
            return (char)(32 + ramp[lo2]);
        }
        int best = 0; float be = 1e9f;
        for (int c = 0; c < 95; c++)
        {
            float d0 = gm[c] - dm;
            float e = 4 * d0 * d0;
            if (e >= be) continue;
            int o = c * 8;
            for (int k = 0; k < 8 && e < be; k++) { float t = dz[k] - gv[o + k]; e += t * t; }
            if (e < be) { be = e; best = c; }
        }
        return (char)(32 + best);
    }

    static void CellInk(int cx, int cy, bool invert, float edgeW)
    {
        for (int k = 0; k < 8; k++)
        {
            int i = (cy * 4 + k / 2) * sw + cx * 2 + (k & 1);
            float v = invert ? 1 - N[i] : N[i];
            if (edgeW > 0) v = Math.Min(1, v * 0.85f + Ed[i] * edgeW);
            dz[k] = invert ? (float)Math.Pow(v, 1.9) : (float)Math.Pow(v, 1.15);
        }
    }

    static int Rgb(double r, double g, double b)
    {
        int ri = r < 0 ? 0 : r > 255 ? 255 : (int)r, gi = g < 0 ? 0 : g > 255 ? 255 : (int)g, bi = b < 0 ? 0 : b > 255 ? 255 : (int)b;
        return (ri << 16) | (gi << 8) | bi;
    }

    static void CellColor(int cx, int cy, int r0, int r1, out double r, out double g, out double b)
    {
        r = g = b = 0; int n = 0;
        double rng = Math.Max(0.1, hi - lo);
        for (int yy = cy * 4 + r0; yy <= cy * 4 + r1; yy++)
            for (int xx = cx * 2; xx < cx * 2 + 2; xx++) { int i = yy * sw + xx; r += Rr[i]; g += Gg[i]; b += Bb[i]; n++; }
        r = (r / n - lo) / rng; g = (g / n - lo) / rng; b = (b / n - lo) / rng;
        r = (r - 0.5) * contrast + 0.5 + bright; g = (g - 0.5) * contrast + 0.5 + bright; b = (b - 0.5) * contrast + 0.5 + bright;
    }

    // ---------------------------------------------------------------- dibujo en la consola
    static void Put(int x, int y, char c, int fg, int bg) { if (x < 0 || y < 0 || x >= W || y >= H) return; int i = y * W + x; cb[i] = c; cc[i] = fg; cbg[i] = bg; }
    static void Text(int x, int y, string s, int fg, int bg) { for (int i = 0; i < s.Length; i++) Put(x + i, y, s[i], fg, bg); }

    static readonly int[] BAYER = { 0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5 };

    static void Draw()
    {
        bool paper = mode == 2;
        int bgAll = paper ? Rgb(236, 230, 216) : 0;
        for (int i = 0; i < cb.Length; i++) { cb[i] = ' '; cc[i] = 0; cbg[i] = bgAll; }
        if (img == null || iw_ <= 0)
        {
            Waiting();
        }
        else
        {
            for (int cy = 0; cy < rows; cy++)
                for (int cx = 0; cx < cols; cx++)
                {
                    int X = ox + cx, Y = oy + cy;
                    switch (mode)
                    {
                        case 0:
                            CellInk(cx, cy, false, 0);
                            Put(X, Y, Match(), Rgb(235, 235, 235), 0);
                            break;
                        case 1:
                        {
                            CellInk(cx, cy, false, 0);
                            double r, g, b; CellColor(cx, cy, 0, 3, out r, out g, out b);
                            double mx = Math.Max(0.15, Math.Max(r, Math.Max(g, b))), m = (r + g + b) / 3;
                            r = m + (r - m) * 1.5; g = m + (g - m) * 1.5; b = m + (b - m) * 1.5;
                            double sc = 255 * (0.55 + 0.45 * Math.Min(1, mx)) / Math.Max(0.15, Math.Max(r, Math.Max(g, b)));
                            Put(X, Y, Match(), Rgb(r * sc, g * sc, b * sc) & 0xF0F0F0, 0);
                            break;
                        }
                        case 2:
                            CellInk(cx, cy, true, 1.1f);
                            Put(X, Y, Match(), Rgb(48, 46, 58), bgAll);
                            break;
                        case 3:
                        {
                            CellInk(cx, cy, false, 0);
                            float m = 0; for (int k = 0; k < 8; k++) m += dz[k]; m /= 8;
                            double q = Math.Round(m * 5) / 5;
                            double head = Frac(gt * (0.25 + Hash01(cx) * 0.35) + Hash01(cx + 77)) * (rows + 12) - 6;
                            double hd = cy - head;
                            int col = Rgb(10 + 30 * q, 70 + 185 * q, 30 + 50 * q);
                            if (hd > -1 && hd <= 0.5) col = Rgb(200, 255, 210);
                            else if (hd < -1 && hd > -6) col = Rgb(30 + 60 * q, 120 + 135 * q, 60 + 40 * q);
                            Put(X, Y, Match(), col, 0);
                            break;
                        }
                        case 4:
                        {
                            double r, g, b, r2, g2, b2;
                            CellColor(cx, cy, 0, 1, out r, out g, out b); CellColor(cx, cy, 2, 3, out r2, out g2, out b2);
                            int t = Rgb(r * 255, g * 255, b * 255) & 0xF8F8F8, u = Rgb(r2 * 255, g2 * 255, b2 * 255) & 0xF8F8F8;
                            if (t == u) Put(X, Y, ' ', 0, u); else Put(X, Y, UPB, t, u);
                            break;
                        }
                        case 5:
                        {
                            int bits = 0;
                            int[] map = { 0x01, 0x08, 0x02, 0x10, 0x04, 0x20, 0x40, 0x80 };
                            for (int k = 0; k < 8; k++)
                            {
                                int sx = cx * 2 + (k & 1), sy = cy * 4 + k / 2;
                                if (N[sy * sw + sx] * 16 > BAYER[(sx & 3) + (sy & 3) * 4] + 0.5) bits |= map[k];
                            }
                            Put(X, Y, (char)(0x2800 + bits), Rgb(235, 235, 235), 0);
                            break;
                        }
                        case 6:
                        {
                            float bestE = 0; int bi = 0;
                            for (int k = 0; k < 8; k++) { int i = (cy * 4 + k / 2) * sw + cx * 2 + (k & 1); if (Ed[i] > bestE) { bestE = Ed[i]; bi = i; } }
                            if (bestE > 0.22)
                            {
                                double a = Math.Atan2(Ey[bi], Ex[bi]) * 180 / Math.PI; if (a < 0) a += 180;
                                char ch = a < 22.5 || a >= 157.5 ? '|' : a < 67.5 ? '/' : a < 112.5 ? '-' : '\\';
                                int[] pal = { Rgb(0, 255, 255), Rgb(255, 60, 220), Rgb(255, 230, 40), Rgb(80, 255, 120) };
                                int ci = ch == '|' ? 0 : ch == '/' ? 1 : ch == '-' ? 2 : 3;
                                double f = Math.Min(1, 0.35 + bestE);
                                int pc = pal[ci];
                                Put(X, Y, ch, Rgb(((pc >> 16) & 255) * f, ((pc >> 8) & 255) * f, (pc & 255) * f) & 0xE0E0E0, 0);
                            }
                            else
                            {
                                float m = 0; for (int k = 0; k < 8; k++) m += N[(cy * 4 + k / 2) * sw + cx * 2 + (k & 1)]; m /= 8;
                                if (m > 0.55) Put(X, Y, m > 0.8 ? ':' : '.', Rgb(30, 40, 90), 0);
                            }
                            break;
                        }
                    }
                }
        }
        Status();
    }

    static double Frac(double v) { return v - Math.Floor(v); }
    static double Hash01(int x) { unchecked { uint h = (uint)(x * 374761393 + 668265263); h = (h ^ (h >> 13)) * 1274126177u; h ^= h >> 16; return (h & 0xFFFF) / 65536.0; } }

    static void Waiting()
    {
        string err = camErr;
        int y = H / 2 - 3;
        string title = "CAMARA ASCII";
        Text((W - title.Length) / 2, y, title, Rgb(0, 230, 255), 0);
        if (err.Length == 0)
        {
            string s = "Abriendo la camara " + "|/-\\"[(int)(gt * 8) % 4];
            Text((W - s.Length) / 2, y + 2, s, Rgb(235, 235, 235), 0);
            string h2 = "(si Windows pregunta, deja que la app use la camara)";
            Text((W - h2.Length) / 2, y + 4, h2, Rgb(150, 150, 165), 0);
        }
        else
        {
            int line = 0;
            foreach (string part in Wrap(err, Math.Min(W - 4, 76)))
            {
                Text((W - part.Length) / 2, y + 2 + line, part, Rgb(255, 120, 100), 0);
                line++;
            }
            string h2 = camCount > 1 ? "K: probar otra camara     ESC: salir" : "ESC: salir";
            Text((W - h2.Length) / 2, y + 3 + line, h2, Rgb(150, 150, 165), 0);
        }
    }

    static System.Collections.Generic.List<string> Wrap(string s, int w)
    {
        System.Collections.Generic.List<string> r = new System.Collections.Generic.List<string>();
        string cur = "";
        foreach (string word in s.Split(' '))
        {
            if (cur.Length + word.Length + 1 > w && cur.Length > 0) { r.Add(cur); cur = ""; }
            cur = cur.Length == 0 ? word : cur + " " + word;
        }
        if (cur.Length > 0) r.Add(cur);
        return r;
    }

    static void Status()
    {
        int y = H - 1, bg = Rgb(22, 22, 34);
        for (int x = 0; x < W; x++) Put(x, y, ' ', 0, bg);
        string left = " " + (mode + 1) + "/" + MODES.Length + " " + MODES[mode] + (frozen ? "  [FOTO]" : "") + "  ";
        Text(0, y, left, Rgb(0, 230, 255), bg);
        string info;
        if (gt - noteT < 2.5 && note.Length > 0) info = note;
        else info = "\u2190 \u2192 modo  \u2191 \u2193 contraste  M espejo  F foto  S guardar  K camara  +/- detalle  ESC salir";
        Text(left.Length, y, info, gt - noteT < 2.5 ? Rgb(255, 215, 0) : Rgb(175, 175, 190), bg);
        string right = " " + (int)Math.Round(fps) + " fps  " + camRes + " ";
        if (mode == 5 && !fontCtl) right = " braille: usa Windows Terminal " + right;
        if (left.Length + info.Length + right.Length < W) Text(W - right.Length, y, right, Rgb(120, 200, 120), bg);
    }

    // ---------------------------------------------------------------- guardar como texto
    static void Save()
    {
        if (img == null) { Note("TODAVIA NO HAY IMAGEN"); return; }
        try
        {
            StringBuilder t = new StringBuilder();
            for (int cy = 0; cy < rows; cy++)
            {
                for (int cx = 0; cx < cols; cx++) { CellInk(cx, cy, true, 0.6f); t.Append(Match()); }
                t.Append("\r\n");
            }
            string dir = Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory);
            if (string.IsNullOrEmpty(dir) || !Directory.Exists(dir)) dir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
            string path = Path.Combine(dir, "camara_ascii_" + DateTime.Now.ToString("yyyyMMdd_HHmmss", CultureInfo.InvariantCulture) + ".txt");
            File.WriteAllText(path, t.ToString(), new UTF8Encoding(false));
            Note("GUARDADO: " + path);
        }
        catch (Exception ex) { Note("NO SE PUDO GUARDAR: " + ex.Message); }
    }

    // ---------------------------------------------------------------- salida
    static void Out(string s)
    {
        if (testing) return;
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
                int i = y * W + x, b = cbg[i], f = cc[i];
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
}
'@
try {
    Add-Type -TypeDefinition $code -Language CSharp
} catch {
    Write-Host ""
    Write-Host "  Error compilando el programa:" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    exit 1
}
[CamAscii]::Run()
exit 0
