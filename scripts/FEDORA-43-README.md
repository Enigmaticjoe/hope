# Fedora 43 Deployment Scripts

This directory contains scripts specifically designed for Fedora 43 deployments.

## Scripts Overview

### 1. `install-portainer-fedora.sh`

**Purpose:** Automated installation of Docker Engine and Portainer CE on Fedora 43.

**What it does:**
- Removes old Docker installations
- Installs Docker Engine from official Docker repository
- Installs Portainer Community Edition
- Configures firewall rules (if firewalld is active)
- Sets up Portainer to auto-restart on reboot

**Usage:**
```bash
sudo ./install-portainer-fedora.sh
```

**Default Configuration:**
- Portainer Web UI: `http://localhost:9000`
- Portainer Tunnel Port: `8000`
- Data Directory: `/var/lib/portainer`

**Post-Installation:**
1. Navigate to `http://your-server-ip:9000`
2. Create an admin account (first-time login)
3. Select "Docker" as the environment type
4. Start managing your containers!

---

### 2. `shadow_ops_fedora.sh`

**Purpose:** Transform Fedora 43 into a Kali Linux-inspired offensive security workstation.

**What it does:**
- **Visual Transformation:**
  - Installs Materia Dark GTK theme
  - Installs Flat Remix Blue Dark icons
  - Sets up Kali Dragon wallpaper
  - Configures custom Conky HUD overlay
  - Applies GNOME theme settings

- **Offensive Toolkit:**
  - Network scanners: nmap, masscan, arp-scan
  - Wireless tools: aircrack-ng
  - Password crackers: john, hashcat, hydra
  - Web testing: sqlmap, nikto, dirb, gobuster
  - Exploitation: metasploit-framework
  - Python security libraries: scapy, impacket, shodan

- **Terminal Customization:**
  - Configures Terminator with dark theme
  - Custom bash aliases for common tasks
  - Kali-style command prompt

**Usage:**
```bash
sudo ./shadow_ops_fedora.sh
```

**Post-Installation:**
1. Reboot or log out/in to apply visual changes
2. Launch `gnome-tweaks` for fine-tuning
3. Open Terminator for the full terminal experience
4. Conky HUD will auto-start on login

**Custom Aliases Added:**
```bash
nmap-quick          # Fast nmap scan
nmap-full           # Full nmap scan with OS detection
scan-subnet         # Quick subnet ping scan
update              # Update package lists
upgrade             # Upgrade all packages
clean               # Clean DNF cache
ports               # Show listening ports
myip                # Show public IP address
```

---

## System Requirements

### Common Requirements:
- Fedora 43 (fresh or existing installation)
- Root/sudo access
- Active internet connection
- Minimum 10GB free disk space

### For Portainer:
- No additional requirements

### For Shadow Ops:
- GNOME Desktop Environment (recommended)
- At least 2GB RAM
- Display resolution: 1920x1080 or higher (for optimal Conky display)

---

## Integration with Project CHIMERA

These scripts are designed to work alongside the existing CHIMERA ecosystem:

### Portainer Integration:
- Complements the existing Docker Compose and Swarm deployments
- Provides GUI management for containers
- Compatible with existing stacks (infrastructure, media, ai-core, etc.)
- Can manage remote Docker hosts (including Unraid nodes)

### Shadow Ops Integration:
- Can be deployed on dedicated security workstation nodes
- Network scanning tools can audit CHIMERA infrastructure
- Terminal configuration matches the tactical theme
- Conky HUD can monitor CHIMERA service health

---

## Troubleshooting

### Portainer Installation Issues:

**Docker fails to start:**
```bash
# Check Docker service status
sudo systemctl status docker

# View Docker logs
sudo journalctl -u docker -n 50
```

**Port 9000 already in use:**
```bash
# Check what's using the port
sudo ss -tulpn | grep 9000

# Stop conflicting service or modify PORTAINER_PORT in the script
```

### Shadow Ops Installation Issues:

**Theme not applying:**
```bash
# Manually apply with gsettings
gsettings set org.gnome.desktop.interface gtk-theme 'Materia-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Flat-Remix-Blue-Dark'
```

**Conky not starting:**
```bash
# Manually start Conky
conky -c ~/.config/conky/conky.conf

# Check for errors
conky -c ~/.config/conky/conky.conf -d
```

**Network interface not showing in Conky:**
- Edit `~/.config/conky/conky.conf`
- Replace `eth0` with your actual interface name (find with `ip link`)

**Tools not available:**
- Some security tools may not be in default Fedora repos
- RPM Fusion repos are automatically enabled by the script
- Some tools may need manual compilation from source

---

## Security Considerations

### For Portainer:
- **Change default credentials immediately** after first login
- Use HTTPS in production (consider nginx reverse proxy with SSL)
- Restrict network access with firewall rules if needed
- Regularly update Portainer: `docker pull portainer/portainer-ce:latest`

### For Shadow Ops:
- **Use responsibly** - these are penetration testing tools
- Only scan networks/systems you own or have permission to test
- Some tools may be flagged by antivirus software (expected for pentesting tools)
- Keep tools updated for latest security features and bug fixes

---

## Maintenance

### Portainer Updates:
```bash
# Pull latest image
docker pull portainer/portainer-ce:latest

# Stop and remove old container
docker stop portainer && docker rm portainer

# Re-run the installation script or manually start new container
```

### Shadow Ops Updates:
```bash
# Update all installed packages
sudo dnf update -y

# Update Python security libraries
pip3 install --upgrade requests beautifulsoup4 paramiko pycryptodome impacket
```

---

## Additional Resources

- **Portainer Documentation:** https://docs.portainer.io/
- **Docker Documentation:** https://docs.docker.com/
- **Kali Linux Tools:** https://www.kali.org/tools/
- **Conky Configuration:** https://github.com/brndnmtthws/conky/wiki

---

## License & Credits

These scripts are part of Project CHIMERA and follow the same licensing.

**Credits:**
- Portainer CE: Portainer.io
- Flat Remix Icons: Daniel Ruiz de Alegría
- Materia Theme: nana-4
- Kali Wallpapers: Offensive Security
- Various open-source security tools and their maintainers

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review logs: `journalctl -xe`
3. Open an issue in the repository
4. Consult individual tool documentation

**Remember:** These are powerful tools. Use them ethically and legally.
