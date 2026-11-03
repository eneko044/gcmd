# Contexto para IA — Análisis de Veyon 4.11.4 (ingeniería inversa)

> Este documento reúne **todo el código fuente relevante** (de la versión 4.11.4,
> github.com/veyon/veyon) y **todos los volcados binarios** (tablas de importación,
> exportaciones y dependencias) de la **instalación oficial de Windows x86-64** que se
> analizó. Está pensado para entregarse íntegro a otro modelo de IA como contexto de
> trabajo. La correlación binario↔fuente está verificada: los símbolos del código
> aparecen en los .dll/.exe instalados.

## 0. Ficha

| Dato | Valor |
|------|-------|
| Producto | Veyon — "Virtual Eye On Networks" |
| Versión | 4.11.4 |
| Licencia | GNU GPL v2 (© 2004–2026 Tobias Junghans / Veyon Solutions) |
| Plataforma del paquete | Windows x86-64 (compilado con MinGW/GCC) |
| Framework | C++ con Qt 6 (Core/Gui/Widgets/Network/WebSockets/HttpServer) |
| Criptografía | QCA (Qt Cryptographic Architecture) sobre OpenSSL 3 |
| Firma de binarios | Cadena Certum (OCSP: ccsca2021.ocsp-certum.com) |
| Componentes en el paquete | service, server, worker, configurator, cli, wcli (NO incluye master) |
| Puertos TCP por defecto | 11100 (server VNC+auth), 11300 (worker mgr), 11400 (demo) |
| Tipo de seguridad RFB propio | rfbSecTypeVeyon = 40 |
| Parámetros cripto | RSA-4096, reto 128 B, firma EMSA3_SHA512, cifrado EME_PKCS1_OAEP |

## 1. Qué es y qué hace

Software libre de **monitorización y control de aulas**. Modelo profesor↔alumno sobre
RFB/VNC. Funciones: overview (miniaturas), control remoto, demo (difusión de pantalla),
bloqueo de pantalla, mensajes, inicio/cierre de sesión masivo, capturas, lanzar
programas/URLs, transferencia de archivos, encendido/apagado/reinicio.

## 2. Arquitectura

- **veyon-service.exe**: servicio del sistema (SYSTEM). Arranca con el equipo, detecta la
  sesión activa del alumno y lanza server/worker DENTRO de esa sesión (ver §5, mecanismo 1).
- **veyon-server.exe**: agente en la sesión del alumno. Servidor VNC + autenticación +
  control de acceso. Sirve pantalla y recibe órdenes.
- **veyon-worker.exe**: ejecuta las "features" en el contexto del usuario.
- **veyon-configurator.exe**: GUI de configuración.
- **veyon-cli.exe / veyon-wcli.exe**: línea de comandos.
- **veyon-core.dll**: núcleo compartido (lógica, red, auth, features, cliente VNC). Solo
  usa Qt; NO llama directamente a Win32.
- **plugins/windows-platform.dll**: TODA la interacción con Windows (servicios, tokens,
  CreateProcessAsUser, input/hooks/interception, WTS, registro, apagado, LDAP/dominio).
