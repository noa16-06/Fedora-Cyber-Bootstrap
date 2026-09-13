# 🛡️ Fedora Cyber Bootstrap

A complete, idempotent setup script for Cybersecurity, CTF and Bug Bounty on Fedora Linux.  
**For use on your own systems, authorized tests and CTF labs only.**

---

## ⚡ Quick Start

```bash
chmod +x fedora-cyber-bootstrap.sh
./fedora-cyber-bootstrap.sh            # install / update everything
./fedora-cyber-bootstrap.sh --check    # only report status, change nothing
./fedora-cyber-bootstrap.sh --help     # show help
```

After installation:
```bash
# Log back in (important for docker group & Zsh)
# Then:
source ~/.zshrc
```

Everything is installed under a single base directory (`~/Security` by default).
Override it with `SEC_BASE`:
```bash
SEC_BASE=~/pentest ./fedora-cyber-bootstrap.sh
```

---

## 🔁 Idempotent & Self-Updating – Safe to Run Multiple Times

The script checks whether each component is already present. Anything missing is
installed cleanly; **anything already installed is updated** on every run:

- System packages: `dnf upgrade --refresh`
- Flatpak apps: `flatpak update`
- Go tools: re-run `go install ...@latest` (pulls the newest version)
- Python tools: `pipx upgrade`
- Cloned repos & wordlists: `git pull`
- Nuclei templates: `nuclei -update-templates`

All downloads go through a temporary directory that is removed automatically when
the script exits (even on error), so no leftovers are left in `/tmp`.

| Symbol | Meaning |
|--------|---------|
| `[✓]` | Successfully installed |
| `[~]` | Already present – skipped |
| `↻` | Already present – updated to the latest version |
| `[!]` | Warning – not critical |
| `[x]` | Error – script stopped |

---

## 📦 What Gets Installed?

### 🖥️ Core / Terminal
| Tool | Usage |
|------|-------|
| `git` | Version control |
| `neovim` | Modern terminal text editor |
| `tmux` | Multiple terminal sessions in one window |
| `fzf` | Fuzzy search in the terminal |
| `bat` | `cat` with syntax highlighting |
| `ripgrep` | Extremely fast file search |
| `btop / htop` | System monitoring |
| `zsh + Oh-My-Zsh + Powerlevel10k` | Modern shell setup |

### 🔍 Recon / Web / Bug Bounty
| Tool | Usage |
|------|-------|
| `subfinder` | Subdomain enumeration |
| `httpx` | HTTP probing – find which hosts are reachable |
| `nuclei` | Automated vulnerability scanner |
| `ffuf` | Web fuzzing – find hidden directories |
| `gobuster` | Directory brute-force |
| `feroxbuster` | Recursive directory brute-force |
| `katana` | Modern web crawler |
| `hakrawler` | Web crawler for bug bounty |
| `waybackurls` | Fetch old URLs from the Wayback Machine |
| `assetfinder` | Find subdomains and assets |
| `gau` | Fetch all known URLs for a domain |
| `httprobe` | Check which hosts have HTTP/HTTPS |
| `wafw00f` | Web Application Firewall detection |
| `naabu` | Fast port scanner |
| `dnsx` | DNS toolkit for recon |
| `theharvester` | Gather emails and domains from public sources |

### 🔒 Scanning / Exploitation
| Tool | Usage |
|------|-------|
| `nmap` | Network scanner – the classic |
| `masscan` | Extremely fast port scanner |
| `sqlmap` | SQL injection detection and exploitation |
| `nikto` | Web server scanner |
| `wpscan` | WordPress vulnerability scanner |
| `mitmproxy` | Man-in-the-middle proxy |

### 🔑 Passwords / Cracking
| Tool | Usage |
|------|-------|
| `hydra` | Brute-force login attacks |
| `john` | Password cracking from hashes |
| `hashcat` | GPU-based password cracking |
| `hcxtools` | Prepare WLAN handshakes for hashcat |
| `kerbrute` | Kerberos brute-force for Active Directory |

### 🏢 Active Directory / Windows
| Tool | Usage |
|------|-------|
| `impacket` | Python tools for Windows protocols |
| `gitleaks` | Find secrets and API keys in Git repos |
| `semgrep` | Static code analysis for vulnerabilities |
| `PowerSploit` | PowerShell post-exploitation framework |
| `Responder` | LLMNR/NBT-NS poisoning |
| `PrivescCheck` | Windows privilege escalation checks |
| `PEASS-ng` | Linux/Windows privilege escalation scripts |

