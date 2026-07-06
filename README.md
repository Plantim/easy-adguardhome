# 🛡️ Easy Install AdGuardHome (Windows)

🌐 **Select Language:** [Français](#-easy-install-adguardhome-français) | [English](#-easy-install-adguardhome-english)

---

## 🇫🇷 Easy Install AdGuardHome (Français)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078d7.svg?logo=windows&logoColor=white)](https://www.microsoft.com/windows)

Un outil d'automatisation moderne et ultra-rapide écrit en **PowerShell** permettant de déployer une instance locale d'**AdGuard Home** sur Windows en quelques secondes, avec une configuration pré-optimisée et une sécurité maximale.

## 🚀 Utilisation Rapide

Ouvrez une console **PowerShell** et exécutez la commande suivante :

```powershell
irm https://raw.githubusercontent.com/Plantim/easy-adguardhome/main/deploy_adguard.ps1 | iex
```

---

### 🖥️ Menu du script (Interface Console)

Lorsque vous exécutez le script, une interface textuelle interactive s'affiche directement dans votre console PowerShell :

```text
==================================================
        EASY INSTALL ADGUARDHOME (WINDOWS)        
==================================================

  [1] Install AdGuardHome
  [2] Restore Default DNS (Auto/DHCP)
  [3] Exit

==================================================
 Veuillez choisir une option [1-3] :
```

---

## ⚙️ Fonctionnement du script

Lorsque vous lancez le script et choisissez l'option **`[1] Install AdGuardHome`**, voici exactement ce qu'il exécute étape par étape sur votre système :

1. **Contrôle d'élévation :** Le script vérifie la présence des privilèges Administrateur. Une boîte de dialogue Windows (UAC) s'affiche pour valider l'exécution sécurisée.
2. **Configuration initiale :** L'assistant vous invite à configurer vos accès :
   * Saisie de l'identifiant (valeur par défaut : `admin` si laissé vide).
   * Saisie du mot de passe (valeur par défaut : `password` si laissé vide).
   * Choix d'attribution automatique du DNS local `127.0.0.1` (`O/N`) sur votre carte réseau active.
3. **Téléchargement & Extraction :** Le script crée le répertoire de destination `C:\AdGuardHome`, récupère l'archive officielle Windows (AMD64) d'AdGuard Home dans le dossier temporaire du système, extrait le binaire `AdGuardHome.exe`, puis nettoie proprement les fichiers temporaires.
4. **Sécurisation des identifiants (Local BCrypt) :** Le script exécute silencieusement le binaire AdGuard Home avec l'argument `--hash-password` pour chiffrer votre mot de passe en `BCrypt`. **Le hash est généré localement sur votre machine : aucun mot de passe ne circule en clair.**
5. **Injection du Template :** Le script télécharge le fichier `Template_AdGuardHome.yaml`, remplace le bloc des utilisateurs par vos identifiants et le hash généré, puis écrit le fichier de configuration final encodé en UTF-8.
6. **Installation du Service Windows :** AdGuard Home est enregistré et démarré en tant que service système Windows natif. Il s'exécutera ainsi automatiquement en arrière-plan à chaque démarrage du PC.
7. **Configuration Réseau & FlushDNS :** Si vous avez accepté l'étape réseau, le script identifie votre carte réseau active (Ethernet ou Wi-Fi connecté) et remplace son serveur DNS par l'adresse locale `127.0.0.1`. Enfin, il vide instantanément le cache DNS de Windows (`Clear-DnsClientCache`) pour appliquer immédiatement les protections.

---

### ⚙️ Optimisations appliquées (vs Configuration de base)

Le fichier `Template_AdGuardHome.yaml` pré-configure entièrement AdGuard Home en appliquant les réglages et filtres optimisés suivants :

## Filtres > Listes de blocage DNS

#### 1. Configuration des Filtres (10 listes actives)
Les listes de blocage de DNS sont triées sur le volet pour garantir un blocage maximal sans faux positifs ni "casse" de sites internet :

* **Section "Général" :**
  * `AdGuard DNS filter` : La base du blocage, active par défaut.
  * `HaGeZi's Normal Blocklist` : Une pépite extrêmement bien maintenue pour bloquer un maximum de cochonneries sans faux positifs.
  * `OISD Blocklist Small` : Légendaire pour son efficacité globale et son taux de casse de sites web proche de zéro.
  * `Peter Lowe's Blocklist` : Une liste historique, légère et très fiable.

* **Section "Autre" :**
  * `HaGeZi's Windows/Office Tracker Blocklist` : Parfaite pour bloquer toute la télémétrie abusive et les espions intégrés de Microsoft Windows et de la suite Office sans bloquer les mises à jour importantes.

* **Section "Sécurité" (Le Bouclier contre les arnaques et virus) :**
  * `Phishing URL Blocklist (PhishTank and OpenPhish)` : Pour vous protéger des faux sites de banques ou de services de livraison (Phishing).
  * `NoCoin Filter List` : Bloque les scripts cachés sur certains sites web qui utilisent la puissance de votre PC à votre insu pour miner de la crypto-monnaie.
  * `Malicious URL Blocklist (URLHaus)` : Bloque les domaines connus pour distribuer des malwares.
  * `uBlock₀ filters – Badware risks` : Les filtres d'uBlock dédiés à la sécurité, une valeur sûre.

## Paramètres > Paramètres DNS

#### 2. Configuration des serveurs DNS (Upstream & Locaux)
* **Serveurs amonts (Upstream) sécurisés :** Utilisation de serveurs DNS publics rapides et chiffrés automatiquement en DoH (DNS over HTTPS) :
  ```text
  https://dns.cloudflare.com/dns-query
  https://dns.quad9.net/dns-query
  ```
* **Mode de requêtes :** Sélection de l'option **"Requêtes en parallèle"** pour utiliser systématiquement la réponse du serveur le plus rapide.
* **Serveurs de repli (Fallback) :**
  ```text
  1.1.1.1
  9.9.9.9
  ```

#### 3. Optimisation de la Vitesse & Cache DNS
* **Configuration du serveur DNS (Limite de taux) :** La limite est passée de `20` à `0` (désactivée) afin d'éviter tout blocage réseau local intempestif.
* **Taille du cache :** Augmentée de 4 Mo (`4194304`) à **64 Mo** (`67108864`) pour mémoriser un maximum de requêtes.
* **Ajustement du TTL (Time-To-Live) :** 
  * **Remplacer le TTL minimum :** Fixé à `3600` (1 heure) pour forcer AdGuard à garder les adresses en mémoire et éviter de redemander constamment la même chose à Cloudflare.
  * **TTL maximal :** Fixé à `86400` (24 heures).
* **Caching Optimiste (Optimistic caching) :** Case cochée et active (`cache_optimistic: true`). Couplé au grand cache, cela permet à AdGuard de répondre instantanément au PC en utilisant la valeur en mémoire même si la validité du domaine a expiré de quelques minutes, pendant qu'il rafraîchit l'information en arrière-plan.

---
<!-- SÉPARATEUR VISUEL ENTRE LES DEUX LANGUES -->
---

## 🇺🇸 Easy Install AdGuardHome (English)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078d7.svg?logo=windows&logoColor=white)](https://www.microsoft.com/windows)

A modern, ultra-fast automation tool written in **PowerShell** to deploy a local instance of **AdGuard Home** on Windows in seconds, featuring a pre-optimized configuration template and maximum security.

## 🚀 Quick Start

Open a **PowerShell** console and execute the following command:

```powershell
irm https://raw.githubusercontent.com/Plantim/easy-adguardhome/main/deploy_adguard.ps1 | iex
```

---

### 🖥️ Script Menu (Console Interface)

When you run the script, an interactive text interface will display directly in your PowerShell console:

```text
==================================================
        EASY INSTALL ADGUARDHOME (WINDOWS)        
==================================================

  [1] Install AdGuardHome
  [2] Restore Default DNS (Auto/DHCP)
  [3] Exit

==================================================
 Veuillez choisir une option [1-3] :
```

---

## ⚙️ How the Script Works

When you launch the script and select option **`[1] Install AdGuardHome`**, here is exactly what it executes step-by-step on your system:

1. **Privilege Check:** The script checks for Administrator privileges. A Windows User Account Control (UAC) prompt will appear to ensure secure execution.
2. **Initial Setup:** The wizard prompts you to configure your access credentials:
   * Username input (defaults to `admin` if left blank).
   * Password input (defaults to `password` if left blank).
   * Option to automatically assign the local DNS `127.0.0.1` (`Y/N`) to your active network adapter.
3. **Download & Extraction:** The script creates the destination directory `C:\AdGuardHome`, fetches the official Windows (AMD64) AdGuard Home archive into the system's temporary folder, extracts the `AdGuardHome.exe` binary, and cleanly deletes the temporary files.
4. **Credential Security (Local BCrypt):** The script silently runs the AdGuard Home binary with the `--hash-password` argument to encrypt your password using `BCrypt`. **The hash is generated locally on your machine: no plaintext password ever leaves your system.**
5. **Template Injection:** The script downloads the `Template_AdGuardHome.yaml` file, replaces the user block with your credentials and the newly generated hash, and then writes the final UTF-8 encoded configuration file.
6. **Windows Service Installation:** AdGuard Home is registered and started as a native Windows system service. This ensures it runs automatically in the background every time your PC boots up.
7. **Network Configuration & FlushDNS:** If you accepted the network configuration step, the script identifies your active network adapter (connected Ethernet or Wi-Fi) and updates its DNS server to the local address `127.0.0.1`. Finally, it instantly flushes the Windows DNS cache (`Clear-DnsClientCache`) to apply the protections immediately.

---

### ⚙️ Applied Optimizations (vs. Stock Configuration)

The `Template_AdGuardHome.yaml` file fully pre-configures AdGuard Home by applying the following optimized settings and filters:

## Filters > DNS Blocklists

#### 1. Filter Configuration (10 Active Lists)
The DNS blocklists are handpicked to guarantee maximum blocking with zero false positives or broken websites:

* **"General" Section:**
  * `AdGuard DNS filter`: The core blocking foundation, active by default.
  * `HaGeZi's Normal Blocklist`: A highly maintained gem designed to block a maximum amount of junk without false positives.
  * `OISD Blocklist Small`: Legendary for its overall efficiency and near-zero website breakage rate.
  * `Peter Lowe's Blocklist`: A historic, lightweight, and highly reliable list.

* **"Other" Section:**
  * `HaGeZi's Windows/Office Tracker Blocklist`: Perfect for blocking intrusive telemetry and tracking embedded within Microsoft Windows and the Office suite, without interfering with critical updates.

* **"Security" Section (The Anti-Scam & Anti-Virus Shield):**
  * `Phishing URL Blocklist (PhishTank and OpenPhish)`: Protection against fake banking websites or fraudulent delivery services (Phishing).
  * `NoCoin Filter List`: Blocks hidden scripts on certain websites that stealthily use your PC's resources to mine cryptocurrency.
  * `Malicious URL Blocklist (URLHaus)`: Blocks domains known for distributing malware.
  * `uBlock₀ filters – Badware risks`: uBlock's dedicated security filters, a proven standard.

## Settings > DNS Settings

#### 2. DNS Server Configuration (Upstream & Local)
* **Secure Upstream Servers:** Uses fast, public DNS servers automatically encrypted with DoH (DNS over HTTPS):
  ```text
  https://dns.cloudflare.com/dns-query
  https://dns.quad9.net/dns-query
  ```
* **Query Mode:** Set to **"Parallel requests"** to always use the response from the fastest server.
* **Fallback Servers:**
  ```text
  1.1.1.1
  9.9.9.9
  ```

#### 3. Speed & DNS Cache Optimization
* **DNS Server Configuration (Rate Limit):** The limit is changed from `20` to `0` (disabled) to prevent any unexpected local network blocking.
* **Cache Size:** Increased from 4 MB (`4194304`) to **64 MB** (`67108864`) to cache as many requests as possible.
* **TTL (Time-To-Live) Adjustment:** 
  * **Override Minimum TTL:** Set to `3600` (1 hour) to force AdGuard to keep addresses in memory and avoid constantly making identical requests to Cloudflare.
  * **Maximum TTL:** Set to `86400` (24 hours).
* **Optimistic Caching:** Box checked and enabled (`cache_optimistic: true`). Combined with the large cache, this allows AdGuard to respond instantly to the PC using the cached value even if the domain validity expired a few minutes ago, while refreshing the information in the background.
