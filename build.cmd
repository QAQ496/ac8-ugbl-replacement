@echo off
rem Builds AC8-UGBL-Installer.exe from source.
rem Requires nothing but a normal Windows installation (csc.exe ships with the .NET Framework).
setlocal
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
    echo csc.exe not found - is the .NET Framework installed?
    pause
    exit /b 1
)

"%CSC%" /nologo /target:winexe /out:AC8-UGBL-Installer.exe /r:System.Windows.Forms.dll /r:System.Drawing.dll installer_bilingual.cs
if errorlevel 1 (
    echo Build failed.
    pause
    exit /b 1
)

echo.
echo Build OK: AC8-UGBL-Installer.exe
certutil -hashfile AC8-UGBL-Installer.exe SHA256
pause
