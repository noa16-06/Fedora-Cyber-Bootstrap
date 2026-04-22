#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# fedora-cyber-bootstrap.sh
# Full Fedora bootstrap for cybersecurity / CTF / bug bounty
# Idempotent – safe to run multiple times
# For authorized testing, labs, and CTFs only.
############################################

### ---------- farben & helpers ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()   { printf "\n${BLUE}${BOLD}[*]${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[!]${NC} %s\n" "$*" >&2; }
skip()  { printf "${CYAN}[~]${NC} %s – bereits installiert, überspringe.\n" "$*"; }
fail()  { printf "\n${RED}[x]${NC} %s\n" "$*" >&2; exit 1; }

trap 'warn "Unerwarteter Fehler in Zeile $LINENO. Ausgabe oben prüfen."' ERR

### ---------- preflight ----------
require_fedora() {
  [[ -f /etc/fedora-release ]] || fail "Dieses Script ist nur für Fedora."
  FEDORA_VERSION=$(rpm -E %fedora)
  log "Fedora $FEDORA_VERSION erkannt."
}

require_root_or_sudo() {
  if ! sudo -v &>/dev/null; then
    fail "sudo-Zugriff wird benötigt."
  fi
  ok "sudo-Zugriff bestätigt."
}

### ---------- hilfsfunktionen ----------

# Prüft ob ein dnf-Paket installiert ist
dnf_installed() {
  rpm -q "$1" &>/dev/null
}

# Installiert ein dnf-Paket nur wenn noch nicht vorhanden
dnf_install_if_missing() {
  local pkg="$1"
  if dnf_installed "$pkg"; then
    skip "$pkg"
  else
    printf "  ${YELLOW}→${NC} installiere %s\n" "$pkg"
    sudo dnf install -y "$pkg" || warn "Konnte $pkg nicht installieren"
  fi
}

# Prüft ob ein Befehl im PATH vorhanden ist
cmd_exists() {
  command -v "$1" &>/dev/null
}

# Clont ein Repo nur wenn Zielordner noch nicht existiert
clone_if_missing() {
  local url="$1"
  local dest="$2"
  local name
  name=$(basename "$dest")
  if [[ -d "$dest" ]]; then
    skip "$name (Repo)"
  else
    printf "  ${YELLOW}→${NC} clone %s\n" "$name"
    git clone --depth=1 "$url" "$dest" || warn "Clone fehlgeschlagen: $url"
  fi
}

# Schreibt eine Zeile in eine Datei, nur wenn noch nicht vorhanden
append_once() {
  local line="$1"
  local file="$2"
  touch "$file"
  grep -Fq "$line" "$file" || echo "$line" >> "$file"
}

# Installiert ein pipx-Paket nur wenn noch nicht vorhanden
pipx_install_if_missing() {
  local app="$1"
  if pipx list 2>/dev/null | grep -q "^  - $app "; then
    skip "$app (pipx)"
  else
    printf "  ${YELLOW}→${NC} pipx install %s\n" "$app"
    pipx install "$app" || warn "pipx install fehlgeschlagen: $app"
  fi
}

# Installiert ein Go-Tool nur wenn binary noch nicht vorhanden
go_install_if_missing() {
  local pkg="$1"
  local bin="$2"
  if cmd_exists "$bin" || [[ -f "$HOME/go/bin/$bin" ]]; then
    skip "$bin (go)"
  else
    printf "  ${YELLOW}→${NC} go install %s\n" "$bin"
    go install "$pkg" || warn "go install fehlgeschlagen: $pkg"
  fi
}

### ---------- verzeichnisse ----------
create_dirs() {
  log "Erstelle Arbeitsverzeichnisse..."
  local dirs=(
    "$HOME/tools"
    "$HOME/labs"
    "$HOME/wordlists"
    "$HOME/screenshots"
    "$HOME/reports"
    "$HOME/.local/bin"
    "$HOME/go/bin"
  )
  for d in "${dirs[@]}"; do
    if [[ -d "$d" ]]; then
      skip "$d"
    else
      mkdir -p "$d"
      ok "Erstellt: $d"
    fi
  done
}

### ---------- system update ----------
system_update() {
  log "System aktualisieren..."
  sudo dnf upgrade -y --refresh || warn "System-Update teilweise fehlgeschlagen"
  ok "System aktuell."
}

### ---------- repos ----------
setup_repos() {
  log "Repositories einrichten..."

  # RPM Fusion
  if dnf_installed rpmfusion-free-release; then
    skip "RPM Fusion Free"
  else
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm" \
      || warn "RPM Fusion konnte nicht installiert werden"
    ok "RPM Fusion aktiviert."
  fi

  # Docker CE Repo
  if [[ -f /etc/yum.repos.d/docker-ce.repo ]]; then
    skip "Docker CE Repo"
  else
    sudo wget -q -O /etc/yum.repos.d/docker-ce.repo \
      https://download.docker.com/linux/fedora/docker-ce.repo \
      || warn "Docker Repo konnte nicht hinzugefügt werden"
    ok "Docker CE Repo hinzugefügt."
  fi
}

