#!/bin/bash
# ==============================================================================
# PROJECT CHIMERA | VARIANT: SHADOW OPS | CODENAME: KALI AIO
# ==============================================================================
# TARGET:    Fedora 43 (Intel Arc Node)
# ROLE:      Unattended Deployment of Kali Aesthetics + Offensive Toolset
# VERSION:   1.0.0 (Silent Strike) - Fedora Edition
# ==============================================================================

set -e

# --- CONFIGURATION ---
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
THEME_DIR="/usr/share/themes"
ICON_DIR="/usr/share/icons"
WALLPAPER_DIR="/usr/share/backgrounds/kali"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Root Check
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] Run as root: sudo ./shadow_ops_fedora.sh${NC}"
   exit 1
fi

echo -e "${PURPLE}"
cat << "EOF"
   ___  __ __    _    ___   ___  _      __    ___  ___  ___ 
  / __||  |  |  /_\  |   \ / _ \| |    |  \  | __|| _ \| __|
  \__ \|  _  | / _ \ | |) | (_) | | \/ | - < | _| |  _/| _| 
  |___/|_| |_|/_/ \_\|___/ \___/ \__/\_|__/  |___||_|  |___|
   UNATTENDED DEPLOYMENT SEQUENCE // KALI MORPH + ARSENAL
                   FEDORA 43 EDITION
EOF
echo -e "${NC}"

# ==============================================================================
# PHASE 1: VISUAL TRANSFORMATION (The Look)
# ==============================================================================
echo -e "${BLUE}[JULES]${NC} Phase 1: Overwriting Visual Cortex..."

# 1. Silent Install of UI Tools
echo -e "${YELLOW}[1/5]${NC} Installing UI components..."
dnf install -y -q \
    terminator \
    git \
    curl \
    wget \
    dconf \
    materia-gtk-theme \
    conky \
    papirus-icon-theme \
    gnome-tweaks

# 2. Icons (Flat Remix Blue Dark)
echo -e "${YELLOW}[2/5]${NC} Installing Flat Remix Icons..."
mkdir -p "$ICON_DIR"
if [ ! -d "$ICON_DIR/Flat-Remix-Blue-Dark" ]; then
    echo -e "   - Fetching Icon Assets..."
    git clone --depth 1 https://github.com/daniruiz/flat-remix "$ICON_DIR/flat-remix-temp" > /dev/null 2>&1
    cp -r "$ICON_DIR/flat-remix-temp/Flat-Remix-Blue-Dark" "$ICON_DIR/"
    rm -rf "$ICON_DIR/flat-remix-temp"
    gtk-update-icon-cache "$ICON_DIR/Flat-Remix-Blue-Dark" 2>/dev/null || true
fi

# 3. Wallpaper (The Dragon)
echo -e "${YELLOW}[3/5]${NC} Deploying Kali Wallpaper..."
mkdir -p "$WALLPAPER_DIR"
# Try primary URL, fallback if needed
if ! wget -qO "$WALLPAPER_DIR/kali-dragon.png" "https://gitlab.com/kalilinux/packages/kali-wallpapers/-/raw/kali/master/2024.1/backgrounds/kali/kali-2024.1-16x9.png" 2>/dev/null; then
    # Fallback: download SVG with correct extension
    if wget -qO "$WALLPAPER_DIR/kali-dragon.svg" "https://www.kali.org/images/kali-dragon-icon.svg" 2>/dev/null; then
        # If imagemagick is available, convert to PNG, otherwise use SVG
        if command -v convert &> /dev/null; then
            convert "$WALLPAPER_DIR/kali-dragon.svg" "$WALLPAPER_DIR/kali-dragon.png" 2>/dev/null && \
            rm "$WALLPAPER_DIR/kali-dragon.svg" || \
            mv "$WALLPAPER_DIR/kali-dragon.svg" "$WALLPAPER_DIR/kali-dragon.png"
        else
            # Just rename if no conversion tool available (GNOME can handle SVG)
            mv "$WALLPAPER_DIR/kali-dragon.svg" "$WALLPAPER_DIR/kali-dragon.png"
        fi
    else
        echo -e "   ${YELLOW}[!]${NC} Wallpaper download failed - using system default"
    fi
