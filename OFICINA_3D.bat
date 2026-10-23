<# : -------- parte BATCH (PowerShell la ve como un comentario) --------
@echo off
setlocal
title OFICINA 3D
color 0F
cls
echo.
echo   [*] OFICINA 3D - controla al personaje con tus manos y la camara
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

public static class Oficina
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

    // ================================================================ materiales
    const int M_WALL = 0, M_FLOOR = 1, M_DESK = 2, M_METAL = 3, M_DARK = 4, M_LIGHT = 5, M_SCREEN = 6, M_KEYS = 7, M_PAPER = 8, M_LEAF = 9,
        M_SOIL = 10, M_POT = 11, M_SKIN = 12, M_HAIR = 13, M_SHIRT = 14, M_PANTS = 15, M_SHOE = 16, M_CERAMIC = 17, M_SKY = 18, M_POSTER = 19,
        M_CLOCK = 20, M_BOOK = 21, M_RUG = 22, M_BULB = 23, M_CHAIR = 24, M_LED = 25, M_RUBBER = 26, M_COFFEE = 27, M_WOODD = 28, M_TINT = 29, M_TINTS = 30, M_PHONE = 31, NMAT = 32;
    static bool[] matTwo = new bool[NMAT];

    public class Inst { public V tint = new V(1, 1, 1); public int[] tex; public int tw, th; public bool noShadow; public float glow; public int tag; }
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

    // ---------------------------------------------------------------- mapa de sombras del sol
    const int SM = 400;
    static float[] smap = new float[SM * SM];
    static V sunDir = new V(0.82f, -0.5f, 0.28f).Norm(), sLr, sLu;
    static float sMinR, sMinU, sScR, sScU;

    static void ShadowPass()
    {
        sLr = Cross(new V(0, 1, 0), sunDir).Norm(); sLu = Cross(sunDir, sLr);
        float minR = 1e9f, maxR = -1e9f, minU = 1e9f, maxU = -1e9f;
        for (int i = 0; i < 8; i++)
        {
            V c = new V((i & 1) == 0 ? -1.9f : 2.1f, (i & 2) == 0 ? 0f : 3.4f, (i & 4) == 0 ? -1.2f : 1.7f);
            float r = Dot(c, sLr), u = Dot(c, sLu);
            minR = Math.Min(minR, r); maxR = Math.Max(maxR, r); minU = Math.Min(minU, u); maxU = Math.Max(maxU, u);
        }
        sMinR = minR; sMinU = minU; sScR = SM / (maxR - minR); sScU = SM / (maxU - minU);
        for (int i = 0; i < smap.Length; i++) smap[i] = 1e9f;
        for (int t = 0; t < nT; t++)
        {
            if (insts[tI[t]].noShadow) continue;
            V A = fP[tA[t]], B = fP[tB[t]], C = fP[tC[t]];
            float x0 = (Dot(A, sLr) - sMinR) * sScR, y0 = (Dot(A, sLu) - sMinU) * sScU, d0 = Dot(A, sunDir);
            float x1 = (Dot(B, sLr) - sMinR) * sScR, y1 = (Dot(B, sLu) - sMinU) * sScU, d1 = Dot(B, sunDir);
            float x2 = (Dot(C, sLr) - sMinR) * sScR, y2 = (Dot(C, sLu) - sMinU) * sScU, d2 = Dot(C, sunDir);
            float area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0);
            if (area > -1e-6f && area < 1e-6f) continue;
            float ia = 1f / area;
            int minx = Math.Max(0, (int)Math.Floor(Math.Min(x0, Math.Min(x1, x2)))), maxx = Math.Min(SM - 1, (int)Math.Ceiling(Math.Max(x0, Math.Max(x1, x2))));
            int miny = Math.Max(0, (int)Math.Floor(Math.Min(y0, Math.Min(y1, y2)))), maxy = Math.Min(SM - 1, (int)Math.Ceiling(Math.Max(y0, Math.Max(y1, y2))));
            for (int py = miny; py <= maxy; py++)
                for (int px = minx; px <= maxx; px++)
                {
                    float fx = px + 0.5f, fy = py + 0.5f;
                    float w0 = ((x1 - fx) * (y2 - fy) - (x2 - fx) * (y1 - fy)) * ia; if (w0 < 0) continue;
                    float w1 = ((x2 - fx) * (y0 - fy) - (x0 - fx) * (y2 - fy)) * ia; if (w1 < 0) continue;
                    float w2 = 1 - w0 - w1; if (w2 < 0) continue;
                    float d = w0 * d0 + w1 * d1 + w2 * d2;
                    int i = py * SM + px;
                    if (d < smap[i]) smap[i] = d;
                }
        }
    }

    static float SunVis(V p, V n)
    {
        V q = p + n * 0.012f;
        float fx = (Dot(q, sLr) - sMinR) * sScR - 0.5f, fy = (Dot(q, sLu) - sMinU) * sScU - 0.5f, d = Dot(q, sunDir) - 0.012f;
        int x0 = (int)Math.Floor(fx), y0 = (int)Math.Floor(fy);
        float lit = 0;
        for (int j = -1; j <= 1; j++)
            for (int i = -1; i <= 1; i++)
            {
                int x = x0 + i, y = y0 + j;
                if (x < 0 || y < 0 || x >= SM || y >= SM) { lit += 1; continue; }
                if (smap[y * SM + x] >= d) lit += 1;
            }
        return lit / 9f;
    }

    // ---------------------------------------------------------------- sombreado de cada pixel
    static float[] hR, hG, hB;
    static V lampPos = new V(-0.46f, 1.2f, 0.7f), lampDir = new V(0.25f, -1, -0.1f).Norm();
    static V monPos = new V(0, 1.08f, 0.8f);

    static void ShadePass()
    {
        int n = RW * RH;
        V amb1 = C3(70, 74, 88), amb2 = C3(60, 48, 38);
        V sunCol = C3(255, 226, 180) * 1.35f, lampCol = C3(255, 196, 120) * 1.6f, monCol = C3(120, 160, 255) * 0.55f, ceilCol = C3(255, 245, 230) * 0.45f;
        V ceilPos = new V(0.2f, 2.6f, 0.2f);
        for (int idx = 0; idx < n; idx++)
        {
            int t = tidb[idx];
            if (t < 0) { hR[idx] = 0.02f; hG[idx] = 0.02f; hB[idx] = 0.03f; continue; }
            int a = tA[t], b = tB[t], c = tC[t];
            float w1 = bA[idx], w2 = bB[idx], w0 = 1 - w1 - w2;
            V P = fP[a] * w0 + fP[b] * w1 + fP[c] * w2;
            V N = (fN[a] * w0 + fN[b] * w1 + fN[c] * w2).Norm();
            float u = fU[a] * w0 + fU[b] * w1 + fU[c] * w2, v = fVv[a] * w0 + fVv[b] * w1 + fVv[c] * w2;
            V toC = (camPos - P).Norm();
            int mat = tM[t];
            if (matTwo[mat] && Dot(N, toC) < 0) N = -N;
            float spec = 0, shin = 16, emit = 0;
            V alb = Albedo(mat, insts[tI[t]], P, N, u, v, ref spec, ref shin, ref emit);
            V col;
            if (emit >= 1) col = alb;
            else
            {
                float hemi = N.y * 0.5f + 0.5f;
                V light = LerpV(amb2, amb1, hemi) * (lampOn ? 1.0f : 0.85f);
                V specAcc = new V(0, 0, 0);
                // sol por la ventana
                float ndl = -Dot(N, sunDir);
                if (ndl > 0)
                {
                    float vis = SunVis(P, N);
                    if (vis > 0)
                    {
                        light = light + sunCol * (ndl * vis);
                        if (spec > 0) { V hv = (toC - sunDir).Norm(); specAcc = specAcc + sunCol * (spec * vis * (float)Math.Pow(Math.Max(0, Dot(N, hv)), shin)); }
                    }
                }
                // luz del techo
                {
                    V d = ceilPos - P; float l2 = Dot(d, d); V L = d * (1f / (float)Math.Sqrt(l2));
                    float nd = Dot(N, L); if (nd > 0) light = light + ceilCol * (nd * 2.2f / (1 + l2));
                }
                // flexo
                if (lampOn)
                {
                    V d = lampPos - P; float l2 = Dot(d, d); V L = d * (1f / (float)Math.Sqrt(l2));
                    float nd = Dot(N, L);
                    float spot = SStep(0.55f, 0.85f, -Dot(L, lampDir));
                    if (nd > 0 && spot > 0)
                    {
                        float at = spot / (0.15f + l2 * 3f);
                        light = light + lampCol * (nd * at);
                        if (spec > 0) { V hv = (toC + L).Norm(); specAcc = specAcc + lampCol * (spec * at * (float)Math.Pow(Math.Max(0, Dot(N, hv)), shin)); }
                    }
                }
                // brillo de la pantalla encendida
                if (pcOn)
                {
                    V d = monPos - P; float l2 = Dot(d, d); V L = d * (1f / (float)Math.Sqrt(l2));
                    float nd = Dot(N, L); float front = SStep(-0.2f, 0.3f, -L.z);
                    if (nd > 0) light = light + monCol * (nd * front * screenLum / (0.2f + l2 * 5f));
                }
                col = Mul(alb, light) + specAcc;
                if (emit > 0) col = col + alb * emit;
            }
            hR[idx] = col.x; hG[idx] = col.y; hB[idx] = col.z;
        }
    }

    // reduce el supermuestreo 2x2 y aplica tono y gamma
    static void Resolve()
    {
        for (int y = 0; y < PH; y++)
            for (int x = 0; x < PW; x++)
            {
                int i0 = (y * 2) * RW + x * 2, i1 = i0 + 1, i2 = i0 + RW, i3 = i2 + 1;
                float r = (hR[i0] + hR[i1] + hR[i2] + hR[i3]) * 0.25f, g = (hG[i0] + hG[i1] + hG[i2] + hG[i3]) * 0.25f, b = (hB[i0] + hB[i1] + hB[i2] + hB[i3]) * 0.25f;
                float vx = (x - PW * 0.5f) / PW, vy = (y - PH * 0.5f) / PH, vig = 1 - (vx * vx + vy * vy) * 0.55f;
                r = r * vig / (1 + r * 0.18f); g = g * vig / (1 + g * 0.18f); b = b * vig / (1 + b * 0.18f);
                int R = (int)(Math.Sqrt(Sat(r)) * 255), G = (int)(Math.Sqrt(Sat(g)) * 255), B = (int)(Math.Sqrt(Sat(b)) * 255);
                pix[y * PW + x] = (R << 16) | (G << 8) | B;
            }
    }
    // ================================================================ materiales procedurales
    static void InitMats()
    {
        matTwo[M_PAPER] = true; matTwo[M_LEAF] = true; matTwo[M_SKY] = true; matTwo[M_SCREEN] = true; matTwo[M_KEYS] = true;
        matTwo[M_POSTER] = true; matTwo[M_CLOCK] = true; matTwo[M_RUG] = true; matTwo[M_WALL] = true; matTwo[M_FLOOR] = true;
    }

    static V Wood(float a, float b, V c1, V c2)
    {
        float n = Noise(a * 3, b * 3, 5);
        float ring = (float)Math.Sin((a + n * 0.35f) * 34) * 0.5f + 0.5f;
        float fine = Noise(a * 40, b * 2, 6);
        return LerpV(c1, c2, ring * 0.6f + fine * 0.4f);
    }

    static int Tex(int[] tex, int tw, int th, float u, float v)
    {
        int x = (int)(Fr(u) * tw), y = (int)(Fr(v) * th);
        if (x >= tw) x = tw - 1; if (y >= th) y = th - 1;
        return tex[y * tw + x];
    }
    static V TexV(int c) { return new V(((c >> 16) & 255) / 255f, ((c >> 8) & 255) / 255f, (c & 255) / 255f); }

    static V Albedo(int mat, Inst ins, V P, V N, float u, float v, ref float spec, ref float shin, ref float emit)
    {
        switch (mat)
        {
            case M_WALL:
            {
                float n = Noise(P.x * 9 + P.z * 9, P.y * 9, 1) * 0.06f + Noise(P.x * 40 + P.z * 40, P.y * 40, 2) * 0.03f;
                V c = C3(208, 198, 178) * (0.93f + n);
                if (P.y < 0.1f) c = C3(235, 232, 225);
                return c;
            }
            case M_FLOOR:
            {
                float pw = 0.16f; int plank = (int)Math.Floor(P.z / pw);
                float along = P.x + Hash(plank, 0, 3) * 2.3f;
                int seg = (int)Math.Floor(along / 1.1f);
                V c = Wood(along, P.z * 2, C3(128, 84, 50), C3(166, 114, 70)) * (0.85f + 0.3f * Hash(plank, seg, 4));
                if (Fr(P.z / pw) < 0.035f || Fr(along / 1.1f) < 0.008f) c = c * 0.45f;
                spec = 0.35f; shin = 40;
                return c;
            }
            case M_DESK:
            {
                spec = 0.4f; shin = 45;
                if (Math.Abs(N.y) > 0.7f) return Wood(P.x * 1.2f, P.z * 8, C3(150, 98, 58), C3(190, 136, 84));
                return Wood(P.x * 1.2f + P.z, P.y * 8, C3(120, 76, 44), C3(160, 108, 64));
            }
            case M_METAL: spec = 0.8f; shin = 70; return C3(150, 152, 160);
            case M_DARK: spec = 0.45f; shin = 50; return C3(26, 26, 30);
            case M_LIGHT: spec = 0.35f; shin = 40; return C3(212, 212, 218);
            case M_SCREEN:
            {
                if (!pcOn) { spec = 1.2f; shin = 90; return C3(8, 9, 12); }
                emit = 1;
                V c = TexV(Tex(scr, STW, STH, u, v)) * screenLum;
                return c * 1.25f;
            }
            case M_KEYS:
            {
                // teclado: 5 filas de teclas; la tecla pulsada o apuntada se ilumina
                float rows = 5, cols = 14;
                int r = (int)(v * rows), k = (int)(u * cols);
                float fu = Fr(u * cols), fv = Fr(v * rows);
                if (r == 4) { if (u > 0.25f && u < 0.72f) { k = 99; fu = (u - 0.25f) / 0.47f; } }
                bool gap = fu < 0.1f || fu > 0.9f || fv < 0.12f || fv > 0.88f;
                if (r == 4 && k != 99) gap = true;
                V c = gap ? C3(12, 12, 14) : C3(40, 40, 46);
                int key = r * 20 + (k == 99 ? 19 : k);
                if (!gap)
                {
                    if (key == keyPress && gt - keyPressT < 0.25f) { c = C3(120, 200, 255); emit = 0.8f; }
                    else if (key == keyHoverL || key == keyHoverR) c = C3(70, 80, 110);
                    if (fu > 0.35f && fu < 0.55f && fv > 0.3f && fv < 0.55f && Hash(key, 1, 9) > 0.2f) c = C3(170, 170, 180);
                    spec = 0.3f; shin = 30;
                }
                return c;
            }
            case M_PAPER:
            {
                V c = C3(238, 236, 228);
                if (ins.tex != null) return TexV(Tex(ins.tex, ins.tw, ins.th, u, v));
                float lv = v * 34; int line = (int)lv;
                if (line > 2 && line < 31 && Fr(lv) < 0.3f && u > 0.12f && u < 0.12f + 0.76f * (0.4f + 0.6f * Hash(line, ins.tag, 7))) c = C3(150, 150, 160);
                return c;
            }
            case M_LEAF:
            {
                spec = 0.25f; shin = 20;
                float vein = Math.Abs(u - 0.5f) < 0.04f ? 1.25f : 1;
                return ins.tint * ((0.8f + 0.25f * Noise(u * 8, v * 8, 11)) * vein);
            }
            case M_SOIL: return C3(56, 38, 26) * (0.7f + 0.5f * Noise(P.x * 60, P.z * 60, 12));
            case M_POT: spec = 0.15f; return C3(170, 86, 52) * (Fr(P.y * 10) < 0.1f ? 0.8f : 1);
            case M_SKIN: spec = 0.18f; shin = 14; return C3(222, 168, 132);
            case M_HAIR: spec = 0.35f; shin = 25; return C3(46, 28, 18) * (0.75f + 0.4f * Noise(u * 40, v * 6, 13));
            case M_SHIRT: return ins.tint * (0.9f + 0.1f * Noise(P.x * 70, P.y * 70 + P.z * 70, 14));
            case M_PANTS: return C3(40, 48, 70) * (0.9f + 0.1f * Noise(P.x * 60, P.y * 60, 15));
            case M_SHOE: spec = 0.5f; shin = 30; return C3(20, 20, 22);
            case M_CERAMIC: spec = 0.7f; shin = 60; return ins.tint;
            case M_SKY:
            {
                emit = 1;
                // cielo, sol y edificios a lo lejos
                V sky = LerpV(C3(120, 170, 235), C3(250, 220, 180), Sat(v * 1.2f));
                float dsun = (float)Math.Sqrt((u - 0.25f) * (u - 0.25f) + (v - 0.25f) * (v - 0.25f));
                if (dsun < 0.06f) sky = C3(255, 250, 225); else sky = sky + C3(255, 220, 160) * (0.35f * Sat(1 - dsun * 3));
                int bi = (int)(u * 14);
                float bh = 0.35f + 0.4f * Hash(bi, 0, 21);
                if (1 - v < bh * 0.7f + 0.05f)
                {
                    V bc = LerpV(C3(90, 105, 130), C3(140, 150, 170), Hash(bi, 1, 21));
                    if (Fr(u * 14 * 4) > 0.5f && Fr(v * 40) > 0.5f && Hash((int)(u * 56), (int)(v * 40), 22) > 0.5f) bc = C3(250, 240, 200);
                    sky = bc;
                }
                if (1 - v < 0.08f) sky = C3(70, 120, 70);
                return sky;
            }
            case M_POSTER:
            {
                // atardecer con montanas y un texto
                V c = LerpV(C3(255, 120, 80), C3(255, 210, 120), Sat(v * 1.6f));
                float ds = (float)Math.Sqrt((u - 0.65f) * (u - 0.65f) + (v - 0.45f) * (v - 0.45f) * 0.4f);
                if (ds < 0.13f) c = C3(255, 245, 200);
                float m1 = 0.62f + 0.08f * (float)Math.Sin(u * 9) + 0.04f * (float)Math.Sin(u * 23);
                float m2 = 0.74f + 0.05f * (float)Math.Sin(u * 13 + 1);
                if (v > m1) c = C3(120, 60, 90);
                if (v > m2) c = C3(60, 30, 60);
                if (v < 0.2f && FontPix("SIGUE ADELANTE", (u - 0.12f) / 0.76f, v / 0.2f)) c = C3(255, 255, 255);
                return c;
            }
            case M_CLOCK:
            {
                float dx = u - 0.5f, dy = v - 0.5f, d = (float)Math.Sqrt(dx * dx + dy * dy);
                V c = C3(245, 245, 240);
                if (d > 0.47f) return C3(30, 30, 34);
                DateTime now = DateTime.Now;
                double ang = Math.Atan2(dx, -dy); if (ang < 0) ang += Math.PI * 2;
                for (int h = 0; h < 12; h++) { double a = h * Math.PI / 6; if (Math.Abs(AngD(ang, a)) < 0.03 && d > 0.38f) c = C3(40, 40, 40); }
                double ah = (now.Hour % 12 + now.Minute / 60.0) / 12 * Math.PI * 2, am = (now.Minute + now.Second / 60.0) / 60 * Math.PI * 2, asec = now.Second / 60.0 * Math.PI * 2;
                if (HandHit(dx, dy, ah, 0.25f, 0.035f)) c = C3(20, 20, 20);
                if (HandHit(dx, dy, am, 0.38f, 0.025f)) c = C3(20, 20, 20);
                if (HandHit(dx, dy, asec, 0.4f, 0.012f)) c = C3(220, 30, 30);
                return c;
            }
            case M_BOOK: spec = 0.2f; return ins.tint * (u < 0.1f || u > 0.9f ? 0.7f : 1);
            case M_RUG:
            {
                float bx = Math.Min(u, 1 - u), by = Math.Min(v, 1 - v), e = Math.Min(bx, by);
                V c = C3(120, 40, 40);
                if (e < 0.06f) c = C3(200, 170, 110); else if (e < 0.09f) c = C3(60, 30, 30);
                else if (Math.Abs(Fr(u * 6) - 0.5f) + Math.Abs(Fr(v * 4) - 0.5f) < 0.25f) c = C3(170, 120, 70);
                return c * (0.9f + 0.1f * Noise(u * 120, v * 120, 16));
            }
            case M_BULB: if (lampOn) { emit = 1; return C3(255, 240, 200) * 1.6f; } return C3(200, 200, 190);
            case M_CHAIR: return C3(34, 34, 40) * (0.85f + 0.2f * Noise(P.x * 90, P.y * 90 + P.z * 90, 17));
            case M_LED: emit = 1; return ins.tint;
            case M_RUBBER: return C3(18, 18, 20);
            case M_COFFEE: spec = 0.9f; shin = 80; return C3(60, 32, 16);
            case M_WOODD: spec = 0.3f; shin = 30; return Wood(P.x * 2 + P.z, P.y * 6, C3(80, 50, 30), C3(110, 72, 44));
            case M_TINTS: spec = 0.5f; shin = 40; return ins.tint;
            case M_PHONE:
            {
                spec = 0.8f; shin = 80;
                if (N.y > 0.7f && u > 0.08f && u < 0.92f && v > 0.06f && v < 0.94f)
                {
                    if (gt - phoneT < 3) { emit = 1; return LerpV(C3(40, 120, 255), C3(220, 60, 200), v); }
                    return C3(6, 6, 10);
                }
                return C3(30, 30, 34);
            }
            default: return ins.tint;
        }
    }

    static double AngD(double a, double b) { double d = a - b; while (d > Math.PI) d -= Math.PI * 2; while (d < -Math.PI) d += Math.PI * 2; return d; }
    static bool HandHit(float dx, float dy, double ang, float len, float w)
    {
        float hx = (float)Math.Sin(ang), hy = -(float)Math.Cos(ang);
        float t = dx * hx + dy * hy;
        if (t < -0.04f || t > len) return false;
        float px = dx - hx * t, py = dy - hy * t;
        return px * px + py * py < w * w;
    }

    // ---------------------------------------------------------------- fuente 3x5
    static readonly Dictionary<char, string> F3 = new Dictionary<char, string>();
    static void InitFont()
    {
        string[] t = {
            "A.#.|#.#|###|#.#|#.#", "B##.|#.#|##.|#.#|##.", "C.##|#..|#..|#..|.##", "D##.|#.#|#.#|#.#|##.", "E###|#..|##.|#..|###",
            "F###|#..|##.|#..|#..", "G.##|#..|#.#|#.#|.##", "H#.#|#.#|###|#.#|#.#", "I###|.#.|.#.|.#.|###", "J..#|..#|..#|#.#|.#.",
            "K#.#|#.#|##.|#.#|#.#", "L#..|#..|#..|#..|###", "M#.#|###|###|#.#|#.#", "N##.|#.#|#.#|#.#|#.#", "O.#.|#.#|#.#|#.#|.#.",
            "P##.|#.#|##.|#..|#..", "Q.#.|#.#|#.#|##.|.##", "R##.|#.#|##.|#.#|#.#", "S.##|#..|.#.|..#|##.", "T###|.#.|.#.|.#.|.#.",
            "U#.#|#.#|#.#|#.#|###", "V#.#|#.#|#.#|#.#|.#.", "W#.#|#.#|###|###|#.#", "X#.#|#.#|.#.|#.#|#.#", "Y#.#|#.#|.#.|.#.|.#.",
            "Z###|..#|.#.|#..|###", "0###|#.#|#.#|#.#|###", "1.#.|##.|.#.|.#.|###", "2###|..#|###|#..|###", "3###|..#|.##|..#|###",
            "4#.#|#.#|###|..#|..#", "5###|#..|###|..#|###", "6###|#..|###|#.#|###", "7###|..#|.#.|.#.|.#.", "8###|#.#|###|#.#|###",
            "9###|#.#|###|..#|###", "!.#.|.#.|.#.|...|.#.", "-...|...|###|...|...", " ...|...|...|...|...", ":...|.#.|...|.#.|...",
            "+...|.#.|###|.#.|...", "?##.|..#|.#.|...|.#.", "/..#|..#|.#.|#..|#..", ",...|...|...|.#.|#..", "_...|...|...|...|###" };
        foreach (string g in t) F3[g[0]] = g.Substring(1).Replace("|", "");
        F3['.'] = "............#..";
    }

    // texto "pintado" en coordenadas normalizadas (para texturas)
    static bool FontPix(string s, float fu, float fv)
    {
        if (fu < 0 || fu >= 1 || fv < 0 || fv >= 1) return false;
        float cw = 1f / s.Length;
        int ci = (int)(fu / cw); float lu = (fu - ci * cw) / cw;
        int gx = (int)(lu * 4), gy = (int)(fv * 5);
        if (gx > 2) return false;
        string g; if (!F3.TryGetValue(char.ToUpperInvariant(s[ci]), out g)) return false;
        return g[gy * 3 + gx] == '#';
    }

    static void TexText(int[] tex, int tw, int th, string s, int x, int y, int col)
    {
        foreach (char ch0 in s)
        {
            char ch = char.ToUpperInvariant(ch0);
            string g; if (!F3.TryGetValue(ch, out g)) g = F3[' '];
            for (int r = 0; r < 5; r++) for (int c = 0; c < 3; c++)
                    if (g[r * 3 + c] == '#') { int px = x + c, py = y + r; if (px >= 0 && py >= 0 && px < tw && py < th) tex[py * tw + px] = col; }
            x += 4;
        }
    }
    static void TexRect(int[] tex, int tw, int th, int x, int y, int w, int h, int col)
    {
        for (int yy = Math.Max(0, y); yy < Math.Min(th, y + h); yy++) for (int xx = Math.Max(0, x); xx < Math.Min(tw, x + w); xx++) tex[yy * tw + xx] = col;
    }
    // ================================================================ el ordenador (textura de la pantalla)
    const int STW = 160, STH = 100;
    static int[] scr = new int[STW * STH];
    static bool pcOn; static double pcT; static float screenLum;
    static int osState;  // 0 apagado, 1 bios, 2 logo, 3 escritorio, 4 notas, 5 paint, 6 apagando
    static StringBuilder notes = new StringBuilder();
    static int[] canvas = new int[STW * STH];
    static float curX = 80, curY = 50; static double dwellT; static int dwellOn = -1, lastClick = -1;
    static int paintCol = 0x202020;
    static readonly int[] PALETTE = { 0x202020, 0xE03030, 0x30A040, 0x3060E0, 0xF0C020, 0xFFFFFF };

    static void PcToggle()
    {
        if (!pcOn) { pcOn = true; pcT = 0; osState = 1; Msg("Has encendido el ordenador"); }
        else if (osState != 6) { osState = 6; pcT = 0; Msg("Apagando el ordenador..."); }
    }

    static void OsUpdate(double dt)
    {
        if (!pcOn) { screenLum = 0; return; }
        pcT += dt;
        screenLum = Math.Min(1, screenLum + (float)dt * 2);
        if (osState == 1 && pcT > 2.2) { osState = 2; pcT = 0; }
        else if (osState == 2 && pcT > 2.0) { osState = 3; pcT = 0; }
        else if (osState == 6 && pcT > 1.8) { pcOn = false; osState = 0; screenLum = 0; }
        // clic por permanencia: mantener el cursor quieto sobre un boton
        int hit = HitTest();
        if (hit != lastClick) lastClick = -1;
        if (hit >= 0 && hit == dwellOn && hit != lastClick) { dwellT += dt; if (dwellT > 1.1) { Click(hit); dwellT = 0; lastClick = hit; } }
        else if (hit != dwellOn) { dwellOn = hit; dwellT = 0; }
        if (osState == 5 && mouseHeld) PaintAt((int)curX, (int)curY);
        DrawScreen();
    }

    // botones: 1 notas, 2 paint, 3 apagar, 10 cerrar ventana, 11 imprimir, 20+ colores
    static int HitTest()
    {
        int x = (int)curX, y = (int)curY;
        if (osState == 3)
        {
            for (int i = 0; i < 3; i++) if (x >= 8 && x < 30 && y >= 8 + i * 26 && y < 30 + i * 26) return i + 1;
        }
        if (osState == 4 || osState == 5)
        {
            if (x >= STW - 14 && y < 10) return 10;
            if (x >= STW - 54 && x < STW - 18 && y < 10) return 11;
            if (osState == 5) for (int i = 0; i < PALETTE.Length; i++) if (x >= 4 + i * 12 && x < 14 + i * 12 && y >= STH - 18 && y < STH - 10) return 20 + i;
        }
        return -1;
    }

    static void Click(int b)
    {
        if (b == 1) { osState = 4; Msg("Abriendo las notas"); }
        else if (b == 2) { osState = 5; for (int i = 0; i < canvas.Length; i++) canvas[i] = 0xFFFFFF; Msg("Abriendo Paint: mueve el raton para dibujar"); }
        else if (b == 3) { osState = 6; pcT = 0; Msg("Apagando el ordenador..."); }
        else if (b == 10) osState = 3;
        else if (b == 11) Print();
        else if (b >= 20) paintCol = PALETTE[b - 20];
    }

    static void PaintAt(int x, int y)
    {
        for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++)
            {
                int px = x + dx, py = y + dy;
                if (px >= 2 && px < STW - 2 && py >= 12 && py < STH - 20) canvas[py * STW + px] = paintCol;
            }
    }

    static void TypeKey(char ch)
    {
        if (!pcOn || osState < 3 || osState > 5) return;
        if (osState == 3 || osState == 5) { osState = 4; }
        if (ch == '\b') { if (notes.Length > 0) notes.Length--; }
        else if (ch == '\n') notes.Append('\n');
        else if (notes.Length < 400) notes.Append(ch);
    }

    static void DrawScreen()
    {
        int[] s = scr;
        if (osState == 1)
        {
            TexRect(s, STW, STH, 0, 0, STW, STH, 0x000000);
            string[] lines = { "BIOS v2.6 OFICINA", "CPU ... OK", "MEMORIA 16384 MB OK", "DISCO ... OK", "TECLADO ... OK", "RATON ... OK", "ARRANCANDO..." };
            int n = Math.Min(lines.Length, (int)(pcT * 4));
            for (int i = 0; i < n; i++) TexText(s, STW, STH, lines[i], 4, 4 + i * 8, 0xC0C0C0);
            return;
        }
        if (osState == 2 || osState == 6)
        {
            for (int y = 0; y < STH; y++) for (int x = 0; x < STW; x++) s[y * STW + x] = Lerp(0x0A1A40, 0x2050A0, y / (float)STH);
            int lx = STW / 2 - 12, ly = STH / 2 - 18;
            TexRect(s, STW, STH, lx, ly, 11, 11, 0xF04020); TexRect(s, STW, STH, lx + 13, ly, 11, 11, 0x40C040);
            TexRect(s, STW, STH, lx, ly + 13, 11, 11, 0x3080F0); TexRect(s, STW, STH, lx + 13, ly + 13, 11, 11, 0xF0C020);
            string t = osState == 2 ? "OFICINA OS" : "APAGANDO...";
            TexText(s, STW, STH, t, STW / 2 - t.Length * 2, ly + 30, 0xFFFFFF);
            for (int k = 0; k < 8; k++)
            {
                double a = pcT * 6 + k * Math.PI / 4;
                int px = STW / 2 + (int)(Math.Cos(a) * 6), py = ly + 46 + (int)(Math.Sin(a) * 6);
                int c = Lerp(0x303060, 0xFFFFFF, k / 8f);
                TexRect(s, STW, STH, px, py, 2, 2, c);
            }
            return;
        }
        // escritorio
        for (int y = 0; y < STH; y++) for (int x = 0; x < STW; x++)
            {
                float w = (float)Math.Sin(x * 0.05 + y * 0.03 + gt * 0.3) * 0.5f + 0.5f;
                s[y * STW + x] = Lerp(Lerp(0x1A5080, 0x40A0C0, y / (float)STH), 0x60C0D0, w * 0.25f);
            }
        string[] names = { "NOTAS", "PAINT", "APAGAR" };
        int[] icol = { 0xF0E070, 0xF06090, 0xE04040 };
        for (int i = 0; i < 3; i++)
        {
            int y0 = 8 + i * 26;
            bool hov = osState == 3 && dwellOn == i + 1;
            TexRect(s, STW, STH, 10, y0, 18, 14, hov ? 0xFFFFFF : icol[i]);
            TexRect(s, STW, STH, 12, y0 + 2, 14, 10, Lerp(icol[i], 0x000000, 0.25f));
            TexText(s, STW, STH, names[i], 19 - names[i].Length * 2, y0 + 16, 0xFFFFFF);
        }
        // barra de tareas con la hora
        TexRect(s, STW, STH, 0, STH - 8, STW, 8, 0x101828);
        TexRect(s, STW, STH, 2, STH - 7, 10, 6, 0x3080F0);
        TexText(s, STW, STH, DateTime.Now.ToString("HH:mm", CultureInfo.InvariantCulture), STW - 22, STH - 7, 0xFFFFFF);
        if (osState == 4)
        {
            Window(s, "NOTAS", 0xFFFFF0);
            int x = 6, y = 14;
            string txt = notes.ToString();
            foreach (char ch in txt)
            {
                if (ch == '\n' || x > STW - 10) { x = 6; y += 7; if (ch == '\n') continue; }
                if (y > STH - 18) break;
                TexText(s, STW, STH, ch.ToString(), x, y, 0x202020); x += 4;
            }
            if (((int)(gt * 2)) % 2 == 0 && y <= STH - 18) TexRect(s, STW, STH, x, y, 1, 5, 0x202020);
            if (txt.Length == 0) TexText(s, STW, STH, "TECLEA CON LOS DEDOS...", 6, 14, 0x909090);
        }
        if (osState == 5)
        {
            Window(s, "PAINT", 0xFFFFFF);
            for (int y = 12; y < STH - 20; y++) for (int x = 2; x < STW - 2; x++) s[y * STW + x] = canvas[y * STW + x];
            for (int i = 0; i < PALETTE.Length; i++)
            {
                TexRect(s, STW, STH, 4 + i * 12, STH - 18, 10, 8, PALETTE[i]);
                if (PALETTE[i] == paintCol) TexRect(s, STW, STH, 4 + i * 12, STH - 9, 10, 1, 0x000000);
            }
        }
        // cursor con anillo de "clic por permanencia"
        int cx = (int)curX, cy = (int)curY;
        if (dwellT > 0.15 && dwellOn >= 0)
        {
            double f = Math.Min(1, dwellT / 1.1);
            for (int k = 0; k < 24; k++) if (k < f * 24) { double a = k / 24.0 * Math.PI * 2 - Math.PI / 2; TexRect(s, STW, STH, cx + (int)(Math.Cos(a) * 6), cy + (int)(Math.Sin(a) * 6), 1, 1, 0xFFE040); }
        }
        string[] arrow = { "X.....", "XX....", "XWX...", "XWWX..", "XWWWX.", "XWWWWX", "XWWXXX", "XX.XX.", "X...XX" };
        for (int r = 0; r < arrow.Length; r++) for (int c = 0; c < 6; c++)
            {
                char ch = arrow[r][c]; if (ch == '.') continue;
                int px = cx + c, py = cy + r;
                if (px >= 0 && py >= 0 && px < STW && py < STH) s[py * STW + px] = ch == 'X' ? 0x000000 : 0xFFFFFF;
            }
    }

    static void Window(int[] s, string title, int bg)
    {
        TexRect(s, STW, STH, 0, 0, STW, STH - 8, bg);
        TexRect(s, STW, STH, 0, 0, STW, 10, 0x2050A0);
        TexText(s, STW, STH, title, 4, 3, 0xFFFFFF);
        bool hov = dwellOn == 10;
        TexRect(s, STW, STH, STW - 14, 1, 12, 8, hov ? 0xFF8080 : 0xD03030);
        TexText(s, STW, STH, "X", STW - 10, 3, 0xFFFFFF);
        TexRect(s, STW, STH, STW - 54, 1, 36, 8, dwellOn == 11 ? 0xFFFFFF : 0xE0E0E0);
        TexText(s, STW, STH, "IMPRIMIR", STW - 52, 3, 0x2050A0);
    }

    static int Lerp(int a, int b, float t)
    {
        t = Sat(t);
        int ar = (a >> 16) & 255, ag = (a >> 8) & 255, ab = a & 255;
        return ((int)(ar + (((b >> 16) & 255) - ar) * t) << 16) | ((int)(ag + (((b >> 8) & 255) - ag) * t) << 8) | (int)(ab + ((b & 255) - ab) * t);
    }

    // textura para un folio impreso: las notas o el dibujo de Paint
    static int[] PrintTex(out int tw, out int th)
    {
        tw = 64; th = 90;
        int[] t = new int[tw * th];
        for (int i = 0; i < t.Length; i++) t[i] = 0xF2F0E8;
        if (osState == 5)
        {
            for (int y = 0; y < th - 10; y++) for (int x = 0; x < tw - 8; x++)
                {
                    int sx = 2 + x * (STW - 4) / (tw - 8), sy = 12 + y * (STH - 32) / (th - 10);
                    t[(y + 5) * tw + x + 4] = canvas[sy * STW + sx];
                }
        }
        else
        {
            TexText(t, tw, th, "NOTAS", 4, 4, 0x3050A0);
            int x = 4, y = 14;
            foreach (char ch in notes.ToString())
            {
                if (ch == '\n' || x > tw - 6) { x = 4; y += 7; if (ch == '\n') continue; }
                if (y > th - 8) break;
                TexText(t, tw, th, ch.ToString(), x, y, 0x202020); x += 4;
            }
            if (notes.Length == 0) TexText(t, tw, th, "HOLA!", 4, 14, 0x202020);
        }
        return t;
    }
    // ================================================================ la oficina
    const float DESK = 0.75f;
    static readonly V KB_C = new V(0, 0.763f, 0.45f);
    const float KB_X0 = -0.21f, KB_X1 = 0.21f, KB_Z0 = 0.385f, KB_Z1 = 0.515f, KB_TOP = 0.7765f;
    static readonly V BTN_PC = new V(0.62f, 1.10f, 0.592f), SW_LAMP = new V(-0.62f, 0.788f, 0.815f), BTN_PR = new V(1.40f, 0.925f, 0.62f);
    static bool lampOn = true;
    static bool[] btnArm = { true, true, true };
    public static double btnPcT = -9, btnLampT = -9, btnPrT = -9, phoneT = -9, keyPressT = -9;
    static int keyPress = -1, keyHoverL = -1, keyHoverR = -1;
    static int binCount;

    struct Box3 { public V mn, mx; public Box3(float x0, float y0, float z0, float x1, float y1, float z1) { mn = new V(x0, y0, z0); mx = new V(x1, y1, z1); } }
    static List<Box3> statics = new List<Box3>();
    static int nStaticFixed;
    static readonly V BIN = new V(-0.58f, 0, 0.0f); const float BIN_R = 0.15f, BIN_H = 0.32f;

    class Part { public Mesh m; public Tf tf; public Inst ins; public Part(Mesh m_, Tf t_, Inst i_) { m = m_; tf = t_; ins = i_; } }
    static List<Part> scene = new List<Part>();

    static Inst In(V tint) { Inst i = new Inst(); i.tint = tint; return i; }
    static Inst NoSh() { Inst i = new Inst(); i.noShadow = true; return i; }
    static void S(Mesh m, Tf t) { scene.Add(new Part(m, t, null)); }
    static void S(Mesh m, Tf t, Inst i) { scene.Add(new Part(m, t, i)); }
    static void Col(float x0, float y0, float z0, float x1, float y1, float z1) { statics.Add(new Box3(x0, y0, z0, x1, y1, z1)); }

    static Tf RYm90 { get { return Tf.Ry(-(float)Math.PI / 2); } }

    static void BuildScene()
    {
        scene.Clear(); statics.Clear();
        Random r = new Random(5);
        // habitacion
        S(MPlane(4.0f, 4.0f, 10, 10, M_FLOOR), Tf.T(0.1f, 0, 0.1f));
        S(MPlane(1.8f, 1.4f, 2, 2, M_RUG), Tf.T(0.05f, 0.003f, 0.05f), NoSh());
        S(MQuad(4.0f, 3.5f, M_WALL), Tf.T(0.1f, 1.75f, 1.6f));
        S(MQuad(4.0f, 3.5f, M_WALL), Tf.T(2.0f, 1.75f, 0.1f).Mul(Tf.Ry((float)Math.PI / 2)));
        // pared izquierda con la ventana por la que entra el sol
        Tf lw = RYm90;
        S(MQuad(4.0f, 0.9f, M_WALL), Tf.T(-1.8f, 0.45f, 0.1f).Mul(lw));
        S(MQuad(4.0f, 1.4f, M_WALL), Tf.T(-1.8f, 2.8f, 0.1f).Mul(lw));
        S(MQuad(1.8f, 1.2f, M_WALL), Tf.T(-1.8f, 1.5f, -1.0f).Mul(lw));
        S(MQuad(1.0f, 1.2f, M_WALL), Tf.T(-1.8f, 1.5f, 1.6f).Mul(lw));
        Inst sky = NoSh();
        S(MQuad(6, 4, M_SKY), Tf.T(-2.6f, 1.6f, 0.5f).Mul(lw), sky);
        S(MBox(0.12f, 0.06f, 1.3f, M_LIGHT), Tf.T(-1.78f, 0.9f, 0.5f));
        S(MBox(0.08f, 0.06f, 1.2f, M_LIGHT), Tf.T(-1.8f, 2.1f, 0.5f));
        S(MBox(0.08f, 1.2f, 0.06f, M_LIGHT), Tf.T(-1.8f, 1.5f, -0.1f));
        S(MBox(0.08f, 1.2f, 0.06f, M_LIGHT), Tf.T(-1.8f, 1.5f, 1.1f));
        S(MBox(0.05f, 1.2f, 0.04f, M_LIGHT), Tf.T(-1.8f, 1.5f, 0.5f));
        S(MBox(0.05f, 0.04f, 1.2f, M_LIGHT), Tf.T(-1.8f, 1.5f, 0.5f));
        // radiador
        for (int k = 0; k < 9; k++) S(MRBox(0.07f, 0.5f, 0.05f, 0.02f, M_LIGHT), Tf.T(-1.74f, 0.52f, 0.1f + k * 0.1f));
        Col(-2.2f, 0, -2.3f, -1.8f, 3.5f, 2.4f); Col(2.0f, 0, -2.3f, 2.4f, 3.5f, 2.4f); Col(-2.2f, 0, 1.6f, 2.4f, 3.5f, 2.0f); Col(-2.2f, 0, -2.3f, 2.4f, 3.5f, -1.9f);
        Col(-1.8f, 0.25f, 0.05f, -1.68f, 0.8f, 0.95f);

        // mesa
        S(MRBox(1.6f, 0.04f, 0.8f, 0.012f, M_DESK), Tf.T(0, DESK - 0.02f, 0.65f));
        Col(-0.8f, DESK - 0.04f, 0.25f, 0.8f, DESK, 1.05f);
        foreach (float lx in new float[] { -0.76f })
            foreach (float lz in new float[] { 0.3f, 1.0f }) { S(MBox(0.05f, 0.71f, 0.05f, M_METAL), Tf.T(lx, 0.355f, lz)); Col(lx - 0.025f, 0, lz - 0.025f, lx + 0.025f, 0.71f, lz + 0.025f); }
        S(MBox(1.1f, 0.38f, 0.02f, M_WOODD), Tf.T(-0.2f, 0.52f, 1.02f)); Col(-0.76f, 0.33f, 1.0f, 0.36f, 0.71f, 1.04f);
        // cajonera
        S(MRBox(0.42f, 0.7f, 0.66f, 0.01f, M_DESK), Tf.T(0.57f, 0.36f, 0.69f)); Col(0.36f, 0, 0.36f, 0.78f, 0.71f, 1.02f);
        for (int k = 0; k < 3; k++)
        {
            S(MBox(0.38f, 0.2f, 0.01f, M_WOODD), Tf.T(0.57f, 0.15f + k * 0.22f, 0.355f));
            S(MBox(0.12f, 0.015f, 0.02f, M_METAL), Tf.T(0.57f, 0.21f + k * 0.22f, 0.34f));
        }
        // monitor
        S(MCyl(0.11f, 0.1f, 0.015f, 20, M_DARK, true, true), Tf.T(0, DESK, 0.86f));
        S(MRBox(0.05f, 0.26f, 0.03f, 0.01f, M_DARK), Tf.T(0, DESK + 0.13f, 0.89f));
        S(MRBox(0.64f, 0.4f, 0.035f, 0.012f, M_DARK), Tf.T(0, 1.12f, 0.87f));
        S(MQuad(0.6f, 0.36f, M_SCREEN), Tf.T(0, 1.12f, 0.8515f), NoSh());
        S(MBox(0.012f, 0.004f, 0.004f, M_LED), Tf.T(0.28f, 0.93f, 0.851f), In(C3(80, 160, 255)));
        Col(-0.32f, 0.92f, 0.85f, 0.32f, 1.32f, 0.89f); Col(-0.03f, DESK, 0.87f, 0.03f, 0.95f, 0.91f); Col(-0.11f, DESK, 0.75f, 0.11f, DESK + 0.015f, 0.97f);
        // post-its en el marco
        S(MQuad(0.05f, 0.05f, M_TINT), Tf.T(0.29f, 1.29f, 0.85f).Mul(Tf.Rz(0.15f)), In(C3(250, 230, 90)));
        S(MQuad(0.05f, 0.05f, M_TINT), Tf.T(-0.29f, 1.28f, 0.85f).Mul(Tf.Rz(-0.1f)), In(C3(255, 150, 190)));
        // torre del ordenador
        S(MRBox(0.2f, 0.42f, 0.44f, 0.012f, M_DARK), Tf.T(0.62f, DESK + 0.21f, 0.82f));
        for (int k = 0; k < 5; k++) S(MBox(0.14f, 0.006f, 0.002f, M_METAL), Tf.T(0.62f, DESK + 0.06f + k * 0.025f, 0.599f));
        Col(0.52f, DESK, 0.6f, 0.72f, DESK + 0.42f, 1.04f);
        // teclado
        S(MRBox(0.44f, 0.026f, 0.15f, 0.008f, M_DARK), Tf.T(KB_C));
        S(MQuad(0.42f, 0.13f, M_KEYS), Tf.T(0, KB_TOP, 0.45f).Mul(Tf.Rx((float)Math.PI / 2)), NoSh());
        Col(-0.22f, DESK, 0.375f, 0.22f, DESK + 0.026f, 0.525f);
        S(MBox(0.24f, 0.003f, 0.2f, M_DARK), Tf.T(0.36f, DESK + 0.0015f, 0.47f), NoSh());
        // flexo
        S(MCyl(0.075f, 0.07f, 0.02f, 20, M_DARK, true, true), Tf.T(-0.62f, DESK, 0.88f));
        Col(-0.7f, DESK, 0.8f, -0.54f, DESK + 0.025f, 0.96f);
        V j0 = new V(-0.62f, DESK + 0.02f, 0.88f), j1 = new V(-0.67f, 1.2f, 0.87f), j2 = new V(-0.47f, 1.3f, 0.72f);
        S(MCapsule(0.012f, (j1 - j0).Len(), M_METAL), Tf.Seg(j0, j1, new V(0, 0, 1)));
        S(MCapsule(0.012f, (j2 - j1).Len(), M_METAL), Tf.Seg(j1, j2, new V(0, 0, 1)));
        S(MSphere(0.02f, 0.02f, 0.02f, 8, 10, M_DARK), Tf.T(j1));
        Tf head = Tf.Seg(j2, j2 + lampDir, new V(1, 0, 0));
        S(MCyl(0.035f, 0.075f, 0.11f, 20, M_TINTS, false, false), head, In(C3(40, 130, 90)));
        S(MSphere(0.03f, 0.03f, 0.03f, 8, 10, M_BULB), head.Mul(Tf.T(0, 0.06f, 0)), NoSh());
        S(MBox(0.025f, 0.012f, 0.02f, M_TINTS), Tf.T(SW_LAMP), In(C3(200, 40, 40)));
        // lapicero
        S(MCyl(0.035f, 0.035f, 0.1f, 16, M_TINTS, true, false), Tf.T(-0.33f, DESK, 0.9f), In(C3(40, 90, 180)));
        int[] pc = { 0xE03030, 0x2050D0, 0x202020 };
        for (int k = 0; k < 3; k++)
        {
            V a = new V(-0.33f + (k - 1) * 0.012f, DESK + 0.01f, 0.9f), b = a + new V((k - 1) * 0.03f, 0.15f, (k - 1) * 0.01f);
            S(MCapsule(0.0045f, (b - a).Len(), M_TINTS), Tf.Seg(a, b, new V(0, 0, 1)), In(TexVc(pc[k])));
        }
        Col(-0.37f, DESK, 0.86f, -0.29f, DESK + 0.1f, 0.94f);
        // armario e impresora
        S(MRBox(0.5f, 0.72f, 0.5f, 0.01f, M_WOODD), Tf.T(1.25f, 0.36f, 0.72f)); Col(1.0f, 0, 0.47f, 1.5f, 0.72f, 0.97f);
        S(MRBox(0.42f, 0.2f, 0.36f, 0.03f, M_LIGHT), Tf.T(1.25f, 0.82f, 0.74f)); Col(1.04f, 0.72f, 0.56f, 1.46f, 0.92f, 0.92f);
        S(MBox(0.3f, 0.01f, 0.12f, M_DARK), Tf.T(1.25f, 0.85f, 0.56f).Mul(Tf.Rx(-0.25f)));
        S(MBox(0.32f, 0.03f, 0.01f, M_DARK), Tf.T(1.25f, 0.88f, 0.561f));
        S(MCyl(0.014f, 0.014f, 0.008f, 12, M_TINTS, false, true), Tf.T(BTN_PR - new V(0, 0.008f, 0)), In(C3(60, 200, 90)));
        S(MBox(0.06f, 0.004f, 0.04f, M_DARK), Tf.T(1.3f, 0.921f, 0.62f));
        // silla de oficina
        S(MRBox(0.5f, 0.08f, 0.48f, 0.035f, M_CHAIR), Tf.T(0, 0.46f, 0.0f)); Col(-0.25f, 0.42f, -0.24f, 0.25f, 0.5f, 0.24f);
        S(MRBox(0.46f, 0.42f, 0.07f, 0.03f, M_CHAIR), Tf.T(0, 0.8f, -0.26f).Mul(Tf.Rx(-0.12f))); Col(-0.23f, 0.58f, -0.32f, 0.23f, 1.0f, -0.2f);
        S(MBox(0.04f, 0.3f, 0.03f, M_METAL), Tf.T(0, 0.55f, -0.24f));
        S(MCyl(0.03f, 0.03f, 0.34f, 12, M_METAL, false, false), Tf.T(0, 0.08f, 0));
        for (int k = 0; k < 5; k++)
        {
            float a = k * (float)Math.PI * 2 / 5 + 0.3f;
            V e = new V(Math.Cos(a) * 0.3f, 0.06f, Math.Sin(a) * 0.3f);
            S(MCapsule(0.018f, 0.3f, M_DARK), Tf.Seg(new V(0, 0.07f, 0), e, new V(0, 1, 0)));
            S(MSphere(0.028f, 0.028f, 0.028f, 6, 8, M_RUBBER), Tf.T(e.x, 0.028f, e.z));
        }
        // papelera
        S(MCyl(0.12f, BIN_R, BIN_H, 20, M_TINT, true, false), Tf.T(BIN), In(C3(90, 95, 105)));
        for (int k = 0; k < 10; k++) { float a = k * (float)Math.PI / 5; S(MBox(0.004f, BIN_H, 0.004f, M_METAL), Tf.T(BIN.x + (float)Math.Cos(a) * 0.137f, BIN_H / 2, BIN.z + (float)Math.Sin(a) * 0.137f)); }
        // planta detras del personaje
        V pot = new V(-0.9f, 0, -0.5f);
        S(MCyl(0.13f, 0.17f, 0.34f, 20, M_POT, true, false), Tf.T(pot));
        S(MCyl(0.165f, 0.165f, 0.005f, 20, M_SOIL, false, true), Tf.T(pot + new V(0, 0.31f, 0)));
        Col(pot.x - 0.17f, 0, pot.z - 0.17f, pot.x + 0.17f, 0.34f, pot.z + 0.17f);
        V t0 = pot + new V(0, 0.3f, 0), t1 = pot + new V(0.03f, 0.85f, 0.02f), t2 = pot + new V(-0.02f, 1.35f, 0.05f);
        S(MCapsule(0.02f, (t1 - t0).Len(), M_WOODD), Tf.Seg(t0, t1, new V(0, 0, 1)));
        S(MCapsule(0.015f, (t2 - t1).Len(), M_WOODD), Tf.Seg(t1, t2, new V(0, 0, 1)));
        Mesh leaf = MSphere(0.028f, 0.004f, 0.075f, 4, 8, M_LEAF);
        for (int k = 0; k < 90; k++)
        {
            float hgt = 0.55f + (float)r.NextDouble() * 0.95f, ang = (float)(r.NextDouble() * Math.PI * 2);
            float rad = 0.08f + (float)r.NextDouble() * 0.22f * (1.2f - Math.Abs(hgt - 1.1f));
            V c = pot + new V(Math.Cos(ang) * rad, hgt, Math.Sin(ang) * rad);
            Tf lt = Tf.T(c).Mul(Tf.Ry(-ang + (float)Math.PI / 2)).Mul(Tf.Rx(-0.5f - (float)r.NextDouble() * 0.6f)).Mul(Tf.Rz((float)(r.NextDouble() - 0.5) * 0.6f)).Mul(Tf.T(0, 0, 0.07f));
            S(leaf, lt, In(LerpV(C3(30, 100, 40), C3(90, 160, 60), (float)r.NextDouble())));
        }
        // estanteria con libros
        S(MRBox(0.26f, 0.03f, 1.0f, 0.006f, M_WOODD), Tf.T(1.87f, 1.45f, 0.75f));
        S(MRBox(0.26f, 0.03f, 1.0f, 0.006f, M_WOODD), Tf.T(1.87f, 1.85f, 0.75f));
        float bz = 0.3f;
        for (int k = 0; k < 14; k++)
        {
            float bw = 0.025f + (float)r.NextDouble() * 0.03f, bh = 0.2f + (float)r.NextDouble() * 0.12f;
            V col = LerpV(C3(40, 60, 140), C3(200, 60, 50), (float)r.NextDouble());
            if (k % 3 == 1) col = C3(230, 200, 120);
            S(MRBox(0.18f, bh, bw, 0.004f, M_BOOK), Tf.T(1.88f, 1.465f + bh / 2, bz + bw / 2).Mul(Tf.Rx(k == 9 ? 0.25f : 0)), In(col));
            bz += bw + 0.004f;
        }
        S(MCyl(0.04f, 0.03f, 0.06f, 14, M_TINTS, true, true), Tf.T(1.86f, 1.865f, 0.5f), In(C3(230, 180, 40)));
        S(MSphere(0.045f, 0.045f, 0.045f, 8, 12, M_TINTS), Tf.T(1.86f, 1.97f, 0.5f), In(C3(240, 190, 50)));
        // reloj y cuadro
        S(MCyl(0.17f, 0.17f, 0.035f, 28, M_DARK, false, true), Tf.T(-0.55f, 2.0f, 1.6f).Mul(Tf.Rx(-(float)Math.PI / 2)));
        S(MQuad(0.32f, 0.32f, M_CLOCK), Tf.T(-0.55f, 2.0f, 1.564f), NoSh());
        S(MRBox(0.68f, 0.5f, 0.025f, 0.008f, M_DARK), Tf.T(0.55f, 1.8f, 1.588f));
        S(MQuad(0.62f, 0.44f, M_POSTER), Tf.T(0.55f, 1.8f, 1.574f), NoSh());
        nStaticFixed = statics.Count;
    }
    static V TexVc(int c) { return new V(((c >> 16) & 255) / 255f, ((c >> 8) & 255) / 255f, (c & 255) / 255f); }

    // ================================================================ fisica de los objetos
    const int K_MUG = 0, K_PAPER = 1, K_BALL = 2, K_MOUSE = 3, K_BOOK = 4, K_STAPLER = 5, K_PHONE = 6, K_PAD = 7, K_PBALL = 8;
    static readonly string[] KNAME = { "la taza", "un folio", "la pelota antiestres", "el raton", "un libro", "la grapadora", "el movil", "los post-it", "una bola de papel" };
    public class Body
    {
        public V p, v, he; public float yaw, yawV, tx, tz, txV, tzV, spin; public bool sphere; public float r;
        public int kind, held = -1, id; public bool ground; public float sleep, bounce = 0.25f;
        public Inst ins = new Inst(); public bool binned; public float heldT, squash;
    }
    static List<Body> bodies = new List<Body>();
    static int bodyIds;

    static Body NewBody(int kind, V p, V he, V tint)
    {
        Body b = new Body(); b.kind = kind; b.p = p; b.he = he; b.ins.tint = tint; b.id = bodyIds++; b.ins.tag = b.id;
        bodies.Add(b); return b;
    }

    static void ResetBodies()
    {
        bodies.Clear();
        NewBody(K_MUG, new V(-0.4f, DESK + 0.05f, 0.43f), new V(0.042f, 0.05f, 0.042f), C3(200, 40, 40));
        for (int k = 0; k < 5; k++) { Body p = NewBody(K_PAPER, new V(-0.52f, DESK + 0.0012f + k * 0.0024f, 0.64f), new V(0.105f, 0.0011f, 0.1485f), new V(1, 1, 1)); p.yaw = (k - 2) * 0.04f; }
        Body ball = NewBody(K_BALL, new V(0.2f, DESK + 0.032f, 0.66f), new V(0.032f, 0.032f, 0.032f), C3(255, 120, 20)); ball.sphere = true; ball.r = 0.032f; ball.bounce = 0.7f;
        NewBody(K_MOUSE, new V(0.36f, DESK + 0.0175f, 0.46f), new V(0.031f, 0.0175f, 0.052f), new V(1, 1, 1));
        NewBody(K_BOOK, new V(-0.15f, DESK + 0.016f, 0.94f), new V(0.085f, 0.016f, 0.12f), C3(40, 70, 160));
        Body b2 = NewBody(K_BOOK, new V(-0.14f, DESK + 0.049f, 0.94f), new V(0.08f, 0.016f, 0.115f), C3(50, 140, 80)); b2.yaw = 0.25f;
        NewBody(K_STAPLER, new V(0.22f, DESK + 0.022f, 0.86f), new V(0.022f, 0.022f, 0.075f), C3(200, 30, 30));
        Body ph = NewBody(K_PHONE, new V(-0.24f, DESK + 0.005f, 0.6f), new V(0.037f, 0.005f, 0.075f), new V(1, 1, 1)); ph.yaw = -0.3f;
        NewBody(K_PAD, new V(0.27f, DESK + 0.009f, 0.64f), new V(0.04f, 0.009f, 0.04f), C3(250, 225, 80));
    }

    static void Ext(Body b, out float ex, out float ey, out float ez)
    {
        if (b.sphere) { ex = ey = ez = b.r; return; }
        float c = Math.Abs((float)Math.Cos(b.yaw)), s = Math.Abs((float)Math.Sin(b.yaw));
        ex = c * b.he.x + s * b.he.z; ez = s * b.he.x + c * b.he.z; ey = b.he.y;
    }

    static void Physics(double dt)
    {
        int sub = 3; float h = (float)(dt / sub);
        for (int it = 0; it < sub; it++)
        {
            foreach (Body b in bodies)
            {
                if (b.held >= 0) continue;
                if (b.sleep > 0.5f) continue;
                b.v.y -= 9.8f * h;
                if (b.kind == K_PAPER && !b.ground)
                {
                    b.v = b.v * (1 - 2.5f * h);
                    if (b.v.y < -0.6f) b.v.y = -0.6f;
                    b.v.x += (float)Math.Sin(gt * 7 + b.id) * 1.2f * h; b.v.z += (float)Math.Cos(gt * 5 + b.id * 2) * 1.2f * h;
                    b.txV += (float)Math.Sin(gt * 6 + b.id) * 8 * h;
                }
                b.p = b.p + b.v * h; b.yaw += b.yawV * h; b.tx += b.txV * h; b.tz += b.tzV * h;
                if (b.sphere) b.spin += new V(b.v.x, 0, b.v.z).Len() / b.r * h;
                b.ground = false;
                float ex, ey, ez; Ext(b, out ex, out ey, out ez);
                foreach (Box3 s in statics) Collide(b, s, ex, ey, ez);
                BinCollide(b, ex, ey);
                if (b.p.y - ey < 0) { b.p.y = ey; Land(b, h); }
            }
            // objetos entre si
            for (int i = 0; i < bodies.Count; i++)
                for (int j = i + 1; j < bodies.Count; j++) Pair(bodies[i], bodies[j]);
        }
        foreach (Body b in bodies)
        {
            if (b.held >= 0) { b.sleep = 0; continue; }
            if (b.ground && b.v.Len() < 0.04f && Math.Abs(b.yawV) < 0.2f) b.sleep += (float)dt; else b.sleep = 0;
            if (b.sleep > 0.5f) { b.v = new V(0, 0, 0); b.yawV = 0; }
            if (b.ground) { b.tx *= 0.7f; b.tz *= 0.7f; b.txV = 0; b.tzV = 0; }
            if (b.kind == K_MOUSE) { V home = new V(0.36f, DESK, 0.46f); V d = b.p - home; if (d.Len() > 0.5f) { b.p = home + d.Norm() * 0.5f; b.v = b.v * -0.3f; } }
            // papelera
            V bd = new V(b.p.x - BIN.x, 0, b.p.z - BIN.z);
            bool inside = bd.Len() < BIN_R - 0.01f && b.p.y < BIN_H;
            if (inside && !b.binned && b.ground) { b.binned = true; binCount++; Msg("Canasta! " + KNAME[b.kind] + " a la papelera (" + binCount + ")"); }
            if (!inside) b.binned = false;
        }
    }

    static void Land(Body b, float h)
    {
        if (b.v.y < -0.6f) { b.v.y = -b.v.y * b.bounce; b.yawV *= 0.6f; }
        else if (b.v.y < 0) b.v.y = 0;
        float f = Math.Max(0, 1 - (b.sphere ? 0.6f : 9f) * h);
        b.v.x *= f; b.v.z *= f; b.yawV *= Math.Max(0, 1 - 7 * h);
        b.ground = true;
    }

    static void Collide(Body b, Box3 s, float ex, float ey, float ez)
    {
        float ox = Math.Min(b.p.x + ex, s.mx.x) - Math.Max(b.p.x - ex, s.mn.x); if (ox <= 0) return;
        float oy = Math.Min(b.p.y + ey, s.mx.y) - Math.Max(b.p.y - ey, s.mn.y); if (oy <= 0) return;
        float oz = Math.Min(b.p.z + ez, s.mx.z) - Math.Max(b.p.z - ez, s.mn.z); if (oz <= 0) return;
        float cx = (s.mn.x + s.mx.x) / 2, cy = (s.mn.y + s.mx.y) / 2, cz = (s.mn.z + s.mx.z) / 2;
        // preferimos apoyar encima si viene de arriba
        bool fromTop = b.p.y > s.mx.y - 0.004f && oy < 0.05f;
        if (fromTop || (oy <= ox && oy <= oz))
        {
            if (b.p.y > cy) { b.p.y += oy; if (b.v.y < 0) Land(b, 0.016f); b.ground = true; }
            else { b.p.y -= oy; if (b.v.y > 0) b.v.y = -b.v.y * 0.2f; }
        }
        else if (ox <= oz) { b.p.x += b.p.x > cx ? ox : -ox; if ((b.p.x > cx) != (b.v.x > 0)) { b.v.x = -b.v.x * 0.35f; b.yawV += b.v.z * 4; } }
        else { b.p.z += b.p.z > cz ? oz : -oz; if ((b.p.z > cz) != (b.v.z > 0)) { b.v.z = -b.v.z * 0.35f; b.yawV -= b.v.x * 4; } }
    }

    static void BinCollide(Body b, float ex, float ey)
    {
        float dx = b.p.x - BIN.x, dz = b.p.z - BIN.z, d = (float)Math.Sqrt(dx * dx + dz * dz);
        if (b.p.y - ey > BIN_H + 0.005f || d > BIN_R + ex + 0.01f) return;
        float rad = Math.Max(0.01f, Math.Min(ex, BIN_R * 0.6f));
        if (d < BIN_R - 0.005f && b.p.y < BIN_H + ey * 0.5f)
        {
            // dentro: rebota en la pared interior y cae al fondo
            if (d > BIN_R - rad) { float k = (BIN_R - rad) / Math.Max(1e-4f, d); b.p.x = BIN.x + dx * k; b.p.z = BIN.z + dz * k; b.v.x *= -0.3f; b.v.z *= -0.3f; }
            if (b.p.y - ey < 0.02f) { b.p.y = 0.02f + ey; Land(b, 0.016f); }
        }
        else if (b.p.y < BIN_H)
        {
            float k = (BIN_R + rad) / Math.Max(1e-4f, d); b.p.x = BIN.x + dx * k; b.p.z = BIN.z + dz * k;
            b.v.x = dx / Math.Max(1e-4f, d) * Math.Abs(b.v.x) * 0.4f; b.v.z = dz / Math.Max(1e-4f, d) * Math.Abs(b.v.z) * 0.4f;
        }
        else if (Math.Abs(d - BIN_R) < rad && b.v.y < 0) { b.v.y = Math.Abs(b.v.y) * 0.4f; b.v.x += dx * 2; b.v.z += dz * 2; }
    }

    static void Pair(Body a, Body b)
    {
        if (a.held >= 0 && b.held >= 0) return;
        float ax, ay, az, bx, by, bz; Ext(a, out ax, out ay, out az); Ext(b, out bx, out by, out bz);
        float ox = Math.Min(a.p.x + ax, b.p.x + bx) - Math.Max(a.p.x - ax, b.p.x - bx); if (ox <= 0) return;
        float oy = Math.Min(a.p.y + ay, b.p.y + by) - Math.Max(a.p.y - ay, b.p.y - by); if (oy <= 0) return;
        float oz = Math.Min(a.p.z + az, b.p.z + bz) - Math.Max(a.p.z - az, b.p.z - bz); if (oz <= 0) return;
        float wa = a.held >= 0 ? 0 : 0.5f, wb = b.held >= 0 ? 0 : 0.5f;
        if (wa + wb == 0) return;
        float k = 1f / (wa + wb);
        if (oy <= ox && oy <= oz)
        {
            Body top = a.p.y > b.p.y ? a : b, bot = top == a ? b : a;
            float wt = top.held >= 0 ? 0 : 1, wbo = bot.held >= 0 ? 0 : (wt == 0 ? 1 : 0);
            if (wt > 0) { top.p.y += oy; if (top.v.y < bot.v.y) { top.v.y = bot.v.y; } top.ground = true; top.v.x = Lf(top.v.x, bot.v.x, 0.3f); top.v.z = Lf(top.v.z, bot.v.z, 0.3f); }
            else bot.p.y -= oy * wbo;
            top.sleep = Math.Min(top.sleep, 0.4f);
        }
        else if (ox <= oz)
        {
            float sg = a.p.x < b.p.x ? -1 : 1;
            a.p.x += sg * ox * wa * k; b.p.x -= sg * ox * wb * k;
            float va = a.v.x, vb = b.v.x;
            if (wa > 0) a.v.x = Lf(va, vb, 0.6f); if (wb > 0) b.v.x = Lf(vb, va, 0.6f);
            a.sleep = 0; b.sleep = 0;
        }
        else
        {
            float sg = a.p.z < b.p.z ? -1 : 1;
            a.p.z += sg * oz * wa * k; b.p.z -= sg * oz * wb * k;
            float va = a.v.z, vb = b.v.z;
            if (wa > 0) a.v.z = Lf(va, vb, 0.6f); if (wb > 0) b.v.z = Lf(vb, va, 0.6f);
            a.sleep = 0; b.sleep = 0;
        }
    }

    // ================================================================ el personaje
    // 0 = mano izquierda, 1 = mano derecha (vistas desde detras, como las tuyas)
    static V[] hTgt = new V[2], hPos = new V[2], hVel = new V[2], hPrev = new V[2];
    static int[] hFingers = new int[2]; static float[,] curl = new float[2, 5];
    static Body[] heldB = new Body[2]; static V[] heldOff = new V[2]; static float[] heldYaw = new float[2], hYaw = new float[2];
    static V[,] tips = new V[2, 5]; static bool[,] tipDown = new bool[2, 5];
    static V[] palmC = new V[2];
    static float leanF = 0.1f, leanS, headYaw, headPitch = -0.15f, autoF, autoS;
    static bool[] gripPrev = new bool[2];
    static readonly float[] FLEN = { 0.04f, 0.045f, 0.042f, 0.034f, 0.035f };   // indice, corazon, anular, menique, pulgar

    static void HandsInit()
    {
        hTgt[0] = new V(-0.17f, 0.8f, 0.27f); hTgt[1] = new V(0.17f, 0.8f, 0.27f);
        for (int h = 0; h < 2; h++) { hPos[h] = hTgt[h]; hPrev[h] = hTgt[h]; hVel[h] = new V(0, 0, 0); hFingers[h] = 5; heldB[h] = null; }
    }

    static V ArmRoot(int h, Tf torso) { return torso.P(new V(h == 0 ? -0.19f : 0.19f, 0.43f, 0.0f)); }

    static Tf TorsoTf() { return Tf.T(0, 0.57f, 0.02f).Mul(Tf.Ry(headYaw * 0.3f)).Mul(Tf.Rz(-(leanS + autoS))).Mul(Tf.Rx(leanF + autoF)); }

    // limita la mano: no atraviesa la mesa ni los objetos fijos
    static V ConstrainHand(V p)
    {
        p.y = Math.Max(0.45f, Math.Min(1.6f, p.y));
        p.x = Math.Max(-0.85f, Math.Min(0.95f, p.x));
        p.z = Math.Max(-0.15f, Math.Min(0.84f, p.z));
        if (Math.Abs(p.x) < 0.3f && p.z < 0.24f) p.z = 0.24f;   // no atravesar el pecho
        float r = 0.03f;
        for (int k = 0; k < nStaticFixed; k++)
        {
            Box3 s = statics[k];
            if (p.x < s.mn.x - r || p.x > s.mx.x + r || p.y < s.mn.y - r || p.y > s.mx.y + r || p.z < s.mn.z - r || p.z > s.mx.z + r) continue;
            float up = s.mx.y + r - p.y, dn = p.y - (s.mn.y - r), lx = p.x - (s.mn.x - r), rx = s.mx.x + r - p.x, fz = p.z - (s.mn.z - r), bz = s.mx.z + r - p.z;
            float m = Math.Min(up, Math.Min(dn, Math.Min(lx, Math.Min(rx, Math.Min(fz, bz)))));
            if (m == up) p.y += up; else if (m == dn) p.y -= dn; else if (m == lx) p.x -= lx; else if (m == rx) p.x += rx; else if (m == fz) p.z -= fz; else p.z += bz;
        }
        return p;
    }

    static void UpdateHands(double dt)
    {
        // si la mano no llega, el cuerpo se inclina hacia ella
        float wf = 0, ws = 0;
        Tf t0 = Tf.T(0, 0.57f, 0.02f).Mul(Tf.Rz(-leanS)).Mul(Tf.Rx(leanF));
        for (int h = 0; h < 2; h++)
        {
            V d0 = ConstrainHand(hTgt[h]) - ArmRoot(h, t0); float l0 = d0.Len(), ex = l0 - 0.6f;
            if (ex > 0) { wf = Math.Max(wf, ex * 1.6f * Math.Max(0, d0.z / l0 + 0.3f)); ws += ex * 1.4f * d0.x / l0; }
        }
        autoF = Lf(autoF, Clampf(wf, 0, 0.35f), (float)Math.Min(1, dt * 4));
        autoS = Lf(autoS, Clampf(ws, -0.15f, 0.15f), (float)Math.Min(1, dt * 4));
        Tf torso = TorsoTf();
        for (int h = 0; h < 2; h++)
        {
            V tgt = ConstrainHand(hTgt[h]);
            V s = ArmRoot(h, torso);
            V d = tgt - s; float L = d.Len();
            if (L > 0.68f) tgt = s + d * (0.68f / L);
            hPrev[h] = hPos[h];
            hPos[h] = LerpV(hPos[h], tgt, (float)Math.Min(1, dt * 11));
            hPos[h] = ConstrainHand(hPos[h]);
            V vel = (hPos[h] - hPrev[h]) * (float)(1 / Math.Max(1e-3, dt));
            hVel[h] = LerpV(hVel[h], vel, 0.4f);
            // curvatura de los dedos segun los dedos que muestras
            int n = hFingers[h];
            for (int f = 0; f < 5; f++)
            {
                bool ext = n >= 5 || (f < 4 && f < n) || (n == 5 && f == 4);
                float tc = ext ? 0.12f : (f == 4 ? 0.9f : 1.45f);
                curl[h, f] += (tc - curl[h, f]) * (float)Math.Min(1, dt * 12);
            }
            bool grip = n == 0;
            // coger y soltar
            if (grip && !gripPrev[h] && heldB[h] == null)
            {
                Body best = null; float bd = 0.1f;
                foreach (Body b in bodies)
                {
                    if (b.held >= 0) continue;
                    float ex, ey, ez; Ext(b, out ex, out ey, out ez);
                    V q = new V(Clampf(palmC[h].x, b.p.x - ex, b.p.x + ex), Clampf(palmC[h].y, b.p.y - ey, b.p.y + ey), Clampf(palmC[h].z, b.p.z - ez, b.p.z + ez));
                    float dd = (q - palmC[h]).Len();
                    if (dd < bd) { bd = dd; best = b; }
                }
                if (best != null)
                {
                    heldB[h] = best; best.held = h; best.heldT = 0; best.sleep = 0;
                    heldOff[h] = RotY(best.p - palmC[h], -hYaw[h]); heldYaw[h] = best.yaw - hYaw[h];
                    if (heldOff[h].Len() > 0.12f) heldOff[h] = heldOff[h].Norm() * 0.12f;
                    Msg("Has cogido " + KNAME[best.kind]);
                }
            }
            if (!grip && heldB[h] != null)
            {
                Body b = heldB[h]; b.held = -1; heldB[h] = null;
                V tv = hVel[h] * 1.5f;
                if (tv.Len() > 6) tv = tv.Norm() * 6;
                b.v = tv; b.yawV = (float)(rnd.NextDouble() - 0.5) * tv.Len() * 8;
                if (b.kind != K_MOUSE && tv.Len() > 0.8f) { b.txV = (float)(rnd.NextDouble() - 0.5) * 14; b.tzV = (float)(rnd.NextDouble() - 0.5) * 14; Msg("Has lanzado " + KNAME[b.kind]); }
                b.sleep = 0; b.squash = 0;
            }
            gripPrev[h] = grip;
            if (heldB[h] != null)
            {
                Body b = heldB[h];
                b.heldT += (float)dt;
                V target = palmC[h] + RotY(heldOff[h], hYaw[h]) + new V(0, -0.02f, 0);
                if (b.kind == K_MOUSE) { target.y = DESK + b.he.y; }
                V nv = (target - b.p) * (float)(1 / Math.Max(1e-3, dt));
                b.v = nv; b.p = target; b.yaw = hYaw[h] + heldYaw[h]; b.tx *= 0.8f; b.tz *= 0.8f;
                if (b.kind == K_PAPER && b.heldT > 1.0f) Crumple(b);
                if (b.kind == K_BALL) b.squash = Math.Min(1, b.squash + (float)dt * 4);
            }
        }
        mouseHeld = (heldB[0] != null && heldB[0].kind == K_MOUSE) || (heldB[1] != null && heldB[1].kind == K_MOUSE);
    }

    static V RotY(V v, float a) { float c = (float)Math.Cos(a), s = (float)Math.Sin(a); return new V(v.x * c + v.z * s, v.y, -v.x * s + v.z * c); }

    static void Crumple(Body b)
    {
        b.kind = K_PBALL; b.sphere = true; b.r = 0.035f; b.he = new V(b.r, b.r, b.r); b.bounce = 0.45f; b.ins.tex = null;
        Msg("Has arrugado el papel: ahora tiralo a la papelera!");
    }

    // empujar objetos con las manos (colisiones de la mano)
    static void HandPush()
    {
        for (int h = 0; h < 2; h++)
            for (int k = 0; k < 6; k++)
            {
                V c = k == 5 ? palmC[h] : tips[h, k]; float rr = k == 5 ? 0.045f : 0.014f;
                foreach (Body b in bodies)
                {
                    if (b.held >= 0) continue;
                    float ex, ey, ez; Ext(b, out ex, out ey, out ez);
                    V q = new V(Clampf(c.x, b.p.x - ex, b.p.x + ex), Clampf(c.y, b.p.y - ey, b.p.y + ey), Clampf(c.z, b.p.z - ez, b.p.z + ez));
                    V d = q - c; float dist = d.Len();
                    if (dist >= rr) continue;
                    V n = dist > 1e-4f ? d * (1 / dist) : new V(0, 1, 0);
                    if (n.y < -0.5f && b.p.y - ey < DESK + 0.01f) n = new V(n.x, 0, n.z).Norm();
                    b.p = b.p + n * (rr - dist);
                    float push = Dot(hVel[h] - b.v, n);
                    if (push > 0 && hVel[h].Len() > 0.5f) b.v = b.v + n * Math.Min(push * 0.7f, 1.6f);
                    b.sleep = 0;
                    if (b.kind == K_PHONE) phoneT = gt;
                }
            }
    }

    // botones, teclado y raton
    static float prevMx, prevMz; static bool mouseHeld;
    static readonly string[] KROWS = { "1234567890-<", "QWERTYUIOP", "ASDFGHJKL\n", "ZXCVBNM,.?" };

    static void Interact()
    {
        keyHoverL = keyHoverR = -1;
        // botones: se pulsan al entrar el dedo y se rearman al apartarlo
        V[] bp = { BTN_PC, SW_LAMP, BTN_PR }; float[] br = { 0.035f, 0.04f, 0.04f };
        for (int k = 0; k < 3; k++)
        {
            float md = 9;
            for (int h = 0; h < 2; h++) for (int f = 0; f < 5; f++) if (f == 0 || hFingers[h] == 1 || hFingers[h] == 5) md = Math.Min(md, (tips[h, f] - bp[k]).Len());
            if (md < br[k] && btnArm[k])
            {
                btnArm[k] = false;
                if (k == 0) { btnPcT = gt; PcToggle(); }
                else if (k == 1) { btnLampT = gt; lampOn = !lampOn; Msg(lampOn ? "Has encendido el flexo" : "Has apagado el flexo"); }
                else if (gt - btnPrT > 2.0) { btnPrT = gt; Print(); }
            }
            else if (md > br[k] * 1.8f) btnArm[k] = true;
        }
        for (int h = 0; h < 2; h++)
            for (int f = 0; f < 5; f++)
            {
                V t = tips[h, f];
                // teclado
                bool over = t.x > KB_X0 && t.x < KB_X1 && t.z > KB_Z0 && t.z < KB_Z1;
                if (over)
                {
                    float u = (t.x - KB_X0) / (KB_X1 - KB_X0), v = (KB_Z1 - t.z) / (KB_Z1 - KB_Z0);
                    int row = Math.Min(4, (int)(v * 5)), col = Math.Min(13, (int)(u * 14));
                    int key = row == 4 ? 99 : row * 20 + col;
                    if (f == 0 && t.y < KB_TOP + 0.07f) { if (h == 0) keyHoverL = key; else keyHoverR = key; }
                    if (t.y < KB_TOP + 0.008f && curl[h, f] < 0.6f && hFingers[h] >= 1 && hFingers[h] <= 3)
                    {
                        if (!tipDown[h, f])
                        {
                            tipDown[h, f] = true;
                            char ch = ' ';
                            if (row < 4) { string rs = KROWS[row]; ch = rs[Math.Min(rs.Length - 1, col * rs.Length / 14)]; }
                            if (ch == '<') ch = '\b';
                            keyPress = key; keyPressT = gt;
                            TypeKey(ch);
                        }
                    }
                    else if (t.y > KB_TOP + 0.02f) tipDown[h, f] = false;
                }
                else tipDown[h, f] = false;
            }
        // raton
        Body mouse = null; foreach (Body b in bodies) if (b.kind == K_MOUSE) mouse = b;
        if (mouse != null)
        {
            if (mouseHeld) { curX = Clampf(curX + (mouse.p.x - prevMx) * 600, 0, STW - 2); curY = Clampf(curY - (mouse.p.z - prevMz) * 600, 0, STH - 2); }
            prevMx = mouse.p.x; prevMz = mouse.p.z;
        }
    }

    static void Print()
    {
        int tw, th; int[] tex = PrintTex(out tw, out th);
        Body p = NewBody(K_PAPER, new V(1.25f, 0.87f, 0.6f), new V(0.105f, 0.0011f, 0.1485f), new V(1, 1, 1));
        p.ins.tex = tex; p.ins.tw = tw; p.ins.th = th; p.v = new V(0, 0.2f, -0.55f);
        Msg(osState == 5 ? "La impresora saca tu dibujo" : "La impresora saca tus notas");
        if (bodies.Count > 40) bodies.RemoveAt(1);
    }

    // cuerpo dinamico de la persona (para que los objetos choquen con ella)
    static void BodyColliders()
    {
        while (statics.Count > nStaticFixed) statics.RemoveAt(statics.Count - 1);
        Tf t = TorsoTf();
        V c = t.P(new V(0, 0.28f, 0));
        Col(c.x - 0.18f, c.y - 0.28f, c.z - 0.12f, c.x + 0.18f, c.y + 0.3f, c.z + 0.12f);
        Col(-0.2f, 0.5f, 0.0f, 0.2f, 0.62f, 0.45f);
        V hd = t.P(new V(0, 0.68f, 0.03f));
        Col(hd.x - 0.1f, hd.y - 0.12f, hd.z - 0.11f, hd.x + 0.1f, hd.y + 0.13f, hd.z + 0.11f);
    }

    // ---------------------------------------------------------------- dibujo de la persona
    static Dictionary<int, Mesh> capCache = new Dictionary<int, Mesh>();
    static Mesh Cap(float r, float len, int mat)
    {
        int key = (int)(r * 1000) * 100000 + (int)(len * 1000) * 40 + mat;
        Mesh m; if (!capCache.TryGetValue(key, out m)) { m = MCapsule(r, len, mat); capCache[key] = m; }
        return m;
    }
    static void Limb(V a, V b, float r, int mat, Inst ins) { Draw(Cap(r, Math.Max(0.001f, (b - a).Len()), mat), Tf.Seg(a, b, new V(0, 0, 1)), ins); }

    static Mesh mTorso, mPelvis, mHead, mHair, mHair2, mEar, mPalm, mShoe, mNeck, mJoint, mJointS;
    static Inst shirt = new Inst();

    static void CharMeshes()
    {
        shirt.tint = C3(40, 120, 150);
        mTorso = MRBox(0.37f, 0.5f, 0.22f, 0.09f, M_SHIRT);
        mPelvis = MRBox(0.35f, 0.16f, 0.25f, 0.07f, M_PANTS);
        mHead = MSphere(0.095f, 0.12f, 0.105f, 14, 18, M_SKIN);
        mHair = MSphere(0.102f, 0.1f, 0.11f, 12, 16, M_HAIR);
        mHair2 = MSphere(0.1f, 0.09f, 0.06f, 10, 14, M_HAIR);
        mEar = MSphere(0.015f, 0.028f, 0.02f, 6, 8, M_SKIN);
        mPalm = MRBox(0.082f, 0.095f, 0.028f, 0.012f, M_SKIN);
        mShoe = MRBox(0.1f, 0.07f, 0.26f, 0.03f, M_SHOE);
        mNeck = MCyl(0.048f, 0.045f, 0.12f, 12, M_SKIN, false, false);
        mJoint = MSphere(0.06f, 0.06f, 0.06f, 8, 10, M_SHIRT);
        mJointS = MSphere(0.035f, 0.035f, 0.035f, 8, 10, M_SKIN);
    }

    static void DrawPerson()
    {
        Tf t = TorsoTf();
        // piernas (bajo la mesa)
        for (int s = -1; s <= 1; s += 2)
        {
            V hip = new V(s * 0.1f, 0.56f, 0.03f), knee = new V(s * 0.12f, 0.55f, 0.45f), ankle = new V(s * 0.13f, 0.1f, 0.5f);
            Limb(hip, knee, 0.075f, M_PANTS, null); Limb(knee, ankle, 0.055f, M_PANTS, null);
            Draw(mShoe, Tf.T(ankle.x, 0.045f, ankle.z + 0.06f));
        }
        Draw(mPelvis, t.Mul(Tf.T(0, 0.05f, 0)));
        Draw(mTorso, t.Mul(Tf.T(0, 0.28f, 0)), shirt);
        Draw(mNeck, t.Mul(Tf.T(0, 0.5f, 0.01f)));
        Tf ht = t.Mul(Tf.T(0, 0.68f, 0.03f)).Mul(Tf.Ry(headYaw)).Mul(Tf.Rx(-headPitch));
        Draw(mHead, ht);
        Draw(mHair, ht.Mul(Tf.T(0, 0.035f, -0.012f)));
        Draw(mHair2, ht.Mul(Tf.T(0, -0.02f, -0.06f)));
        Draw(mEar, ht.Mul(Tf.T(-0.094f, 0, 0)));
        Draw(mEar, ht.Mul(Tf.T(0.094f, 0, 0)));
        for (int h = 0; h < 2; h++)
        {
            V sh = ArmRoot(h, t);
            V wrist = hPos[h] - new V(0, 0, 0.055f);
            V elbow; IK(sh, ref wrist, 0.29f, 0.27f, new V(h == 0 ? -0.5f : 0.5f, -0.8f, -0.35f), out elbow);
            Draw(mJoint, Tf.T(sh), shirt);
            Limb(sh, elbow, 0.05f, M_SHIRT, shirt);
            V sleeveEnd = LerpV(elbow, wrist, 0.35f);
            Limb(elbow, sleeveEnd, 0.047f, M_SHIRT, shirt);
            Limb(elbow, wrist, 0.035f, M_SKIN, null);
            Draw(mJointS, Tf.T(wrist));
            // mano: Y hacia los dedos, Z dorso, X hacia el pulgar de la derecha
            float pa = Sat((curl[h, 1] - curl[h, 0]) / 1.2f);
            V fw = (LerpV((wrist - elbow).Norm(), new V(0, -0.25f - 0.55f * pa, 1).Norm(), 0.5f + 0.2f * pa)).Norm();
            Tf hand = Tf.Seg(wrist, wrist + fw, new V(0, 1, 0));
            hYaw[h] = (float)Math.Atan2(fw.x, fw.z);
            Draw(mPalm, hand.Mul(Tf.T(0, 0.05f, 0)));
            palmC[h] = hand.P(new V(0, 0.055f, -0.025f));
            float side = h == 0 ? -1 : 1;  // hacia donde queda el indice (hacia dentro)
            for (int f = 0; f < 5; f++)
            {
                float c = curl[h, f];
                V root, dir;
                if (f < 4)
                {
                    float ox = side * (0.03f - f * 0.02f);
                    root = hand.P(new V(ox, 0.095f, 0));
                    dir = hand.D(new V(0, (float)Math.Cos(c), -(float)Math.Sin(c)));
                }
                else
                {
                    root = hand.P(new V(side * 0.042f, 0.03f, -0.008f));
                    dir = hand.D(new V(side * 0.55f * (1 - c * 0.5f), 0.7f, -0.35f - c * 0.4f)).Norm();
                }
                float l1 = FLEN[f], l2 = FLEN[f] * 0.85f;
                V mid = root + dir * l1;
                V dir2 = f < 4 ? hand.D(new V(0, (float)Math.Cos(c * 1.6f), -(float)Math.Sin(c * 1.6f))) : (dir + hand.D(new V(-side * c * 0.6f, 0, -c * 0.3f))).Norm();
                V tip = mid + dir2 * l2;
                float rr = f == 4 ? 0.011f : 0.0095f;
                Limb(root, mid, rr, M_SKIN, null); Limb(mid, tip, rr * 0.92f, M_SKIN, null);
                tips[h, f] = tip;
            }
            // lo que tiene en la mano
            if (heldB[h] != null) { }
        }
    }

    static void IK(V s, ref V t, float l1, float l2, V pole, out V e)
    {
        V d = t - s; float dist = d.Len();
        float mx = (l1 + l2) * 0.999f, mn = Math.Abs(l1 - l2) + 0.02f;
        if (dist > mx) { t = s + d * (mx / dist); dist = mx; }
        if (dist < mn) { t = s + d.Norm() * mn; dist = mn; }
        V dir = (t - s).Norm();
        float a = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist);
        float hh = (float)Math.Sqrt(Math.Max(0, l1 * l1 - a * a));
        V pp = (pole - dir * Dot(pole, dir)).Norm();
        e = s + dir * a + pp * hh;
    }

    // ---------------------------------------------------------------- dibujo de los objetos con fisica
    static Mesh mMug, mMugH, mCoffee, mPaper, mBall, mMouse, mWheel, mBook, mPages, mStapB, mStapT, mPhone, mPad, mPBall;
    static void BodyMeshes()
    {
        mMug = MCyl(0.04f, 0.042f, 0.1f, 18, M_CERAMIC, true, false);
        mMugH = MTorus(0.024f, 0.007f, 12, 6, M_CERAMIC);
        mCoffee = MCyl(0.037f, 0.037f, 0.002f, 16, M_COFFEE, false, true);
        mPaper = MBox(0.21f, 0.0022f, 0.297f, M_PAPER);
        mBall = MSphere(0.032f, 0.032f, 0.032f, 10, 14, M_TINTS);
        mMouse = MRBox(0.062f, 0.035f, 0.105f, 0.017f, M_LIGHT);
        mWheel = MBox(0.008f, 0.01f, 0.018f, M_DARK);
        mBook = MRBox(0.17f, 0.032f, 0.24f, 0.003f, M_BOOK);
        mPages = MBox(0.162f, 0.026f, 0.232f, M_LIGHT);
        mStapB = MBox(0.044f, 0.014f, 0.15f, M_DARK);
        mStapT = MRBox(0.04f, 0.024f, 0.14f, 0.01f, M_TINTS);
        mPhone = MBox(0.074f, 0.01f, 0.15f, M_PHONE);
        mPad = MBox(0.08f, 0.018f, 0.08f, M_TINT);
        // bola de papel arrugada: esfera deformada
        mPBall = MSphere(0.035f, 0.035f, 0.035f, 8, 10, M_PAPER);
        Random r = new Random(3);
        for (int i = 0; i < mPBall.p.Length; i++) { float k = 0.75f + (float)r.NextDouble() * 0.45f; mPBall.p[i] = mPBall.p[i] * k; mPBall.n[i] = (mPBall.n[i] + new V((float)r.NextDouble() - 0.5f, (float)r.NextDouble() - 0.5f, (float)r.NextDouble() - 0.5f)).Norm(); }
    }

    static void DrawBodies()
    {
        foreach (Body b in bodies)
        {
            Tf t = Tf.T(b.p).Mul(Tf.Ry(b.yaw)).Mul(Tf.Rx(b.tx)).Mul(Tf.Rz(b.tz));
            switch (b.kind)
            {
                case K_MUG:
                    Draw(mMug, t.Mul(Tf.T(0, -0.05f, 0)), b.ins); Draw(mMugH, t.Mul(Tf.T(0.05f, 0.005f, 0)).Mul(Tf.Rx((float)Math.PI / 2)), b.ins);
                    Draw(mCoffee, t.Mul(Tf.T(0, 0.032f, 0)));
                    break;
                case K_PAPER: Draw(mPaper, t, b.ins); break;
                case K_PBALL: Draw(mPBall, Tf.T(b.p).Mul(Tf.Ry(b.yaw + b.spin)).Mul(Tf.Rx(b.spin)), b.ins); break;
                case K_BALL:
                {
                    float sq = b.squash * 0.25f;
                    Tf bt = Tf.T(b.p).Mul(Tf.Rx(b.spin)); bt.X = bt.X * (1 + sq); bt.Z = bt.Z * (1 + sq); bt.Y = bt.Y * (1 - sq);
                    Draw(mBall, bt, b.ins); break;
                }
                case K_MOUSE: Draw(mMouse, t); Draw(mWheel, t.Mul(Tf.T(0, 0.016f, 0.02f))); break;
                case K_BOOK: Draw(mBook, t, b.ins); Draw(mPages, t.Mul(Tf.T(0.006f, 0, 0))); break;
                case K_STAPLER: Draw(mStapB, t.Mul(Tf.T(0, -0.013f, 0))); Draw(mStapT, t.Mul(Tf.T(0, 0.006f, 0.003f)), b.ins); break;
                case K_PHONE: Draw(mPhone, t); break;
                case K_PAD: Draw(mPad, t, b.ins); break;
            }
        }
    }

    static void DrawWorld()
    {
        BeginFrame();
        foreach (Part p in scene) Draw(p.m, p.tf, p.ins);
        // boton del ordenador (se hunde al pulsar) y su luz
        float push = gt - btnPcT < 0.25 ? 0.006f : 0;
        Draw(mBtn, Tf.T(BTN_PC + new V(0, 0, push)).Mul(Tf.Rx(-(float)Math.PI / 2)), btnIns);
        ledIns.tint = pcOn ? C3(60, 160, 255) : C3(40, 40, 50);
        Draw(mLed, Tf.T(0.62f, 1.06f, 0.598f), ledIns);
        prLed.tint = gt - btnPrT < 3 ? (((int)(gt * 6)) % 2 == 0 ? C3(60, 255, 90) : C3(20, 60, 30)) : C3(60, 200, 90);
        Draw(mLed, Tf.T(1.32f, 0.924f, 0.6f), prLed);
        DrawPerson();
        DrawBodies();
    }
    static Mesh mBtn, mLed; static Inst btnIns = new Inst(), ledIns = new Inst(), prLed = new Inst();
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

    // ================================================================ seguimiento de manos y cabeza (vision por ordenador clasica)
    const int GW = 192, GH = 144;
    static byte[] gY = new byte[GW * GH], gCr = new byte[GW * GH], gCb = new byte[GW * GH];
    static int[] prevRGB = new int[GW * GH];
    static float[] bgY = new float[GW * GH], bgCr = new float[GW * GH], bgCb = new float[GW * GH];
    static bool bgOk; static int bgN;
    static byte[] hm = new byte[GW * GH], sm = new byte[GW * GH], tmpM = new byte[GW * GH];
    static int[] lab = new int[GW * GH], qbuf = new int[GW * GH];
    static bool[] tkOk = new bool[2]; static float[] tkU = new float[2], tkV = new float[2], tkS = new float[2], tkPx = new float[2], tkPy = new float[2];
    static int[] tkF = new int[2]; static int[,] fHist = new int[2, 7]; static int fHi;
    static double[] tkSeen = { -9, -9 }, tkGoodT = { -9, -9 }; static int[] tkHits = new int[2]; static double noHandT = 0, noHandMsgT = -99;
    static bool faceOk; static float faceU = 0.5f, faceV = 0.3f, faceS = 0.2f, face0U = 0.5f, face0V = 0.3f, face0S = 0.2f, handRef = 0.12f;
    static int faceX0, faceY0, faceX1, faceY1;
    static int calStep; static bool camActive; static int frameNo;
    static byte[] img; static int iw_, ih_, istride, lastId = -1;

    class Blob { public int id, area, x0, y0, x1, y1; public float cx, cy; }

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

    static double badT = -99;
    static bool camMirror = false;   // G: invertir izquierda/derecha
    // Basado en las tecnicas clasicas de OpenCV:
    //  - "back projection" de un histograma Cr/Cb de tu piel frente al del fondo (Jones & Rehg)
    //  - deteccion de movimiento por diferencia de fotogramas (con memoria)
    //  - seguimiento de cada mano con mean-shift / CamShift sobre el mapa de probabilidad
    const int HB = 32;
    static float[] skP = new float[HB * HB];
    static bool skInit;
    static float[] prob = new float[GW * GH], motion = new float[GW * GH];
    static byte[] prevY = new byte[GW * GH];
    static float[] wX = { 60, 130 }, wY = { 90, 90 }, wS = { 24, 24 };
    static bool[] wOn = new bool[2];
    static int[] wLost = new int[2];

    static void DefaultSkin()
    {
        for (int a = 0; a < HB; a++)
            for (int b = 0; b < HB; b++)
            {
                float u = (a * 8 + 4 - 153) / 16f, v = (b * 8 + 4 - 104) / 18f;
                skP[a * HB + b] = (float)Math.Exp(-(u * u + v * v) * 1.2);
            }
    }

    static void FlipBg()
    {
        for (int y = 0; y < GH; y++)
            for (int x = 0; x < GW / 2; x++)
            {
                int i = y * GW + x, j = y * GW + GW - 1 - x; float t; byte c;
                t = bgY[i]; bgY[i] = bgY[j]; bgY[j] = t;
                t = bgCr[i]; bgCr[i] = bgCr[j]; bgCr[j] = t;
                t = bgCb[i]; bgCb[i] = bgCb[j]; bgCb[j] = t;
                t = motion[i]; motion[i] = motion[j]; motion[j] = t;
                c = prevY[i]; prevY[i] = prevY[j]; prevY[j] = c;
            }
        for (int h = 0; h < 2; h++) { wX[h] = GW - 1 - wX[h]; wOn[h] = false; }
    }

    static bool Fg(int i)
    {
        return !bgOk || Math.Abs(gY[i] - bgY[i]) > 20 || Math.Abs(gCr[i] - bgCr[i]) + Math.Abs(gCb[i] - bgCb[i]) > 12;
    }

    static void TrackFrame()
    {
        if (!skInit) { DefaultSkin(); skInit = true; }
        frameNo++;
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
                prevRGB[i] = (R << 16) | (G << 8) | B;
                gY[i] = (byte)(0.299f * R + 0.587f * G + 0.114f * B);
                gCr[i] = (byte)Clampf(128 + 0.5f * R - 0.4187f * G - 0.0813f * B, 0, 255);
                gCb[i] = (byte)Clampf(128 - 0.1687f * R - 0.3313f * G + 0.5f * B, 0, 255);
            }
        }
        if (calStep == 3)
        {
            for (int i = 0; i < GW * GH; i++) { bgY[i] += gY[i]; bgCr[i] += gCr[i]; bgCb[i] += gCb[i]; }
            bgN++;
            if (bgN >= 15) { for (int i = 0; i < GW * GH; i++) { bgY[i] /= bgN; bgCr[i] /= bgN; bgCb[i] /= bgN; } bgOk = true; calStep = 2; }
            return;
        }
        // movimiento + probabilidad de piel + primer plano
        for (int i = 0; i < GW * GH; i++)
        {
            int d = Math.Abs(gY[i] - prevY[i]);
            motion[i] = d > 16 ? 1f : motion[i] * 0.88f;
            prevY[i] = gY[i];
            float p = gY[i] < 35 ? 0 : skP[(gCr[i] >> 3) * HB + (gCb[i] >> 3)];
            sm[i] = (byte)(p > 0.45f ? 1 : 0);
            float hp = p * (Fg(i) ? 1f : 0.15f) * (0.75f + 0.25f * motion[i]);
            prob[i] = hp;
            hm[i] = (byte)(hp > 0.4f ? 1 : 0);
        }
        Morph(hm); Morph(sm);
        // cabeza: la mancha de piel grande de la parte de arriba
        List<Blob> fb = Blobs(sm, 60);
        Blob face = null; float fscore = -1;
        foreach (Blob b in fb)
        {
            if (b.cy > GH * 0.7f || b.area > GW * GH * 0.22f) continue;
            int bw = b.x1 - b.x0 + 1, bh = b.y1 - b.y0 + 1;
            if (bw > bh * 2.2f || bh > bw * 3) continue;
            if (InHand(b.cx, b.cy, 1.0f)) continue;     // una mano no es la cara
            float dx = b.cx / GW - faceU, dy = b.cy / GH - faceV;
            float sc = b.area * (float)Math.Exp(-(dx * dx + dy * dy) / 0.03) * (1.3f - b.cy / GH);
            if (sc > fscore) { fscore = sc; face = b; }
        }
        faceOk = face != null;
        if (faceOk)
        {
            faceU = Lf(faceU, face.cx / GW, 0.4f); faceV = Lf(faceV, face.cy / GH, 0.4f); faceS = Lf(faceS, (float)Math.Sqrt(face.area) / GW, 0.3f);
            faceX0 = face.x0; faceY0 = face.y0; faceX1 = face.x1; faceY1 = face.y1;
            // la cara nunca es una mano
            int fw = face.x1 - face.x0 + 1, fh = face.y1 - face.y0 + 1;
            int ex0 = Math.Max(0, face.x0 - fw / 5), ex1 = Math.Min(GW - 1, face.x1 + fw / 5), ey0 = Math.Max(0, face.y0 - fh / 5), ey1 = Math.Min(GH - 1, face.y1 + fh / 6);
            // y el cuello
            for (int y = ey1; y <= Math.Min(GH - 1, face.y1 + fh * 2 / 3); y++) for (int x = Math.Max(0, (int)face.cx - fw / 3); x <= Math.Min(GW - 1, (int)face.cx + fw / 3); x++) { if (InHand(x, y, 1.3f)) continue; int i = y * GW + x; prob[i] = 0; hm[i] = 0; }
            for (int y = ey0; y <= ey1; y++) for (int x = ex0; x <= ex1; x++) { if (InHand(x, y, 1.3f)) continue; int i = y * GW + x; prob[i] = 0; hm[i] = 0; }
        }
        // el fondo se adapta a los cambios de luz (salvo donde hay piel o movimiento)
        if (bgOk)
        {
            int cov = 0;
            for (int i = 0; i < GW * GH; i++)
            {
                if (hm[i] != 0) cov++;
                if (motion[i] > 0.2f) continue;
                // el fondo visible se adapta rapido a la luz; lo que lo tapa, muy despacio (sin "fantasmas")
                float k = !Fg(i) ? 0.05f : sm[i] == 0 ? 0.002f : 0f;
                if (k == 0) continue;
                bgY[i] += (gY[i] - bgY[i]) * k; bgCr[i] += (gCr[i] - bgCr[i]) * k; bgCb[i] += (gCb[i] - bgCb[i]) * k;
            }
            if (cov > GW * GH * 0.3f && gt - badT > 6) { badT = gt; Msg("Detecto demasiada 'piel' en la imagen: pulsa C para recalibrar"); }
        }
        List<Blob> hb = Blobs(hm, 30);
        // 1) seguir las manos que ya tenemos
        for (int h = 0; h < 2; h++) if (wOn[h]) MeanShift(h);
        if (wOn[0] && wOn[1])
        {
            float dx = wX[0] - wX[1], dy = wY[0] - wY[1];
            if (Math.Sqrt(dx * dx + dy * dy) < (wS[0] + wS[1]) * 0.4f) wOn[wLost[0] > wLost[1] ? 0 : 1] = false;
            else if (wX[0] > wX[1] + 4) { float t = wX[0]; wX[0] = wX[1]; wX[1] = t; t = wY[0]; wY[0] = wY[1]; wY[1] = t; t = wS[0]; wS[0] = wS[1]; wS[1] = t; }
        }
        // 2) buscar manos nuevas: manchas de piel que se mueven
        float minA = Math.Max(110, handRef * GW * handRef * GW * 0.3f);
        if (!wOn[0] || !wOn[1])
        {
            hb.Sort(delegate(Blob p, Blob q) { return q.area.CompareTo(p.area); });
            foreach (Blob b in hb)
            {
                if (wOn[0] && wOn[1]) break;
                if (b.area < minA || b.area > GW * GH * 0.16f) continue;
                bool taken = false;
                for (int h = 0; h < 2; h++) if (wOn[h] && Math.Abs(b.cx - wX[h]) < wS[h] * 1.2f && Math.Abs(b.cy - wY[h]) < wS[h] * 1.5f) taken = true;
                if (taken) continue;
                if (faceOk && b.cy < face.y1 + (face.y1 - face.y0) * 0.6f && Math.Abs(b.cx - face.cx) < (face.x1 - face.x0 + 1) * 0.9f) continue;
                // tiene que moverse para "engancharla"
                float mv = 0; int mn = 0;
                for (int y = b.y0; y <= b.y1; y += 2) for (int x = b.x0; x <= b.x1; x += 2) { int i = y * GW + x; if (lab[i] == b.id) { mv += motion[i]; mn++; } }
                if (mn == 0 || mv / mn < 0.1f) continue;
                int hh;
                if (!wOn[0] && !wOn[1]) hh = b.cx < (faceOk ? face.cx : GW / 2f) ? 0 : 1;
                else if (wOn[0]) { if (b.cx < wX[0]) continue; hh = 1; }
                else { if (b.cx > wX[1]) continue; hh = 0; }
                wOn[hh] = true; wX[hh] = b.cx; wY[hh] = b.cy; wS[hh] = Clampf((float)Math.Sqrt(b.area) * 0.85f, 10, 70); wLost[hh] = 0;
                for (int k = 0; k < 7; k++) fHist[hh, k] = 5;
            }
        }
        // 3) posicion, tamano y dedos de cada mano
        bool[] used = new bool[2];
        for (int h = 0; h < 2; h++)
        {
            if (!wOn[h]) continue;
            Blob best = null; int bestN = 0;
            int r = (int)wS[h];
            int x0 = Math.Max(0, (int)(wX[h] - r * 1.4f)), x1 = Math.Min(GW - 1, (int)(wX[h] + r * 1.4f)), y0 = Math.Max(0, (int)(wY[h] - r * 1.8f)), y1 = Math.Min(GH - 1, (int)(wY[h] + r * 1.2f));
            foreach (Blob b in hb)
            {
                if (b.x1 < x0 || b.x0 > x1 || b.y1 < y0 || b.y0 > y1) continue;
                int n = 0;
                for (int y = Math.Max(y0, b.y0); y <= Math.Min(y1, b.y1); y += 2) for (int x = Math.Max(x0, b.x0); x <= Math.Min(x1, b.x1); x += 2) if (lab[y * GW + x] == b.id) n++;
                if (n > bestN) { bestN = n; best = b; }
            }
            if (best != null && bestN * 4 > 20)
            {
                Blob c = new Blob(); c.id = best.id; c.area = best.area;
                c.x0 = Math.Max(x0, best.x0); c.x1 = Math.Min(x1, best.x1); c.y0 = Math.Max(y0, best.y0); c.y1 = Math.Min(y1, best.y1);
                c.cx = wX[h]; c.cy = wY[h];
                HandFeat(h, c);
            }
            else
            {
                tkU[h] = Lf(tkU[h], wX[h] / GW, 0.5f); tkV[h] = Lf(tkV[h], wY[h] / GH, 0.5f);
                tkPx[h] = wX[h]; tkPy[h] = wY[h]; tkSeen[h] = gt;
            }
            used[h] = true;
        }
        fHi = (fHi + 1) % 7;
        for (int h = 0; h < 2; h++)
        {
            tkHits[h] = used[h] ? tkHits[h] + 1 : 0;
            tkOk[h] = tkHits[h] >= 2;
            if (tkOk[h]) tkGoodT[h] = gt;
        }
        if (tkOk[0] || tkOk[1]) noHandT = gt;
        else if (calStep == 0 && gt - noHandT > 2.5 && gt - noHandMsgT > 8) { noHandMsgT = gt; Msg("No veo tus manos: levantalas delante del pecho y muevelas un poco"); }
    }

    static bool InHand(float x, float y, float k)
    {
        for (int h = 0; h < 2; h++) if (wOn[h] && Math.Abs(x - wX[h]) < wS[h] * k && Math.Abs(y - wY[h]) < wS[h] * k * 1.3f) return true;
        return false;
    }

    // mean-shift: la ventana va hacia donde se concentra la probabilidad de "mano"
    static void MeanShift(int h)
    {
        float m0 = 0; int cntN = 0;
        for (int it = 0; it < 6; it++)
        {
            int r = (int)wS[h];
            int x0 = Math.Max(0, (int)wX[h] - r), x1 = Math.Min(GW - 1, (int)wX[h] + r), y0 = Math.Max(0, (int)wY[h] - r), y1 = Math.Min(GH - 1, (int)wY[h] + r);
            float sx = 0, sy = 0; m0 = 0; cntN = 0;
            for (int y = y0; y <= y1; y++)
            {
                float wy = y < wY[h] ? 1f : 0.7f;   // el antebrazo no tira de la ventana
                for (int x = x0; x <= x1; x++)
                {
                    float p = prob[y * GW + x];
                    if (p < 0.2f) continue;
                    cntN++; p *= wy; m0 += p; sx += p * x; sy += p * y;
                }
            }
            if (m0 < 1) break;
            float nx = sx / m0, ny = sy / m0;
            bool done = Math.Abs(nx - wX[h]) < 0.5f && Math.Abs(ny - wY[h]) < 0.5f;
            wX[h] = nx; wY[h] = ny;
            if (done) break;
        }
        float minM = Math.Max(40, handRef * GW * handRef * GW * 0.18f);
        if (m0 < minM) { if (++wLost[h] > 8) wOn[h] = false; }
        else { wLost[h] = 0; wS[h] = Lf(wS[h], Clampf((float)Math.Sqrt(cntN) * 0.85f, 10, 70), 0.3f); }
    }

    static void Morph(byte[] m)
    {
        // apertura: erosion + dilatacion (quita ruido)
        for (int y = 0; y < GH; y++)
            for (int x = 0; x < GW; x++)
            {
                int i = y * GW + x; byte v = m[i];
                if (v != 0 && (x == 0 || y == 0 || x == GW - 1 || y == GH - 1 || m[i - 1] == 0 || m[i + 1] == 0 || m[i - GW] == 0 || m[i + GW] == 0)) v = 0;
                tmpM[i] = v;
            }
        for (int y = 0; y < GH; y++)
            for (int x = 0; x < GW; x++)
            {
                int i = y * GW + x;
                m[i] = (byte)((tmpM[i] != 0 || (x > 0 && tmpM[i - 1] != 0) || (x < GW - 1 && tmpM[i + 1] != 0) || (y > 0 && tmpM[i - GW] != 0) || (y < GH - 1 && tmpM[i + GW] != 0)) ? 1 : 0);
            }
    }

    static List<Blob> Blobs(byte[] m, int minArea)
    {
        List<Blob> res = new List<Blob>();
        for (int i = 0; i < GW * GH; i++) lab[i] = 0;
        int next = 1;
        for (int s = 0; s < GW * GH; s++)
        {
            if (m[s] == 0 || lab[s] != 0) continue;
            Blob b = new Blob(); b.id = next++; b.x0 = GW; b.y0 = GH; b.x1 = 0; b.y1 = 0;
            int qh = 0, qt = 0; qbuf[qt++] = s; lab[s] = b.id;
            long sx = 0, sy = 0;
            while (qh < qt)
            {
                int i = qbuf[qh++], x = i % GW, y = i / GW;
                b.area++; sx += x; sy += y;
                if (x < b.x0) b.x0 = x; if (x > b.x1) b.x1 = x; if (y < b.y0) b.y0 = y; if (y > b.y1) b.y1 = y;
                if (x > 0 && m[i - 1] != 0 && lab[i - 1] == 0) { lab[i - 1] = b.id; qbuf[qt++] = i - 1; }
                if (x < GW - 1 && m[i + 1] != 0 && lab[i + 1] == 0) { lab[i + 1] = b.id; qbuf[qt++] = i + 1; }
                if (y > 0 && m[i - GW] != 0 && lab[i - GW] == 0) { lab[i - GW] = b.id; qbuf[qt++] = i - GW; }
                if (y < GH - 1 && m[i + GW] != 0 && lab[i + GW] == 0) { lab[i + GW] = b.id; qbuf[qt++] = i + GW; }
            }
            if (b.area >= minArea) { b.cx = (float)sx / b.area; b.cy = (float)sy / b.area; res.Add(b); }
        }
        return res;
    }

    static byte[] hreg = new byte[GW * GH];

    // posicion de la mano, tamano y numero de dedos extendidos
    static void HandFeat(int h, Blob b)
    {
        int bw = b.x1 - b.x0 + 1;
        int yEnd = Math.Min(b.y1, b.y0 + (int)Math.Max(bw * 1.25f, (b.y1 - b.y0 + 1) * 0.45f));
        int n = 0; long sx = 0, sy = 0;
        for (int i = 0; i < GW * GH; i++) hreg[i] = 0;
        for (int y = b.y0; y <= yEnd; y++)
            for (int x = b.x0; x <= b.x1; x++)
            {
                int i = y * GW + x;
                if (lab[i] == b.id) { hreg[i] = 1; n++; sx += x; sy += y; }
            }
        if (n < 20) return;
        float cx = (float)sx / n, cy = (float)sy / n;
        // centro de la palma: erosionar hasta quitar los dedos
        int er = Math.Max(1, (int)Math.Round(bw * 0.11f));
        for (int i = 0; i < GW * GH; i++) tmpM[i] = hreg[i];
        for (int k = 0; k < er; k++)
        {
            for (int y = Math.Max(1, b.y0); y <= Math.Min(GH - 2, yEnd); y++)
                for (int x = Math.Max(1, b.x0); x <= Math.Min(GW - 2, b.x1); x++)
                {
                    int i = y * GW + x;
                    sm[i] = (byte)(tmpM[i] != 0 && tmpM[i - 1] != 0 && tmpM[i + 1] != 0 && tmpM[i - GW] != 0 && tmpM[i + GW] != 0 ? 1 : 0);
                }
            for (int y = Math.Max(1, b.y0); y <= Math.Min(GH - 2, yEnd); y++)
                for (int x = Math.Max(1, b.x0); x <= Math.Min(GW - 2, b.x1); x++) { int i = y * GW + x; tmpM[i] = sm[i]; }
        }
        int pn = 0; long px = 0, py = 0;
        for (int y = b.y0; y <= yEnd; y++) for (int x = b.x0; x <= b.x1; x++) { int i = y * GW + x; if (tmpM[i] != 0) { pn++; px += x; py += y; } }
        float pcx = pn > 3 ? (float)px / pn : cx, pcy = pn > 3 ? (float)py / pn : cy + (yEnd - b.y0) * 0.15f;
        float pr = (float)Math.Sqrt(Math.Max(1, pn) / Math.PI) + er;
        // circulos alrededor de la palma: cada dedo corta el circulo una vez (metodo clasico de los tutoriales de OpenCV)
        int runs = 0;
        foreach (float kr in new float[] { 1.45f, 1.7f, 1.95f })
        {
            float R = pr * kr;
            int N = Math.Max(72, (int)(Math.PI * 2 * R * 2));
            int first = -1, nRun = 0, len = 0; bool prev = false;
            // empezamos en un punto de abajo (excluido) para no partir un dedo
            for (int k = 0; k <= N; k++)
            {
                double ang = Math.PI / 2 + k * Math.PI * 2 / N;
                float dx = (float)Math.Cos(ang), dy = (float)Math.Sin(ang);
                int x = (int)Math.Round(pcx + dx * R), y = (int)Math.Round(pcy + dy * R);
                bool on = dy < 0.5f && x >= 0 && y >= 0 && x < GW && y < GH && y <= yEnd + 2 && lab[y * GW + x] == b.id;
                if (on) len++;
                else if (prev)
                {
                    float w = len * (float)(Math.PI * 2 * R / N);
                    if (w >= 1.2f && w <= Math.Max(4f, pr * 1.1f)) nRun++;
                    len = 0;
                }
                prev = on;
                if (first < 0) first = k;
            }
            runs = Math.Max(runs, nRun);
        }
        int fingers = Math.Min(5, runs);
        fHist[h, fHi] = fingers;
        int[] cnt = new int[6]; for (int k = 0; k < 7; k++) cnt[fHist[h, k]]++;
        int bestF = 0; for (int f = 1; f <= 5; f++) if (cnt[f] > cnt[bestF]) bestF = f;
        tkF[h] = bestF >= 4 ? 5 : bestF;   // con 4 o 5 dedos la mano esta abierta (el pulgar a veces no se ve)
        tkU[h] = Lf(tkU[h], pcx / GW, 0.5f); tkV[h] = Lf(tkV[h], pcy / GH, 0.5f); tkS[h] = Lf(tkS[h], (float)Math.Sqrt(n) / GW, 0.35f);
        tkPx[h] = pcx; tkPy[h] = pcy;
        tkSeen[h] = gt;
    }

    // de la imagen de la camara a la mesa del personaje
    static void ApplyTracking(double dt)
    {
        for (int h = 0; h < 2; h++)
        {
            if (tkOk[h] || gt - tkGoodT[h] < 0.4)
            {
                float x = Clampf((tkU[h] - 0.5f) * 1.3f, -0.75f, 0.85f);
                float y = 0.6f + Sat((0.98f - tkV[h]) / 0.78f) * 0.8f;
                float z = Clampf(0.42f + (tkS[h] / handRef - 1) * 0.5f, Math.Abs(x) > 0.5f ? 0.0f : 0.3f, 0.84f);
                hTgt[h] = LerpV(hTgt[h], new V(x, y, z), (float)Math.Min(1, dt * 10));
                hFingers[h] = tkF[h];
            }
            else
            {
                V rest = new V(h == 0 ? -0.17f : 0.17f, 0.8f, 0.27f);
                hTgt[h] = LerpV(hTgt[h], rest, (float)Math.Min(1, dt * 2));
                hFingers[h] = 5;
            }
        }
        if (faceOk)
        {
            leanF = Lf(leanF, 0.1f + Clampf((faceS / face0S - 1) * 0.7f, -0.15f, 0.3f), 0.2f);
            leanS = Lf(leanS, Clampf((faceU - face0U) * 1.0f, -0.22f, 0.22f), 0.2f);
            headYaw = Lf(headYaw, Clampf((faceU - face0U) * 1.2f, -0.45f, 0.45f), 0.2f);
            headPitch = Lf(headPitch, -0.15f + Clampf((faceV - face0V) * 1.4f, -0.4f, 0.4f), 0.2f);
        }
    }

    // calibracion: 1 fondo, 2 histograma de tu piel frente al del resto de la imagen
    static void CalibrateSkin()
    {
        int cx = GW / 2, cy = GH / 2, rr = 14;
        float[] hs = new float[HB * HB], hg = new float[HB * HB]; int ns = 0, ng = 0;
        for (int y = 0; y < GH; y++)
            for (int x = 0; x < GW; x++)
            {
                int i = y * GW + x, bin = (gCr[i] >> 3) * HB + (gCb[i] >> 3);
                if (Math.Abs(x - cx) < rr && Math.Abs(y - cy) < rr) { if (Fg(i) && gY[i] > 35) { hs[bin]++; ns++; } }
                else if (Math.Abs(x - cx) > rr + 4 || Math.Abs(y - cy) > rr + 4)
                {
                    if (faceOk && x >= faceX0 && x <= faceX1 && y >= faceY0 && y <= faceY1) continue;
                    hg[bin]++; ng++;
                }
            }
        if (ns < 40) { Msg("No veo tu mano en el recuadro: acercala y pulsa ESPACIO otra vez"); return; }
        hs = Blur(hs); hg = Blur(hg);
        float mx = 0; for (int k = 0; k < HB * HB; k++) mx = Math.Max(mx, hs[k]);
        for (int k = 0; k < HB * HB; k++)
        {
            float ps = hs[k] / ns, pg = hg[k] / Math.Max(1, ng);
            float r = ps / (ps + pg + 0.3f / ns);
            float conf = Sat(hs[k] / (mx * 0.04f + 1e-6f));
            skP[k] = Sat(r * 1.2f) * conf;
        }
        skInit = true;
        handRef = Clampf((float)Math.Sqrt(ns) / GW * 1.3f, 0.06f, 0.3f);
        if (faceOk) { face0U = faceU; face0V = faceV; face0S = faceS; }
        wOn[0] = wOn[1] = false;
        calStep = 0;
        Msg("Calibrado! Mueve las manos delante del pecho: puno = coger, mano abierta = soltar, un dedo = pulsar");
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
    static Random rnd = new Random(9);
    static volatile bool quit; static bool dumping;
    static double gt;
    static V camTarget; static float camFov = 1.05f;
    static int view; static bool manual, showCam = true, help;

    // ================================================================ arranque
    public static void Run()
    {
        Setup();
        if (!win && Environment.OSVersion.Platform == PlatformID.Win32NT) { Console.WriteLine("Esta consola no soporta colores ANSI (hace falta Windows 10 o superior)."); return; }
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
    static double fps, fpsT; static int fpsN;

    // modo de prueba: un guion mueve las manos y se vuelcan fotogramas
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
                    StringBuilder held = new StringBuilder();
                    for (int hh = 0; hh < 2; hh++) held.Append(heldB[hh] != null ? KNAME[heldB[hh].kind] : "-").Append(hh == 0 ? "|" : "");
                    o.WriteLine("F " + T.ToString("0.00", CultureInfo.InvariantCulture) + " pc=" + pcOn + " os=" + osState + " lamp=" + lampOn + " notes='" + notes.ToString().Replace("\n", "/") + "' bin=" + binCount +
                        " held=" + held + " bodies=" + bodies.Count + " tris=" + nT + " ms/frame=" + (sw.Elapsed.TotalMilliseconds / frames).ToString("0", CultureInfo.InvariantCulture) + " msg='" + msg + "'" + DbgS());
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

    static string Dbg(V v) { return "(" + v.x.ToString("0.00", CultureInfo.InvariantCulture) + "," + v.y.ToString("0.00", CultureInfo.InvariantCulture) + "," + v.z.ToString("0.00", CultureInfo.InvariantCulture) + ")"; }
    static string DbgS()
    {
        string r = " cur=" + (int)curX + "," + (int)curY + " pL=" + Dbg(palmC[0]) + " pR=" + Dbg(palmC[1]) + " tL=" + Dbg(tips[0, 0]) + " tR=" + Dbg(tips[1, 0]) + " hR=" + Dbg(hPos[1]) + " c=" + curl[1, 0].ToString("0.0") + "/" + curl[1, 1].ToString("0.0");
        foreach (Body b in bodies) if (b.kind == K_MUG || b.kind == K_PBALL || b.kind == K_MOUSE) r += " " + b.kind + "=" + Dbg(b.p);
        return r;
    }
    static void Init()
    {
        InitMats(); InitFont(); BuildScene(); ResetBodies(); CharMeshes(); BodyMeshes(); HandsInit();
        mBtn = MCyl(0.014f, 0.014f, 0.012f, 14, M_METAL, false, true); mLed = MBox(0.03f, 0.004f, 0.004f, M_LED);
        btnIns.tint = C3(200, 200, 210);
        manual = dumping;
        msg = "Bienvenido a la oficina"; msgT = 0;
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
    static bool Key(int vk) { return kNow[vk]; }
    static bool Press(int vk) { return kNow[vk] && !kPrev[vk]; }
    static readonly int[] WATCH = { 0x1B, 0x20, 0x0D, 0x09, 0x70, 0x71, 0x72, 0x73, 0x25, 0x26, 0x27, 0x28, 0x6B, 0x6D, 0xBB, 0xBD,
        'A', 'D', 'W', 'S', 'Q', 'E', 'Z', 'X', 'J', 'L', 'I', 'K', 'U', 'O', 'M', 'N', 'C', 'T', 'R', 'H', 'V', 'G' };

    static void ReadInput()
    {
        for (int i = 0; i < 256; i++) kPrev[i] = kNow[i];
        if (dumping) return;
        try
        {
            foreach (int vk in WATCH) kNow[vk] = (GetAsyncKeyState(vk) & 0x8000) != 0;
            FlushConsoleInputBuffer(hIn);
        }
        catch
        {
            for (int i = 0; i < 256; i++) kNow[i] = false;
            try { while (Console.KeyAvailable) { ConsoleKeyInfo k = Console.ReadKey(true); int vk = (int)k.Key; if (vk < 256) kNow[vk] = true; } } catch { }
        }
    }

    // ================================================================ cada fotograma
    static void Frame(double dt)
    {
        gt += dt;
        if (Press(0x1B)) { quit = true; return; }
        if (Press(0x09)) showCam = !showCam;
        if (Press('T')) { manual = !manual; Msg(manual ? "Control con el teclado" : "Control con la camara"); }
        if (Press('R')) { ResetBodies(); Msg("Mesa recogida"); }
        if (Press('H')) help = !help;
        if (Press('G')) { camMirror = !camMirror; FlipBg(); tkU[0] = 1 - tkU[0]; tkU[1] = 1 - tkU[1]; faceU = 1 - faceU; face0U = 1 - face0U; Msg("Camara invertida (izquierda <-> derecha)"); }
        if (Press('C') && camActive) { calStep = 1; Msg("Recalibrando"); }
        if (Press(0x70)) view = 0; if (Press(0x71)) view = 1; if (Press(0x72)) view = 2; if (Press(0x73)) view = 3;
        if (Press(0x6B) || Press(0xBB)) { if (fontCtl) { fIdx = Math.Max(0, fIdx - 1); ApplyFont(); } else Msg("En Windows Terminal: Ctrl + '-' para mas detalle"); }
        if (Press(0x6D) || Press(0xBD)) { if (fontCtl) { fIdx = Math.Min(FSIZES.Length - 1, fIdx + 1); ApplyFont(); } }

        bool fresh = !dumping && GrabFrame();
        if (fresh)
        {
            if (calStep == 0 && frameNo == 0 && !bgOk) calStep = 1;
            if (calStep == 1 && Press(0x20)) { for (int i = 0; i < GW * GH; i++) { bgY[i] = 0; bgCr[i] = 0; bgCb[i] = 0; } bgN = 0; bgOk = false; calStep = 3; }
            else if (calStep == 2 && Press(0x20)) CalibrateSkin();
            if ((calStep == 1 || calStep == 2) && Press(0x0D)) { calStep = 0; Msg("Calibracion saltada (se usan valores por defecto)"); }
            TrackFrame();
        }
        if (dumping) Script(gt);
        else if (manual || !camActive) Manual(dt);
        else if (calStep == 0) ApplyTracking(dt);

        UpdateHands(dt);
        BodyColliders();
        HandPush();
        Physics(dt);
        Interact();
        OsUpdate(dt);

        // camara de la escena
        V[] cp = { new V(0.45f, 2.05f, -0.8f), new V(-1.25f, 1.45f, 0.1f), new V(0.05f, 1.55f, 1.35f), new V(1.3f, 1.9f, -0.9f) };
        V[] ct = { new V(-0.08f, 0.8f, 0.52f), new V(0.15f, 0.95f, 0.5f), new V(0, 1.05f, 0.1f), new V(0, 0.85f, 0.45f) };
        V tp = cp[view] + new V((float)Math.Sin(gt * 0.25) * 0.03f, (float)Math.Sin(gt * 0.31) * 0.015f, 0);
        camPos = gt < 0.1 ? tp : LerpV(camPos, tp, (float)Math.Min(1, dt * 3));
        camTarget = gt < 0.1 ? ct[view] : LerpV(camTarget, ct[view], (float)Math.Min(1, dt * 3));

        DrawWorld();
        RasterAll();
        ShadowPass();
        ShadePass();
        Resolve();
        HudPix();
        ToCells();
        HudText();
    }

    // control con el teclado: WASD/QE + Z X (izquierda), IJKL/UO + M N (derecha)
    static void Manual(double dt)
    {
        float s = (float)dt * 0.45f;
        int[,] keys = { { 'A', 'D', 'W', 'S', 'Q', 'E', 'Z', 'X' }, { 'J', 'L', 'I', 'K', 'U', 'O', 'M', 'N' } };
        for (int h = 0; h < 2; h++)
        {
            V t = hTgt[h];
            if (Key(keys[h, 0])) t.x -= s; if (Key(keys[h, 1])) t.x += s;
            if (Key(keys[h, 2])) t.z += s; if (Key(keys[h, 3])) t.z -= s;
            if (Key(keys[h, 4])) t.y -= s; if (Key(keys[h, 5])) t.y += s;
            hTgt[h] = new V(Clampf(t.x, -0.85f, 0.95f), Clampf(t.y, 0.45f, 1.6f), Clampf(t.z, -0.15f, 0.84f));
            hFingers[h] = Key(keys[h, 6]) ? 0 : Key(keys[h, 7]) ? 1 : 5;
        }
        if (Key(0x26)) leanF = Math.Min(0.5f, leanF + (float)dt * 0.5f); if (Key(0x28)) leanF = Math.Max(-0.15f, leanF - (float)dt * 0.5f);
        if (Key(0x25)) leanS = Math.Max(-0.35f, leanS - (float)dt * 0.5f); if (Key(0x27)) leanS = Math.Min(0.35f, leanS + (float)dt * 0.5f);
        headYaw = leanS * 0.8f;
    }

    // guion de la prueba automatica
    static void Script(double t)
    {
        V L = new V(-0.17f, 0.8f, 0.27f), R = new V(0.17f, 0.8f, 0.27f);
        hFingers[0] = 5; hFingers[1] = 5;
        if (t < 1.5) { }
        else if (t < 3.5) { R = new V(0.62f, 1.16f, 0.48f); hFingers[1] = 1; if (t > 2.5) R = new V(0.62f, 1.16f, 0.55f); }
        else if (t < 9)
        {
            // teclear con las dos manos
            double ph = t * 3;
            L = new V(-0.1f + (float)Math.Sin(ph) * 0.06f, KB_TOP + 0.05f + (float)Math.Max(0, Math.Sin(ph * 2.3)) * 0.06f, 0.36f);
            R = new V(0.1f + (float)Math.Cos(ph * 1.3) * 0.06f, KB_TOP + 0.05f + (float)Math.Max(0, Math.Cos(ph * 2.1)) * 0.06f, 0.37f);
            hFingers[0] = 1; hFingers[1] = 1;
        }
        else if (t < 13)
        {
            // coger la taza, levantarla y dejarla en otro sitio
            L = new V(-0.37f, 0.83f, 0.40f);
            if (t > 10) hFingers[0] = 0;
            if (t > 10.6) L = new V(-0.28f, 1.0f, 0.45f);
            if (t > 11.6) L = new V(-0.08f, 0.86f, 0.64f);
            if (t > 12.5) hFingers[0] = 5;
            if (t > 12.7) L = new V(-0.12f, 0.95f, 0.5f);
        }
        else if (t < 19)
        {
            // coger un folio, arrugarlo y tirarlo a la papelera
            L = new V(-0.52f, 0.82f, 0.62f);
            if (t > 14) hFingers[0] = 0;
            if (t > 15.3) L = new V(-0.35f, 1.0f, 0.3f);
            if (t > 16.6) L = new V(-0.58f, 0.72f, 0.0f);
            if (t > 17.4) hFingers[0] = 5;
        }
        else if (t < 24)
        {
            // raton: llevar el cursor a IMPRIMIR y esperar
            R = new V(0.36f, 0.82f, 0.46f);
            if (t > 19.6) hFingers[1] = 0;
            float k = Clampf((float)(t - 20.2), 0, 1);
            R = R + new V(0.07f, 0, 0.09f) * k;
            if (t > 23.4) hFingers[1] = 5;
        }
        else if (t < 28) { L = new V(-0.62f, 0.86f, 0.74f); hFingers[0] = 1; if (t > 25.5) L = new V(-0.62f, 0.8f, 0.815f); if (t > 26.5) L = new V(-0.4f, 0.95f, 0.6f); }
        else if (t < 32)
        {
            // coger la pelota y lanzarla
            R = new V(0.2f, 0.8f, 0.64f);
            if (t > 28.8) hFingers[1] = 0;
            if (t > 29.5) R = new V(0.22f, 1.1f, 0.35f);
            if (t > 30.6) R = new V(0.1f, 1.2f, 0.8f);
            if (t > 30.75) hFingers[1] = 5;
        }
        hTgt[0] = L; hTgt[1] = R;
        leanF = 0.1f + (float)Math.Sin(t * 0.5) * 0.05f;
    }

    // ================================================================ interfaz
    static string msg = ""; static double msgT = -9;
    static void Msg(string s) { msg = s; msgT = gt; }

    static void Panel(int cx, int cy, int cw, int ch, float a)
    {
        for (int y = cy * 2; y < Math.Min(PH, (cy + ch) * 2); y++)
            for (int x = Math.Max(0, cx); x < Math.Min(PW, cx + cw); x++) { int i = y * PW + x; pix[i] = Lerp(pix[i], 0x060812, a); }
    }

    static void HudPix()
    {
        Panel(0, 0, Math.Min(W, 44), 4, 0.7f);
        if (gt - msgT < 4 && msg.Length > 0) Panel((W - msg.Length - 4) / 2, 5, msg.Length + 4, 1, 0.75f);
        Panel(0, H - 1, W, 1, 0.8f);
        bool cal = camActive && calStep != 0;
        if ((showCam || cal) && camActive)
        {
            int cw = cal ? Math.Min(PW - 10, (int)(PH * 0.62f * GW / GH)) : Math.Max(30, PW / 4);
            int chh = cw * GH / GW;
            int x0 = cal ? (PW - cw) / 2 : PW - cw - 1, y0 = cal ? 12 : 1;
            for (int y = 0; y < chh; y++)
                for (int x = 0; x < cw; x++)
                {
                    int gx = x * GW / cw, gy = y * GH / chh, gi = gy * GW + gx;
                    int c = prevRGB[gi];
                    if (calStep == 0 && hm[gi] != 0) c = Lerp(c, 0x30FF80, 0.45f);
                    if (y0 + y < PH && x0 + x < PW) pix[(y0 + y) * PW + x0 + x] = c;
                }
            // marcas de las manos y la cabeza
            for (int h = 0; h < 2 && calStep == 0; h++)
                if (tkOk[h])
                {
                    int mx = x0 + (int)(tkPx[h] * cw / GW), my = y0 + (int)(tkPy[h] * chh / GH);
                    int col = h == 0 ? 0xFF4040 : 0x40A0FF;
                    for (int k = -3; k <= 3; k++) { PixSet(mx + k, my, col); PixSet(mx, my + k, col); }
                    int rx0 = x0 + (int)((wX[h] - wS[h]) * cw / GW), rx1 = x0 + (int)((wX[h] + wS[h]) * cw / GW), ry0 = y0 + (int)((wY[h] - wS[h] * 1.3f) * chh / GH), ry1 = y0 + (int)((wY[h] + wS[h]) * chh / GH);
                    for (int x = rx0; x <= rx1; x++) { PixSet(x, ry0, col); PixSet(x, ry1, col); }
                    for (int y = ry0; y <= ry1; y++) { PixSet(rx0, y, col); PixSet(rx1, y, col); }
                }
            if (faceOk && calStep == 0)
            {
                int fx0 = x0 + faceX0 * cw / GW, fx1 = x0 + faceX1 * cw / GW, fy0 = y0 + faceY0 * chh / GH, fy1 = y0 + faceY1 * chh / GH;
                for (int x = fx0; x <= fx1; x++) { PixSet(x, fy0, 0xFFE040); PixSet(x, fy1, 0xFFE040); }
                for (int y = fy0; y <= fy1; y++) { PixSet(fx0, y, 0xFFE040); PixSet(fx1, y, 0xFFE040); }
            }
            if (calStep == 2)
            {
                int bx0 = x0 + (GW / 2 - 14) * cw / GW, bx1 = x0 + (GW / 2 + 14) * cw / GW, by0 = y0 + (GH / 2 - 14) * chh / GH, by1 = y0 + (GH / 2 + 14) * chh / GH;
                int col = ((int)(gt * 4)) % 2 == 0 ? 0x30FF80 : 0xFFFFFF;
                for (int x = bx0; x <= bx1; x++) { PixSet(x, by0, col); PixSet(x, by1, col); }
                for (int y = by0; y <= by1; y++) { PixSet(bx0, y, col); PixSet(bx1, y, col); }
            }
            if (cal) Panel(0, Math.Max(0, 12 / 2 - 5), W, 5, 0.85f);
        }
        if (help) Panel(W / 2 - 34, H / 2 - 9, 68, 19, 0.88f);
    }
    static void PixSet(int x, int y, int c) { if (x >= 0 && y >= 0 && x < PW && y < PH) pix[y * PW + x] = c; }

    static readonly string[] GNAME = { "PUNO (coger)", "1 DEDO (pulsar)", "2 DEDOS", "3 DEDOS", "4 DEDOS", "ABIERTA (soltar)" };

    static void HudText()
    {
        int wh = 0xFFFFFF, gr = 0xAAAEBE, cy = 0x30E0FF;
        string mode = dumping ? "DEMO" : (manual || !camActive) ? "TECLADO" : calStep != 0 ? "CALIBRANDO" : "CAMARA";
        TS(1, 0, "OFICINA 3D", cy); TS(13, 0, "control: " + mode, gr);
        for (int h = 0; h < 2; h++)
        {
            string s = (h == 0 ? "IZQ: " : "DER: ") + GNAME[Math.Max(0, Math.Min(5, hFingers[h]))];
            if (heldB[h] != null) s += "  [" + KNAME[heldB[h].kind] + "]";
            TS(1, 1 + h, s, h == 0 ? 0xFF8080 : 0x80C0FF);
        }
        TS(1, 3, "PC " + (pcOn ? "ON " : "OFF") + "  FLEXO " + (lampOn ? "ON " : "OFF") + "  PAPELERA " + binCount + "  " + (int)Math.Round(fps) + " fps", gr);
        if (gt - msgT < 4 && msg.Length > 0 && !(((int)((gt - msgT) * 8)) % 2 == 0 && gt - msgT > 3.4)) TS((W - msg.Length) / 2, 5, msg, 0xFFE060);
        string bar = help ? "H: cerrar ayuda" : "H ayuda   T teclado/camara   C calibrar   G invertir   TAB ver camara   F1-F4 vistas   R recoger   +/- detalle   ESC salir";
        TS(Math.Max(0, (W - bar.Length) / 2), H - 1, bar.Length > W ? bar.Substring(0, W) : bar, gr);
        if (camActive && calStep != 0)
        {
            string a, b;
            if (calStep == 1) { a = "PASO 1/2: saca las manos del encuadre y quedate quieto"; b = "Pulsa ESPACIO (ENTER para saltar la calibracion)"; }
            else if (calStep == 3) { a = "Aprendiendo el fondo... no te muevas"; b = ""; }
            else { a = "PASO 2/2: pon la palma de la mano dentro del recuadro"; b = "Pulsa ESPACIO cuando este dentro"; }
            TSC(2, "CALIBRACION DE LA CAMARA", cy); TSC(3, a, wh); TSC(4, b, 0xFFE060);
        }
        else if (!camActive && !dumping && gt > 3 && camErr.Length > 0) TS(1, 4, ("Sin camara: " + camErr).Substring(0, Math.Min(W - 2, ("Sin camara: " + camErr).Length)), 0xFF8070);
        if (help)
        {
            int y = H / 2 - 8, x = W / 2 - 32;
            string[] l = {
                "CON LA CAMARA (sentado, manos delante del pecho):",
                "  mueve las manos -> mueve los brazos (acercalas = estirar el brazo)",
                "  PUNO = coger / apretar     MANO ABIERTA = soltar o lanzar",
                "  UN DEDO = pulsar botones y teclear     inclinate = el cuerpo se inclina",
                "  si los brazos van al reves pulsa G (invierte izquierda/derecha)",
                "",
                "CON EL TECLADO (T):",
                "  mano izq: A D (lados)  W S (delante/detras)  Q E (abajo/arriba)",
                "            Z = puno     X = un dedo",
                "  mano der: J L  I K  U O     M = puno     N = un dedo",
                "  flechas = inclinar el cuerpo",
                "",
                "COSAS QUE PUEDES HACER:",
                "  boton de la torre: encender/apagar      teclado: escribir en NOTAS",
                "  coger el raton: mover el cursor (quieto sobre un icono = clic)",
                "  apretar un folio: bola de papel -> papelera     boton verde: imprimir",
                "  interruptor rojo del flexo, el movil, la taza, la pelota, los libros..." };
            for (int i = 0; i < l.Length; i++) TS(x, y + i, l[i], i == 0 || i == 5 || i == 11 ? cy : wh);
        }
    }

    // ================================================================ celdas y salida
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
        if (cb[i] == UPB) cbg[i] = Lerp(cc[i], cbg[i], 0.5f);
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
[Oficina]::Run()
exit 0