- **plugins/*.dll**: cada función remota es un plugin; dependen solo de core+Qt y delegan
  lo del SO en windows-platform.dll.

## 3. Resumen de los dos mecanismos centrales

**(1) Suplantación de sesión (Windows):** el servicio SYSTEM se auto-concede privilegios
(SE_TCB, SE_ASSIGNPRIMARYTOKEN), localiza un proceso del usuario, duplica su token como
token primario, y llama a `CreateProcessAsUser` con `si.lpDesktop = "Winsta0\\Default"` para
ejecutar el agente en el escritorio interactivo del alumno. Código íntegro en §6
(WindowsCoreFunctions.cpp).

**(2) Autenticación por firma (reto-respuesta asimétrico):** el servidor genera un reto de
128 bytes; el cliente lo firma con su clave privada RSA-4096 (EMSA3_SHA512); el servidor
verifica con la clave pública instalada. La privada nunca viaja. Hay límite anti-DoS de
8192 B en el tamaño de firma. Código íntegro en §6 (VeyonConnection.cpp,
ServerAuthenticationManager.cpp, CryptoCore).

---

# 4. VOLCADOS BINARIOS (de la instalación Windows analizada)

### 4.1 Tabla de importación — plugins/windows-platform.dll (TODAS las APIs Win32 usadas)

```text
	DLL Name: ADVAPI32.dll
	638d8	   31  AdjustTokenPrivileges
	638f0	   32  AllocateAndInitializeSid
	6390c	   91  ChangeServiceConfig2W
	63924	   93  ChangeServiceConfigW
	6393c	   95  CheckTokenMembership
	63954	  101  CloseServiceHandle
	6396a	  106  ControlService
	6397c	  123  ConvertSidToStringSidW
	63996	  131  ConvertStringSidToSidW
	639b0	  133  CopySid
	639ba	  139  CreateProcessAsUserW
	639d2	  145  CreateServiceW
	639e4	  236  DeleteService
	639f4	  237  DeregisterEventSource
	63a0c	  241  DuplicateTokenEx
	63a20	  282  EqualSid
	63a2c	  309  FreeSid
	63a36	  332  GetLengthSid
	63a46	  344  GetNamedSecurityInfoW
	63a5e	  369  GetTokenInformation
	63a74	  395  ImpersonateLoggedOnUser
	63a8e	  402  InitiateShutdownW
	63aa2	  421  LogonUserW
	63ab0	  423  LookupAccountNameW
	63ac6	  425  LookupAccountSidW
	63ada	  431  LookupPrivilegeValueW
	63af2	  544  OpenProcessToken
	63b06	  546  OpenSCManagerW
	63b18	  548  OpenServiceW
	63b28	  549  OpenThreadToken
	63b3a	  603  QueryServiceStatus
	63b50	  614  RegCloseKey
	63b5e	  623  RegCreateKeyExW
	63b70	  663  RegOpenKeyExW
	63b80	  692  RegSetValueExW
	63b92	  697  RegisterEventSourceW
	63baa	  701  RegisterServiceCtrlHandlerExW
	63bca	  715  ReportEventW
	63bda	  716  RevertToSelf
	63bea	  740  SetEntriesInAclW
	63bfe	  751  SetNamedSecurityInfoW
	63c16	  766  SetServiceStatus
	63c2a	  774  StartServiceCtrlDispatcherW
	63c48	  775  StartServiceW
	DLL Name: IMM32.dll
	63c58	   63  ImmGetDefaultIMEWnd
	DLL Name: interception.dll
	63c70	    0  interception_create_context
	63c90	    1  interception_destroy_context
	63cb0	   10  interception_set_filter
	DLL Name: IPHLPAPI.DLL
	63ccc	   81  FreeMibTable
	63cdc	  106  GetIfEntry2
	63cea	  126  GetIpForwardTable2
	63d00	  186  Icmp6CreateFile
	63d12	  188  Icmp6SendEcho2
	63d24	  189  IcmpCloseHandle
	63d36	  190  IcmpCreateFile
	63d48	  192  IcmpSendEcho
	DLL Name: KERNEL32.dll
	63d58	  151  CloseHandle
	63d66	  211  CreateEventW
	63d76	  244  CreatePipe
	63d84	  272  CreateToolhelp32Snapshot
	63da0	  295  DeleteCriticalSection
	63db8	  325  DuplicateHandle
	63dca	  333  EnterCriticalSection
	63de2	  458  FreeLibrary
	63df0	  511  GetComputerNameW
	63e04	  568  GetCurrentProcess
	63e18	  569  GetCurrentProcessId
	63e2e	  572  GetCurrentThread
	63e42	  573  GetCurrentThreadId
	63e58	  608  GetExitCodeProcess
	63e6e	  629  GetFileType
	63e7c	  631  GetFinalPathNameByHandleW
	63e98	  648  GetLastError
	63ea8	  669  GetModuleFileNameW
	63ebe	  670  GetModuleHandleA
	63ed2	  673  GetModuleHandleW
	63ee6	  730  GetProcAddress
	63ef8	  737  GetProcessHeap
	63f0a	  768  GetStdHandle
	63f1a	  847  GetVersionExW
	63f2a	  889  HeapAlloc
	63f36	  895  HeapFree
	63f42	  918  InitializeCriticalSection
	63f5e	  954  IsProcessorFeaturePresent
	63f7a	 1012  LeaveCriticalSection
	63f92	 1018  LoadLibraryExW
	63fa4	 1019  LoadLibraryW
	63fb4	 1030  LocalFree
	63fc0	 1085  OpenEventW
	63fce	 1097  OpenProcess
	63fdc	 1127  Process32FirstW
	63fee	 1129  Process32NextW
	64000	 1130  ProcessIdToSessionId
	64018	 1247  ResetEvent
	64026	 1317  SetConsoleOutputCP
	6403c	 1341  SetEvent
	64048	 1365  SetHandleInformation
	64060	 1410  SetThreadExecutionState
	6407a	 1449  Sleep
	64082	 1465  TerminateProcess
	64096	 1485  TlsGetValue
	640a4	 1533  VirtualProtect
	640b6	 1535  VirtualQuery
	640c6	 1538  WTSGetActiveConsoleSessionId
	640e6	 1542  WaitForMultipleObjects
	64100	 1544  WaitForSingleObject
	64116	 1608  WriteFile
	64122	 1647  lstrcpyW
	6412e	 1653  lstrlenW
	DLL Name: msvcrt.dll
	6413a	  129  __iob_func
	64148	  191  _amsg_exit
	64156	  379  _initterm
	64162	  482  _lock
	6416a	  820  _unlock
	64174	  885  _wcsicmp
	64180	 1016  abort
	64188	 1033  calloc
	64192	 1065  fprintf
	6419c	 1072  free
	641a4	 1138  memcmp
	641ae	 1139  memcpy
	641b8	 1140  memmove
	641c2	 1141  memset
	641cc	 1159  realloc
	641d6	 1168  setvbuf
	641e0	 1182  strchr
	641ea	 1183  strcmp
	641f4	 1190  strlen
	641fe	 1193  strncmp
	64208	 1195  strncpy_s
	64214	 1224  vfprintf
	64220	 1238  wcscmp
	6422a	 1244  wcslen
	64234	 1245  wcsncat
	6423e	 1248  wcsncpy
	64248	 1333  _write
	DLL Name: NETAPI32.dll
	64252	   17  DsGetDcNameW
	64262	  121  NetApiBufferFree
	64276	  171  NetGetDCName
	64286	  179  NetGroupEnum
	64296	  192  NetLocalGroupEnum
	642aa	  276  NetUserGetGroups
	642be	  278  NetUserGetLocalGroups
	DLL Name: ntdll.dll
	642d6	  549  NtQuerySystemInformation
	DLL Name: ole32.dll
	642f2	   30  CoCreateInstance
	64306	   85  CoInitializeEx
	64318	  128  CoTaskMemFree
	64328	  132  CoUninitialize
	DLL Name: OLEAUT32.dll
	6433a	   99  SysAllocString
	6434c	  102  SysFreeString
	DLL Name: Secur32.dll
	6435c	   30  GetUserNameExW
	DLL Name: SETUPAPI.dll
	6436e	   87  CM_Get_Device_IDW
	64382	  368  SetupDiCallClassInstaller
	6439e	  395  SetupDiDestroyDeviceInfoList
	643be	  398  SetupDiEnumDeviceInfo
	643d6	  418  SetupDiGetClassDevsW
	643ee	  448  SetupDiGetDeviceRegistryPropertyW
	64412	  500  SetupDiSetClassInstallParamsW
	DLL Name: SHELL32.dll
	64432	  231  SHGetKnownFolderPath
	6444a	  338  ShellExecuteExW
	DLL Name: USER32.dll
	6445c	   30  CallNextHookEx
	6446e	   78  CloseDesktop
	6447e	  188  DisplayConfigGetDeviceInfo
	6449c	  237  EnableWindow
	644ac	  251  EnumDisplayDevicesW
	644c2	  264  EnumWindows
	644d0	  269  ExitWindowsEx
	644e0	  274  FindWindowW
	644ee	  287  GetAsyncKeyState
	64502	  328  GetDisplayConfigBufferSizes
	64520	  342  GetForegroundWindow
	64536	  358  GetKeyState
	64544	  367  GetLayeredWindowAttributes
	64562	  452  GetThreadDesktop
	64576	  464  GetUserObjectInformationW
	64592	  467  GetWindow
	6459e	  481  GetWindowLongW
	645b0	  493  GetWindowTextLengthW
	645c8	  494  GetWindowTextW
	645da	  495  GetWindowThreadProcessId
	645f6	  568  IsWindow
	64602	  574  IsWindowVisible
	64614	  617  MapVirtualKeyW
	64626	  651  OpenInputDesktop
	6463a	  665  PostMessageW
	6464a	  677  QueryDisplayConfig
	64660	  705  RedrawWindow
	64670	  760  SendInput
	6467c	  766  SendMessageW
	6468c	  804  SetLayeredWindowAttributes
	646aa	  845  SetThreadDesktop
	646be	  863  SetWindowLongW
	646d0	  865  SetWindowPos
	646e0	  874  SetWindowsHookExW
	646f4	  884  ShowWindow
	64702	  900  SystemParametersInfoW
	6471a	  905  ToAscii
	64724	  920  UnhookWindowsHookEx
	6473a	  958  VkKeyScanW
	64748	  975  keybd_event
	DLL Name: USERENV.dll
	64756	    9  CreateEnvironmentBlock
	64770	   23  DestroyEnvironmentBlock
	DLL Name: WS2_32.dll
	6478a	   48  WSAGetLastError
	6479c	   59  WSAIoctl
	647a8	   89  WSAStartup
	647b6	  166  freeaddrinfo
	647c6	  167  getaddrinfo
	647d4	  181  inet_addr
	647e0	  194  setsockopt
	DLL Name: WTSAPI32.dll
	647ee	   15  WTSEnumerateProcessesW
	64808	   21  WTSEnumerateSessionsW
	64820	   22  WTSFreeMemory
	64830	   37  WTSQuerySessionInformationW
	6484e	   40  WTSQueryUserToken
	DLL Name: libstdc++-6.dll
	64864	  616  _ZNKSt5ctypeIcE13_M_widen_initEv
	64888	 3713  _ZNSt6thread15_M_start_threadESt10unique_ptrINS_6_StateESt14default_deleteIS1_EEPFvvE
	648e0	 3715  _ZNSt6thread4joinEv
	648f8	 3718  _ZNSt6thread6_StateD2Ev
	64914	 4535  _ZNSt8ios_base15sync_with_stdioEb
	64938	 4824  _ZSt16__throw_bad_castv
	64954	 4837  _ZSt18_Rb_tree_decrementPSt18_Rb_tree_node_base
	64988	 4838  _ZSt18_Rb_tree_incrementPKSt18_Rb_tree_node_base
	649bc	 4839  _ZSt18_Rb_tree_incrementPSt18_Rb_tree_node_base
	649f0	 4852  _ZSt20__throw_length_errorPKc
	64a10	 4869  _ZSt25__throw_bad_function_callv
	64a34	 4871  _ZSt28_Rb_tree_rebalance_for_erasePSt18_Rb_tree_node_baseRS_
	64a74	 4873  _ZSt29_Rb_tree_insert_and_rebalancebPSt18_Rb_tree_node_baseS0_RS_
	64ab8	 4876  _ZSt3cin
	64ac4	 4891  _ZSt7getlineIcSt11char_traitsIcESaIcEERSt13basic_istreamIT_T0_ES7_RNSt7__cxx1112basic_stringIS4_S5_T1_EES4_
	64b34	 4948  _ZSt9terminatev
	64b48	 5621  _ZTVN10__cxxabiv117__class_type_infoE
	64b70	 5625  _ZTVN10__cxxabiv120__si_class_type_infoE
	64b9c	 5626  _ZTVN10__cxxabiv121__vmi_class_type_infoE
	64bc8	 5868  _ZdaPv
	64bd4	 5872  _ZdaPvy
	64be0	 5874  _ZdlPv
	64bec	 5878  _ZdlPvy
	64bf8	 5880  _Znay
	64c00	 5884  _Znwy
	64c08	 5907  __cxa_guard_acquire
	64c20	 5908  __cxa_guard_release
	DLL Name: Qt6Core.dll
	64c38	   77  _Z21qRegisterResourceDataiPKhS0_S0_
	64c60	   81  _Z23qUnregisterResourceDataiPKhS0_S0_
	64c88	   90  _Z26qt_QMetaEnum_debugOperatorR6QDebugxPK11QMetaObjectPKc
	64cc4	  120  _Z5qHash11QStringViewy
	64ce0	  188  _ZN10QArrayData10deallocateEPS_xx
	64d04	  189  _ZN10QArrayData19reallocateUnalignedEPS_PvxxNS_16AllocationOptionE
	64d4c	  190  _ZN10QArrayData8allocateEPPS_xxxNS_16AllocationOptionE
	64d88	  195  _ZN10QByteArray11reallocDataExN10QArrayData16AllocationOptionE
	64dcc	  204  _ZN10QByteArray14trimmed_helperERS_
	64df4	  216  _ZN10QByteArray6_emptyE
	64e10	  221  _ZN10QByteArray6insertEx14QByteArrayView
	64e3c	  242  _ZN10QByteArrayC1EPKcx
	64e58	  243  _ZN10QByteArrayC1ExN2Qt14InitializationE
	64e84	  244  _ZN10QByteArrayC1Exc
	64e9c	  424  _ZN11QBasicMutex12lockInternalEv
	64ec0	  428  _ZN11QBasicMutex15destroyInternalEPv
	64ee8	  429  _ZN11QBasicMutex19unlockInternalFutexEPv
	64f14	  474  _ZN11QDataStreamD1Ev
	64f2c	  480  _ZN11QDataStreamlsEa
	64f44	  484  _ZN11QDataStreamlsEi
	64f5c	  492  _ZN11QDataStreamrsERb
	64f74	  495  _ZN11QDataStreamrsERi
	64f8c	  575  _ZN11QMetaObject10ConnectionD1Ev
	64fb0	  589  _ZN11QMetaObject18connectSlotsByNameEP7QObject
	64fe4	  682  _ZN11QTextStreamlsEPKc
	65000	  683  _ZN11QTextStreamlsEPKv
	6501c	  685  _ZN11QTextStreamlsERK7QString
	6503c	  686  _ZN11QTextStreamlsEc
	65054	  689  _ZN11QTextStreamlsEi
	6506c	  691  _ZN11QTextStreamlsEl
	65084	  692  _ZN11QTextStreamlsEm
	6509c	  695  _ZN11QTextStreamlsEx
	650b4	  855  _ZN13QElapsedTimer5startEv
	650d4	  856  _ZN13QElapsedTimer7restartEv
	650f4	 1059  _ZN14QDeadlineTimerC1ExN2Qt9TimerTypeE
	65120	 1189  _ZN14QWaitCondition4waitEP6QMutexm
	65148	 1190  _ZN14QWaitCondition7wakeAllEv
	65168	 1192  _ZN14QWaitConditionC1Ev
	65184	 1194  _ZN14QWaitConditionD1Ev
	651a0	 1288  _ZN15QtSharedPointer20ExternalRefCountData9getAndRefEPK7QObject
	651e4	 1345  _ZN16QCoreApplication15applicationNameEv
	65210	 1351  _ZN16QCoreApplication16organizationNameEv
	6523c	 1360  _ZN16QCoreApplication18applicationDirPathEv
	6526c	 1383  _ZN16QCoreApplication4selfE
	6528c	 1389  _ZN16QCoreApplication9translateEPKcS1_S1_i
	652bc	 1397  _ZN16QDebugStateSaverC1ER6QDebug
	652e0	 1399  _ZN16QDebugStateSaverD1Ev
	652fc	 2274  _ZN19QProcessEnvironment17systemEnvironmentEv
	6532c	 2285  _ZN19QProcessEnvironmentD1Ev
	6534c	 2998  _ZN4QDir18toNativeSeparatorsERK7QString
	65378	 3165  _ZN5QUuid10fromStringE14QAnyStringView
	653a4	 3189  _ZN6QDebug9putStringEPK5QChary
	653c8	 3190  _ZN6QDebugD1Ev
	653dc	 3219  _ZN6QTimer16staticMetaObjectE
	653fc	 3223  _ZN6QTimer4stopEv
	65410	 3225  _ZN6QTimer5startEi
	65428	 3227  _ZN6QTimer7timeoutENS_14QPrivateSignalE
	65454	 3228  _ZN6QTimerC1EP7QObject
	65470	 3231  _ZN6QTimerD1Ev
	65484	 3243  _ZN7QBuffer4openE6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	654c0	 3252  _ZN7QBufferC1EP10QByteArrayP7QObject
	654e8	 3253  _ZN7QBufferC1EP7QObject
	65504	 3257  _ZN7QBufferD1Ev
	65518	 3298  _ZN7QObject10childEventEP11QChildEvent
	65544	 3305  _ZN7QObject10timerEventEP11QTimerEvent
	65570	 3306  _ZN7QObject11connectImplEPKS_PPvS1_S3_PN9QtPrivate15QSlotObjectBaseEN2Qt14ConnectionTypeEPKiPK11QMetaObject
	655e0	 3307  _ZN7QObject11customEventEP6QEvent
	65604	 3308  _ZN7QObject11deleteLaterEv
	65624	 3309  _ZN7QObject11eventFilterEPS_P6QEvent
	6564c	 3310  _ZN7QObject11qt_metacallEN11QMetaObject4CallEiPPv
	65680	 3311  _ZN7QObject11qt_metacastEPKc
	656a0	 3316  _ZN7QObject13connectNotifyERK11QMetaMethod
	656d0	 3319  _ZN7QObject13setObjectNameE14QAnyStringView
	65700	 3323  _ZN7QObject16disconnectNotifyERK11QMetaMethod
	65730	 3324  _ZN7QObject16staticMetaObjectE
	65754	 3330  _ZN7QObject5eventEP6QEvent
	65774	 3333  _ZN7QObject9destroyedEPS_
	65790	 3339  _ZN7QObjectC2EPS_
	657a4	 3343  _ZN7QObjectD2Ev
	657b8	 3344  _ZN7QString10fromLatin1E14QByteArrayView
	657e4	 3355  _ZN7QString13toUtf8_helperERKS_
	65808	 3358  _ZN7QString14toLower_helperERKS_
	6582c	 3359  _ZN7QString14toLower_helperERS_
	65850	 3365  _ZN7QString15toLatin1_helperERKS_
	65874	 3368  _ZN7QString17toIntegral_helperE11QStringViewPbi
	658a8	 3379  _ZN7QString6_emptyE
	658c0	 3382  _ZN7QString6appendE5QChar
	658dc	 3384  _ZN7QString6appendERKS_
	658f8	 3391  _ZN7QString6numberEii
	65910	 3394  _ZN7QString6numberEmi
	65928	 3395  _ZN7QString6numberExi
	65940	 3409  _ZN7QString7replaceE5QCharRKS_N2Qt15CaseSensitivityE
	65978	 3420  _ZN7QString8fromUtf8E14QByteArrayView
	659a0	 3422  _ZN7QString9fromUtf16EPKDsx
	659c0	 3425  _ZN7QStringC1EPK5QCharx
	659dc	 3427  _ZN7QStringC1ExN2Qt14InitializationE
	65a04	 3434  _ZN7QStringaSERKS_
	65a1c	 3435  _ZN7QThread11qt_metacallEN11QMetaObject4CallEiPPv
	65a50	 3436  _ZN7QThread11qt_metacastEPKc
	65a70	 3444  _ZN7QThread16staticMetaObjectE
	65a94	 3449  _ZN7QThread19requestInterruptionEv
	65abc	 3451  _ZN7QThread3runEv
	65ad0	 3454  _ZN7QThread4quitEv
	65ae8	 3455  _ZN7QThread4waitE14QDeadlineTimer
	65b0c	 3456  _ZN7QThread5eventEP6QEvent
	65b2c	 3459  _ZN7QThread5startENS_8PriorityE
	65b50	 3460  _ZN7QThread6msleepEm
	65b68	 3463  _ZN7QThread8finishedENS_14QPrivateSignalE
	65b94	 3467  _ZN7QThreadC2EP7QObject
	65bb0	 3471  _ZN7QThreadD2Ev
	65bc4	 3538  _ZN8QProcess14waitForStartedEi
	65be8	 3540  _ZN8QProcess15waitForFinishedEi
	65c0c	 3567  _ZN8QProcess5startERK7QStringRK5QListIS0_E6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	65c64	 3568  _ZN8QProcess7executeERK7QStringRK5QListIS0_E
	65c94	 3574  _ZN8QProcessC1EP7QObject
	65cb0	 3577  _ZN8QProcessD1Ev
	65cc4	 3592  _ZN8QVariant13moveConstructE9QMetaTypePv
	65cf0	 3616  _ZN8QVariantC1E9QMetaTypePKv
	65d10	 3617  _ZN8QVariantC1ERK10QByteArray
	65d30	 3626  _ZN8QVariantC1ERK4QMapI7QStringS_E
	65d58	 3641  _ZN8QVariantC1ERK7QString
	65d74	 3644  _ZN8QVariantC1ERKS_
	65d8c	 3646  _ZN8QVariantC1Eb
	65da0	 3649  _ZN8QVariantC1Ei
	65db4	 3703  _ZN8QVariantD1Ev
	65dc8	 3823  _ZN9QHashSeed10globalSeedEv
	65de8	 3837  _ZN9QIODevice16staticMetaObjectE
	65e0c	 3862  _ZN9QIODevice7readAllEv
	65e28	 3866  _ZN9QIODevice9readyReadEv
	65e44	 3897  _ZN9QMetaType14registerHelperEPKN9QtPrivate18QMetaTypeInterfaceE
	65e88	 3903  _ZN9QMetaType25registerNormalizedTypedefERK10QByteArrayS_
	65ec4	 3911  _ZN9QMetaType7convertES_PKvS_Pv
	65ee8	 4009  _ZN9QSettingsC1ENS_5ScopeERK7QStringS3_P7QObject
	65f1c	 4012  _ZN9QSettingsC1ERK7QStringNS_6FormatEP7QObject
	65f50	 4021  _ZN9QSettingsD1Ev
	65f64	 4136  _ZN9QtPrivate12argToQStringE14QAnyStringViewyPPKNS_7ArgBaseE
	65fa4	 4139  _ZN9QtPrivate12equalStringsE11QStringViewS0_
	65fd4	 4159  _ZN9QtPrivate14compareStringsE11QStringViewS0_N2Qt15CaseSensitivityE
	6601c	 4242  _ZN9QtPrivate16QStringList_joinEPK5QListI7QStringEPK5QCharx
	6605c	 4249  _ZN9QtPrivate18QStringList_filterEPK5QListI7QStringE11QStringViewN2Qt15CaseSensitivityE
	660b8	 4289  _ZN9QtPrivate28QStringList_removeDuplicatesEP5QListI7QStringE
	660f8	 4344  _ZNK10QByteArray5splitEc
	66114	 4345  _ZNK10QByteArray5toHexEc
	66130	 4545  _ZNK11QMetaObject2trEPKcS1_i
	66150	 4546  _ZNK11QMetaObject4castEPK7QObject
	66174	 4552  _ZNK11QMetaObject9classNameEv
	66194	 4553  _ZNK11QObjectData17dynamicMetaObjectEv
	661c0	 4658  _ZNK13QElapsedTimer7elapsedEv
	661e0	 4824  _ZNK14QMessageLogger4infoEv
	66200	 4830  _ZNK14QMessageLogger5debugEv
	66220	 4843  _ZNK14QMessageLogger7warningEv
	66244	 4846  _ZNK14QMessageLogger8criticalEPKcz
	6626c	 4849  _ZNK14QMessageLogger8criticalEv
	66290	 5312  _ZNK19QProcessEnvironment5valueERK7QStringS2_
	662c0	 5636  _ZNK5QFile13symLinkTargetEv
	662e0	 5662  _ZNK5QUuid8toStringENS_12StringFormatE
	6630c	 5691  _ZNK7QBuffer4dataEv
	66324	 5786  _ZNK7QObject10objectNameEv
	66344	 5797  _ZNK7QString10startsWithE13QLatin1StringN2Qt15CaseSensitivityE
	66388	 5827  _ZNK7QString5splitE5QChar6QFlagsIN2Qt18SplitBehaviorFlagsEENS2_15CaseSensitivityE
	663dc	 5830  _ZNK7QString5utf16Ev
	663f4	 5832  _ZNK7QString7compareE13QLatin1StringN2Qt15CaseSensitivityE
	66434	 5833  _ZNK7QString7compareERKS_N2Qt15CaseSensitivityE
	66468	 5837  _ZNK7QString7indexOfERKS_xN2Qt15CaseSensitivityE
	6649c	 5843  _ZNK7QString8arg_implE14QAnyStringViewi5QChar
	664cc	 5845  _ZNK7QString8arg_implExii5QChar
	664f0	 5846  _ZNK7QString8arg_implEyii5QChar
	66514	 5854  _ZNK7QThread10metaObjectEv
	66534	 5858  _ZNK7QThread23isInterruptionRequestedEv
	66560	 5893  _ZNK8QProcess8exitCodeEv
	6657c	 5899  _ZNK8QVariant11toByteArrayEv
	6659c	 5912  _ZNK8QVariant5toIntEPb
	665b8	 5913  _ZNK8QVariant5toMapEv
	665d0	 5915  _ZNK8QVariant6equalsERKS_
	665ec	 5939  _ZNK8QVariant8toStringEv
	66608	 6167  _ZNK9QSettings5valueE14QAnyStringView
	66630	 6252  _ZNKR7QString3midExx
	66648	 6606  qt_version_tag_6_10
	DLL Name: Qt6Gui.dll
	66660	 1760  _ZN15QGuiApplication16staticMetaObjectE
	6668c	 1779  _ZN15QGuiApplication23platformNativeInterfaceEv
	666c0	 4354  _ZN5QIcon7addFileERK7QStringRK5QSizeNS_4ModeENS_5StateE
	666fc	 4366  _ZN5QIconC1Ev
	6670c	 4372  _ZN5QIconD1Ev
	6671c	 4816  _ZN7QWindow6createEv
	66734	 4837  _ZN7QWindowC1EP7QScreen
	66750	 7106  _ZNK7QScreen4nameEv
	DLL Name: Qt6Network.dll
	66768	  320  _ZN12QHostAddressC1ERK7QString
	6678c	  332  _ZN12QHostAddressD1Ev
	667a4	  406  _ZN12QLocalServer13newConnectionEv
	667cc	  407  _ZN12QLocalServer16setSocketOptionsE6QFlagsINS_12SocketOptionEE
	66810	  408  _ZN12QLocalServer16staticMetaObjectE
	66838	  418  _ZN12QLocalServer6listenERK7QString
	66860	  420  _ZN12QLocalServerC1EP7QObject
	66880	  427  _ZN12QLocalSocket12disconnectedEv
	668a4	  433  _ZN12QLocalSocket15connectToServerERK7QString6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	668fc	  435  _ZN12QLocalSocket16staticMetaObjectE
	66924	  436  _ZN12QLocalSocket16waitForConnectedEi
	6694c	  441  _ZN12QLocalSocket19waitForBytesWrittenEi
	66978	  443  _ZN12QLocalSocket20disconnectFromServerEv
	669a4	  448  _ZN12QLocalSocket5flushEv
	669c0	  453  _ZN12QLocalSocketC1EP7QObject
	669e0	  456  _ZN12QLocalSocketD1Ev
	669f8	  865  _ZN17QNetworkInterface18interfaceFromIndexEi
	66a28	  869  _ZN17QNetworkInterfaceC1Ev
	66a48	  872  _ZN17QNetworkInterfaceD1Ev
	66a68	 1503  _ZN9QHostInfo13localHostNameEv
	66a8c	 1670  _ZNK12QHostAddress8protocolEv
	66aac	 1702  _ZNK12QLocalServer11errorStringEv
	66ad0	 1917  _ZNK17QNetworkInterface5indexEv
	66af4	 1918  _ZNK17QNetworkInterface7isValidEv
	DLL Name: Qt6Widgets.dll
	66b18	   63  _ZN10QBoxLayout9addLayoutEP7QLayouti
	66b40	   64  _ZN10QBoxLayout9addWidgetEP7QWidgeti6QFlagsIN2Qt13AlignmentFlagEE
	66b84	  534  _ZN11QGridLayout9addWidgetEP7QWidgetiiii6QFlagsIN2Qt13AlignmentFlagEE
	66bcc	  535  _ZN11QGridLayoutC1EP7QWidget
	66bec	  545  _ZN11QHBoxLayoutC1Ev
	66c04	  967  _ZN11QVBoxLayoutC1EP7QWidget
	66c24	 2216  _ZN15QAbstractButton7setTextERK7QString
	66c50	 4275  _ZN6QLabel7setTextERK7QString
	66c70	 4280  _ZN6QLabelC1EP7QWidget6QFlagsIN2Qt10WindowTypeEE
	66ca4	 4362  _ZN7QLayout18setContentsMarginsEiiii
	66ccc	 4460  _ZN7QWidget10closeEventEP11QCloseEvent
	66cf8	 4461  _ZN7QWidget10enterEventEP11QEnterEvent
	66d24	 4462  _ZN7QWidget10leaveEventEP6QEvent
	66d48	 4463  _ZN7QWidget10paintEventEP11QPaintEvent
	66d74	 4467  _ZN7QWidget10setVisibleEb
	66d90	 4471  _ZN7QWidget10wheelEventEP11QWheelEvent
	66dbc	 4472  _ZN7QWidget11actionEventEP12QActionEvent
	66de8	 4473  _ZN7QWidget11changeEventEP6QEvent
	66e0c	 4476  _ZN7QWidget11nativeEventERK10QByteArrayPvPx
	66e3c	 4479  _ZN7QWidget11resizeEventEP12QResizeEvent
	66e68	 4483  _ZN7QWidget11setTabOrderEPS_S0_
	66e8c	 4485  _ZN7QWidget11tabletEventEP12QTabletEvent
	66eb8	 4488  _ZN7QWidget12focusInEventEP11QFocusEvent
	66ee4	 4500  _ZN7QWidget13dragMoveEventEP14QDragMoveEvent
	66f14	 4501  _ZN7QWidget13focusOutEventEP11QFocusEvent
	66f40	 4503  _ZN7QWidget13keyPressEventEP9QKeyEvent
	66f6c	 4509  _ZN7QWidget13setWindowIconERK5QIcon
	66f94	 4514  _ZN7QWidget14activateWindowEv
	66fb4	 4515  _ZN7QWidget14dragEnterEventEP15QDragEnterEvent
	66fe8	 4516  _ZN7QWidget14dragLeaveEventEP15QDragLeaveEvent
	6701c	 4517  _ZN7QWidget14mouseMoveEventEP11QMouseEvent
	6704c	 4525  _ZN7QWidget14setWindowTitleERK7QString
	67078	 4528  _ZN7QWidget15keyReleaseEventEP9QKeyEvent
	670a4	 4530  _ZN7QWidget15mousePressEventEP11QMouseEvent
	670d4	 4537  _ZN7QWidget16contextMenuEventEP17QContextMenuEvent
	6710c	 4538  _ZN7QWidget16inputMethodEventEP17QInputMethodEvent
	67144	 4545  _ZN7QWidget17mouseReleaseEventEP11QMouseEvent
	67174	 4556  _ZN7QWidget18focusNextPrevChildEb
	67198	 4570  _ZN7QWidget21mouseDoubleClickEventEP11QMouseEvent
	671cc	 4583  _ZN7QWidget5eventEP6QEvent
	671ec	 4585  _ZN7QWidget5raiseEv
	67204	 4615  _ZN7QWidget9dropEventEP10QDropEvent
	6722c	 4618  _ZN7QWidget9hideEventEP10QHideEvent
	67254	 4619  _ZN7QWidget9moveEventEP10QMoveEvent
	6727c	 4627  _ZN7QWidget9showEventEP10QShowEvent
	672a4	 4634  _ZN7QWidgetD2Ev
	672b8	 4770  _ZN8QSpinBox10setMaximumEi
	672d8	 4771  _ZN8QSpinBox10setMinimumEi
	672f8	 4777  _ZN8QSpinBox13setSingleStepEi
	67318	 4785  _ZN8QSpinBox9setSuffixERK7QString
	6733c	 4786  _ZN8QSpinBoxC1EP7QWidget
	67358	 4872  _ZN9QCheckBoxC1EP7QWidget
	67374	 4889  _ZN9QComboBox10insertItemEiRK5QIconRK7QStringRK8QVariant
	673b0	 4904  _ZN9QComboBox11setItemTextEiRK7QString
	673dc	 4920  _ZN9QComboBox15setCurrentIndexEi
	67400	 4926  _ZN9QComboBox16staticMetaObjectE
	67424	 4933  _ZN9QComboBox19currentIndexChangedEi
	6744c	 4948  _ZN9QComboBoxC1EP7QWidget
	67468	 4986  _ZN9QGroupBox8setTitleERK7QString
	6748c	 4987  _ZN9QGroupBoxC1EP7QWidget
	674a8	 7313  _ZNK7QWidget10redirectedEP6QPoint
	674cc	 7321  _ZNK7QWidget11initPainterEP8QPainter
	674f4	 7332  _ZNK7QWidget11paintEngineEv
	67514	 7341  _ZNK7QWidget12windowHandleEv
	67534	 7347  _ZNK7QWidget13sharedPainterEv
	67554	 7358  _ZNK7QWidget14heightForWidthEi
	67578	 7366  _ZNK7QWidget15minimumSizeHintEv
	6759c	 7369  _ZNK7QWidget16inputMethodQueryEN2Qt16InputMethodQueryE
	675d8	 7373  _ZNK7QWidget17hasHeightForWidthEv
	675fc	 7375  _ZNK7QWidget18nativeParentWidgetEv
	67624	 7392  _ZNK7QWidget6metricEN12QPaintDevice17PaintDeviceMetricE
	67660	 7398  _ZNK7QWidget7devTypeEv
	6767c	 7405  _ZNK7QWidget8sizeHintEv
	67698	 7531  _ZNK9QComboBox5countEv
	676b4	 7934  _ZTV11QSpacerItem
	676c8	 8384  _ZThn16_NK7QWidget10redirectedEP6QPoint
	676f4	 8385  _ZThn16_NK7QWidget11initPainterEP8QPainter
	67724	 8386  _ZThn16_NK7QWidget11paintEngineEv
	67748	 8387  _ZThn16_NK7QWidget13sharedPainterEv
	67770	 8388  _ZThn16_NK7QWidget6metricEN12QPaintDevice17PaintDeviceMetricE
	677b0	 8389  _ZThn16_NK7QWidget7devTypeEv
	DLL Name: libqca-qt6.dll
	677d0	  219  _ZN3QCA11SecureArrayC1ERK10QByteArray
	677f8	  221  _ZN3QCA11SecureArrayC1ERKS0_
	67818	  223  _ZN3QCA11SecureArrayC1Ev
	67834	  230  _ZN3QCA11SecureArrayD1Ev
	67850	  232  _ZN3QCA11SecureArrayaSERK10QByteArray
	67878	  233  _ZN3QCA11SecureArrayaSERKS0_
	67898	 1319  _ZNK3QCA11SecureArray11toByteArrayEv
	678c0	 1323  _ZNK3QCA11SecureArray7isEmptyEv
	DLL Name: veyon-core.dll
	678e4	    0  _ZN10CryptoCore17generateChallengeEv
	6790c	   64  _ZN11HostAddressC1ERK7QString
	6792c	   84  _ZN13Configuration5Proxy11qt_metacallEN11QMetaObject4CallEiPPv
	67970	   85  _ZN13Configuration5Proxy11qt_metacastEPKc
	6799c	   89  _ZN13Configuration5Proxy16staticMetaObjectE
	679cc	   93  _ZN13Configuration5ProxyC2EPNS_6ObjectE
	679f8	  117  _ZN13Configuration8Property11qt_metacallEN11QMetaObject4CallEiPPv
	67a3c	  118  _ZN13Configuration8Property11qt_metacastEPKc
	67a6c	  124  _ZN13Configuration8PropertyC2EPNS_5ProxyERK7QStringS5_RK8QVariant6QFlagsINS0_4FlagEE
	67ac4	  137  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyIbEEP9QCheckBox
	67b20	  139  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyIiEEP8QSpinBox
	67b7c	  147  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyIbEEP9QCheckBox
	67bd8	  149  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyIiEEP8QSpinBox
	67c34	  152  _ZN13Configuration9UiMapping8setFlagsEP7QObject6QFlagsINS_8Property4FlagEE
	67c84	  178  _ZN13ProcessHelper13runAndReadAllEv
	67cac	  179  _ZN13ProcessHelper3runEv
	67cc8	  181  _ZN13ProcessHelperC2ERK7QStringRK5QListIS0_E
	67cf8	  188  _ZN13VariantStream4readEv
	67d14	  189  _ZN13VariantStream5writeERK8QVariant
	67d3c	  195  _ZN13VariantStreamC1EP9QIODevice
	67d60	  398  _ZN17ConfigurationPage11qt_metacallEN11QMetaObject4CallEiPPv
	67da0	  399  _ZN17ConfigurationPage11qt_metacastEPKc
	67dcc	  401  _ZN17ConfigurationPage16staticMetaObjectE
	67df8	  404  _ZN17ConfigurationPageC2EP7QWidget
	67e20	  487  _ZN19StandardInputReader8lineReadERK7QString
	67e50	  488  _ZN19VariantArrayMessage17isReadyForReceiveEv
	67e80	  489  _ZN19VariantArrayMessage4readEv
	67ea4	  490  _ZN19VariantArrayMessage4sendEv
	67ec8	  491  _ZN19VariantArrayMessage5writeERK8QVariant
	67ef8	  492  _ZN19VariantArrayMessage7receiveEv
	67f20	  493  _ZN19VariantArrayMessageC1EP9QIODevice
	67f4c	  585  _ZN23KeyboardShortcutTrapper11qt_metacallEN11QMetaObject4CallEiPPv
	67f94	  586  _ZN23KeyboardShortcutTrapper11qt_metacastEPKc
	67fc4	  587  _ZN23KeyboardShortcutTrapper15shortcutTrappedENS_8ShortcutE
	68004	  588  _ZN23KeyboardShortcutTrapper16staticMetaObjectE
	68038	  636  _ZN24PlatformSessionFunctions16staticMetaObjectE
	6806c	  641  _ZN24UserGroupsBackendManager17configuredBackendEv
	680a4	  715  _ZN9VeyonCore11initializedEv
	680c4	  716  _ZN9VeyonCore11isDebuggingEv
	680e4	  719  _ZN9VeyonCore11stripDomainERK7QString
	6810c	  727  _ZN9VeyonCore15shortenFuncinfoERK10QByteArray
	6813c	  729  _ZN9VeyonCore16staticMetaObjectE
	68160	  730  _ZN9VeyonCore17applicationLoadedEv
	68188	  749  _ZN9VeyonCore8instanceEv
	681a4	  757  _ZNK10CryptoCore15decryptPasswordERK7QString
	681d4	  758  _ZNK10CryptoCore15encryptPasswordERKN3QCA11SecureArrayE
	68210	  764  _ZNK10Filesystem14serverFilePathEv
	68238	  782  _ZNK11HostAddress7convertENS_4TypeE
	68260	  787  _ZNK13Configuration5Proxy10metaObjectEv
	6828c	  795  _ZNK13Configuration8Property10metaObjectEv
	682bc	  796  _ZNK13Configuration8Property12variantValueEv
	682ec	  797  _ZNK13Configuration8Property13lambdaContextEv
	6831c	  798  _ZNK13Configuration8Property15setVariantValueERK8QVariant
	68358	  963  _ZTV17ConfigurationPage
	68374	  968  _ZTV19StandardInputReader
	68390	  978  _ZTV23KeyboardShortcutTrapper
	683b0	  988  _ZTVN13Configuration5ProxyE
	683d0	  990  _ZTVN13Configuration8PropertyE
```

### 4.2 Tabla de importación — veyon-core.dll

```text
	DLL Name: KERNEL32.dll
	f2420	  295  DeleteCriticalSection
	f2438	  333  EnterCriticalSection
	f2450	  568  GetCurrentProcess
	f2464	  648  GetLastError
	f2474	  670  GetModuleHandleA
	f2488	  730  GetProcAddress
	f249a	  918  InitializeCriticalSection
	f24b6	  945  IsDBCSLeadByteEx
	f24ca	  954  IsProcessorFeaturePresent
	f24e6	 1012  LeaveCriticalSection
	f24fe	 1019  LoadLibraryW
	f250e	 1064  MultiByteToWideChar
	f2524	 1449  Sleep
	f252c	 1465  TerminateProcess
	f2540	 1485  TlsGetValue
	f254e	 1533  VirtualProtect
	f2560	 1535  VirtualQuery
	f2570	 1588  WideCharToMultiByte
	DLL Name: msvcrt.dll
	f2586	  109  ___lc_codepage_func
	f259c	  112  ___mb_cur_max_func
	f25b2	  129  __iob_func
	f25c0	  191  _amsg_exit
	f25ce	  266  _errno
	f25d8	  379  _initterm
	f25e4	  482  _lock
	f25ec	  820  _unlock
	f25f6	 1016  abort
	f25fe	 1033  calloc
	f2608	 1053  fflush
	f2612	 1065  fprintf
	f261c	 1067  fputc
	f2624	 1072  free
	f262c	 1123  localeconv
	f263a	 1130  malloc
	f2644	 1137  memchr
	f264e	 1138  memcmp
	f2658	 1139  memcpy
	f2662	 1140  memmove
	f266c	 1141  memset
	f2676	 1150  putc
	f267e	 1159  realloc
	f2688	 1183  strcmp
	f2692	 1188  strerror
	f269e	 1190  strlen
	f26a8	 1193  strncmp
	f26b2	 1224  vfprintf
	f26be	 1244  wcslen
	f26c8	 1333  _write
	f26d2	 1351  _strdup
	DLL Name: libgcc_s_seh-1.dll
	f26dc	   45  __emutls_get_address
	DLL Name: libstdc++-6.dll
	f26f4	 4830  _ZSt17__throw_bad_allocv
	f2710	 4837  _ZSt18_Rb_tree_decrementPSt18_Rb_tree_node_base
	f2744	 4838  _ZSt18_Rb_tree_incrementPKSt18_Rb_tree_node_base
	f2778	 4839  _ZSt18_Rb_tree_incrementPSt18_Rb_tree_node_base
	f27ac	 4852  _ZSt20__throw_length_errorPKc
	f27cc	 4869  _ZSt25__throw_bad_function_callv
	f27f0	 4871  _ZSt28_Rb_tree_rebalance_for_erasePSt18_Rb_tree_node_baseRS_
	f2830	 4872  _ZSt28__throw_bad_array_new_lengthv
	f2858	 4873  _ZSt29_Rb_tree_insert_and_rebalancebPSt18_Rb_tree_node_baseS0_RS_
	f289c	 5621  _ZTVN10__cxxabiv117__class_type_infoE
	f28c4	 5625  _ZTVN10__cxxabiv120__si_class_type_infoE
	f28f0	 5626  _ZTVN10__cxxabiv121__vmi_class_type_infoE
	f291c	 5868  _ZdaPv
	f2928	 5872  _ZdaPvy
	f2934	 5874  _ZdlPv
	f2940	 5878  _ZdlPvy
	f294c	 5880  _Znay
	f2954	 5884  _Znwy
	f295c	 5907  __cxa_guard_acquire
	f2974	 5908  __cxa_guard_release
	f298c	 5927  __dynamic_cast
	DLL Name: Qt6Core.dll
	f29a0	   15  _Z13comparesEqualRK10QJsonArrayS1_
	f29c8	   17  _Z13comparesEqualRK11QJsonObjectS1_
	f29f0	   29  _Z13comparesEqualRK7QLocaleNS_8LanguageE
	f2a1c	   70  _Z20qEnvironmentVariablePKc
	f2a3c	   73  _Z20qt_qFindChild_helperPK7QObject14QAnyStringViewRK11QMetaObject6QFlagsIN2Qt15FindChildOptionEE
	f2aa0	   77  _Z21qRegisterResourceDataiPKhS0_S0_
	f2ac8	   80  _Z22qInstallMessageHandlerPFv9QtMsgTypeRK18QMessageLogContextRK7QStringE
	f2b14	   81  _Z23qUnregisterResourceDataiPKhS0_S0_
	f2b3c	   82  _Z23qt_qFindChildren_helperPK7QObject14QAnyStringViewRK11QMetaObjectP5QListIPvE6QFlagsIN2Qt15FindChildOptionEE
	f2bb0	   87  _Z25qEnvironmentVariableIsSetPKc
	f2bd4	   90  _Z26qt_QMetaEnum_debugOperatorR6QDebugxPK11QMetaObjectPKc
	f2c10	   96  _Z30qt_QMetaEnum_flagDebugOperatorR6QDebugyPK11QMetaObjectPKc
	f2c50	   98  _Z30qt_QMetaEnum_flagDebugOperatorR6QDebugyj
	f2c80	  120  _Z5qHash11QStringViewy
	f2c9c	  171  _Z8qmemrchrPKviy
	f2cb0	  188  _ZN10QArrayData10deallocateEPS_xx
	f2cd4	  189  _ZN10QArrayData19reallocateUnalignedEPS_PvxxNS_16AllocationOptionE
	f2d1c	  190  _ZN10QArrayData8allocateEPPS_xxxNS_16AllocationOptionE
	f2d58	  193  _ZN10QByteArray10fromBase64ERKS_6QFlagsINS_12Base64OptionEE
	f2d98	  195  _ZN10QByteArray11reallocDataExN10QArrayData16AllocationOptionE
	f2ddc	  212  _ZN10QByteArray4chopEx
	f2df8	  214  _ZN10QByteArray5clearEv
	f2e14	  216  _ZN10QByteArray6_emptyE
	f2e30	  218  _ZN10QByteArray6appendEc
	f2e4c	  221  _ZN10QByteArray6insertEx14QByteArrayView
	f2e78	  230  _ZN10QByteArray6removeExx
	f2e94	  231  _ZN10QByteArray6resizeEx
	f2eb0	  236  _ZN10QByteArray7fromHexERKS_
	f2ed0	  238  _ZN10QByteArray7replaceE14QByteArrayViewS0_
	f2f00	  241  _ZN10QByteArray8truncateEx
	f2f20	  242  _ZN10QByteArrayC1EPKcx
	f2f3c	  243  _ZN10QByteArrayC1ExN2Qt14InitializationE
	f2f68	  248  _ZN10QByteArrayaSEPKc
	f2f80	  249  _ZN10QByteArrayaSERKS_
	f2f9c	  332  _ZN10QJsonArray6appendERK10QJsonValue
	f2fc4	  339  _ZN10QJsonArrayC1EOS_
	f2fdc	  341  _ZN10QJsonArrayC1ERKS_
	f2ff8	  343  _ZN10QJsonArrayC1Ev
	f3010	  349  _ZN10QJsonArrayD1Ev
	f3028	  353  _ZN10QJsonValue11fromVariantERK8QVariant
	f3054	  358  _ZN10QJsonValueC1EO10QJsonArray
	f3078	  359  _ZN10QJsonValueC1EO11QJsonObject
	f309c	  361  _ZN10QJsonValueC1ERK10QJsonArray
	f30c0	  362  _ZN10QJsonValueC1ERK11QJsonObject
	f30e4	  363  _ZN10QJsonValueC1ERK7QString
	f3104	  365  _ZN10QJsonValueC1Eb
	f311c	  367  _ZN10QJsonValueC1Ei
	f3134	  382  _ZN10QJsonValueD1Ev
	f314c	  424  _ZN11QBasicMutex12lockInternalEv
	f3170	  428  _ZN11QBasicMutex15destroyInternalEPv
	f3198	  429  _ZN11QBasicMutex19unlockInternalFutexEPv
	f31c4	  447  _ZN11QDataStream11resetStatusEv
	f31e8	  455  _ZN11QDataStream16startTransactionEv
	f3210	  457  _ZN11QDataStream19rollbackTransactionEv
	f323c	  465  _ZN11QDataStream9setStatusENS_6StatusE
	f3268	  467  _ZN11QDataStreamC1EP9QIODevice
	f328c	  474  _ZN11QDataStreamD1Ev
	f32a4	  480  _ZN11QDataStreamlsEa
	f32bc	  484  _ZN11QDataStreamlsEi
	f32d4	  486  _ZN11QDataStreamlsEx
	f32ec	  491  _ZN11QDataStreamrsERa
	f3304	  492  _ZN11QDataStreamrsERb
	f331c	  495  _ZN11QDataStreamrsERi
	f3334	  497  _ZN11QDataStreamrsERx
	f334c	  517  _ZN11QFileDevice5closeEv
	f3368	  518  _ZN11QFileDevice5flushEv
	f3384	  533  _ZN11QJsonObject14fromVariantMapERK4QMapI7QString8QVariantE
	f33c4	  550  _ZN11QJsonObjectC1EOS_
	f33e0	  552  _ZN11QJsonObjectC1ERKS_
	f33fc	  554  _ZN11QJsonObjectC1Ev
	f3414	  560  _ZN11QJsonObjectD1Ev
	f342c	  565  _ZN11QJsonObjectixERK7QString
	f344c	  575  _ZN11QMetaObject10ConnectionD1Ev
	f3470	  582  _ZN11QMetaObject14normalizedTypeEPKc
	f3498	  589  _ZN11QMetaObject18connectSlotsByNameEP7QObject
	f34cc	  592  _ZN11QMetaObject8activateEP7QObjectPKS_iPPv
	f34fc	  682  _ZN11QTextStreamlsEPKc
	f3518	  683  _ZN11QTextStreamlsEPKv
	f3534	  685  _ZN11QTextStreamlsERK7QString
	f3554	  686  _ZN11QTextStreamlsEc
	f356c	  689  _ZN11QTextStreamlsEi
	f3584	  690  _ZN11QTextStreamlsEj
	f359c	  694  _ZN11QTextStreamlsEt
	f35b4	  695  _ZN11QTextStreamlsEx
	f35cc	  696  _ZN11QTextStreamlsEy
	f35e4	  719  _ZN11QThreadPool14globalInstanceEv
	f360c	  729  _ZN11QThreadPool5startEP9QRunnablei
	f3634	  750  _ZN11QTranslator16staticMetaObjectE
	f365c	  754  _ZN11QTranslator4loadERK7QStringS2_S2_S2_
	f3688	  755  _ZN11QTranslatorC1EP7QObject
	f36a8	  811  _ZN12QLibraryInfo4pathENS_11LibraryPathE
	f36d4	  855  _ZN13QElapsedTimer5startEv
	f36f4	  856  _ZN13QElapsedTimer7restartEv
	f3714	  904  _ZN13QJsonDocument8fromJsonERK10QByteArrayP15QJsonParseError
	f3754	  910  _ZN13QJsonDocumentC1ERK11QJsonObject
	f377c	  919  _ZN13QJsonDocumentD1Ev
	f3798	  923  _ZN13QJsonValueRefaSERK10QJsonValue
	f37c0	  953  _ZN13QPluginLoader6unloadEv
	f37e0	  954  _ZN13QPluginLoader8instanceEv
	f3800	  956  _ZN13QPluginLoaderC1ERK7QStringP7QObject
	f382c	 1059  _ZN14QDeadlineTimerC1ExN2Qt9TimerTypeE
	f3858	 1111  _ZN14QReadWriteLock14tryLockForReadE14QDeadlineTimer
	f3890	 1114  _ZN14QReadWriteLock15tryLockForWriteE14QDeadlineTimer
	f38c8	 1117  _ZN14QReadWriteLock16destroyRecursiveEP21QReadWriteLockPrivate
	f390c	 1118  _ZN14QReadWriteLock6unlockEv
	f392c	 1126  _ZN14QStandardPaths16writableLocationENS_16StandardLocationE
	f396c	 1177  _ZN14QVersionNumber10fromStringE14QAnyStringViewPx
	f39a4	 1185  _ZN14QVersionNumber7compareERKS_S1_
	f39cc	 1189  _ZN14QWaitCondition4waitEP6QMutexm
	f39f4	 1190  _ZN14QWaitCondition7wakeAllEv
	f3a14	 1192  _ZN14QWaitConditionC1Ev
	f3a30	 1194  _ZN14QWaitConditionD1Ev
	f3a4c	 1249  _ZN15QRecursiveMutex6unlockEv
	f3a6c	 1250  _ZN15QRecursiveMutex7tryLockE14QDeadlineTimer
	f3a9c	 1252  _ZN15QRecursiveMutexD1Ev
	f3ab8	 1288  _ZN15QtSharedPointer20ExternalRefCountData9getAndRefEPK7QObject
	f3afc	 1336  _ZN16QCoreApplication12setAttributeEN2Qt20ApplicationAttributeEb
	f3b40	 1338  _ZN16QCoreApplication13processEventsE6QFlagsIN10QEventLoop17ProcessEventsFlagEE
	f3b94	 1342  _ZN16QCoreApplication14addLibraryPathERK7QString
	f3bc8	 1345  _ZN16QCoreApplication15applicationNameEv
	f3bf4	 1351  _ZN16QCoreApplication16organizationNameEv
	f3c20	 1356  _ZN16QCoreApplication17installTranslatorEP11QTranslator
	f3c5c	 1360  _ZN16QCoreApplication18applicationDirPathEv
	f3c8c	 1365  _ZN16QCoreApplication18setApplicationNameERK7QString
	f3cc4	 1369  _ZN16QCoreApplication19setOrganizationNameERK7QString
	f3cfc	 1373  _ZN16QCoreApplication21setOrganizationDomainERK7QString
	f3d38	 1380  _ZN16QCoreApplication4execEv
	f3d58	 1382  _ZN16QCoreApplication4quitEv
	f3d78	 1383  _ZN16QCoreApplication4selfE
	f3d98	 1386  _ZN16QCoreApplication9argumentsEv
	f3dbc	 1389  _ZN16QCoreApplication9translateEPKcS1_S1_i
	f3dec	 1397  _ZN16QDebugStateSaverC1ER6QDebug
	f3e10	 1399  _ZN16QDebugStateSaverD1Ev
	f3e2c	 1449  _ZN16QRandomGenerator10_fillRangeEPvx
	f3e54	 1688  _ZN17QVariantAnimation11setDurationEi
	f3e7c	 1689  _ZN17QVariantAnimation11setEndValueERK8QVariant
	f3eb0	 1694  _ZN17QVariantAnimation13setStartValueERK8QVariant
	f3ee4	 1735  _ZN18QAbstractAnimation16staticMetaObjectE
	f3f14	 1744  _ZN18QAbstractAnimation5startENS_14DeletionPolicyE
	f3f4c	 1746  _ZN18QAbstractAnimation8finishedEv
	f3f74	 1756  _ZN18QAbstractItemModel10insertRowsEiiRK11QModelIndex
	f3fac	 1758  _ZN18QAbstractItemModel10removeRowsEiiRK11QModelIndex
	f3fe4	 1761  _ZN18QAbstractItemModel11moveColumnsERK11QModelIndexiiS2_i
	f4024	 1762  _ZN18QAbstractItemModel11qt_metacallEN11QMetaObject4CallEiPPv
	f4064	 1763  _ZN18QAbstractItemModel11qt_metacastEPKc
	f4090	 1765  _ZN18QAbstractItemModel11setItemDataERK11QModelIndexRK4QMapIi8QVariantE
	f40dc	 1767  _ZN18QAbstractItemModel12dropMimeDataEPK9QMimeDataN2Qt10DropActionEiiRK11QModelIndex
	f4134	 1770  _ZN18QAbstractItemModel13clearItemDataERK11QModelIndex
	f4170	 1774  _ZN18QAbstractItemModel13insertColumnsEiiRK11QModelIndex
	f41ac	 1776  _ZN18QAbstractItemModel13removeColumnsEiiRK11QModelIndex
	f41e8	 1777  _ZN18QAbstractItemModel13setHeaderDataEiN2Qt11OrientationERK8QVarianti
	f4234	 1787  _ZN18QAbstractItemModel16staticMetaObjectE
	f4264	 1789  _ZN18QAbstractItemModel17resetInternalDataEv
	f4294	 1803  _ZN18QAbstractItemModel4sortEiN2Qt9SortOrderE
	f42c4	 1804  _ZN18QAbstractItemModel6revertEv
	f42e8	 1805  _ZN18QAbstractItemModel6submitEv
	f430c	 1806  _ZN18QAbstractItemModel7setDataERK11QModelIndexRK8QVarianti
	f434c	 1807  _ZN18QAbstractItemModel8moveRowsERK11QModelIndexiiS2_i
	f4388	 1808  _ZN18QAbstractItemModel9fetchMoreERK11QModelIndex
	f43bc	 1817  _ZN18QAbstractListModel11qt_metacallEN11QMetaObject4CallEiPPv
	f43fc	 1818  _ZN18QAbstractListModel11qt_metacastEPKc
	f4428	 1819  _ZN18QAbstractListModel12dropMimeDataEPK9QMimeDataN2Qt10DropActionEiiRK11QModelIndex
	f4480	 1820  _ZN18QAbstractListModel16staticMetaObjectE
	f44b0	 1824  _ZN18QAbstractListModelC2EP7QObject
	f44d8	 1952  _ZN18QJsonValueConstRef11concreteIntES_xb
	f4504	 1953  _ZN18QJsonValueConstRef12concreteBoolES_b
	f4530	 1954  _ZN18QJsonValueConstRef12concreteTypeES_
	f455c	 1957  _ZN18QJsonValueConstRef14concreteStringES_RK7QString
	f4594	 1959  _ZN18QJsonValueConstRef8concreteES_
	f45bc	 1960  _ZN18QJsonValueConstRef9objectKeyES_
	f45e4	 2024  _ZN18QPropertyAnimationC1EP7QObjectRK10QByteArrayS1_
	f461c	 2032  _ZN18QRandomGenerator646systemEv
	f4640	 2037  _ZN18QRegularExpression27wildcardToRegularExpressionE11QStringView6QFlagsINS_24WildcardConversionOptionEE
	f46ac	 2040  _ZN18QRegularExpressionC1ERK7QString6QFlagsINS_13PatternOptionEE
	f46f0	 2047  _ZN18QRegularExpressionD1Ev
	f4710	 2274  _ZN19QProcessEnvironment17systemEnvironmentEv
	f4740	 2285  _ZN19QProcessEnvironmentD1Ev
	f4760	 2349  _ZN20QFutureInterfaceBase11setRunnableEP9QRunnable
	f4798	 2352  _ZN20QFutureInterfaceBase13reportStartedEv
	f47c8	 2354  _ZN20QFutureInterfaceBase13setThreadPoolEP11QThreadPool
	f4804	 2358  _ZN20QFutureInterfaceBase14reportCanceledEv
	f4834	 2359  _ZN20QFutureInterfaceBase14reportFinishedEv
	f4864	 2385  _ZN20QFutureInterfaceBaseC1ERKS_
	f4888	 2386  _ZN20QFutureInterfaceBaseC2ENS_5StateE
	f48b4	 2389  _ZN20QFutureInterfaceBaseD1Ev
	f48d4	 2390  _ZN20QFutureInterfaceBaseD2Ev
	f48f4	 2447  _ZN21QAbstractConcatenable14appendLatin1ToE13QLatin1StringP5QChar
	f4938	 2705  _ZN23QRegularExpressionMatchC1Ev
	f495c	 2709  _ZN23QRegularExpressionMatchD1Ev
	f4980	 2949  _ZN2Qt3hexER11QTextStream
	f499c	 2998  _ZN4QDir18toNativeSeparatorsERK7QString
	f49c8	 3001  _ZN4QDir2cdERK7QString
	f49e4	 3007  _ZN4QDir6removeERK7QString
	f4a04	 3010  _ZN4QDir8homePathEv
	f4a1c	 3011  _ZN4QDir8rootPathEv
	f4a34	 3012  _ZN4QDir8tempPathEv
	f4a4c	 3016  _ZN4QDirC1ERK7QString
	f4a64	 3023  _ZN4QDirD1Ev
	f4a74	 3055  _ZN4QUrlC1ERK7QStringNS_11ParsingModeE
	f4aa0	 3061  _ZN4QUrlD1Ev
	f4ab0	 3091  _ZN5QDate10fromStringE11QStringViewN2Qt10DateFormatE
	f4ae8	 3096  _ZN5QDate11currentDateEv
	f4b04	 3112  _ZN5QFile14setPermissionsERK7QString6QFlagsIN11QFileDevice10PermissionEE
	f4b50	 3120  _ZN5QFile4openE6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	f4b8c	 3125  _ZN5QFile6removeERK7QString
	f4bac	 3126  _ZN5QFile6removeEv
	f4bc4	 3128  _ZN5QFile6renameERK7QStringS2_
	f4be8	 3133  _ZN5QFileC1ERK7QString
	f4c04	 3142  _ZN5QFileD1Ev
	f4c14	 3151  _ZN5QTime11currentTimeEv
	f4c30	 3162  _ZN5QUuid10createUuidEv
	f4c4c	 3165  _ZN5QUuid10fromStringE14QAnyStringView
	f4c78	 3171  _ZN5QUuid12createUuidV5ES_14QByteArrayView
	f4ca8	 3183  _ZN6QDebug12putByteArrayEPKcyNS_13Latin1ContentE
	f4cdc	 3189  _ZN6QDebug9putStringEPK5QChary
	f4d00	 3190  _ZN6QDebugD1Ev
	f4d14	 3211  _ZN6QTimer11setIntervalEi
	f4d30	 3213  _ZN6QTimer13setSingleShotEb
	f4d50	 3215  _ZN6QTimer14singleShotImplENSt6chrono8durationIxSt5ratioILx1ELx1000000000EEEEN2Qt9TimerTypeEPK7QObjectPN9QtPrivate15QSlotObjectBaseE
	f4dd8	 3219  _ZN6QTimer16staticMetaObjectE
	f4df8	 3223  _ZN6QTimer4stopEv
	f4e0c	 3225  _ZN6QTimer5startEi
	f4e24	 3226  _ZN6QTimer5startEv
	f4e3c	 3227  _ZN6QTimer7timeoutENS_14QPrivateSignalE
	f4e68	 3228  _ZN6QTimerC1EP7QObject
	f4e84	 3231  _ZN6QTimerD1Ev
	f4e98	 3243  _ZN7QBuffer4openE6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	f4ed4	 3245  _ZN7QBuffer5closeEv
	f4eec	 3248  _ZN7QBuffer7setDataERK10QByteArray
	f4f14	 3252  _ZN7QBufferC1EP10QByteArrayP7QObject
	f4f3c	 3253  _ZN7QBufferC1EP7QObject
	f4f58	 3257  _ZN7QBufferD1Ev
	f4f6c	 3260  _ZN7QLocale10setDefaultERKS_
	f4f8c	 3280  _ZN7QLocale6systemEv
	f4fa4	 3281  _ZN7QLocaleC1E11QStringView
	f4fc4	 3282  _ZN7QLocaleC1ENS_8LanguageENS_6ScriptENS_7CountryE
	f4ffc	 3287  _ZN7QLocaleC1Ev
	f5010	 3295  _ZN7QLocaleD1Ev
	f5024	 3298  _ZN7QObject10childEventEP11QChildEvent
	f5050	 3299  _ZN7QObject10disconnectEPKS_PKcS1_S3_
	f5078	 3305  _ZN7QObject10timerEventEP11QTimerEvent
	f50a4	 3306  _ZN7QObject11connectImplEPKS_PPvS1_S3_PN9QtPrivate15QSlotObjectBaseEN2Qt14ConnectionTypeEPKiPK11QMetaObject
	f5114	 3307  _ZN7QObject11customEventEP6QEvent
	f5138	 3308  _ZN7QObject11deleteLaterEv
	f5158	 3309  _ZN7QObject11eventFilterEPS_P6QEvent
	f5180	 3310  _ZN7QObject11qt_metacallEN11QMetaObject4CallEiPPv
	f51b4	 3311  _ZN7QObject11qt_metacastEPKc
	f51d4	 3316  _ZN7QObject13connectNotifyERK11QMetaMethod
	f5204	 3318  _ZN7QObject13doSetPropertyEPKcRK8QVariantPS2_
	f5234	 3319  _ZN7QObject13setObjectNameE14QAnyStringView
	f5264	 3322  _ZN7QObject15doSetObjectNameERK7QString
	f5290	 3323  _ZN7QObject16disconnectNotifyERK11QMetaMethod
	f52c0	 3324  _ZN7QObject16staticMetaObjectE
	f52e4	 3328  _ZN7QObject18installEventFilterEPS_
	f530c	 3330  _ZN7QObject5eventEP6QEvent
	f532c	 3331  _ZN7QObject7connectEPKS_PKcS1_S3_N2Qt14ConnectionTypeE
	f5368	 3333  _ZN7QObject9destroyedEPS_
	f5384	 3336  _ZN7QObject9setParentEPS_
	f53a0	 3339  _ZN7QObjectC2EPS_
	f53b4	 3343  _ZN7QObjectD2Ev
	f53c8	 3344  _ZN7QString10fromLatin1E14QByteArrayView
	f53f4	 3355  _ZN7QString13toUtf8_helperERKS_
	f5418	 3358  _ZN7QString14toLower_helperERKS_
	f543c	 3359  _ZN7QString14toLower_helperERS_
	f5460	 3362  _ZN7QString14trimmed_helperERKS_
	f5484	 3368  _ZN7QString17toIntegral_helperE11QStringViewPbi
	f54b8	 3369  _ZN7QString17toIntegral_helperE11QStringViewPbj
	f54ec	 3376  _ZN7QString4chopEx
	f5504	 3379  _ZN7QString6_emptyE
	f551c	 3382  _ZN7QString6appendE5QChar
	f5538	 3384  _ZN7QString6appendERKS_
	f5554	 3389  _ZN7QString6insertExPK5QCharx
	f5574	 3391  _ZN7QString6numberEii
	f558c	 3410  _ZN7QString7replaceE5QCharS0_N2Qt15CaseSensitivityE
	f55c4	 3412  _ZN7QString7replaceERK18QRegularExpressionRKS_
	f55f8	 3414  _ZN7QString7replaceERKS_S1_N2Qt15CaseSensitivityE
	f562c	 3420  _ZN7QString8fromUtf8E14QByteArrayView
	f5654	 3424  _ZN7QStringC1E5QChar
	f566c	 3425  _ZN7QStringC1EPK5QCharx
	f5688	 3426  _ZN7QStringC1Ex5QChar
	f56a0	 3427  _ZN7QStringC1ExN2Qt14InitializationE
	f56c8	 3434  _ZN7QStringaSERKS_
	f56e0	 3435  _ZN7QThread11qt_metacallEN11QMetaObject4CallEiPPv
	f5714	 3436  _ZN7QThread11qt_metacastEPKc
	f5734	 3440  _ZN7QThread13currentThreadEv
	f5754	 3444  _ZN7QThread16staticMetaObjectE
	f5778	 3455  _ZN7QThread4waitE14QDeadlineTimer
	f579c	 3456  _ZN7QThread5eventEP6QEvent
	f57bc	 3459  _ZN7QThread5startENS_8PriorityE
	f57e0	 3460  _ZN7QThread6msleepEm
	f57f8	 3464  _ZN7QThread9terminateEv
	f5814	 3467  _ZN7QThreadC2EP7QObject
	f5830	 3471  _ZN7QThreadD2Ev
	f5844	 3538  _ZN8QProcess14waitForStartedEi
	f5868	 3540  _ZN8QProcess15waitForFinishedEi
	f588c	 3542  _ZN8QProcess16staticMetaObjectE
	f58b0	 3556  _ZN8QProcess21setProcessChannelModeENS_18ProcessChannelModeE
	f58f0	 3563  _ZN8QProcess4killEv
	f5908	 3567  _ZN8QProcess5startERK7QStringRK5QListIS0_E6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	f5960	 3570  _ZN8QProcess8finishedEiNS_10ExitStatusE
	f598c	 3572  _ZN8QProcess9terminateEv
	f59a8	 3574  _ZN8QProcessC1EP7QObject
	f59c4	 3579  _ZN8QSysInfo10kernelTypeEv
	f59e4	 3580  _ZN8QSysInfo11productTypeEv
	f5a04	 3582  _ZN8QSysInfo13kernelVersionEv
	f5a24	 3583  _ZN8QSysInfo14productVersionEv
	f5a48	 3586  _ZN8QSysInfo17prettyProductNameEv
	f5a6c	 3592  _ZN8QVariant13moveConstructE9QMetaTypePv
	f5a98	 3603  _ZN8QVariantC1E13QLatin1String
	f5abc	 3607  _ZN8QVariantC1E5QRect
	f5ad4	 3610  _ZN8QVariantC1E5QUuid
	f5aec	 3612  _ZN8QVariantC1E6QPoint
	f5b08	 3616  _ZN8QVariantC1E9QMetaTypePKv
	f5b28	 3617  _ZN8QVariantC1ERK10QByteArray
	f5b48	 3618  _ZN8QVariantC1ERK10QJsonArray
	f5b68	 3620  _ZN8QVariantC1ERK11QJsonObject
	f5b8c	 3626  _ZN8QVariantC1ERK4QMapI7QStringS_E
	f5bb4	 3630  _ZN8QVariantC1ERK5QListI7QStringE
	f5bd8	 3631  _ZN8QVariantC1ERK5QListIS_E
	f5bf8	 3641  _ZN8QVariantC1ERK7QString
	f5c14	 3644  _ZN8QVariantC1ERKS_
	f5c2c	 3646  _ZN8QVariantC1Eb
	f5c40	 3649  _ZN8QVariantC1Ei
	f5c54	 3703  _ZN8QVariantD1Ev
	f5c68	 3705  _ZN8QVariantaSERKS_
	f5c80	 3762  _ZN9QDateTime15currentDateTimeEv
	f5ca4	 3796  _ZN9QDateTimeD1Ev
	f5cb8	 3809  _ZN9QFileInfoC1ERK11QFileDevice
	f5cdc	 3811  _ZN9QFileInfoC1ERK7QString
	f5cfc	 3812  _ZN9QFileInfoC1ERKS_
	f5d14	 3820  _ZN9QFileInfoD1Ev
	f5d28	 3823  _ZN9QHashSeed10globalSeedEv
	f5d48	 3826  _ZN9QIODevice11qt_metacallEN11QMetaObject4CallEiPPv
	f5d80	 3827  _ZN9QIODevice11qt_metacastEPKc
	f5da4	 3831  _ZN9QIODevice12readLineDataEPcx
	f5dc8	 3837  _ZN9QIODevice16staticMetaObjectE
	f5dec	 3838  _ZN9QIODevice16waitForReadyReadEi
	f5e10	 3845  _ZN9QIODevice19waitForBytesWrittenEi
	f5e38	 3848  _ZN9QIODevice4openE6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	f5e78	 3849  _ZN9QIODevice4peekEPcx
	f5e94	 3850  _ZN9QIODevice4peekEx
	f5eac	 3851  _ZN9QIODevice4readEPcx
	f5ec8	 3852  _ZN9QIODevice4readEx
	f5ee0	 3853  _ZN9QIODevice4seekEx
	f5ef8	 3855  _ZN9QIODevice5closeEv
	f5f10	 3856  _ZN9QIODevice5resetEv
	f5f28	 3858  _ZN9QIODevice5writeEPKcx
	f5f44	 3859  _ZN9QIODevice5writeERK10QByteArray
	f5f6c	 3862  _ZN9QIODevice7readAllEv
	f5f88	 3865  _ZN9QIODevice8skipDataEx
	f5fa4	 3866  _ZN9QIODevice9readyReadEv
	f5fc0	 3871  _ZN9QIODeviceC2EP7QObject
	f5fdc	 3876  _ZN9QIODeviceD2Ev
	f5ff0	 3897  _ZN9QMetaType14registerHelperEPKN9QtPrivate18QMetaTypeInterfaceE
	f6034	 3903  _ZN9QMetaType25registerNormalizedTypedefERK10QByteArrayS_
	f6070	 3911  _ZN9QMetaType7convertES_PKvS_Pv
	f6094	 3961  _ZN9QRunnableD2Ev
	f60a8	 3982  _ZN9QSettings10beginGroupE14QAnyStringView
	f60d8	 3996  _ZN9QSettings19setFallbacksEnabledEb
	f6100	 3999  _ZN9QSettings5clearEv
	f6118	 4005  _ZN9QSettings8endGroupEv
	f6134	 4006  _ZN9QSettings8setValueE14QAnyStringViewRK8QVariant
	f616c	 4010  _ZN9QSettingsC1ENS_6FormatENS_5ScopeERK7QStringS4_P7QObject
	f61ac	 4136  _ZN9QtPrivate12argToQStringE14QAnyStringViewyPPKNS_7ArgBaseE
	f61ec	 4139  _ZN9QtPrivate12equalStringsE11QStringViewS0_
	f621c	 4152  _ZN9QtPrivate13findByteArrayE14QByteArrayViewxS0_
	f6250	 4159  _ZN9QtPrivate14compareStringsE11QStringViewS0_N2Qt15CaseSensitivityE
	f6298	 4242  _ZN9QtPrivate16QStringList_joinEPK5QListI7QStringEPK5QCharx
	f62d8	 4264  _ZN9QtPrivate19QStringList_indexOfEPK5QListI7QStringERK18QRegularExpressionx
	f6328	 4275  _ZN9QtPrivate20QStringList_containsEPK5QListI7QStringE11QStringViewN2Qt15CaseSensitivityE
	f6384	 4327  _ZN9QtPrivate8qustrchrE11QStringViewDs
	f63b0	 4344  _ZNK10QByteArray5splitEc
	f63cc	 4345  _ZNK10QByteArray5toHexEc
	f63e8	 4357  _ZNK10QByteArray8toBase64E6QFlagsINS_12Base64OptionEE
	f6420	 4396  _ZNK10QJsonArray4sizeEv
	f643c	 4404  _ZNK10QJsonValue4typeEv
	f6458	 4405  _ZNK10QJsonValue5toIntEi
	f6474	 4412  _ZNK10QJsonValue8toObjectEv
	f6494	 4414  _ZNK10QJsonValue8toStringEv
	f64b4	 4441  _ZNK11QDataStream26isDeviceTransactionStartedEv
	f64e8	 4482  _ZNK11QJsonObject4sizeEv
	f6504	 4486  _ZNK11QJsonObject5valueERK7QString
	f652c	 4491  _ZNK11QJsonObject8containsERK7QString
	f6554	 4524  _ZNK11QMetaObject10enumeratorEi
	f6578	 4543  _ZNK11QMetaObject17indexOfEnumeratorEPKc
	f65a4	 4545  _ZNK11QMetaObject2trEPKcS1_i
	f65c4	 4546  _ZNK11QMetaObject4castEPK7QObject
	f65e8	 4552  _ZNK11QMetaObject9classNameEv
	f6608	 4553  _ZNK11QObjectData17dynamicMetaObjectEv
	f6634	 4658  _ZNK13QElapsedTimer7elapsedEv
	f6654	 4683  _ZNK13QJsonDocument6objectEv
	f6674	 4684  _ZNK13QJsonDocument6toJsonENS_10JsonFormatE
	f66a4	 4694  _ZNK13QJsonValueRef7toArrayEv
	f66c4	 4696  _ZNK13QJsonValueRef8toObjectEv
	f66e8	 4830  _ZNK14QMessageLogger5debugEv
	f6708	 4833  _ZNK14QMessageLogger5fatalEPKcz
	f672c	 4843  _ZNK14QMessageLogger7warningEv
	f6750	 4849  _ZNK14QMessageLogger8criticalEv
	f6774	 4900  _ZNK14QVersionNumber8toStringEv
	f6798	 5092  _ZNK18QAbstractItemModel10headerDataEiN2Qt11OrientationEi
	f67d4	 5094  _ZNK18QAbstractItemModel11hasChildrenERK11QModelIndex
	f680c	 5095  _ZNK18QAbstractItemModel12canFetchMoreERK11QModelIndex
	f6848	 5096  _ZNK18QAbstractItemModel15canDropMimeDataEPK9QMimeDataN2Qt10DropActionEiiRK11QModelIndex
	f68a4	 5098  _ZNK18QAbstractItemModel20supportedDragActionsEv
	f68d8	 5099  _ZNK18QAbstractItemModel20supportedDropActionsEv
	f690c	 5100  _ZNK18QAbstractItemModel4spanERK11QModelIndex
	f693c	 5101  _ZNK18QAbstractItemModel5buddyERK11QModelIndex
	f6970	 5102  _ZNK18QAbstractItemModel5flagsERK11QModelIndex
	f69a4	 5103  _ZNK18QAbstractItemModel5matchERK11QModelIndexiRK8QVarianti6QFlagsIN2Qt9MatchFlagEE
	f69fc	 5104  _ZNK18QAbstractItemModel7siblingEiiRK11QModelIndex
	f6a34	 5106  _ZNK18QAbstractItemModel8itemDataERK11QModelIndex
	f6a68	 5107  _ZNK18QAbstractItemModel8mimeDataERK5QListI11QModelIndexE
	f6aa4	 5108  _ZNK18QAbstractItemModel9mimeTypesEv
	f6acc	 5109  _ZNK18QAbstractItemModel9multiDataERK11QModelIndex18QModelRoleDataSpan
	f6b18	 5110  _ZNK18QAbstractItemModel9roleNamesEv
	f6b40	 5112  _ZNK18QAbstractListModel11columnCountERK11QModelIndex
	f6b78	 5113  _ZNK18QAbstractListModel11hasChildrenERK11QModelIndex
	f6bb0	 5114  _ZNK18QAbstractListModel5flagsERK11QModelIndex
	f6be4	 5115  _ZNK18QAbstractListModel5indexEiiRK11QModelIndex
	f6c18	 5116  _ZNK18QAbstractListModel6parentERK11QModelIndex
	f6c4c	 5117  _ZNK18QAbstractListModel7siblingEiiRK11QModelIndex
	f6c84	 5162  _ZNK18QJsonValueConstRef8toObjectEv
	f6cac	 5163  _ZNK18QJsonValueConstRef9toVariantEv
	f6cd4	 5206  _ZNK18QRegularExpression5matchERK7QStringxNS_9MatchTypeE6QFlagsINS_11MatchOptionEE
	f6d2c	 5207  _ZNK18QRegularExpression7isValidEv
	f6d54	 5312  _ZNK19QProcessEnvironment5valueERK7QStringS2_
	f6d84	 5314  _ZNK19QProcessEnvironment8containsERK7QString
	f6db4	 5335  _ZNK20QFutureInterfaceBase10isCanceledEv
	f6de0	 5336  _ZNK20QFutureInterfaceBase10isFinishedEv
	f6e0c	 5353  _ZNK20QFutureInterfaceBase15runContinuationEv
	f6e3c	 5361  _ZNK20QFutureInterfaceBase9isRunningEv
	f6e68	 5497  _ZNK23QRegularExpressionMatch8capturedEi
	f6e94	 5498  _ZNK23QRegularExpressionMatch8hasMatchEv
	f6ec0	 5540  _ZNK4QDir12absolutePathEv
	f6edc	 5543  _ZNK4QDir13entryInfoListERK5QListI7QStringE6QFlagsINS_6FilterEES5_INS_8SortFlagEE
	f6f30	 5551  _ZNK4QDir5mkdirERK7QStringSt8optionalI6QFlagsIN11QFileDevice10PermissionEEE
	f6f80	 5554  _ZNK4QDir6existsEv
	f6f98	 5558  _ZNK4QDir6mkpathERK7QStringSt8optionalI6QFlagsIN11QFileDevice10PermissionEEE
	f6fe8	 5560  _ZNK4QDir7dirNameEv
	f7000	 5565  _ZNK4QDir9entryListE6QFlagsINS_6FilterEES0_INS_8SortFlagEE
	f7040	 5566  _ZNK4QDir9entryListERK5QListI7QStringE6QFlagsINS_6FilterEES5_INS_8SortFlagEE
	f7090	 5579  _ZNK4QUrl4hostE6QFlagsINS_25ComponentFormattingOptionEE
	f70cc	 5581  _ZNK4QUrl4portEi
	f70e0	 5626  _ZNK5QDate8toStringEN2Qt10DateFormatE
	f7108	 5639  _ZNK5QFile8fileNameEv
	f7120	 5640  _ZNK5QRect10intersectsERKS_
	f7140	 5642  _ZNK5QRect8containsERK6QPointb
	f7164	 5644  _ZNK5QRectanERKS_
	f7178	 5646  _ZNK5QSize6scaledERKS_N2Qt15AspectRatioModeE
	f71a8	 5657  _ZNK5QTime8toStringEN2Qt10DateFormatE
	f71d0	 5662  _ZNK5QUuid8toStringENS_12StringFormatE
	f71fc	 5686  _ZNK6QTimer8isActiveEv
	f7218	 5690  _ZNK7QBuffer3posEv
	f7230	 5691  _ZNK7QBuffer4dataEv
	f7248	 5692  _ZNK7QBuffer4sizeEv
	f7260	 5715  _ZNK7QLocale13textDirectionEv
	f7280	 5731  _ZNK7QLocale4nameENS_12TagSeparatorE
	f72a8	 5758  _ZNK7QLocale8languageEv
	f72c4	 5762  _ZNK7QLocale8toStringE5QDateNS_10FormatTypeE
	f72f4	 5786  _ZNK7QObject10objectNameEv
	f7314	 5793  _ZNK7QObject6threadEv
	f732c	 5794  _ZNK7QObject8propertyEPKc
	f7348	 5797  _ZNK7QString10startsWithE13QLatin1StringN2Qt15CaseSensitivityE
	f738c	 5798  _ZNK7QString10startsWithE5QCharN2Qt15CaseSensitivityE
	f73c4	 5799  _ZNK7QString10startsWithERKS_N2Qt15CaseSensitivityE
	f73fc	 5823  _ZNK7QString5countE5QCharN2Qt15CaseSensitivityE
	f7430	 5827  _ZNK7QString5splitE5QChar6QFlagsIN2Qt18SplitBehaviorFlagsEENS2_15CaseSensitivityE
	f7484	 5833  _ZNK7QString7compareERKS_N2Qt15CaseSensitivityE
	f74b8	 5841  _ZNK7QString7sectionERKS_xx6QFlagsINS_11SectionFlagEE
	f74f0	 5843  _ZNK7QString8arg_implE14QAnyStringViewi5QChar
	f7520	 5845  _ZNK7QString8arg_implExii5QChar
	f7544	 5846  _ZNK7QString8arg_implEyii5QChar
	f7568	 5849  _ZNK7QString8endsWithE5QCharN2Qt15CaseSensitivityE
	f75a0	 5860  _ZNK7QThread9isRunningEv
	f75bc	 5893  _ZNK8QProcess8exitCodeEv
	f75d8	 5899  _ZNK8QVariant11toByteArrayEv
	f75f8	 5900  _ZNK8QVariant11toJsonArrayEv
	f7618	 5904  _ZNK8QVariant12toJsonObjectEv
	f7638	 5906  _ZNK8QVariant12toStringListEv
	f7658	 5912  _ZNK8QVariant5toIntEPb
	f7674	 5913  _ZNK8QVariant5toMapEv
	f768c	 5915  _ZNK8QVariant6equalsERKS_
	f76a8	 5916  _ZNK8QVariant6isNullEv
	f76c4	 5922  _ZNK8QVariant6toListEv
	f76e0	 5924  _ZNK8QVariant6toRectEv
	f76fc	 5928  _ZNK8QVariant6toUuidEv
	f7718	 5939  _ZNK8QVariant8toStringEv
	f7734	 6004  _ZNK9QDateTime8toStringEN2Qt10DateFormatE
	f7760	 6005  _ZNK9QDateTime8toStringERK7QString
	f7788	 6012  _ZNK9QFileInfo10isWritableEv
	f77a8	 6017  _ZNK9QFileInfo12absolutePathEv
	f77cc	 6025  _ZNK9QFileInfo16absoluteFilePathEv
	f77f4	 6027  _ZNK9QFileInfo17canonicalFilePathEv
	f781c	 6028  _ZNK9QFileInfo3dirEv
	f7834	 6032  _ZNK9QFileInfo5isDirEv
	f7850	 6035  _ZNK9QFileInfo6isFileEv
	f786c	 6044  _ZNK9QFileInfo8fileNameEv
	f7888	 6045  _ZNK9QFileInfo8filePathEv
	f78a4	 6050  _ZNK9QFileInfo9isSymLinkEv
	f78c4	 6055  _ZNK9QIODevice11canReadLineEv
	f78e4	 6057  _ZNK9QIODevice12bytesToWriteEv
	f7908	 6058  _ZNK9QIODevice12isSequentialEv
	f792c	 6059  _ZNK9QIODevice14bytesAvailableEv
	f7950	 6066  _ZNK9QIODevice3posEv
	f7968	 6067  _ZNK9QIODevice4sizeEv
	f7980	 6068  _ZNK9QIODevice5atEndEv
	f799c	 6069  _ZNK9QIODevice6isOpenEv
	f79b8	 6079  _ZNK9QMetaEnum10valueToKeyEy
	f79d8	 6158  _ZNK9QSettings10isWritableEv
	f79f8	 6160  _ZNK9QSettings11childGroupsEv
	f7a18	 6167  _ZNK9QSettings5valueE14QAnyStringView
	f7a40	 6177  _ZNK9QSettings9childKeysEv
	f7a60	 6250  _ZNKR10QByteArray3midExx
	f7a7c	 6252  _ZNKR7QString3midExx
	f7a94	 6482  _Zls6QDebugRK10QJsonArray
	f7ab0	 6484  _Zls6QDebugRK11QJsonObject
	f7ad0	 6503  _Zls6QDebugRK5QUuid
	f7ae8	 6527  _ZlsR11QDataStreamRK10QJsonArray
	f7b0c	 6529  _ZlsR11QDataStreamRK11QJsonObject
	f7b30	 6539  _ZlsR11QDataStreamRK5QUuid
	f7b50	 6546  _ZlsR11QDataStreamRK7QString
	f7b70	 6549  _ZlsR11QDataStreamRK8QVariant
	f7b90	 6558  _ZrsR11QDataStreamR10QByteArray
	f7bb4	 6561  _ZrsR11QDataStreamR10QJsonArray
	f7bd8	 6563  _ZrsR11QDataStreamR11QJsonObject
	f7bfc	 6577  _ZrsR11QDataStreamR5QUuid
	f7c18	 6584  _ZrsR11QDataStreamR7QString
	f7c38	 6587  _ZrsR11QDataStreamR8QVariant
	f7c58	 6606  qt_version_tag_6_10
	DLL Name: Qt6Gui.dll
	f7c70	  649  _ZN11QStyleHints14setColorSchemeEN2Qt11ColorSchemeE
	f7ca8	  942  _ZN12QFontMetricsC1ERK5QFont
	f7cc8	  948  _ZN12QFontMetricsD1Ev
	f7ce0	 1072  _ZN12QKeySequenceC1ERKS_
	f7cfc	 1073  _ZN12QKeySequenceC1Eiiii
	f7d18	 1074  _ZN12QKeySequenceC1Ev
	f7d30	 1081  _ZN12QKeySequenceD1Ev
	f7d48	 1083  _ZN12QKeySequenceaSERKS_
	f7d64	 1085  _ZN12QPaintDeviceC2Ev
	f7d7c	 1733  _ZN15QGuiApplication10styleHintsEv
	f7da4	 1743  _ZN15QGuiApplication11screenAddedEP7QScreen
	f7dd4	 1747  _ZN15QGuiApplication13primaryScreenEv
	f7dfc	 1748  _ZN15QGuiApplication13screenRemovedEP7QScreen
	f7e2c	 1760  _ZN15QGuiApplication16staticMetaObjectE
	f7e58	 1763  _ZN15QGuiApplication17setOverrideCursorERK7QCursor
	f7e90	 1768  _ZN15QGuiApplication18setLayoutDirectionEN2Qt15LayoutDirectionE
	f7ed4	 1773  _ZN15QGuiApplication21restoreOverrideCursorEv
	f7f04	 1782  _ZN15QGuiApplication25setQuitOnLastWindowClosedEb
	f7f38	 1792  _ZN15QGuiApplication7screensEv
	f7f5c	 2032  _ZN16QConicalGradient8setAngleEd
	f7f80	 2033  _ZN16QConicalGradient9setCenterERK7QPointF
	f7fb0	 2036  _ZN16QConicalGradientC1Ev
	f7fcc	 2040  _ZN16QConicalGradientD1Ev
	f7fe8	 2044  _ZN16QDesktopServices7openUrlERK4QUrl
	f8010	 4205  _ZN4QPen11setCapStyleEN2Qt11PenCapStyleE
	f803c	 4218  _ZN4QPenC1ERK6QBrushdN2Qt8PenStyleENS3_11PenCapStyleENS3_12PenJoinStyleE
	f8088	 4227  _ZN4QPenD1Ev
	f8098	 4299  _ZN5QFont12setPointSizeEi
	f80b4	 4328  _ZN5QFont9setWeightENS_6WeightE
	f80d8	 4332  _ZN5QFontC1ERKS_
	f80ec	 4334  _ZN5QFontC1Ev
	f80fc	 4341  _ZN5QFontD1Ev
	f810c	 4343  _ZN5QFontaSERKS_
	f8120	 4354  _ZN5QIcon7addFileERK7QStringRK5QSizeNS_4ModeENS_5StateE
	f815c	 4355  _ZN5QIcon9addPixmapERK7QPixmapNS_4ModeENS_5StateE
	f8190	 4363  _ZN5QIconC1ERK7QPixmap
	f81ac	 4365  _ZN5QIconC1ERKS_
	f81c0	 4366  _ZN5QIconC1Ev
	f81d0	 4372  _ZN5QIconD1Ev
	f81e0	 4407  _ZN6QBrushC1ERK6QColorN2Qt10BrushStyleE
	f820c	 4411  _ZN6QBrushC1ERK9QGradient
	f8228	 4424  _ZN6QBrushD1Ev
	f823c	 4432  _ZN6QColor10fromStringE14QAnyStringView
	f8268	 4461  _ZN6QColor8fromRgbaEj
	f8280	 4462  _ZN6QColor8setAlphaEi
	f8298	 4471  _ZN6QColorC1EN2Qt11GlobalColorE
	f82bc	 4487  _ZN6QImage13setPixelColorEiiRK6QColor
	f82e4	 4495  _ZN6QImage16staticMetaObjectE
	f8304	 4503  _ZN6QImage23convertToFormat_inplaceENS_6FormatE6QFlagsIN2Qt19ImageConversionFlagEE
	f835c	 4504  _ZN6QImage4bitsEv
	f8370	 4509  _ZN6QImage4loadERK7QStringPKc
	f8390	 4511  _ZN6QImage7setTextERK7QStringS2_
	f83b4	 4514  _ZN6QImage8scanLineEi
	f83cc	 4523  _ZN6QImageC1EPhiiNS_6FormatEPFvPvES2_
	f83f4	 4524  _ZN6QImageC1EPhiixNS_6FormatEPFvPvES2_
	f8420	 4527  _ZN6QImageC1ERKS_
	f8434	 4529  _ZN6QImageC1Ev
	f8448	 4541  _ZN6QImageD1Ev
	f845c	 4580  _ZN7QAction7setTextERK7QString
	f8480	 4614  _ZN7QCursor3posEv
	f8494	 4616  _ZN7QCursor6setPosEii
	f84ac	 4618  _ZN7QCursorC1EN2Qt11CursorShapeE
	f84d0	 4620  _ZN7QCursorC1ERK7QPixmapii
	f84f0	 4628  _ZN7QCursorD1Ev
	f8504	 4644  _ZN7QPixmap9fromImageERK6QImage6QFlagsIN2Qt19ImageConversionFlagEE
	f854c	 4649  _ZN7QPixmapC1ERK7QStringPKc6QFlagsIN2Qt19ImageConversionFlagEE
	f8590	 4650  _ZN7QPixmapC1ERKS_
	f85a8	 4652  _ZN7QPixmapC1Ev
	f85bc	 4662  _ZN7QPixmapD1Ev
	f85d0	 4664  _ZN7QPixmapaSERKS_
	f85e8	 4695  _ZN7QScreen10grabWindowEyiiii
	f8608	 4698  _ZN7QScreen15geometryChangedERK5QRect
	f8630	 4699  _ZN7QScreen16staticMetaObjectE
	f8654	 4835  _ZN7QWindow9setScreenEP7QScreen
	f8678	 4847  _ZN8QPainter10drawPixmapERK7QPointFRK7QPixmap
	f86a8	 4871  _ZN8QPainter13setRenderHintENS_10RenderHintEb
	f86d8	 4898  _ZN8QPainter6setPenERK4QPen
	f86f8	 4900  _ZN8QPainter7drawArcERK6QRectFii
	f871c	 4903  _ZN8QPainter7setFontERK5QFont
	f873c	 4908  _ZN8QPainter8drawTextERK7QPointFRK7QString
	f876c	 4912  _ZN8QPainter8fillRectERK5QRectRK6QColor
	f8798	 4919  _ZN8QPainter9drawImageERK6QRectFRK6QImageS2_6QFlagsIN2Qt19ImageConversionFlagEE
	f87ec	 4920  _ZN8QPainter9drawImageERK7QPointFRK6QImage
	f881c	 4930  _ZN8QPainterC1EP12QPaintDevice
	f8840	 4934  _ZN8QPainterD1Ev
	f8854	 4943  _ZN8QPalette8setBrushENS_10ColorGroupENS_9ColorRoleERK6QBrush
	f8894	 4949  _ZN8QPaletteC1ERKS_
	f88ac	 4958  _ZN8QPaletteD1Ev
	f88c0	 5033  _ZN9QGradient10setColorAtEdRK6QColor
	f88e8	 5298  _ZNK11QEventPoint8positionEv
	f8908	 5405  _ZNK11QStyleHints11colorSchemeEv
	f892c	 5576  _ZNK12QFontMetrics12boundingRectERK5QRectiRK7QStringiPi
	f8968	 5577  _ZNK12QFontMetrics12boundingRectERK7QString
	f8998	 5587  _ZNK12QFontMetrics17horizontalAdvanceERK7QStringi
	f89cc	 5591  _ZNK12QFontMetrics6ascentEv
	f89ec	 5673  _ZNK12QKeySequence8toStringENS_14SequenceFormatE
	f8a20	 6847  _ZNK5QIcon6pixmapERK5QSizeNS_4ModeENS_5StateE
	f8a50	 6868  _ZNK6QColor3redEv
	f8a64	 6870  _ZNK6QColor4blueEv
	f8a7c	 6873  _ZNK6QColor4nameENS_10NameFormatE
	f8aa0	 6876  _ZNK6QColor5alphaEv
	f8ab8	 6880  _ZNK6QColor5greenEv
	f8ad0	 6911  _ZNK6QColorcv8QVariantEv
	f8aec	 6912  _ZNK6QColoreqERKS_
	f8b04	 6918  _ZNK6QImage10pixelColorEii
	f8b24	 6925  _ZNK6QImage12bytesPerLineEv
	f8b44	 6943  _ZNK6QImage22convertToFormat_helperENS_6FormatE6QFlagsIN2Qt19ImageConversionFlagEE
	f8b9c	 6945  _ZNK6QImage4copyERK5QRect
	f8bb8	 6946  _ZNK6QImage4rectEv
	f8bd0	 6947  _ZNK6QImage4saveEP9QIODevicePKci
	f8bf4	 6949  _ZNK6QImage4sizeEv
	f8c0c	 6950  _ZNK6QImage4textERK7QString
	f8c2c	 6955  _ZNK6QImage5widthEv
	f8c44	 6956  _ZNK6QImage6formatEv
	f8c5c	 6957  _ZNK6QImage6heightEv
	f8c74	 6958  _ZNK6QImage6isNullEv
	f8c8c	 6961  _ZNK6QImage6scaledERK5QSizeN2Qt15AspectRatioModeENS3_18TransformationModeE
	f8cdc	 6968  _ZNK6QImage9constBitsEv
	f8cf8	 6971  _ZNK6QImageeqERKS_
	f8d10	 7034  _ZNK7QPixmap4sizeEv
	f8d28	 7036  _ZNK7QPixmap5widthEv
	f8d40	 7038  _ZNK7QPixmap6heightEv
	f8d58	 7043  _ZNK7QPixmap7toImageEv
	f8d74	 7084  _ZNK7QScreen11virtualSizeEv
	f8d94	 7102  _ZNK7QScreen20availableVirtualSizeEv
	f8dbc	 7111  _ZNK7QScreen8geometryEv
	f8dd8	 7184  _ZNK8QPainter4fontEv
	f8df0	 7196  _ZNK8QPalette5brushENS_10ColorGroupENS_9ColorRoleE
	f8e28	 7279  _ZNK9QKeyEvent9modifiersEv
	f8e48	 7827  _ZTV6QImage
	f8e58	 7830  _ZTV7QPixmap
	f8e68	 7944  _Zls6QDebugRK6QColor
	f8e80	 7945  _Zls6QDebugRK6QImage
	f8e98	 7986  _ZlsR11QDataStreamRK6QColor
	f8eb8	 7987  _ZlsR11QDataStreamRK6QImage
	f8ed8	 8019  _ZrsR11QDataStreamR6QColor
	f8ef8	 8020  _ZrsR11QDataStreamR6QImage
	DLL Name: Qt6Network.dll
	f8f18	  175  _ZN10QTcpServer13newConnectionEv
	f8f3c	  178  _ZN10QTcpServer16staticMetaObjectE
	f8f64	  185  _ZN10QTcpServer21nextPendingConnectionEv
	f8f90	  188  _ZN10QTcpServer5closeEv
	f8fac	  189  _ZN10QTcpServer6listenERK12QHostAddresst
	f8fd8	  192  _ZN10QTcpServerC1EP7QObject
	f8ff8	  196  _ZN10QTcpServerD1Ev
	f9010	  316  _ZN12QHostAddressC1ENS_14SpecialAddressE
	f903c	  320  _ZN12QHostAddressC1ERK7QString
	f9060	  321  _ZN12QHostAddressC1ERKS_
	f907c	  332  _ZN12QHostAddressD1Ev
	f9094	  591  _ZN15QAbstractSocket12disconnectedEv
	f90bc	  606  _ZN15QAbstractSocket16staticMetaObjectE
	f90e8	  861  _ZN17QNetworkInterface12allAddressesEv
	f9114	 1503  _ZN9QHostInfo13localHostNameEv
	f9138	 1507  _ZN9QHostInfo15localDomainNameEv
	f915c	 1509  _ZN9QHostInfo8fromNameERK7QString
	f9180	 1515  _ZN9QHostInfoD1Ev
	f9194	 1657  _ZNK12QHostAddress10isLoopbackEv
	f91b8	 1666  _ZNK12QHostAddress6isNullEv
	f91d8	 1670  _ZNK12QHostAddress8protocolEv
	f91f8	 1671  _ZNK12QHostAddress8toStringEv
	f9218	 1673  _ZNK12QHostAddresseqERKS_
	f9234	 1790  _ZNK15QAbstractSocket11peerAddressEv
	f925c	 1803  _ZNK15QAbstractSocket8peerPortEv
	f9280	 2131  _ZNK9QHostInfo11errorStringEv
	f92a0	 2132  _ZNK9QHostInfo5errorEv
	f92bc	 2133  _ZNK9QHostInfo8hostNameEv
	f92d8	 2135  _ZNK9QHostInfo9addressesEv
	DLL Name: Qt6Widgets.dll
	f92f8	   44  _ZN10QBoxLayout10setSpacingEi
	f9318	   63  _ZN10QBoxLayout9addLayoutEP7QLayouti
	f9340	   64  _ZN10QBoxLayout9addWidgetEP7QWidgeti6QFlagsIN2Qt13AlignmentFlagEE
	f9384	  206  _ZN10QTabWidget10setTabTextEiRK7QString
	f93b0	  225  _ZN10QTabWidget15setCurrentIndexEi
	f93d8	  238  _ZN10QTabWidget6addTabEP7QWidgetRK5QIconRK7QString
	f9410	  245  _ZN10QTabWidgetC1EP7QWidget
	f9430	  391  _ZN11QFileDialog15getOpenFileNameEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE
	f9488	  393  _ZN11QFileDialog15getSaveFileNameEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE
	f94e0	  411  _ZN11QFileDialog20getExistingDirectoryEP7QWidgetRK7QStringS4_6QFlagsINS_6OptionEE
	f9534	  514  _ZN11QGridLayout10setSpacingEi
	f9558	  520  _ZN11QGridLayout16setColumnStretchEii
	f9580	  523  _ZN11QGridLayout18setVerticalSpacingEi
	f95ac	  525  _ZN11QGridLayout20setHorizontalSpacingEi
	f95d8	  530  _ZN11QGridLayout7addItemEP11QLayoutItemiiii6QFlagsIN2Qt13AlignmentFlagEE
	f9624	  534  _ZN11QGridLayout9addWidgetEP7QWidgetiiii6QFlagsIN2Qt13AlignmentFlagEE
	f966c	  535  _ZN11QGridLayoutC1EP7QWidget
	f968c	  545  _ZN11QHBoxLayoutC1Ev
	f96a4	  740  _ZN11QMessageBox15setEscapeButtonEP15QAbstractButton
	f96dc	  742  _ZN11QMessageBox16setDefaultButtonEP11QPushButton
	f9710	  758  _ZN11QMessageBox8criticalEP7QWidgetRK7QStringS4_6QFlagsINS_14StandardButtonEES6_
	f9764	  766  _ZN11QMessageBox9addButtonERK7QStringNS_10ButtonRoleE
	f979c	  769  _ZN11QMessageBoxC1ENS_4IconERK7QStringS3_6QFlagsINS_14StandardButtonEEP7QWidgetS4_IN2Qt10WindowTypeEE
	f9804	  776  _ZN11QMessageBoxD1Ev
	f981c	  823  _ZN11QPushButtonC1EP7QWidget
	f983c	  890  _ZN11QToolButton10enterEventEP11QEnterEvent
	f986c	  891  _ZN11QToolButton10leaveEventEP6QEvent
	f9894	  892  _ZN11QToolButton10paintEventEP11QPaintEvent
	f98c4	  893  _ZN11QToolButton10timerEventEP11QTimerEvent
	f98f4	  894  _ZN11QToolButton11actionEventEP12QActionEvent
	f9924	  895  _ZN11QToolButton11changeEventEP6QEvent
	f9950	  896  _ZN11QToolButton11qt_metacallEN11QMetaObject4CallEiPPv
	f998c	  897  _ZN11QToolButton11qt_metacastEPKc
	f99b0	  899  _ZN11QToolButton12setAutoRaiseEb
	f99d4	  901  _ZN11QToolButton13checkStateSetEv
	f99f8	  902  _ZN11QToolButton14nextCheckStateEv
	f9a20	  903  _ZN11QToolButton15mousePressEventEP11QMouseEvent
	f9a54	  905  _ZN11QToolButton16staticMetaObjectE
	f9a7c	  906  _ZN11QToolButton17mouseReleaseEventEP11QMouseEvent
	f9ab4	  908  _ZN11QToolButton18setToolButtonStyleEN2Qt15ToolButtonStyleE
	f9af4	  909  _ZN11QToolButton5eventEP6QEvent
	f9b18	  914  _ZN11QToolButtonC2EP7QWidget
	f9b38	  917  _ZN11QToolButtonD2Ev
	f9b50	  967  _ZN11QVBoxLayoutC1EP7QWidget
	f9b70	 1006  _ZN12QApplication12activeWindowEv
	f9b94	 1009  _ZN12QApplication13setStyleSheetERK7QString
	f9bc4	 1018  _ZN12QApplication16staticMetaObjectE
	f9bec	 1045  _ZN12QApplication8setStyleEP6QStyle
	f9c14	 1094  _ZN12QColorDialogC1ERK6QColorP7QWidget
	f9c40	 1098  _ZN12QColorDialogD1Ev
	f9c58	 1139  _ZN12QInputDialog12setInputModeENS_9InputModeE
	f9c8c	 1140  _ZN12QInputDialog12setLabelTextERK7QString
	f9cbc	 1171  _ZN12QInputDialogC1EP7QWidget6QFlagsIN2Qt10WindowTypeEE
	f9cf8	 1174  _ZN12QInputDialogD1Ev
	f9d10	 1724  _ZN13QStyleFactory6createERK7QString
	f9d38	 1923  _ZN14QPlainTextEdit11setReadOnlyEb
	f9d60	 1928  _ZN14QPlainTextEdit12setPlainTextERK7QString
	f9d90	 1989  _ZN14QPlainTextEditC1EP7QWidget
	f9db4	 2185  _ZN15QAbstractButton10setCheckedEb
	f9ddc	 2190  _ZN15QAbstractButton11setIconSizeERK5QSize
	f9e0c	 2191  _ZN15QAbstractButton11setShortcutERK12QKeySequence
	f9e44	 2193  _ZN15QAbstractButton12focusInEventEP11QFocusEvent
	f9e78	 2196  _ZN15QAbstractButton13focusOutEventEP11QFocusEvent
	f9eb0	 2197  _ZN15QAbstractButton13keyPressEventEP9QKeyEvent
	f9ee4	 2199  _ZN15QAbstractButton14mouseMoveEventEP11QMouseEvent
	f9f1c	 2201  _ZN15QAbstractButton15keyReleaseEventEP9QKeyEvent
	f9f50	 2204  _ZN15QAbstractButton16staticMetaObjectE
	f9f7c	 2212  _ZN15QAbstractButton7clickedEb
	f9fa0	 2215  _ZN15QAbstractButton7setIconERK5QIcon
	f9fc8	 2216  _ZN15QAbstractButton7setTextERK7QString
	f9ff4	 2217  _ZN15QAbstractButton7toggledEb
	fa018	 2532  _ZN15QSystemTrayIcon10setToolTipERK7QString
	fa048	 2533  _ZN15QSystemTrayIcon10setVisibleEb
	fa070	 2536  _ZN15QSystemTrayIcon11showMessageERK7QStringS2_NS_11MessageIconEi
	fa0b4	 2545  _ZN15QSystemTrayIcon7setIconERK5QIcon
	fa0dc	 2547  _ZN15QSystemTrayIconC1EP7QObject
	fa100	 2648  _ZN16QDialogButtonBox16staticMetaObjectE
	fa12c	 2650  _ZN16QDialogButtonBox18setStandardButtonsE6QFlagsINS_14StandardButtonEE
	fa178	 2654  _ZN16QDialogButtonBox8acceptedEv
	fa19c	 2655  _ZN16QDialogButtonBox8rejectedEv
	fa1c0	 2662  _ZN16QDialogButtonBoxC1EP7QWidget
	fa1e4	 3835  _ZN22QGraphicsOpacityEffect10setOpacityEd
	fa210	 3844  _ZN22QGraphicsOpacityEffectC1EP7QObject
	fa23c	 4232  _ZN6QFrame13setFrameShapeENS_5ShapeE
	fa264	 4252  _ZN6QLabel11setWordWrapEb
	fa280	 4254  _ZN6QLabel12setAlignmentE6QFlagsIN2Qt13AlignmentFlagEE
	fa2bc	 4269  _ZN6QLabel20setOpenExternalLinksEb
	fa2e4	 4275  _ZN6QLabel7setTextERK7QString
	fa304	 4279  _ZN6QLabel9setPixmapERK7QPixmap
	fa328	 4280  _ZN6QLabelC1EP7QWidget6QFlagsIN2Qt10WindowTypeEE
	fa35c	 4311  _ZN7QDialog10closeEventEP11QCloseEvent
	fa388	 4312  _ZN7QDialog10setVisibleEb
	fa3a4	 4313  _ZN7QDialog11eventFilterEP7QObjectP6QEvent
	fa3d4	 4314  _ZN7QDialog11qt_metacallEN11QMetaObject4CallEiPPv
	fa408	 4315  _ZN7QDialog11qt_metacastEPKc
	fa428	 4316  _ZN7QDialog11resizeEventEP12QResizeEvent
	fa454	 4317  _ZN7QDialog13keyPressEventEP9QKeyEvent
	fa480	 4319  _ZN7QDialog16contextMenuEventEP17QContextMenuEvent
	fa4b8	 4320  _ZN7QDialog16staticMetaObjectE
	fa4dc	 4323  _ZN7QDialog4doneEi
	fa4f4	 4324  _ZN7QDialog4execEv
	fa50c	 4325  _ZN7QDialog4openEv
	fa524	 4326  _ZN7QDialog6acceptEv
	fa53c	 4327  _ZN7QDialog6rejectEv
	fa554	 4331  _ZN7QDialog8setModalEb
	fa570	 4333  _ZN7QDialog9showEventEP10QShowEvent
	fa598	 4336  _ZN7QDialogC2EP7QWidget6QFlagsIN2Qt10WindowTypeEE
	fa5cc	 4340  _ZN7QDialogD2Ev
	fa5e0	 4362  _ZN7QLayout18setContentsMarginsEiiii
	fa608	 4460  _ZN7QWidget10closeEventEP11QCloseEvent
	fa634	 4461  _ZN7QWidget10enterEventEP11QEnterEvent
	fa660	 4462  _ZN7QWidget10leaveEventEP6QEvent
	fa684	 4463  _ZN7QWidget10paintEventEP11QPaintEvent
	fa6b0	 4464  _ZN7QWidget10setEnabledEb
	fa6cc	 4465  _ZN7QWidget10setPaletteERK8QPalette
	fa6f4	 4467  _ZN7QWidget10setVisibleEb
	fa710	 4471  _ZN7QWidget10wheelEventEP11QWheelEvent
	fa73c	 4472  _ZN7QWidget11actionEventEP12QActionEvent
	fa768	 4473  _ZN7QWidget11changeEventEP6QEvent
	fa78c	 4476  _ZN7QWidget11nativeEventERK10QByteArrayPvPx
	fa7bc	 4477  _ZN7QWidget11qt_metacallEN11QMetaObject4CallEiPPv
	fa7f0	 4478  _ZN7QWidget11qt_metacastEPKc
	fa810	 4479  _ZN7QWidget11resizeEventEP12QResizeEvent
	fa83c	 4485  _ZN7QWidget11tabletEventEP12QTabletEvent
	fa868	 4488  _ZN7QWidget12focusInEventEP11QFocusEvent
	fa894	 4489  _ZN7QWidget12grabKeyboardEv
	fa8b4	 4495  _ZN7QWidget12setAttributeEN2Qt15WidgetAttributeEb
	fa8e8	 4496  _ZN7QWidget12setFixedSizeERK5QSize
	fa910	 4497  _ZN7QWidget12setFixedSizeEii
	fa930	 4500  _ZN7QWidget13dragMoveEventEP14QDragMoveEvent
	fa960	 4501  _ZN7QWidget13focusOutEventEP11QFocusEvent
	fa98c	 4503  _ZN7QWidget13keyPressEventEP9QKeyEvent
	fa9b8	 4504  _ZN7QWidget13setFixedWidthEi
	fa9d8	 4506  _ZN7QWidget13setSizePolicyE11QSizePolicy
	faa04	 4507  _ZN7QWidget13setStyleSheetERK7QString
	faa2c	 4509  _ZN7QWidget13setWindowIconERK5QIcon
	faa54	 4514  _ZN7QWidget14activateWindowEv
	faa74	 4515  _ZN7QWidget14dragEnterEventEP15QDragEnterEvent
	faaa8	 4516  _ZN7QWidget14dragLeaveEventEP15QDragLeaveEvent
	faadc	 4517  _ZN7QWidget14mouseMoveEventEP11QMouseEvent
	fab0c	 4519  _ZN7QWidget14setFixedHeightEi
	fab2c	 4520  _ZN7QWidget14setFocusPolicyEN2Qt11FocusPolicyE
	fab60	 4521  _ZN7QWidget14setMaximumSizeEii
	fab84	 4522  _ZN7QWidget14setMinimumSizeEii
	faba8	 4523  _ZN7QWidget14setWindowFlagsE6QFlagsIN2Qt10WindowTypeEE
	fabe4	 4525  _ZN7QWidget14setWindowTitleERK7QString
	fac10	 4526  _ZN7QWidget14showFullScreenEv
	fac30	 4528  _ZN7QWidget15keyReleaseEventEP9QKeyEvent
	fac5c	 4530  _ZN7QWidget15mousePressEventEP11QMouseEvent
	fac8c	 4531  _ZN7QWidget15releaseKeyboardEv
	facb0	 4535  _ZN7QWidget15setMaximumWidthEi
	facd4	 4536  _ZN7QWidget15setMinimumWidthEi
	facf8	 4537  _ZN7QWidget16contextMenuEventEP17QContextMenuEvent
	fad30	 4538  _ZN7QWidget16inputMethodEventEP17QInputMethodEvent
	fad68	 4539  _ZN7QWidget16setMaximumHeightEi
	fad8c	 4540  _ZN7QWidget16setMinimumHeightEi
	fadb0	 4543  _ZN7QWidget16staticMetaObjectE
	fadd4	 4545  _ZN7QWidget17mouseReleaseEventEP11QMouseEvent
	fae04	 4549  _ZN7QWidget17setGraphicsEffectEP15QGraphicsEffect
	fae38	 4556  _ZN7QWidget18focusNextPrevChildEb
	fae5c	 4570  _ZN7QWidget21mouseDoubleClickEventEP11QMouseEvent
	fae90	 4580  _ZN7QWidget4moveERK6QPoint
	faeb0	 4581  _ZN7QWidget4showEv
	faec8	 4582  _ZN7QWidget5closeEv
	faee0	 4583  _ZN7QWidget5eventEP6QEvent
	faf00	 4585  _ZN7QWidget5raiseEv
	faf18	 4589  _ZN7QWidget6resizeERK5QSize
	faf38	 4592  _ZN7QWidget6updateERK5QRect
	faf58	 4594  _ZN7QWidget6updateEv
	faf70	 4599  _ZN7QWidget7repaintEv
	faf88	 4600  _ZN7QWidget7setFontERK5QFont
	fafa8	 4603  _ZN7QWidget8setFocusEN2Qt11FocusReasonE
	fafd4	 4615  _ZN7QWidget9dropEventEP10QDropEvent
	faffc	 4617  _ZN7QWidget9grabMouseEv
	fb018	 4618  _ZN7QWidget9hideEventEP10QHideEvent
	fb040	 4619  _ZN7QWidget9moveEventEP10QMoveEvent
	fb068	 4620  _ZN7QWidget9setCursorERK7QCursor
	fb08c	 4627  _ZN7QWidget9showEventEP10QShowEvent
	fb0b4	 4628  _ZN7QWidgetC1EPS_6QFlagsIN2Qt10WindowTypeEE
	fb0e4	 4630  _ZN7QWidgetC2EPS_6QFlagsIN2Qt10WindowTypeEE
	fb114	 4634  _ZN7QWidgetD2Ev
	fb128	 4776  _ZN8QSpinBox12valueChangedEi
	fb148	 4778  _ZN8QSpinBox16staticMetaObjectE
	fb16c	 4783  _ZN8QSpinBox8setValueEi
	fb188	 4821  _ZN8QToolBar9addWidgetEP7QWidget
	fb1ac	 4852  _ZN8QToolTip10setPaletteERK8QPalette
	fb1d4	 4855  _ZN8QToolTip7paletteEv
	fb1f0	 4857  _ZN8QToolTip8showTextERK6QPointRK7QStringP7QWidgetRK5QRecti
	fb230	 4914  _ZN9QComboBox14setCurrentTextERK7QString
	fb25c	 4920  _ZN9QComboBox15setCurrentIndexEi
	fb280	 4926  _ZN9QComboBox16staticMetaObjectE
	fb2a4	 4929  _ZN9QComboBox18currentTextChangedERK7QString
	fb2d4	 4933  _ZN9QComboBox19currentIndexChangedEi
	fb2fc	 4969  _ZN9QGroupBox10setCheckedEb
	fb31c	 4979  _ZN9QGroupBox16staticMetaObjectE
	fb340	 4985  _ZN9QGroupBox7toggledEb
	fb35c	 5000  _ZN9QLineEdit11setEchoModeENS_8EchoModeE
	fb388	 5003  _ZN9QLineEdit11textChangedERK7QString
	fb3b0	 5031  _ZN9QLineEdit16staticMetaObjectE
	fb3d4	 5038  _ZN9QLineEdit18setPlaceholderTextERK7QString
	fb404	 5053  _ZN9QLineEdit7setTextERK7QString
	fb428	 5061  _ZN9QLineEditC1EP7QWidget
	fb444	 5496  _ZNK10QTabWidget7indexOfEPK7QWidget
	fb46c	 5737  _ZNK11QMessageBox13clickedButtonEv
	fb494	 5745  _ZNK11QMessageBox6buttonENS_14StandardButtonE
	fb4c4	 5804  _ZNK11QToolButton15initStyleOptionEP22QStyleOptionToolButton
	fb504	 5805  _ZNK11QToolButton15minimumSizeHintEv
	fb52c	 5808  _ZNK11QToolButton8sizeHintEv
	fb54c	 5811  _ZNK11QToolButton9hitButtonERK6QPoint
	fb574	 5874  _ZNK12QColorDialog13selectedColorEv
	fb59c	 5933  _ZNK12QInputDialog9textValueEv
	fb5c0	 6432  _ZNK15QAbstractButton4iconEv
	fb5e0	 6433  _ZNK15QAbstractButton4textEv
	fb600	 6436  _ZNK15QAbstractButton8iconSizeEv
	fb624	 6589  _ZNK16QDialogButtonBox6buttonENS_14StandardButtonE
	fb65c	 7226  _ZNK6QLabel4textEv
	fb674	 7244  _ZNK7QDialog15minimumSizeHintEv
	fb698	 7247  _ZNK7QDialog8sizeHintEv
	fb6b4	 7313  _ZNK7QWidget10redirectedEP6QPoint
	fb6d8	 7314  _ZNK7QWidget10sizePolicyEv
	fb6f8	 7321  _ZNK7QWidget11initPainterEP8QPainter
	fb720	 7326  _ZNK7QWidget11mapToGlobalERK6QPoint
	fb748	 7330  _ZNK7QWidget11maximumSizeEv
	fb768	 7331  _ZNK7QWidget11minimumSizeEv
	fb788	 7332  _ZNK7QWidget11paintEngineEv
	fb7a8	 7341  _ZNK7QWidget12windowHandleEv
	fb7c8	 7347  _ZNK7QWidget13sharedPainterEv
	fb7e8	 7352  _ZNK7QWidget14backgroundRoleEv
	fb80c	 7358  _ZNK7QWidget14heightForWidthEi
	fb830	 7366  _ZNK7QWidget15minimumSizeHintEv
	fb854	 7369  _ZNK7QWidget16inputMethodQueryEN2Qt16InputMethodQueryE
	fb890	 7373  _ZNK7QWidget17hasHeightForWidthEv
	fb8b4	 7377  _ZNK7QWidget1xEv
	fb8c8	 7378  _ZNK7QWidget1yEv
	fb8dc	 7392  _ZNK7QWidget6metricEN12QPaintDevice17PaintDeviceMetricE
	fb918	 7393  _ZNK7QWidget6screenEv
	fb930	 7394  _ZNK7QWidget6windowEv
	fb948	 7398  _ZNK7QWidget7devTypeEv
	fb964	 7401  _ZNK7QWidget7paletteEv
	fb980	 7405  _ZNK7QWidget8sizeHintEv
	fb99c	 7406  _ZNK7QWidget9frameSizeEv
	fb9b8	 7533  _ZNK9QComboBox8findDataERK8QVarianti6QFlagsIN2Qt9MatchFlagEE
	fb9f8	 7536  _ZNK9QComboBox8itemDataEii
	fba18	 7577  _ZNK9QLineEdit4textEv
	fba30	 7934  _ZTV11QSpacerItem
	fba44	 8384  _ZThn16_NK7QWidget10redirectedEP6QPoint
	fba70	 8385  _ZThn16_NK7QWidget11initPainterEP8QPainter
	fbaa0	 8386  _ZThn16_NK7QWidget11paintEngineEv
	fbac4	 8387  _ZThn16_NK7QWidget13sharedPainterEv
	fbaec	 8388  _ZThn16_NK7QWidget6metricEN12QPaintDevice17PaintDeviceMetricE
	fbb2c	 8389  _ZThn16_NK7QWidget7devTypeEv
	DLL Name: libqca-qt6.dll
	fbb4c	    1  _Z13qcaVersionStrv
	fbb64	   51  _ZN3QCA10PrivateKey11fromPEMFileERK7QStringRKNS_11SecureArrayEPNS_13ConvertResultES3_
	fbbbc	   52  _ZN3QCA10PrivateKey11signMessageERKNS_12MemoryRegionENS_18SignatureAlgorithmENS_15SignatureFormatE
	fbc24	   55  _ZN3QCA10PrivateKey7decryptERKNS_11SecureArrayEPS1_NS_19EncryptionAlgorithmE
	fbc74	   62  _ZN3QCA10PrivateKeyC1ERK7QStringRKNS_11SecureArrayE
	fbcac	   64  _ZN3QCA10PrivateKeyC1ERKS0_
	fbccc	   65  _ZN3QCA10PrivateKeyC1Ev
	fbce8	   71  _ZN3QCA10PrivateKeyD1Ev
	fbd04	   73  _ZN3QCA10PrivateKeyaSERKS0_
	fbd24	  176  _ZN3QCA11InitializerC1ENS_10MemoryModeEi
	fbd50	  178  _ZN3QCA11InitializerD1Ev
	fbd6c	  219  _ZN3QCA11SecureArrayC1ERK10QByteArray
	fbd94	  221  _ZN3QCA11SecureArrayC1ERKS0_
	fbdb4	  223  _ZN3QCA11SecureArrayC1Ev
	fbdd0	  230  _ZN3QCA11SecureArrayD1Ev
	fbdec	  233  _ZN3QCA11SecureArrayaSERKS0_
	fbe0c	  320  _ZN3QCA12MemoryRegionC1ERK10QByteArray
	fbe38	  333  _ZN3QCA12MemoryRegionD1Ev
	fbe54	  563  _ZN3QCA17supportedFeaturesEv
	fbe74	 1204  _ZN3QCA9PublicKey7encryptERKNS_11SecureArrayENS_19EncryptionAlgorithmE
	fbec0	 1206  _ZN3QCA9PublicKey7fromPEMERK7QStringPNS_13ConvertResultES3_
	fbf00	 1218  _ZN3QCA9PublicKeyD1Ev
	fbf18	 1257  _ZNK3QCA10PrivateKey7canSignEv
	fbf3c	 1319  _ZNK3QCA11SecureArray11toByteArrayEv
	fbf64	 1322  _ZNK3QCA11SecureArray4sizeEv
	fbf84	 1323  _ZNK3QCA11SecureArray7isEmptyEv
	fbfa8	 1324  _ZNK3QCA11SecureArray9constDataEv
	fbfcc	 1548  _ZNK3QCA4PKey11toPublicKeyEv
	fbfec	 1562  _ZNK3QCA4PKey6isNullEv
	fc008	 1566  _ZNK3QCA4PKey9isPrivateEv
	fc024	 1679  _ZNK3QCA9PublicKey10canEncryptEv
	DLL Name: libvncclient.dll
	fc048	   18  HandleRFBServerMessage
	fc064	   26  ReadFromRFBServer
	fc078	   33  SendClientCutText
	fc08c	   37  SendFramebufferUpdateRequest
	fc0ac	   38  SendIncrementalFramebufferUpdateRequest
	fc0d8	   39  SendKeyEvent
	fc0e8	   40  SendPointerEvent
	fc0fc	   47  SetFormatAndEncodings
	fc114	   58  WaitForMessage
	fc128	   59  WriteToRFBServer
	fc13c	   73  rfbClientCleanup
	fc150	   77  rfbClientErr
	fc160	   79  rfbClientGetClientData
	fc17c	   82  rfbClientLog
	fc18c	   83  rfbClientRegisterExtension
	fc1ac	   84  rfbClientSetClientData
	fc1c8	   89  rfbGetClient
	fc1d8	   91  rfbInitClient
```

### 4.3 Tabla de importación — veyon-service.exe

```text
	DLL Name: KERNEL32.dll
	93e8	  295  DeleteCriticalSection
	9400	  333  EnterCriticalSection
	9418	  568  GetCurrentProcess
	942c	  648  GetLastError
	943c	  670  GetModuleHandleA
	9450	  730  GetProcAddress
	9462	  918  InitializeCriticalSection
	947e	  954  IsProcessorFeaturePresent
	949a	 1012  LeaveCriticalSection
	94b2	 1019  LoadLibraryW
	94c2	 1433  SetUnhandledExceptionFilter
	94e0	 1449  Sleep
	94e8	 1465  TerminateProcess
	94fc	 1485  TlsGetValue
	950a	 1533  VirtualProtect
	951c	 1535  VirtualQuery
	952c	 1625  __C_specific_handler
	DLL Name: msvcrt.dll
	9544	  127  __getmainargs
	9554	  128  __initenv
	9560	  129  __iob_func
	956e	  160  __set_app_type
	9580	  162  __setusermatherr
	9594	  191  _amsg_exit
	95a2	  210  _cexit
	95ac	  224  _commode
	95b8	  300  _fmode
	95c2	  379  _initterm
	95ce	 1016  abort
	95d6	 1023  atexit
	95e0	 1033  calloc
	95ea	 1046  exit
	95f2	 1065  fprintf
	95fc	 1072  free
	9604	 1130  malloc
	960e	 1139  memcpy
	9618	 1169  signal
	9622	 1190  strlen
	962c	 1193  strncmp
	9636	 1224  vfprintf
	9642	 1333  _write
	DLL Name: libstdc++-6.dll
	964c	 5621  _ZTVN10__cxxabiv117__class_type_infoE
	DLL Name: Qt6Core.dll
	9674	  188  _ZN10QArrayData10deallocateEPS_xx
	9698	 1391  _ZN16QCoreApplicationC1ERiPPci
	96bc	 1395  _ZN16QCoreApplicationD1Ev
	96d8	 6606  qt_version_tag_6_10
	DLL Name: veyon-core.dll
	96f0	  501  _ZN19VeyonServiceControl4nameEv
	9714	  742  _ZN9VeyonCore26setupApplicationParametersEv
	9744	  749  _ZN9VeyonCore8instanceEv
	9760	  752  _ZN9VeyonCoreC1EP16QCoreApplicationNS_9ComponentERK7QString
	97a0	  755  _ZN9VeyonCoreD1Ev
```

### 4.4 Tabla de importación — veyon-server.exe

```text
	DLL Name: KERNEL32.dll
	244d8	  295  DeleteCriticalSection
	244f0	  333  EnterCriticalSection
	24508	  568  GetCurrentProcess
	2451c	  648  GetLastError
	2452c	  670  GetModuleHandleA
	24540	  730  GetProcAddress
	24552	  918  InitializeCriticalSection
	2456e	  954  IsProcessorFeaturePresent
	2458a	 1012  LeaveCriticalSection
	245a2	 1019  LoadLibraryW
	245b2	 1433  SetUnhandledExceptionFilter
	245d0	 1449  Sleep
	245d8	 1465  TerminateProcess
	245ec	 1485  TlsGetValue
	245fa	 1533  VirtualProtect
	2460c	 1535  VirtualQuery
	2461c	 1625  __C_specific_handler
	DLL Name: msvcrt.dll
	24634	  127  __getmainargs
	24644	  128  __initenv
	24650	  129  __iob_func
	2465e	  160  __set_app_type
	24670	  162  __setusermatherr
	24684	  191  _amsg_exit
	24692	  210  _cexit
	2469c	  224  _commode
	246a8	  300  _fmode
	246b2	  379  _initterm
	246be	 1016  abort
	246c6	 1023  atexit
	246d0	 1033  calloc
	246da	 1046  exit
	246e2	 1065  fprintf
	246ec	 1072  free
	246f4	 1130  malloc
	246fe	 1138  memcmp
	24708	 1139  memcpy
	24712	 1140  memmove
	2471c	 1169  signal
	24726	 1183  strcmp
	24730	 1190  strlen
	2473a	 1193  strncmp
	24744	 1224  vfprintf
	24750	 1333  _write
	DLL Name: libstdc++-6.dll
	2475c	 4837  _ZSt18_Rb_tree_decrementPSt18_Rb_tree_node_base
	24790	 4838  _ZSt18_Rb_tree_incrementPKSt18_Rb_tree_node_base
	247c4	 4839  _ZSt18_Rb_tree_incrementPSt18_Rb_tree_node_base
	247f8	 4871  _ZSt28_Rb_tree_rebalance_for_erasePSt18_Rb_tree_node_baseRS_
	24838	 4873  _ZSt29_Rb_tree_insert_and_rebalancebPSt18_Rb_tree_node_baseS0_RS_
	2487c	 5621  _ZTVN10__cxxabiv117__class_type_infoE
	248a4	 5625  _ZTVN10__cxxabiv120__si_class_type_infoE
	248d0	 5626  _ZTVN10__cxxabiv121__vmi_class_type_infoE
	248fc	 5868  _ZdaPv
	24908	 5872  _ZdaPvy
	24914	 5874  _ZdlPv
	24920	 5878  _ZdlPvy
	2492c	 5880  _Znay
	24934	 5884  _Znwy
	DLL Name: Qt6Core.dll
	2493c	   90  _Z26qt_QMetaEnum_debugOperatorR6QDebugxPK11QMetaObjectPKc
	24978	  120  _Z5qHash11QStringViewy
	24994	  188  _ZN10QArrayData10deallocateEPS_xx
	249b8	  189  _ZN10QArrayData19reallocateUnalignedEPS_PvxxNS_16AllocationOptionE
	24a00	  190  _ZN10QArrayData8allocateEPPS_xxxNS_16AllocationOptionE
	24a3c	  195  _ZN10QByteArray11reallocDataExN10QArrayData16AllocationOptionE
	24a80	  216  _ZN10QByteArray6_emptyE
	24a9c	  217  _ZN10QByteArray6appendERKS_
	24abc	  218  _ZN10QByteArray6appendEc
	24ad8	  221  _ZN10QByteArray6insertEx14QByteArrayView
	24b04	  230  _ZN10QByteArray6removeExx
	24b20	  231  _ZN10QByteArray6resizeEx
	24b3c	  242  _ZN10QByteArrayC1EPKcx
	24b58	  249  _ZN10QByteArrayaSERKS_
	24b74	  424  _ZN11QBasicMutex12lockInternalEv
	24b98	  428  _ZN11QBasicMutex15destroyInternalEPv
	24bc0	  429  _ZN11QBasicMutex19unlockInternalFutexEPv
	24bec	  474  _ZN11QDataStreamD1Ev
	24c04	  480  _ZN11QDataStreamlsEa
	24c1c	  484  _ZN11QDataStreamlsEi
	24c34	  492  _ZN11QDataStreamrsERb
	24c4c	  495  _ZN11QDataStreamrsERi
	24c64	  575  _ZN11QMetaObject10ConnectionD1Ev
	24c88	  592  _ZN11QMetaObject8activateEP7QObjectPKS_iPPv
	24cb8	  682  _ZN11QTextStreamlsEPKc
	24cd4	  685  _ZN11QTextStreamlsERK7QString
	24cf4	  686  _ZN11QTextStreamlsEc
	24d0c	  689  _ZN11QTextStreamlsEi
	24d24	  719  _ZN11QThreadPool14globalInstanceEv
	24d4c	  729  _ZN11QThreadPool5startEP9QRunnablei
	24d74	  855  _ZN13QElapsedTimer5startEv
	24d94	  856  _ZN13QElapsedTimer7restartEv
	24db4	 1288  _ZN15QtSharedPointer20ExternalRefCountData9getAndRefEPK7QObject
	24df8	 1382  _ZN16QCoreApplication4quitEv
	24e18	 1383  _ZN16QCoreApplication4selfE
	24e38	 1911  _ZN18QFutureWatcherBase11qt_metacallEN11QMetaObject4CallEiPPv
	24e78	 1912  _ZN18QFutureWatcherBase11qt_metacastEPKc
	24ea4	 1915  _ZN18QFutureWatcherBase13connectNotifyERK11QMetaMethod
	24ee0	 1920  _ZN18QFutureWatcherBase16disconnectNotifyERK11QMetaMethod
	24f1c	 1921  _ZN18QFutureWatcherBase16staticMetaObjectE
	24f4c	 1926  _ZN18QFutureWatcherBase22connectOutputInterfaceEv
	24f80	 1928  _ZN18QFutureWatcherBase25disconnectOutputInterfaceEb
	24fb8	 1929  _ZN18QFutureWatcherBase5eventEP6QEvent
	24fe4	 1938  _ZN18QFutureWatcherBase8finishedEv
	2500c	 1942  _ZN18QFutureWatcherBaseC2EP7QObject
	25034	 2349  _ZN20QFutureInterfaceBase11setRunnableEP9QRunnable
	2506c	 2352  _ZN20QFutureInterfaceBase13reportStartedEv
	2509c	 2354  _ZN20QFutureInterfaceBase13setThreadPoolEP11QThreadPool
	250d8	 2355  _ZN20QFutureInterfaceBase13waitForResultEi
	25108	 2358  _ZN20QFutureInterfaceBase14reportCanceledEv
	25138	 2359  _ZN20QFutureInterfaceBase14reportFinishedEv
	25168	 2363  _ZN20QFutureInterfaceBase15resultStoreBaseEv
	25198	 2374  _ZN20QFutureInterfaceBase18reportResultsReadyEii
	251cc	 2380  _ZN20QFutureInterfaceBase4swapERS_
	251f4	 2386  _ZN20QFutureInterfaceBaseC2ENS_5StateE
	25220	 2387  _ZN20QFutureInterfaceBaseC2ERKS_
	25244	 2390  _ZN20QFutureInterfaceBaseD2Ev
	25264	 3165  _ZN5QUuid10fromStringE14QAnyStringView
	25290	 3189  _ZN6QDebug9putStringEPK5QChary
	252b4	 3190  _ZN6QDebugD1Ev
	252c8	 3213  _ZN6QTimer13setSingleShotEb
	252e8	 3219  _ZN6QTimer16staticMetaObjectE
	25308	 3223  _ZN6QTimer4stopEv
	2531c	 3225  _ZN6QTimer5startEi
	25334	 3227  _ZN6QTimer7timeoutENS_14QPrivateSignalE
	25360	 3228  _ZN6QTimerC1EP7QObject
	2537c	 3231  _ZN6QTimerD1Ev
	25390	 3257  _ZN7QBufferD1Ev
	253a4	 3298  _ZN7QObject10childEventEP11QChildEvent
	253d0	 3299  _ZN7QObject10disconnectEPKS_PKcS1_S3_
	253f8	 3305  _ZN7QObject10timerEventEP11QTimerEvent
	25424	 3306  _ZN7QObject11connectImplEPKS_PPvS1_S3_PN9QtPrivate15QSlotObjectBaseEN2Qt14ConnectionTypeEPKiPK11QMetaObject
	25494	 3307  _ZN7QObject11customEventEP6QEvent
	254b8	 3308  _ZN7QObject11deleteLaterEv
	254d8	 3309  _ZN7QObject11eventFilterEPS_P6QEvent
	25500	 3310  _ZN7QObject11qt_metacallEN11QMetaObject4CallEiPPv
	25534	 3311  _ZN7QObject11qt_metacastEPKc
	25554	 3316  _ZN7QObject13connectNotifyERK11QMetaMethod
	25584	 3323  _ZN7QObject16disconnectNotifyERK11QMetaMethod
	255b4	 3324  _ZN7QObject16staticMetaObjectE
	255d8	 3330  _ZN7QObject5eventEP6QEvent
	255f8	 3339  _ZN7QObjectC2EPS_
	2560c	 3343  _ZN7QObjectD2Ev
	25620	 3348  _ZN7QString11reallocDataExN10QArrayData16AllocationOptionE
	25660	 3379  _ZN7QString6_emptyE
	25678	 3401  _ZN7QString6resizeEx
	25690	 3420  _ZN7QString8fromUtf8E14QByteArrayView
	256b8	 3434  _ZN7QStringaSERKS_
	256d0	 3435  _ZN7QThread11qt_metacallEN11QMetaObject4CallEiPPv
	25704	 3436  _ZN7QThread11qt_metacastEPKc
	25724	 3444  _ZN7QThread16staticMetaObjectE
	25748	 3456  _ZN7QThread5eventEP6QEvent
	25768	 3459  _ZN7QThread5startENS_8PriorityE
	2578c	 3463  _ZN7QThread8finishedENS_14QPrivateSignalE
	257b8	 3467  _ZN7QThreadC2EP7QObject
	257d4	 3471  _ZN7QThreadD2Ev
	257e8	 3616  _ZN8QVariantC1E9QMetaTypePKv
	25808	 3617  _ZN8QVariantC1ERK10QByteArray
	25828	 3641  _ZN8QVariantC1ERK7QString
	25844	 3703  _ZN8QVariantD1Ev
	25858	 3823  _ZN9QHashSeed10globalSeedEv
	25878	 3830  _ZN9QIODevice12bytesWrittenEx
	25898	 3837  _ZN9QIODevice16staticMetaObjectE
	258bc	 3849  _ZN9QIODevice4peekEPcx
	258d8	 3852  _ZN9QIODevice4readEx
	258f0	 3859  _ZN9QIODevice5writeERK10QByteArray
	25918	 3860  _ZN9QIODevice7getCharEPc
	25934	 3866  _ZN9QIODevice9readyReadEv
	25950	 3867  _ZN9QIODevice9ungetCharEc
	2596c	 3897  _ZN9QMetaType14registerHelperEPKN9QtPrivate18QMetaTypeInterfaceE
	259b0	 3903  _ZN9QMetaType25registerNormalizedTypedefERK10QByteArrayS_
	259ec	 3911  _ZN9QMetaType7convertES_PKvS_Pv
	25a10	 3961  _ZN9QRunnableD2Ev
	25a24	 4136  _ZN9QtPrivate12argToQStringE14QAnyStringViewyPPKNS_7ArgBaseE
	25a64	 4139  _ZN9QtPrivate12equalStringsE11QStringViewS0_
	25a94	 4159  _ZN9QtPrivate14compareStringsE11QStringViewS0_N2Qt15CaseSensitivityE
	25adc	 4173  _ZN9QtPrivate15ResultStoreBase9addResultEiPKv
	25b0c	 4242  _ZN9QtPrivate16QStringList_joinEPK5QListI7QStringEPK5QCharx
	25b4c	 4275  _ZN9QtPrivate20QStringList_containsEPK5QListI7QStringE11QStringViewN2Qt15CaseSensitivityE
	25ba8	 4357  _ZNK10QByteArray8toBase64E6QFlagsINS_12Base64OptionEE
	25be0	 4545  _ZNK11QMetaObject2trEPKcS1_i
	25c00	 4546  _ZNK11QMetaObject4castEPK7QObject
	25c24	 4552  _ZNK11QMetaObject9classNameEv
	25c44	 4553  _ZNK11QObjectData17dynamicMetaObjectEv
	25c70	 4653  _ZNK13QElapsedTimer10hasExpiredEx
	25c94	 4658  _ZNK13QElapsedTimer7elapsedEv
	25cb4	 4824  _ZNK14QMessageLogger4infoEv
	25cd4	 4830  _ZNK14QMessageLogger5debugEv
	25cf4	 4843  _ZNK14QMessageLogger7warningEv
	25d18	 4849  _ZNK14QMessageLogger8criticalEv
	25d3c	 5146  _ZNK18QFutureWatcherBase10metaObjectEv
	25d68	 5335  _ZNK20QFutureInterfaceBase10isCanceledEv
	25d94	 5337  _ZNK20QFutureInterfaceBase10queryStateENS_5StateE
	25dc8	 5343  _ZNK20QFutureInterfaceBase12hasExceptionEv
	25df8	 5352  _ZNK20QFutureInterfaceBase15resultStoreBaseEv
	25e28	 5353  _ZNK20QFutureInterfaceBase15runContinuationEv
	25e58	 5356  _ZNK20QFutureInterfaceBase4refTEv
	25e7c	 5357  _ZNK20QFutureInterfaceBase5mutexEv
	25ea4	 5358  _ZNK20QFutureInterfaceBase6derefTEv
	25ecc	 5686  _ZNK6QTimer8isActiveEv
	25ee8	 5843  _ZNK7QString8arg_implE14QAnyStringViewi5QChar
	25f18	 5845  _ZNK7QString8arg_implExii5QChar
	25f3c	 5899  _ZNK8QVariant11toByteArrayEv
	25f5c	 5939  _ZNK8QVariant8toStringEv
	25f78	 6227  _ZNK9QtPrivate15ResultStoreBase10filterModeEv
	25fa8	 6229  _ZNK9QtPrivate15ResultStoreBase23containsValidResultItemEi
	25fe8	 6232  _ZNK9QtPrivate15ResultStoreBase5countEv
	26014	 6234  _ZNK9QtPrivate15ResultStoreBase8resultAtEi
	26044	 6250  _ZNKR10QByteArray3midExx
	26060	 6403  _ZTV18QFutureWatcherBase
	2607c	 6503  _Zls6QDebugRK5QUuid
	26094	 6539  _ZlsR11QDataStreamRK5QUuid
	260b4	 6577  _ZrsR11QDataStreamR5QUuid
	260d0	 6606  qt_version_tag_6_10
	DLL Name: Qt6Gui.dll
	260e8	 1767  _ZN15QGuiApplication18setDesktopFileNameERK7QString
	26120	 1797  _ZN15QGuiApplicationC1ERiPPci
	26140	 1801  _ZN15QGuiApplicationD1Ev
	DLL Name: Qt6Network.dll
	2615c	  172  _ZN10QTcpServer11acceptErrorEN15QAbstractSocket11SocketErrorE
	2619c	  175  _ZN10QTcpServer13newConnectionEv
	261c0	  178  _ZN10QTcpServer16staticMetaObjectE
	261e8	  188  _ZN10QTcpServer5closeEv
	26204	  189  _ZN10QTcpServer6listenERK12QHostAddresst
	26230	  192  _ZN10QTcpServerC1EP7QObject
	26250	  203  _ZN10QTcpSocketC1EP7QObject
	26270	  316  _ZN12QHostAddressC1ENS_14SpecialAddressE
	2629c	  321  _ZN12QHostAddressC1ERKS_
	262b8	  332  _ZN12QHostAddressD1Ev
	262d0	  591  _ZN15QAbstractSocket12disconnectedEv
	262f8	  597  _ZN15QAbstractSocket13connectToHostERK12QHostAddresst6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	26358	  606  _ZN15QAbstractSocket16staticMetaObjectE
	26384	  618  _ZN15QAbstractSocket5abortEv
	263a4	 1604  _ZNK10QTcpServer11errorStringEv
	263c8	 1605  _ZNK10QTcpServer11isListeningEv
	263ec	 1671  _ZNK12QHostAddress8toStringEv
	2640c	 1790  _ZNK15QAbstractSocket11peerAddressEv
	26434	 2257  _Zls6QDebugN15QAbstractSocket11SocketErrorE
	DLL Name: libqca-qt6.dll
	26464	   55  _ZN3QCA10PrivateKey7decryptERKNS_11SecureArrayEPS1_NS_19EncryptionAlgorithmE
	264b4	   64  _ZN3QCA10PrivateKeyC1ERKS0_
	264d4	   65  _ZN3QCA10PrivateKeyC1Ev
	264f0	   71  _ZN3QCA10PrivateKeyD1Ev
	2650c	   73  _ZN3QCA10PrivateKeyaSERKS0_
	2652c	  219  _ZN3QCA11SecureArrayC1ERK10QByteArray
	26554	  221  _ZN3QCA11SecureArrayC1ERKS0_
	26574	  223  _ZN3QCA11SecureArrayC1Ev
	26590	  230  _ZN3QCA11SecureArrayD1Ev
	265ac	  233  _ZN3QCA11SecureArrayaSERKS0_
	265cc	  299  _ZN3QCA12KeyGenerator9createRSAEiiRK7QString
	265fc	  300  _ZN3QCA12KeyGeneratorC1EP7QObject
	26620	  303  _ZN3QCA12KeyGeneratorD1Ev
	2663c	  320  _ZN3QCA12MemoryRegionC1ERK10QByteArray
	26668	  333  _ZN3QCA12MemoryRegionD1Ev
	26684	 1200  _ZN3QCA9PublicKey13verifyMessageERKNS_12MemoryRegionERK10QByteArrayNS_18SignatureAlgorithmENS_15SignatureFormatE
	266f8	 1207  _ZN3QCA9PublicKeyC1ERK7QString
	2671c	 1218  _ZN3QCA9PublicKeyD1Ev
	26734	 1322  _ZNK3QCA11SecureArray4sizeEv
	26754	 1323  _ZNK3QCA11SecureArray7isEmptyEv
	26778	 1325  _ZNK3QCA11SecureArrayeqERKNS_12MemoryRegionE
	267a8	 1548  _ZNK3QCA4PKey11toPublicKeyEv
	267c8	 1562  _ZNK3QCA4PKey6isNullEv
	267e4	 1564  _ZNK3QCA4PKey8isPublicEv
	26800	 1684  _ZNK3QCA9PublicKey5toPEMEv
	DLL Name: veyon-core.dll
	26820	    0  _ZN10CryptoCore17generateChallengeEv
	26848	   62  _ZN11HostAddress9localFQDNEv
	26868	   64  _ZN11HostAddressC1ERK7QString
	26888	   66  _ZN12RfbVeyonAuth16staticMetaObjectE
	268b0	  290  _ZN14FeatureMessage17isReadyForReceiveEP9QIODevice
	268e8	  291  _ZN14FeatureMessage7receiveEP9QIODevice
	26914	  348  _ZN14SystemTrayIcon10setToolTipERK7QStringR20FeatureWorkerManager
	26958	  353  _ZN14SystemTrayIcon11showMessageERK7QStringS2_R20FeatureWorkerManager
	269a0	  383  _ZN15VncServerClient16staticMetaObjectE
	269cc	  385  _ZN15VncServerClient21accessControlFinishedEPS_
	26a00	  415  _ZN17VncClientProtocol14receiveMessageEv
	26a2c	  416  _ZN17VncClientProtocol14setPixelFormatE14rfbPixelFormat
	26a68	  437  _ZN17VncClientProtocol4readEv
	26a88	  439  _ZN17VncClientProtocol5startEv
	26aac	  440  _ZN17VncClientProtocolC1EP9QIODeviceRKN3QCA11SecureArrayE
	26ae8	  453  _ZN17VncServerProtocol4readEv
	26b08	  454  _ZN17VncServerProtocol5startEv
	26b2c	  457  _ZN17VncServerProtocolC2EP10QTcpSocketP15VncServerClient
	26b68	  473  _ZN19DesktopAccessDialog16staticMetaObjectE
	26b98	  478  _ZN19DesktopAccessDialog4execEP20FeatureWorkerManagerRK7QStringS4_
	26be0	  480  _ZN19DesktopAccessDialog8finishedEv
	26c08	  489  _ZN19VariantArrayMessage4readEv
	26c2c	  490  _ZN19VariantArrayMessage4sendEv
	26c50	  491  _ZN19VariantArrayMessage5writeERK8QVariant
	26c80	  493  _ZN19VariantArrayMessageC1EP9QIODevice
	26cac	  529  _ZN20FeatureWorkerManagerC1ER20VeyonServerInterfaceP7QObject
	26cec	  532  _ZN20FeatureWorkerManagerD1Ev
	26d0c	  539  _ZN20VeyonServerInterface11qt_metacallEN11QMetaObject4CallEiPPv
	26d50	  540  _ZN20VeyonServerInterface11qt_metacastEPKc
	26d80	  541  _ZN20VeyonServerInterface16staticMetaObjectE
	26db0	  543  _ZN21AccessControlProvider11checkAccessERK7QStringS2_RK5QListIS0_E
	26df8	  716  _ZN9VeyonCore11isDebuggingEv
	26e18	  723  _ZN9VeyonCore13versionStringEv
	26e3c	  727  _ZN9VeyonCore15shortenFuncinfoERK10QByteArray
	26e6c	  729  _ZN9VeyonCore16staticMetaObjectE
	26e90	  742  _ZN9VeyonCore26setupApplicationParametersEv
	26ec0	  743  _ZN9VeyonCore28isAuthenticationKeyNameValidERK7QString
	26efc	  746  _ZN9VeyonCore4execEv
	26f14	  749  _ZN9VeyonCore8instanceEv
	26f30	  752  _ZN9VeyonCoreC1EP16QCoreApplicationNS_9ComponentERK7QString
	26f70	  755  _ZN9VeyonCoreD1Ev
	26f84	  762  _ZNK10Filesystem13publicKeyPathERK7QString
	26fb4	  779  _ZNK11HostAddress10tryConvertENS_4TypeE
	26fe0	  796  _ZNK13Configuration8Property12variantValueEv
	27010	  798  _ZNK13Configuration8Property15setVariantValueERK8QVariant
	2704c	  825  _ZNK14FeatureManager20handleFeatureMessageER20VeyonServerInterfaceRK14MessageContextRK14FeatureMessage
	270b8	  827  _ZNK14FeatureManager24sendAsyncFeatureMessagesER20VeyonServerInterfaceRK14MessageContext
	27114	  832  _ZNK14FeatureMessage16sendAsRfbMessageEP9QIODevice
	2714c	  850  _ZNK17VncServerProtocol5stateEv
	27170	  854  _ZNK19DesktopAccessDialog6isBusyEP20FeatureWorkerManager
	271ac	  873  _ZNK21AccessControlProvider29isAccessToLocalComputerDeniedEv
	271ec	  893  _ZNK25AuthenticationCredentials14hasCredentialsENS_4TypeE
	27228	  961  _ZTV15VncServerClient
	27240	  964  _ZTV17VncServerProtocol
	2725c	  973  _ZTV20VeyonServerInterface
	2727c	 1061  _Zls6QDebugRK14FeatureMessage
```

### 4.5 Tabla de importación — veyon-worker.exe

```text
	DLL Name: KERNEL32.dll
	fa88	  295  DeleteCriticalSection
	faa0	  333  EnterCriticalSection
	fab8	  568  GetCurrentProcess
	facc	  648  GetLastError
	fadc	  670  GetModuleHandleA
	faf0	  730  GetProcAddress
	fb02	  918  InitializeCriticalSection
	fb1e	  954  IsProcessorFeaturePresent
	fb3a	 1012  LeaveCriticalSection
	fb52	 1019  LoadLibraryW
	fb62	 1433  SetUnhandledExceptionFilter
	fb80	 1449  Sleep
	fb88	 1465  TerminateProcess
	fb9c	 1485  TlsGetValue
	fbaa	 1533  VirtualProtect
	fbbc	 1535  VirtualQuery
	fbcc	 1625  __C_specific_handler
	DLL Name: msvcrt.dll
	fbe4	  127  __getmainargs
	fbf4	  128  __initenv
	fc00	  129  __iob_func
	fc0e	  160  __set_app_type
	fc20	  162  __setusermatherr
	fc34	  191  _amsg_exit
	fc42	  210  _cexit
	fc4c	  224  _commode
	fc58	  300  _fmode
	fc62	  379  _initterm
	fc6e	 1016  abort
	fc76	 1023  atexit
	fc80	 1033  calloc
	fc8a	 1046  exit
	fc92	 1065  fprintf
	fc9c	 1072  free
	fca4	 1130  malloc
	fcae	 1139  memcpy
	fcb8	 1140  memmove
	fcc2	 1169  signal
	fccc	 1183  strcmp
	fcd6	 1190  strlen
	fce0	 1193  strncmp
	fcea	 1224  vfprintf
	fcf6	 1333  _write
	DLL Name: libstdc++-6.dll
	fd00	 4837  _ZSt18_Rb_tree_decrementPSt18_Rb_tree_node_base
	fd34	 4873  _ZSt29_Rb_tree_insert_and_rebalancebPSt18_Rb_tree_node_baseS0_RS_
	fd78	 5621  _ZTVN10__cxxabiv117__class_type_infoE
	fda0	 5625  _ZTVN10__cxxabiv120__si_class_type_infoE
	fdcc	 5626  _ZTVN10__cxxabiv121__vmi_class_type_infoE
	fdf8	 5878  _ZdlPvy
	fe04	 5884  _Znwy
	DLL Name: Qt6Core.dll
	fe0c	  188  _ZN10QArrayData10deallocateEPS_xx
	fe30	  189  _ZN10QArrayData19reallocateUnalignedEPS_PvxxNS_16AllocationOptionE
	fe78	  190  _ZN10QArrayData8allocateEPPS_xxxNS_16AllocationOptionE
	feb4	  216  _ZN10QByteArray6_emptyE
	fed0	  242  _ZN10QByteArrayC1EPKcx
	feec	  249  _ZN10QByteArrayaSERKS_
	ff08	  447  _ZN11QDataStream11resetStatusEv
	ff2c	  465  _ZN11QDataStream9setStatusENS_6StatusE
	ff58	  484  _ZN11QDataStreamlsEi
	ff70	  486  _ZN11QDataStreamlsEx
	ff88	  495  _ZN11QDataStreamrsERi
	ffa0	  497  _ZN11QDataStreamrsERx
	ffb8	  575  _ZN11QMetaObject10ConnectionD1Ev
	ffdc	  685  _ZN11QTextStreamlsERK7QString
	fffc	  686  _ZN11QTextStreamlsEc
	10014	  689  _ZN11QTextStreamlsEi
	1002c	 1381  _ZN16QCoreApplication4exitEi
	1004c	 1383  _ZN16QCoreApplication4selfE
	1006c	 1386  _ZN16QCoreApplication9argumentsEv
	10090	 1397  _ZN16QDebugStateSaverC1ER6QDebug
	100b4	 1399  _ZN16QDebugStateSaverD1Ev
	100d0	 3165  _ZN5QUuid10fromStringE14QAnyStringView
	100fc	 3189  _ZN6QDebug9putStringEPK5QChary
	10120	 3190  _ZN6QDebugD1Ev
	10134	 3219  _ZN6QTimer16staticMetaObjectE
	10154	 3223  _ZN6QTimer4stopEv
	10168	 3225  _ZN6QTimer5startEi
	10180	 3227  _ZN6QTimer7timeoutENS_14QPrivateSignalE
	101ac	 3228  _ZN6QTimerC1EP7QObject
	101c8	 3231  _ZN6QTimerD1Ev
	101dc	 3298  _ZN7QObject10childEventEP11QChildEvent
	10208	 3305  _ZN7QObject10timerEventEP11QTimerEvent
	10234	 3306  _ZN7QObject11connectImplEPKS_PPvS1_S3_PN9QtPrivate15QSlotObjectBaseEN2Qt14ConnectionTypeEPKiPK11QMetaObject
	102a4	 3307  _ZN7QObject11customEventEP6QEvent
	102c8	 3308  _ZN7QObject11deleteLaterEv
	102e8	 3309  _ZN7QObject11eventFilterEPS_P6QEvent
	10310	 3310  _ZN7QObject11qt_metacallEN11QMetaObject4CallEiPPv
	10344	 3311  _ZN7QObject11qt_metacastEPKc
	10364	 3316  _ZN7QObject13connectNotifyERK11QMetaMethod
	10394	 3323  _ZN7QObject16disconnectNotifyERK11QMetaMethod
	103c4	 3324  _ZN7QObject16staticMetaObjectE
	103e8	 3330  _ZN7QObject5eventEP6QEvent
	10408	 3339  _ZN7QObjectC2EPS_
	1041c	 3343  _ZN7QObjectD2Ev
	10430	 3355  _ZN7QString13toUtf8_helperERKS_
	10454	 3379  _ZN7QString6_emptyE
	1046c	 3391  _ZN7QString6numberEii
	10484	 3420  _ZN7QString8fromUtf8E14QByteArrayView
	104ac	 3427  _ZN7QStringC1ExN2Qt14InitializationE
	104d4	 3617  _ZN8QVariantC1ERK10QByteArray
	104f4	 3644  _ZN8QVariantC1ERKS_
	1050c	 3703  _ZN8QVariantD1Ev
	10520	 3705  _ZN8QVariantaSERKS_
	10538	 3837  _ZN9QIODevice16staticMetaObjectE
	1055c	 3866  _ZN9QIODevice9readyReadEv
	10578	 3897  _ZN9QMetaType14registerHelperEPKN9QtPrivate18QMetaTypeInterfaceE
	105bc	 3911  _ZN9QMetaType7convertES_PKvS_Pv
	105e0	 4139  _ZN9QtPrivate12equalStringsE11QStringViewS0_
	10610	 4159  _ZN9QtPrivate14compareStringsE11QStringViewS0_N2Qt15CaseSensitivityE
	10658	 4275  _ZN9QtPrivate20QStringList_containsEPK5QListI7QStringE11QStringViewN2Qt15CaseSensitivityE
	106b4	 4441  _ZNK11QDataStream26isDeviceTransactionStartedEv
	106e8	 4553  _ZNK11QObjectData17dynamicMetaObjectEv
	10714	 4824  _ZNK14QMessageLogger4infoEv
	10734	 4830  _ZNK14QMessageLogger5debugEv
	10754	 4833  _ZNK14QMessageLogger5fatalEPKcz
	10778	 4849  _ZNK14QMessageLogger8criticalEv
	1079c	 5662  _ZNK5QUuid8toStringENS_12StringFormatE
	107c8	 6503  _Zls6QDebugRK5QUuid
	107e0	 6546  _ZlsR11QDataStreamRK7QString
	10800	 6584  _ZrsR11QDataStreamR7QString
	10820	 6606  qt_version_tag_6_10
	DLL Name: Qt6Gui.dll
	10838	 1749  _ZN15QGuiApplication13setWindowIconERK5QIcon
	10868	 4364  _ZN5QIconC1ERK7QString
	10884	 4372  _ZN5QIconD1Ev
	DLL Name: Qt6Network.dll
	10894	  203  _ZN10QTcpSocketC1EP7QObject
	108b4	  209  _ZN10QTcpSocketD1Ev
	108cc	  316  _ZN12QHostAddressC1ENS_14SpecialAddressE
	108f8	  332  _ZN12QHostAddressD1Ev
	10910	  591  _ZN15QAbstractSocket12disconnectedEv
	10938	  597  _ZN15QAbstractSocket13connectToHostERK12QHostAddresst6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	10998	  606  _ZN15QAbstractSocket16staticMetaObjectE
	109c4	  625  _ZN15QAbstractSocket9connectedEv
	109e8	 1800  _ZNK15QAbstractSocket5stateEv
	DLL Name: Qt6Widgets.dll
	10a08	 1048  _ZN12QApplicationC1ERiPPci
	10a28	 1051  _ZN12QApplicationD1Ev
	DLL Name: veyon-core.dll
	10a40	  290  _ZN14FeatureMessage17isReadyForReceiveEP9QIODevice
	10a78	  291  _ZN14FeatureMessage7receiveEP9QIODevice
	10aa4	  485  _ZN19StandardInputReader16staticMetaObjectE
	10ad4	  487  _ZN19StandardInputReader8lineReadERK7QString
	10b04	  716  _ZN9VeyonCore11isDebuggingEv
	10b24	  727  _ZN9VeyonCore15shortenFuncinfoERK10QByteArray
	10b54	  742  _ZN9VeyonCore26setupApplicationParametersEv
	10b84	  746  _ZN9VeyonCore4execEv
	10b9c	  749  _ZN9VeyonCore8instanceEv
	10bb8	  752  _ZN9VeyonCoreC1EP16QCoreApplicationNS_9ComponentERK7QString
	10bf8	  755  _ZN9VeyonCoreD1Ev
	10c0c	  796  _ZNK13Configuration8Property12variantValueEv
	10c3c	  826  _ZNK14FeatureManager20handleFeatureMessageER20VeyonWorkerInterfaceRK14FeatureMessage
	10c94	  833  _ZNK14FeatureMessage9sendPlainEP9QIODevice
	10cc4	 1061  _Zls6QDebugRK14FeatureMessage
```

### 4.6 Tabla de importación — veyon-configurator.exe

```text
	DLL Name: KERNEL32.dll
	45400	  295  DeleteCriticalSection
	45418	  333  EnterCriticalSection
	45430	  568  GetCurrentProcess
	45444	  648  GetLastError
	45454	  670  GetModuleHandleA
	45468	  730  GetProcAddress
	4547a	  918  InitializeCriticalSection
	45496	  954  IsProcessorFeaturePresent
	454b2	 1012  LeaveCriticalSection
	454ca	 1019  LoadLibraryW
	454da	 1433  SetUnhandledExceptionFilter
	454f8	 1449  Sleep
	45500	 1465  TerminateProcess
	45514	 1485  TlsGetValue
	45522	 1533  VirtualProtect
	45534	 1535  VirtualQuery
	45544	 1625  __C_specific_handler
	DLL Name: msvcrt.dll
	4555c	  127  __getmainargs
	4556c	  128  __initenv
	45578	  129  __iob_func
	45586	  160  __set_app_type
	45598	  162  __setusermatherr
	455ac	  191  _amsg_exit
	455ba	  210  _cexit
	455c4	  224  _commode
	455d0	  300  _fmode
	455da	  379  _initterm
	455e6	 1016  abort
	455ee	 1023  atexit
	455f8	 1033  calloc
	45602	 1046  exit
	4560a	 1065  fprintf
	45614	 1072  free
	4561c	 1130  malloc
	45626	 1137  memchr
	45630	 1138  memcmp
	4563a	 1139  memcpy
	45644	 1140  memmove
	4564e	 1169  signal
	45658	 1183  strcmp
	45662	 1190  strlen
	4566c	 1193  strncmp
	45676	 1224  vfprintf
	45682	 1333  _write
	DLL Name: libstdc++-6.dll
	4568c	 4837  _ZSt18_Rb_tree_decrementPSt18_Rb_tree_node_base
	456c0	 4838  _ZSt18_Rb_tree_incrementPKSt18_Rb_tree_node_base
	456f4	 4839  _ZSt18_Rb_tree_incrementPSt18_Rb_tree_node_base
	45728	 4873  _ZSt29_Rb_tree_insert_and_rebalancebPSt18_Rb_tree_node_baseS0_RS_
	4576c	 5621  _ZTVN10__cxxabiv117__class_type_infoE
	45794	 5625  _ZTVN10__cxxabiv120__si_class_type_infoE
	457c0	 5626  _ZTVN10__cxxabiv121__vmi_class_type_infoE
	457ec	 5874  _ZdlPv
	457f8	 5878  _ZdlPvy
	45804	 5884  _Znwy
	DLL Name: Qt6Core.dll
	4580c	   15  _Z13comparesEqualRK10QJsonArrayS1_
	45834	   77  _Z21qRegisterResourceDataiPKhS0_S0_
	4585c	   81  _Z23qUnregisterResourceDataiPKhS0_S0_
	45884	   82  _Z23qt_qFindChildren_helperPK7QObject14QAnyStringViewRK11QMetaObjectP5QListIPvE6QFlagsIN2Qt15FindChildOptionEE
	458f8	   90  _Z26qt_QMetaEnum_debugOperatorR6QDebugxPK11QMetaObjectPKc
	45934	   94  _Z28qEnvironmentVariableIntValuePKcPb
	4595c	  188  _ZN10QArrayData10deallocateEPS_xx
	45980	  189  _ZN10QArrayData19reallocateUnalignedEPS_PvxxNS_16AllocationOptionE
	459c8	  190  _ZN10QArrayData8allocateEPPS_xxxNS_16AllocationOptionE
	45a04	  195  _ZN10QByteArray11reallocDataExN10QArrayData16AllocationOptionE
	45a48	  216  _ZN10QByteArray6_emptyE
	45a64	  218  _ZN10QByteArray6appendEc
	45a80	  221  _ZN10QByteArray6insertEx14QByteArrayView
	45aac	  242  _ZN10QByteArrayC1EPKcx
	45ac8	  332  _ZN10QJsonArray6appendERK10QJsonValue
	45af0	  337  _ZN10QJsonArray7replaceExRK10QJsonValue
	45b1c	  338  _ZN10QJsonArray8removeAtEx
	45b3c	  339  _ZN10QJsonArrayC1EOS_
	45b54	  341  _ZN10QJsonArrayC1ERKS_
	45b70	  343  _ZN10QJsonArrayC1Ev
	45b88	  349  _ZN10QJsonArrayD1Ev
	45ba0	  352  _ZN10QJsonArrayixEx
	45bb8	  359  _ZN10QJsonValueC1EO11QJsonObject
	45bdc	  382  _ZN10QJsonValueD1Ev
	45bf4	  447  _ZN11QDataStream11resetStatusEv
	45c18	  465  _ZN11QDataStream9setStatusENS_6StatusE
	45c44	  480  _ZN11QDataStreamlsEa
	45c5c	  484  _ZN11QDataStreamlsEi
	45c74	  486  _ZN11QDataStreamlsEx
	45c8c	  492  _ZN11QDataStreamrsERb
	45ca4	  495  _ZN11QDataStreamrsERi
	45cbc	  497  _ZN11QDataStreamrsERx
	45cd4	  560  _ZN11QJsonObjectD1Ev
	45cec	  575  _ZN11QMetaObject10ConnectionD1Ev
	45d10	  589  _ZN11QMetaObject18connectSlotsByNameEP7QObject
	45d44	  682  _ZN11QTextStreamlsEPKc
	45d60	  685  _ZN11QTextStreamlsERK7QString
	45d80	  686  _ZN11QTextStreamlsEc
	45d98	  923  _ZN13QJsonValueRefaSERK10QJsonValue
	45dc0	  924  _ZN13QJsonValueRefaSERKS_
	45ddc	 1368  _ZN16QCoreApplication19applicationFilePathEv
	45e0c	 1383  _ZN16QCoreApplication4selfE
	45e2c	 1386  _ZN16QCoreApplication9argumentsEv
	45e50	 1389  _ZN16QCoreApplication9translateEPKcS1_S1_i
	45e80	 1397  _ZN16QDebugStateSaverC1ER6QDebug
	45ea4	 1399  _ZN16QDebugStateSaverD1Ev
	45ec0	 1756  _ZN18QAbstractItemModel10insertRowsEiiRK11QModelIndex
	45ef8	 1758  _ZN18QAbstractItemModel10removeRowsEiiRK11QModelIndex
	45f30	 1761  _ZN18QAbstractItemModel11moveColumnsERK11QModelIndexiiS2_i
	45f70	 1765  _ZN18QAbstractItemModel11setItemDataERK11QModelIndexRK4QMapIi8QVariantE
	45fbc	 1770  _ZN18QAbstractItemModel13clearItemDataERK11QModelIndex
	45ff8	 1773  _ZN18QAbstractItemModel13endResetModelEv
	46024	 1774  _ZN18QAbstractItemModel13insertColumnsEiiRK11QModelIndex
	46060	 1776  _ZN18QAbstractItemModel13removeColumnsEiiRK11QModelIndex
	4609c	 1777  _ZN18QAbstractItemModel13setHeaderDataEiN2Qt11OrientationERK8QVarianti
	460e8	 1782  _ZN18QAbstractItemModel15beginResetModelEv
	46118	 1789  _ZN18QAbstractItemModel17resetInternalDataEv
	46148	 1803  _ZN18QAbstractItemModel4sortEiN2Qt9SortOrderE
	46178	 1804  _ZN18QAbstractItemModel6revertEv
	4619c	 1805  _ZN18QAbstractItemModel6submitEv
	461c0	 1806  _ZN18QAbstractItemModel7setDataERK11QModelIndexRK8QVarianti
	46200	 1807  _ZN18QAbstractItemModel8moveRowsERK11QModelIndexiiS2_i
	4623c	 1808  _ZN18QAbstractItemModel9fetchMoreERK11QModelIndex
	46270	 1817  _ZN18QAbstractListModel11qt_metacallEN11QMetaObject4CallEiPPv
	462b0	 1818  _ZN18QAbstractListModel11qt_metacastEPKc
	462dc	 1819  _ZN18QAbstractListModel12dropMimeDataEPK9QMimeDataN2Qt10DropActionEiiRK11QModelIndex
	46334	 1820  _ZN18QAbstractListModel16staticMetaObjectE
	46364	 1824  _ZN18QAbstractListModelC2EP7QObject
	4638c	 1828  _ZN18QAbstractListModelD2Ev
	463ac	 1959  _ZN18QJsonValueConstRef8concreteES_
	463d4	 3007  _ZN4QDir6removeERK7QString
	463f4	 3010  _ZN4QDir8homePathEv
	4640c	 3016  _ZN4QDirC1ERK7QString
	46424	 3023  _ZN4QDirD1Ev
	46434	 3165  _ZN5QUuid10fromStringE14QAnyStringView
	46460	 3189  _ZN6QDebug9putStringEPK5QChary
	46484	 3190  _ZN6QDebugD1Ev
	46498	 3215  _ZN6QTimer14singleShotImplENSt6chrono8durationIxSt5ratioILx1ELx1000000000EEEEN2Qt9TimerTypeEPK7QObjectPN9QtPrivate15QSlotObjectBaseE
	46520	 3219  _ZN6QTimer16staticMetaObjectE
	46540	 3225  _ZN6QTimer5startEi
	46558	 3227  _ZN6QTimer7timeoutENS_14QPrivateSignalE
	46584	 3228  _ZN6QTimerC1EP7QObject
	465a0	 3274  _ZN7QLocale16languageToStringENS_8LanguageE
	465d0	 3281  _ZN7QLocaleC1E11QStringView
	465f0	 3282  _ZN7QLocaleC1ENS_8LanguageENS_6ScriptENS_7CountryE
	46628	 3295  _ZN7QLocaleD1Ev
	4663c	 3298  _ZN7QObject10childEventEP11QChildEvent
	46668	 3305  _ZN7QObject10timerEventEP11QTimerEvent
	46694	 3306  _ZN7QObject11connectImplEPKS_PPvS1_S3_PN9QtPrivate15QSlotObjectBaseEN2Qt14ConnectionTypeEPKiPK11QMetaObject
	46704	 3307  _ZN7QObject11customEventEP6QEvent
	46728	 3309  _ZN7QObject11eventFilterEPS_P6QEvent
	46750	 3316  _ZN7QObject13connectNotifyERK11QMetaMethod
	46780	 3319  _ZN7QObject13setObjectNameE14QAnyStringView
	467b0	 3323  _ZN7QObject16disconnectNotifyERK11QMetaMethod
	467e0	 3330  _ZN7QObject5eventEP6QEvent
	46800	 3331  _ZN7QObject7connectEPKS_PKcS1_S3_N2Qt14ConnectionTypeE
	4683c	 3343  _ZN7QObjectD2Ev
	46850	 3355  _ZN7QString13toUtf8_helperERKS_
	46874	 3379  _ZN7QString6_emptyE
	4688c	 3384  _ZN7QString6appendERKS_
	468a8	 3420  _ZN7QString8fromUtf8E14QByteArrayView
	468d0	 3434  _ZN7QStringaSERKS_
	468e8	 3610  _ZN8QVariantC1E5QUuid
	46900	 3616  _ZN8QVariantC1E9QMetaTypePKv
	46920	 3641  _ZN8QVariantC1ERK7QString
	4693c	 3649  _ZN8QVariantC1Ei
	46950	 3703  _ZN8QVariantD1Ev
	46964	 3897  _ZN9QMetaType14registerHelperEPKN9QtPrivate18QMetaTypeInterfaceE
	469a8	 3903  _ZN9QMetaType25registerNormalizedTypedefERK10QByteArrayS_
	469e4	 3911  _ZN9QMetaType7convertES_PKvS_Pv
	46a08	 4136  _ZN9QtPrivate12argToQStringE14QAnyStringViewyPPKNS_7ArgBaseE
	46a48	 4137  _ZN9QtPrivate12equalStringsE11QStringView13QLatin1String
	46a84	 4139  _ZN9QtPrivate12equalStringsE11QStringViewS0_
	46ab4	 4159  _ZN9QtPrivate14compareStringsE11QStringViewS0_N2Qt15CaseSensitivityE
	46afc	 4242  _ZN9QtPrivate16QStringList_joinEPK5QListI7QStringEPK5QCharx
	46b3c	 4275  _ZN9QtPrivate20QStringList_containsEPK5QListI7QStringE11QStringViewN2Qt15CaseSensitivityE
	46b98	 4396  _ZNK10QJsonArray4sizeEv
	46bb4	 4441  _ZNK11QDataStream26isDeviceTransactionStartedEv
	46be8	 4545  _ZNK11QMetaObject2trEPKcS1_i
	46c08	 4552  _ZNK11QMetaObject9classNameEv
	46c28	 4553  _ZNK11QObjectData17dynamicMetaObjectEv
	46c54	 4695  _ZNK13QJsonValueRef7toValueEv
	46c74	 4833  _ZNK14QMessageLogger5fatalEPKcz
	46c98	 4849  _ZNK14QMessageLogger8criticalEv
	46cbc	 5092  _ZNK18QAbstractItemModel10headerDataEiN2Qt11OrientationEi
	46cf8	 5095  _ZNK18QAbstractItemModel12canFetchMoreERK11QModelIndex
	46d34	 5096  _ZNK18QAbstractItemModel15canDropMimeDataEPK9QMimeDataN2Qt10DropActionEiiRK11QModelIndex
	46d90	 5098  _ZNK18QAbstractItemModel20supportedDragActionsEv
	46dc4	 5099  _ZNK18QAbstractItemModel20supportedDropActionsEv
	46df8	 5100  _ZNK18QAbstractItemModel4spanERK11QModelIndex
	46e28	 5101  _ZNK18QAbstractItemModel5buddyERK11QModelIndex
	46e5c	 5103  _ZNK18QAbstractItemModel5matchERK11QModelIndexiRK8QVarianti6QFlagsIN2Qt9MatchFlagEE
	46eb4	 5106  _ZNK18QAbstractItemModel8itemDataERK11QModelIndex
	46ee8	 5107  _ZNK18QAbstractItemModel8mimeDataERK5QListI11QModelIndexE
	46f24	 5108  _ZNK18QAbstractItemModel9mimeTypesEv
	46f4c	 5109  _ZNK18QAbstractItemModel9multiDataERK11QModelIndex18QModelRoleDataSpan
	46f98	 5110  _ZNK18QAbstractItemModel9roleNamesEv
	46fc0	 5112  _ZNK18QAbstractListModel11columnCountERK11QModelIndex
	46ff8	 5113  _ZNK18QAbstractListModel11hasChildrenERK11QModelIndex
	47030	 5114  _ZNK18QAbstractListModel5flagsERK11QModelIndex
	47064	 5115  _ZNK18QAbstractListModel5indexEiiRK11QModelIndex
	47098	 5116  _ZNK18QAbstractListModel6parentERK11QModelIndex
	470cc	 5117  _ZNK18QAbstractListModel7siblingEiiRK11QModelIndex
	47104	 5566  _ZNK4QDir9entryListERK5QListI7QStringE6QFlagsINS_6FilterEES5_INS_8SortFlagEE
	47154	 5662  _ZNK5QUuid8toStringENS_12StringFormatE
	47180	 5727  _ZNK7QLocale18nativeLanguageNameEv
	471a8	 5731  _ZNK7QLocale4nameENS_12TagSeparatorE
	471d0	 5758  _ZNK7QLocale8languageEv
	471ec	 5786  _ZNK7QObject10objectNameEv
	4720c	 5797  _ZNK7QString10startsWithE13QLatin1StringN2Qt15CaseSensitivityE
	47250	 5827  _ZNK7QString5splitE5QChar6QFlagsIN2Qt18SplitBehaviorFlagsEENS2_15CaseSensitivityE
	472a4	 5843  _ZNK7QString8arg_implE14QAnyStringViewi5QChar
	472d4	 5850  _ZNK7QString8endsWithERKS_N2Qt15CaseSensitivityE
	47308	 5928  _ZNK8QVariant6toUuidEv
	47324	 5939  _ZNK8QVariant8toStringEv
	47340	 6482  _Zls6QDebugRK10QJsonArray
	4735c	 6527  _ZlsR11QDataStreamRK10QJsonArray
	47380	 6546  _ZlsR11QDataStreamRK7QString
	473a0	 6561  _ZrsR11QDataStreamR10QJsonArray
	473c4	 6584  _ZrsR11QDataStreamR7QString
	473e4	 6606  qt_version_tag_6_10
	DLL Name: Qt6Gui.dll
	473fc	  875  _ZN12QActionGroup12setExclusiveEb
	47420	  878  _ZN12QActionGroup16staticMetaObjectE
	47448	  883  _ZN12QActionGroup9addActionEP7QAction
	47470	  886  _ZN12QActionGroup9triggeredEP7QAction
	47498	  887  _ZN12QActionGroupC1EP7QObject
	474b8	 1071  _ZN12QKeySequenceC1ERK7QStringNS_14SequenceFormatE
	474f0	 1081  _ZN12QKeySequenceD1Ev
	47508	 4326  _ZN5QFont8setStyleENS_5StyleE
	47528	 4328  _ZN5QFont9setWeightENS_6WeightE
	4754c	 4334  _ZN5QFontC1Ev
	4755c	 4341  _ZN5QFontD1Ev
	4756c	 4354  _ZN5QIcon7addFileERK7QStringRK5QSizeNS_4ModeENS_5StateE
	475a8	 4364  _ZN5QIconC1ERK7QString
	475c4	 4366  _ZN5QIconC1Ev
	475d4	 4372  _ZN5QIconD1Ev
	475e4	 4544  _ZN7QAction10setCheckedEb
	47600	 4546  _ZN7QAction10setToolTipERK7QString
	47628	 4553  _ZN7QAction11setShortcutERK12QKeySequence
	47654	 4555  _ZN7QAction12setCheckableEb
	47674	 4568  _ZN7QAction16staticMetaObjectE
	47698	 4579  _ZN7QAction7setIconERK5QIcon
	476b8	 4580  _ZN7QAction7setTextERK7QString
	476dc	 4583  _ZN7QAction9triggeredEb
	476f8	 4584  _ZN7QActionC1EP7QObject
	47714	 6850  _ZNK5QIconcv8QVariantEv
	47730	 6992  _ZNK7QAction9isCheckedEv
	DLL Name: Qt6Widgets.dll
	4774c	   44  _ZN10QBoxLayout10setSpacingEi
	4776c	   45  _ZN10QBoxLayout10setStretchEii
	47790	   63  _ZN10QBoxLayout9addLayoutEP7QLayouti
	477b8	   64  _ZN10QBoxLayout9addWidgetEP7QWidgeti6QFlagsIN2Qt13AlignmentFlagEE
	477fc	  206  _ZN10QTabWidget10setTabTextEiRK7QString
	47828	  225  _ZN10QTabWidget15setCurrentIndexEi
	47850	  239  _ZN10QTabWidget6addTabEP7QWidgetRK7QString
	47880	  245  _ZN10QTabWidgetC1EP7QWidget
	478a0	  391  _ZN11QFileDialog15getOpenFileNameEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE
	478f8	  393  _ZN11QFileDialog15getSaveFileNameEP7QWidgetRK7QStringS4_S4_PS2_6QFlagsINS_6OptionEE
	47950	  507  _ZN11QFormLayout9setWidgetEiNS_8ItemRoleEP7QWidget
	47988	  508  _ZN11QFormLayoutC1EP7QWidget
	479a8	  520  _ZN11QGridLayout16setColumnStretchEii
	479d0	  525  _ZN11QGridLayout20setHorizontalSpacingEi
	479fc	  530  _ZN11QGridLayout7addItemEP11QLayoutItemiiii6QFlagsIN2Qt13AlignmentFlagEE
	47a48	  532  _ZN11QGridLayout9addLayoutEP7QLayoutiiii6QFlagsIN2Qt13AlignmentFlagEE
	47a90	  534  _ZN11QGridLayout9addWidgetEP7QWidgetiiii6QFlagsIN2Qt13AlignmentFlagEE
	47ad8	  535  _ZN11QGridLayoutC1EP7QWidget
	47af8	  544  _ZN11QHBoxLayoutC1EP7QWidget
	47b18	  545  _ZN11QHBoxLayoutC1Ev
	47b30	  633  _ZN11QListWidget10insertItemEiP15QListWidgetItem
	47b64	  634  _ZN11QListWidget10insertItemEiRK7QString
	47b90	  645  _ZN11QListWidget13setCurrentRowEi
	47bb4	  650  _ZN11QListWidget16staticMetaObjectE
	47bdc	  651  _ZN11QListWidget17currentRowChangedEi
	47c04	  654  _ZN11QListWidget17setSortingEnabledEb
	47c2c	  662  _ZN11QListWidget5clearEv
	47c48	  669  _ZN11QListWidgetC1EP7QWidget
	47c68	  677  _ZN11QMainWindow10setMenuBarEP8QMenuBar
	47c94	  678  _ZN11QMainWindow11qt_metacallEN11QMetaObject4CallEiPPv
	47cd0	  679  _ZN11QMainWindow11qt_metacastEPKc
	47cf4	  694  _ZN11QMainWindow15createPopupMenuEv
	47d1c	  698  _ZN11QMainWindow16contextMenuEventEP17QContextMenuEvent
	47d58	  700  _ZN11QMainWindow16setCentralWidgetEP7QWidget
	47d88	  701  _ZN11QMainWindow16staticMetaObjectE
	47db0	  713  _ZN11QMainWindow5eventEP6QEvent
	47dd4	  716  _ZN11QMainWindowC2EP7QWidget6QFlagsIN2Qt10WindowTypeEE
	47e10	  719  _ZN11QMainWindowD2Ev
	47e28	  723  _ZN11QMessageBox11informationEP7QWidgetRK7QStringS4_6QFlagsINS_14StandardButtonEES6_
	47e80	  755  _ZN11QMessageBox7warningEP7QWidgetRK7QStringS4_6QFlagsINS_14StandardButtonEES6_
	47ed4	  758  _ZN11QMessageBox8criticalEP7QWidgetRK7QStringS4_6QFlagsINS_14StandardButtonEES6_
	47f28	  761  _ZN11QMessageBox8questionEP7QWidgetRK7QStringS4_6QFlagsINS_14StandardButtonEES6_
	47f7c	  823  _ZN11QPushButtonC1EP7QWidget
	47f9c	  861  _ZN11QScrollArea18setWidgetResizableEb
	47fc8	  864  _ZN11QScrollArea9setWidgetEP7QWidget
	47ff0	  865  _ZN11QScrollAreaC1EP7QWidget
	48010	  913  _ZN11QToolButtonC1EP7QWidget
	48030	  967  _ZN11QVBoxLayoutC1EP7QWidget
	48050	  968  _ZN11QVBoxLayoutC1Ev
	48068	 1041  _ZN12QApplication7aboutQtEv
	48088	 1048  _ZN12QApplicationC1ERiPPci
	480a8	 1051  _ZN12QApplicationD1Ev
	480c0	 1065  _ZN12QButtonGroup9addButtonEP15QAbstractButtoni
	480f4	 1069  _ZN12QButtonGroupC1EP7QObject
	48114	 1168  _ZN12QInputDialog7getTextEP7QWidgetRK7QStringS4_N9QLineEdit8EchoModeES4_Pb6QFlagsIN2Qt10WindowTypeEES8_INS9_15InputMethodHintEE
	48198	 1228  _ZN12QRadioButtonC1EP7QWidget
	481b8	 2028  _ZN14QStackedWidget14currentChangedEi
	481e0	 2029  _ZN14QStackedWidget15setCurrentIndexEi
	4820c	 2031  _ZN14QStackedWidget16staticMetaObjectE
	48238	 2034  _ZN14QStackedWidget9addWidgetEP7QWidget
	48264	 2035  _ZN14QStackedWidgetC1EP7QWidget
	48288	 2185  _ZN15QAbstractButton10setCheckedEb
	482b0	 2204  _ZN15QAbstractButton16staticMetaObjectE
	482dc	 2212  _ZN15QAbstractButton7clickedEb
	48300	 2215  _ZN15QAbstractButton7setIconERK5QIcon
	48328	 2216  _ZN15QAbstractButton7setTextERK7QString
	48354	 2217  _ZN15QAbstractButton7toggledEb
	48378	 2448  _ZN15QListWidgetItem7setDataEiRK8QVariant
	483a4	 2449  _ZN15QListWidgetItem8setFlagsE6QFlagsIN2Qt8ItemFlagEE
	483dc	 2450  _ZN15QListWidgetItemC1EP11QListWidgeti
	48408	 2451  _ZN15QListWidgetItemC1ERK5QIconRK7QStringP11QListWidgeti
	48444	 2646  _ZN16QDialogButtonBox14setOrientationEN2Qt11OrientationE
	48480	 2647  _ZN16QDialogButtonBox16setCenterButtonsEb
	484ac	 2648  _ZN16QDialogButtonBox16staticMetaObjectE
	484d8	 2650  _ZN16QDialogButtonBox18setStandardButtonsE6QFlagsINS_14StandardButtonEE
	48524	 2653  _ZN16QDialogButtonBox7clickedEP15QAbstractButton
	48558	 2654  _ZN16QDialogButtonBox8acceptedEv
	4857c	 2655  _ZN16QDialogButtonBox8rejectedEv
	485a0	 2662  _ZN16QDialogButtonBoxC1EP7QWidget
	485c4	 2760  _ZN17QAbstractItemView11setIconSizeERK5QSize
	485f4	 2786  _ZN17QAbstractItemView15setCurrentIndexERK11QModelIndex
	48630	 2788  _ZN17QAbstractItemView15setEditTriggersE6QFlagsINS_11EditTriggerEE
	48678	 2795  _ZN17QAbstractItemView16setTextElideModeEN2Qt13TextElideModeE
	486b8	 3314  _ZN19QAbstractScrollArea19setSizeAdjustPolicyENS_16SizeAdjustPolicyE
	48700	 3318  _ZN19QAbstractScrollArea26setVerticalScrollBarPolicyEN2Qt15ScrollBarPolicyE
	48750	 3319  _ZN19QAbstractScrollArea28setHorizontalScrollBarPolicyEN2Qt15ScrollBarPolicyE
	487a0	 4157  _ZN5QMenu12addSeparatorEv
	487bc	 4191  _ZN5QMenu8setTitleERK7QString
	487dc	 4198  _ZN5QMenuC1EP7QWidget
	487f4	 4232  _ZN6QFrame13setFrameShapeENS_5ShapeE
	4881c	 4234  _ZN6QFrame14setFrameShadowENS_6ShadowE
	48848	 4240  _ZN6QFrameC1EP7QWidget6QFlagsIN2Qt10WindowTypeEE
	4887c	 4252  _ZN6QLabel11setWordWrapEb
	48898	 4275  _ZN6QLabel7setTextERK7QString
	488b8	 4280  _ZN6QLabelC1EP7QWidget6QFlagsIN2Qt10WindowTypeEE
	488ec	 4311  _ZN7QDialog10closeEventEP11QCloseEvent
	48918	 4312  _ZN7QDialog10setVisibleEb
	48934	 4313  _ZN7QDialog11eventFilterEP7QObjectP6QEvent
	48964	 4314  _ZN7QDialog11qt_metacallEN11QMetaObject4CallEiPPv
	48998	 4315  _ZN7QDialog11qt_metacastEPKc
	489b8	 4316  _ZN7QDialog11resizeEventEP12QResizeEvent
	489e4	 4317  _ZN7QDialog13keyPressEventEP9QKeyEvent
	48a10	 4319  _ZN7QDialog16contextMenuEventEP17QContextMenuEvent
	48a48	 4320  _ZN7QDialog16staticMetaObjectE
	48a6c	 4323  _ZN7QDialog4doneEi
	48a84	 4324  _ZN7QDialog4execEv
	48a9c	 4325  _ZN7QDialog4openEv
	48ab4	 4326  _ZN7QDialog6acceptEv
	48acc	 4327  _ZN7QDialog6rejectEv
	48ae4	 4333  _ZN7QDialog9showEventEP10QShowEvent
	48b0c	 4336  _ZN7QDialogC2EP7QWidget6QFlagsIN2Qt10WindowTypeEE
	48b40	 4340  _ZN7QDialogD2Ev
	48b54	 4362  _ZN7QLayout18setContentsMarginsEiiii
	48b7c	 4460  _ZN7QWidget10closeEventEP11QCloseEvent
	48ba8	 4461  _ZN7QWidget10enterEventEP11QEnterEvent
	48bd4	 4462  _ZN7QWidget10leaveEventEP6QEvent
	48bf8	 4463  _ZN7QWidget10paintEventEP11QPaintEvent
	48c24	 4464  _ZN7QWidget10setEnabledEb
	48c40	 4466  _ZN7QWidget10setToolTipERK7QString
	48c68	 4467  _ZN7QWidget10setVisibleEb
	48c84	 4471  _ZN7QWidget10wheelEventEP11QWheelEvent
	48cb0	 4472  _ZN7QWidget11actionEventEP12QActionEvent
	48cdc	 4473  _ZN7QWidget11changeEventEP6QEvent
	48d00	 4476  _ZN7QWidget11nativeEventERK10QByteArrayPvPx
	48d30	 4479  _ZN7QWidget11resizeEventEP12QResizeEvent
	48d5c	 4481  _ZN7QWidget11setDisabledEb
	48d7c	 4483  _ZN7QWidget11setTabOrderEPS_S0_
	48da0	 4485  _ZN7QWidget11tabletEventEP12QTabletEvent
	48dcc	 4488  _ZN7QWidget12focusInEventEP11QFocusEvent
	48df8	 4500  _ZN7QWidget13dragMoveEventEP14QDragMoveEvent
	48e28	 4501  _ZN7QWidget13focusOutEventEP11QFocusEvent
	48e54	 4503  _ZN7QWidget13keyPressEventEP9QKeyEvent
	48e80	 4506  _ZN7QWidget13setSizePolicyE11QSizePolicy
	48eac	 4509  _ZN7QWidget13setWindowIconERK5QIcon
	48ed4	 4515  _ZN7QWidget14dragEnterEventEP15QDragEnterEvent
	48f08	 4516  _ZN7QWidget14dragLeaveEventEP15QDragLeaveEvent
	48f3c	 4517  _ZN7QWidget14mouseMoveEventEP11QMouseEvent
	48f6c	 4521  _ZN7QWidget14setMaximumSizeEii
	48f90	 4522  _ZN7QWidget14setMinimumSizeEii
	48fb4	 4525  _ZN7QWidget14setWindowTitleERK7QString
	48fe0	 4528  _ZN7QWidget15keyReleaseEventEP9QKeyEvent
	4900c	 4530  _ZN7QWidget15mousePressEventEP11QMouseEvent
	4903c	 4537  _ZN7QWidget16contextMenuEventEP17QContextMenuEvent
	49074	 4538  _ZN7QWidget16inputMethodEventEP17QInputMethodEvent
	490ac	 4543  _ZN7QWidget16staticMetaObjectE
	490d0	 4545  _ZN7QWidget17mouseReleaseEventEP11QMouseEvent
	49100	 4550  _ZN7QWidget17setUpdatesEnabledEb
	49124	 4556  _ZN7QWidget18focusNextPrevChildEb
	49148	 4570  _ZN7QWidget21mouseDoubleClickEventEP11QMouseEvent
	4917c	 4579  _ZN7QWidget4hideEv
	49194	 4581  _ZN7QWidget4showEv
	491ac	 4582  _ZN7QWidget5closeEv
	491c4	 4583  _ZN7QWidget5eventEP6QEvent
	491e4	 4589  _ZN7QWidget6resizeERK5QSize
	49204	 4600  _ZN7QWidget7setFontERK5QFont
	49224	 4603  _ZN7QWidget8setFocusEN2Qt11FocusReasonE
	49250	 4605  _ZN7QWidget9addActionEP7QAction
	49274	 4615  _ZN7QWidget9dropEventEP10QDropEvent
	4929c	 4618  _ZN7QWidget9hideEventEP10QHideEvent
	492c4	 4619  _ZN7QWidget9moveEventEP10QMoveEvent
	492ec	 4627  _ZN7QWidget9showEventEP10QShowEvent
	49314	 4628  _ZN7QWidgetC1EPS_6QFlagsIN2Qt10WindowTypeEE
	49344	 4634  _ZN7QWidgetD2Ev
	49358	 4765  _ZN8QMenuBarC1EP7QWidget
	49374	 4770  _ZN8QSpinBox10setMaximumEi
	49394	 4771  _ZN8QSpinBox10setMinimumEi
	493b4	 4777  _ZN8QSpinBox13setSingleStepEi
	493d4	 4783  _ZN8QSpinBox8setValueEi
	493f0	 4784  _ZN8QSpinBox9setPrefixERK7QString
	49414	 4785  _ZN8QSpinBox9setSuffixERK7QString
	49438	 4786  _ZN8QSpinBoxC1EP7QWidget
	49454	 4872  _ZN9QCheckBoxC1EP7QWidget
	49470	 4889  _ZN9QComboBox10insertItemEiRK5QIconRK7QStringRK8QVariant
	494ac	 4895  _ZN9QComboBox11insertItemsEiRK5QListI7QStringE
	494e0	 4900  _ZN9QComboBox11setEditableEb
	49500	 4904  _ZN9QComboBox11setItemTextEiRK7QString
	4952c	 4914  _ZN9QComboBox14setCurrentTextERK7QString
	49558	 4917  _ZN9QComboBox15insertSeparatorEi
	4957c	 4920  _ZN9QComboBox15setCurrentIndexEi
	495a0	 4926  _ZN9QComboBox16staticMetaObjectE
	495c4	 4933  _ZN9QComboBox19currentIndexChangedEi
	495ec	 4935  _ZN9QComboBox19setSizeAdjustPolicyENS_16SizeAdjustPolicyE
	49628	 4948  _ZN9QComboBoxC1EP7QWidget
	49644	 4986  _ZN9QGroupBox8setTitleERK7QString
	49668	 4987  _ZN9QGroupBoxC1EP7QWidget
	49684	 5038  _ZN9QLineEdit18setPlaceholderTextERK7QString
	496b4	 5053  _ZN9QLineEdit7setTextERK7QString
	496d8	 5061  _ZN9QLineEditC1EP7QWidget
	496f4	 5070  _ZN9QListView10setSpacingEi
	49714	 5079  _ZN9QListView11setViewModeENS_8ViewModeE
	49740	 5086  _ZN9QListView12setRowHiddenEib
	49764	 5106  _ZN9QListView19setUniformItemSizesEb
	4978c	 5115  _ZN9QListViewC1EP7QWidget
	497a8	 5496  _ZNK10QTabWidget7indexOfEPK7QWidget
	497d0	 5687  _ZNK11QListWidget10currentRowEv
	497f4	 5693  _ZNK11QListWidget13selectedItemsEv
	4981c	 5695  _ZNK11QListWidget16isSortingEnabledEv
	49844	 5700  _ZNK11QListWidget4itemEi
	49860	 5701  _ZNK11QListWidget5countEv
	4987c	 6385  _ZNK14QStackedWidget13currentWidgetEv
	498a4	 6387  _ZNK14QStackedWidget6widgetEi
	498c4	 6439  _ZNK15QAbstractButton9isCheckedEv
	498e8	 6587  _ZNK16QDialogButtonBox14standardButtonEP15QAbstractButton
	49924	 6637  _ZNK17QAbstractItemView12currentIndexEv
	49950	 6856  _ZNK19QAbstractScrollArea17verticalScrollBarEv
	49984	 7189  _ZNK5QMenu10menuActionEv
	499a0	 7244  _ZNK7QDialog15minimumSizeHintEv
	499c4	 7247  _ZNK7QDialog8sizeHintEv
	499e0	 7313  _ZNK7QWidget10redirectedEP6QPoint
	49a04	 7314  _ZNK7QWidget10sizePolicyEv
	49a24	 7316  _ZNK7QWidget10windowIconEv
	49a44	 7321  _ZNK7QWidget11initPainterEP8QPainter
	49a6c	 7331  _ZNK7QWidget11minimumSizeEv
	49a8c	 7332  _ZNK7QWidget11paintEngineEv
	49aac	 7334  _ZNK7QWidget11windowTitleEv
	49acc	 7347  _ZNK7QWidget13sharedPainterEv
	49aec	 7358  _ZNK7QWidget14heightForWidthEi
	49b10	 7366  _ZNK7QWidget15minimumSizeHintEv
	49b34	 7369  _ZNK7QWidget16inputMethodQueryEN2Qt16InputMethodQueryE
	49b70	 7373  _ZNK7QWidget17hasHeightForWidthEv
	49b94	 7392  _ZNK7QWidget6metricEN12QPaintDevice17PaintDeviceMetricE
	49bd0	 7398  _ZNK7QWidget7devTypeEv
	49bec	 7405  _ZNK7QWidget8sizeHintEv
	49c08	 7513  _ZNK9QComboBox11currentDataEi
	49c28	 7514  _ZNK9QComboBox11currentTextEv
	49c48	 7516  _ZNK9QComboBox12currentIndexEv
	49c6c	 7531  _ZNK9QComboBox5countEv
	49c88	 7577  _ZNK9QLineEdit4textEv
	49ca0	 7608  _ZNK9QListView7spacingEv
	49cbc	 7934  _ZTV11QSpacerItem
	49cd0	 8384  _ZThn16_NK7QWidget10redirectedEP6QPoint
	49cfc	 8385  _ZThn16_NK7QWidget11initPainterEP8QPainter
	49d2c	 8386  _ZThn16_NK7QWidget11paintEngineEv
	49d50	 8387  _ZThn16_NK7QWidget13sharedPainterEv
	49d78	 8388  _ZThn16_NK7QWidget6metricEN12QPaintDevice17PaintDeviceMetricE
	49db8	 8389  _ZThn16_NK7QWidget7devTypeEv
	DLL Name: veyon-core.dll
	49dd8	   48  _ZN11AboutDialogC1EP7QWidget
	49df8	   51  _ZN11AboutDialogD1Ev
	49e10	   62  _ZN11HostAddress9localFQDNEv
	49e30	   99  _ZN13Configuration6Object16staticMetaObjectE
	49e60	  101  _ZN13Configuration6Object20configurationChangedEv
	49e94	  111  _ZN13Configuration6ObjectD2Ev
	49eb4	  126  _ZN13Configuration9JsonStore4loadEPNS_6ObjectE
	49ee8	  128  _ZN13Configuration9JsonStore5flushEPKNS_6ObjectE
	49f1c	  129  _ZN13Configuration9JsonStoreC1ENS_5Store5ScopeERK7QString
	49f58	  131  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyI5QUuidEEP9QComboBox
	49fb8	  132  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyI6QColorEEP11QPushButton
	4a01c	  133  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyI7QStringEEP9QComboBox
	4a080	  134  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyI7QStringEEP9QLineEdit
	4a0e4	  136  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyIbEEP12QRadioButton
	4a144	  137  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyIbEEP9QCheckBox
	4a1a0	  139  _ZN13Configuration9UiMapping22initWidgetFromPropertyERKNS_13TypedPropertyIiEEP8QSpinBox
	4a1fc	  141  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyI5QUuidEEP9QComboBox
	4a260	  142  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyI6QColorEEP11QPushButton
	4a2c8	  143  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyI7QStringEEP9QComboBox
	4a32c	  144  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyI7QStringEEP9QLineEdit
	4a390	  146  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyIbEEP12QRadioButton
	4a3f0	  147  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyIbEEP9QCheckBox
	4a44c	  149  _ZN13Configuration9UiMapping23connectWidgetToPropertyERKNS_13TypedPropertyIiEEP8QSpinBox
	4a4a8	  151  _ZN13Configuration9UiMapping5flagsEP7QObject
	4a4d8	  152  _ZN13Configuration9UiMapping8setFlagsEP7QObject6QFlagsINS_8Property4FlagEE
	4a528	  167  _ZN13PluginManager15pluginInterfaceE5QUuid
	4a558	  300  _ZN14MonitoringMode16staticMetaObjectE
	4a584	  333  _ZN14ServiceControl11stopServiceEv
	4a5ac	  334  _ZN14ServiceControl12startServiceEv
	4a5d4	  336  _ZN14ServiceControl14restartServiceEv
	4a5fc	  339  _ZN14ServiceControl16isServiceRunningEv
	4a628	  387  _ZN17AccessControlRuleC1ERK10QJsonValue
	4a654	  388  _ZN17AccessControlRuleC1Ev
	4a674	  391  _ZN17AccessControlRuleaSERKS_
	4a694	  394  _ZN17ComputerListModel16staticMetaObjectE
	4a6c0	  398  _ZN17ConfigurationPage11qt_metacallEN11QMetaObject4CallEiPPv
	4a700	  399  _ZN17ConfigurationPage11qt_metacastEPKc
	4a72c	  400  _ZN17ConfigurationPage14widgetsChangedEv
	4a758	  401  _ZN17ConfigurationPage16staticMetaObjectE
	4a784	  404  _ZN17ConfigurationPageC2EP7QWidget
	4a7ac	  405  _ZN17FileSystemBrowser4execEP9QLineEditRK7QStringS4_
	4a7e4	  468  _ZN18VeyonConfigurationC1Ev
	4a804	  503  _ZN19VeyonServiceControlC1EP7QWidget
	4a82c	  508  _ZN20ConfigurationManager17saveConfigurationEv
	4a860	  509  _ZN20ConfigurationManager18applyConfigurationEv
	4a894	  510  _ZN20ConfigurationManager18clearConfigurationEv
	4a8c8	  512  _ZN20ConfigurationManagerC1EP7QObject
	4a8f0	  551  _ZN21AccessControlProvider23processAuthorizedGroupsERK7QString
	4a934	  552  _ZN21AccessControlProvider25processAccessControlRulesERK7QStringS2_S2_S2_RK5QListIS0_E
	4a990	  554  _ZN21AccessControlProviderC1Ev
	4a9b4	  562  _ZN21PlatformUserFunctions16staticMetaObjectE
	4a9e4	  636  _ZN24PlatformSessionFunctions16staticMetaObjectE
	4aa18	  640  _ZN24UserGroupsBackendManager17availableBackendsEv
	4aa50	  641  _ZN24UserGroupsBackendManager17configuredBackendEv
	4aa88	  643  _ZN24UserGroupsBackendManager19reloadConfigurationEv
	4aac0	  653  _ZN26VncConnectionConfiguration16staticMetaObjectE
	4aaf8	  661  _ZN29NetworkObjectDirectoryManager20availableDirectoriesEv
	4ab38	  674  _ZN6Logger16staticMetaObjectE
	4ab58	  707  _ZN8Computer16staticMetaObjectE
	4ab7c	  723  _ZN9VeyonCore13versionStringEv
	4aba0	  727  _ZN9VeyonCore15shortenFuncinfoERK10QByteArray
	4abd0	  729  _ZN9VeyonCore16staticMetaObjectE
	4abf4	  732  _ZN9VeyonCore18initAuthenticationEv
	4ac1c	  737  _ZN9VeyonCore21translationsDirectoryEv
	4ac48	  742  _ZN9VeyonCore26setupApplicationParametersEv
	4ac78	  746  _ZN9VeyonCore4execEv
	4ac90	  749  _ZN9VeyonCore8instanceEv
	4acac	  752  _ZN9VeyonCoreC1EP16QCoreApplicationNS_9ComponentERK7QString
	4acec	  755  _ZN9VeyonCoreD1Ev
	4ad00	  759  _ZNK10Filesystem10expandPathE7QString
	4ad28	  796  _ZNK13Configuration8Property12variantValueEv
	4ad58	  797  _ZNK13Configuration8Property13lambdaContextEv
	4ad88	  798  _ZNK13Configuration8Property15setVariantValueERK8QVariant
	4adc4	  844  _ZNK17AccessControlRule6toJsonEv
	4ade8	  862  _ZNK21AccessControlProvider10userGroupsEv
	4ae14	  874  _ZNK21AccessControlProvider9locationsEv
	4ae40	  957  _ZTV14ServiceControl
	4ae58	  963  _ZTV17ConfigurationPage
	4ae74	  966  _ZTV18VeyonConfiguration
	4ae90	  970  _ZTV20ConfigurationManager
	4aeb0	  974  _ZTV21AccessControlProvider
	4aed0	  991  _ZTVN13Configuration9JsonStoreE
```

### 4.7 Tabla de importación — veyon-cli.exe

```text
	DLL Name: KERNEL32.dll
	291a0	  295  DeleteCriticalSection
	291b8	  333  EnterCriticalSection
	291d0	  568  GetCurrentProcess
	291e4	  648  GetLastError
	291f4	  670  GetModuleHandleA
	29208	  730  GetProcAddress
	2921a	  918  InitializeCriticalSection
	29236	  945  IsDBCSLeadByteEx
	2924a	  954  IsProcessorFeaturePresent
	29266	 1012  LeaveCriticalSection
	2927e	 1019  LoadLibraryW
	2928e	 1064  MultiByteToWideChar
	292a4	 1433  SetUnhandledExceptionFilter
	292c2	 1449  Sleep
	292ca	 1465  TerminateProcess
	292de	 1485  TlsGetValue
	292ec	 1533  VirtualProtect
	292fe	 1535  VirtualQuery
	2930e	 1588  WideCharToMultiByte
	29324	 1625  __C_specific_handler
	DLL Name: msvcrt.dll
	2933c	  109  ___lc_codepage_func
	29352	  112  ___mb_cur_max_func
	29368	  127  __getmainargs
	29378	  128  __initenv
	29384	  129  __iob_func
	29392	  160  __set_app_type
	293a4	  162  __setusermatherr
	293b8	  191  _amsg_exit
	293c6	  210  _cexit
	293d0	  224  _commode
	293dc	  266  _errno
	293e6	  300  _fmode
	293f0	  379  _initterm
	293fc	  482  _lock
	29404	  820  _unlock
	2940e	 1016  abort
	29416	 1023  atexit
	29420	 1033  calloc
	2942a	 1046  exit
	29432	 1065  fprintf
	2943c	 1067  fputc
	29444	 1072  free
	2944c	 1123  localeconv
	2945a	 1130  malloc
	29464	 1138  memcmp
	2946e	 1139  memcpy
	29478	 1140  memmove
	29482	 1169  signal
	2948c	 1183  strcmp
	29496	 1188  strerror
	294a2	 1190  strlen
	294ac	 1193  strncmp
	294b6	 1224  vfprintf
	294c2	 1244  wcslen
	294cc	 1333  _write
	DLL Name: libstdc++-6.dll
	294d8	 4837  _ZSt18_Rb_tree_decrementPSt18_Rb_tree_node_base
	2950c	 4838  _ZSt18_Rb_tree_incrementPKSt18_Rb_tree_node_base
	29540	 4839  _ZSt18_Rb_tree_incrementPSt18_Rb_tree_node_base
	29574	 4873  _ZSt29_Rb_tree_insert_and_rebalancebPSt18_Rb_tree_node_baseS0_RS_
	295b8	 5621  _ZTVN10__cxxabiv117__class_type_infoE
	295e0	 5626  _ZTVN10__cxxabiv121__vmi_class_type_infoE
	2960c	 5868  _ZdaPv
	29618	 5872  _ZdaPvy
	29624	 5874  _ZdlPv
	29630	 5878  _ZdlPvy
	2963c	 5880  _Znay
	29644	 5884  _Znwy
	DLL Name: Qt6Core.dll
	2964c	   82  _Z23qt_qFindChildren_helperPK7QObject14QAnyStringViewRK11QMetaObjectP5QListIPvE6QFlagsIN2Qt15FindChildOptionEE
	296c0	   90  _Z26qt_QMetaEnum_debugOperatorR6QDebugxPK11QMetaObjectPKc
	296fc	   92  _Z27qEnvironmentVariableIsEmptyPKc
	29724	  164  _Z7qputenvPKc14QByteArrayView
	29744	  188  _ZN10QArrayData10deallocateEPS_xx
	29768	  189  _ZN10QArrayData19reallocateUnalignedEPS_PvxxNS_16AllocationOptionE
	297b0	  190  _ZN10QArrayData8allocateEPPS_xxxNS_16AllocationOptionE
	297ec	  195  _ZN10QByteArray11reallocDataExN10QArrayData16AllocationOptionE
	29830	  216  _ZN10QByteArray6_emptyE
	2984c	  221  _ZN10QByteArray6insertEx14QByteArrayView
	29878	  224  _ZN10QByteArray6numberEii
	29894	  317  _ZN10QEventLoop4execE6QFlagsINS_17ProcessEventsFlagEE
	298cc	  319  _ZN10QEventLoop4quitEv
	298e8	  322  _ZN10QEventLoopC1EP7QObject
	29908	  325  _ZN10QEventLoopD1Ev
	29920	  349  _ZN10QJsonArrayD1Ev
	29938	  447  _ZN11QDataStream11resetStatusEv
	2995c	  465  _ZN11QDataStream9setStatusENS_6StatusE
	29988	  484  _ZN11QDataStreamlsEi
	299a0	  486  _ZN11QDataStreamlsEx
	299b8	  495  _ZN11QDataStreamrsERi
	299d0	  497  _ZN11QDataStreamrsERx
	299e8	  560  _ZN11QJsonObjectD1Ev
	29a00	  575  _ZN11QMetaObject10ConnectionD1Ev
	29a24	  586  _ZN11QMetaObject16invokeMethodImplEP7QObjectPKcN2Qt14ConnectionTypeExPKPKvPKS3_PKPKN9QtPrivate18QMetaTypeInterfaceE
	29a9c	  644  _ZN11QTextStream12readLineIntoEP7QStringx
	29ac8	  665  _ZN11QTextStreamC1EP6_iobuf6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	29b10	  677  _ZN11QTextStreamD1Ev
	29b28	  682  _ZN11QTextStreamlsEPKc
	29b44	  685  _ZN11QTextStreamlsERK7QString
	29b64	  686  _ZN11QTextStreamlsEc
	29b7c	  855  _ZN13QElapsedTimer5startEv
	29b9c	  904  _ZN13QJsonDocument8fromJsonERK10QByteArrayP15QJsonParseError
	29bdc	  909  _ZN13QJsonDocumentC1ERK10QJsonArray
	29c04	  910  _ZN13QJsonDocumentC1ERK11QJsonObject
	29c2c	  919  _ZN13QJsonDocumentD1Ev
	29c48	 1286  _ZN15QtSharedPointer20ExternalRefCountData16setQObjectSharedEPK7QObjectb
	29c94	 1368  _ZN16QCoreApplication19applicationFilePathEv
	29cc4	 1386  _ZN16QCoreApplication9argumentsEv
	29ce8	 1397  _ZN16QDebugStateSaverC1ER6QDebug
	29d0c	 1399  _ZN16QDebugStateSaverD1Ev
	29d28	 2951  _ZN2Qt4endlER11QTextStream
	29d48	 3023  _ZN4QDirD1Ev
	29d58	 3120  _ZN5QFile4openE6QFlagsIN13QIODeviceBase12OpenModeFlagEE
	29d94	 3133  _ZN5QFileC1ERK7QString
	29db0	 3142  _ZN5QFileD1Ev
	29dc0	 3165  _ZN5QUuid10fromStringE14QAnyStringView
	29dec	 3189  _ZN6QDebug9putStringEPK5QChary
	29e10	 3190  _ZN6QDebugD1Ev
	29e24	 3219  _ZN6QTimer16staticMetaObjectE
	29e44	 3225  _ZN6QTimer5startEi
	29e5c	 3227  _ZN6QTimer7timeoutENS_14QPrivateSignalE
	29e88	 3228  _ZN6QTimerC1EP7QObject
	29ea4	 3231  _ZN6QTimerD1Ev
	29eb8	 3298  _ZN7QObject10childEventEP11QChildEvent
	29ee4	 3305  _ZN7QObject10timerEventEP11QTimerEvent
	29f10	 3306  _ZN7QObject11connectImplEPKS_PPvS1_S3_PN9QtPrivate15QSlotObjectBaseEN2Qt14ConnectionTypeEPKiPK11QMetaObject
	29f80	 3307  _ZN7QObject11customEventEP6QEvent
	29fa4	 3309  _ZN7QObject11eventFilterEPS_P6QEvent
	29fcc	 3310  _ZN7QObject11qt_metacallEN11QMetaObject4CallEiPPv
	2a000	 3311  _ZN7QObject11qt_metacastEPKc
	2a020	 3316  _ZN7QObject13connectNotifyERK11QMetaMethod
	2a050	 3323  _ZN7QObject16disconnectNotifyERK11QMetaMethod
	2a080	 3324  _ZN7QObject16staticMetaObjectE
	2a0a4	 3330  _ZN7QObject5eventEP6QEvent
	2a0c4	 3339  _ZN7QObjectC2EPS_
	2a0d8	 3343  _ZN7QObjectD2Ev
	2a0ec	 3344  _ZN7QString10fromLatin1E14QByteArrayView
	2a118	 3355  _ZN7QString13toUtf8_helperERKS_
	2a13c	 3358  _ZN7QString14toLower_helperERKS_
	2a160	 3379  _ZN7QString6_emptyE
	2a178	 3391  _ZN7QString6numberEii
	2a190	 3409  _ZN7QString7replaceE5QCharRKS_N2Qt15CaseSensitivityE
	2a1c8	 3420  _ZN7QString8fromUtf8E14QByteArrayView
	2a1f0	 3427  _ZN7QStringC1ExN2Qt14InitializationE
	2a218	 3434  _ZN7QStringaSERKS_
	2a230	 3460  _ZN7QThread6msleepEm
	2a248	 3530  _ZN8QProcess12splitCommandE11QStringView
	2a274	 3568  _ZN8QProcess7executeERK7QStringRK5QListIS0_E
	2a2a4	 3589  _ZN8QSysInfo8buildAbiEv
	2a2c0	 3618  _ZN8QVariantC1ERK10QJsonArray
	2a2e0	 3630  _ZN8QVariantC1ERK5QListI7QStringE
	2a304	 3641  _ZN8QVariantC1ERK7QString
	2a320	 3703  _ZN8QVariantD1Ev
	2a334	 3811  _ZN9QFileInfoC1ERK7QString
	2a354	 3820  _ZN9QFileInfoD1Ev
	2a368	 3823  _ZN9QHashSeed10globalSeedEv
	2a388	 3864  _ZN9QIODevice8readLineEx
	2a3a4	 3897  _ZN9QMetaType14registerHelperEPKN9QtPrivate18QMetaTypeInterfaceE
	2a3e8	 3903  _ZN9QMetaType25registerNormalizedTypedefERK10QByteArrayS_
	2a424	 3913  _ZN9QMetaTypeC1Ei
	2a438	 4136  _ZN9QtPrivate12argToQStringE14QAnyStringViewyPPKNS_7ArgBaseE
	2a478	 4137  _ZN9QtPrivate12equalStringsE11QStringView13QLatin1String
	2a4b4	 4139  _ZN9QtPrivate12equalStringsE11QStringViewS0_
	2a4e4	 4159  _ZN9QtPrivate14compareStringsE11QStringViewS0_N2Qt15CaseSensitivityE
	2a52c	 4242  _ZN9QtPrivate16QStringList_joinEPK5QListI7QStringEPK5QCharx
	2a56c	 4441  _ZNK11QDataStream26isDeviceTransactionStartedEv
	2a5a0	 4531  _ZNK11QMetaObject13indexOfMethodEPKc
	2a5c8	 4545  _ZNK11QMetaObject2trEPKcS1_i
	2a5e8	 4552  _ZNK11QMetaObject9classNameEv
	2a608	 4553  _ZNK11QObjectData17dynamicMetaObjectEv
	2a634	 4658  _ZNK13QElapsedTimer7elapsedEv
	2a654	 4681  _ZNK13QJsonDocument5arrayEv
	2a674	 4684  _ZNK13QJsonDocument6toJsonENS_10JsonFormatE
	2a6a4	 4688  _ZNK13QJsonDocument9toVariantEv
	2a6c8	 4900  _ZNK14QVersionNumber8toStringEv
	2a6ec	 4943  _ZNK15QJsonParseError11errorStringEv
	2a714	 5546  _ZNK4QDir4pathEv
	2a728	 5638  _ZNK5QFile6existsEv
	2a740	 5639  _ZNK5QFile8fileNameEv
	2a758	 5662  _ZNK5QUuid8toStringENS_12StringFormatE
	2a784	 5827  _ZNK7QString5splitE5QChar6QFlagsIN2Qt18SplitBehaviorFlagsEENS2_15CaseSensitivityE
	2a7d8	 5837  _ZNK7QString7indexOfERKS_xN2Qt15CaseSensitivityE
	2a80c	 5843  _ZNK7QString8arg_implE14QAnyStringViewi5QChar
	2a83c	 5900  _ZNK8QVariant11toJsonArrayEv
	2a85c	 5904  _ZNK8QVariant12toJsonObjectEv
	2a87c	 5906  _ZNK8QVariant12toStringListEv
	2a89c	 5912  _ZNK8QVariant5toIntEPb
	2a8b8	 5913  _ZNK8QVariant5toMapEv
	2a8d0	 5939  _ZNK8QVariant8toStringEv
	2a8ec	 6009  _ZNK9QFileInfo10isReadableEv
	2a90c	 6012  _ZNK9QFileInfo10isWritableEv
	2a92c	 6028  _ZNK9QFileInfo3dirEv
	2a944	 6034  _ZNK9QFileInfo6existsEv
	2a960	 6055  _ZNK9QIODevice11canReadLineEv
	2a980	 6546  _ZlsR11QDataStreamRK7QString
	2a9a0	 6584  _ZrsR11QDataStreamR7QString
	2a9c0	 6597  qVersion
	2a9cc	 6606  qt_version_tag_6_10
	DLL Name: Qt6Gui.dll
	2a9e4	 1081  _ZN12QKeySequenceD1Ev
	DLL Name: Qt6Network.dll
	2a9fc	  320  _ZN12QHostAddressC1ERK7QString
	2aa20	  332  _ZN12QHostAddressD1Ev
	DLL Name: Qt6Widgets.dll
	2aa38	 1048  _ZN12QApplicationC1ERiPPci
	DLL Name: libcrypto-3-x64.dll
	2aa58	 3647  OpenSSL_version
	DLL Name: libqca-qt6.dll
	2aa6c	  219  _ZN3QCA11SecureArrayC1ERK10QByteArray
	2aa94	  230  _ZN3QCA11SecureArrayD1Ev
	DLL Name: veyon-core.dll
	2aab0	   67  _ZN13CommandLineIO10printTableERKSt4pairI5QListI7QStringES1_IS3_EEccc
	2aaf8	   68  _ZN13CommandLineIO10printUsageERK7QStringS2_RK5QListISt4pairIS0_S0_EES8_
	2ab44	   69  _ZN13CommandLineIO13printExamplesERK7QStringS2_RK5QListISt4pairIS0_S3_IS0_EEE
	2ab94	   72  _ZN13CommandLineIO16printDescriptionERK7QString
	2abc8	   74  _ZN13CommandLineIO5errorERK7QString
	2abf0	   75  _ZN13CommandLineIO5printERK7QString
	2ac18	   97  _ZN13Configuration6Object11removeValueERK7QStringS3_
	2ac50	  102  _ZN13Configuration6Object8setValueERK7QStringRK8QVariantS3_
	2ac90	  111  _ZN13Configuration6ObjectD2Ev
	2acb0	  113  _ZN13Configuration6ObjectpLERKS0_
	2acd4	  119  _ZN13Configuration8Property16staticMetaObjectE
	2ad08	  121  _ZN13Configuration8Property4findEP7QObjectRK7QStringS5_
	2ad44	  128  _ZN13Configuration9JsonStore5flushEPKNS_6ObjectE
	2ad78	  129  _ZN13Configuration9JsonStoreC1ENS_5Store5ScopeERK7QString
	2adb4	  172  _ZN13PluginManager28registerExtraPluginInterfaceEP7QObject
	2adf4	  288  _ZN14FeatureManagerC1EP7QObject
	2ae18	  333  _ZN14ServiceControl11stopServiceEv
	2ae40	  334  _ZN14ServiceControl12startServiceEv
	2ae68	  338  _ZN14ServiceControl15registerServiceEv
	2ae94	  339  _ZN14ServiceControl16isServiceRunningEv
	2aec0	  342  _ZN14ServiceControl17unregisterServiceEv
	2aeec	  344  _ZN14ServiceControl19isServiceRegisteredEv
	2af1c	  467  _ZN18VeyonConfigurationC1EPN13Configuration5StoreE
	2af54	  503  _ZN19VeyonServiceControlC1EP7QWidget
	2af7c	  508  _ZN20ConfigurationManager17saveConfigurationEv
	2afb0	  509  _ZN20ConfigurationManager18applyConfigurationEv
	2afe4	  510  _ZN20ConfigurationManager18clearConfigurationEv
	2b018	  512  _ZN20ConfigurationManagerC1EP7QObject
	2b040	  599  _ZN24ComputerControlInterface12stateChangedEv
	2b070	  608  _ZN24ComputerControlInterface16staticMetaObjectE
	2b0a4	  617  _ZN24ComputerControlInterface19isMessageQueueEmptyEv
	2b0dc	  629  _ZN24ComputerControlInterface5startE5QSizeNS_10UpdateModeEP19AuthenticationProxy
	2b130	  630  _ZN24ComputerControlInterfaceC1ERK8ComputeriP7QObject
	2b168	  633  _ZN24ComputerControlInterfaceD1Ev
	2b18c	  652  _ZN26CommandLinePluginInterface16staticMetaObjectE
	2b1c4	  708  _ZN8ComputerC1E5QUuidRK7QStringS3_S3_S3_
	2b1f0	  723  _ZN9VeyonCore13versionStringEv
	2b214	  729  _ZN9VeyonCore16staticMetaObjectE
	2b238	  732  _ZN9VeyonCore18initAuthenticationEv
	2b260	  742  _ZN9VeyonCore26setupApplicationParametersEv
	2b290	  749  _ZN9VeyonCore8instanceEv
	2b2ac	  752  _ZN9VeyonCoreC1EP16QCoreApplicationNS_9ComponentERK7QString
	2b2ec	  758  _ZNK10CryptoCore15encryptPasswordERKN3QCA11SecureArrayE
	2b328	  792  _ZNK13Configuration6Object5valueERK7QStringS3_RK8QVariant
	2b364	  793  _ZNK13Configuration6Object8hasValueERK7QStringS3_
	2b398	  796  _ZNK13Configuration8Property12variantValueEv
	2b3c8	  809  _ZNK13PluginManager10pluginNameE5QUuid
	2b3f4	  821  _ZNK14FeatureManager14controlFeatureE5QUuidN24FeatureProviderInterface9OperationERK4QMapI7QString8QVariantERK28ComputerControlInterfaceList
	2b484	  829  _ZNK14FeatureManager7featureE5QUuid
	2b4ac	  831  _ZNK14FeatureManager9pluginUidE5QUuid
	2b4d4	  954  _ZTV14FeatureManager
	2b4ec	  957  _ZTV14ServiceControl
	2b504	  966  _ZTV18VeyonConfiguration
	2b520	  970  _ZTV20ConfigurationManager
	2b540	  991  _ZTVN13Configuration9JsonStoreE
```

### 4.8 Dependencias (DLL Name) de cada plugin

```text
### authkeys.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Widgets.dll
   libqca-qt6.dll
   veyon-core.dll
### builtin-ultravnc-server.dll
   ADVAPI32.dll
   GDI32.dll
   IMM32.dll
   KERNEL32.dll
   msvcrt.dll
   SHELL32.dll
   USER32.dll
   VERSION.dll
   WS2_32.dll
   libgcc_s_seh-1.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Widgets.dll
   libjpeg-62.dll
   liblzo2-2.dll
   libqca-qt6.dll
   zlib1.dll
   veyon-core.dll
### builtindirectory.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Widgets.dll
   veyon-core.dll
### demo.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Network.dll
   Qt6Widgets.dll
   libqca-qt6.dll
   veyon-core.dll
### desktopservices.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Widgets.dll
   veyon-core.dll
### external-vnc-server.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Widgets.dll
   libqca-qt6.dll
   veyon-core.dll
### filetransfer.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Widgets.dll
   veyon-core.dll
### headless-vnc-server.dll
   KERNEL32.dll
   msvcrt.dll
   WS2_32.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   libqca-qt6.dll
   libvncserver.dll
   veyon-core.dll
### ldap.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Widgets.dll
   liblber.dll
   libldap.dll
   libqca-qt6.dll
   veyon-core.dll
   libkldap-light.dll
### powercontrol.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Network.dll
   Qt6Widgets.dll
   veyon-core.dll
### remoteaccess.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Network.dll
   Qt6Widgets.dll
   veyon-core.dll
### screenlock.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   veyon-core.dll
### screenshot.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Network.dll
   Qt6Widgets.dll
   veyon-core.dll
### systemusergroups.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   veyon-core.dll
### textmessage.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Widgets.dll
   veyon-core.dll
### usersessioncontrol.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Widgets.dll
   libqca-qt6.dll
   veyon-core.dll
### webapi.dll
   KERNEL32.dll
   msvcrt.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6HttpServer.dll
   Qt6Network.dll
   Qt6Widgets.dll
   libqca-qt6.dll
   veyon-core.dll
### windows-platform.dll
   ADVAPI32.dll
   IMM32.dll
   interception.dll
   IPHLPAPI.DLL
   KERNEL32.dll
   msvcrt.dll
   NETAPI32.dll
   ntdll.dll
   ole32.dll
   OLEAUT32.dll
   Secur32.dll
   SETUPAPI.dll
   SHELL32.dll
   USER32.dll
   USERENV.dll
   WS2_32.dll
   WTSAPI32.dll
   libstdc++-6.dll
   Qt6Core.dll
   Qt6Gui.dll
   Qt6Network.dll
   Qt6Widgets.dll
   libqca-qt6.dll
   veyon-core.dll
```

### 4.9 Exportaciones relevantes de veyon-core.dll (símbolos C++ manglados, filtrados a auth/vnc/service/feature/accesscontrol)

```text
_ZN10CryptoCore17generateChallengeEv
_ZN10CryptoCoreC1Ev
_ZN10CryptoCoreC2Ev
_ZN10CryptoCoreD1Ev
_ZN10CryptoCoreD2Ev
_ZN13VncConnection22libvncClientDispatcherEPcxN12SocketDevice15SocketOperationEPv
_ZN14FeatureManager11qt_metacallEN11QMetaObject4CallEiPPv
_ZN14FeatureManager11qt_metacastEPKc
_ZN14FeatureManager16staticMetaObjectE
_ZN14FeatureManager18qt_static_metacallEP7QObjectN11QMetaObject4CallEiPPv
_ZN14FeatureManagerC1EP7QObject
_ZN14FeatureManagerC2EP7QObject
_ZN14ServiceControl11qt_metacallEN11QMetaObject4CallEiPPv
_ZN14ServiceControl11qt_metacastEPKc
_ZN14ServiceControl11stopServiceEv
_ZN14ServiceControl12startServiceEv
_ZN14ServiceControl12textFeedbackERK7QStringRK7QFutureIvE
_ZN14ServiceControl14restartServiceEv
_ZN14ServiceControl14serviceControlERK7QStringRK7QFutureIvE
_ZN14ServiceControl15registerServiceEv
_ZN14ServiceControl16isServiceRunningEv
_ZN14ServiceControl16staticMetaObjectE
_ZN14ServiceControl17graphicalFeedbackERK7QStringRK7QFutureIvE
_ZN14ServiceControl17unregisterServiceEv
_ZN14ServiceControl18qt_static_metacallEP7QObjectN11QMetaObject4CallEiPPv
_ZN14ServiceControl19isServiceRegisteredEv
_ZN14ServiceControlC1ERK7QStringS2_S2_P7QWidget
_ZN14ServiceControlC2ERK7QStringS2_S2_P7QWidget
_ZN15VeyonConnection25hookPrepareAuthenticationEP10_rfbClient
_ZN15VncServerClient11qt_metacallEN11QMetaObject4CallEiPPv
_ZN15VncServerClient11qt_metacastEPKc
_ZN15VncServerClient16staticMetaObjectE
_ZN15VncServerClient18qt_static_metacallEP7QObjectN11QMetaObject4CallEiPPv
_ZN15VncServerClient21accessControlFinishedEPS_
_ZN17AccessControlRule16staticMetaObjectE
_ZN17AccessControlRuleC1ERK10QJsonValue
_ZN17AccessControlRuleC1Ev
_ZN17AccessControlRuleC2ERK10QJsonValue
_ZN17AccessControlRuleC2Ev
_ZN17AccessControlRuleaSERKS_
_ZN17VncClientProtocol10handleRectER7QBuffer30rfbFramebufferUpdateRectHeader
_ZN17VncClientProtocol11readMessageEi
_ZN17VncClientProtocol12readProtocolEv
_ZN17VncClientProtocol12setEncodingsERK5QListIjE
_ZN17VncClientProtocol13sendEncodingsEv
_ZN17VncClientProtocol14receiveMessageEv
_ZN17VncClientProtocol14setPixelFormatE14rfbPixelFormat
_ZN17VncClientProtocol15sendPixelFormatEv
_ZN17VncClientProtocol16isPseudoEncodingE30rfbFramebufferUpdateRectHeader
_ZN17VncClientProtocol17receiveXvpMessageEv
_ZN17VncClientProtocol18receiveBellMessageEv
_ZN17VncClientProtocol20receiveSecurityTypesEv
_ZN17VncClientProtocol21handleRectEncodingRREER7QBufferj
_ZN17VncClientProtocol21receiveCutTextMessageEv
_ZN17VncClientProtocol21receiveSecurityResultEv
_ZN17VncClientProtocol22handleRectEncodingZRLEER7QBuffer
_ZN17VncClientProtocol22handleRectEncodingZlibER7QBuffer
_ZN17VncClientProtocol23handleRectEncodingCoRREER7QBufferj
_ZN17VncClientProtocol23handleRectEncodingTightER7QBuffer30rfbFramebufferUpdateRectHeader
_ZN17VncClientProtocol24receiveSecurityChallengeEv
_ZN17VncClientProtocol24receiveServerInitMessageEv
_ZN17VncClientProtocol24requestFramebufferUpdateEb
_ZN17VncClientProtocol25handleRectEncodingHextileER7QBuffer30rfbFramebufferUpdateRectHeaderj
_ZN17VncClientProtocol30receiveColourMapEntriesMessageEv
_ZN17VncClientProtocol31receiveFramebufferUpdateMessageEv
_ZN17VncClientProtocol31receiveResizeFramebufferMessageEv
_ZN17VncClientProtocol32handleRectEncodingExtDesktopSizeER7QBuffer
_ZN17VncClientProtocol4readEv
_ZN17VncClientProtocol5resetEv
_ZN17VncClientProtocol5startEv
_ZN17VncClientProtocolC1EP9QIODeviceRKN3QCA11SecureArrayE
_ZN17VncClientProtocolC2EP9QIODeviceRKN3QCA11SecureArrayE
_ZN17VncServerProtocol12readProtocolEv
_ZN17VncServerProtocol17sendSecurityTypesEv
_ZN17VncServerProtocol20processAccessControlEv
_ZN17VncServerProtocol21processAuthenticationER19VariantArrayMessage
_ZN17VncServerProtocol22processFramebufferInitEv
_ZN17VncServerProtocol23sendAuthenticationTypesEv
_ZN17VncServerProtocol26sendEmptyServerInitMessageEv
_ZN17VncServerProtocol27receiveSecurityTypeResponseEv
_ZN17VncServerProtocol28receiveAuthenticationMessageEv
_ZN17VncServerProtocol30sendFailedAccessControlDetailsEv
_ZN17VncServerProtocol33receiveAuthenticationTypeResponseEv
_ZN17VncServerProtocol4readEv
_ZN17VncServerProtocol5startEv
_ZN17VncServerProtocol8setStateENS_5StateE
_ZN17VncServerProtocolC1EP10QTcpSocketP15VncServerClient
_ZN17VncServerProtocolC2EP10QTcpSocketP15VncServerClient
_ZN19VeyonServiceControl11displayNameEv
_ZN19VeyonServiceControl11qt_metacallEN11QMetaObject4CallEiPPv
_ZN19VeyonServiceControl11qt_metacastEPKc
_ZN19VeyonServiceControl12setAutostartEb
_ZN19VeyonServiceControl16staticMetaObjectE
_ZN19VeyonServiceControl18qt_static_metacallEP7QObjectN11QMetaObject4CallEiPPv
_ZN19VeyonServiceControl4nameEv
_ZN19VeyonServiceControl8filePathEv
_ZN19VeyonServiceControlC1EP7QWidget
_ZN19VeyonServiceControlC2EP7QWidget
_ZN21AccessControlProvider11checkAccessERK7QStringS2_RK5QListIS0_E
_ZN21AccessControlProvider11objectNamesERK5QListI13NetworkObjectE
_ZN21AccessControlProvider11qt_metacallEN11QMetaObject4CallEiPPv
_ZN21AccessControlProvider11qt_metacastEPKc
_ZN21AccessControlProvider11sendDetailsEP9QIODeviceRK7QString
_ZN21AccessControlProvider16staticMetaObjectE
_ZN21AccessControlProvider18qt_static_metacallEP7QObjectN11QMetaObject4CallEiPPv
_ZN21AccessControlProvider20handleFeatureMessageE14QSharedPointerI24ComputerControlInterfaceERK14FeatureMessage
_ZN21AccessControlProvider23processAuthorizedGroupsERK7QString
_ZN21AccessControlProvider25processAccessControlRulesERK7QStringS2_S2_S2_RK5QListIS0_E
_ZN21AccessControlProvider9matchListERK5QListI7QStringERKS1_
_ZN21AccessControlProviderC1Ev
_ZN21AccessControlProviderC2Ev
_ZN24ComputerControlInterface22setAccessControlFailedERK7QString
_ZN24ComputerControlInterface27accessControlDetailsChangedEv
_ZN24ComputerControlInterface5startE5QSizeNS_10UpdateModeEP19AuthenticationProxy
_ZN25AuthenticationCredentials13setPrivateKeyERKN3QCA10PrivateKeyE
_ZN25AuthenticationCredentials14loadPrivateKeyERK7QString
_ZN25AuthenticationCredentialsC1ERKS_
_ZN25AuthenticationCredentialsC1Ev
_ZN25AuthenticationCredentialsC2ERKS_
_ZN25AuthenticationCredentialsC2Ev
_ZN9VeyonCore14initCryptoCoreEv
_ZN9VeyonCore18initAuthenticationEv
_ZN9VeyonCore23initLogonAuthenticationEv
_ZN9VeyonCore25initKeyFileAuthenticationEv
_ZN9VeyonCore28isAuthenticationKeyNameValidERK7QString
_ZN9VeyonCore29initAuthenticationCredentialsEv
_ZNK10CryptoCore15decryptPasswordERK7QString
_ZNK10CryptoCore15encryptPasswordERKN3QCA11SecureArrayE
_ZNK14FeatureManager10metaObjectEv
_ZNK14FeatureManager11stopFeatureER20VeyonMasterInterfaceRK7FeatureRK28ComputerControlInterfaceList
_ZNK14FeatureManager12startFeatureER20VeyonMasterInterfaceRK7FeatureRK28ComputerControlInterfaceList
_ZNK14FeatureManager14activeFeaturesER20VeyonServerInterface
_ZNK14FeatureManager14controlFeatureE5QUuidN24FeatureProviderInterface9OperationERK4QMapI7QString8QVariantERK28ComputerControlInterfaceList
_ZNK14FeatureManager14metaFeatureUidE5QUuid
_ZNK14FeatureManager15relatedFeaturesE5QUuid
_ZNK14FeatureManager20handleFeatureMessageE14QSharedPointerI24ComputerControlInterfaceERK14FeatureMessage
_ZNK14FeatureManager20handleFeatureMessageER20VeyonServerInterfaceRK14MessageContextRK14FeatureMessage
_ZNK14FeatureManager20handleFeatureMessageER20VeyonWorkerInterfaceRK14FeatureMessage
_ZNK14FeatureManager24sendAsyncFeatureMessagesER20VeyonServerInterfaceRK14MessageContext
_ZNK14FeatureManager30handleFeatureMessageFromWorkerER20VeyonServerInterfaceRK14FeatureMessage
_ZNK14FeatureManager7featureE5QUuid
_ZNK14FeatureManager8featuresE5QUuid
_ZNK14FeatureManager9pluginUidE5QUuid
_ZNK14ServiceControl10metaObjectEv
_ZNK15VeyonConnection25authenticationCredentialsEv
_ZNK15VncServerClient10metaObjectEv
_ZNK17AccessControlRule6toJsonEv
_ZNK17VncServerProtocol5stateEv
_ZNK19VeyonServiceControl10metaObjectEv
_ZNK21AccessControlProvider10metaObjectEv
_ZNK21AccessControlProvider10userGroupsEv
_ZNK21AccessControlProvider11isLocalHostERK7QString
_ZNK21AccessControlProvider11isLocalUserERK7QStringS2_
_ZNK21AccessControlProvider11isLocatedAtERK7QStringS2_
_ZNK21AccessControlProvider13lookupSubjectEN17AccessControlRule7SubjectERK7QStringS4_S4_S4_
_ZNK21AccessControlProvider15matchConditionsERK17AccessControlRuleRK7QStringS5_S5_S5_RK5QListIS3_E
_ZNK21AccessControlProvider16isNoUserLoggedOnEv
_ZNK21AccessControlProvider17haveSameLocationsERK7QStringS2_
_ZNK21AccessControlProvider18haveGroupsInCommonERK7QStringS2_
_ZNK21AccessControlProvider19isMemberOfUserGroupERK7QStringS2_
_ZNK21AccessControlProvider19locationsOfComputerERK7QString
_ZNK21AccessControlProvider29isAccessToLocalComputerDeniedEv
_ZNK21AccessControlProvider9locationsEv
_ZNK25AuthenticationCredentials14hasCredentialsENS_4TypeE
_ZTI14FeatureManager
_ZTI14ServiceControl
_ZTI15VncServerClient
_ZTI17VncServerProtocol
_ZTI19VeyonServiceControl
_ZTI21AccessControlProvider
_ZTV14FeatureManager
_ZTV14ServiceControl
_ZTV15VncServerClient
_ZTV17VncServerProtocol
_ZTV19VeyonServiceControl
_ZTV21AccessControlProvider
_ZThn16_N21AccessControlProvider14controlFeatureE5QUuidN24FeatureProviderInterface9OperationERK4QMapI7QString8QVariantERK28ComputerControlInterfaceList
_ZThn16_N21AccessControlProvider20handleFeatureMessageE14QSharedPointerI24ComputerControlInterfaceERK14FeatureMessage
_ZThn16_N21AccessControlProviderD0Ev
_ZThn16_N21AccessControlProviderD1Ev
_ZThn16_NK21AccessControlProvider11featureListEv
_ZThn24_NK21AccessControlProvider11descriptionEv
_ZThn24_NK21AccessControlProvider3uidEv
_ZThn24_NK21AccessControlProvider4nameEv
_ZThn24_NK21AccessControlProvider6vendorEv
_ZThn24_NK21AccessControlProvider7versionEv
_ZThn24_NK21AccessControlProvider9copyrightEv
libvncclient.dll
```

### 4.10 Fragmento de desensamblado x86-64 real (plugins/windows-platform.dll, inicio de .text)

```asm
Disassembly of section .text:
000000036eff1000 <.text>:
  36eff1000: 41 55               push   %r13
  36eff1002: 41 54               push   %r12
  36eff1004: 55                  push   %rbp
  36eff1005: 57                  push   %rdi
  36eff1006: 56                  push   %rsi
  36eff1007: 53                  push   %rbx
  36eff1008: 48 83 ec 28         sub    $0x28,%rsp
  36eff100c: 48 89 cf            mov    %rcx,%rdi        ; arg1 (conv. x64 Windows: rcx,rdx,r8,r9)
  36eff100f: 4d 89 c5            mov    %r8,%r13         ; arg3
  36eff1012: 85 d2               test   %edx,%edx
  36eff1014: 0f 85 9e 00 00 00   jne    0x36eff10b8
```
(IAT de `CreateProcessAsUserW` en windows-platform.dll: offset 0x639ba.)

---

# 5. Mapa de capacidades → APIs importadas (windows-platform.dll)

| Capacidad | APIs clave (Win32) |
|-----------|--------------------|
| Control del servicio | OpenSCManagerW, CreateServiceW, DeleteService, StartServiceW, ControlService, ChangeServiceConfigW/2W, SetServiceStatus, StartServiceCtrlDispatcherW, RegisterServiceCtrlHandlerExW |
| Ejecutar como el usuario | WTSGetActiveConsoleSessionId, WTSEnumerateSessionsW, WTSQueryUserToken, WTSEnumerateProcessesW, LogonUserW, OpenProcessToken, DuplicateTokenEx, ImpersonateLoggedOnUser, RevertToSelf, AdjustTokenPrivileges, LookupPrivilegeValueW, CreateProcessAsUserW, CreateEnvironmentBlock |
| Inyección/bloqueo input | SendInput, keybd_event, MapVirtualKeyW, VkKeyScanW, ToAscii, GetAsyncKeyState, GetKeyState, SetWindowsHookExW, CallNextHookEx, UnhookWindowsHookEx, + interception.dll |
| Ventanas/escritorios/monitores | EnumWindows, FindWindowW, GetForegroundWindow, GetWindowTextW, OpenInputDesktop, SetThreadDesktop, CloseDesktop, SetLayeredWindowAttributes, SetWindowPos, ShowWindow, RedrawWindow, EnableWindow, EnumDisplayDevicesW, QueryDisplayConfig, DisplayConfigGetDeviceInfo |
| Sesiones/apagado | InitiateShutdownW, ExitWindowsEx, ProcessIdToSessionId |
| Dominio/LDAP | DsGetDcNameW, NetGroupEnum, NetUserGetGroups, NetLocalGroupEnum, GetUserNameExW |
| Registro/eventos | RegCreateKeyExW, RegOpenKeyExW, RegSetValueExW, RegCloseKey, RegisterEventSourceW, ReportEventW |
| Procesos/red | CreateToolhelp32Snapshot, Process32FirstW/NextW, OpenProcess, TerminateProcess, CreatePipe, DuplicateHandle, SetThreadExecutionState, IPHLPAPI (MAC/WOL), SETUPAPI (instalar driver) |

---

# 6. CÓDIGO FUENTE ÍNTEGRO (archivos clave, versión 4.11.4)

## 6.1 Autenticación — tipos y protocolo

### Archivo: `core/src/RfbVeyonAuth.h`

```cpp
/*
 * RfbVeyonAuth.h - types and names related to veyon-specific RFB
 *                  authentication type
 *
 * Copyright (c) 2017-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#pragma once

#include "VeyonCore.h"

static constexpr char rfbSecTypeVeyon = 40;

class VEYON_CORE_EXPORT RfbVeyonAuth
{
	Q_GADGET
public:
	enum Type
	{
		// invalid/null authentication type
		Invalid,

		// client has to sign some data to verify it's authority
		KeyFile = 3,

		// authentication is performed using given username and password
		Logon,

		// client has to prove its authenticity by knowing common token
		Token,
	} ;

	Q_ENUM(Type)

};
```

### Archivo: `core/src/CryptoCore.h`

```cpp
/*
 * CryptoCore.h - core functions for crypto features
 *
 * Copyright (c) 2017-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#pragma once

#include "VeyonCore.h"

#include <QtCrypto>

// clazy:excludeall=rule-of-three

class VEYON_CORE_EXPORT CryptoCore
{
public:
	using KeyGenerator = QCA::KeyGenerator;
	using PrivateKey = QCA::PrivateKey;
	using PublicKey = QCA::PublicKey;
	using SecureArray = QCA::SecureArray;
	using PlaintextPassword = SecureArray;

	enum {
		RsaKeySize = 4096,
		ChallengeSize = 128,
	};

	static constexpr QCA::EncryptionAlgorithm DefaultEncryptionAlgorithm = QCA::EME_PKCS1_OAEP;
	static constexpr QCA::SignatureAlgorithm DefaultSignatureAlgorithm = QCA::EMSA3_SHA512;

	CryptoCore();
	~CryptoCore();

	static QByteArray generateChallenge();

	QString encryptPassword( const PlaintextPassword& password ) const;
	PlaintextPassword decryptPassword( const QString& encryptedPassword ) const;

private:
	QCA::Initializer m_qcaInitializer;
	PrivateKey m_defaultPrivateKey;

};
```

### Archivo: `core/src/CryptoCore.cpp`

```cpp
/*
 * CryptoCore.cpp - core functions for crypto features
 *
 * Copyright (c) 2017-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include <QRandomGenerator>

#include "CryptoCore.h"

CryptoCore::CryptoCore() :
	m_qcaInitializer(),
	m_defaultPrivateKey()
{
	const auto features = QCA::supportedFeatures();

	vDebug() << "CryptoCore instance created - features supported by QCA" << qcaVersionStr() << features;

	if( features.contains( QStringLiteral( "rsa" ) ) == false )
	{
		qFatal( "CryptoCore: RSA not supported! Please install a QCA plugin which provides RSA support "
				"(e.g. packages such as libqca-qt5-2-plugins or qca-qt5-ossl)." );
	}

	m_defaultPrivateKey = PrivateKey::fromPEMFile( QStringLiteral(":/core/default-pkey.pem") );
}



CryptoCore::~CryptoCore()
{
	vDebug();
}



QByteArray CryptoCore::generateChallenge()
{
	static_assert(ChallengeSize % sizeof(quint32) == 0);

	using ChallengeWords = std::array<quint32, ChallengeSize / sizeof(quint32)>;

	ChallengeWords challenge{};
	QRandomGenerator::system()->fillRange(challenge.data(), challenge.size());

	return QByteArray(reinterpret_cast<const char*>(challenge.data()), ChallengeSize);
}



QString CryptoCore::encryptPassword( const PlaintextPassword& password ) const
{
	return QString::fromLatin1( m_defaultPrivateKey.toPublicKey().
								encrypt( password, DefaultEncryptionAlgorithm ).toByteArray().toHex() );
}



CryptoCore::PlaintextPassword CryptoCore::decryptPassword( const QString& encryptedPassword ) const
{
	PlaintextPassword decryptedPassword;

	if( PrivateKey( m_defaultPrivateKey ).decrypt( QByteArray::fromHex( encryptedPassword.toUtf8() ),
												   &decryptedPassword, DefaultEncryptionAlgorithm ) )
	{
		return decryptedPassword;
	}

	vCritical() << "failed to decrypt password!";

	return {};
}
```

### Archivo: `core/src/AuthenticationCredentials.h`

```cpp
/*
 * AuthenticationCredentials.h - class holding credentials for authentication
 *
 * Copyright (c) 2010-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#pragma once

#include "CryptoCore.h"

// clazy:excludeall=rule-of-three

class VEYON_CORE_EXPORT AuthenticationCredentials
{
public:
	using Token = CryptoCore::SecureArray;
	using Password = CryptoCore::SecureArray;

	enum class Type
	{
		None = 0x00,
		PrivateKey = 0x01,
		UserLogon = 0x02,
		Token = 0x04,
		AllTypes = PrivateKey | UserLogon | Token
	} ;

	Q_DECLARE_FLAGS(TypeFlags, Type)

	AuthenticationCredentials();
	AuthenticationCredentials( const AuthenticationCredentials &other );

	bool hasCredentials( Type credentialType ) const;

	// private key auth
	bool loadPrivateKey( const QString& privateKeyFile );
	bool setPrivateKey( const CryptoCore::PrivateKey& privateKey );
	const CryptoCore::PrivateKey& privateKey() const
	{
		return m_privateKey;
	}

	const QString& authenticationKeyName() const
	{
		return m_authenticationKeyName;
	}

	void setAuthenticationKeyName( const QString& authenticationKeyName )
	{
		m_authenticationKeyName = authenticationKeyName;
	}

	// user logon auth
	void setLogonUsername( const QString& username )
	{
		m_logonUsername = username;
	}

	void setLogonPassword( const Password& password )
	{
		m_logonPassword = password;
	}

	const QString& logonUsername() const
	{
		return m_logonUsername;
	}

	const Password& logonPassword() const
	{
		return m_logonPassword;
	}

	void setToken( const Token& token )
	{
		m_token = token;
	}

	const Token& token() const
	{
		return m_token;
	}

	void setInternalVncServerPassword( const Password& password )
	{
		m_internalVncServerPassword = password;
	}

	const Password& internalVncServerPassword() const
	{
		return m_internalVncServerPassword;
	}

private:
	CryptoCore::PrivateKey m_privateKey;
	QString m_authenticationKeyName;

	QString m_logonUsername;
	Password m_logonPassword;

	Token m_token;

	Password m_internalVncServerPassword;

} ;
```

### Archivo: `core/src/AuthenticationCredentials.cpp`

```cpp
/*
 * AuthenticationCredentials.cpp - class holding credentials for authentication
 *
 * Copyright (c) 2010-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307,
 * USA.
 */