### ---------- core tools ----------
install_core() {
  log "Core / Terminal-Tools installieren..."

  local pkgs=(
    git wget curl jq
    ripgrep fd-find bat tree
    tmux fzf htop btop ncdu
    neovim sqlite
    openssl gnupg
    unzip zip p7zip
    stow direnv
    zsh util-linux-user
    make gcc g++ cmake
    python3 python3-pip pipx
    golang nodejs ruby
    socat netcat nmap tcpdump
    wireshark whois
  )

  for pkg in "${pkgs[@]}"; do
    dnf_install_if_missing "$pkg"
  done
}

### ---------- security / pentest tools ----------
install_security_tools() {
  log "Security / Pentest-Tools installieren..."

  local pkgs=(
    sqlmap nikto hydra masscan
    john hashcat hcxtools
    wpscan theharvester
  )

  for pkg in "${pkgs[@]}"; do
    dnf_install_if_missing "$pkg"
  done

  # ffuf
  if cmd_exists ffuf; then
    skip "ffuf"
  else
    local ffuf_url
    ffuf_url=$(curl -s https://api.github.com/repos/ffuf/ffuf/releases/latest \
      | grep "browser_download_url.*linux_amd64.tar.gz" \
      | cut -d '"' -f 4)
    if [[ -n "$ffuf_url" ]]; then
      wget -q "$ffuf_url" -O /tmp/ffuf.tar.gz
      tar -xzf /tmp/ffuf.tar.gz -C /tmp
      sudo mv /tmp/ffuf /usr/local/bin/ffuf
      rm -f /tmp/ffuf.tar.gz
      ok "ffuf installiert."
    else
      warn "ffuf Download fehlgeschlagen"
    fi
  fi

  # feroxbuster
  if cmd_exists feroxbuster; then
    skip "feroxbuster"
  else
    curl -sL https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh \
      | bash -s -- /usr/local/bin || warn "feroxbuster Installation fehlgeschlagen"
    ok "feroxbuster installiert."
  fi
}

### ---------- docker ----------
install_docker() {
  log "Docker installieren..."

  local docker_pkgs=(
    docker-ce
    docker-ce-cli
    containerd.io
    docker-buildx-plugin
    docker-compose-plugin
  )

  for pkg in "${docker_pkgs[@]}"; do
    dnf_install_if_missing "$pkg"
  done

  # Docker Service aktivieren
  if systemctl is-enabled docker &>/dev/null; then
    skip "Docker Service (bereits aktiviert)"
  else
    sudo systemctl enable --now docker
    ok "Docker Service aktiviert."
  fi

  # User zur docker-Gruppe hinzufügen
  if groups "$USER" | grep -q docker; then
    skip "docker-Gruppe (User bereits Mitglied)"
  else
    sudo usermod -aG docker "$USER"
    ok "User zur docker-Gruppe hinzugefügt. Bitte neu einloggen!"
  fi
}

### ---------- flatpak apps ----------
install_flatpaks() {
  log "Flatpak Apps installieren..."

  if ! cmd_exists flatpak; then
    dnf_install_if_missing flatpak
  fi

  # Flathub hinzufügen
  if flatpak remotes | grep -q flathub; then
    skip "Flathub Remote"
  else
    sudo flatpak remote-add --if-not-exists flathub \
      https://flathub.org/repo/flathub.flatpakrepo
    ok "Flathub hinzugefügt."
  fi

  local flatpaks=(
    "com.visualstudio.code:VSCode"
    "org.wireshark.Wireshark:Wireshark"
    "md.obsidian.Obsidian:Obsidian"
    "org.mozilla.firefox:Firefox"
    "com.discordapp.Discord:Discord"
    "org.signal.Signal:Signal"
    "org.telegram.desktop:Telegram"
    "org.libreoffice.LibreOffice:LibreOffice"
  )

  for entry in "${flatpaks[@]}"; do
    local app_id="${entry%%:*}"
    local app_name="${entry##*:}"
    if flatpak list | grep -q "$app_id"; then
      skip "$app_name (Flatpak)"
    else
      printf "  ${YELLOW}→${NC} installiere %s\n" "$app_name"
      flatpak install -y flathub "$app_id" || warn "$app_name Installation fehlgeschlagen"
    fi
  done
}

