# 🛡️ Fedora Cyber Bootstrap

Ein vollständiges, idempotentes Setup-Script für Cybersecurity, CTF und Bug Bounty auf Fedora Linux.  
**Nur für eigene Systeme, autorisierte Tests und CTF-Labs verwenden.**

---

## ⚡ Schnellstart

```bash
chmod +x fedora-cyber-bootstrap.sh
./fedora-cyber-bootstrap.sh
```

Nach der Installation:
```bash
# Neu einloggen (wichtig für docker-Gruppe & Zsh)
# Dann:
source ~/.zshrc
```

---

## 🔁 Idempotent – sicher mehrfach ausführbar

Das Script prüft vor jeder Installation ob eine Komponente bereits vorhanden ist:

| Symbol | Bedeutung |
|--------|-----------|
| `[✓]` | Erfolgreich installiert |
| `[~]` | Bereits vorhanden – übersprungen |
| `[!]` | Warnung – nicht kritisch |
| `[x]` | Fehler – Script gestoppt |

---

## 📦 Was wird installiert?

### 🖥️ Core / Terminal
| Tool | Verwendung |
|------|-----------|
| `git` | Versionskontrolle |
| `neovim` | Moderner Texteditor im Terminal |
| `tmux` | Mehrere Terminal-Sessions in einem Fenster |
| `fzf` | Fuzzy-Suche im Terminal |
| `bat` | `cat` mit Syntax-Highlighting |
| `ripgrep` | Extrem schnelle Dateisuche |
| `btop / htop` | System-Monitoring |
| `zsh + Oh-My-Zsh + Powerlevel10k` | Modernes Shell-Setup |

### 🔍 Recon / Web / Bug Bounty
| Tool | Verwendung |
|------|-----------|
| `subfinder` | Subdomains aufspüren |
| `httpx` | HTTP-Probing – welche Hosts sind erreichbar |
| `nuclei` | Automatisierter Schwachstellen-Scanner |
| `ffuf` | Web-Fuzzing – versteckte Verzeichnisse finden |
| `gobuster` | Directory-Bruteforce |
| `feroxbuster` | Rekursiver Directory-Bruteforce |
| `katana` | Moderner Web-Crawler |
| `hakrawler` | Web-Crawler für Bug Bounty |
| `waybackurls` | Alte URLs aus dem Wayback Machine holen |
| `assetfinder` | Subdomains und Assets finden |
| `gau` | Alle bekannten URLs einer Domain |
| `httprobe` | Prüft welche Hosts HTTP/HTTPS haben |
| `wafw00f` | Web Application Firewall erkennen |
| `naabu` | Schneller Port-Scanner |
| `dnsx` | DNS-Toolkit für Recon |
| `theharvester` | E-Mails, Domains aus öffentlichen Quellen |

### 🔒 Scanning / Exploitation
| Tool | Verwendung |
|------|-----------|
| `nmap` | Netzwerk-Scanner, der Klassiker |
| `masscan` | Extrem schneller Port-Scanner |
| `sqlmap` | SQL-Injection Erkennung und Ausnutzung |
| `nikto` | Webserver-Scanner |
| `wpscan` | WordPress-Schwachstellen-Scanner |
| `mitmproxy` | Man-in-the-Middle Proxy |

### 🔑 Passwörter / Cracking
| Tool | Verwendung |
|------|-----------|
| `hydra` | Brute-Force Login-Angriffe |
| `john` | Passwort-Cracking aus Hashes |
| `hashcat` | GPU-basiertes Passwort-Cracking |
| `hcxtools` | WLAN-Handshakes für hashcat vorbereiten |
| `kerbrute` | Kerberos-Bruteforce für Active Directory |

### 🏢 Active Directory / Windows
| Tool | Verwendung |
|------|-----------|
| `impacket` | Python-Tools für Windows-Protokolle |
| `gitleaks` | Secrets und API-Keys in Git-Repos finden |
| `semgrep` | Statische Code-Analyse auf Schwachstellen |
| `PowerSploit` | PowerShell Post-Exploitation Framework |
| `Responder` | LLMNR/NBT-NS Poisoning |
| `PrivescCheck` | Windows Privilege Escalation Checks |
| `PEASS-ng` | Linux/Windows Privilege Escalation Scripts |

