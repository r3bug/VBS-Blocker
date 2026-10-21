@echo off
setlocal

net session >nul 2>&1
if not "%errorlevel%"=="0" (
    echo Errore: eseguire questo file come amministratore.
    pause
    exit /b 1
)

reg add "HKLM\SYSTEM\CurrentControlSet\Control\Lsa" /v LsaCfgFlags /t REG_DWORD /d 0 /f
if errorlevel 1 exit /b 1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard" /v EnableVirtualizationBasedSecurity /t REG_DWORD /d 0 /f
if errorlevel 1 exit /b 1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /v Enabled /t REG_DWORD /d 0 /f
if errorlevel 1 exit /b 1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard" /v Enabled /t REG_DWORD /d 0 /f
if errorlevel 1 exit /b 1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello" /v Enabled /t REG_DWORD /d 0 /f
if errorlevel 1 exit /b 1
reg add "HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks" /v Enabled /t REG_DWORD /d 0 /f
if errorlevel 1 exit /b 1

bcdedit /set hypervisorlaunchtype off
if errorlevel 1 exit /b 1
bcdedit /set vsmlaunchtype off
if errorlevel 1 exit /b 1

echo.
echo Modifiche applicate. Riavviare Windows per renderle effettive.
echo Dopo il riavvio verificare lo stato con msinfo32.exe.
pause