### ---------- go tools ----------
install_go_tools() {
  log "Go-basierte Tools installieren..."
  export PATH="$HOME/go/bin:$PATH"

  go_install_if_missing "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"   "subfinder"
  go_install_if_missing "github.com/projectdiscovery/httpx/cmd/httpx@latest"              "httpx"
  go_install_if_missing "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"         "nuclei"
  go_install_if_missing "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"           "naabu"
  go_install_if_missing "github.com/projectdiscovery/katana/cmd/katana@latest"            "katana"
  go_install_if_missing "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"                "dnsx"
  go_install_if_missing "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest" "interactsh-client"
  go_install_if_missing "github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"    "shuffledns"
  go_install_if_missing "github.com/ffuf/ffuf/v2@latest"                                  "ffuf"
  go_install_if_missing "github.com/OJ/gobuster/v3@latest"                                "gobuster"
  go_install_if_missing "github.com/hakluke/hakrawler@latest"                             "hakrawler"
  go_install_if_missing "github.com/tomnomnom/waybackurls@latest"                         "waybackurls"
  go_install_if_missing "github.com/tomnomnom/assetfinder@latest"                         "assetfinder"
  go_install_if_missing "github.com/lc/gau/v2/cmd/gau@latest"                            "gau"
  go_install_if_missing "github.com/tomnomnom/httprobe@latest"                            "httprobe"
  go_install_if_missing "github.com/ropnop/kerbrute@latest"                               "kerbrute"
  go_install_if_missing "github.com/zricethezav/gitleaks/v8@latest"                       "gitleaks"
}

### ---------- pipx tools ----------
install_pipx_tools() {
  log "Python-basierte Tools (pipx) installieren..."
  pipx ensurepath || true

  pipx_install_if_missing "dirsearch"
  pipx_install_if_missing "mitmproxy"
  pipx_install_if_missing "bloodhound"
  pipx_install_if_missing "impacket"
  pipx_install_if_missing "semgrep"
  pipx_install_if_missing "wafw00f"
  pipx_install_if_missing "wfuzz"
}

### ---------- repos & wordlists ----------
clone_repos() {
  log "Security-Repos und Wordlists clonen..."

  clone_if_missing "https://github.com/danielmiessler/SecLists.git"                    "$HOME/wordlists/SecLists"
  clone_if_missing "https://github.com/swisskyrepo/PayloadsAllTheThings.git"           "$HOME/tools/PayloadsAllTheThings"
  clone_if_missing "https://github.com/lgandx/Responder.git"                           "$HOME/tools/Responder"
  clone_if_missing "https://github.com/s0md3v/XSStrike.git"                            "$HOME/tools/XSStrike"
  clone_if_missing "https://github.com/danielmiessler/RobotsDisallowed.git"            "$HOME/tools/RobotsDisallowed"
  clone_if_missing "https://github.com/1ndianl33t/Gf-Patterns.git"                    "$HOME/tools/Gf-Patterns"
  clone_if_missing "https://github.com/projectdiscovery/fuzzing-templates.git"         "$HOME/tools/fuzzing-templates"
  clone_if_missing "https://github.com/projectdiscovery/nuclei-templates.git"          "$HOME/tools/nuclei-templates"
  clone_if_missing "https://github.com/itm4n/PrivescCheck.git"                         "$HOME/tools/PrivescCheck"
  clone_if_missing "https://github.com/PowerShellMafia/PowerSploit.git"               "$HOME/tools/PowerSploit"
  clone_if_missing "https://github.com/carlospolop/PEASS-ng.git"                       "$HOME/tools/PEASS-ng"
}

### ---------- zsh + oh-my-zsh + p10k ----------
setup_zsh() {
  log "Zsh / Oh-My-Zsh / Powerlevel10k einrichten..."

  # Zsh als Standard-Shell
  if [[ "$SHELL" == */zsh ]]; then
    skip "Zsh (bereits Standard-Shell)"
  else
    chsh -s "$(which zsh)"
    ok "Zsh als Standard-Shell gesetzt. Bitte neu einloggen!"
  fi

  # Oh-My-Zsh
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    skip "Oh-My-Zsh"
  else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
      "" --unattended
    ok "Oh-My-Zsh installiert."
  fi

  # Powerlevel10k
  local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  if [[ -d "$p10k_dir" ]]; then
    skip "Powerlevel10k"
  else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    ok "Powerlevel10k installiert."
    append_once 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"
  fi

  # MesloLGS Nerd Font
  local font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"
  if [[ -f "$font_dir/MesloLGS NF Regular.ttf" ]]; then
    skip "MesloLGS NF Font"
  else
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    wget -q "$base_url/MesloLGS%20NF%20Regular.ttf"  -O "$font_dir/MesloLGS NF Regular.ttf"
    wget -q "$base_url/MesloLGS%20NF%20Bold.ttf"     -O "$font_dir/MesloLGS NF Bold.ttf"
    wget -q "$base_url/MesloLGS%20NF%20Italic.ttf"   -O "$font_dir/MesloLGS NF Italic.ttf"
    fc-cache -fv &>/dev/null
    ok "MesloLGS NF Font installiert."
  fi
}