### 🌐 Netzwerk
| Tool | Verwendung |
|------|-----------|
| `tcpdump` | Netzwerktraffic mitschneiden |
| `wireshark` | Netzwerktraffic grafisch analysieren |
| `socat / netcat` | Netzwerkverbindungen, Reverse Shells |

### 🖱️ GUI Apps (Flatpak)
| App | Verwendung |
|-----|-----------|
| `VSCode` | Code-Editor |
| `Obsidian` | Notizen und Dokumentation |
| `Firefox` | Browser |
| `Wireshark` | Netzwerkanalyse |
| `Discord / Signal / Telegram` | Kommunikation |
| `LibreOffice` | Office Suite |

### 📚 Wordlists & Repos
| Sammlung | Verwendung |
|----------|-----------|
| `SecLists` | Größte Wordlist-Sammlung |
| `PayloadsAllTheThings` | Payloads für alle Angriffstechniken |
| `nuclei-templates` | Templates für den Nuclei-Scanner |
| `fuzzing-templates` | Fuzzing-Templates von ProjectDiscovery |
| `Gf-Patterns` | Grep-Patterns für interessante URL-Parameter |
| `RobotsDisallowed` | Häufige Pfade aus robots.txt |
| `XSStrike` | XSS-Schwachstellen finden |

---

## 📁 Ordnerstruktur

```
~/
├── labs/          → CTF-Übungen und eigene Projekte
├── tools/         → Geklonte Security-Tools
├── wordlists/     → SecLists und andere Wordlists
├── reports/       → Eigene Berichte
└── screenshots/   → Screenshots
```

---

## 🐚 Shell-Aliases

Nach der Installation sind folgende Aliases verfügbar:

```bash
ll          # ls -lah
ctf         # cd ~/labs
tools       # cd ~/tools
wordlists   # cd ~/wordlists
ports       # ss -tulpn (offene Ports anzeigen)
myip        # Eigene öffentliche IPv4 anzeigen
myip6       # Eigene öffentliche IPv6 anzeigen
grepip      # IPs aus Text filtern
pyserver    # Python HTTP-Server auf Port 8000
dockerps    # Docker Container übersichtlich anzeigen
reload      # Shell-Config neu laden
```

---

## 🔧 Manuell zu installierende Tools

Einige Tools werden bewusst nicht automatisch installiert:

| Tool | Grund | Link |
|------|-------|------|
| **Burp Suite** | Manuelle Installation empfohlen | [portswigger.net](https://portswigger.net/burp) |
| **BloodHound** | GUI-Setup erforderlich | [github.com/BloodHoundAD](https://github.com/BloodHoundAD/BloodHound) |
| **Maltego** | Kostenlose Registrierung nötig | [maltego.com](https://www.maltego.com) |
| **Tor Browser** | Über Flatpak oder torproject.org | [torproject.org](https://www.torproject.org) |
| **Nessus** | Kommerzielle Lizenz nötig | [tenable.com](https://www.tenable.com/products/nessus) |

---

## ✅ Nach der Installation prüfen

```bash
# Tools testen
which nmap ffuf nuclei subfinder httpx sqlmap

# Docker prüfen
docker --version
docker ps

# Go-Tools prüfen
ls ~/go/bin/

# Wordlists prüfen
ls ~/wordlists/SecLists/
```

---

## ⚠️ Rechtlicher Hinweis

Dieses Script installiert Tools die für offensive Sicherheitstests gedacht sind.  
**Verwende diese Tools ausschließlich:**
- Auf eigenen Systemen
- In autorisierten Pentests (schriftliche Genehmigung!)
- In CTF-Labs und Übungsumgebungen (HackTheBox, TryHackMe, etc.)

Der Missbrauch dieser Tools ist illegal und strafbar.

---

## 🤝 Getestet auf

- Fedora 40
- Fedora 41
- Fedora 42
- Fedora 43