#include "AuthenticationCredentials.h"


AuthenticationCredentials::AuthenticationCredentials() :
	m_privateKey(),
	m_logonUsername(),
	m_logonPassword(),
	m_token(),
	m_internalVncServerPassword()
{
}



AuthenticationCredentials::AuthenticationCredentials( const AuthenticationCredentials &other ) :
	m_privateKey( other.privateKey() ),
	m_authenticationKeyName( other.authenticationKeyName() ),
	m_logonUsername( other.logonUsername() ),
	m_logonPassword( other.logonPassword() ),
	m_token( other.token() ),
	m_internalVncServerPassword( other.internalVncServerPassword() )
{
}



bool AuthenticationCredentials::hasCredentials( Type type ) const
{
	switch( type )
	{
	case Type::PrivateKey:
		return m_privateKey.isNull() == false;

	case Type::UserLogon:
		return m_logonUsername.isEmpty() == false && m_logonPassword.isEmpty() == false;

	case Type::Token:
		return m_token.isEmpty() == false && m_token.size() == CryptoCore::ChallengeSize;

	default:
		break;
	}

	vCritical() << "no valid credential type given:" << TypeFlags( type );

	return false;
}



bool AuthenticationCredentials::loadPrivateKey( const QString& privateKeyFile )
{
	vDebug() << privateKeyFile;

	if( privateKeyFile.isEmpty() )
	{
		return false;
	}

	return setPrivateKey( CryptoCore::PrivateKey( privateKeyFile ) );
}



