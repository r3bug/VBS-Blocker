#requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch] $InstallStartupTask,
    [switch] $Apply
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'Questo script deve essere eseguito su Windows.'
}

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Aprire PowerShell come amministratore e rieseguire lo script.'
}

function Set-DwordValue {
    param(
        [Parameter(Mandatory)]
        [string] $Path,
        [Parameter(Mandatory)]
        [string] $Name,
        [Parameter(Mandatory)]
        [int] $Value
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }

    New-ItemProperty -Path $Path -Name $Name -PropertyType DWord -Value $Value -Force | Out-Null
    Write-Host "Impostato $Path\$Name = $Value"
}

if ($InstallStartupTask) {
    $taskName = 'VBS Blocker - Apply at startup'
    $scriptPath = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptPath) -or -not (Test-Path -LiteralPath $scriptPath)) {
        throw 'Per installare il task è necessario eseguire il file .ps1 salvato su disco.'
    }

    $installDirectory = Join-Path $env:ProgramData 'VBS-Blocker'
    $installedScriptPath = Join-Path $installDirectory 'Disable-VBS.ps1'
    New-Item -Path $installDirectory -ItemType Directory -Force | Out-Null
    Copy-Item -LiteralPath $scriptPath -Destination $installedScriptPath -Force

    $powershellPath = Join-Path $PSHOME 'powershell.exe'
    $taskArguments = "-NoProfile -ExecutionPolicy Bypass -File `"$installedScriptPath`" -Apply"
    $action = New-ScheduledTaskAction -Execute $powershellPath -Argument $taskArguments
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "Attività di avvio '$taskName' installata."
}

Write-Host 'Applicazione delle impostazioni VBS...'

$registryValues = @(
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard'
        Name = 'EnableVirtualizationBasedSecurity'
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard'
        Name = 'RequirePlatformSecurityFeatures'
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard'
        Name = 'HypervisorEnforcedCodeIntegrity'
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard'
        Name = 'LsaCfgFlags'
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
        Name = 'Enabled'
    },
    @{
        Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard\Scenarios\CredentialGuard'
        Name = 'Enabled'
    },
    @{
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa'
        Name = 'LsaCfgFlags'
    },
    @{
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard'
        Name = 'EnableVirtualizationBasedSecurity'
    },
    @{
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'
        Name = 'Enabled'
    },
    @{
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\CredentialGuard'
        Name = 'Enabled'
    },
    @{
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\WindowsHello'
        Name = 'Enabled'
    },
    @{
        Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\KernelShadowStacks'
        Name = 'Enabled'
    }
)

foreach ($registryValue in $registryValues) {
    Set-DwordValue -Path $registryValue.Path -Name $registryValue.Name -Value 0
}

foreach ($bcdSetting in @('hypervisorlaunchtype', 'vsmlaunchtype')) {
    & bcdedit.exe /set $bcdSetting off
    if ($LASTEXITCODE -ne 0) {
        throw "bcdedit non ha potuto impostare $bcdSetting su off (codice $LASTEXITCODE)."
    }
    Write-Host "Impostato BCD: $bcdSetting = off"
}

Write-Host ''
Write-Host 'Modifiche applicate. Riavviare Windows per renderle effettive.'
Write-Host 'Dopo il riavvio verificare lo stato con msinfo32.exe e con gli strumenti amministrativi del sistema.'
