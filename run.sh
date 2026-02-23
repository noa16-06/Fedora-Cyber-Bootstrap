#!/bin/bash

# =============================================
# Weaponiized Kali Installation Script
# by milchjunge
# =============================================

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Header
echo -e "${BLUE}==============================${NC}"
echo -e "${GREEN}Weaponiized Kali${NC}"
echo -e "${BLUE}by milchjunge${NC}"
echo -e "${BLUE}==============================${NC}"

# Funktionen
print_status() {
    echo -e "${GREEN}[*] $1${NC}"
}

print_error() {
    echo -e "${RED}[!] $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}[?] $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Dieses Skript sollte mit sudo ausgeführt werden!"
        print_warning "Starte neu mit sudo..."
        sudo bash "$0"
        exit
    fi
}

install_basic_tools() {
    print_status "Installiere Basis-Tools..."
    sudo apt install -y nmap hydra metasploit-framework \
        wireshark aircrack-ng burpsuite john sqlmap
}

install_bonus_tools() {
    print_status "Installiere Bonus-Tools..."
    sudo apt install -y gobuster dirb nikto wfuzz \
        netcat-openbsd tcpdump traceroute \
        enum4linux smbclient snmpcheck
}

install_python_tools() {
    print_status "Installiere Python-Tools..."
    sudo apt install -y python3-pip python3-venv
    pip3 install --user scapy requests beautifulsoup4
}

install_wireless_tools() {
    print_status "Installiere Wireless-Tools..."
    sudo apt install -y kismet reaver bully
}

install_password_tools() {
    print_status "Installiere Password-Cracking-Tools..."
    sudo apt install -y hashcat crunch cewl
}

install_social_tools() {
    print_status "Installiere Social Engineering Tools..."
    sudo apt install -y set
}

cleanup_system() {
    print_status "Bereinige System..."
    sudo apt autoremove -y
    sudo apt autoclean
}

update_system() {
    print_status "Update Paketlisten..."
    sudo apt update
    
    print_status "Upgrade Pakete..."
    sudo apt upgrade -y
}

show_menu() {
    echo ""
    echo -e "${BLUE}Wähle eine Installationsoption:${NC}"
    echo "1) Alle Tools installieren"
    echo "2) Nur Basis-Tools"
    echo "3) Benutzerdefinierte Auswahl"
    echo "4) Beenden"
    read -p "Deine Wahl (1-4): " menu_choice
    
    case $menu_choice in
        1)
            update_system
            install_basic_tools
            install_bonus_tools
            install_python_tools
            install_wireless_tools
            install_password_tools
            install_social_tools
            cleanup_system
            print_status "Alle Tools wurden installiert!"
            ;;
        2)
            update_system
            install_basic_tools
            cleanup_system
            print_status "Basis-Tools wurden installiert!"
            ;;
        3)
            custom_install
            ;;
        4)
            print_status "Auf Wiedersehen!"
            exit 0
            ;;
        *)
            print_error "Ungültige Auswahl!"
            show_menu
            ;;
    esac
}

custom_install() {
    echo ""
    print_warning "Wähle Tools zum Installieren (mehrere mit Leerzeichen):"
    echo "1) Basis-Tools (nmap, hydra, metasploit, etc.)"
    echo "2) Bonus-Tools (gobuster, nikto, etc.)"
    echo "3) Python-Tools"
    echo "4) Wireless-Tools"
    echo "5) Password-Cracking"
    echo "6) Social Engineering"
    echo ""
    echo "Beispiel: '1 3 5' für Basis, Python und Password-Tools"
    read -p "Deine Wahl: " custom_choice
    
    update_system
    
    for choice in $custom_choice; do
        case $choice in
            1) install_basic_tools ;;
            2) install_bonus_tools ;;
            3) install_python_tools ;;
            4) install_wireless_tools ;;
            5) install_password_tools ;;
            6) install_social_tools ;;
            *) print_error "Ungültige Auswahl: $choice" ;;
        esac
    done
    
    cleanup_system
    print_status "Installation abgeschlossen!"
}

# Hauptprogramm
main() {
    check_root
    
    read -p "Möchtest du die Installation starten? (y/n): " answer
    if [[ $answer == 'y' || $answer == 'Y' ]]; then
        show_menu
    else
        print_error "Installation abgebrochen."
        exit 0
    fi
}

# Skript starten
main