bool AuthenticationCredentials::setPrivateKey( const CryptoCore::PrivateKey& privateKey )
{
	if( privateKey.isNull() == false && privateKey.isPrivate() )
	{
		m_privateKey = privateKey;

		return true;
	}

	return false;
}
```

## 6.2 Handshake — lado CLIENTE (profesor)

### Archivo: `core/src/VeyonConnection.cpp`

```cpp
/*
 * VeyonConnection.cpp - implementation of VeyonConnection
 *
 * Copyright (c) 2008-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include "rfb/rfbclient.h"

#include "AuthenticationProxy.h"
#include "CryptoCore.h"
#include "PlatformUserFunctions.h"
#include "SocketDevice.h"
#include "VariantArrayMessage.h"
#include "VeyonConfiguration.h"
#include "VeyonConnection.h"
#include "VncFeatureMessageEvent.h"


static rfbClientProtocolExtension* __veyonProtocolExt = nullptr;
static const uint32_t __veyonSecurityTypes[2] = { rfbSecTypeVeyon, 0 };


rfbBool handleVeyonMessage( rfbClient* client, rfbServerToClientMsg* msg )
{
	auto connection = reinterpret_cast<VeyonConnection *>( VncConnection::clientData( client, VeyonConnection::VeyonConnectionTag ) );
	if( connection )
	{
		return connection->handleServerMessage( client, msg->type ) ? TRUE : FALSE;
	}

	return FALSE;
}



VeyonConnection::VeyonConnection() :
	m_veyonAuthType(RfbVeyonAuth::Logon)
{
	if( __veyonProtocolExt == nullptr )
	{
		__veyonProtocolExt = new rfbClientProtocolExtension;
		__veyonProtocolExt->encodings = nullptr;
		__veyonProtocolExt->handleEncoding = nullptr;
		__veyonProtocolExt->handleMessage = handleVeyonMessage;
		__veyonProtocolExt->securityTypes = __veyonSecurityTypes;
		__veyonProtocolExt->handleAuthentication = handleSecTypeVeyon;

		rfbClientRegisterExtension( __veyonProtocolExt );
	}

	if( VeyonCore::config().authenticationMethod() == VeyonCore::AuthenticationMethod::KeyFileAuthentication )
	{
		m_veyonAuthType = RfbVeyonAuth::KeyFile;
	}

	connect( m_vncConnection, &VncConnection::connectionPrepared, this, &VeyonConnection::registerConnection, Qt::DirectConnection );
	connect( m_vncConnection, &VncConnection::destroyed, VeyonCore::instance(), [this]() {
		delete this;
	} );
}



VeyonConnection::~VeyonConnection()
{
	delete m_authenticationProxy;
}



void VeyonConnection::stopAndDeleteLater()
{
	unregisterConnection();

	if( m_vncConnection )
	{
		m_vncConnection->stopAndDeleteLater();
		m_vncConnection = nullptr;
	}
}



void VeyonConnection::sendFeatureMessage(const FeatureMessage& featureMessage)
{
	if( m_vncConnection )
	{
		m_vncConnection->enqueueEvent(new VncFeatureMessageEvent(featureMessage));
	}
}



bool VeyonConnection::handleServerMessage( rfbClient* client, uint8_t msg )
{
	if( msg == FeatureMessage::RfbMessageType )
	{
		SocketDevice socketDev( VncConnection::libvncClientDispatcher, client );
		FeatureMessage featureMessage;
		if( featureMessage.receive( &socketDev ) == false )
		{
			vDebug() << "could not receive feature message";

			return false;
		}

		vDebug() << qUtf8Printable(QStringLiteral("%1:%2").arg(QString::fromUtf8(client->serverHost)).arg(client->serverPort))
				 << featureMessage;

		Q_EMIT featureMessageReceived( featureMessage );

		return true;
	}
	else
	{
		vCritical() << "unknown message type" << static_cast<int>( msg )
					<< "from server. Closing connection. Will re-open it later.";
	}

	return false;
}



void VeyonConnection::registerConnection()
{
	if( m_vncConnection )
	{
		m_vncConnection->setClientData( VeyonConnectionTag, this );
	}
}



void VeyonConnection::unregisterConnection()
{
	if( m_vncConnection )
	{
		m_vncConnection->setClientData( VeyonConnectionTag, nullptr );
	}
}



rfbBool VeyonConnection::handleSecTypeVeyon( rfbClient* client, uint32_t authScheme )
{
	if( authScheme != rfbSecTypeVeyon )
	{
		return FALSE;
	}

	hookPrepareAuthentication( client );

	auto connection = static_cast<VeyonConnection *>( VncConnection::clientData( client, VeyonConnectionTag ) );
	if( connection == nullptr )
	{
		return FALSE;
	}

	const auto proxy = connection->m_authenticationProxy;

	SocketDevice socketDevice( VncConnection::libvncClientDispatcher, client );
	VariantArrayMessage message( &socketDevice );
	if( message.receive() == false )
	{
		vDebug() << QThread::currentThreadId() << "invalid authentication message received";
		if( proxy )
		{
			proxy->notifyProtocolError();
		}
		return FALSE;
	}

	const auto authTypeCount = message.read().toInt();

	if (authTypeCount == 0 || authTypeCount > 32)
	{
		vDebug() << QThread::currentThreadId() << "no or too many auth types received";
		if( proxy )
		{
			proxy->notifyProtocolError();
		}
		return FALSE;
	}

	QList<RfbVeyonAuth::Type> authTypes;
	authTypes.reserve( authTypeCount );

	for( int i = 0; i < authTypeCount; ++i )
	{
		const auto authType = message.read().value<RfbVeyonAuth::Type>();
		if( authType == RfbVeyonAuth::Type::Invalid )
		{
			vDebug() << QThread::currentThreadId() << "invalid auth type received";
			if( proxy )
			{
				proxy->notifyProtocolError();
			}
			return FALSE;
		}
		authTypes.append( authType );
	}

	if( proxy )
	{
		proxy->setAuthenticationTypes( authTypes );
	}

	vDebug() << QThread::currentThreadId() << "received authentication types:" << authTypes;

	auto chosenAuthType = authTypes.first();
	if( proxy )
	{
		chosenAuthType = proxy->initCredentials();
	}
	// look whether the VncConnection recommends a specific authentication type (e.g. RfbVeyonAuth::Token
	// when running as demo client)
	else if( authTypes.contains( connection->veyonAuthType() ) )
	{
		chosenAuthType = connection->veyonAuthType();
	}

	if( chosenAuthType == RfbVeyonAuth::Invalid )
	{
		return FALSE;
	}

	vDebug() << QThread::currentThreadId() << "chose authentication type:" << authTypes;

	VariantArrayMessage authReplyMessage( &socketDevice );

	authReplyMessage.write( chosenAuthType );

	// send username which is used when displaying an access confirm dialog
	if( connection->authenticationCredentials().hasCredentials( AuthenticationCredentials::Type::UserLogon ) )
	{
		authReplyMessage.write( connection->authenticationCredentials().logonUsername() );
	}
	else
	{
		authReplyMessage.write(VeyonCore::platform().userFunctions().queryCurrentUserProperty(PlatformUserFunctions::UserProperty::LoginName));
	}

	authReplyMessage.send();

	VariantArrayMessage authAckMessage( &socketDevice );
	if( authAckMessage.receive() == false )
	{
		vWarning() << QThread::currentThreadId() << "failed to receive authentication acknowledge";
		return FALSE;
	}

	switch( chosenAuthType )
	{
	case RfbVeyonAuth::KeyFile:
		if( connection->authenticationCredentials().hasCredentials( AuthenticationCredentials::Type::PrivateKey ) )
		{
			VariantArrayMessage challengeReceiveMessage( &socketDevice );
			challengeReceiveMessage.receive();
			const auto challenge = challengeReceiveMessage.read().toByteArray();

			if( challenge.size() != CryptoCore::ChallengeSize )
			{
				vCritical() << QThread::currentThreadId() << "challenge size mismatch!";
				return FALSE;
			}

			// create local copy of private key so we can modify it within our own thread
			auto key = connection->authenticationCredentials().privateKey();
			if( key.isNull() || key.canSign() == false )
			{
				vCritical() << QThread::currentThreadId() << "invalid private key!";
				return FALSE;
			}

			const auto signature = key.signMessage( challenge, CryptoCore::DefaultSignatureAlgorithm );

			VariantArrayMessage challengeResponseMessage( &socketDevice );
			challengeResponseMessage.write( connection->authenticationCredentials().authenticationKeyName() );
			challengeResponseMessage.write( signature );
			challengeResponseMessage.send();
		}
		break;

	case RfbVeyonAuth::Logon:
	{
		VariantArrayMessage publicKeyMessage( &socketDevice );
		publicKeyMessage.receive();

		CryptoCore::PublicKey publicKey = CryptoCore::PublicKey::fromPEM( publicKeyMessage.read().toString() );

		if( publicKey.canEncrypt() == false )
		{
			vCritical() << QThread::currentThreadId() << "can't encrypt with given public key!";
			return FALSE;
		}

		CryptoCore::SecureArray plainTextPassword( connection->authenticationCredentials().logonPassword() );
		CryptoCore::SecureArray encryptedPassword = publicKey.encrypt( plainTextPassword, CryptoCore::DefaultEncryptionAlgorithm );
		if( encryptedPassword.isEmpty() )
		{
			vCritical() << QThread::currentThreadId() << "password encryption failed!";
			return FALSE;
		}

		VariantArrayMessage passwordResponse( &socketDevice );
		passwordResponse.write( encryptedPassword.toByteArray() );
		passwordResponse.send();
		break;
	}

	case RfbVeyonAuth::Token:
	{
		VariantArrayMessage tokenAuthMessage( &socketDevice );
		tokenAuthMessage.write( connection->authenticationCredentials().token().toByteArray() );
		tokenAuthMessage.send();
		break;
	}

	default:
		// nothing to do - we just get accepted
		break;
	}

	return TRUE;
}



void VeyonConnection::hookPrepareAuthentication( rfbClient* client )
{
	auto connection = static_cast<VncConnection *>( VncConnection::clientData( client, VncConnection::VncConnectionTag ) );
	if( connection )
	{
		// set our internal flag which indicates that we basically have communication with the client
		// which means that the host is reachable
		connection->setServerReachable();
	}
}



AuthenticationCredentials VeyonConnection::authenticationCredentials() const
{
	if( m_authenticationProxy )
	{
		return m_authenticationProxy->credentials();
	}

	return VeyonCore::authenticationCredentials();
}
```

## 6.3 Handshake — lado SERVIDOR (alumno)

### Archivo: `core/src/VncServerProtocol.cpp`

```cpp
/*
 * VncServerProtocol.cpp - implementation of the VncServerProtocol class
 *
 * Copyright (c) 2017-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include "rfb/rfbproto.h"

#include <cstdio>

#include <QHostAddress>
#include <QRegularExpression>
#include <QTcpSocket>

#include "AccessControlProvider.h"
#include "BuiltinFeatures.h"
#include "VariantArrayMessage.h"
#include "VncServerClient.h"
#include "VncServerProtocol.h"



VncServerProtocol::VncServerProtocol(QTcpSocket* socket, VncServerClient* client) :
	m_socket( socket ),
	m_client( client ),
	m_serverInitMessage()
{
	m_client->setHostAddress(m_socket->peerAddress().toString());
	m_client->setAccessControlState( VncServerClient::AccessControlState::Init );
}



VncServerProtocol::State VncServerProtocol::state() const
{
	return m_client->protocolState();
}



void VncServerProtocol::start()
{
	if( state() == State::Disconnected )
	{
		// One extra byte for snprintf's terminator, otherwise it replaces the trailing newline
		std::array<char, sz_rfbProtocolVersionMsg + 1> protocol{};

		std::snprintf(protocol.data(), protocol.size(), rfbProtocolVersionFormat, 3, 8); // Flawfinder: ignore

		m_socket->write(protocol.data(), sz_rfbProtocolVersionMsg);

		setState( State::Protocol );
	}
}



bool VncServerProtocol::read()
{
	switch( state() )
	{
	case State::Protocol:
		return readProtocol();

	case State::SecurityInit:
		return receiveSecurityTypeResponse();

	case State::AuthenticationTypes:
		return receiveAuthenticationTypeResponse();

	case State::Authenticating:
		return receiveAuthenticationMessage();

	case State::AccessControl:
		return processAccessControl();

	case State::FramebufferInit:
		return processFramebufferInit();

	case State::Close:
		vDebug() << "closing connection per protocol state";
		m_socket->close();
		break;

	case State::Closing:
		if (m_socket->isOpen())
		{
			m_socket->readAll();
		}
		else
		{
			setState(State::Close);
		}
		return false;

	default:
		break;
	}

	return false;
}



void VncServerProtocol::setState( VncServerProtocol::State state )
{
	m_client->setProtocolState( state );
}



bool VncServerProtocol::readProtocol()
{
	// More protocol data may already be queued when TCP combines packets.
	if( m_socket->bytesAvailable() >= sz_rfbProtocolVersionMsg )
	{
		const auto protocol = m_socket->read( sz_rfbProtocolVersionMsg );

		if( protocol.size() != sz_rfbProtocolVersionMsg )
		{
			vCritical() << "protocol initialization failed";
			m_socket->close();
			return false;
		}

		static const QRegularExpression rfbRX{QStringLiteral("RFB (\\d\\d\\d)\\.(\\d\\d\\d)\n")};
		const auto match = rfbRX.match(QString::fromUtf8(protocol));
		if( match.hasMatch() == false || match.captured(1).toInt() != 3 ||
			match.captured(2).toInt() < 7 || match.captured(2).toInt() > 8 )
		{
			vCritical() << "invalid protocol version";
			m_socket->close();
			return false;
		}

		setState( State::SecurityInit );

		return sendSecurityTypes();
	}

	return false;
}



bool VncServerProtocol::sendSecurityTypes()
{
	// send list of supported security types
	const char securityTypeList[2] = { 1, rfbSecTypeVeyon }; // Flawfinder: ignore
	m_socket->write( securityTypeList, sizeof( securityTypeList ) );

	return true;
}



bool VncServerProtocol::receiveSecurityTypeResponse()
{
	if( m_socket->bytesAvailable() >= 1 )
	{
		char chosenSecurityType = 0;

		if( m_socket->read( &chosenSecurityType, sizeof(chosenSecurityType) ) != sizeof(chosenSecurityType) ||
				chosenSecurityType != rfbSecTypeVeyon )
		{
			vCritical() << "protocol initialization failed";
			m_socket->close();

			return false;
		}

		setState(State::AuthenticationTypes);

		return sendAuthenticationTypes();
	}

	return false;
}



bool VncServerProtocol::sendAuthenticationTypes()
{
	const auto authTypes = supportedAuthTypes();

	VariantArrayMessage message( m_socket );
	message.write(int(authTypes.count()));

	for( auto authType : authTypes )
	{
		message.write( authType );
	}

	return message.send();
}



bool VncServerProtocol::receiveAuthenticationTypeResponse()
{
	VariantArrayMessage message( m_socket );

	if( message.isReadyForReceive() && message.receive() )
	{
		const auto chosenAuthType = message.read().value<RfbVeyonAuth::Type>();

		if( supportedAuthTypes().contains( chosenAuthType ) == false )
		{
			vCritical() << "unsupported authentication type chosen by client!";
			m_socket->close();

			return false;
		}

		const auto username = message.read().toString();
		constexpr int MaxUsernameLength = 256;
		if (username.length() > MaxUsernameLength)
		{
			vCritical() << "username exceeds maximum length of" << MaxUsernameLength;
			m_socket->close();
			return false;
		}

		m_client->setAuthType( chosenAuthType );
		m_client->setUsername( username );

		setState( State::Authenticating );

		// send auth ack message
		VariantArrayMessage( m_socket ).send();

		// init authentication
		VariantArrayMessage dummyMessage( m_socket );
		processAuthentication( dummyMessage );
	}

	return false;
}



bool VncServerProtocol::receiveAuthenticationMessage()
{
	VariantArrayMessage message( m_socket );

	if( message.isReadyForReceive() && message.receive() )
	{
		return processAuthentication( message );
	}

	return false;
}



bool VncServerProtocol::processAuthentication( VariantArrayMessage& message )
{
	processAuthenticationMessage( message );

	switch( m_client->authState() )
	{
	case VncServerClient::AuthState::Successful:
	{
		const auto authResult = qToBigEndian<uint32_t>(rfbVncAuthOK);
		m_socket->write( reinterpret_cast<const char *>( &authResult ), sizeof(authResult) );

		setState( State::AccessControl );
		return true;
	}

	case VncServerClient::AuthState::Failed:
		vCritical() << "authentication failed - closing connection";
		m_socket->close();

		return false;

	default:
		break;
	}

	return false;
}



bool VncServerProtocol::processAccessControl()
{
	performAccessControl();

	switch( m_client->accessControlState() )
	{
	case VncServerClient::AccessControlState::Successful:
		setState( State::FramebufferInit );
		return true;

	case VncServerClient::AccessControlState::Pending:
	case VncServerClient::AccessControlState::Waiting:
		break;

	default:
		vCritical() << "access control failed - closing connection";
		m_socket->read(sz_rfbClientInitMsg);
		sendEmptyServerInitMessage();
		sendFailedAccessControlDetails();
		return true;
	}

	return false;
}



void VncServerProtocol::sendFailedAccessControlDetails()
{
	VeyonCore::builtinFeatures().accessControlProvider().sendDetails(m_socket, client()->accessControlDetails());

	QObject::connect (&m_accessControlDetailsSendTimer, &QTimer::timeout, m_socket, [this]() {
		VeyonCore::builtinFeatures().accessControlProvider().sendDetails(m_socket, client()->accessControlDetails());
	});
	QTimer::singleShot(AccessControlCloseDelay, m_socket, &QAbstractSocket::close);
	m_accessControlDetailsSendTimer.start(AccessControlDetailsSendInterval);

	setState(State::Closing);
}



void VncServerProtocol::sendEmptyServerInitMessage()
{
	rfbServerInitMsg message{};
	m_socket->write(reinterpret_cast<const char *>(&message), sizeof(message));
}



bool VncServerProtocol::processFramebufferInit()
{
	if( m_socket->bytesAvailable() >= sz_rfbClientInitMsg &&
			m_serverInitMessage.isEmpty() == false )
	{
		// just read client init message without further evaluation
		m_socket->read( sz_rfbClientInitMsg );

		m_socket->write( m_serverInitMessage );

		setState( State::Running );

		return true;
	}

	return false;
}
```

### Archivo: `server/src/VeyonServerProtocol.cpp`

```cpp
/*
 * VeyonServerProtocol.cpp - implementation of the VeyonServerProtocol class
 *
 * Copyright (c) 2017-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include <QTcpSocket>

#include "ServerAuthenticationManager.h"
#include "ServerAccessControlManager.h"
#include "VeyonServerProtocol.h"


VeyonServerProtocol::VeyonServerProtocol( QTcpSocket* socket,
										  VncServerClient* client,
										  ServerAuthenticationManager& serverAuthenticationManager,
										  ServerAccessControlManager& serverAccessControlManager ) :
	VncServerProtocol( socket, client ),
	m_serverAuthenticationManager( serverAuthenticationManager ),
	m_serverAccessControlManager( serverAccessControlManager )
{
}



QVector<RfbVeyonAuth::Type> VeyonServerProtocol::supportedAuthTypes() const
{
	return m_serverAuthenticationManager.supportedAuthTypes();
}



void VeyonServerProtocol::processAuthenticationMessage(VariantArrayMessage &message)
{
	m_serverAuthenticationManager.processAuthenticationMessage( client(), message );
}



void VeyonServerProtocol::performAccessControl()
{
	// perform access control via ServerAccessControl manager if either
	// client just entered access control or is still waiting to be
	// processed (e.g. desktop access dialog already active for a different connection)
	if( client()->accessControlState() == VncServerClient::AccessControlState::Init ||
			client()->accessControlState() == VncServerClient::AccessControlState::Waiting )
	{
		m_serverAccessControlManager.addClient( client() );
	}
}
```

### Archivo: `server/src/ServerAuthenticationManager.cpp`

```cpp
/*
 * ServerAuthenticationManager.cpp - implementation of ServerAuthenticationManager
 *
 * Copyright (c) 2017-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include "AuthenticationCredentials.h"
#include "ServerAuthenticationManager.h"
#include "CryptoCore.h"
#include "Filesystem.h"
#include "PlatformUserFunctions.h"
#include "VariantArrayMessage.h"
#include "VeyonConfiguration.h"


ServerAuthenticationManager::ServerAuthenticationManager( QObject* parent ) :
	QObject( parent )
{
}



QVector<RfbVeyonAuth::Type> ServerAuthenticationManager::supportedAuthTypes() const
{
	QVector<RfbVeyonAuth::Type> authTypes;

	if( VeyonCore::config().authenticationMethod() == VeyonCore::AuthenticationMethod::KeyFileAuthentication )
	{
		authTypes.append( RfbVeyonAuth::KeyFile );
	}

	if( VeyonCore::config().authenticationMethod() == VeyonCore::AuthenticationMethod::LogonAuthentication )
	{
		authTypes.append( RfbVeyonAuth::Logon );
	}

	if( VeyonCore::authenticationCredentials().hasCredentials( AuthenticationCredentials::Type::Token ) )
	{
		authTypes.append( RfbVeyonAuth::Token );
	}

	return authTypes;
}



void ServerAuthenticationManager::processAuthenticationMessage( VncServerClient* client,
																VariantArrayMessage& message )
{
	vDebug() << "state" << client->authState()
			 << "type" << client->authType()
			 << "host" << client->hostAddress()
			 << "user" << client->username();

	switch( client->authType() )
	{
		// authentication via DSA-challenge/-response
	case RfbVeyonAuth::KeyFile:
		client->setAuthState( performKeyAuthentication( client, message ) );
		break;

	case RfbVeyonAuth::Logon:
		client->setAuthState( performLogonAuthentication( client, message ) );
		break;

	case RfbVeyonAuth::Token:
		client->setAuthState( performTokenAuthentication( client, message ) );
		break;

	default:
		// unknown or unsupported auth type
		client->setAuthState( VncServerClient::AuthState::Failed );
		break;
	}

	switch( client->authState() )
	{
	case VncServerClient::AuthState::Failed:
	case VncServerClient::AuthState::Successful:
		Q_EMIT finished( client );
		break;
	default:
		break;
	}
}



VncServerClient::AuthState ServerAuthenticationManager::performKeyAuthentication( VncServerClient* client,
																				  VariantArrayMessage& message )
{
	switch( client->authState() )
	{
	case VncServerClient::AuthState::Init:
		client->setChallenge( CryptoCore::generateChallenge() );
		if( VariantArrayMessage( message.ioDevice() ).write( client->challenge() ).send() == false )
		{
			vWarning() << "failed to send challenge";
			return VncServerClient::AuthState::Failed;
		}
		return VncServerClient::AuthState::Challenge;

	case VncServerClient::AuthState::Challenge:
	{
		// get authentication key name
		const auto authKeyName = message.read().toString(); // Flawfinder: ignore

		if( VeyonCore::isAuthenticationKeyNameValid( authKeyName ) == false )
		{
			vDebug() << "invalid auth key name!";
			return VncServerClient::AuthState::Failed;
		}

		// now try to verify received signed data using public key of the user
		// under which the client claims to run
		const auto signature = message.read().toByteArray();

		// Validate signature size to prevent DoS attacks
		// RSA-4096 signatures are exactly 512 bytes (4096 bits / 8)
		// 8KB limit provides headroom for encoding overhead, metadata, or future algorithms
		constexpr int MaxSignatureSize = 8192;
		if (signature.size() > MaxSignatureSize)
		{
			vWarning() << "signature size exceeds maximum of" << MaxSignatureSize << "bytes";
			return VncServerClient::AuthState::Failed;
		}

		const auto publicKeyPath = VeyonCore::filesystem().publicKeyPath( authKeyName );

		CryptoCore::PublicKey publicKey( publicKeyPath );
		if( publicKey.isNull() || publicKey.isPublic() == false )
		{
			vWarning() << "failed to load public key from" << publicKeyPath;
			return VncServerClient::AuthState::Failed;
		}

		vDebug() << "loaded public key from" << publicKeyPath;
		if( publicKey.verifyMessage( client->challenge(), signature, CryptoCore::DefaultSignatureAlgorithm ) == false )
		{
			vWarning() << "FAIL";
			return VncServerClient::AuthState::Failed;
		}

		vDebug() << "SUCCESS";
		return VncServerClient::AuthState::Successful;
	}

	default:
		break;
	}

	return VncServerClient::AuthState::Failed;
}



VncServerClient::AuthState ServerAuthenticationManager::performLogonAuthentication( VncServerClient* client,
																					VariantArrayMessage& message )
{
	switch( client->authState() )
	{
	case VncServerClient::AuthState::Init:
		client->setPrivateKey( CryptoCore::KeyGenerator().createRSA( CryptoCore::RsaKeySize ) );

		if( VariantArrayMessage( message.ioDevice() ).write( client->privateKey().toPublicKey().toPEM() ).send() )
		{
			return VncServerClient::AuthState::Password;
		}

		vDebug() << "failed to send public key";
		return VncServerClient::AuthState::Failed;

	case VncServerClient::AuthState::Password:
	{
		auto privateKey = client->privateKey();

		CryptoCore::SecureArray encryptedPassword( message.read().toByteArray() ); // Flawfinder: ignore
		constexpr auto MaxEncryptedPasswordSize = 8192;
		if( encryptedPassword.isEmpty() || encryptedPassword.size() > MaxEncryptedPasswordSize )
		{
			vWarning() << "invalid encrypted password size" << encryptedPassword.size();
			return VncServerClient::AuthState::Failed;
		}

		CryptoCore::SecureArray decryptedPassword;

		if( privateKey.decrypt( encryptedPassword,
								&decryptedPassword,
								CryptoCore::DefaultEncryptionAlgorithm ) == false )
		{
			vWarning() << "failed to decrypt password";
			return VncServerClient::AuthState::Failed;
		}

		vInfo() << "authenticating user" << client->username();

		if( VeyonCore::platform().userFunctions().authenticate( client->username(), decryptedPassword ) )
		{
			vDebug() << "SUCCESS";
			return VncServerClient::AuthState::Successful;
		}

		vDebug() << "FAIL";
		return VncServerClient::AuthState::Failed;
	}

	default:
		break;
	}

	return VncServerClient::AuthState::Failed;
}



VncServerClient::AuthState ServerAuthenticationManager::performTokenAuthentication( VncServerClient* client,
																					VariantArrayMessage& message )
{
	switch( client->authState() )
	{
	case VncServerClient::AuthState::Init:
		return VncServerClient::AuthState::Token;

	case VncServerClient::AuthState::Token:
	{
		const auto tokenData = message.read().toByteArray();

		// Validate token size to prevent DoS attacks
		constexpr int MaxTokenSize = 4096; // Reasonable maximum for authentication tokens
		if (tokenData.size() > MaxTokenSize)
		{
			vWarning() << "token size exceeds maximum of" << MaxTokenSize << "bytes";
			return VncServerClient::AuthState::Failed;
		}

		const auto token = AuthenticationCredentials::Token( tokenData );

		if( VeyonCore::authenticationCredentials().hasCredentials( AuthenticationCredentials::Type::Token ) &&
				token == VeyonCore::authenticationCredentials().token() )
		{
			vDebug() << "SUCCESS";
			return VncServerClient::AuthState::Successful;
		}

		vDebug() << "FAIL";
		return VncServerClient::AuthState::Failed;
	}

	default:
		break;
	}

	return VncServerClient::AuthState::Failed;
}
```

## 6.4 Mecanismo de suplantación de sesión (Windows)

### Archivo: `plugins/platform/windows/WindowsCoreFunctions.cpp`

```cpp
/*
 * WindowsCoreFunctions.cpp - implementation of WindowsCoreFunctions class
 *
 * Copyright (c) 2017-2026 Tobias Junghans <tobydox@veyon.io>
 *
 * This file is part of Veyon - https://veyon.io
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program (see COPYING); if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

#include <QGuiApplication>
#include <QScreen>
#include <QWidget>
#include <qpa/qplatformnativeinterface.h>

#include <iostream>
#include <shlobj.h>
#include <userenv.h>
#include <sddl.h>
#include <tlhelp32.h>

#include "StandardInputReader.h"
#include "VeyonConfiguration.h"
#include "WindowsCoreFunctions.h"
#include "WindowsPlatformConfiguration.h"
#include "WindowsPlatformPlugin.h"
#include "WtsSessionManager.h"
#include "XEventLog.h"


static bool configureSoftwareSAS( bool enabled )
{
	HKEY hkLocal;
	HKEY hkLocalKey;
	DWORD dw;
	if( RegCreateKeyEx( HKEY_LOCAL_MACHINE,
						L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies",
						0, REG_NONE, REG_OPTION_NON_VOLATILE,
						KEY_READ, nullptr, &hkLocal, &dw ) != ERROR_SUCCESS)
	{
		return false;
	}

	if( RegOpenKeyEx( hkLocal,
					  L"System",
					  0, KEY_WRITE | KEY_READ,
					  &hkLocalKey ) != ERROR_SUCCESS )
	{
		RegCloseKey( hkLocal );
		return false;
	}

	LONG pref = enabled ? 1 : 0;
	RegSetValueEx( hkLocalKey, L"SoftwareSASGeneration", 0, REG_DWORD, reinterpret_cast<LPBYTE>( &pref ), sizeof(pref) );
	RegCloseKey( hkLocalKey );
	RegCloseKey( hkLocal );

	return true;
}


class StandardInputReaderThread : public QThread
{
public:
	StandardInputReaderThread(StandardInputReader* reader, QObject* parent) :
		QThread(parent),
		m_reader(reader)
	{
	}

protected:
	void run() override
	{
		std::ios_base::sync_with_stdio(false);

		while (isInterruptionRequested() == false)
		{
			std::string line;
			if (std::getline(std::cin, line) && m_reader)
			{
				m_reader->lineRead(QString::fromStdString(line));
			}
			else
			{
				vCritical() << "failed to read from stdin or EOF reached";
			}
			QThread::msleep(10);
		}
	}

private:
	QPointer<StandardInputReader> m_reader;
};


WindowsCoreFunctions::~WindowsCoreFunctions()
{
	delete m_eventLog;
}



bool WindowsCoreFunctions::applyConfiguration()
{
	WindowsPlatformConfiguration config( &VeyonCore::config() );

	if( configureSoftwareSAS( config.isSoftwareSASEnabled() ) == false )
	{
		vCritical() << WindowsPlatformConfiguration::tr( "Could not change the setting for SAS generation by software. "
														 "Sending Ctrl+Alt+Del via remote control will not work!" );
		return false;
	}

	return true;
}



void WindowsCoreFunctions::initNativeLoggingSystem( const QString& appName )
{
	SetConsoleOutputCP( CP_UTF8 );
	setvbuf( stdout, nullptr, _IOFBF, ConsoleOutputBufferSize );
	setvbuf( stderr, nullptr, _IOFBF, ConsoleOutputBufferSize );

	m_eventLog = new CXEventLog( toConstWCharArray( appName ) );
}



void WindowsCoreFunctions::writeToNativeLoggingSystem( const QString& message, Logger::LogLevel loglevel )
{
	int messageType = -1;

	switch( loglevel )
	{
	case Logger::LogLevel::Critical:
	case Logger::LogLevel::Error: messageType = EVENTLOG_ERROR_TYPE; break;
	case Logger::LogLevel::Warning: messageType = EVENTLOG_WARNING_TYPE; break;
	default:
		break;
	}

	if( messageType > 0 && m_eventLog )
	{
		m_eventLog->Write( static_cast<WORD>( messageType ), toConstWCharArray( message ) );
	}
}



StandardInputReader* WindowsCoreFunctions::createStandardInputReader(QObject* parent)
{
	auto reader = new StandardInputReader(parent);
	auto thread = new StandardInputReaderThread(reader, parent);

	QObject::connect(reader, &QObject::destroyed, thread, &QThread::requestInterruption);
	QObject::connect(thread, &QThread::finished, reader, &QThread::deleteLater);

	thread->start();

	return reader;
}



void WindowsCoreFunctions::reboot()
{
	enablePrivilege( SE_SHUTDOWN_NAME, true );
	InitiateShutdown( nullptr, nullptr, 0, ShutdownFlags | SHUTDOWN_RESTART, ShutdownReason );
}



void WindowsCoreFunctions::powerDown( bool installUpdates )
{
	enablePrivilege( SE_SHUTDOWN_NAME, true );
	InitiateShutdown( nullptr, nullptr, 0,
					  ShutdownFlags | SHUTDOWN_POWEROFF | ( installUpdates ? SHUTDOWN_INSTALL_UPDATES : 0 ),
					  ShutdownReason );
}



static QWindow* windowForWidget( const QWidget* widget )
{
	QWindow* window = widget->windowHandle();
	if( window )
	{
		return window;
	}

	const QWidget* nativeParent = widget->nativeParentWidget();
	if( nativeParent )
	{
		return nativeParent->windowHandle();
	}

	return nullptr;
}



void WindowsCoreFunctions::raiseWindow( QWidget* widget, bool stayOnTop )
{
	widget->activateWindow();
	widget->raise();

	auto window = windowForWidget( widget );
	if( window )
	{
		auto windowHandle = HWND( QGuiApplication::platformNativeInterface()->
								  nativeResourceForWindow( QByteArrayLiteral( "handle" ), window ) );

		SetWindowPos( windowHandle, stayOnTop ? HWND_TOPMOST : HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE );
	}
}



void WindowsCoreFunctions::disableScreenSaver()
{
	for( size_t i = 0; i < ScreenSaverSettingsCount; ++i )
	{
		SystemParametersInfo( ScreenSaverSettingsGetList.at(i), 0, &m_screenSaverSettings.at(i), 0 );
		SystemParametersInfo( ScreenSaverSettingsSetList.at(i), 0, nullptr, 0 );
	}

	SetThreadExecutionState( ES_CONTINUOUS | ES_DISPLAY_REQUIRED );
}



void WindowsCoreFunctions::restoreScreenSaverSettings()
{
	for( size_t i = 0; i < ScreenSaverSettingsCount; ++i )
	{
		SystemParametersInfo( ScreenSaverSettingsSetList.at(i), m_screenSaverSettings.at(i), nullptr, 0 );
	}

	SetThreadExecutionState( ES_CONTINUOUS );
}



void WindowsCoreFunctions::setSystemUiState( bool enabled )
{
	WindowsPlatformConfiguration config( &VeyonCore::config() );

	if( config.hideTaskbarForScreenLock() )
	{
		setTaskbarState( enabled );
	}

	if( config.hideStartMenuForScreenLock() )
	{
		setStartMenuState( enabled );
	}

	if( config.hideDesktopForScreenLock() )
	{
		setDesktopState( enabled );
	}
}



QString WindowsCoreFunctions::activeDesktopName()
{
	QString desktopName;

	auto desktopHandle = GetThreadDesktop( GetCurrentThreadId() );

	std::array<wchar_t, MAX_PATH> inputDesktopName{};
	if (GetUserObjectInformation(desktopHandle, UOI_NAME, inputDesktopName.data(), inputDesktopName.size() * sizeof(wchar_t), nullptr))
	{
		desktopName = QString( QStringLiteral( "winsta0\\%1" ) ).arg( QString::fromWCharArray( inputDesktopName.data() ) );
	}

	return desktopName;
}



bool WindowsCoreFunctions::isRunningAsAdmin() const
{
	BOOL runningAsAdmin = false;
	SmartSID adminGroupSid;

	// allocate and initialize a SID of the administrators group.
	SID_IDENTIFIER_AUTHORITY NtAuthority = { SECURITY_NT_AUTHORITY };
	if (AllocateAndInitializeSid(
			&NtAuthority,
			2,
			SECURITY_BUILTIN_DOMAIN_RID,
			DOMAIN_ALIAS_RID_ADMINS,
			0, 0, 0, 0, 0, 0,
			adminGroupSid.put()))
	{
		// determine whether the SID of administrators group is enabled in
		// the primary access token of the process.
		CheckTokenMembership(nullptr, adminGroupSid.get(), &runningAsAdmin);
	}

	return runningAsAdmin;
}



bool WindowsCoreFunctions::runProgramAsAdmin( const QString& program, const QStringList& parameters )
{
	const auto parametersJoined = parameters.join( QLatin1Char(' ') );

	SHELLEXECUTEINFO sei{};
	sei.cbSize = sizeof(sei);
	sei.lpVerb = L"runas";
	sei.lpFile = toConstWCharArray( program );
	sei.hwnd = GetForegroundWindow();
	sei.lpParameters = toConstWCharArray( parametersJoined );
	sei.nShow = SW_NORMAL;

	if( ShellExecuteEx( &sei ) == false )
	{
		return false;
	}

	return true;
}



bool WindowsCoreFunctions::runProgramAsUser(const QString& program,
											const QStringList& parameters,
											const QString& username,
											const QString& desktop,
											const QByteArray& stdInData)
{
	vDebug() << program << parameters << username << desktop;

	const auto baseProcessId = WtsSessionManager::findUserProcessId( username );
	if( baseProcessId == WtsSessionManager::InvalidProcess )
	{
		vCritical() << "could not determine base process ID for user" << username;
		return false;
	}

	return runProgramInSession(program, parameters, {}, baseProcessId, desktop, stdInData).isValid();
}



QString WindowsCoreFunctions::genericUrlHandler() const
{
	return QStringLiteral( "explorer" );
}



QString WindowsCoreFunctions::queryDisplayDeviceName(const QScreen& screen) const
{
	if(screen.name().isEmpty())
	{
		return {};
	}

	const auto screenDeviceName = toConstWCharArray(screen.name());

	const auto fallbackEnumDisplayDevices = [&]() -> QString {
		DISPLAY_DEVICE displayDevice{};
		displayDevice.cb = sizeof(displayDevice);
		if (EnumDisplayDevicesW(screenDeviceName, 0, &displayDevice, 0))
		{
			return QString::fromWCharArray(displayDevice.DeviceString);
		}
		return {};
	};

	UINT32 requiredPaths, requiredModes;
	auto result = GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &requiredPaths, &requiredModes);
	if (result != ERROR_SUCCESS || requiredPaths == 0 || requiredModes == 0)
	{
		return fallbackEnumDisplayDevices();
	}

	std::vector<DISPLAYCONFIG_PATH_INFO> paths(requiredPaths);
	std::vector<DISPLAYCONFIG_MODE_INFO> modes(requiredModes);
	if (QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS, &requiredPaths, paths.data(),
						   &requiredModes, modes.data(), nullptr) != ERROR_SUCCESS)
	{
		return fallbackEnumDisplayDevices();
	}

	for (const auto& p : paths)
	{
		DISPLAYCONFIG_SOURCE_DEVICE_NAME sourceName{};
		sourceName.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
		sourceName.header.size = sizeof(sourceName);
		sourceName.header.adapterId = p.sourceInfo.adapterId;
		sourceName.header.id = p.sourceInfo.id;

		if (DisplayConfigGetDeviceInfo(&sourceName.header) != ERROR_SUCCESS)
		{
			continue;
		}

		if (wcscmp(screenDeviceName, sourceName.viewGdiDeviceName) == 0)
		{
			DISPLAYCONFIG_TARGET_DEVICE_NAME name{};
			name.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME;
			name.header.size = sizeof(name);
			name.header.adapterId = p.sourceInfo.adapterId;
			name.header.id = p.targetInfo.id;

			if (DisplayConfigGetDeviceInfo(&name.header) != ERROR_SUCCESS)
			{
				return fallbackEnumDisplayDevices();
			}

			const auto monitorFriendlyDeviceName = QString::fromWCharArray(name.monitorFriendlyDeviceName);
			const auto outputName = [&]() -> QString {
				switch(name.outputTechnology)
				{
				case DISPLAYCONFIG_OUTPUT_TECHNOLOGY_HDMI:
					return QStringLiteral("HDMI-%1").arg(name.connectorInstance);
				case DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DVI:
					return QStringLiteral("DVI-%1").arg(name.connectorInstance);
				case DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DISPLAYPORT_EMBEDDED:
					return QStringLiteral("eDP-%1").arg(name.connectorInstance);
				case DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DISPLAYPORT_EXTERNAL:
					return QStringLiteral("DP-%1").arg(name.connectorInstance);
				case DISPLAYCONFIG_OUTPUT_TECHNOLOGY_LVDS:
					return QStringLiteral("LVDS-%1").arg(name.connectorInstance);
				case DISPLAYCONFIG_OUTPUT_TECHNOLOGY_MIRACAST:
					return QStringLiteral("Miracast-%1").arg(name.connectorInstance);
				case DISPLAYCONFIG_OUTPUT_TECHNOLOGY_SVIDEO:
					return QStringLiteral("S-Video-%1").arg(name.connectorInstance);
				case DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INTERNAL:
					return WindowsPlatformPlugin::tr("Internal display") +
							( name.connectorInstance > 1 ?
								  QStringLiteral(" %2").arg(name.connectorInstance) : QString{} );
				default:
					break;
				}
				return {};
			}();
			if(monitorFriendlyDeviceName.isEmpty())
			{
				if(outputName.isEmpty() == false)
				{
					return outputName;
				}
				// use display device string as fallback
			}
			else
			{
				return monitorFriendlyDeviceName +
						( outputName.isEmpty() ? QString {} : QStringLiteral(" [%1]").arg(outputName) );
			}
		}
	}

	return fallbackEnumDisplayDevices();
}



QString WindowsCoreFunctions::getApplicationName(ProcessId processId) const
{
	if (processId == InvalidProcessId)
	{
		return {};
	}

	struct WindowSearchData {
		DWORD pid;
		QString title;
	};

	WindowSearchData data = {DWORD(processId), {}};

	EnumWindows([](HWND window, LPARAM instance) -> WINBOOL CALLBACK {
		WindowSearchData* data = reinterpret_cast<WindowSearchData*>(instance);
		DWORD winPid;
		GetWindowThreadProcessId(window, &winPid);
		if (winPid == data->pid && IsWindowVisible(window))
		{
			const auto len = GetWindowTextLengthW(window);
			if (len > 0)
			{
				std::wstring winTitle(len, L'\0');
				GetWindowTextW(window, &winTitle[0], len + 1);
				data->title = QString::fromStdWString(winTitle);
				return FALSE;
			}
		}
		return TRUE;
	}, reinterpret_cast<LPARAM>(&data));

	if (data.title.isEmpty())
	{
		const auto hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
		if (hSnapshot == INVALID_HANDLE_VALUE)
		{
			return {};
		}

		PROCESSENTRY32W pe;
		pe.dwSize = sizeof(PROCESSENTRY32W);

		if (Process32FirstW(hSnapshot, &pe))
		{
			do {
				if (pe.th32ProcessID == data.pid)
				{
					data.title = QString::fromWCharArray(pe.szExeFile);
					break;
				}
			} while (Process32NextW(hSnapshot, &pe));
		}
		CloseHandle(hSnapshot);
	}

	return data.title;
}



bool WindowsCoreFunctions::enablePrivilege( LPCWSTR privilegeName, bool enable )
{
	SmartToken processToken;
	if (!OpenProcessToken(GetCurrentProcess(),
						  TOKEN_ADJUST_PRIVILEGES | TOKEN_QUERY | TOKEN_READ, processToken.put()))
	{
		vCritical() << "could not open process token";
		return false;
	}

	LUID luid{};
	if (!LookupPrivilegeValue(nullptr, privilegeName, &luid))
	{
		vCritical() << "could not lookup privilege value" << privilegeName;
		return false;
	}

	TOKEN_PRIVILEGES tokenPrivileges{};
	tokenPrivileges.PrivilegeCount = 1;
	tokenPrivileges.Privileges[0].Luid = luid;
	tokenPrivileges.Privileges[0].Attributes = enable ? SE_PRIVILEGE_ENABLED : 0;

	const auto ret = AdjustTokenPrivileges(processToken.get(), false, &tokenPrivileges, 0, nullptr, nullptr );
	if (ret == false || GetLastError() != ERROR_SUCCESS)
	{
		vCritical() << "could not enable or disable privilege" << privilegeName;
		return false;
	}

	return true;
}



SmartWCharPtr WindowsCoreFunctions::toWCharArray(const QString& qstring)
{
	auto wcharArray = new wchar_t[qstring.size()+1];
	qstring.toWCharArray( wcharArray );
	wcharArray[qstring.size()] = 0;

	return SmartWCharPtr{wcharArray};
}



const wchar_t* WindowsCoreFunctions::toConstWCharArray( const QString& qstring )
{
	return reinterpret_cast<const wchar_t*>( qstring.utf16() );
}



QString WindowsCoreFunctions::securityIdentifierToString(const SecurityIdentifierBuffer& sidBuffer)
{
	SmartStringSID stringSid;
	if (ConvertSidToStringSidW(reinterpret_cast<PSID>(const_cast<std::byte *>(sidBuffer.data())), stringSid.put()))
	{
		const auto sidString = QString::fromWCharArray(stringSid.get());
		return sidString;
	}

	vCritical() << "Could not convert SID to string:" << GetLastError();

	return {};
}



bool WindowsCoreFunctions::stringToSecurityIdentifier(const QString& sidString, WindowsCoreFunctions::SecurityIdentifierBuffer& sidBuffer)
{
	memset(sidBuffer.data(), 0, sidBuffer.size());

	SmartSID sid;
	if (ConvertStringSidToSid(toConstWCharArray(sidString), sid.put()) && sid)
	{
		const auto sidLength = GetLengthSid(sid.get());
		if (sidLength <= sidBuffer.size())
		{
			memcpy(sidBuffer.data(), sid.get(), sidLength);
		}
		return true;
	}

	vCritical() << "Could not convert SID string to SID:" << GetLastError();

	return false;
}



SmartHandle WindowsCoreFunctions::runProgramInSession(const QString& program,
													  const QStringList& parameters,
													  const QStringList& extraEnvironment,
													  DWORD baseProcessId,
													  const QString& desktop,
													  const QByteArray& stdInData)
{
	vDebug() << program << parameters << extraEnvironment << baseProcessId;

	enablePrivilege( SE_ASSIGNPRIMARYTOKEN_NAME, true );
	enablePrivilege( SE_INCREASE_QUOTA_NAME, true );
	enablePrivilege( SE_TCB_NAME, true );

	SmartHandle userProcessHandle{OpenProcess(PROCESS_ALL_ACCESS, false, baseProcessId)};
	if (userProcessHandle.isInvalid())
	{
		vCritical() << "OpenProcess()" << GetLastError();
		return {};
	}

	SmartToken userProcessToken;
	if (OpenProcessToken(userProcessHandle.get(), MAXIMUM_ALLOWED, userProcessToken.put()) == false)
	{
		vCritical() << "OpenProcessToken()" << GetLastError();
		return {};
	}

	SmartEnvBlockPtr userEnvironment;
	if (CreateEnvironmentBlock(userEnvironment.put(), userProcessToken.get(), false) == false)
	{
		vCritical() << "CreateEnvironmentBlock()" << GetLastError();
		return {};
	}

	SmartCoTaskMemPtr<wchar_t> profileDir;
	if (SHGetKnownFolderPath(FOLDERID_Profile, 0, userProcessToken.get(), profileDir.put()) != S_OK)
	{
		vCritical() << "SHGetKnownFolderPath()" << GetLastError();
		return {};
	}

	if (ImpersonateLoggedOnUser(userProcessToken.get()) == false) // Flawfinder: ignore
	{
		vCritical() << "ImpersonateLoggedOnUser()" << GetLastError();
		return {};
	}

	const auto revertToSelfGuard = qScopeGuard(RevertToSelf);

	auto desktopWide = toWCharArray(desktop);

	if (desktop.isEmpty())
	{
		desktopWide = toWCharArray( QStringLiteral("Winsta0\\Default") );
	}

	STARTUPINFO si{};
	si.cb = sizeof(STARTUPINFO);
	si.lpDesktop = desktopWide.get();

	const SmartWCharPtr fullEnvironment{appendToEnvironmentBlock(reinterpret_cast<const wchar_t *>(userEnvironment.get()), extraEnvironment)};

	SmartToken newToken;
	if (DuplicateTokenEx(userProcessToken.get(), TOKEN_ASSIGN_PRIMARY|TOKEN_ALL_ACCESS, nullptr,
						 SecurityImpersonation, TokenPrimary, newToken.put()) == false ||
		newToken.isInvalid())
	{
		vCritical() << "DuplicateTokenEx()" << GetLastError();
		return {};
	}

	SmartFileHandle stdinRead;
	SmartFileHandle stdinWrite;

	if (stdInData.isEmpty() == false)
	{
		SECURITY_ATTRIBUTES sa{};
		sa.nLength = sizeof(sa);
		sa.lpSecurityDescriptor = nullptr;
		sa.bInheritHandle = true;

		if (CreatePipe(stdinRead.put(), stdinWrite.put(), &sa, 0) == false)
		{
			vCritical() << "could not create stdin pipe";
			return {};
		}

		if (SetHandleInformation(stdinWrite.get(), HANDLE_FLAG_INHERIT, 0) == false)
		{
			return {};
		}

		si.dwFlags |= STARTF_USESTDHANDLES;
		si.hStdInput = stdinRead.get();
		si.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
		si.hStdError = GetStdHandle(STD_ERROR_HANDLE);
	}

	const auto commandLine = toWCharArray(QStringLiteral("\"%1\" %2").arg(program, parameters.join(QLatin1Char(' '))));

	PROCESS_INFORMATION pi{};
	if (CreateProcessAsUser(
			newToken.get(),			// client's access token
			nullptr,			  // file to execute
			commandLine.get(),	 // command line
			nullptr,			  // pointer to process SECURITY_ATTRIBUTES
			nullptr,			  // pointer to thread SECURITY_ATTRIBUTES
			stdInData.isEmpty() == false, // handles are inheritable when we need to pass data via stdin
			CREATE_UNICODE_ENVIRONMENT | NORMAL_PRIORITY_CLASS,   // creation flags
			fullEnvironment ? fullEnvironment.get() : userEnvironment.get(),			  // pointer to new environment block
			profileDir.get(),			  // name of current directory
			&si,			   // pointer to STARTUPINFO structure
			&pi				// receives information about new process
			) == false)
	{
		vCritical() << "CreateProcessAsUser()" << GetLastError();
		return {};
	}

	SmartHandle threadHandle{pi.hThread};
	SmartHandle processHandle{pi.hProcess};

	if (stdInData.isEmpty() == false)
	{
		DWORD written = 0;
		const auto stdInDataSize = DWORD(stdInData.size());
		if (WriteFile(stdinWrite.get(), stdInData.constData(), stdInDataSize, &written, nullptr) == false ||
			written != stdInDataSize)
		{
			vCritical() << "failed to write stdin data";
		}
	}

	return processHandle;
}



QStringList WindowsCoreFunctions::queryProcessEnvironmentVariables(DWORD processId)
{
	SmartHandle processHandle{OpenProcess(PROCESS_QUERY_INFORMATION, false, processId)};
	if (processHandle.isInvalid())
	{
		vCritical() << "OpenProcess()" << GetLastError();
		return {};
	}

	SmartToken processToken;
	if (OpenProcessToken(processHandle.get(), MAXIMUM_ALLOWED, processToken.put()) == false)
	{
		vCritical() << "OpenProcessToken()" << GetLastError();
		return {};
	}

	SmartEnvBlockPtr envBlock;
	if (CreateEnvironmentBlock(envBlock.put(), processToken.get(), false) == false ||
		envBlock.isInvalid())
	{
		vCritical() << "CreateEnvironmentBlock()" << GetLastError();
		return {};
	}

	const auto env = reinterpret_cast<const wchar_t *>(envBlock.get());
	size_t envPos = 0;
	size_t envCurVarStart = 0;

	QStringList envVars;
	while (envPos < MaximumEnvironmentBlockSize-1 && !(env[envPos] == 0 && env[envPos+1] == 0))
	{
		if (env[envPos] == 0)
		{
			envVars.append(QString::fromWCharArray(env + envCurVarStart));
			envCurVarStart = envPos+1;
		}
		++envPos;
	}

	return envVars;
}



bool WindowsCoreFunctions::terminateProcess( ProcessId processId, DWORD timeout )
{
	if( processId != WtsSessionManager::InvalidProcess )
	{
		SmartHandle processHandle{OpenProcess(PROCESS_TERMINATE, false, processId)};
		if( processHandle )
		{
			const auto result = TerminateProcess(processHandle.get(), 0);
			WaitForSingleObject(processHandle.get(), timeout);

			return result;
		}

		vCritical() << "could not open process with ID" << processId;
	}

	return false;
}



wchar_t* WindowsCoreFunctions::appendToEnvironmentBlock( const wchar_t* env, const QStringList& strings )
{
	if (env == nullptr)
	{
		return nullptr;
	}

	static constexpr auto MaximumExtraStringsLength = 1024*1024;

	size_t envPos = 0;
	while (envPos < MaximumEnvironmentBlockSize-1 && !(env[envPos] == 0 && env[envPos+1] == 0))
	{
		++envPos;
	}

	++envPos;

	if (envPos >= MaximumEnvironmentBlockSize-1)
	{
		return nullptr;
	}

	const auto stringsTotalLength = size_t( strings.join( QLatin1Char(' ') ).size() );
	if( stringsTotalLength >= MaximumExtraStringsLength )
	{
		return nullptr;
	}

	auto newEnv = new wchar_t[envPos + stringsTotalLength + 2];
	memcpy( newEnv, env, envPos*2 ); // Flawfinder: ignore

	for( const auto& string : strings )
	{
		const auto stringLength = size_t(string.size());
		memcpy( &newEnv[envPos], toConstWCharArray( string ), stringLength * sizeof(wchar_t) ); // Flawfinder: ignore
		envPos += stringLength;
		newEnv[envPos] = 0;
		++envPos;
	}

	newEnv[envPos] = 0;

	return newEnv;
}



void WindowsCoreFunctions::setTaskbarState( bool enabled )
{
	auto taskbar = FindWindow( L"Shell_TrayWnd", nullptr );
	auto startButton = FindWindow( L"Start", L"Start" );
	if( startButton == nullptr )
	{
		// Win 7
		startButton = FindWindow( L"Button", L"Start" );
	}

	ShowWindow( taskbar, enabled ? SW_SHOW : SW_HIDE );
	ShowWindow( startButton, enabled ? SW_SHOW : SW_HIDE );

	EnableWindow( taskbar, enabled );
	EnableWindow( startButton, enabled );
}



void WindowsCoreFunctions::setStartMenuState( bool enabled )
{
	auto startMenu = FindWindow( L"Windows.UI.Core.CoreWindow", L"Start" );
	if( startMenu )
	{
		ShowWindow( startMenu, enabled ? SW_SHOWDEFAULT : SW_HIDE );
	}
	else
	{
		startMenu = FindWindow( L"DV2ControlHost", nullptr );
		if( enabled == false )
		{
			ShowWindow( startMenu, SW_HIDE );
		}
		EnableWindow( startMenu, enabled );
	}
}



void WindowsCoreFunctions::setDesktopState( bool enabled )
{
	ShowWindow( FindWindow( L"Progman", nullptr ), enabled ? SW_SHOW : SW_HIDE );
}
```

---

# 7. Valoración

- Software **legítimo, open source (GPLv2)** y **firmado** (Certum). Sin malware, ofuscación ni telemetría encubierta observada.
- Criptografía sólida: RSA-4096, SHA-512, reto aleatorio por sesión, validación de tamaños, clave privada nunca transmitida.
- Buenas prácticas: punteros inteligentes (SmartHandle/SmartToken), `qScopeGuard(RevertToSelf)`, control de acceso por reglas/grupos/LDAP.
- Funcionalmente es una herramienta de **control remoto con capacidades de nivel kernel** (driver Interception) y **suplantación de sesión**; debe desplegarse solo con autorización y conocimiento de los usuarios.
- Superficie a vigilar en despliegue: puertos 11100/11300/11400, driver Interception, API REST (webapi), y custodia de las claves públicas instaladas.

**FIN DEL CONTEXTO.**