fi

# 4. Conky HUD (Red Team Ops)
echo -e "${YELLOW}[4/5]${NC} Configuring HUD (Conky)..."
CONKY_DIR="$USER_HOME/.config/conky"
mkdir -p "$CONKY_DIR"

cat > "$CONKY_DIR/conky.conf" << 'CONKYCONF'
conky.config = {
    alignment = 'top_right',
    background = true,
    border_width = 1,
    cpu_avg_samples = 2,
    default_color = 'white',
    default_outline_color = 'white',
    default_shade_color = 'white',
    double_buffer = true,
    draw_borders = false,
    draw_graph_borders = true,
    draw_outline = false,
    draw_shades = false,
    extra_newline = false,
    font = 'DejaVu Sans Mono:size=10',
    gap_x = 20,
    gap_y = 60,
    minimum_height = 5,
    minimum_width = 300,
    net_avg_samples = 2,
    no_buffers = true,
    out_to_console = false,
    out_to_ncurses = false,
    out_to_stderr = false,
    out_to_x = true,
    own_window = true,
    own_window_class = 'Conky',
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_argb_visual = true,
    own_window_argb_value = 180,
    show_graph_range = false,
    show_graph_scale = false,
    stippled_borders = 0,
    update_interval = 1.0,
    uppercase = false,
    use_spacer = 'none',
    use_xft = true,
    color0 = 'red',
    color1 = 'cyan',
    color2 = 'white'
}