### ---------- shell config ----------
write_shell_config() {
  log "Shell-Konfiguration / Aliases schreiben..."

  local rc_file="$HOME/.zshrc"
  [[ "${SHELL:-}" != */zsh ]] && rc_file="$HOME/.bashrc"
  touch "$rc_file"

  append_once ''                                                                    "$rc_file"
  append_once '# === cyber / ctf aliases ==='                                      "$rc_file"
  append_once 'alias ll="ls -lah"'                                                 "$rc_file"
  append_once 'alias la="ls -A"'                                                   "$rc_file"
  append_once 'alias ctf="cd $HOME/labs"'                                          "$rc_file"
  append_once 'alias tools="cd $HOME/tools"'                                       "$rc_file"
  append_once 'alias wordlists="cd $HOME/wordlists"'                               "$rc_file"
  append_once 'alias ports="ss -tulpn"'                                             "$rc_file"
  append_once 'alias myip="curl -4 ifconfig.me && echo"'                           "$rc_file"
  append_once 'alias myip6="curl -6 ifconfig.me && echo"'                          "$rc_file"
  append_once 'alias grepip="grep -Eo \"([0-9]{1,3}\.){3}[0-9]{1,3}\""'           "$rc_file"
  append_once 'alias pyserver="python3 -m http.server 8000"'                       "$rc_file"
  append_once 'alias reload="source ~/.zshrc 2>/dev/null || source ~/.bashrc"'     "$rc_file"
  append_once 'alias dockerps="docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""' "$rc_file"
  append_once 'export PATH="$HOME/.local/bin:$HOME/go/bin:$PATH"'                 "$rc_file"
  append_once 'export EDITOR="nvim"'                                               "$rc_file"
  append_once 'export WORDLISTS="$HOME/wordlists/SecLists"'                        "$rc_file"
  append_once 'export GOPATH="$HOME/go"'                                           "$rc_file"

  ok "Shell-Konfiguration aktualisiert."
}

### ---------- post-install ----------
finalize() {
  log "Post-Install Aufgaben..."

  # Nuclei Templates updaten
  if cmd_exists nuclei; then
    nuclei -update-templates -silent || warn "Nuclei Template-Update fehlgeschlagen"
    ok "Nuclei Templates aktuell."
  fi

  # Nuclei-Templates Repo updaten falls vorhanden
  if [[ -d "$HOME/tools/nuclei-templates/.git" ]]; then
    git -C "$HOME/tools/nuclei-templates" pull --quiet || true
  fi
}

### ---------- abschlussnachricht ----------
final_notes() {
  cat <<EOF

${GREEN}${BOLD}
╔══════════════════════════════════════════════════════╗
║        Fedora Cyber Bootstrap – Fertig!              ║
╚══════════════════════════════════════════════════════╝
${NC}
${BOLD}Installiert:${NC}
  • Core Terminal-Tools (bat, fzf, tmux, neovim, ...)
  • Security-Tools (nmap, sqlmap, hydra, hashcat, ...)
  • Go-Tools (subfinder, httpx, nuclei, ffuf, ...)
  • Python-Tools via pipx (mitmproxy, impacket, ...)
  • Docker CE + docker-compose
  • Flatpak Apps (VSCode, Obsidian, Firefox, ...)
  • Zsh + Oh-My-Zsh + Powerlevel10k
  • Wordlists & Security-Repos

${BOLD}Nächste Schritte:${NC}
  1. ${YELLOW}Neu einloggen${NC} (für docker-Gruppe und Zsh)
  2. ${YELLOW}source ~/.zshrc${NC} ausführen
  3. Tools prüfen:
       which nmap ffuf nuclei subfinder httpx sqlmap

${BOLD}Wichtige Ordner:${NC}
  ~/labs        → CTF / Übungen
  ~/tools       → Geklonte Tools
  ~/wordlists   → SecLists & Co.
  ~/reports     → Eigene Berichte
  ~/screenshots → Screenshots

${BOLD}Hinweise:${NC}
  • Nur für eigene Systeme, Labs und CTFs verwenden!
  • BloodHound/Maltego: manuell von Website installieren
  • Burp Suite: manuell von portswigger.net installieren
  • Tor Browser: über Flatpak oder torproject.org

EOF
}

### ---------- main ----------
main() {
  echo -e "${BOLD}${BLUE}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║      Fedora Cyber Bootstrap – Start                  ║"
  echo "║      Idempotent – sicher mehrfach ausführbar         ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"

  require_fedora
  require_root_or_sudo
  create_dirs
  system_update
  setup_repos
  install_core
  install_security_tools
  install_docker
  install_flatpaks
  install_go_tools
  install_pipx_tools
  clone_repos
  setup_zsh
  write_shell_config
  finalize
  final_notes
}

main "$@"