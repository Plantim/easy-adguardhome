# ==============================================================================
# Script : deploy_adguard_en.ps1
# Repo   : easy-adguardhome
# ==============================================================================

# 1. IMMEDIATE ADMIN ELEVATION (Base64 encoding to avoid UAC crashes)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $Command = "irm https://raw.githubusercontent.com/Plantim/easy-adguardhome/main/deploy_adguard_en.ps1 | iex"
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
    $EncodedCommand = [Convert]::ToBase64String($Bytes)

    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $EncodedCommand" -Verb RunAs
    Exit
}

# Global config
$TargetDir = "C:\AdGuardHome"
$ZipPath = "$env:TEMP\AdGuardHome.zip"
$UrlRegistry = "https://static.adguard.com/adguardhome/release/AdGuardHome_windows_amd64.zip"
$UrlTemplate = "https://raw.githubusercontent.com/Plantim/easy-adguardhome/refs/heads/main/Template_AdGuardHome.yaml"

# Force UTF-8 console output
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# MAIN MENU LOOP
do {
    [System.Console]::Clear()
    Clear-Host

    # 2. MENU
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "          Easy Install AdGuardHome (Windows)         " -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Install AdGuardHome" -ForegroundColor Green
    Write-Host "  [2] Restore Default DNS (Auto/DHCP)" -ForegroundColor Yellow
    Write-Host "  [3] Set DNS (custom)" -ForegroundColor Yellow
    Write-Host "  [4] Change Username/Password" -ForegroundColor Magenta
    Write-Host "  [5] Exit" -ForegroundColor Red
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan

    $Choice = Read-Host "Select an option (1-5)"

    if ($Choice -eq "5" -or [string]::IsNullOrWhiteSpace($Choice)) {
        Write-Host "[-] Exiting..." -ForegroundColor Yellow
        break
    }

    # ------------------------------------------------------------------------------
    # OPTION 2 : RESTORE DEFAULT DNS (REVERT)
    # ------------------------------------------------------------------------------
    if ($Choice -eq "2") {
        Clear-Host
        Write-Host "=== Restore Windows DNS (Auto/DHCP) ===" -ForegroundColor Yellow
        Write-Host ""

        $ActiveAdapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1
        if ($ActiveAdapter) {
            try {
                Set-DnsClientServerAddress -InterfaceAlias $ActiveAdapter.Name -ResetServerAddresses -ErrorAction Stop
                Write-Host "[+] DNS reset to automatic on adapter : $($ActiveAdapter.Name)" -ForegroundColor Green
            } catch {
                Write-Host "[-] Error : unable to reset DNS on adapter $($ActiveAdapter.Name)." -ForegroundColor Red
            }
        } else {
            Write-Host "[-] Error : no active network adapter found to reset DNS." -ForegroundColor Red
        }

        Clear-DnsClientCache
        Write-Host "[+] Windows DNS cache cleared (FlushDNS)." -ForegroundColor Cyan
        Write-Host ""
        Read-Host "Press Enter to return to menu..."
    }

    # ------------------------------------------------------------------------------
    # OPTION 1 : INSTALL ADGUARD HOME
    # ------------------------------------------------------------------------------
    if ($Choice -eq "1") {
        Clear-Host
        Write-Host "=== Admin Configuration ===" -ForegroundColor Magenta
        Write-Host ""

        $Username = Read-Host "-> Username (if empty: admin) "
        if ([string]::IsNullOrWhiteSpace($Username)) { $Username = "admin" }

        $PasswordRaw = Read-Host "-> Password (if empty: password) "
        if ([string]::IsNullOrWhiteSpace($PasswordRaw)) { $PasswordRaw = "password" }

        Write-Host ""
        Write-Host "=== Network Configuration ===" -ForegroundColor Magenta
        $SetDnsChoice = Read-Host "-> Automatically set active network adapter DNS to 127.0.0.1 ? (Y/N) "

        Clear-Host
        Write-Host "=== Deploying ===" -ForegroundColor Cyan
        Write-Host ""

        if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }

        Write-Host "[1/5] Downloading latest AdGuard Home..." -ForegroundColor Green
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $UrlRegistry -OutFile $ZipPath

        Write-Host "[2/5] Extracting files..." -ForegroundColor Green
        Expand-Archive -Path $ZipPath -DestinationPath "$env:TEMP\AGH_Extract" -Force
        Copy-Item -Path "$env:TEMP\AGH_Extract\AdGuardHome\*" -Destination $TargetDir -Recurse -Force
        Remove-Item -Path "$env:TEMP\AGH_Extract" -Recurse -Force
        Remove-Item -Path $ZipPath -Force

        Write-Host "[3/5] Generating BCrypt hash..." -ForegroundColor Green
        try {
            $bcryptUrl = "https://www.nuget.org/api/v2/package/BCrypt.Net-Next/4.2.0"
            $bcryptZip = Join-Path $env:TEMP "BCrypt.Net-Next.zip"
            $bcryptDir = Join-Path $env:TEMP "BCrypt.Net-Next"
            Invoke-WebRequest -Uri $bcryptUrl -OutFile $bcryptZip -UseBasicParsing
            Expand-Archive -Path $bcryptZip -DestinationPath $bcryptDir -Force
            Remove-Item $bcryptZip -Force
            $dllPath = Get-ChildItem -LiteralPath "$bcryptDir\lib\net462" -Filter "BCrypt-Net-Next.dll" | Select-Object -First 1 -ExpandProperty FullName
            if (-not $dllPath) {
                $dllPath = Get-ChildItem -LiteralPath "$bcryptDir\lib\net48" -Filter "BCrypt-Net-Next.dll" | Select-Object -First 1 -ExpandProperty FullName
            }
            if (-not $dllPath) {
                $dllPath = Get-ChildItem -LiteralPath "$bcryptDir\lib\netstandard2.0" -Filter "BCrypt-Net-Next.dll" | Select-Object -First 1 -ExpandProperty FullName
            }
            if (-not $dllPath) { throw "DLL not found" }
            $dllBytes = [System.IO.File]::ReadAllBytes($dllPath)
            Remove-Item $bcryptDir -Recurse -Force
            [System.Reflection.Assembly]::Load($dllBytes) | Out-Null
            $FinalPasswordHash = [BCrypt.Net.BCrypt]::HashPassword($PasswordRaw, 10)
        } catch {
            Write-Host "    -> NuGet method failed, falling back to AdGuardHome API..." -ForegroundColor Yellow
            Set-Location $TargetDir
            Remove-Item "AdGuardHome.yaml" -ErrorAction SilentlyContinue
            Start-Process -FilePath ".\AdGuardHome.exe" -WindowStyle Hidden
            $ready = $false
            for ($i = 0; $i -lt 15; $i++) {
                Start-Sleep -Seconds 1
                try { $s = Invoke-WebRequest -Uri "http://127.0.0.1:3000/control/status" -UseBasicParsing -ErrorAction Stop
                    if ((ConvertFrom-Json $s.Content).installation_closed -eq $false) { $ready = $true; break } } catch {}
            }
            if (-not $ready) { throw "AdGuardHome did not start" }
            $body = @{web = @{bind_host = "127.0.0.1"; bind_port = 3000}; dns = @{bind_hosts = @("127.0.0.1"); port = 15353};
                users = @(@{name = $Username; password = $PasswordRaw})} | ConvertTo-Json -Compress
            Invoke-WebRequest -Uri "http://127.0.0.1:3000/control/installation/configure" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing | Out-Null
            Start-Sleep -Seconds 4
            Get-Process -Name "AdGuardHome" -ErrorAction SilentlyContinue | Stop-Process -Force
            if (Test-Path "AdGuardHome.yaml") { $c = Get-Content "AdGuardHome.yaml" -Raw; $m = [regex]::Match($c, 'password:\s*"(.+)"'); if ($m.Success) { $FinalPasswordHash = $m.Groups[1].Value } else { throw "Hash not found" } }
            else { throw "Config file not created" }
            Remove-Item "AdGuardHome.yaml" -Force -ErrorAction SilentlyContinue
        }

        Write-Host "[4/5] Injecting custom configuration..." -ForegroundColor Green
        $YamlContent = Invoke-WebRequest -Uri $UrlTemplate -UseBasicParsing | Select-Object -ExpandProperty Content

        $UserBlock = @"
users:
  - name: $Username
    password: "$FinalPasswordHash"
"@

        $NewYamlContent = $YamlContent -replace "users:\s*\[\]", $UserBlock
        [IO.File]::WriteAllText("$TargetDir\AdGuardHome.yaml", $NewYamlContent, [System.Text.Encoding]::UTF8)

        Write-Host "[5/5] Installing and starting Windows service..." -ForegroundColor Green
        Set-Location $TargetDir
        & .\AdGuardHome.exe -s install | Out-Null
        & .\AdGuardHome.exe -s start | Out-Null

        if ($SetDnsChoice -match "^[oO0yY]") {
            $ActiveAdapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1
            if ($ActiveAdapter) {
                try {
                    Set-DnsClientServerAddress -InterfaceAlias $ActiveAdapter.Name -ServerAddresses ("127.0.0.1") -ErrorAction Stop
                    Write-Host "[+] DNS 127.0.0.1 applied on adapter : $($ActiveAdapter.Name)" -ForegroundColor Cyan
                } catch {
                    Write-Host "[-] Error : unable to apply DNS on adapter $($ActiveAdapter.Name). Restricted network rights." -ForegroundColor Red
                }
            } else {
                Write-Host "[-] Error : no active network adapter found for automatic DNS assignment." -ForegroundColor Red
            }
        } else {
            Write-Host "[*] Automatic DNS configuration skipped." -ForegroundColor Yellow
        }

        Clear-DnsClientCache
        Write-Host "[+] Windows DNS cache cleared (FlushDNS)." -ForegroundColor Cyan

        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "       INSTALLATION COMPLETED SUCCESSFULLY !        " -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host " -> Web Interface : http://127.0.0.1" -ForegroundColor Green
        Write-Host " -> Username      : $Username" -ForegroundColor Yellow
        Write-Host " -> Password      : $PasswordRaw" -ForegroundColor Yellow
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        Read-Host "Press Enter to return to menu..."
    }

    # ------------------------------------------------------------------------------
    # OPTION 3 : SET CUSTOM DNS
    # ------------------------------------------------------------------------------
    if ($Choice -eq "3") {
        Clear-Host
        Write-Host "=== Custom DNS Configuration ===" -ForegroundColor Yellow
        Write-Host ""

        $dnsAddress = Read-Host "-> DNS address (if empty: 127.0.0.1) "
        if ([string]::IsNullOrWhiteSpace($dnsAddress)) { $dnsAddress = "127.0.0.1" }

        $ActiveAdapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1
        if ($ActiveAdapter) {
            try {
                Set-DnsClientServerAddress -InterfaceAlias $ActiveAdapter.Name -ServerAddresses ($dnsAddress) -ErrorAction Stop
                Write-Host "[+] DNS $dnsAddress applied on adapter : $($ActiveAdapter.Name)" -ForegroundColor Green
            } catch {
                Write-Host "[-] Error : unable to apply DNS on adapter $($ActiveAdapter.Name)." -ForegroundColor Red
            }
        } else {
            Write-Host "[-] Error : no active network adapter found." -ForegroundColor Red
        }

        Clear-DnsClientCache
        Write-Host "[+] Windows DNS cache cleared (FlushDNS)." -ForegroundColor Cyan
        Write-Host ""
        Read-Host "Press Enter to return to menu..."
    }

    # ------------------------------------------------------------------------------
    # OPTION 4 : CHANGE USERNAME / PASSWORD
    # ------------------------------------------------------------------------------
    if ($Choice -eq "4") {
        Clear-Host
        Write-Host "=== Change Username / Password ===" -ForegroundColor Magenta
        Write-Host ""

        # Auto-detect YAML path
        $defaultYaml = "$TargetDir\AdGuardHome.yaml"
        if (Test-Path $defaultYaml) {
            $yamlPath = $defaultYaml
            Write-Host "[*] File detected : $yamlPath" -ForegroundColor Cyan
        } else {
            $yamlPath = Read-Host "-> Path to AdGuardHome.yaml"
            if ($yamlPath) { $yamlPath = $yamlPath.Trim('"', "'") }
            if ([string]::IsNullOrWhiteSpace($yamlPath) -or -not (Test-Path $yamlPath)) {
                Write-Host "[-] File not found or invalid." -ForegroundColor Red
                Read-Host "Press Enter to return to menu..."
                continue
            }
        }
        Write-Host ""

        # Extract current username
        $rawYaml = Get-Content $yamlPath -Raw
        $currentName = ""
        $currentHash = ""
        if ($rawYaml -match '(?m)^\s+- name:\s*(.+)$') { $currentName = $Matches[1] }
        if ($rawYaml -match '(?m)^\s+password:\s*"(.+)"') { $currentHash = $Matches[1] }
        Write-Host "Current username : $currentName" -ForegroundColor Gray
        Write-Host ""

        $Username = Read-Host "-> New username (empty = unchanged) "
        if ([string]::IsNullOrWhiteSpace($Username)) { $Username = $currentName }

        $PasswordRaw = Read-Host "-> New password (empty = unchanged) "
        $passwordChanged = -not [string]::IsNullOrWhiteSpace($PasswordRaw)
        Write-Host ""

        if ($passwordChanged) {
            Write-Host "[*] Generating BCrypt hash..." -ForegroundColor Green
            try {
                $bcryptTmp = Join-Path $env:TEMP "BCrypt.Net-Next"
                $bcryptZip = "$bcryptTmp.zip"
                Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/BCrypt.Net-Next/4.2.0" -OutFile $bcryptZip -UseBasicParsing
                Expand-Archive -Path $bcryptZip -DestinationPath $bcryptTmp -Force
                Remove-Item $bcryptZip -Force
                $dllPath = Get-ChildItem -LiteralPath "$bcryptTmp\lib\net462" -Filter "BCrypt-Net-Next.dll" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
                if (-not $dllPath) { $dllPath = Get-ChildItem -LiteralPath "$bcryptTmp\lib\net48" -Filter "BCrypt-Net-Next.dll" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName }
                if (-not $dllPath) { throw "DLL not found" }
                $dllBytes = [System.IO.File]::ReadAllBytes($dllPath)
                Remove-Item $bcryptTmp -Recurse -Force
                [System.Reflection.Assembly]::Load($dllBytes) | Out-Null
                $NewHash = [BCrypt.Net.BCrypt]::HashPassword($PasswordRaw, 10)
            } catch {
                Write-Host "[-] BCrypt error : $_" -ForegroundColor Red
                Read-Host "Press Enter to return to menu..."
                continue
            }
        } else {
            $NewHash = $currentHash
        }

        Write-Host "[*] Stopping AdGuardHome service..." -ForegroundColor Green
        $aghDir = Split-Path $yamlPath -Parent
        $aghExe = Join-Path $aghDir "AdGuardHome.exe"
        & $aghExe -s stop | Out-Null
        Start-Sleep -Seconds 2

        Write-Host "[*] Updating YAML file..." -ForegroundColor Green
        $yaml = Get-Content $yamlPath -Raw
        $userBlock = @"
users:
  - name: $Username
    password: "$NewHash"
"@
        $yaml = $yaml -replace "(?m)^users:.*(?:\r?\n\s+.*)*", $userBlock
        [IO.File]::WriteAllText($yamlPath, $yaml, [System.Text.Encoding]::UTF8)

        Write-Host "[*] Restarting AdGuardHome service..." -ForegroundColor Green
        & $aghExe -s start | Out-Null

        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "       CREDENTIALS UPDATED SUCCESSFULLY !           " -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host " -> Web Interface : http://127.0.0.1" -ForegroundColor Green
        Write-Host " -> Username      : $Username" -ForegroundColor Yellow
        if ($passwordChanged) {
            Write-Host " -> Password      : $PasswordRaw" -ForegroundColor Yellow
        } else {
            Write-Host " -> Password      : unchanged" -ForegroundColor Gray
        }
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        Read-Host "Press Enter to return to menu..."
    }

} while ($true)
