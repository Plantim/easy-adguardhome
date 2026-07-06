# 🛡️ Easy Install AdGuardHome (Windows)

🌐 **Select Language:** [Français](#-easy-install-adguardhome-français) | [English](#-easy-install-adguardhome-english)

---

## 🇫🇷 Easy Install AdGuardHome (Français)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078d7.svg?logo=windows&logoColor=white)](https://www.microsoft.com/windows)

Un outil d'automatisation moderne et ultra-rapide écrit en **PowerShell** permettant de déployer une instance locale d'**AdGuard Home** sur Windows en quelques secondes, avec une configuration pré-optimisée et une sécurité maximale.

---

## ✨ Fonctionnalités

* ⚡ **Déploiement en une seule ligne :** Téléchargement, extraction, injection de configuration et installation du service en une seule commande.
* 🔐 **Identifiants dynamiques et sécurisés :** Le script vous invite à choisir votre identifiant et mot de passe, puis utilise le binaire natif d'AdGuard Home pour générer un hash `BCrypt` localement avant l'écriture du fichier de configuration. **Aucun mot de passe n'est stocké en clair ou transmis sur Internet.**
* 🌐 **Automatisation Réseau Intelligente :** Détection de la carte réseau active (Wi-Fi ou Ethernet) pour basculer le DNS sur `127.0.0.1` (Optionnel).
* 🧼 **Nettoyage Automatique :** Vidage systématique du cache DNS Windows (`FlushDNS`) à la fin des opérations.
* 🧯 **Option de Secours (Revert) :** Un menu dédié permet de restaurer instantanément la configuration DNS d'origine de Windows (Mode Auto/DHCP via votre Box/Routeur) en cas de besoin.
* 📦 **Configuration pré-packagée :** Utilise un template personnalisé embarquant déjà des listes de blocages performantes.

---

## 🚀 Utilisation Rapide

Ouvrez une console **PowerShell** et exécutez la commande suivante :

```powershell
irm https://raw.githubusercontent.com/Plantim/easy-adguardhome/main/deploy_adguard.ps1 | iex
```

---
<!-- SÉPARATEUR VISUEL ENTRE LES DEUX LANGUES -->
---

## 🇺🇸 Easy Install AdGuardHome (English)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: Windows](https://img.shields.io/badge/Platform-Windows-0078d7.svg?logo=windows&logoColor=white)](https://www.microsoft.com/windows)

A modern, ultra-fast automation tool written in **PowerShell** to deploy a local instance of **AdGuard Home** on Windows in seconds, featuring a pre-optimized configuration template and maximum security.

---

## ✨ Features

* ⚡ **One-Line Deployment:** Automated downloader, extractor, configuration injector, and Windows service installer all in one single command.
* 🔐 **Secure & Dynamic Credentials:** Prompts for your desired admin username and password, then leverages the official AdGuard Home binary to generate a secure `BCrypt` hash locally. **No plain text passwords are ever stored or transmitted over the internet.**
* 🌐 **Smart Network Automation:** Automatically detects your active network adapter (Wi-Fi or Ethernet) to optionally toggle your primary DNS to `127.0.0.1`.
* 🧼 **Automatic Cleanup:** Systematically flushes the Windows DNS cache (`Clear-DnsClientCache`) at the end of the process to ensure instant blocklist propagation.
* 🧯 **Safety Revert Option:** A dedicated built-in recovery menu allows you to instantly restore Windows DNS settings back to Automatic (DHCP via your router/ISP) if needed.
* 📦 **Pre-baked Config:** Integrates your customized `Template_AdGuardHome.yaml` containing high-performance blocklists out of the box.

---

## 🚀 Quick Start

Open **PowerShell** (no need to run as Administrator beforehand, the script handles it) and run the following command:

```powershell
irm https://raw.githubusercontent.com/Plantim/easy-adguardhome/main/deploy_adguard.ps1 | iex
```

