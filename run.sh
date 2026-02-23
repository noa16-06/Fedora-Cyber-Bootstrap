#!/bin/bash

echo 'Weaponiized Kali'
echo 'by milchjunge'

read -p "Do you want to start the installation (y/n): answer



echo 'Started Installation'

RED='\033[0;31m]'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}[*] Update Packetlist...${NC}"
sudo apt update 

echo -e "${GREEN}[*] Upgrade Packetlist...${NC}"
sudo apt upgrade -y

echo -e "${GREEN}[*] Installing tools...${NC}"


function basic_tools {
# Basic pentest tools
sudo apt install -y nmap hydra metasploit-framework
sudo apt install -y wireshark aircrack-ng burpsuite john sqlmap
}


# Bunus tools
sudo apt install -y gobuster dirb nikto wfuzz
sudo apt install -y netcat-openbsd tcpdump traceroute
sudo apt install -y enum4linux smbclient snmpcheck

# Python tools
sudo apt install python3-pip python3-venv
pip3 install --user scapy requests beautifulsoup4

# Wireless-Tools
sudo apt install -y kismet reaver bully

# Password-Cracking
sudo apt install -y hashcat crunch cewl

# Social Engineering Tools
sudo apt install -y set

sudo apt autoremov -y
sudo apt autoclean
echo 'Installation complete'

