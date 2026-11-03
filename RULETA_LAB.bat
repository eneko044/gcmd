@echo off
setlocal
title RULETA LAB
mode con: cols=140 lines=45
cd /d "%~dp0ruleta"
set "PY="
where py >nul 2>nul && set "PY=py -3"
if not defined PY where python >nul 2>nul && set "PY=python"
if not defined PY (
    echo.
    echo   [!] Hace falta Python 3: https://www.python.org/downloads/
    echo       Marca "Add python.exe to PATH" al instalarlo.
    pause
    exit /b 1
)
echo.
echo   RULETA LAB - ruleta europea ficticia con pagos y limites reales
echo.
echo   1. Experimento completo (modelos + estrategias + optima)  ~2 min
echo   2. Ver la ruleta ronda a ronda (2000 rondas, en directo)
echo   3. Grupo de control: rueda trucada
echo   4. Calcular la estrategia optima para mi banca y objetivo
echo.
set /p "OP=  Elige [1-4]: "
if "%OP%"=="2" %PY% ruleta.py entrenar --rondas 2000 --ver --pausa 0.03
if "%OP%"=="3" %PY% ruleta.py entrenar --sesgo
if "%OP%"=="4" (
    set /p "BANCA=  Banca en EUR: "
    set /p "OBJ=  Objetivo en EUR: "
    set /p "MESA=  Mesa [casino_es / francesa / online]: "
)
if "%OP%"=="4" %PY% ruleta.py optimo --banca %BANCA% --objetivo %OBJ% --mesa %MESA%
if not "%OP%"=="2" if not "%OP%"=="3" if not "%OP%"=="4" %PY% ruleta.py todo
echo.
echo   Resultados en la carpeta ruleta\salida  (informe_para_claude.json)
pause
endlocal
