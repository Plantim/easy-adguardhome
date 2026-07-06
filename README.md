# Easy_install_AdGuardHome

An ultra-fast, modern automation tool to deploy a local instance of AdGuard Home on Windows with zero hassle. 

## 🚀 Features
* **One-Line Deployment:** Downloader, installer, and configuration injector all in one single command.
* **Interactive & Secure Setup:** Dynamically prompts for your desired admin username and password, then hashes it locally using BCrypt before writing it to the config file.
* **Network Automation:** Automatically detects the active network adapter, sets the DNS server to `127.0.0.1`, and flushes the Windows DNS cache.
* **Pre-baked Config:** Ready to block ads out of the box using high-performance blocklists (HaGeZi, OISD, AdGuard Filters, etc.).

## 🛠️ Quick Start
Open PowerShell as Administrator and run the following command:

```powershell
irm [https://raw.githubusercontent.com/YOUR_PSEUDO/Easy_install_AdGuardHome/main/deploy_adguard.ps1](https://raw.githubusercontent.com/YOUR_PSEUDO/Easy_install_AdGuardHome/main/deploy_adguard.ps1) | iex
