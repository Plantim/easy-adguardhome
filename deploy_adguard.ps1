# ==============================================================================
# Script : deploy_adguard.ps1
# Repo   : easy-adguardhome
# ==============================================================================

# 1. ÉLÉVATION ADMIN IMMÉDIATE
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # On utilise -NoExit pour forcer la fenêtre à rester ouverte si besoin, et on passe par -Command
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `& `"$PSCommandPath`"" -Verb RunAs
    Exit
}

# Configuration des variables globales
$TargetDir = "C:\AdGuardHome"
$ZipPath = "$env:TEMP\AdGuardHome.zip"
$UrlRegistry = "https://static.adguard.com/adguardhome/release/AdGuardHome_windows_amd64.zip"
$UrlTemplate = "https://raw.githubusercontent.com/Plantim/easy-adguardhome/refs/heads/main/Template_AdGuardHome.yaml"

Clear-Host

# 2. MENU D'ACCUEIL
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "         Easy Install AdGuardHome (Windows)         " -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  [1] Install AdGuardHome" -ForegroundColor Green
Write-Host "  [2] Restore Default DNS (Auto/DHCP)" -ForegroundColor Yellow
Write-Host "  [3] Exit" -ForegroundColor Red
Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan

$Choice = Read-Host "Sélectionnez une option (1-3)"

if ($Choice -eq "3" -or [string]::IsNullOrWhiteSpace($Choice)) {
    Write-Host "[-] Opération annulée. Quitter..." -ForegroundColor Yellow
    Exit
}

# ------------------------------------------------------------------------------
# OPTION 2 : RESTAURER LE DNS EN AUTOMATIQUE (REVERT)
# ------------------------------------------------------------------------------
if ($Choice -eq "2") {
    Clear-Host
    Write-Host "=== Restauration du DNS Windows (Mode Auto/DHCP) ===" -ForegroundColor Yellow
    Write-Host ""
    
    $ActiveAdapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1
    if ($ActiveAdapter) {
        try {
            Set-DnsClientServerAddress -InterfaceAlias $ActiveAdapter.Name -ResetServerAddresses -ErrorAction Stop
            Write-Host "[+] Le DNS a été remis en automatique sur l'interface : $($ActiveAdapter.Name)" -ForegroundColor Green
        } catch {
            Write-Host "[-] Erreur : Impossible de réinitialiser le DNS sur l'interface $($ActiveAdapter.Name)." -ForegroundColor Red
        }
    } else {
        Write-Host "[-] Erreur : Aucune carte réseau active détectée pour réinitialiser le DNS." -ForegroundColor Red
    }
    
    Clear-DnsClientCache
    Write-Host "[+] Cache DNS Windows vidé (FlushDNS)." -ForegroundColor Cyan
    Write-Host ""
    Read-Host "Appuyez sur Entrée pour quitter..."
    Exit
}

# ------------------------------------------------------------------------------
# OPTION 1 : INSTALLATION D'ADGUARD HOME
# ------------------------------------------------------------------------------
if ($Choice -eq "1") {
    Clear-Host
    Write-Host "=== Configuration de l'Administrateur ===" -ForegroundColor Magenta
    Write-Host ""
    
    # Gestion Identifiant par défaut
    $Username = Read-Host "-> Entrez l'identifiant souhaité (par défaut: admin) "
    if ([string]::IsNullOrWhiteSpace($Username)) { $Username = "admin" }

    # MAJ : Gestion Mot de passe par défaut
    $PasswordRaw = Read-Host "-> Entrez le mot de passe souhaité (par défaut: password) "
    if ([string]::IsNullOrWhiteSpace($PasswordRaw)) { $PasswordRaw = "password" }

    Write-Host ""
    Write-Host "=== Configuration Réseau ===" -ForegroundColor Magenta
    $SetDnsChoice = Read-Host "-> Voulez-vous configurer automatiquement la carte réseau active sur 127.0.0.1 ? (O/N) "

    Clear-Host
    Write-Host "=== Déploiement en cours ===" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Test-Path $TargetDir)) { New-Item -ItemType Directory -Path $TargetDir | Out-Null }

    Write-Host "[1/5] Téléchargement de la dernière version d'AdGuard Home..." -ForegroundColor Green
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $UrlRegistry -OutFile $ZipPath

    Write-Host "[2/5] Extraction des fichiers..." -ForegroundColor Green
    Expand-Archive -Path $ZipPath -DestinationPath "$env:TEMP\AGH_Extract" -Force
    Copy-Item -Path "$env:TEMP\AGH_Extract\AdGuardHome\*" -Destination $TargetDir -Recurse -Force
    Remove-Item -Path "$env:TEMP\AGH_Extract" -Recurse -Force
    Remove-Item -Path $ZipPath -Force

    Write-Host "[3/5] Génération du Hash BCrypt via AdGuard Home..." -ForegroundColor Green
    Set-Location $TargetDir
    $FinalPasswordHash = .\AdGuardHome.exe --hash-password "$PasswordRaw"

    Write-Host "[4/5] Injection de la configuration personnalisée..." -ForegroundColor Green
    $YamlContent = Invoke-WebRequest -Uri $UrlTemplate -UseBasicParsing | Select-Object -ExpandProperty Content

    $UserBlock = @"
users:
  - name: $Username
    password: "$FinalPasswordHash"
"@

    $NewYamlContent = $YamlContent -replace "users:\s*\[\]", $UserBlock
    $NewYamlContent | Set-Content -Path "$TargetDir\AdGuardHome.yaml" -Encoding UTF8

    Write-Host "[5/5] Enregistrement et démarrage du service Windows..." -ForegroundColor Green
    & .\AdGuardHome.exe -s install | Out-Null
    & .\AdGuardHome.exe -s start | Out-Null

    # Application du DNS avec gestion d'erreur poussée
    if ($SetDnsChoice -match "^[oO0yY]") {
        $ActiveAdapter = Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1
        if ($ActiveAdapter) {
            try {
                Set-DnsClientServerAddress -InterfaceAlias $ActiveAdapter.Name -ServerAddresses ("127.0.0.1") -ErrorAction Stop
                Write-Host "[+] DNS 127.0.0.1 appliqué sur l'interface : $($ActiveAdapter.Name)" -ForegroundColor Cyan
            } catch {
                Write-Host "[-] Erreur : Impossible d'appliquer le DNS sur l'interface $($ActiveAdapter.Name). Droits réseau restreints." -ForegroundColor Red
            }
        } else {
            Write-Host "[-] Erreur : Aucune carte réseau active détectée pour l'attribution automatique du DNS." -ForegroundColor Red
        }
    } else {
        Write-Host "[*] Configuration automatique du DNS ignorée." -ForegroundColor Yellow
    }

    Clear-DnsClientCache
    Write-Host "[+] Cache DNS Windows vidé avec succès (FlushDNS)." -ForegroundColor Cyan

    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host "   INSTALLATION TERMINEE AVEC SUCCES !              " -ForegroundColor Green
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host " -> Interface Web  : http://127.0.0.1" -ForegroundColor Green
    Write-Host " -> Identifiant     : $Username" -ForegroundColor Yellow
    Write-Host " -> Mot de passe    : $PasswordRaw" -ForegroundColor Yellow
    Write-Host "====================================================" -ForegroundColor Green
    Write-Host ""
    Read-Host "Appuyez sur Entrée pour quitter..."
}