conky.text = [[
${color0}┌─[ ${color1}SHADOW OPS${color0} ]─[ ${color2}$nodename${color0} ]
${color0}│
${color0}├─[ ${color1}SYSTEM${color0} ]
${color0}│  ${color2}OS:        ${color}Fedora 43
${color0}│  ${color2}Kernel:    ${color}$kernel
${color0}│  ${color2}Uptime:    ${color}$uptime
${color0}│  ${color2}Load:      ${color}$loadavg
${color0}│
${color0}├─[ ${color1}RESOURCES${color0} ]
${color0}│  ${color2}CPU:       ${color}${cpu}% ${cpubar 8}
${color0}│  ${color2}RAM:       ${color}$mem/$memmax - $memperc% ${membar 8}
${color0}│  ${color2}Swap:      ${color}$swap/$swapmax - $swapperc% ${swapbar 8}
${color0}│  ${color2}Disk:      ${color}${fs_used /}/${fs_size /} ${fs_bar 8 /}
${color0}│
${color0}├─[ ${color1}NETWORK${color0} ]
${color0}│  ${color2}Gateway IF:${color}${gw_iface}
${color0}│  ${color2}IP:        ${color}${addr ${gw_iface}}
${color0}│  ${color2}Down:      ${color}${downspeed ${gw_iface}}/s ${downspeedgraph ${gw_iface} 8,100}
${color0}│  ${color2}Up:        ${color}${upspeed ${gw_iface}}/s ${upspeedgraph ${gw_iface} 8,100}
${color0}│
${color0}├─[ ${color1}PROCESSES${color0} ]
${color0}│  ${color2}Running:   ${color}$running_processes / $processes
${color0}│  ${color2}${top name 1} ${top pid 1} ${top cpu 1}%
${color0}│  ${color2}${top name 2} ${top pid 2} ${top cpu 2}%
${color0}│  ${color2}${top name 3} ${top pid 3} ${top cpu 3}%
${color0}│
${color0}└─[ ${color1}CHIMERA${color0} // ${color1}ACTIVE${color0} ]
]]
CONKYCONF

chown -R "$REAL_USER:$REAL_USER" "$CONKY_DIR"

# 5. Apply Theme via dconf for GNOME users
echo -e "${YELLOW}[5/5]${NC} Applying GNOME theme settings..."
if command -v gsettings &> /dev/null; then
    sudo -u "$REAL_USER" gsettings set org.gnome.desktop.interface gtk-theme 'Materia-dark'
    sudo -u "$REAL_USER" gsettings set org.gnome.desktop.interface icon-theme 'Flat-Remix-Blue-Dark'
    sudo -u "$REAL_USER" gsettings set org.gnome.desktop.background picture-uri "file://$WALLPAPER_DIR/kali-dragon.png"
    sudo -u "$REAL_USER" gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_DIR/kali-dragon.png"
fi

# ==============================================================================
# PHASE 2: OFFENSIVE TOOLKIT (The Arsenal)
# ==============================================================================
echo -e "\n${BLUE}[ARSENAL]${NC} Phase 2: Deploying Offensive Tools..."

# Enable RPM Fusion repositories for additional packages
echo -e "${YELLOW}[1/4]${NC} Enabling RPM Fusion repositories..."
dnf install -y -q \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 2>/dev/null || true

# Install security and pentesting tools
echo -e "${YELLOW}[2/4]${NC} Installing security tools..."
# Note: metasploit-framework not available in standard repos - install manually from Rapid7

# Define security tools to install
SECURITY_TOOLS=(
    nmap
    wireshark
    tcpdump
    netcat
    john
    aircrack-ng
    hydra
    sqlmap
    nikto
    dirb
    gobuster
    masscan
    enum4linux
    smbclient
    arp-scan
    hashcat
    ophcrack
    macchanger
)

# Track unavailable packages
UNAVAILABLE_TOOLS=()

# Try to install each tool
for tool in "${SECURITY_TOOLS[@]}"; do
    if ! dnf install -y -q "$tool" 2>/dev/null; then
        UNAVAILABLE_TOOLS+=("$tool")
    fi
done

# Report any unavailable tools
if [ ${#UNAVAILABLE_TOOLS[@]} -gt 0 ]; then
    echo -e "   ${YELLOW}[!]${NC} The following tools are not available in Fedora repos: ${UNAVAILABLE_TOOLS[*]}"
fi

# Inform about Metasploit if not installed
if ! command -v msfconsole &> /dev/null; then
    echo -e "   ${YELLOW}[!]${NC} Metasploit not installed - requires manual install from: https://www.rapid7.com/products/metasploit/download/"
fi

# Install Python security libraries
echo -e "${YELLOW}[3/4]${NC} Installing Python security libraries..."
dnf install -y -q python3-pip python3-scapy
pip3 install --quiet \
    requests \
    beautifulsoup4 \
    paramiko \
    pycryptodome \
    impacket \
    shodan \
    censys 2>/dev/null || true

# Install additional utilities
echo -e "${YELLOW}[4/4]${NC} Installing utilities..."
dnf install -y -q \
    vim \
    tmux \
    htop \
    tree \
    jq \
    whois \
    traceroute \
    net-tools \
    bind-utils \
    telnet \
    ftp

# ==============================================================================
# PHASE 3: TERMINAL CONFIGURATION
# ==============================================================================
echo -e "\n${BLUE}[TERMINAL]${NC} Phase 3: Configuring Terminator..."

TERMINATOR_DIR="$USER_HOME/.config/terminator"
mkdir -p "$TERMINATOR_DIR"

cat > "$TERMINATOR_DIR/config" << 'TERMCONF'
[global_config]
  title_transmit_bg_color = "#0076c9"
  focus = system
[keybindings]
[profiles]
  [[default]]
    background_color = "#0d1117"
    background_darkness = 0.9
    background_type = transparent
    cursor_color = "#00ff00"
    font = Monospace 11
    foreground_color = "#00ff00"
    scrollback_infinite = True
    palette = "#000000:#cc0000:#4e9a06:#c4a000:#3465a4:#75507b:#06989a:#d3d7cf:#555753:#ef2929:#8ae234:#fce94f:#729fcf:#ad7fa8:#34e2e2:#eeeeec"
    use_system_font = False
    copy_on_selection = True
    scroll_on_output = False
[layouts]
  [[default]]
    [[[window0]]]
      type = Window
      parent = ""
    [[[child1]]]
      type = Terminal
      parent = window0
      profile = default
[plugins]
TERMCONF

chown -R "$REAL_USER:$REAL_USER" "$TERMINATOR_DIR"

# ==============================================================================
# PHASE 4: BASH CUSTOMIZATION
# ==============================================================================
echo -e "\n${BLUE}[SHELL]${NC} Phase 4: Customizing Bash..."

# Add custom bash aliases
BASHRC="$USER_HOME/.bashrc"

if ! grep -q "# SHADOW OPS CUSTOM ALIASES" "$BASHRC"; then
    cat >> "$BASHRC" << 'BASHCONF'

# SHADOW OPS CUSTOM ALIASES
alias ll='ls -lah --color=auto'
alias nmap-quick='nmap -T4 -F'
alias nmap-full='nmap -T4 -A -v'
alias scan-subnet='nmap -sn'
alias update='sudo dnf update -y'
alias upgrade='sudo dnf upgrade -y'
alias clean='sudo dnf clean all'
alias ports='ss -tuln'
alias myip='curl -s ifconfig.me'

# Kali-style PS1
export PS1='\[\033[01;31m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
BASHCONF
fi

chown "$REAL_USER:$REAL_USER" "$BASHRC"

# ==============================================================================
# PHASE 5: AUTOSTART CONFIGURATION
# ==============================================================================
echo -e "\n${BLUE}[AUTOSTART]${NC} Phase 5: Setting up Conky autostart..."

AUTOSTART_DIR="$USER_HOME/.config/autostart"
mkdir -p "$AUTOSTART_DIR"

cat > "$AUTOSTART_DIR/conky.desktop" << 'AUTOSTARTCONF'
[Desktop Entry]
Type=Application
Name=Conky
Exec=conky -c ~/.config/conky/conky.conf
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Comment=Start Conky HUD on login
AUTOSTARTCONF

chown -R "$REAL_USER:$REAL_USER" "$AUTOSTART_DIR"

# ==============================================================================
# COMPLETION
# ==============================================================================
echo -e "\n${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              SHADOW OPS DEPLOYMENT COMPLETE                   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Visual Transform:${NC}"
echo -e "  ✓ Theme: Materia Dark"
echo -e "  ✓ Icons: Flat Remix Blue Dark"
echo -e "  ✓ Wallpaper: Kali Dragon"
echo -e "  ✓ HUD: Conky (Red Team Ops)"
echo ""
echo -e "${BLUE}Arsenal Deployed:${NC}"
echo -e "  ✓ Network scanners (nmap, masscan, arp-scan)"
echo -e "  ✓ Wireless tools (aircrack-ng)"
echo -e "  ✓ Password tools (john, hashcat, hydra)"
echo -e "  ✓ Web tools (sqlmap, nikto, dirb, gobuster)"
echo -e "  ✓ Python security libraries"
if command -v msfconsole &> /dev/null; then
    echo -e "  ✓ Exploitation frameworks (metasploit)"
else
    echo -e "  ⚠ Metasploit requires manual installation"
fi
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. Reboot or log out/in to apply visual changes"
echo -e "  2. Launch 'gnome-tweaks' to fine-tune appearance"
echo -e "  3. Conky will auto-start on next login"
echo -e "  4. Open Terminator for the full experience"
echo ""
echo -e "${PURPLE}SHADOW OPS STATUS: ${GREEN}OPERATIONAL${NC}"
echo ""
