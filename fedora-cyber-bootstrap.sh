#!/usr/bin/env bash
set -Eeuo pipefail

############################################
# fedora-cyber-bootstrap.sh
# Full Fedora bootstrap for cybersecurity / CTF / bug bounty.
# Idempotent - safe to run multiple times.
# On each run it also UPDATES what is already installed
# (system packages, flatpaks, go/pipx/gem tools, cloned repos).
# All downloads go through a temp dir that is cleaned up on exit.
# For authorized testing, labs, and CTFs only.
#
# Usage:
#   ./fedora-cyber-bootstrap.sh            # install / update everything
#   ./fedora-cyber-bootstrap.sh --check    # only report status, change nothing
#   ./fedora-cyber-bootstrap.sh --help     # show help
############################################

### ---------- colors & helpers ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

log()    { printf "\n${BLUE}${BOLD}[*]${NC} %s\n" "$*"; }
ok()     { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
warn()   { printf "${YELLOW}[!]${NC} %s\n" "$*" >&2; }
skip()   { printf "${CYAN}[~]${NC} %s - already installed, skipping.\n" "$*"; }
update() { printf "  ${CYAN}↻${NC} update %s\n" "$*"; }
add()    { printf "  ${YELLOW}→${NC} %s\n" "$*"; }
fail()   { printf "\n${RED}[x]${NC} %s\n" "$*" >&2; exit 1; }

trap 'warn "Unexpected error on line $LINENO. Check the output above."' ERR

### ---------- base directory ----------
# Everything lives under ONE base directory instead of being scattered in $HOME.
# Override via environment, e.g.  SEC_BASE=~/pentest ./fedora-cyber-bootstrap.sh
SEC_BASE="${SEC_BASE:-$HOME/Security}"
DIR_TOOLS="$SEC_BASE/tools"
DIR_LABS="$SEC_BASE/labs"
DIR_WORDLISTS="$SEC_BASE/wordlists"
DIR_SCREENSHOTS="$SEC_BASE/screenshots"
DIR_REPORTS="$SEC_BASE/reports"
DIR_SCANS="$SEC_BASE/scans"
DIR_BIN="$SEC_BASE/bin"          # our own binaries (feroxbuster, nikto symlink, wpscan wrapper, ...)

CHECK_ONLY=0

### ---------- temp dir & cleanup ----------
TMP_DIR=""
cleanup() { [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"; }
trap cleanup EXIT

### ---------- preflight ----------
require_fedora() {
  [[ -f /etc/fedora-release ]] || fail "This script is for Fedora only."
  FEDORA_VERSION=$(rpm -E %fedora)
  log "Detected Fedora $FEDORA_VERSION."
}

require_root_or_sudo() {
  if ! sudo -v &>/dev/null; then
    fail "sudo access is required."
  fi
  ok "sudo access confirmed."
}

### ---------- helper functions ----------
dnf_installed() { rpm -q "$1" &>/dev/null; }
cmd_exists()    { command -v "$1" &>/dev/null; }

# present in PATH OR in one of our bin directories?
tool_present() {
  local bin="$1"
  cmd_exists "$bin" \
    || [[ -x "$HOME/go/bin/$bin" ]] \
    || [[ -x "$HOME/.local/bin/$bin" ]] \
    || [[ -x "$DIR_BIN/$bin" ]]
}

dnf_install_if_missing() {
  local pkg="$1"
  if dnf_installed "$pkg"; then
    skip "$pkg"
  else
    add "installing $pkg"
    sudo dnf install -y "$pkg" || warn "Could not install $pkg"
  fi
}

clone_or_update() {
  local url="$1" dest="$2" name
  name=$(basename "$dest")
  if [[ -d "$dest/.git" ]]; then
    update "$name (repo)"
    git -C "$dest" pull --quiet --ff-only || warn "Update failed: $name"
  elif [[ -d "$dest" ]]; then
    skip "$name (repo - not a git directory)"
  else
    add "clone $name"
    git clone --depth=1 "$url" "$dest" || warn "Clone failed: $url"
  fi
}

append_once() {
  local line="$1" file="$2"
  touch "$file"
  grep -Fqx "$line" "$file" || echo "$line" >> "$file"
}

pipx_install_or_upgrade() {
  local app="$1" spec="${2:-$1}"
  if pipx list --short 2>/dev/null | grep -q "^$app "; then
    update "$app (pipx)"
    pipx upgrade "$app" &>/dev/null || warn "pipx upgrade failed: $app"
  else
    add "pipx install $app"
    pipx install "$spec" || warn "pipx install failed: $app"
  fi
}

go_install_or_update() {
  local pkg="$1" bin="$2"
  if tool_present "$bin"; then update "$bin (go)"; else add "go install $bin"; fi
  go install "$pkg" || warn "go install failed: $pkg"
}

### ---------- directories ----------
create_dirs() {
  log "Creating working directories under $SEC_BASE..."
  local dirs=(
    "$SEC_BASE" "$DIR_TOOLS" "$DIR_LABS" "$DIR_WORDLISTS"
    "$DIR_SCREENSHOTS" "$DIR_REPORTS" "$DIR_SCANS" "$DIR_SCANS/nmap"
    "$DIR_BIN" "$HOME/.local/bin" "$HOME/go/bin"
  )
  for d in "${dirs[@]}"; do
    if [[ -d "$d" ]]; then skip "$d"; else mkdir -p "$d"; ok "Created: $d"; fi
  done
}

### ---------- system update ----------
system_update() {
  log "Updating system..."
  sudo dnf upgrade -y --refresh || warn "System update partially failed"
  ok "System up to date."
}

### ---------- repos ----------
setup_repos() {
  log "Setting up repositories..."
  if dnf_installed rpmfusion-free-release; then
    skip "RPM Fusion Free"
  else
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm" \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm" \
      || warn "RPM Fusion could not be installed"
    ok "RPM Fusion enabled."
  fi

  if [[ -f /etc/yum.repos.d/docker-ce.repo ]]; then
    skip "Docker CE repo"
  else
    sudo wget -q -O /etc/yum.repos.d/docker-ce.repo \
      https://download.docker.com/linux/fedora/docker-ce.repo \
      || warn "Docker repo could not be added"
    ok "Docker CE repo added."
  fi
}

### ---------- core tools ----------
install_core() {
  log "Installing core / terminal tools..."
  local pkgs=(
    git wget curl jq
    ripgrep fd-find bat tree
    tmux fzf htop btop ncdu
    neovim sqlite
    openssl gnupg
    unzip zip p7zip
    stow direnv
    zsh util-linux-user
    make gcc gcc-c++ cmake
    python3 python3-pip pipx
    golang nodejs
    # ruby + build deps: required so wpscan (yajl-ruby/nokogiri) compiles
    ruby ruby-devel rubygems zlib-devel libffi-devel openssl-devel redhat-rpm-config
    # perl-core: required for nikto
    perl-core
    socat netcat nmap tcpdump
    wireshark whois
  )
  for pkg in "${pkgs[@]}"; do dnf_install_if_missing "$pkg"; done
}

### ---------- security tools from dnf ----------
install_security_pkgs() {
  log "Installing security tools from dnf..."
  # ONLY packages that actually exist on Fedora.
  # sqlmap / nikto / wpscan / theHarvester are NOT in dnf -> see install_extra_tools()
  local pkgs=(
    hydra masscan
    john hashcat hcxtools
  )
  for pkg in "${pkgs[@]}"; do dnf_install_if_missing "$pkg"; done
}

### ---------- extra security tools (no dnf package) ----------
# This was the actual reason wpscan never showed up before:
# it was treated as a dnf package, but no such package exists there.
install_extra_tools() {
  log "Installing / updating extra tools without a dnf package..."

  # --- wpscan (Ruby gem; wrapper placed in DIR_BIN for a consistent layout) ---
  if tool_present wpscan; then
    update "wpscan (gem)"
    gem install --user-install --bindir "$DIR_BIN" wpscan &>/dev/null \
      || warn "wpscan update failed"
  else
    add "gem install wpscan"
    if gem install --user-install --bindir "$DIR_BIN" wpscan; then
      ok "wpscan installed ($DIR_BIN/wpscan)"
    else
      warn "wpscan install failed - check ruby-devel / zlib(-ng-compat)-devel / openssl-devel"
    fi
  fi

  # --- sqlmap (pipx) ---
  pipx_install_or_upgrade "sqlmap"

  # --- theHarvester (pipx from Git; no current PyPI release) ---
  if pipx list --short 2>/dev/null | grep -q "^theharvester "; then
    update "theHarvester (pipx)"
    pipx upgrade theharvester &>/dev/null || warn "theHarvester update failed"
  else
    add "pipx install theHarvester"
    pipx install "git+https://github.com/laramies/theHarvester.git" \
      || warn "theHarvester install failed"
  fi

  # --- nikto (git clone + symlink) ---
  clone_or_update "https://github.com/sullo/nikto.git" "$DIR_TOOLS/nikto"
  if [[ -f "$DIR_TOOLS/nikto/program/nikto.pl" ]]; then
    ln -sf "$DIR_TOOLS/nikto/program/nikto.pl" "$DIR_BIN/nikto"
    chmod +x "$DIR_TOOLS/nikto/program/nikto.pl" 2>/dev/null || true
    ok "nikto linked ($DIR_BIN/nikto)"
  fi

  # --- feroxbuster (binary) ---
  if tool_present feroxbuster; then
    skip "feroxbuster"
  else
    add "downloading feroxbuster"
    ( cd "$DIR_BIN" && curl -sL \
        https://raw.githubusercontent.com/epi052/feroxbuster/main/install-nix.sh \
        | bash -s -- "$DIR_BIN" ) || warn "feroxbuster install failed"
  fi

  # --- ffuf: fallback only if Go is missing (otherwise via install_go_tools) ---
  if tool_present ffuf; then
    skip "ffuf"
  else
    TMP_DIR="${TMP_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/fcb.XXXXXX")}"
    local url tgz
    url=$(curl -fsSL https://api.github.com/repos/ffuf/ffuf/releases/latest \
          | grep "browser_download_url.*linux_amd64.tar.gz" | cut -d '"' -f 4)
    tgz="$TMP_DIR/ffuf.tar.gz"
    if [[ -n "$url" ]] && wget -q "$url" -O "$tgz" \
        && tar -xzf "$tgz" -C "$TMP_DIR" ffuf && [[ -s "$TMP_DIR/ffuf" ]]; then
      install -m 0755 "$TMP_DIR/ffuf" "$DIR_BIN/ffuf"
      ok "ffuf installed ($DIR_BIN/ffuf)"
    else
      warn "ffuf download failed"
    fi
  fi
}

### ---------- docker ----------
install_docker() {
  log "Installing Docker..."
  local docker_pkgs=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
  for pkg in "${docker_pkgs[@]}"; do dnf_install_if_missing "$pkg"; done

  if systemctl is-enabled docker &>/dev/null; then
    skip "Docker service (already enabled)"
  else
    sudo systemctl enable --now docker
    ok "Docker service enabled."
  fi

  if groups "$USER" | grep -q docker; then
    skip "docker group (user already a member)"
  else
    sudo usermod -aG docker "$USER"
    ok "User added to docker group. Please log out and back in!"
  fi
}

### ---------- flatpak apps ----------
install_flatpaks() {
  log "Installing Flatpak apps..."
  cmd_exists flatpak || dnf_install_if_missing flatpak

  if flatpak remotes | grep -q flathub; then
    skip "Flathub remote"
  else
    sudo flatpak remote-add --if-not-exists flathub \
      https://flathub.org/repo/flathub.flatpakrepo
    ok "Flathub added."
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
    local app_id="${entry%%:*}" app_name="${entry##*:}"
    if flatpak list --app --columns=application 2>/dev/null | grep -qx "$app_id"; then
      update "$app_name (Flatpak)"
      flatpak update -y "$app_id" &>/dev/null || warn "$app_name update failed"
    else
      add "installing $app_name"
      flatpak install -y flathub "$app_id" || warn "$app_name install failed"
    fi
  done
}

### ---------- go tools ----------
install_go_tools() {
  log "Installing / updating Go-based tools..."
  export PATH="$HOME/go/bin:$PATH"
  go_install_or_update "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"       "subfinder"
  go_install_or_update "github.com/projectdiscovery/httpx/cmd/httpx@latest"                  "httpx"
  go_install_or_update "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"             "nuclei"
  go_install_or_update "github.com/projectdiscovery/naabu/v2/cmd/naabu@latest"               "naabu"
  go_install_or_update "github.com/projectdiscovery/katana/cmd/katana@latest"                "katana"
  go_install_or_update "github.com/projectdiscovery/dnsx/cmd/dnsx@latest"                    "dnsx"
  go_install_or_update "github.com/projectdiscovery/interactsh/cmd/interactsh-client@latest" "interactsh-client"
  go_install_or_update "github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest"        "shuffledns"
  go_install_or_update "github.com/ffuf/ffuf/v2@latest"                                      "ffuf"
  go_install_or_update "github.com/OJ/gobuster/v3@latest"                                    "gobuster"
  go_install_or_update "github.com/hakluke/hakrawler@latest"                                 "hakrawler"
  go_install_or_update "github.com/tomnomnom/waybackurls@latest"                             "waybackurls"
  go_install_or_update "github.com/tomnomnom/assetfinder@latest"                             "assetfinder"
  go_install_or_update "github.com/lc/gau/v2/cmd/gau@latest"                                 "gau"
  go_install_or_update "github.com/tomnomnom/httprobe@latest"                                "httprobe"
  go_install_or_update "github.com/ropnop/kerbrute@latest"                                   "kerbrute"
  go_install_or_update "github.com/zricethezav/gitleaks/v8@latest"                           "gitleaks"
}

### ---------- pipx tools ----------
install_pipx_tools() {
  log "Installing / updating Python-based tools (pipx)..."
  pipx ensurepath || true
  pipx_install_or_upgrade "dirsearch"
  pipx_install_or_upgrade "mitmproxy"
  pipx_install_or_upgrade "bloodhound"
  pipx_install_or_upgrade "impacket"
  pipx_install_or_upgrade "semgrep"
  pipx_install_or_upgrade "wafw00f"
  # Note: wfuzz is intentionally NOT installed - incompatible with Python 3.12+
  # (it uses the removed 'imp' module). Use ffuf / feroxbuster instead.
}

### ---------- repos & wordlists ----------
clone_repos() {
  log "Cloning / updating security repos and wordlists..."
  clone_or_update "https://github.com/danielmiessler/SecLists.git"            "$DIR_WORDLISTS/SecLists"
  clone_or_update "https://github.com/swisskyrepo/PayloadsAllTheThings.git"   "$DIR_TOOLS/PayloadsAllTheThings"
  clone_or_update "https://github.com/lgandx/Responder.git"                   "$DIR_TOOLS/Responder"
  clone_or_update "https://github.com/s0md3v/XSStrike.git"                    "$DIR_TOOLS/XSStrike"
  clone_or_update "https://github.com/danielmiessler/RobotsDisallowed.git"    "$DIR_TOOLS/RobotsDisallowed"
  clone_or_update "https://github.com/1ndianl33t/Gf-Patterns.git"             "$DIR_TOOLS/Gf-Patterns"
  clone_or_update "https://github.com/projectdiscovery/fuzzing-templates.git" "$DIR_TOOLS/fuzzing-templates"
  clone_or_update "https://github.com/projectdiscovery/nuclei-templates.git"  "$DIR_TOOLS/nuclei-templates"
  clone_or_update "https://github.com/itm4n/PrivescCheck.git"                 "$DIR_TOOLS/PrivescCheck"
  clone_or_update "https://github.com/PowerShellMafia/PowerSploit.git"        "$DIR_TOOLS/PowerSploit"
  clone_or_update "https://github.com/carlospolop/PEASS-ng.git"               "$DIR_TOOLS/PEASS-ng"
}

### ---------- zsh + oh-my-zsh + p10k ----------
setup_zsh() {
  log "Setting up Zsh / Oh-My-Zsh / Powerlevel10k..."
  if [[ "$SHELL" == */zsh ]]; then
    skip "Zsh (already the default shell)"
  else
    chsh -s "$(which zsh)" && ok "Zsh set as default shell. Please log out and back in!"
  fi

  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    skip "Oh-My-Zsh"
  else
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    ok "Oh-My-Zsh installed."
  fi

  local p10k_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
  if [[ -d "$p10k_dir" ]]; then
    skip "Powerlevel10k"
  else
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
    ok "Powerlevel10k installed."
    append_once 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"
  fi

  local font_dir="$HOME/.local/share/fonts"
  mkdir -p "$font_dir"
  if [[ -f "$font_dir/MesloLGS NF Regular.ttf" ]]; then
    skip "MesloLGS NF font"
  else
    local base_url="https://github.com/romkatv/powerlevel10k-media/raw/master"
    wget -q "$base_url/MesloLGS%20NF%20Regular.ttf" -O "$font_dir/MesloLGS NF Regular.ttf"
    wget -q "$base_url/MesloLGS%20NF%20Bold.ttf"    -O "$font_dir/MesloLGS NF Bold.ttf"
    wget -q "$base_url/MesloLGS%20NF%20Italic.ttf"  -O "$font_dir/MesloLGS NF Italic.ttf"
    fc-cache -fv &>/dev/null
    ok "MesloLGS NF font installed."
  fi
}

### ---------- shell config ----------
write_shell_config() {
  log "Writing shell configuration / aliases..."
  local rc_file="$HOME/.zshrc"
  [[ "${SHELL:-}" != */zsh ]] && rc_file="$HOME/.bashrc"
  touch "$rc_file"

  append_once ''                                                                "$rc_file"
  append_once '# === cyber / ctf aliases ==='                                   "$rc_file"
  append_once 'alias ll="ls -lah"'                                              "$rc_file"
  append_once 'alias la="ls -A"'                                                "$rc_file"
  append_once "alias ctf=\"cd $DIR_LABS\""                                      "$rc_file"
  append_once "alias tools=\"cd $DIR_TOOLS\""                                   "$rc_file"
  append_once "alias wordlists=\"cd $DIR_WORDLISTS\""                           "$rc_file"
  append_once 'alias ports="ss -tulpn"'                                         "$rc_file"
  append_once 'alias myip="curl -4 ifconfig.me && echo"'                        "$rc_file"
  append_once 'alias myip6="curl -6 ifconfig.me && echo"'                       "$rc_file"
  append_once 'alias grepip="grep -Eo \"([0-9]{1,3}\.){3}[0-9]{1,3}\""'         "$rc_file"
  append_once 'alias pyserver="python3 -m http.server 8000"'                    "$rc_file"
  append_once 'alias reload="source ~/.zshrc 2>/dev/null || source ~/.bashrc"'  "$rc_file"
  append_once 'alias dockerps="docker ps --format \"table {{.Names}}\t{{.Status}}\t{{.Ports}}\""' "$rc_file"
  append_once "export SEC_BASE=\"$SEC_BASE\""                                   "$rc_file"
  append_once "export PATH=\"\$HOME/.local/bin:\$HOME/go/bin:$DIR_BIN:\$PATH\"" "$rc_file"
  append_once 'export EDITOR="nvim"'                                            "$rc_file"
  append_once "export WORDLISTS=\"$DIR_WORDLISTS/SecLists\""                    "$rc_file"
  append_once 'export GOPATH="$HOME/go"'                                        "$rc_file"

  ok "Shell configuration updated ($rc_file)."
}

### ---------- post-install ----------
finalize() {
  log "Post-install tasks..."
  if cmd_exists nuclei; then
    nuclei -update-templates -silent || warn "Nuclei template update failed"
    ok "Nuclei templates up to date."
  fi
  if [[ -d "$DIR_TOOLS/nuclei-templates/.git" ]]; then
    git -C "$DIR_TOOLS/nuclei-templates" pull --quiet || true
  fi
}

### ---------- status check ----------
# Shows, for each important tool, whether it is present. Changes nothing.
print_status() {
  export PATH="$HOME/go/bin:$HOME/.local/bin:$DIR_BIN:$PATH"
  log "Status overview (installed / missing)"

  local cli=(
    git wget curl jq rg fd bat tree tmux fzf htop btop ncdu nvim
    make gcc go node ruby gem python3 pipx docker flatpak
    nmap masscan tcpdump whois socat hydra john hashcat
    sqlmap nikto wpscan theHarvester
    ffuf feroxbuster gobuster subfinder httpx nuclei naabu katana dnsx
    hakrawler waybackurls assetfinder gau httprobe kerbrute gitleaks
    dirsearch mitmproxy wafw00f semgrep
  )
  local miss=0
  for c in "${cli[@]}"; do
    if tool_present "$c"; then
      printf "  ${GREEN}[✓]${NC} %-18s %s\n" "$c" "$(command -v "$c" 2>/dev/null || echo "$DIR_BIN/$c")"
    else
      printf "  ${RED}[x]${NC} %-18s MISSING\n" "$c"; miss=$((miss+1))
    fi
  done

  echo
  log "Repos / wordlists"
  for r in "$DIR_WORDLISTS/SecLists" "$DIR_TOOLS/PayloadsAllTheThings" \
           "$DIR_TOOLS/nuclei-templates" "$DIR_TOOLS/PEASS-ng" "$DIR_TOOLS/Responder"; do
    if [[ -d "$r" ]]; then printf "  ${GREEN}[✓]${NC} %s\n" "$r"
    else printf "  ${RED}[x]${NC} %s MISSING\n" "$r"; fi
  done

  echo
  if [[ "$miss" -eq 0 ]]; then
    ok "All checked CLI tools are present."
  else
    warn "$miss CLI tool(s) missing. To install them: ./fedora-cyber-bootstrap.sh"
  fi
}

### ---------- final message ----------
final_notes() {
  cat <<EOF

${GREEN}${BOLD}
╔══════════════════════════════════════════════════════╗
║        Fedora Cyber Bootstrap - Done!               ║
╚══════════════════════════════════════════════════════╝
${NC}
${BOLD}Next steps:${NC}
  1. ${YELLOW}Log out and back in${NC} (for the docker group and Zsh)
  2. Run ${YELLOW}source ~/.zshrc${NC}
  3. Check status:
       ${YELLOW}./fedora-cyber-bootstrap.sh --check${NC}

${BOLD}Everything bundled under ${SEC_BASE}:${NC}
  $DIR_LABS        → CTF / practice
  $DIR_TOOLS       → cloned tools + own binaries
  $DIR_WORDLISTS   → SecLists & co.
  $DIR_REPORTS     → your reports
  $DIR_SCANS/nmap  → scan results
  $DIR_BIN         → feroxbuster, nikto, ffuf fallback

${BOLD}Notes:${NC}
  • Use only on your own systems, labs, and CTFs!
  • wpscan / nikto / feroxbuster live in $DIR_BIN
  • Burp Suite / BloodHound GUI / Maltego: install manually

EOF
}

usage() {
  cat <<EOF
fedora-cyber-bootstrap.sh - Fedora setup for security / CTF / bug bounty

  (no option)     Install or update everything. Safe to run multiple times.
  --check, -c     Only show status (what's present, what's missing). Changes nothing.
  --help,  -h     This help.

Override the base directory:  SEC_BASE=~/pentest ./fedora-cyber-bootstrap.sh
EOF
}

### ---------- main ----------
main() {
  case "${1:-}" in
    -h|--help)  usage; exit 0 ;;
    -c|--check) CHECK_ONLY=1 ;;
    "")         : ;;
    *)          warn "Unknown option: $1"; usage; exit 1 ;;
  esac

  echo -e "${BOLD}${BLUE}"
  echo "╔══════════════════════════════════════════════════════╗"
  echo "║      Fedora Cyber Bootstrap                          ║"
  echo "║      Installs & updates - run it multiple times      ║"
  echo "╚══════════════════════════════════════════════════════╝"
  echo -e "${NC}"

  require_fedora

  if [[ "$CHECK_ONLY" -eq 1 ]]; then
    print_status
    exit 0
  fi

  require_root_or_sudo
  create_dirs
  system_update
  setup_repos
  install_core
  install_security_pkgs
  install_extra_tools
  install_docker
  install_flatpaks
  install_go_tools
  install_pipx_tools
  clone_repos
  setup_zsh
  write_shell_config
  finalize
  print_status
  final_notes
}

main "$@"
