<# : -------- parte BATCH (PowerShell la ve como un comentario) --------
@echo off
setlocal
title CABEZA 3D
color 0F
cls
echo.
echo   [*] CABEZA 3D - una cabeza que imita tus gestos con la camara
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
# -------- parte POWERSHELL: compila y lanza el programa --------
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

public static class Cabeza3D
{
    // ================================================================ consola
    [DllImport("kernel32.dll")] static extern IntPtr GetStdHandle(int n);
    [DllImport("kernel32.dll")] static extern bool GetConsoleMode(IntPtr h, out uint m);
    [DllImport("kernel32.dll")] static extern bool SetConsoleMode(IntPtr h, uint m);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    static extern bool WriteConsoleW(IntPtr h, string s, int n, out int w, IntPtr r);
    [DllImport("kernel32.dll")] static extern bool FlushConsoleInputBuffer(IntPtr h);
    [DllImport("user32.dll")] static extern short GetAsyncKeyState(int vk);
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
    static int W = 120, H = 40, PW = 120, PH = 80;
    static int[] pix; static char[] cb, pcb; static int[] cc, cbg, pcc, pcbg; static bool fullDraw = true;
    static StringBuilder sb = new StringBuilder(1 << 18);
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

    // ================================================================ captura de la camara (hilo aparte)
    static volatile bool capRun = true;
    public static volatile int camReq = 0, camCur = -1, camCount = 0;
    public static volatile string camName = "", camErr = "", camRes = "";
    static readonly object fLock = new object();
    static byte[] shFrame; static int shLen, shW, shH, shStride; static volatile int shId;

    static string Hex(int hr) { return "0x" + hr.ToString("X8"); }