### 🌐 Network
| Tool | Usage |
|------|-------|
| `tcpdump` | Capture network traffic |
| `wireshark` | Graphical network traffic analysis |
| `socat / netcat` | Network connections, reverse shells |

### 🖱️ GUI Apps (Flatpak)
| App | Usage |
|-----|-------|
| `VSCode` | Code editor |
| `Obsidian` | Notes and documentation |
| `Firefox` | Browser |
| `Wireshark` | Network analysis |
| `Discord / Signal / Telegram` | Communication |
| `LibreOffice` | Office suite |

### 📚 Wordlists & Repos
| Collection | Usage |
|------------|-------|
| `SecLists` | Largest wordlist collection |
| `PayloadsAllTheThings` | Payloads for all attack techniques |
| `nuclei-templates` | Templates for the Nuclei scanner |
| `fuzzing-templates` | Fuzzing templates by ProjectDiscovery |
| `Gf-Patterns` | Grep patterns for interesting URL parameters |
| `RobotsDisallowed` | Common paths from robots.txt |
| `XSStrike` | Find XSS vulnerabilities |

---

## 📁 Directory Structure

Everything lives under one base directory (`~/Security` by default, override with `SEC_BASE`):

```
~/Security/
├── labs/          → CTF exercises and personal projects
├── tools/         → Cloned security tools (+ nikto)
├── wordlists/     → SecLists and other wordlists
├── reports/       → Personal reports
├── screenshots/   → Screenshots
├── scans/nmap/    → Scan results
└── bin/           → Own binaries: wpscan, nikto, feroxbuster, ffuf fallback
```

---

## 🐚 Shell Aliases

The following aliases are available after installation:

```bash
ll          # ls -lah
ctf         # cd ~/Security/labs
tools       # cd ~/Security/tools
wordlists   # cd ~/Security/wordlists
ports       # ss -tulpn (show open ports)
myip        # Show your public IPv4 address
myip6       # Show your public IPv6 address
grepip      # Filter IPs from text
pyserver    # Python HTTP server on port 8000
dockerps    # Display Docker containers clearly
reload      # Reload shell config
```

---

## 🔧 Tools to Install Manually

Some tools are intentionally not installed automatically:

| Tool | Reason | Link |
|------|--------|------|
| **Burp Suite** | Manual installation recommended | [portswigger.net](https://portswigger.net/burp) |
| **BloodHound** | Requires GUI setup | [github.com/BloodHoundAD](https://github.com/BloodHoundAD/BloodHound) |
| **Maltego** | Free registration required | [maltego.com](https://www.maltego.com) |
| **Tor Browser** | Via Flatpak or torproject.org | [torproject.org](https://www.torproject.org) |
| **Nessus** | Commercial license required | [tenable.com](https://www.tenable.com/products/nessus) |

---

## ✅ Post-Installation Checks

```bash
# Test tools
which nmap ffuf nuclei subfinder httpx sqlmap

# Check Docker
docker --version
docker ps

# Check Go tools
ls ~/go/bin/

# Check wordlists
ls ~/Security/wordlists/SecLists/

# Full status report (installed / missing)
./fedora-cyber-bootstrap.sh --check
```

> **Note:** `sqlmap`, `nikto`, `wpscan` and `theHarvester` are **not** Fedora
> packages. The script installs them the right way instead: `wpscan` as a Ruby
> gem (into `~/Security/bin`), `sqlmap` and `theHarvester` via `pipx`, and
> `nikto` as a git clone symlinked into `~/Security/bin`. `wfuzz` is intentionally
> dropped (incompatible with Python 3.12+); use `ffuf` / `feroxbuster` instead.

---

## ⚠️ Legal Notice

This script installs tools intended for offensive security testing.  
**Use these tools exclusively:**
- On your own systems
- In authorized penetration tests (written permission required!)
- In CTF labs and practice environments (HackTheBox, TryHackMe, etc.)

Misuse of these tools is illegal and punishable by law.

---

## 🤝 Tested On

- Fedora 40
- Fedora 41
- Fedora 42
- Fedora 43
