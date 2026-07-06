# ==============================================================================
# Script : deploy_adguard.ps1
# Repo   : easy-adguardhome
# ==============================================================================

# 1. ÉLÉVATION ADMIN IMMÉDIATE (Via Encodage Base64 pour éviter les crashs UAC)
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $Command = "irm https://raw.githubusercontent.com/Plantim/easy-adguardhome/main/deploy_adguard.ps1 | iex"
    $Bytes = [System.Text.Encoding]::Unicode.GetBytes($Command)
    $EncodedCommand = [Convert]::ToBase64String($Bytes)
    
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $EncodedCommand" -Verb RunAs
    Exit
}

# Configuration des variables globales
$TargetDir = "C:\AdGuardHome"
$ZipPath = "$env:TEMP\AdGuardHome.zip"
$UrlRegistry = "https://static.adguard.com/adguardhome/release/AdGuardHome_windows_amd64.zip"
$UrlTemplate = "https://raw.githubusercontent.com/Plantim/easy-adguardhome/refs/heads/main/Template_AdGuardHome.yaml"

# Force la console et la police à interpréter les caractères en UTF-8 pour corriger les accents
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# BOUCLE PRINCIPALE DU MENU
do {
    # Nettoyage forcé de la console à chaque retour au menu
    [System.Console]::Clear()
    Clear-Host

    # 2. MENU D'ACCUEIL
    $yamlExists = Test-Path "$TargetDir\AdGuardHome.yaml"
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host "         Easy Install AdGuardHome (Windows)         " -ForegroundColor Cyan
    Write-Host "====================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [1] Install AdGuardHome" -ForegroundColor Green
    Write-Host "  [2] Restore Default DNS (Auto/DHCP)" -ForegroundColor Yellow
    if ($yamlExists) { Write-Host "  [4] Change Username/Password" -ForegroundColor Magenta }
    Write-Host "  [3] Exit" -ForegroundColor Red
    Write-Host ""
    Write-Host "====================================================" -ForegroundColor Cyan

    $maxOpt = if ($yamlExists) { "4" } else { "3" }
    $Choice = Read-Host "Sélectionnez une option (1-$maxOpt)"

    if ($Choice -eq "3" -or [string]::IsNullOrWhiteSpace($Choice)) {
        Write-Host "[-] Quitter..." -ForegroundColor Yellow
        break # Casse la boucle et ferme le script
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
        Read-Host "Appuyez sur Entrée pour retourner au menu..."
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

        Write-Host "[3/5] Génération du Hash BCrypt..." -ForegroundColor Green
        try {
            $bcryptUrl = "https://www.nuget.org/api/v2/package/BCrypt.Net-Next/4.2.0"
            $bcryptZip = Join-Path $env:TEMP "BCrypt.Net-Next.zip"
            $bcryptDir = Join-Path $env:TEMP "BCrypt.Net-Next"
            Invoke-WebRequest -Uri $bcryptUrl -OutFile $bcryptZip -UseBasicParsing
            Expand-Archive -Path $bcryptZip -DestinationPath $bcryptDir -Force
            Remove-Item $bcryptZip -Force
            # net462 = pas de dépendance System.Memory (seulement mscorlib)
            $dllPath = Get-ChildItem -LiteralPath "$bcryptDir\lib\net462" -Filter "BCrypt-Net-Next.dll" | Select-Object -First 1 -ExpandProperty FullName
            if (-not $dllPath) {
                $dllPath = Get-ChildItem -LiteralPath "$bcryptDir\lib\net48" -Filter "BCrypt-Net-Next.dll" | Select-Object -First 1 -ExpandProperty FullName
            }
            if (-not $dllPath) {
                $dllPath = Get-ChildItem -LiteralPath "$bcryptDir\lib\netstandard2.0" -Filter "BCrypt-Net-Next.dll" | Select-Object -First 1 -ExpandProperty FullName
            }
            if (-not $dllPath) { throw "DLL introuvable" }
            $dllBytes = [System.IO.File]::ReadAllBytes($dllPath)
            Remove-Item $bcryptDir -Recurse -Force
            [System.Reflection.Assembly]::Load($dllBytes) | Out-Null
            $FinalPasswordHash = [BCrypt.Net.BCrypt]::HashPassword($PasswordRaw, 10)
        } catch {
            Write-Host "    -> Méthode NuGet échouée, fallback via l'API AdGuardHome..." -ForegroundColor Yellow
            Set-Location $TargetDir
            Remove-Item "AdGuardHome.yaml" -ErrorAction SilentlyContinue
            $aghProc = Start-Process -FilePath ".\AdGuardHome.exe" -PassThru -WindowStyle Hidden
            $ready = $false
            for ($i = 0; $i -lt 15; $i++) {
                Start-Sleep -Seconds 1
                try { $s = Invoke-WebRequest -Uri "http://127.0.0.1:3000/control/status" -UseBasicParsing -ErrorAction Stop
                    if ((ConvertFrom-Json $s.Content).installation_closed -eq $false) { $ready = $true; break } } catch {}
            }
            if (-not $ready) { throw "AdGuardHome n'a pas démarré" }
            $body = @{web = @{bind_host = "127.0.0.1"; bind_port = 3000}; dns = @{bind_hosts = @("127.0.0.1"); port = 15353};
                users = @(@{name = $Username; password = $PasswordRaw})} | ConvertTo-Json -Compress
            Invoke-WebRequest -Uri "http://127.0.0.1:3000/control/installation/configure" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing | Out-Null
            Start-Sleep -Seconds 4
            Get-Process -Name "AdGuardHome" -ErrorAction SilentlyContinue | Stop-Process -Force
            if (Test-Path "AdGuardHome.yaml") { $c = Get-Content "AdGuardHome.yaml" -Raw; $m = [regex]::Match($c, 'password:\s*"(.+)"'); if ($m.Success) { $FinalPasswordHash = $m.Groups[1].Value } else { throw "Hash introuvable" } }
            else { throw "Fichier de config non créé" }
            Remove-Item "AdGuardHome.yaml" -Force -ErrorAction SilentlyContinue
        }

        Write-Host "[4/5] Injection de la configuration personnalisée..." -ForegroundColor Green
        $YamlContent = Invoke-WebRequest -Uri $UrlTemplate -UseBasicParsing | Select-Object -ExpandProperty Content

        $UserBlock = @"
users:
  - name: $Username
    password: "$FinalPasswordHash"
"@

        $NewYamlContent = $YamlContent -replace "users:\s*\[\]", $UserBlock
        [IO.File]::WriteAllText("$TargetDir\AdGuardHome.yaml", $NewYamlContent, [System.Text.Encoding]::UTF8)

        Write-Host "[5/5] Enregistrement et démarrage du service Windows..." -ForegroundColor Green
        Set-Location $TargetDir
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
        Read-Host "Appuyez sur Entrée pour retourner au menu..."
    }

    # ------------------------------------------------------------------------------
    # OPTION 4 : CHANGER IDENTIFIANT / MOT DE PASSE
    # ------------------------------------------------------------------------------
    if ($Choice -eq "4") {
        Clear-Host
        Write-Host "=== Modification Identifiant / Mot de passe ===" -ForegroundColor Magenta
        Write-Host ""

        $Username = Read-Host "-> Nouvel identifiant (par défaut: admin) "
        if ([string]::IsNullOrWhiteSpace($Username)) { $Username = "admin" }

        $PasswordRaw = Read-Host "-> Nouveau mot de passe (par défaut: password) "
        if ([string]::IsNullOrWhiteSpace($PasswordRaw)) { $PasswordRaw = "password" }

        Write-Host ""
        Write-Host "[*] Génération du hash BCrypt..." -ForegroundColor Green
        try {
            $bcryptTmp = Join-Path $env:TEMP "BCrypt.Net-Next"
            $bcryptZip = "$bcryptTmp.zip"
            Invoke-WebRequest -Uri "https://www.nuget.org/api/v2/package/BCrypt.Net-Next/4.2.0" -OutFile $bcryptZip -UseBasicParsing
            Expand-Archive -Path $bcryptZip -DestinationPath $bcryptTmp -Force
            Remove-Item $bcryptZip -Force
            $dllPath = Get-ChildItem -LiteralPath "$bcryptTmp\lib\net462" -Filter "BCrypt-Net-Next.dll" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
            if (-not $dllPath) { $dllPath = Get-ChildItem -LiteralPath "$bcryptTmp\lib\net48" -Filter "BCrypt-Net-Next.dll" -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName }
            if (-not $dllPath) { throw "DLL introuvable" }
            $dllBytes = [System.IO.File]::ReadAllBytes($dllPath)
            Remove-Item $bcryptTmp -Recurse -Force
            [System.Reflection.Assembly]::Load($dllBytes) | Out-Null
            $NewHash = [BCrypt.Net.BCrypt]::HashPassword($PasswordRaw, 10)
        } catch {
            Write-Host "[-] Erreur BCrypt : $_" -ForegroundColor Red
            Read-Host "Appuyez sur Entrée pour retourner au menu..."
            continue
        }

        Write-Host "[*] Arrêt du service AdGuardHome..." -ForegroundColor Green
        & "$TargetDir\AdGuardHome.exe" -s stop | Out-Null
        Start-Sleep -Seconds 2

        Write-Host "[*] Mise à jour du fichier YAML..." -ForegroundColor Green
        $yamlPath = "$TargetDir\AdGuardHome.yaml"
        $yaml = Get-Content $yamlPath -Raw
        $userBlock = @"
users:
  - name: $Username
    password: "$NewHash"
"@
        $yaml = $yaml -replace "(?m)^users:.*(?:\r?\n\s+.*)*", $userBlock
        [IO.File]::WriteAllText($yamlPath, $yaml, [System.Text.Encoding]::UTF8)

        Write-Host "[*] Redémarrage du service AdGuardHome..." -ForegroundColor Green
        & "$TargetDir\AdGuardHome.exe" -s start | Out-Null

        Write-Host ""
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host "   IDENTIFIANTS MIS A JOUR AVEC SUCCES !           " -ForegroundColor Green
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host " -> Interface Web  : http://127.0.0.1" -ForegroundColor Green
        Write-Host " -> Identifiant     : $Username" -ForegroundColor Yellow
        Write-Host " -> Mot de passe    : $PasswordRaw" -ForegroundColor Yellow
        Write-Host "====================================================" -ForegroundColor Green
        Write-Host ""
        Read-Host "Appuyez sur Entrée pour retourner au menu..."
    }

} while ($true)