    static void CapThread()
    {
        int hr;
        try { hr = MFStartup(0x20070, 0); } catch (Exception ex) { camErr = "Media Foundation no disponible: " + ex.Message; return; }
        if (hr < 0) { camErr = "No se pudo iniciar Media Foundation (" + Hex(hr) + ")."; return; }
        while (capRun)
        {
            int want = camReq;
            IMFActivate act = null; IMFSourceReader reader = null;
            try { reader = Open(want, out act); }
            catch (Exception ex) { camErr = "Error al abrir la camara: " + ex.Message; }
            if (reader == null) { for (int k = 0; k < 40 && capRun && camReq == want; k++) Thread.Sleep(50); continue; }
            camCur = want; camErr = "";
            int w = 0, h = 0, stride = 0;
            ReadFormat(reader, out w, out h, out stride);
            while (capRun && camReq == want)
            {
                int ai, fl; long ts; IMFSample s;
                hr = reader.ReadSample(FIRST_VIDEO, 0, out ai, out fl, out ts, out s);
                if (hr < 0) { camErr = "Se ha perdido la camara (" + Hex(hr) + ")."; break; }
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
        if (n == 0) { camErr = "No se ha encontrado ninguna camara."; Marshal.FreeCoTaskMem(arr); return null; }
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
            if (hr == unchecked((int)0x80070005)) camErr = "Windows no deja usar la camara: Configuracion > Privacidad > Camara > permitir a las aplicaciones de escritorio.";
            else camErr = "No se pudo abrir la camara (" + Hex(hr) + "). Cierra otras apps que la usen.";
            return null;
        }
        IMFAttributes ra; MFCreateAttributes(out ra, 1);
        Guid vp = VIDPROC; ra.SetUINT32(ref vp, 1);
        IMFSourceReader r;
        hr = MFCreateSourceReaderFromMediaSource(src, ra, out r);
        Marshal.Release(src); Marshal.ReleaseComObject(ra);
        if (hr < 0) { camErr = "No se pudo leer la camara (" + Hex(hr) + ")."; return null; }
        int best = -1; long bestSize = 0; double bestScore = 1e9;
        for (int i = 0; i < 400; i++)
        {
            IMFMediaType nt;
            if (r.GetNativeMediaType(FIRST_VIDEO, i, out nt) < 0 || nt == null) break;
            Guid sz = MT_SIZE; long fs;
            if (nt.GetUINT64(ref sz, out fs) >= 0)
            {
                int w = (int)(fs >> 32);
                double sc = Math.Abs(w - 640) + (w > 1280 ? 3000 : 0) + (w < 320 ? 500 : 0);
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
        if (hr < 0) { camErr = "La camara no admite imagen RGB (" + Hex(hr) + ")."; Marshal.ReleaseComObject(r); return null; }
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
    // ================================================================ matematicas
    public struct V
    {
        public float x, y, z;
        public V(float a, float b, float c) { x = a; y = b; z = c; }
        public V(double a, double b, double c) { x = (float)a; y = (float)b; z = (float)c; }
        public static V operator +(V a, V b) { return new V(a.x + b.x, a.y + b.y, a.z + b.z); }
        public static V operator -(V a, V b) { return new V(a.x - b.x, a.y - b.y, a.z - b.z); }
        public static V operator -(V a) { return new V(-a.x, -a.y, -a.z); }
        public static V operator *(V a, float s) { return new V(a.x * s, a.y * s, a.z * s); }
        public static V operator *(float s, V a) { return new V(a.x * s, a.y * s, a.z * s); }
        public float Len() { return (float)Math.Sqrt(x * x + y * y + z * z); }
        public V Norm() { float l = Len(); return l > 1e-9f ? new V(x / l, y / l, z / l) : new V(0, 1, 0); }
    }
    static float Dot(V a, V b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
    static V Cross(V a, V b) { return new V(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x); }
    static V Mul(V a, V b) { return new V(a.x * b.x, a.y * b.y, a.z * b.z); }
    static V LerpV(V a, V b, float t) { return new V(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t); }
    static V C3(int r, int g, int b) { return new V(r / 255f, g / 255f, b / 255f); }
    static float Sat(float v) { return v < 0 ? 0 : v > 1 ? 1 : v; }
    static float Clampf(float v, float a, float b) { return v < a ? a : v > b ? b : v; }
    static float Lf(float a, float b, float t) { return a + (b - a) * t; }
    static float SStep(float a, float b, float x) { float t = Sat((x - a) / (b - a)); return t * t * (3 - 2 * t); }
    static float Fr(float v) { return v - (float)Math.Floor(v); }
    static float Hash(int x, int y, int s)
    {
        unchecked
        {
            uint h = (uint)(x * 374761393 + y * 668265263 + s * 982451653);
            h = (h ^ (h >> 13)) * 1274126177u; h ^= h >> 16;
            return (h & 0xFFFFFF) / 16777216f;
        }
    }
    static float Noise(float x, float y, int s)
    {
        int xi = (int)Math.Floor(x), yi = (int)Math.Floor(y); float fx = x - xi, fy = y - yi;
        fx = fx * fx * (3 - 2 * fx); fy = fy * fy * (3 - 2 * fy);
        return Lf(Lf(Hash(xi, yi, s), Hash(xi + 1, yi, s), fx), Lf(Hash(xi, yi + 1, s), Hash(xi + 1, yi + 1, s), fx), fy);
    }

    // transformacion afin: origen + tres ejes
    public struct Tf
    {
        public V o, X, Y, Z;
        public static Tf Id() { Tf t; t.o = new V(0, 0, 0); t.X = new V(1, 0, 0); t.Y = new V(0, 1, 0); t.Z = new V(0, 0, 1); return t; }
        public V P(V v) { return o + X * v.x + Y * v.y + Z * v.z; }
        public V D(V v) { return X * v.x + Y * v.y + Z * v.z; }
        public Tf Mul(Tf c) { Tf r; r.o = P(c.o); r.X = D(c.X); r.Y = D(c.Y); r.Z = D(c.Z); return r; }
        public static Tf T(V p) { Tf t = Id(); t.o = p; return t; }
        public static Tf T(float x, float y, float z) { return T(new V(x, y, z)); }
        public static Tf Rx(float a) { Tf t = Id(); float c = (float)Math.Cos(a), s = (float)Math.Sin(a); t.Y = new V(0, c, s); t.Z = new V(0, -s, c); return t; }
        public static Tf Ry(float a) { Tf t = Id(); float c = (float)Math.Cos(a), s = (float)Math.Sin(a); t.X = new V(c, 0, -s); t.Z = new V(s, 0, c); return t; }
        public static Tf Rz(float a) { Tf t = Id(); float c = (float)Math.Cos(a), s = (float)Math.Sin(a); t.X = new V(c, s, 0); t.Y = new V(-s, c, 0); return t; }
        // ejes con Y a lo largo de un segmento
        public static Tf Seg(V a, V b, V hint)
        {
            V y = (b - a).Norm();
            V x = Cross(y, hint);
            if (x.Len() < 1e-4f) x = Cross(y, new V(0.3f, 0.1f, 1));
            x = x.Norm(); V z = Cross(x, y);
            Tf t; t.o = a; t.X = x; t.Y = y; t.Z = z; return t;
        }
        public static Tf Basis(V o, V x, V y, V z) { Tf t; t.o = o; t.X = x; t.Y = y; t.Z = z; return t; }
    }

    // ================================================================ mallas
    public class Mesh { public V[] p, n; public float[] u, v; public int[] t; public int mat; }

    class MB
    {
        public List<V> P = new List<V>(), N = new List<V>(); public List<float> U = new List<float>(), Vv = new List<float>(); public List<int> T = new List<int>();
        public int Add(V p, V n, float u, float v) { P.Add(p); N.Add(n); U.Add(u); Vv.Add(v); return P.Count - 1; }
        public void Tri(int a, int b, int c) { T.Add(a); T.Add(b); T.Add(c); }
        public void Quad(int a, int b, int c, int d) { Tri(a, b, c); Tri(a, c, d); }
        public Mesh Done(int mat) { Mesh m = new Mesh(); m.p = P.ToArray(); m.n = N.ToArray(); m.u = U.ToArray(); m.v = Vv.ToArray(); m.t = T.ToArray(); m.mat = mat; return m; }
    }

    static void Face(MB b, V n, V a, V c1, V c2, V c3)
    {
        int i0 = b.Add(a, n, 0, 1), i1 = b.Add(c1, n, 0, 0), i2 = b.Add(c2, n, 1, 0), i3 = b.Add(c3, n, 1, 1);
        b.Quad(i0, i1, i2, i3);
    }

    static Mesh MBox(float w, float h, float d, int mat)
    {
        MB b = new MB(); float x = w / 2, y = h / 2, z = d / 2;
        Face(b, new V(1, 0, 0), new V(x, -y, -z), new V(x, y, -z), new V(x, y, z), new V(x, -y, z));
        Face(b, new V(-1, 0, 0), new V(-x, -y, z), new V(-x, y, z), new V(-x, y, -z), new V(-x, -y, -z));
        Face(b, new V(0, 1, 0), new V(-x, y, z), new V(-x, y, -z), new V(x, y, -z), new V(x, y, z));
        Face(b, new V(0, -1, 0), new V(-x, -y, -z), new V(-x, -y, z), new V(x, -y, z), new V(x, -y, -z));
        Face(b, new V(0, 0, 1), new V(x, -y, z), new V(x, y, z), new V(-x, y, z), new V(-x, -y, z));
        Face(b, new V(0, 0, -1), new V(-x, -y, -z), new V(-x, y, -z), new V(x, y, -z), new V(x, -y, -z));
        return b.Done(mat);
    }

    // caja con aristas redondeadas (caras planas exactas)
    static Mesh MRBox(float w, float h, float d, float r, int mat)
    {
        int q = 3;
        r = Math.Min(r, Math.Min(w, Math.Min(h, d)) * 0.49f);
        float hx = w / 2 - r, hy = h / 2 - r, hz = d / 2 - r;
        List<float> ta = new List<float>(); List<int> ts = new List<int>();
        for (int k = 0; k <= q; k++) { ta.Add((float)(Math.PI / 2 * k / q)); ts.Add(1); }
        for (int k = 0; k <= q; k++) { ta.Add((float)(Math.PI / 2 + Math.PI / 2 * k / q)); ts.Add(-1); }
        List<float> pa = new List<float>(); List<int> pq = new List<int>();
        for (int qd = 0; qd < 4; qd++) for (int k = 0; k <= q; k++) { pa.Add((float)(qd * Math.PI / 2 + Math.PI / 2 * k / q)); pq.Add(qd); }
        MB b = new MB();
        int cols = pa.Count;
        for (int i = 0; i < ta.Count; i++)
            for (int j = 0; j < cols; j++)
            {
                float t = ta[i], p = pa[j];
                V dn = new V(Math.Sin(t) * Math.Cos(p), Math.Cos(t), Math.Sin(t) * Math.Sin(p));
                int qd = pq[j];
                float sx = (qd == 0 || qd == 3) ? 1 : -1, sz = (qd == 0 || qd == 1) ? 1 : -1, sy = ts[i];
                V pos = new V(sx * hx + dn.x * r, sy * hy + dn.y * r, sz * hz + dn.z * r);
                b.Add(pos, dn, (float)j / cols, (float)i / (ta.Count - 1));
            }
        for (int i = 0; i < ta.Count - 1; i++)
            for (int j = 0; j < cols; j++)
            {
                int j2 = (j + 1) % cols;
                b.Quad(i * cols + j, (i + 1) * cols + j, (i + 1) * cols + j2, i * cols + j2);
            }
        return b.Done(mat);
    }

    // tronco de cono (o cilindro) de y=0 a y=h
    static Mesh MCyl(float r0, float r1, float h, int seg, int mat, bool capB, bool capT)
    {
        MB b = new MB();
        float slope = (r0 - r1) / h;
        for (int i = 0; i <= seg; i++)
        {
            float a = (float)(Math.PI * 2 * i / seg), c = (float)Math.Cos(a), s = (float)Math.Sin(a);
            V n = new V(c, slope, s).Norm();
            b.Add(new V(c * r0, 0, s * r0), n, (float)i / seg, 1);
            b.Add(new V(c * r1, h, s * r1), n, (float)i / seg, 0);
        }
        for (int i = 0; i < seg; i++) b.Quad(i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2);
        if (capB)
        {
            int c0 = b.Add(new V(0, 0, 0), new V(0, -1, 0), 0.5f, 0.5f);
            for (int i = 0; i <= seg; i++) { float a = (float)(Math.PI * 2 * i / seg); b.Add(new V(Math.Cos(a) * r0, 0, Math.Sin(a) * r0), new V(0, -1, 0), 0.5f + 0.5f * (float)Math.Cos(a), 0.5f + 0.5f * (float)Math.Sin(a)); }
            for (int i = 0; i < seg; i++) b.Tri(c0, c0 + 1 + i, c0 + 2 + i);
        }
        if (capT)
        {
            int c0 = b.Add(new V(0, h, 0), new V(0, 1, 0), 0.5f, 0.5f);
            for (int i = 0; i <= seg; i++) { float a = (float)(Math.PI * 2 * i / seg); b.Add(new V(Math.Cos(a) * r1, h, Math.Sin(a) * r1), new V(0, 1, 0), 0.5f + 0.5f * (float)Math.Cos(a), 0.5f - 0.5f * (float)Math.Sin(a)); }
            for (int i = 0; i < seg; i++) b.Tri(c0, c0 + 1 + i, c0 + 2 + i);
        }
        return b.Done(mat);
    }

    static Mesh MSphere(float rx, float ry, float rz, int rings, int segs, int mat)
    {
        MB b = new MB();
        for (int i = 0; i <= rings; i++)
        {
            double t = Math.PI * i / rings;
            for (int j = 0; j <= segs; j++)
            {
                double p = Math.PI * 2 * j / segs;
                V d = new V(Math.Sin(t) * Math.Cos(p), Math.Cos(t), Math.Sin(t) * Math.Sin(p));
                b.Add(new V(d.x * rx, d.y * ry, d.z * rz), new V(d.x / rx, d.y / ry, d.z / rz).Norm(), (float)j / segs, (float)i / rings);
            }
        }
        for (int i = 0; i < rings; i++)
            for (int j = 0; j < segs; j++) { int a = i * (segs + 1) + j; b.Quad(a, a + segs + 1, a + segs + 2, a + 1); }
        return b.Done(mat);
    }

    // capsula a lo largo de Y, de 0 a len
    static Mesh MCapsule(float r, float len, int mat)
    {
        MB b = new MB();
        int segs = 10, half = 4;
        int rows = 0;
        for (int part = 0; part < 2; part++)
            for (int i = 0; i <= half; i++)
            {
                double t = part == 0 ? Math.PI / 2 * i / half : Math.PI / 2 + Math.PI / 2 * i / half;
                float cy = part == 0 ? len : 0;
                for (int j = 0; j <= segs; j++)
                {
                    double p = Math.PI * 2 * j / segs;
                    V d = new V(Math.Sin(t) * Math.Cos(p), Math.Cos(t), Math.Sin(t) * Math.Sin(p));
                    b.Add(new V(d.x * r, cy + d.y * r, d.z * r), d, (float)j / segs, (float)rows / (2 * half + 1));
                }
                rows++;
            }
        for (int i = 0; i < rows - 1; i++)
            for (int j = 0; j < segs; j++) { int a = i * (segs + 1) + j; b.Quad(a, a + segs + 1, a + segs + 2, a + 1); }
        return b.Done(mat);
    }

    static Mesh MTorus(float R, float r, int s1, int s2, int mat)
    {
        MB b = new MB();
        for (int i = 0; i <= s1; i++)
        {
            double a = Math.PI * 2 * i / s1;
            for (int j = 0; j <= s2; j++)
            {
                double c = Math.PI * 2 * j / s2;
                V n = new V(Math.Cos(a) * Math.Cos(c), Math.Sin(c), Math.Sin(a) * Math.Cos(c));
                b.Add(new V(Math.Cos(a) * (R + r * Math.Cos(c)), r * Math.Sin(c), Math.Sin(a) * (R + r * Math.Cos(c))), n, (float)i / s1, (float)j / s2);
            }
        }
        for (int i = 0; i < s1; i++) for (int j = 0; j < s2; j++) { int a = i * (s2 + 1) + j; b.Quad(a, a + s2 + 1, a + s2 + 2, a + 1); }
        return b.Done(mat);
    }

    // rectangulo en el plano XY mirando a -Z (u hacia +X, v hacia abajo)
    static Mesh MQuad(float w, float h, int mat)
    {
        MB b = new MB(); float x = w / 2, y = h / 2; V n = new V(0, 0, -1);
        int a = b.Add(new V(-x, -y, 0), n, 0, 1), c1 = b.Add(new V(-x, y, 0), n, 0, 0), c2 = b.Add(new V(x, y, 0), n, 1, 0), c3 = b.Add(new V(x, -y, 0), n, 1, 1);
        b.Quad(a, c1, c2, c3);
        return b.Done(mat);
    }

    // plano horizontal (XZ) mirando arriba, subdividido para la luz
    static Mesh MPlane(float w, float d, int nx, int nz, int mat)
    {
        MB b = new MB(); V n = new V(0, 1, 0);
        for (int i = 0; i <= nz; i++) for (int j = 0; j <= nx; j++) b.Add(new V(-w / 2 + w * j / nx, 0, -d / 2 + d * i / nz), n, (float)j / nx, (float)i / nz);
        for (int i = 0; i < nz; i++) for (int j = 0; j < nx; j++) { int a = i * (nx + 1) + j; b.Quad(a, a + nx + 1, a + nx + 2, a + 1); }
        return b.Done(mat);
    }

    public class Inst { public V tint = new V(1, 1, 1); public V gaze = new V(0, 0, -1); public int tag; }
    static readonly Inst DEF = new Inst();

    // ================================================================ rasterizador (z-buffer + buffer de visibilidad)
    static int RW, RH;
    static float[] zbuf, bA, bB; static int[] tidb;
    static V[] fP = new V[1 << 16], fN = new V[1 << 16]; static float[] fU = new float[1 << 16], fVv = new float[1 << 16];
    static float[] csx = new float[1 << 16], csy = new float[1 << 16], csz = new float[1 << 16];
    static int nV;
    static int[] tA = new int[1 << 16], tB = new int[1 << 16], tC = new int[1 << 16], tM = new int[1 << 16], tI = new int[1 << 16];
    static int nT;
    static Inst[] insts = new Inst[8192]; static int nInst;
    static V camPos, camF, camR, camU; static float focal;
    const float NEAR = 0.04f;

    static void Grow()
    {
        if (nV + 4096 >= fP.Length)
        {
            int n = fP.Length * 2;
            Array.Resize(ref fP, n); Array.Resize(ref fN, n); Array.Resize(ref fU, n); Array.Resize(ref fVv, n);
            Array.Resize(ref csx, n); Array.Resize(ref csy, n); Array.Resize(ref csz, n);
        }
        if (nT + 8192 >= tA.Length)
        {
            int n = tA.Length * 2;
            Array.Resize(ref tA, n); Array.Resize(ref tB, n); Array.Resize(ref tC, n); Array.Resize(ref tM, n); Array.Resize(ref tI, n);
        }
        if (nInst + 4 >= insts.Length) Array.Resize(ref insts, insts.Length * 2);
    }

    static void Draw(Mesh m, Tf tf, Inst ins)
    {
        Grow();
        int ii = nInst++; insts[ii] = ins ?? DEF;
        int b = nV;
        for (int i = 0; i < m.p.Length; i++)
        {
            fP[b + i] = tf.P(m.p[i]); fN[b + i] = tf.D(m.n[i]); fU[b + i] = m.u[i]; fVv[b + i] = m.v[i];
        }
        for (int k = 0; k < m.t.Length; k += 3)
        {
            tA[nT] = b + m.t[k]; tB[nT] = b + m.t[k + 1]; tC[nT] = b + m.t[k + 2]; tM[nT] = m.mat; tI[nT] = ii; nT++;
        }
        nV += m.p.Length;
    }
    static void Draw(Mesh m, Tf tf) { Draw(m, tf, null); }

    static void BeginFrame() { nV = 0; nT = 0; nInst = 0; }

    static void RasterAll()
    {
        camF = (camTarget - camPos).Norm(); camR = Cross(new V(0, 1, 0), camF).Norm(); camU = Cross(camF, camR);
        focal = (float)(RW * 0.5 / Math.Tan(camFov * 0.5));
        for (int i = 0; i < nV; i++)
        {
            V d = fP[i] - camPos;
            csx[i] = Dot(d, camR); csy[i] = Dot(d, camU); csz[i] = Dot(d, camF);
        }
        int n = RW * RH;
        for (int i = 0; i < n; i++) { zbuf[i] = 0; tidb[i] = -1; }
        for (int t = 0; t < nT; t++) RasterTri(t);
    }

    static float[] cpx = new float[8], cpy = new float[8], cpz = new float[8], cl1 = new float[8], cl2 = new float[8];
    static float[] qx = new float[8], qy = new float[8], qz = new float[8], q1 = new float[8], q2 = new float[8];

    static void RasterTri(int t)
    {
        int a = tA[t], b = tB[t], c = tC[t];
        float za = csz[a], zb = csz[b], zc = csz[c];
        if (za < NEAR && zb < NEAR && zc < NEAR) return;
        if (!matTwo[tM[t]])
        {
            V nn = fN[a] + fN[b] + fN[c];
            V toc = camPos - fP[a];
            if (Dot(nn, toc) < -0.08f * nn.Len() * toc.Len()) return;
        }
        // recorte contra el plano cercano (guardando baricentricas respecto al triangulo original)
        cpx[0] = csx[a]; cpy[0] = csy[a]; cpz[0] = za; cl1[0] = 0; cl2[0] = 0;
        cpx[1] = csx[b]; cpy[1] = csy[b]; cpz[1] = zb; cl1[1] = 1; cl2[1] = 0;
        cpx[2] = csx[c]; cpy[2] = csy[c]; cpz[2] = zc; cl1[2] = 0; cl2[2] = 1;
        int n = 3;
        if (za < NEAR || zb < NEAR || zc < NEAR)
        {
            int m = 0;
            for (int i = 0; i < n; i++)
            {
                int j = (i + 1) % n;
                bool ii = cpz[i] >= NEAR, jj = cpz[j] >= NEAR;
                if (ii) { qx[m] = cpx[i]; qy[m] = cpy[i]; qz[m] = cpz[i]; q1[m] = cl1[i]; q2[m] = cl2[i]; m++; }
                if (ii != jj)
                {
                    float k = (NEAR - cpz[i]) / (cpz[j] - cpz[i]);
                    qx[m] = Lf(cpx[i], cpx[j], k); qy[m] = Lf(cpy[i], cpy[j], k); qz[m] = NEAR; q1[m] = Lf(cl1[i], cl1[j], k); q2[m] = Lf(cl2[i], cl2[j], k); m++;
                }
            }
            for (int i = 0; i < m; i++) { cpx[i] = qx[i]; cpy[i] = qy[i]; cpz[i] = qz[i]; cl1[i] = q1[i]; cl2[i] = q2[i]; }
            n = m;
        }
        for (int i = 1; i + 1 < n; i++) RasterSub(t, 0, i, i + 1);
    }

    static void RasterSub(int t, int i0, int i1, int i2)
    {
        float hw = RW * 0.5f, hh = RH * 0.5f;
        float x0 = hw + cpx[i0] * focal / cpz[i0], y0 = hh - cpy[i0] * focal / cpz[i0];
        float x1 = hw + cpx[i1] * focal / cpz[i1], y1 = hh - cpy[i1] * focal / cpz[i1];
        float x2 = hw + cpx[i2] * focal / cpz[i2], y2 = hh - cpy[i2] * focal / cpz[i2];
        float area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0);
        if (area > -1e-6f && area < 1e-6f) return;
        float ia = 1f / area;
        int minx = Math.Max(0, (int)Math.Floor(Math.Min(x0, Math.Min(x1, x2)))), maxx = Math.Min(RW - 1, (int)Math.Ceiling(Math.Max(x0, Math.Max(x1, x2))));
        int miny = Math.Max(0, (int)Math.Floor(Math.Min(y0, Math.Min(y1, y2)))), maxy = Math.Min(RH - 1, (int)Math.Ceiling(Math.Max(y0, Math.Max(y1, y2))));
        if (minx > maxx || miny > maxy) return;
        float iz0 = 1f / cpz[i0], iz1 = 1f / cpz[i1], iz2 = 1f / cpz[i2];
        float a1 = cl1[i0], a2 = cl1[i1], a3 = cl1[i2], c1 = cl2[i0], c2 = cl2[i1], c3 = cl2[i2];
        for (int py = miny; py <= maxy; py++)
        {
            float fy = py + 0.5f;
            int row = py * RW;
            for (int px = minx; px <= maxx; px++)
            {
                float fx = px + 0.5f;
                float w0 = ((x1 - fx) * (y2 - fy) - (x2 - fx) * (y1 - fy)) * ia;
                if (w0 < 0) continue;
                float w1 = ((x2 - fx) * (y0 - fy) - (x0 - fx) * (y2 - fy)) * ia;
                if (w1 < 0) continue;
                float w2 = 1 - w0 - w1;
                if (w2 < 0) continue;
                float zi = w0 * iz0 + w1 * iz1 + w2 * iz2;
                int idx = row + px;
                if (zi <= zbuf[idx]) continue;
                float p0 = w0 * iz0 / zi, p1 = w1 * iz1 / zi, p2 = w2 * iz2 / zi;
                zbuf[idx] = zi; tidb[idx] = t;
                bA[idx] = p0 * a1 + p1 * a2 + p2 * a3; bB[idx] = p0 * c1 + p1 * c2 + p2 * c3;
            }
        }
    }

    // ================================================================ la cabeza 3D
    const int M_FACE = 0, M_EYE = 1, M_LID = 2, M_BROW = 3, M_HAIR = 4, M_SKIN = 5, M_SHIRT = 6, M_LASH = 7, M_EARIN = 8, NMAT = 9;
    static bool[] matTwo = new bool[NMAT];
    const float RX = 0.78f, RY = 1.0f, RZ = 0.86f, MOUTHY = -0.47f, MW = 0.2f, SLIT = 0.006f;
    static readonly V EYEL = new V(-0.3f, 0.115f, -0.64f), EYER = new V(0.3f, 0.115f, -0.64f);
    const float EYER_R = 0.132f;
    static readonly V PIVOT = new V(0, -0.72f, 0.1f);

    // expresion actual (la mueve el seguimiento de la cara)
    static float pYaw, pPitch, pRoll, pX, pY, pZ, pJaw, pSmile, pBrowL, pBrowR, pEyeL = 1, pEyeR = 1, pGazeX, pGazeY;

    // estilos: piel, pelo, ojos, labios, camiseta, fondo
    class Style { public string name; public V skin, hair, iris, lip, shirt, bg1, bg2; public bool freckles; }
    static List<Style> styles = new List<Style>();
    static int styleIdx;
    static Style ST { get { return styles[styleIdx]; } }
    static void InitStyles()
    {
        Style a = new Style(); a.name = "CLASICO"; a.skin = C3(230, 168, 128); a.hair = C3(70, 44, 28); a.iris = C3(70, 120, 60); a.lip = C3(196, 104, 100); a.shirt = C3(40, 90, 160); a.bg1 = C3(40, 70, 90); a.bg2 = C3(8, 12, 20); styles.Add(a);
        Style b = new Style(); b.name = "PELIRROJO"; b.skin = C3(240, 190, 156); b.hair = C3(170, 70, 30); b.iris = C3(60, 110, 170); b.lip = C3(210, 110, 110); b.shirt = C3(50, 130, 80); b.bg1 = C3(90, 60, 40); b.bg2 = C3(16, 10, 8); b.freckles = true; styles.Add(b);
        Style c = new Style(); c.name = "MORENO"; c.skin = C3(150, 100, 70); c.hair = C3(20, 16, 14); c.iris = C3(90, 56, 30); c.lip = C3(130, 70, 66); c.shirt = C3(200, 60, 50); c.bg1 = C3(70, 40, 90); c.bg2 = C3(10, 6, 18); styles.Add(c);
        Style d = new Style(); d.name = "RUBIO"; d.skin = C3(236, 180, 146); d.hair = C3(220, 180, 100); d.iris = C3(80, 140, 200); d.lip = C3(204, 112, 112); d.shirt = C3(240, 240, 235); d.bg1 = C3(40, 90, 80); d.bg2 = C3(6, 16, 14); styles.Add(d);
        Style e = new Style(); e.name = "ALIEN"; e.skin = C3(120, 210, 140); e.hair = C3(40, 60, 70); e.iris = C3(20, 20, 20); e.lip = C3(70, 140, 100); e.shirt = C3(80, 60, 140); e.bg1 = C3(20, 40, 70); e.bg2 = C3(2, 4, 12); styles.Add(e);
    }

    static float G2(float x, float y) { return (float)Math.Exp(-(x * x + y * y)); }

    // forma base de la cabeza (sin expresiones). d = direccion de la esfera unidad
    static V HeadShape(V d)
    {
        float x = d.x * RX, y = d.y * RY, z = d.z * RZ;
        float fr = SStep(0.1f, -0.6f, d.z);
        float s = 1 - 0.24f * SStep(-0.2f, -0.95f, d.y);              // mandibula mas estrecha
        x *= s; if (z > 0) z *= 0.9f + 0.1f * s;
        if (z > 0) z *= 1 + 0.06f * SStep(-0.1f, 0.7f, d.y);           // craneo
        float ax = Math.Abs(x);
        z -= fr * 0.07f * G2(x / 0.2f, (y + 0.86f) / 0.12f);           // barbilla
        z -= fr * 0.035f * G2((ax - 0.38f) / 0.12f, (y + 0.05f) / 0.12f); // pomulos
        z += fr * 0.075f * G2((ax - 0.3f) / 0.13f, (y - 0.12f) / 0.1f);   // cuencas de los ojos
        z -= fr * 0.03f * G2(x / 0.5f, (y - 0.3f) / 0.07f);            // ceja osea
        // nariz: tabique, punta y aletas
        float nw = 0.05f + 0.045f * SStep(0.1f, -0.2f, y);
        z -= fr * 0.17f * SStep(0.22f, -0.12f, y) * SStep(-0.29f, -0.21f, y) * (float)Math.Exp(-(x / nw) * (x / nw));
        z -= fr * 0.05f * G2(x / 0.08f, (y + 0.2f) / 0.06f);
        z -= fr * 0.035f * G2((ax - 0.1f) / 0.045f, (y + 0.23f) / 0.045f);
        z -= fr * 0.04f * G2(x / 0.26f, (y - MOUTHY) / 0.09f);         // labios
        z += fr * 0.015f * G2(x / 0.15f, (y - (MOUTHY - 0.15f)) / 0.04f); // hoyuelo bajo el labio
        return new V(x, y, z);
    }

    static Mesh head, hair, eyeball, lidUp, lidLo, lash, browL, browR, ear, earIn, neck, body, collar;
    static int HRN, HSN = 72;
    static V[] hBase; static float[] wJaw, wSmL, wSmR, wChk, wBrL, wBrR; static V hCenter;
    static Inst eyeInsL = new Inst(), eyeInsR = new Inst(), skinIns = new Inst();

    static void BuildAvatar()
    {
        matTwo[M_LID] = true; matTwo[M_HAIR] = true; matTwo[M_LASH] = true;
        // anillos: uniformes y mas densos en la boca (la raja que se abre)
        List<float> th = new List<float>();
        int RU = 70;
        for (int i = 0; i <= RU; i++) th.Add((float)(Math.PI * i / RU));
        foreach (float yy in new float[] { MOUTHY + SLIT, MOUTHY - SLIT, MOUTHY + 0.025f, MOUTHY - 0.03f, MOUTHY + 0.05f, MOUTHY - 0.06f })
            th.Add((float)Math.Acos(yy / RY));
        th.Sort();
        for (int i = th.Count - 1; i > 0; i--) if (th[i] - th[i - 1] < 0.004f && Math.Abs(Math.Cos(th[i]) * RY - (MOUTHY + SLIT)) > 1e-4 && Math.Abs(Math.Cos(th[i]) * RY - (MOUTHY - SLIT)) > 1e-4) th.RemoveAt(i);
        HRN = th.Count;
        int n = HRN * (HSN + 1);
        hBase = new V[n]; wJaw = new float[n]; wSmL = new float[n]; wSmR = new float[n]; wChk = new float[n]; wBrL = new float[n]; wBrR = new float[n];
        MB b = new MB();
        for (int i = 0; i < HRN; i++)
            for (int j = 0; j <= HSN; j++)
            {
                double t = th[i], p = Math.PI * 2 * j / HSN;
                V d = new V(Math.Sin(t) * Math.Cos(p), Math.Cos(t), Math.Sin(t) * Math.Sin(p));
                V q = HeadShape(d);
                int k = i * (HSN + 1) + j;
                hBase[k] = q;
                float fr = SStep(0.1f, -0.6f, d.z), ax = Math.Abs(q.x);
                float hx = SStep(MW + 0.1f, MW - 0.02f, ax) * SStep(-0.2f, -0.7f, d.z);
                float below = q.y < MOUTHY - 0.001f ? 1 : 0;
                float smooth = SStep(MOUTHY + 0.12f, MOUTHY - 0.32f, q.y) * SStep(0.5f, -0.3f, d.z);
                wJaw[k] = Lf(smooth, below, hx);
                wSmL[k] = fr * G2((q.x + MW) / 0.1f, (q.y - MOUTHY) / 0.1f);
                wSmR[k] = fr * G2((q.x - MW) / 0.1f, (q.y - MOUTHY) / 0.1f);
                wChk[k] = fr * G2((ax - 0.33f) / 0.13f, (q.y + 0.2f) / 0.12f);
                wBrL[k] = fr * G2((q.x + 0.3f) / 0.17f, (q.y - 0.36f) / 0.13f);
                wBrR[k] = fr * G2((q.x - 0.3f) / 0.17f, (q.y - 0.36f) / 0.13f);
                // u,v: coordenadas de la cara (delante) o "nuca" (detras) para el material
                b.Add(q, d, d.z < 0 ? q.x : q.x + 10, q.y);
            }
        for (int i = 0; i < HRN - 1; i++)
            for (int j = 0; j < HSN; j++) { int a = i * (HSN + 1) + j; b.Quad(a, a + HSN + 1, a + HSN + 2, a + 1); }
        head = b.Done(M_FACE);
        hCenter = new V(0, 0, 0);
        // pelo: un casquete con la linea del pelo
        MB hb = new MB(); int HRR = 22;
        for (int i = 0; i <= HRR; i++)
            for (int j = 0; j <= HSN; j++)
            {
                double p = Math.PI * 2 * j / HSN;
                float f = (float)Math.Pow((1 - Math.Sin(p)) / 2, 0.8);           // 1 delante, 0 detras
                float tmax = Lf(2.05f, 1.02f, f) + 0.04f * (float)Math.Sin(p * 9) + 0.18f * (float)Math.Pow(Math.Abs(Math.Cos(p)), 3) * (1 - f * 0.5f);
                float t = tmax * i / HRR;
                V d = new V(Math.Sin(t) * Math.Cos(p), Math.Cos(t), Math.Sin(t) * Math.Sin(p));
                V q = HeadShape(d);
                float edge = (float)i / HRR;
                float vol = 1.05f + 0.11f * (1 - edge * edge) + 0.045f * Noise((float)p * 6, t * 5, 3) + 0.04f * SStep(0.2f, -0.6f, (float)Math.Sin(p)) * (1 - edge);
                q = q * Lf(vol, 1.012f, SStep(0.8f, 1f, edge));
                hb.Add(q, d, (float)(p / (Math.PI * 2)), edge);
            }
        for (int i = 0; i < HRR; i++)
            for (int j = 0; j < HSN; j++) { int a = i * (HSN + 1) + j; hb.Quad(a, a + 1, a + HSN + 2, a + HSN + 1); }
        hair = hb.Done(M_HAIR);
        eyeball = MSphere(EYER_R, EYER_R, EYER_R, 18, 24, M_EYE);
        lidUp = MCap(EYER_R * 1.07f, 2.0f, 10, 24, M_LID);
        lidLo = MCap(EYER_R * 1.06f, 1.4f, 8, 24, M_LID);
        lash = MLash(EYER_R * 1.07f, 2.0f, M_LASH);
        browL = MBrow(-1); browR = MBrow(1);
        ear = MSphere(0.075f, 0.19f, 0.13f, 10, 14, M_SKIN);
        earIn = MSphere(0.05f, 0.13f, 0.08f, 8, 12, M_EARIN);
        neck = MCyl(0.4f, 0.36f, 0.95f, 24, M_SKIN, false, false);
        body = MSphere(1.55f, 0.66f, 0.7f, 18, 32, M_SHIRT);
        collar = MTorus(0.44f, 0.07f, 28, 8, M_SHIRT);
    }

    // casquete esferico alrededor de +Y, de 0 a te radianes (para los parpados)
    static Mesh MCap(float r, float te, int rings, int segs, int mat)
    {
        MB b = new MB();
        for (int i = 0; i <= rings; i++)
        {
            double t = te * i / rings;
            for (int j = 0; j <= segs; j++)
            {
                double p = Math.PI * 2 * j / segs;
                V d = new V(Math.Sin(t) * Math.Cos(p), Math.Cos(t), Math.Sin(t) * Math.Sin(p));
                b.Add(d * r, d, (float)j / segs, (float)i / rings);
            }
        }
        for (int i = 0; i < rings; i++)
            for (int j = 0; j < segs; j++) { int a = i * (segs + 1) + j; b.Quad(a, a + segs + 1, a + segs + 2, a + 1); }
        return b.Done(mat);
    }
    // pestanas: una banda que sale del borde del parpado (solo por delante)
    static Mesh MLash(float r, float te, int mat)
    {
        MB b = new MB(); int segs = 16;
        for (int i = 0; i <= 2; i++)
        {
            double t = te + 0.07 * i, rr = r * (1 + 0.1 * i);
            for (int j = 0; j <= segs; j++)
            {
                double p = -Math.PI / 2 + (j - segs / 2.0) / segs * 2.2;
                V d = new V(Math.Sin(t) * Math.Cos(p), Math.Cos(t) + 0.12 * i, Math.Sin(t) * Math.Sin(p));
                b.Add(d * (float)rr, d, (float)j / segs, i / 2f);
            }
        }
        for (int i = 0; i < 2; i++) for (int j = 0; j < segs; j++) { int a = i * (segs + 1) + j; b.Quad(a, a + segs + 1, a + segs + 2, a + 1); }
        return b.Done(mat);
    }
    // ceja: tubo curvo pegado a la frente (centro en el origen)
    static Mesh MBrow(int side)
    {
        MB b = new MB(); int ns = 14, nr = 8;
        for (int i = 0; i <= ns; i++)
        {
            float s = (float)i / ns;
            float x = (s - 0.5f) * 0.34f * side, y = 0.035f * (float)Math.Sin(s * Math.PI) - 0.03f * s;
            float z = -0.035f * (s - 0.5f) * (s - 0.5f) * 4 + 0.05f * s;
            float r = Lf(0.042f, 0.022f, s);
            for (int k = 0; k <= nr; k++)
            {
                double a = Math.PI * 2 * k / nr;
                V nn = new V(0, Math.Cos(a), -Math.Sin(a) * 0.6);
                b.Add(new V(x, y + (float)Math.Cos(a) * r * 0.7f, z - (float)Math.Sin(a) * r * 0.5f), nn.Norm(), s, (float)k / nr);
            }
        }
        for (int i = 0; i < ns; i++) for (int k = 0; k < nr; k++) { int a = i * (nr + 1) + k; b.Quad(a, a + nr + 1, a + nr + 2, a + 1); }
        return b.Done(M_BROW);
    }

    // aplica la expresion a los vertices de la cabeza y recalcula normales
    static void DeformHead()
    {
        float ja = -pJaw * 0.4f, jc = (float)Math.Cos(ja), js = (float)Math.Sin(ja);
        V hinge = new V(0, -0.1f, 0.15f);
        float sm = pSmile;
        V[] P = head.p;
        for (int k = 0; k < hBase.Length; k++)
        {
            V q = hBase[k];
            if (wJaw[k] > 0)
            {
                float dy = q.y - hinge.y, dz = q.z - hinge.z;
                V r = new V(q.x, hinge.y + dy * jc - dz * js, hinge.z + dy * js + dz * jc);
                q = LerpV(q, r, wJaw[k]);
            }
            float ws = wSmL[k] + wSmR[k];
            if (ws > 0.001f)
            {
                float side = wSmR[k] > wSmL[k] ? 1 : -1;
                q = q + new V(side * 0.045f * sm, (sm > 0 ? 0.07f : 0.06f) * sm, 0.035f * Math.Abs(sm)) * ws;
            }
            if (wChk[k] > 0.001f && sm > 0) q = q + new V(0, 0.025f * sm, -0.022f * sm) * wChk[k];
            q.y += 0.045f * (pBrowL * wBrL[k] + pBrowR * wBrR[k]);
            P[k] = q;
        }
        int S = HSN + 1;
        V[] N = head.n;
        for (int i = 0; i < HRN; i++)
            for (int j = 0; j <= HSN; j++)
            {
                int k = i * S + j;
                int jm = j == 0 ? HSN - 1 : j - 1, jp = j == HSN ? 1 : j + 1;
                int im = Math.Max(0, i - 1), ip = Math.Min(HRN - 1, i + 1);
                // al otro lado de la raja de la boca no se mira (la normal seria rara)
                if (i > 0 && Math.Abs(hBase[k].y - (MOUTHY - SLIT)) < 1e-4) im = i;
                if (i < HRN - 1 && Math.Abs(hBase[k].y - (MOUTHY + SLIT)) < 1e-4) ip = i;
                V dt = P[ip * S + j] - P[im * S + j], dp = P[i * S + jp] - P[i * S + jm];
                V nn = Cross(dp, dt);
                float l = nn.Len();
                if (l < 1e-9f || i == 0 || i == HRN - 1) N[k] = (P[k] - hCenter).Norm();
                else N[k] = nn * (1 / l);
            }
    }

    // dibuja el avatar completo en el mundo
    static float breath;
    static void DrawAvatar()
    {
        DeformHead();
        Tf ht = Tf.T(new V(pX, pY, pZ)).Mul(Tf.T(PIVOT)).Mul(Tf.Ry(-pYaw)).Mul(Tf.Rx(pPitch)).Mul(Tf.Rz(-pRoll)).Mul(Tf.T(-PIVOT));
        Tf nt = Tf.T(new V(pX * 0.6f, pY * 0.5f, pZ * 0.6f)).Mul(Tf.T(PIVOT)).Mul(Tf.Ry(-pYaw * 0.45f)).Mul(Tf.Rx(pPitch * 0.3f)).Mul(Tf.Rz(-pRoll * 0.35f)).Mul(Tf.T(-PIVOT));
        float br = (float)Math.Sin(breath) * 0.012f;
        Draw(body, Tf.T(pX * 0.25f, -1.86f + br, 0.28f));
        Draw(collar, Tf.T(pX * 0.35f, -1.28f + br, 0.12f));
        Draw(neck, nt.Mul(Tf.T(0, -1.5f, 0.12f)));
        Draw(head, ht, skinIns);
        Draw(hair, ht);
        for (int s = -1; s <= 1; s += 2)
        {
            Draw(ear, ht.Mul(Tf.T(s * 0.775f, -0.09f, 0.08f)).Mul(Tf.Ry(s * 0.35f)));
            Draw(earIn, ht.Mul(Tf.T(s * 0.81f, -0.09f, 0.07f)).Mul(Tf.Ry(s * 0.35f)));
            V ec = s < 0 ? EYEL : EYER;
            float open = s < 0 ? pEyeL : pEyeR;
            Inst ei = s < 0 ? eyeInsL : eyeInsR;
            // mirada: hacia delante (-Z) girada un poco
            V g = new V(pGazeX * 0.35f - s * 0.02f, pGazeY * 0.25f, -1).Norm();
            ei.gaze = ht.D(g);
            Tf et = ht.Mul(Tf.T(ec));
            Draw(eyeball, et, ei);
            float up = Lf(-0.05f, 0.98f, Sat(open)) + Math.Max(0, open - 1) * 0.25f + (s < 0 ? pBrowL : pBrowR) * 0.08f;
            float lo = -0.62f + 0.3f * (1 - Sat(open)) + 0.18f * Math.Max(0, pSmile);
            Tf ut = et.Mul(Tf.Rx(up));
            Draw(lidUp, ut, skinIns);
            Draw(lash, ut);
            Draw(lidLo, et.Mul(Tf.Rx(lo)).Mul(Tf.Rz((float)Math.PI)), skinIns);
            float bu = s < 0 ? pBrowL : pBrowR;
            Draw(s < 0 ? browL : browR, ht.Mul(Tf.T(s * 0.3f, 0.36f + 0.05f * bu, -0.79f)).Mul(Tf.Rz(s * 0.12f * Math.Min(0, bu))));
        }
    }

    // ---------------------------------------------------------------- materiales
    static V Albedo(int mat, Inst ins, V P, V N, float u, float v, bool back, ref float spec, ref float shin, ref float wrap)
    {
        Style st = ST;
        switch (mat)
        {
            case M_FACE:
            {
                wrap = 0.4f; spec = 0.12f; shin = 22;
                V c = st.skin * (0.96f + 0.08f * Noise(P.x * 60, P.y * 60, 5));
                if (u > 5) return c;
                float au = Math.Abs(u);
                // interior de la boca (la raja abierta)
                if (au < MW && v < MOUTHY + SLIT && v > MOUTHY - SLIT)
                {
                    float f = (MOUTHY + SLIT - v) / (2 * SLIT), edge = Sat(1 - au / MW);
                    V m;
                    if (f < 0.26f) { float tooth = Fr((u + MW) / 0.048f); m = C3(236, 230, 214) * (tooth < 0.08f ? 0.7f : 1) * (f < 0.04f ? 0.8f : 1); spec = 0.5f; shin = 40; }
                    else if (f > 0.9f) { float tooth = Fr((u + MW) / 0.04f); m = C3(220, 212, 196) * (tooth < 0.1f ? 0.7f : 1); }
                    else if (f > 0.6f) { m = C3(170, 64, 72) * (0.7f + 0.3f * f); spec = 0.3f; shin = 30; }
                    else m = C3(70, 18, 22);
                    wrap = 0;
                    return m * (0.35f + 0.65f * SStep(0, 0.35f, edge));
                }
                // labios
                float lu = 0.052f * (float)Math.Sqrt(Math.Max(0, 1 - (u / (MW * 1.05f)) * (u / (MW * 1.05f)))) * (1 - 0.25f * G2(u / 0.035f, 0));
                float ll = 0.064f * (float)Math.Sqrt(Math.Max(0, 1 - (u / MW) * (u / MW)));
                float dl = v >= MOUTHY ? (v - MOUTHY) / Math.Max(1e-4f, lu) : (MOUTHY - v) / Math.Max(1e-4f, ll);
                if (dl < 1.3f)
                {
                    float k = 1 - SStep(0.8f, 1.15f, dl);
                    V lip = st.lip * (0.9f + 0.1f * (float)Math.Sin(u * 160));
                    c = LerpV(c, lip, k);
                    spec = Lf(spec, 0.45f, k); shin = Lf(shin, 45, k);
                }
                // mejillas sonrosadas, nariz y pecas
                c = LerpV(c, Mul(c, C3(255, 170, 160)), 0.35f * G2((au - 0.38f) / 0.15f, (v + 0.2f) / 0.12f));
                c = LerpV(c, Mul(c, C3(255, 190, 180)), 0.25f * G2(u / 0.08f, (v + 0.2f) / 0.07f));
                if (st.freckles && Noise(u * 70, v * 70, 9) > 0.78f) c = c * (0.85f - 0.1f * G2((au - 0.25f) / 0.25f, (v + 0.12f) / 0.12f));
                // sombras de contacto: cuencas, orificios de la nariz, bajo la nariz
                float ao = 1 - 0.28f * G2((au - 0.3f) / 0.15f, (v - 0.12f) / 0.1f);
                ao *= 1 - 0.45f * G2((au - 0.055f) / 0.026f, (v + 0.262f) / 0.016f);
                ao *= 1 - 0.18f * G2(u / 0.1f, (v + 0.3f) / 0.04f);
                ao *= 1 - 0.2f * G2((au - MW) / 0.035f, (v - MOUTHY) / 0.03f);
                return c * ao;
            }
            case M_EYE:
            {
                spec = 1.4f; shin = 160; wrap = 0.2f;
                V g = ins.gaze;
                float cg = Dot(N, g);
                V scl = C3(240, 236, 230);
                scl = LerpV(scl, C3(230, 170, 160), SStep(0.55f, -0.1f, cg) * 0.6f);
                if (cg < 0.9f) return scl * (0.7f + 0.3f * SStep(-0.2f, 0.6f, cg));
                // iris con vetas radiales
                V ax = Cross(g, new V(0, 1, 0)).Norm(), ay = Cross(ax, g);
                float ang = (float)Math.Atan2(Dot(N, ay), Dot(N, ax));
                float r = (float)Math.Sqrt(Math.Max(0, 1 - cg * cg)) / 0.43f;   // 0 centro, 1 borde del iris
                if (r < 0.38f) return C3(6, 6, 8);
                V ic = st.iris * (0.75f + 0.5f * Noise(ang * 8, r * 3, 7)) * (1 - 0.5f * SStep(0.75f, 1f, r)) * (1 + 0.4f * SStep(0.55f, 0.4f, r));
                return LerpV(ic, scl, SStep(0.96f, 1.02f, r));
            }
            case M_LID:
            {
                wrap = 0.4f; spec = 0.1f;
                if (back) return C3(120, 60, 60) * 0.4f;
                V c = st.skin * 0.95f;
                return LerpV(c, C3(40, 26, 22), SStep(0.86f, 0.98f, v));
            }
            case M_LASH: spec = 0.2f; return st.hair * 0.25f + C3(10, 8, 8);
            case M_BROW:
            {
                spec = 0.15f; shin = 20;
                float k = 0.75f + 0.5f * Noise(u * 40, v * 4, 11);
                return st.hair * 0.8f * k;
            }
            case M_HAIR:
            {
                wrap = 0.2f;
                float strand = 0.65f + 0.35f * Noise(u * 220, v * 6, 13) + 0.15f * Noise(u * 60, v * 2, 17);
                spec = 0.45f * strand; shin = 28;
                if (back) return st.hair * 0.35f;
                return st.hair * strand * (1 - 0.35f * SStep(0.85f, 1f, v));
            }
            case M_SKIN:
            {
                wrap = 0.4f; spec = 0.08f;
                return st.skin * (0.9f + 0.05f * Noise(P.x * 40, P.y * 40, 5)) * (1 - 0.35f * SStep(-1.05f, -0.75f, P.y) * SStep(0.3f, 0.6f, N.y < 0 ? 1 : 0.5f));
            }
            case M_EARIN: wrap = 0.5f; return Mul(st.skin, C3(220, 150, 140)) * 0.8f;
            case M_SHIRT:
            {
                spec = 0.05f;
                float weave = 0.92f + 0.08f * Noise(P.x * 90, P.y * 90, 21);
                return st.shirt * weave;
            }
        }
        return new V(1, 0, 1);
    }

    // luces de estudio: principal calida, relleno frio y contraluz
    static readonly V L1 = new V(-0.7f, 0.6f, -0.45f).Norm(), L2 = new V(0.8f, 0.05f, -0.4f).Norm(), L3 = new V(0.35f, 0.55f, 0.85f).Norm();
    static float[] hR, hG, hB;
    static void ShadePass()
    {
        int n = RW * RH;
        V k1 = C3(255, 232, 205) * 1.15f, k2 = C3(140, 170, 255) * 0.26f, k3 = C3(255, 225, 190) * 0.95f;
        Style st = ST;
        for (int idx = 0; idx < n; idx++)
        {
            int t = tidb[idx];
            if (t < 0)
            {
                float px = (idx % RW) / (float)RW - 0.5f, py = (idx / RW) / (float)RH - 0.42f;
                float r = (float)Math.Sqrt(px * px * 1.2f + py * py);
                V bg = LerpV(st.bg1, st.bg2, SStep(0.05f, 0.75f, r));
                hR[idx] = bg.x; hG[idx] = bg.y; hB[idx] = bg.z; continue;
            }
            int a = tA[t], b = tB[t], c = tC[t];
            float w1 = bA[idx], w2 = bB[idx], w0 = 1 - w1 - w2;
            V P = fP[a] * w0 + fP[b] * w1 + fP[c] * w2;
            V N = (fN[a] * w0 + fN[b] * w1 + fN[c] * w2).Norm();
            float u = fU[a] * w0 + fU[b] * w1 + fU[c] * w2, v = fVv[a] * w0 + fVv[b] * w1 + fVv[c] * w2;
            V toC = (camPos - P).Norm();
            int mat = tM[t];
            bool back = false;
            if (matTwo[mat] && Dot(N, toC) < 0) { N = -N; back = true; }
            float spec = 0, shin = 16, wrap = 0;
            V alb = Albedo(mat, insts[tI[t]], P, N, u, v, back, ref spec, ref shin, ref wrap);
            float hemi = N.y * 0.5f + 0.5f;
            V light = LerpV(C3(22, 18, 22), C3(44, 50, 64), hemi);
            V sp = new V(0, 0, 0);
            float d1 = Dot(N, L1), d2 = Dot(N, L2);
            float wd1 = Math.Max(0, (d1 + wrap) / (1 + wrap)), wd2 = Math.Max(0, (d2 + wrap) / (1 + wrap));
            light = light + k1 * wd1 + k2 * wd2;
            if (wrap > 0.3f) light = light + C3(150, 40, 25) * (0.5f * (wd1 - Math.Max(0, d1)));   // luz bajo la piel
            if (spec > 0)
            {
                if (d1 > 0) sp = sp + k1 * (spec * (float)Math.Pow(Math.Max(0, Dot(N, (toC + L1).Norm())), shin));
                if (d2 > 0) sp = sp + k2 * (spec * 0.6f * (float)Math.Pow(Math.Max(0, Dot(N, (toC + L2).Norm())), shin));
            }
            // contraluz en los bordes
            float fres = (float)Math.Pow(1 - Math.Max(0, Dot(N, toC)), 3);
            float rim = fres * Math.Max(0, Dot(N, L3) + 0.4f);
            V col = Mul(alb, light) + sp + k3 * (rim * 0.55f);
            hR[idx] = col.x; hG[idx] = col.y; hB[idx] = col.z;
        }
    }

    // reduce el supermuestreo 2x2, tono y gamma
    static void Resolve()
    {
        for (int y = 0; y < PH; y++)
            for (int x = 0; x < PW; x++)
            {
                int i0 = (y * 2) * RW + x * 2, i1 = i0 + 1, i2 = i0 + RW, i3 = i2 + 1;
                float r = (hR[i0] + hR[i1] + hR[i2] + hR[i3]) * 0.25f, g = (hG[i0] + hG[i1] + hG[i2] + hG[i3]) * 0.25f, b = (hB[i0] + hB[i1] + hB[i2] + hB[i3]) * 0.25f;
                float vx = (x - PW * 0.5f) / PW, vy = (y - PH * 0.5f) / PH, vig = 1 - (vx * vx + vy * vy) * 0.6f;
                r = r * vig / (1 + r * 0.25f); g = g * vig / (1 + g * 0.25f); b = b * vig / (1 + b * 0.25f);
                int R = (int)(Math.Pow(Sat(r), 0.55) * 255), G = (int)(Math.Pow(Sat(g), 0.55) * 255), B = (int)(Math.Pow(Sat(b), 0.55) * 255);
                pix[y * PW + x] = (R << 16) | (G << 8) | B;
            }
    }

    // ================================================================ seguimiento de la cara (vision por ordenador clasica)
    //  1. piel: histograma Cr/Cb de tu cara frente al fondo (back projection, como OpenCV)
    //  2. la mancha de piel mas grande = la cara; sus momentos dan posicion, tamano e inclinacion
    //  3. dentro de la cara, lo oscuro son ojos, cejas, orificios y boca: de ahi salen giro y gestos
    const int GW = 160, GH = 120, HB = 32;
    static byte[] gY = new byte[GW * GH], gCr = new byte[GW * GH], gCb = new byte[GW * GH];
    static int[] camRGB = new int[GW * GH];
    static float[] skP = new float[HB * HB]; static bool skInit;
    static byte[] fmask = new byte[GW * GH], tmpM = new byte[GW * GH], fill = new byte[GW * GH];
    static int[] lab = new int[GW * GH], qbuf = new int[GW * GH];
    static byte[] img; static int iw_, ih_, istride, lastId = -1;
    static bool camActive, camMirror;
    static int frameNo;

    // resultado del seguimiento
    static bool faceOk; static double faceSeenT = -99;
    static float fcx, fcy, fhw, fhh, fang, fArea;         // centro, semiejes y angulo de la cara (pixeles de la rejilla)
    static int fx0, fy0, fx1, fy1;
    static float skinY;
    // medidas en coordenadas de la cara (u: -1 izq..1 der, v: -1 arriba..1 abajo)
    static float mFeatU, mFeatV, mEyeL, mEyeR, mBrowL, mBrowR, mMouthH, mMouthW, mGazeX, mGazeY, mEyeAng; static bool mEyesBoth;
    // neutro (calibracion)
    static bool calibrated;
    static float nFeatU, nFeatV, nEyeL = 1, nEyeR = 1, nBrowL, nBrowR, nMouthH, nMouthW = 1, nArea = 1, nCx, nCy, nAng, nEyeAng;
    static float eyeUL = -0.36f, eyeUR = 0.36f, eyeV = -0.18f, browV = -0.42f, mouthV = 0.5f;

    static void DefaultSkin()
    {
        for (int a = 0; a < HB; a++)
            for (int b = 0; b < HB; b++)
            {
                float u = (a * 8 + 4 - 152) / 15f, v = (b * 8 + 4 - 106) / 16f;
                skP[a * HB + b] = (float)Math.Exp(-(u * u + v * v) * 1.1);
            }
    }

    static bool GrabFrame()
    {
        lock (fLock)
        {
            if (shId == lastId || shFrame == null) return false;
            if (img == null || img.Length < shLen) img = new byte[shLen];
            Buffer.BlockCopy(shFrame, 0, img, 0, shLen);
            iw_ = shW; ih_ = shH; istride = shStride; lastId = shId;
        }
        camActive = true;
        return true;
    }

    static void ReadPixels()
    {
        int st = Math.Abs(istride); bool bu = istride < 0;
        for (int y = 0; y < GH; y++)
        {
            int sy = Math.Min(ih_ - 1, (int)((y + 0.5f) * ih_ / GH));
            int row = (bu ? ih_ - 1 - sy : sy) * st;
            for (int x = 0; x < GW; x++)
            {
                int sx = Math.Min(iw_ - 1, (int)(((camMirror ? GW - 1 - x : x) + 0.5f) * iw_ / GW));
                int p = row + sx * 4;
                if (p + 2 >= img.Length) continue;
                int B = img[p], G = img[p + 1], R = img[p + 2], i = y * GW + x;
                camRGB[i] = (R << 16) | (G << 8) | B;
                gY[i] = (byte)(0.299f * R + 0.587f * G + 0.114f * B);
                gCr[i] = (byte)Clampf(128 + 0.5f * R - 0.4187f * G - 0.0813f * B, 0, 255);
                gCb[i] = (byte)Clampf(128 - 0.1687f * R - 0.3313f * G + 0.5f * B, 0, 255);
            }
        }
    }

    static float SkinP(int i) { return gY[i] < 30 ? 0 : skP[(gCr[i] >> 3) * HB + (gCb[i] >> 3)]; }

    static void TrackFace()
    {
        if (!skInit) { DefaultSkin(); skInit = true; }
        frameNo++;
        ReadPixels();
        int N = GW * GH;
        for (int i = 0; i < N; i++) fmask[i] = (byte)(SkinP(i) > 0.32f ? 1 : 0);
        Morph(fmask, true); Morph(fmask, false);
        // mancha de piel que mejor encaja con la cara anterior
        for (int i = 0; i < N; i++) lab[i] = 0;
        int best = -1; float bestS = 0; int next = 1;
        int bx0 = 0, by0 = 0, bx1 = 0, by1 = 0;
        float pcx = faceOk ? fcx : GW / 2f, pcy = faceOk ? fcy : GH * 0.45f;
        for (int s = 0; s < N; s++)
        {
            if (fmask[s] == 0 || lab[s] != 0) continue;
            int id = next++, qh = 0, qt = 0; qbuf[qt++] = s; lab[s] = id;
            long sx = 0, sy = 0; int area = 0, x0 = GW, y0 = GH, x1 = 0, y1 = 0;
            while (qh < qt)
            {
                int i = qbuf[qh++], x = i % GW, y = i / GW;
                area++; sx += x; sy += y;
                if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
                if (x > 0 && fmask[i - 1] != 0 && lab[i - 1] == 0) { lab[i - 1] = id; qbuf[qt++] = i - 1; }
                if (x < GW - 1 && fmask[i + 1] != 0 && lab[i + 1] == 0) { lab[i + 1] = id; qbuf[qt++] = i + 1; }
                if (y > 0 && fmask[i - GW] != 0 && lab[i - GW] == 0) { lab[i - GW] = id; qbuf[qt++] = i - GW; }
                if (y < GH - 1 && fmask[i + GW] != 0 && lab[i + GW] == 0) { lab[i + GW] = id; qbuf[qt++] = i + GW; }
            }
            if (area < N * 0.015f || area > N * 0.65f) continue;
            float cx = (float)sx / area, cy = (float)sy / area;
            float d2 = ((cx - pcx) * (cx - pcx) + (cy - pcy) * (cy - pcy)) / (GW * GW * 0.12f);
            float sc = area * (float)Math.Exp(-d2) * (1.2f - cy / GH * 0.6f);
            if (sc > bestS) { bestS = sc; best = id; bx0 = x0; by0 = y0; bx1 = x1; by1 = y1; }
        }
        if (best < 0) { faceOk = false; return; }
        // rellenar huecos (ojos, boca...) dentro de la mancha
        for (int i = 0; i < N; i++) fill[i] = 0;
        int ex0 = Math.Max(0, bx0 - 1), ey0 = Math.Max(0, by0 - 1), ex1 = Math.Min(GW - 1, bx1 + 1), ey1 = Math.Min(GH - 1, by1 + 1);
        {
            int qh = 0, qt = 0;
            for (int x = ex0; x <= ex1; x++) { Seed(x, ey0, best, ref qt); Seed(x, ey1, best, ref qt); }
            for (int y = ey0; y <= ey1; y++) { Seed(ex0, y, best, ref qt); Seed(ex1, y, best, ref qt); }
            while (qh < qt)
            {
                int i = qbuf[qh++], x = i % GW, y = i / GW;
                if (x > ex0) Seed(x - 1, y, best, ref qt); if (x < ex1) Seed(x + 1, y, best, ref qt);
                if (y > ey0) Seed(x, y - 1, best, ref qt); if (y < ey1) Seed(x, y + 1, best, ref qt);
            }
        }
        // fill: 2 = fuera; dentro de la caja lo que no es "fuera" es cara
        // corte del cuello: la cara mide ~1.4 veces su anchura
        int maxW = 0;
        for (int y = by0; y <= by1; y++)
        {
            int w = 0; for (int x = bx0; x <= bx1; x++) if (fill[y * GW + x] != 2) w++;
            if (w > maxW) maxW = w;
            if (y - by0 > maxW * 1.5f && maxW > 6) break;
        }
        int cutY = Math.Min(by1, by0 + (int)(maxW * 1.3f));
        double m00 = 0, m10 = 0, m01 = 0;
        for (int y = by0; y <= cutY; y++) for (int x = bx0; x <= bx1; x++) if (fill[y * GW + x] != 2) { m00++; m10 += x; m01 += y; }
        if (m00 < 30) { faceOk = false; return; }
        double cx0 = m10 / m00, cy0 = m01 / m00, mu20 = 0, mu02 = 0, mu11 = 0;
        for (int y = by0; y <= cutY; y++) for (int x = bx0; x <= bx1; x++) if (fill[y * GW + x] != 2) { double dx = x - cx0, dy = y - cy0; mu20 += dx * dx; mu02 += dy * dy; mu11 += dx * dy; }
        mu20 /= m00; mu02 /= m00; mu11 /= m00;
        double ang = 0.5 * Math.Atan2(2 * mu11, mu02 - mu20);   // 0 = eje mayor vertical
        double tr = mu20 + mu02, det = mu20 * mu02 - mu11 * mu11, disc = Math.Sqrt(Math.Max(0, tr * tr / 4 - det));
        double l1 = tr / 2 + disc, l2 = Math.Max(1e-3, tr / 2 - disc);
        fcx = (float)cx0; fcy = (float)cy0; fhh = (float)(2 * Math.Sqrt(l1)); fhw = (float)(2 * Math.Sqrt(l2)); fang = (float)(-ang); fArea = (float)m00;
        fx0 = bx0; fy0 = by0; fx1 = bx1; fy1 = cutY;
        faceOk = fhw > 4 && fhh > 5;
        if (!faceOk) return;
        // brillo tipico de la piel de la cara (mediana)
        int[] hist = new int[256]; int hn = 0;
        for (int y = by0; y <= cutY; y++) for (int x = bx0; x <= bx1; x++) { int i = y * GW + x; if (lab[i] == best) { hist[gY[i]]++; hn++; } }
        int acc = 0; skinY = 128; for (int k = 0; k < 256; k++) { acc += hist[k]; if (acc >= hn / 2) { skinY = k; break; } }
        Measure(best, by0, cutY, bx0, bx1);
        // segunda pasada: la linea de los ojos da la inclinacion real de la cara (el cuello engana)
        for (int it = 0; it < 3 && mEyesBoth && calibrated; it++)
        {
            float na = mEyeAng - nEyeAng0;
            if (Math.Abs(AngDiffF(na, fang)) > 0.6f || Math.Abs(AngDiffF(na, fang)) < 0.01f) break;
            fang = na; Measure(best, by0, cutY, bx0, bx1);
        }
    }
    static void Seed(int x, int y, int best, ref int qt)
    {
        int i = y * GW + x;
        if (fill[i] != 0 || lab[i] == best) return;
        fill[i] = 2; qbuf[qt++] = i;
    }

    static void Morph(byte[] m, bool open)
    {
        // apertura (quita ruido) o cierre (tapa grietas)
        for (int y = 0; y < GH; y++)
            for (int x = 0; x < GW; x++)
            {
                int i = y * GW + x; byte v = m[i];
                bool edge = x == 0 || y == 0 || x == GW - 1 || y == GH - 1;
                if (open) { if (v != 0 && (edge || m[i - 1] == 0 || m[i + 1] == 0 || m[i - GW] == 0 || m[i + GW] == 0)) v = 0; }
                else { if (v == 0 && !edge && (m[i - 1] != 0 || m[i + 1] != 0 || m[i - GW] != 0 || m[i + GW] != 0)) v = 1; }
                tmpM[i] = v;
            }
        for (int y = 0; y < GH; y++)
            for (int x = 0; x < GW; x++)
            {
                int i = y * GW + x;
                bool edge = x == 0 || y == 0 || x == GW - 1 || y == GH - 1;
                byte v = tmpM[i];
                if (open) { if (v == 0 && !edge && (tmpM[i - 1] != 0 || tmpM[i + 1] != 0 || tmpM[i - GW] != 0 || tmpM[i + GW] != 0)) v = 1; }
                else { if (v != 0 && (edge || tmpM[i - 1] == 0 || tmpM[i + 1] == 0 || tmpM[i - GW] == 0 || tmpM[i + GW] == 0)) v = 0; }
                m[i] = v;
            }
    }

    // coordenadas de la cara de un pixel de la rejilla
    static void FaceUV(int x, int y, out float u, out float v)
    {
        float dx = x - fcx, dy = y - fcy, c = (float)Math.Cos(fang), s = (float)Math.Sin(fang);
        u = (dx * c + dy * s) / fhw; v = (-dx * s + dy * c) / fhh;
    }
    static int FacePix(float u, float v)
    {
        float c = (float)Math.Cos(fang), s = (float)Math.Sin(fang);
        float dx = u * fhw, dy = v * fhh;
        int x = (int)Math.Round(fcx + dx * c - dy * s), y = (int)Math.Round(fcy + dx * s + dy * c);
        if (x < 0 || y < 0 || x >= GW || y >= GH) return -1;
        return y * GW + x;
    }

    // mide ojos, cejas y boca dentro de la cara
    static void Measure(int best, int y0, int y1, int x0, int x1)
    {
        float dark = skinY * 0.66f, vdark = skinY * 0.48f;
        // centro de los rasgos de arriba (ojos y cejas): da el giro de la cabeza
        double su = 0, sv = 0, sn = 0;
        for (int y = y0; y <= y1; y++)
            for (int x = x0; x <= x1; x++)
            {
                int i = y * GW + x; if (fill[i] == 2) continue;
                float u, v; FaceUV(x, y, out u, out v);
                if (v > eyeV + 0.18f + lastDv || v < browV - 0.25f + lastDv || Math.Abs(u) > 0.85f) continue;
                if (gY[i] < dark || lab[i] != best) { su += u; sv += v; sn++; }
            }
        if (sn > 4) { mFeatU = (float)(su / sn); mFeatV = (float)(sv / sn); }
        lastDv = calibrated ? Clampf(mFeatV - nFeatV, -0.3f, 0.3f) : 0;
        // ojos, cejas y mirada (cajas que siguen el giro)
        float du = mFeatU - nFeatU, dv = mFeatV - nFeatV;
        float[] eo = new float[2], bv = new float[2], gx = new float[2], gy = new float[2], ecu = new float[2], ecv = new float[2];
        for (int side = 0; side < 2; side++)
        {
            float cu = (side == 0 ? eyeUL : eyeUR) + du, cv = eyeV + dv;
            int cnt = 0; double ru = 0, rv = 0, rn = 0, eu = 0, ev = 0;
            for (float v = cv - 0.11f; v <= cv + 0.12f; v += 0.5f / fhh)
                for (float u = cu - 0.2f; u <= cu + 0.2f; u += 0.5f / fhw)
                {
                    int i = FacePix(u, v); if (i < 0) continue;
                    if (gY[i] < dark || (lab[i] != best && fill[i] != 2)) { cnt++; eu += u; ev += v; }
                    if (gY[i] < vdark) { ru += u; rv += v; rn++; }
                }
            float area = 0.23f * 0.4f * fhh * fhw * 4;
            eo[side] = cnt / Math.Max(1f, area);
            if (cnt > 0) { ecu[side] = (float)(eu / cnt); ecv[side] = (float)(ev / cnt); } else { ecu[side] = cu; ecv[side] = cv; }
            if (rn > 2) { gx[side] = (float)(ru / rn) - cu; gy[side] = (float)(rv / rn) - cv; }
            // ceja: lo oscuro por encima del ojo
            double bs = 0, bn = 0;
            for (float v = browV + dv - 0.14f; v <= Math.Min(browV + dv + 0.14f, cv - 0.12f); v += 0.5f / fhh)
                for (float u = cu - 0.22f; u <= cu + 0.22f; u += 0.5f / fhw)
                {
                    int i = FacePix(u, v); if (i < 0) continue;
                    if (gY[i] < dark || (lab[i] != best && fill[i] != 2)) { bs += v; bn++; }
                }
            bv[side] = bn > 2 ? (float)(bs / bn) - dv : browV;
        }
        mEyeL = eo[0]; mEyeR = eo[1]; mBrowL = bv[0]; mBrowR = bv[1];
        mGazeX = (gx[0] + gx[1]) * 0.5f; mGazeY = (gy[0] + gy[1]) * 0.5f;
        mEyesBoth = calibrated && needNeutral == 0 ? eo[0] > nEyeL * 0.5f && eo[1] > nEyeR * 0.5f : eo[0] > 0.02f && eo[1] > 0.02f;
        mEyeAng = fang + (float)Math.Atan2((ecv[1] - ecv[0]) * fhh, (ecu[1] - ecu[0]) * fhw);
        // boca: altura de lo muy oscuro y anchura de lo rojo/oscuro
        int top = 999, bot = -999; float w1 = 0, w2 = 0, w3 = 0;
        float mcu = du * 0.6f, mcv = mouthV + dv * 0.5f;
        for (float v = mcv - 0.22f; v <= mcv + 0.3f; v += 0.5f / fhh)
        {
            float l = 9, r = -9; bool any = false;
            for (float u = mcu - 0.6f; u <= mcu + 0.6f; u += 0.5f / fhw)
            {
                int i = FacePix(u, v); if (i < 0) continue;
                bool red = gCr[i] > 150 && gY[i] < skinY * 0.95f, dk = gY[i] < dark;
                if (red || dk) { if (u < l) l = u; if (u > r) r = u; any = true; }
                if (gY[i] < vdark || (dk && gCr[i] > 145)) { int vi = (int)(v * 200); if (vi < top) top = vi; if (vi > bot) bot = vi; }
            }
            float ww = r - l;
            if (any && ww < 1.2f) { if (ww > w1) { w3 = w2; w2 = w1; w1 = ww; } else if (ww > w2) { w3 = w2; w2 = ww; } else if (ww > w3) w3 = ww; }
        }
        mMouthH = bot >= top ? (bot - top) / 200f : 0;
        mMouthW = (w1 + w2 + w3) / 3;
    }

    // ovalo guia para la calibracion (coordenadas de la rejilla)
    const float OVX = GW / 2f, OVY = GH * 0.46f, OVA = GW * 0.17f, OVB = GH * 0.31f;
    static float OvalD(int x, int y) { float a = (x - OVX) / OVA, b = (y - OVY) / OVB; return a * a + b * b; }

    // 1) aprende el color de tu piel: lo de dentro del ovalo frente a lo de fuera
    static void LearnSkinOval()
    {
        float[] hs = new float[HB * HB], hg = new float[HB * HB]; int ns = 0, ng = 0;
        int[] hist = new int[256]; int hn = 0;
        for (int y = 0; y < GH; y++) for (int x = 0; x < GW; x++) if (OvalD(x, y) < 0.5f) { hist[gY[y * GW + x]]++; hn++; }
        int acc = 0, med = 128; for (int k = 0; k < 256; k++) { acc += hist[k]; if (acc >= hn / 2) { med = k; break; } }
        for (int y = 0; y < GH; y++)
            for (int x = 0; x < GW; x++)
            {
                int i = y * GW + x, bin = (gCr[i] >> 3) * HB + (gCb[i] >> 3);
                float d = OvalD(x, y);
                if (d < 0.6f) { if (gY[i] > med * 0.7f && gY[i] < 250) { hs[bin]++; ns++; } }
                else if (d > 1.5f) { hg[bin]++; ng++; }
            }
        if (ns < 40) return;
        hs = Blur(hs); hg = Blur(hg);
        float mx = 0; for (int k = 0; k < hs.Length; k++) mx = Math.Max(mx, hs[k]);
        for (int k = 0; k < hs.Length; k++)
        {
            float ps = hs[k] / ns, pg = hg[k] / Math.Max(1, ng);
            skP[k] = Sat(ps / (ps + pg * 1.5f + 0.3f / ns) * 1.25f) * Sat(hs[k] / (mx * 0.03f + 1e-6f));
        }
        faceOk = false;
    }

    // 2) con la cara ya encontrada, aprende donde estan tus ojos, cejas y boca
    static void Calibrate()
    {
        if (!faceOk) return;
        // histograma de la cara (sin rasgos) frente al resto de la imagen
        float[] hs = new float[HB * HB], hg = new float[HB * HB]; int ns = 0, ng = 0;
        for (int y = 0; y < GH; y++)
            for (int x = 0; x < GW; x++)
            {
                int i = y * GW + x, bin = (gCr[i] >> 3) * HB + (gCb[i] >> 3);
                float u, v; FaceUV(x, y, out u, out v);
                float d = u * u + v * v;
                if (d < 0.55f && gY[i] > skinY * 0.7f) { hs[bin]++; ns++; }
                else if (d > 1.6f && (y < fy0 || y > fy1 + 8 || x < fx0 - 4 || x > fx1 + 4)) { hg[bin]++; ng++; }
            }
        if (ns < 20) return;
        // posiciones de ojos y cejas: en cada lado, dos franjas de "no piel" (la de abajo es el ojo)
        float dark = skinY * 0.66f;
        int best = lab[(int)fcy * GW + (int)fcx];
        float evSum = 0, bvSum = 0; int evN = 0, bvN = 0;
        for (int side = 0; side < 2; side++)
        {
            float[] prof = new float[48];
            for (int y = fy0; y <= fy1; y++)
                for (int x = fx0; x <= fx1; x++)
                {
                    int i = y * GW + x; if (fill[i] == 2) continue;
                    float u, v; FaceUV(x, y, out u, out v);
                    if ((side == 0 ? u > -0.1f || u < -0.75f : u < 0.1f || u > 0.75f) || v < -1.05f || v > 0.1f) continue;
                    if (gY[i] < dark || lab[i] != best) { int bb = (int)((v + 1.05f) / 0.025f); if (bb >= 0 && bb < 48) prof[bb]++; }
                }
            float[] sm = new float[48];
            for (int k = 0; k < 48; k++) sm[k] = prof[k] + (k > 0 ? prof[k - 1] * 0.6f : 0) + (k < 47 ? prof[k + 1] * 0.6f : 0);
            int p1 = -1; for (int k = 0; k < 48; k++) if (p1 < 0 || sm[k] > sm[p1]) p1 = k;
            int p2 = -1; for (int k = 0; k < 48; k++) if (Math.Abs(k - p1) >= 6 && sm[k] > sm[Math.Max(0, k - 1)] && sm[k] >= sm[Math.Min(47, k + 1)] && (p2 < 0 || sm[k] > sm[p2])) p2 = k;
            if (p1 < 0 || sm[p1] < 2) continue;
            int pe = p1, pb = p2;
            if (p2 >= 0 && p2 > p1) { pe = p2; pb = p1; }
            if (p2 >= 0 && sm[p2] < sm[p1] * 0.2f) { pe = p1; pb = -1; }
            evSum += -1.05f + pe * 0.025f; evN++;
            if (pb >= 0) { bvSum += -1.05f + pb * 0.025f; bvN++; }
        }
        if (evN > 0) eyeV = evSum / evN;
        browV = bvN > 0 ? bvSum / bvN : eyeV - 0.22f;
        if (browV > eyeV - 0.1f) browV = eyeV - 0.22f;
        // centro de los ojos en horizontal
        {
            double sl = 0, nl = 0, sr = 0, nr = 0;
            for (int y = fy0; y <= fy1; y++)
                for (int x = fx0; x <= fx1; x++)
                {
                    int i = y * GW + x; float u, v; FaceUV(x, y, out u, out v);
                    if (Math.Abs(v - eyeV) > 0.1f || gY[i] >= dark) continue;
                    if (u < -0.1f && u > -0.75f) { sl += u; nl++; } else if (u > 0.1f && u < 0.75f) { sr += u; nr++; }
                }
            if (nl > 2) eyeUL = (float)(sl / nl); if (nr > 2) eyeUR = (float)(sr / nr);
        }
        // boca: la fila mas roja/oscura de la parte de abajo
        {
            float bestS = 0; mouthV = 0.5f;
            for (float v = 0.2f; v < 0.85f; v += 0.5f / fhh)
            {
                float s = 0;
                for (float u = -0.4f; u <= 0.4f; u += 0.5f / fhw) { int i = FacePix(u, v); if (i < 0) continue; if (gCr[i] > 148 || gY[i] < dark) s++; }
                if (s > bestS) { bestS = s; mouthV = v; }
            }
        }
        nFeatU = mFeatU; nFeatV = mFeatV; lastDv = 0;
        needNeutral = 8; sN = 0; sFU = sFV = sEL = sER = sBL = sBR = sMH = sMW = sAr = sCx = sCy = sAng = sEA = sEA0 = 0;
        calibrated = true;
    }
    static int needNeutral; static float lastDv, nEyeAng0;
    static float sFU, sFV, sEL, sER, sBL, sBR, sMH, sMW, sAr, sCx, sCy, sAng, sEA, sEA0; static int sN;
    // la cara neutra es la media de varios fotogramas (menos ruido)
    static void NeutralStep()
    {
        sFU += mFeatU; sFV += mFeatV; sEL += mEyeL; sER += mEyeR; sBL += mBrowL; sBR += mBrowR; sMH += mMouthH; sMW += mMouthW;
        sAr += fArea; sCx += fcx; sCy += fcy; sAng += fang; sEA += mEyeAng; sEA0 += mEyesBoth ? AngDiffF(mEyeAng, fang) : 0; sN++;
        needNeutral--;
        if (needNeutral > 0) return;
        float k = 1f / sN;
        mFeatU = sFU * k; mFeatV = sFV * k; mEyeL = sEL * k; mEyeR = sER * k; mBrowL = sBL * k; mBrowR = sBR * k; mMouthH = sMH * k; mMouthW = sMW * k;
        fArea = sAr * k; fcx = sCx * k; fcy = sCy * k;
        float ang = sAng * k, ea = sEA * k, ea0 = sEA0 * k;
        float keepAng = fang; fang = ang; float keepEA = mEyeAng; mEyeAng = ea;
        TakeNeutral();
        nEyeAng0 = ea0; fang = keepAng; mEyeAng = keepEA;
    }
    static void TakeNeutral()
    {
        nFeatU = mFeatU; nFeatV = mFeatV; nEyeL = Math.Max(0.02f, mEyeL); nEyeR = Math.Max(0.02f, mEyeR); nBrowL = mBrowL; nBrowR = mBrowR;
        nMouthH = mMouthH; nMouthW = Math.Max(0.1f, mMouthW); nArea = fArea; nCx = fcx; nCy = fcy; nAng = fang; nEyeAng = mEyeAng; nEyeAng0 = mEyesBoth ? AngDiffF(mEyeAng, fang) : 0;
    }
    static float[] Blur(float[] h)
    {
        float[] o = new float[HB * HB];
        for (int a = 0; a < HB; a++)
            for (int b = 0; b < HB; b++)
            {
                float s = 0;
                for (int da = -1; da <= 1; da++) for (int db = -1; db <= 1; db++)
                    {
                        int aa = a + da, bb = b + db;
                        if (aa < 0 || bb < 0 || aa >= HB || bb >= HB) continue;
                        s += h[aa * HB + bb] * (da == 0 && db == 0 ? 4 : (da == 0 || db == 0 ? 2 : 1));
                    }
                o[a * HB + b] = s / 16;
            }
        return o;
    }

    // de las medidas a la expresion del avatar (con suavizado)
    static float tYaw, tPitch, tRoll, tX, tY, tZ, tJaw, tSmile, tBrowL, tBrowR, tEyeL = 1, tEyeR = 1, tGx, tGy;
    static void ApplyTracking(double dt)
    {
        if (!faceOk || !calibrated) return;
        tYaw = Clampf((mFeatU - nFeatU) * 2.0f, -0.75f, 0.75f);
        tPitch = Clampf(-(mFeatV - nFeatV) * 2.2f - (fcy - nCy) / GH * 0.4f, -0.5f, 0.5f);
        float roll = mEyesBoth ? AngDiffF(mEyeAng, nEyeAng) : AngDiffF(fang, nAng);
        tRoll = Clampf(roll * 1.1f, -0.6f, 0.6f);
        tX = Clampf((fcx - nCx) / GW * 2.6f, -0.9f, 0.9f);
        tY = Clampf(-(fcy - nCy) / GH * 2.0f, -0.6f, 0.6f);
        tZ = Clampf(-((float)Math.Sqrt(fArea / nArea) - 1) * 2.2f, -1.2f, 1.0f);
        tJaw = Sat((mMouthH - nMouthH) / 0.2f);
        float sr = mMouthW / (float)Math.Max(0.6, Math.Cos(tYaw * 1.1)) / nMouthW - 1; sr = sr > 0 ? Math.Max(0, sr - 0.03f) : Math.Min(0, sr + 0.05f);
        tSmile = Clampf(sr / 0.13f, -0.6f, 1.1f) * (1 - tJaw * 0.5f);
        tBrowL = Clampf(Dz(nBrowL - mBrowL, 0.02f) / 0.06f, -1, 1); tBrowR = Clampf(Dz(nBrowR - mBrowR, 0.02f) / 0.06f, -1, 1);
        float eL = mEyeL / nEyeL, eR = mEyeR / nEyeR;
        tEyeL = Clampf((eL - 0.25f) / 0.85f, 0, 1.25f); tEyeR = Clampf((eR - 0.25f) / 0.85f, 0, 1.25f);
        // parpadeo: si un ojo se cierra mucho y el otro casi tambien, los dos
        if (tEyeL < 0.35f && tEyeR < 0.6f) tEyeR = Math.Min(tEyeR, 0.3f);
        if (tEyeR < 0.35f && tEyeL < 0.6f) tEyeL = Math.Min(tEyeL, 0.3f);
        tGx = Clampf(mGazeX / 0.1f, -1, 1); tGy = Clampf(-mGazeY / 0.08f, -1, 1);
    }
    static float Dz(float v, float d) { return v > d ? v - d : v < -d ? v + d : 0; }
    static float AngDiffF(float a, float b) { float d = a - b; while (d > Math.PI) d -= (float)(2 * Math.PI); while (d < -Math.PI) d += (float)(2 * Math.PI); return d; }

    static void Smooth(double dt)
    {
        float k = (float)Math.Min(1, dt * 12), kf = (float)Math.Min(1, dt * 20);
        pYaw = Lf(pYaw, tYaw, k); pPitch = Lf(pPitch, tPitch, k); pRoll = Lf(pRoll, tRoll, k);
        pX = Lf(pX, tX, k); pY = Lf(pY, tY, k); pZ = Lf(pZ, tZ, k * 0.6f);
        pJaw = Lf(pJaw, tJaw, kf); pSmile = Lf(pSmile, tSmile, k);
        pBrowL = Lf(pBrowL, tBrowL, k); pBrowR = Lf(pBrowR, tBrowR, k);
        pEyeL = Lf(pEyeL, tEyeL, kf); pEyeR = Lf(pEyeR, tEyeR, kf);
        pGazeX = Lf(pGazeX, tGx, k * 0.7f); pGazeY = Lf(pGazeY, tGy, k * 0.7f);
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
        ReadSize(); Alloc(); Init();
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

    static void ReadSize() { try { W = Math.Max(60, Console.WindowWidth); H = Math.Max(24, Console.WindowHeight); } catch { W = 120; H = 40; } }
    static void CheckSize() { int ow = W, oh = H; ReadSize(); if (ow != W || oh != H) { Alloc(); Out(E + "0m" + E + "2J"); } }

    static void Alloc()
    {
        PW = W; PH = H * 2; RW = PW * 2; RH = PH * 2;
        pix = new int[PW * PH];
        cb = new char[W * H]; cc = new int[W * H]; cbg = new int[W * H];
        pcb = new char[W * H]; pcc = new int[W * H]; pcbg = new int[W * H]; fullDraw = true;
        int n = RW * RH;
        zbuf = new float[n]; bA = new float[n]; bB = new float[n]; tidb = new int[n]; hR = new float[n]; hG = new float[n]; hB = new float[n];
    }

    // ---------------------------------------------------------------- tamano de letra (consola clasica)
    static bool fontCtl; static FONTEX origFont; static CSBI origInfo;
    static readonly int[] FSIZES = { 6, 8, 10, 12, 14, 16 };
    static int fIdx = 2;
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
            int c = Math.Max(60, Math.Min(240, (big & 0xFFFF) - 2)), l = Math.Max(24, Math.Min(110, ((big >> 16) & 0xFFFF) - 2));
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

    // ================================================================ teclado del PC (tus teclas)
    static bool[] kNow = new bool[256], kPrev = new bool[256];

    static Random rnd = new Random(5);
    static volatile bool quit; static bool dumping;
    static double gt, fps, fpsT; static int fpsN;
    static V camTarget; static float camFov = 0.8f;
    static bool showCam = true, help, demo; static double camWaitT;

    // ================================================================ arranque
    public static void Run()
    {
        Setup();
        if (!win && Environment.OSVersion.Platform == PlatformID.Win32NT) { Restore(); Console.WriteLine("Esta consola no soporta colores ANSI (hace falta Windows 10 o superior)."); return; }
        Thread cap = new Thread(CapThread); cap.IsBackground = true; cap.SetApartmentState(ApartmentState.MTA); cap.Start();
        try
        {
            Stopwatch sw = Stopwatch.StartNew(); double last = 0;
            while (!quit)
            {
                double t = sw.Elapsed.TotalSeconds; double dt = Math.Min(0.06, t - last); last = t;
                CheckSize(); ReadInput();
                Frame(dt);
                Present();
                fpsN++; if (t - fpsT > 1) { fps = fpsN / (t - fpsT); fpsN = 0; fpsT = t; }
                int ms = (int)((1.0 / 30 - (sw.Elapsed.TotalSeconds - t)) * 1000);
                if (ms > 1) Thread.Sleep(ms);
            }
        }
        finally { capRun = false; Restore(); }
    }

    static void Init()
    {
        InitStyles(); BuildAvatar(); DefaultSkin(); skInit = true;
        try { string s = File.ReadAllText(Path.Combine(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Cabeza3D"), "estilo.txt")).Trim(); int v; if (int.TryParse(s, out v)) styleIdx = ((v % styles.Count) + styles.Count) % styles.Count; } catch { }
        Msg("Pon tu cara dentro del ovalo, relajada y mirando al frente");
    }
    static void SaveStyle()
    {
        if (dumping) return;
        try { string d = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Cabeza3D"); Directory.CreateDirectory(d); File.WriteAllText(Path.Combine(d, "estilo.txt"), styleIdx.ToString()); } catch { }
    }

    // ================================================================ teclado
    static readonly int[] WATCH = { 0x1B, 0x20, 0x09, 0x43, 0x47, 0x44, 0x48, 0x70, 0x6B, 0x6D, 0xBB, 0xBD, 0x4B };
    static bool Key(int vk) { return kNow[vk]; }
    static bool Press(int vk) { return kNow[vk] && !kPrev[vk]; }
    static void ReadInput()
    {
        for (int i = 0; i < 256; i++) kPrev[i] = kNow[i];
        if (dumping) return;
        try { foreach (int vk in WATCH) kNow[vk] = (GetAsyncKeyState(vk) & 0x8000) != 0; FlushConsoleInputBuffer(hIn); } catch { }
    }

    // ================================================================ cada fotograma
    static bool ovalMode = true; static double ovalT = 6, seekT;
    static void Frame(double dt)
    {
        gt += dt;
        if (Press(0x1B)) { quit = true; return; }
        if (Press(0x09)) showCam = !showCam;
        if (Press(0x43)) { styleIdx = (styleIdx + 1) % styles.Count; SaveStyle(); Msg("Estilo: " + ST.name); }
        if (Press(0x47)) { camMirror = !camMirror; Msg("Imagen invertida (izquierda / derecha)"); }
        if (Press(0x44)) { demo = !demo; Msg(demo ? "Modo demostracion" : "Modo camara"); }
        if (Press(0x48) || Press(0x70)) help = !help;
        if (Press(0x4B)) { camReq++; calibrated = false; ovalMode = true; ovalT = 6; Msg("Cambiando de camara..."); }
        if ((Press(0x6B) || Press(0xBB)) && fontCtl) { fIdx = Math.Max(0, fIdx - 1); ApplyFont(); }
        if ((Press(0x6D) || Press(0xBD)) && fontCtl) { fIdx = Math.Min(FSIZES.Length - 1, fIdx + 1); ApplyFont(); }
        if (Press(0x20) && camActive) { if (ovalMode) ovalT = Math.Min(ovalT, 0.01); else { ovalMode = true; ovalT = 3; } }

        // seguimiento
        if (!dumping && GrabFrame())
        {
            if (ovalMode)
            {
                ReadPixels();
                ovalT -= dt;
                if (ovalT <= 0) { LearnSkinOval(); ovalMode = false; seekT = 1.5; calibrated = false; }
            }
            else
            {
                TrackFace();
                if (faceOk) faceSeenT = gt;
                if (seekT > 0)
                {
                    seekT -= dt;
                    if (faceOk) { Calibrate(); seekT = 0; Msg("Calibrado! Ya te imito (ESPACIO para recalibrar)"); }
                    else if (seekT <= 0) { ovalMode = true; ovalT = 4; Msg("No encuentro tu cara: ponla dentro del ovalo"); }
                }
                if (needNeutral > 0 && faceOk) NeutralStep();
                if (needNeutral == 0 && calibrated) ApplyTracking(dt);
            }
        }
        if (!camActive) camWaitT += dt;
        bool useDemo = demo || dumping || (!camActive && camWaitT > 3);
        if (useDemo) DemoParams(gt);
        else if (gt - faceSeenT > 1.0)
        {
            // si te pierde, vuelve poco a poco a la postura neutra
            float k = (float)Math.Min(1, dt * 1.5);
            tYaw = Lf(tYaw, 0, k); tPitch = Lf(tPitch, 0, k); tRoll = Lf(tRoll, 0, k); tX = Lf(tX, 0, k); tY = Lf(tY, 0, k); tZ = Lf(tZ, 0, k);
            tJaw = Lf(tJaw, 0, k); tSmile = Lf(tSmile, 0, k); tBrowL = Lf(tBrowL, 0, k); tBrowR = Lf(tBrowR, 0, k);
            tEyeL = Lf(tEyeL, 1, k); tEyeR = Lf(tEyeR, 1, k); tGx = Lf(tGx, 0, k); tGy = Lf(tGy, 0, k);
            IdleBlink();
        }
        FixParams();
        Smooth(dt);
        breath += (float)dt * 1.6f;

        // render
        float asp = RW / (float)RH;
        camPos = new V(0, -0.15f, -4.2f); camTarget = new V(0, -0.22f, 0);
        camFov = 2 * (float)Math.Atan(Math.Tan(0.385) * asp);
        BeginFrame();
        DrawAvatar();
        RasterAll();
        ShadePass();
        Resolve();
        HudPix();
        ToCells();
        HudText(useDemo);
    }

    // pruebas: AV_FIX=boca,sonrisa,cejas,ojos,giro,arriba,ladear,estilo
    static void FixParams()
    {
        string f = dumping ? Environment.GetEnvironmentVariable("AV_FIX") : null;
        if (string.IsNullOrEmpty(f)) return;
        string[] p = f.Split(',');
        float[] v = new float[8]; for (int i = 0; i < 8 && i < p.Length; i++) v[i] = float.Parse(p[i], CultureInfo.InvariantCulture);
        tJaw = v[0]; tSmile = v[1]; tBrowL = tBrowR = v[2]; tEyeL = tEyeR = v[3]; tYaw = v[4]; tPitch = v[5]; tRoll = v[6]; styleIdx = (int)v[7];
        tX = tY = tZ = 0; tGx = tGy = 0;
    }

    // parpadeo natural cuando no hay medida de los ojos
    static double nextBlink = 2;
    static void IdleBlink()
    {
        if (gt > nextBlink) { if (gt > nextBlink + 0.16) nextBlink = gt + 2.5 + rnd.NextDouble() * 3; else { tEyeL = 0; tEyeR = 0; } }
    }

    // animacion de muestra (sin camara)
    static void DemoParams(double t)
    {
        tYaw = (float)(Math.Sin(t * 0.55) * 0.45); tPitch = (float)(Math.Sin(t * 0.37 + 1) * 0.18); tRoll = (float)(Math.Sin(t * 0.29) * 0.15);
        tX = (float)(Math.Sin(t * 0.23) * 0.15); tY = 0; tZ = (float)(Math.Sin(t * 0.17) * 0.3);
        tJaw = (float)Math.Pow(Math.Max(0, Math.Sin(t * 1.1)), 3) * 0.9f;
        tSmile = (float)(Math.Sin(t * 0.31 + 2) * 0.7 + 0.25);
        tBrowL = tBrowR = (float)(Math.Sin(t * 0.47) * 0.9);
        tEyeL = tEyeR = 1;
        tGx = (float)Math.Sin(t * 0.8) * 0.7f; tGy = (float)Math.Sin(t * 0.53) * 0.4f;
        IdleBlink();
    }

    // ================================================================ interfaz
    static string msg = ""; static double msgT = -9;
    static void Msg(string s) { msg = s; msgT = gt; }
    static int LerpI(int a, int b, float t)
    {
        t = Sat(t);
        int ar = (a >> 16) & 255, ag = (a >> 8) & 255, ab = a & 255;
        return ((int)(ar + (((b >> 16) & 255) - ar) * t) << 16) | ((int)(ag + (((b >> 8) & 255) - ag) * t) << 8) | (int)(ab + ((b & 255) - ab) * t);
    }
    static void PS(int x, int y, int c) { if (x >= 0 && y >= 0 && x < PW && y < PH) pix[y * PW + x] = c; }
    static void Panel(int cx, int cy, int cw, int ch, float a)
    {
        for (int y = Math.Max(0, cy * 2); y < Math.Min(PH, (cy + ch) * 2); y++)
            for (int x = Math.Max(0, cx); x < Math.Min(PW, cx + cw); x++) { int i = y * PW + x; pix[i] = LerpI(pix[i], 0x070A12, a); }
    }

    static int camX0, camY0, camWp, camHp;
    static void HudPix()
    {
        Panel(0, 0, Math.Min(W, 34), 3, 0.6f);
        // medidores a la derecha
        int mw = 30, mx = W - mw - 1;
        Panel(mx - 1, 0, mw + 2, 10, 0.6f);
        float[] vals = { pYaw / 0.75f, pPitch / 0.5f, pRoll / 0.6f, pJaw, pSmile, (pBrowL + pBrowR) / 2, (pEyeL + pEyeR) / 2 };
        bool[] signed = { true, true, true, false, true, true, false };
        for (int k = 0; k < vals.Length; k++)
        {
            int y = (1 + k) * 2 + 1, x0 = mx + 10, bw = mw - 11;
            for (int x = 0; x < bw; x++) PS(x0 + x, y, 0x283040);
            if (signed[k])
            {
                int c = x0 + bw / 2, e = c + (int)(Clampf(vals[k], -1, 1) * bw / 2);
                for (int x = Math.Min(c, e); x <= Math.Max(c, e); x++) PS(x, y, 0x40D0FF);
                PS(c, y, 0xFFFFFF);
            }
            else for (int x = 0; x < (int)(Sat(vals[k]) * bw); x++) PS(x0 + x, y, 0x60FF90);
        }
        // la imagen de tu camara con lo que se detecta
        bool big = ovalMode && camActive && !dumping;
        if ((showCam && camActive) || big)
        {
            camHp = big ? Math.Min(PH - 14, (PW - 4) * 3 / 4) : Math.Max(20, Math.Min(PH / 3, 64)); camWp = camHp * 4 / 3;
            camX0 = big ? (PW - camWp) / 2 : 1; camY0 = big ? 8 : PH - camHp - 4;
            for (int y = 0; y < camHp; y++)
                for (int x = 0; x < camWp; x++)
                {
                    int gx = x * GW / camWp, gy = y * GH / camHp;
                    PS(camX0 + x, camY0 + y, camRGB[gy * GW + gx]);
                }
            if (big)
            {
                for (int k = 0; k < 160; k++)
                {
                    double a = k * Math.PI * 2 / 160;
                    float gx = OVX + (float)Math.Cos(a) * OVA, gy = OVY + (float)Math.Sin(a) * OVB;
                    int px = camX0 + (int)(gx * camWp / GW), py = camY0 + (int)(gy * camHp / GH);
                    PS(px, py, 0xFFFFFF); PS(px + 1, py, 0xFFFFFF);
                }
            }
            else if (faceOk)
            {
                // elipse de la cara
                for (int k = 0; k < 120; k++)
                {
                    double a = k * Math.PI * 2 / 120;
                    float u = (float)Math.Cos(a), v = (float)Math.Sin(a);
                    CamDot(u, v, 0xFFD040);
                }
                if (calibrated)
                {
                    float du = mFeatU - nFeatU, dv = mFeatV - nFeatV;
                    CamBox(eyeUL + du, eyeV + dv, 0.2f, 0.11f, 0x40E0FF);
                    CamBox(eyeUR + du, eyeV + dv, 0.2f, 0.11f, 0x40E0FF);
                    CamBox(du * 0.6f, mouthV + dv * 0.5f + 0.04f, 0.4f, 0.22f, 0xFF70B0);
                }
            }
        }
    }
    static void CamDot(float u, float v, int c)
    {
        float cs = (float)Math.Cos(fang), sn = (float)Math.Sin(fang);
        float dx = u * fhw, dy = v * fhh;
        float gx = fcx + dx * cs - dy * sn, gy = fcy + dx * sn + dy * cs;
        PS(camX0 + (int)(gx * camWp / GW), camY0 + (int)(gy * camHp / GH), c);
    }
    static void CamBox(float cu, float cv, float hu, float hv, int c)
    {
        for (int k = 0; k <= 20; k++)
        {
            float t = k / 20f * 2 - 1;
            CamDot(cu + t * hu, cv - hv, c); CamDot(cu + t * hu, cv + hv, c);
            CamDot(cu - hu, cv + t * hv, c); CamDot(cu + hu, cv + t * hv, c);
        }
    }

    static void HudText(bool useDemo)
    {
        int wh = 0xFFFFFF, gr = 0xA0A8B8, cy = 0x40E0FF, yl = 0xFFD040;
        TS(1, 0, "CABEZA 3D", cy); TS(12, 0, "estilo: " + ST.name, gr);
        string st;
        int sc = gr;
        if (useDemo) { st = demo ? "MODO DEMOSTRACION (D)" : camErr.Length > 0 ? "SIN CAMARA: demostracion" : "Buscando la camara..."; sc = yl; }
        else if (ovalMode) { st = "CALIBRANDO: cara dentro del ovalo"; sc = yl; }
        else if (!faceOk || gt - faceSeenT > 1) { st = "NO TE VEO: ponte delante"; sc = 0xFF6050; }
        else if (!calibrated || needNeutral > 0) { st = "CALIBRANDO..."; sc = yl; }
        else { st = "TE ESTOY IMITANDO"; sc = 0x60FF90; }
        TS(1, 1, st, sc);
        if (camErr.Length > 0 && !demo) TS(1, 2, camErr.Length > W - 2 ? camErr.Substring(0, W - 2) : camErr, 0xFF8070);
        else if (camActive) TS(1, 2, (camName.Length > 20 ? camName.Substring(0, 20) : camName) + " " + camRes, 0x707888);
        int mx = W - 31;
        string[] names = { "GIRO", "ARRIBA", "LADEAR", "BOCA", "SONRISA", "CEJAS", "OJOS" };
        for (int k = 0; k < names.Length; k++) TS(mx, 1 + k, names[k], wh);
        TS(mx, 8, "(cada barra es un gesto)", 0x707888);
        if (gt - msgT < 4 && msg.Length > 0) TSC(4, msg, yl);
        if (ovalMode && camActive && !dumping)
        {
            TSC(2, "PON TU CARA DENTRO DEL OVALO", yl);
            TSC(3, "relajada, mirando al frente  -  calibrando en " + Math.Max(0, (int)Math.Ceiling(ovalT)) + "  (ESPACIO: ya)", 0xFFFFFF);
        }
        else if (showCam && camActive) TS(1, H - 3, "tu camara (TAB)", gr);
        if (help)
        {
            string[] L = { "ESPACIO  recalibrar (cara relajada, mirando al frente)", "TAB      ver/ocultar tu camara", "C        cambiar de estilo de cabeza", "G        invertir izquierda/derecha", "K        cambiar de camara", "D        modo demostracion", "+ / -    mas o menos detalle", "ESC      salir" };
            for (int i = 0; i < L.Length; i++) TS(W / 2 - 28, H / 2 - 4 + i, L[i], wh);
        }
        TSC(H - 1, "ESPACIO recalibrar   TAB camara   C estilo   G espejo   H ayuda   ESC salir     " + (int)Math.Round(fps) + " fps", 0x8890A0);
    }

    // ================================================================ modo de prueba
    public static void Dump(int w, int h, string path, double[] times)
    {
        dumping = true; W = w; H = h; Alloc(); Init();
        using (StreamWriter o = new StreamWriter(path, false, new UTF8Encoding(false)))
        {
            double T = 0, dt = 1.0 / 30; int k = 0;
            Stopwatch sw = Stopwatch.StartNew(); int frames = 0;
            while (k < times.Length)
            {
                Frame(dt); T += dt; frames++;
                if (T >= times[k])
                {
                    o.WriteLine("F " + T.ToString("0.00", CultureInfo.InvariantCulture) + " yaw=" + pYaw.ToString("0.00") + " jaw=" + pJaw.ToString("0.00") + " smile=" + pSmile.ToString("0.00") + " ms=" + (sw.Elapsed.TotalMilliseconds / frames).ToString("0", CultureInfo.InvariantCulture) + " tris=" + nT);
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
    static void ToCells()
    {
        for (int y = 0; y < H; y++)
            for (int x = 0; x < W; x++)
            {
                int t = pix[(2 * y) * PW + x] & 0xF8F8F8, b = pix[(2 * y + 1) * PW + x] & 0xF8F8F8, i = y * W + x;
                if (t == b) { cb[i] = ' '; cc[i] = 0; cbg[i] = b; } else { cb[i] = UPB; cc[i] = t; cbg[i] = b; }
            }
    }
    static void TC(int x, int y, char ch, int fg)
    {
        if (x < 0 || y < 0 || x >= W || y >= H) return;
        int i = y * W + x;
        if (cb[i] == UPB) cbg[i] = LerpI(cc[i], cbg[i], 0.5f);
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
[Cabeza3D]::Run()
exit 0
