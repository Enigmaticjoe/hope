#!/usr/bin/env python3
"""
Media Stack Configurator - Project Chimera (Unraid Edition)
============================================================
Automated cross-configuration tool for the arr suite, Plex, and Real-Debrid integration.

Designed specifically for Unraid environments with automatic Docker container detection,
API key extraction, and Unraid-standard path configuration.

This tool automatically discovers and wires together:
- Prowlarr → Sonarr/Radarr (indexer sync)
- Rdt-Client → Sonarr/Radarr (download client)
- Bazarr → Sonarr/Radarr (subtitles)
- Overseerr → Sonarr/Radarr/Plex (requests)
- Root folders and quality profiles
- Zurg/Rclone mount integration

Usage:
    python3 media_configurator.py discover          # Scan for Docker containers
    python3 media_configurator.py configure         # Run full configuration
    python3 media_configurator.py configure --auto  # Auto-detect everything
    python3 media_configurator.py configure --dry-run  # Preview changes
    python3 media_configurator.py status            # Check integration status
    python3 media_configurator.py extract-keys      # Extract API keys from configs

Unraid-specific features:
- Automatic Docker container detection via docker inspect
- API key extraction from container config files
- Unraid path conventions (/mnt/user/...)
- Integration with Portainer-deployed stacks
"""

import argparse
import json
import os
import re
import sys
import time
import socket
import subprocess
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field, asdict
from pathlib import Path
from typing import Optional, Dict, List, Any, Tuple
from urllib.parse import urljoin
import urllib.request
import urllib.error
import ssl

# ============================================================================
# Configuration
# ============================================================================

# Config file location - store in /boot/config for persistence across reboots on Unraid
UNRAID_CONFIG_DIR = Path("/boot/config/plugins/chimera")
CONFIG_FILE = UNRAID_CONFIG_DIR / "media_stack_config.json" if UNRAID_CONFIG_DIR.parent.exists() else Path(__file__).parent / "config.json"
DEFAULT_TIMEOUT = 10

# Default service ports
DEFAULT_PORTS = {
    "sonarr": 8989,
    "radarr": 7878,
    "prowlarr": 9696,
    "bazarr": 6767,
    "overseerr": 5055,
    "plex": 32400,
    "rdt-client": 6500,
    "tautulli": 8181,
    "zurg": 9090,
}

# Unraid standard paths
UNRAID_PATHS = {
    "media": "/mnt/user/media",
    "movies": "/mnt/user/media/movies",
    "tv": "/mnt/user/media/tv",
    "downloads": "/mnt/user/downloads",
    "realdebrid": "/mnt/user/realdebrid",
    "appdata": "/mnt/user/appdata",
}

# Docker container name patterns (case-insensitive matching)
CONTAINER_PATTERNS = {
    "sonarr": ["sonarr"],
    "radarr": ["radarr"],
    "prowlarr": ["prowlarr"],
    "bazarr": ["bazarr"],
    "overseerr": ["overseerr", "jellyseerr"],
    "plex": ["plex", "plexmediaserver"],
    "rdt-client": ["rdt-client", "rdtclient", "rdt_client"],
    "tautulli": ["tautulli"],
    "zurg": ["zurg"],
}

# ============================================================================
# ANSI Colors (no external dependencies)
# ============================================================================

class Colors:
    HEADER = '\033[95m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BOLD = '\033[1m'
    DIM = '\033[2m'
    RESET = '\033[0m'

def print_header(text: str):
    print(f"\n{Colors.CYAN}{Colors.BOLD}{'='*60}{Colors.RESET}")
    print(f"{Colors.CYAN}{Colors.BOLD}  {text}{Colors.RESET}")
    print(f"{Colors.CYAN}{Colors.BOLD}{'='*60}{Colors.RESET}\n")

def print_success(text: str):
    print(f"  {Colors.GREEN}✓{Colors.RESET} {text}")

def print_error(text: str):
    print(f"  {Colors.RED}✗{Colors.RESET} {text}")

def print_warning(text: str):
    print(f"  {Colors.YELLOW}⚠{Colors.RESET} {text}")

def print_info(text: str):
    print(f"  {Colors.BLUE}ℹ{Colors.RESET} {text}")

def print_step(num: int, total: int, text: str):
    print(f"\n{Colors.BOLD}[{num}/{total}]{Colors.RESET} {text}")

# ============================================================================
# Data Classes
# ============================================================================

@dataclass
class ServiceConfig:
    name: str
    url: str
    api_key: str = ""
    enabled: bool = True
    verified: bool = False
    version: str = ""

@dataclass
class Config:
    sonarr: Optional[ServiceConfig] = None
    radarr: Optional[ServiceConfig] = None
    prowlarr: Optional[ServiceConfig] = None
    bazarr: Optional[ServiceConfig] = None
    overseerr: Optional[ServiceConfig] = None
    plex: Optional[ServiceConfig] = None
    rdt_client: Optional[ServiceConfig] = None
    tautulli: Optional[ServiceConfig] = None
    zurg: Optional[ServiceConfig] = None

    # Unraid paths (can be internal Docker paths or host paths)
    movies_path: str = "/mnt/user/media/movies"
    tv_path: str = "/mnt/user/media/tv"
    downloads_path: str = "/mnt/user/downloads"
    realdebrid_path: str = "/mnt/user/realdebrid"
    appdata_path: str = "/mnt/user/appdata"

    # Internal container paths (for services running in Docker)
    internal_movies_path: str = "/data/media/movies"
    internal_tv_path: str = "/data/media/tv"
    internal_downloads_path: str = "/data/downloads"

    def to_dict(self) -> dict:
        result = {}
        for key, value in self.__dict__.items():
            if isinstance(value, ServiceConfig):
                result[key] = asdict(value) if value else None
            else:
                result[key] = value
        return result

    @classmethod
    def from_dict(cls, data: dict) -> 'Config':
        config = cls()
        service_keys = ['sonarr', 'radarr', 'prowlarr', 'bazarr', 'overseerr', 'plex', 'rdt_client', 'tautulli', 'zurg']
        for key, value in data.items():
            if key in service_keys:
                if value:
                    setattr(config, key, ServiceConfig(**value))
            elif hasattr(config, key):
                setattr(config, key, value)
        return config

# ============================================================================
# API Client
# ============================================================================

class APIClient:
    """Simple HTTP client for *arr APIs (no external dependencies)"""

    def __init__(self, base_url: str, api_key: str = "", timeout: int = DEFAULT_TIMEOUT):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.timeout = timeout
        # Create SSL context that doesn't verify (for local services)
        self.ssl_context = ssl.create_default_context()
        self.ssl_context.check_hostname = False
        self.ssl_context.verify_mode = ssl.CERT_NONE

    def _request(self, method: str, endpoint: str, data: dict = None) -> Tuple[int, Any]:
        """Make HTTP request and return (status_code, response_data)"""
        url = urljoin(self.base_url + '/', endpoint.lstrip('/'))

        headers = {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
        }
        if self.api_key:
            headers['X-Api-Key'] = self.api_key

        body = json.dumps(data).encode('utf-8') if data else None

        req = urllib.request.Request(url, data=body, headers=headers, method=method)

        try:
            with urllib.request.urlopen(req, timeout=self.timeout, context=self.ssl_context) as response:
                response_data = response.read().decode('utf-8')
                try:
                    return response.status, json.loads(response_data) if response_data else {}
                except json.JSONDecodeError:
                    return response.status, response_data
        except urllib.error.HTTPError as e:
            try:
                error_body = e.read().decode('utf-8')
                return e.code, json.loads(error_body) if error_body else {}
            except:
                return e.code, str(e)
        except urllib.error.URLError as e:
            return 0, str(e.reason)
        except Exception as e:
            return 0, str(e)

    def get(self, endpoint: str) -> Tuple[int, Any]:
        return self._request('GET', endpoint)

    def post(self, endpoint: str, data: dict) -> Tuple[int, Any]:
        return self._request('POST', endpoint, data)

    def put(self, endpoint: str, data: dict) -> Tuple[int, Any]:
        return self._request('PUT', endpoint, data)

    def delete(self, endpoint: str) -> Tuple[int, Any]:
        return self._request('DELETE', endpoint)

# ============================================================================
# Service Discovery
# ============================================================================

def check_port(host: str, port: int, timeout: float = 2.0) -> bool:
    """Check if a port is open on a host"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except:
        return False

def get_docker_containers() -> List[Dict[str, Any]]:
    """Get list of running Docker containers with their details"""
    try:
        result = subprocess.run(
            ["docker", "ps", "--format", "{{json .}}"],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode != 0:
            return []

        containers = []
        for line in result.stdout.strip().split('\n'):
            if line:
                try:
                    containers.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
        return containers
    except Exception as e:
        print_warning(f"Failed to get Docker containers: {e}")
        return []

def inspect_container(container_id: str) -> Optional[Dict]:
    """Get detailed container information via docker inspect"""
    try:
        result = subprocess.run(
            ["docker", "inspect", container_id],
            capture_output=True, text=True, timeout=10
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            return data[0] if data else None
    except:
        pass
    return None

def get_container_ip(container_id: str) -> Optional[str]:
    """Get container IP address"""
    info = inspect_container(container_id)
    if info:
        networks = info.get("NetworkSettings", {}).get("Networks", {})
        for net in networks.values():
            ip = net.get("IPAddress")
            if ip:
                return ip
    return None

def get_container_port_mapping(container_id: str, internal_port: int) -> Optional[int]:
    """Get the host port mapped to an internal container port"""
    info = inspect_container(container_id)
    if info:
        ports = info.get("NetworkSettings", {}).get("Ports", {})
        port_key = f"{internal_port}/tcp"
        if port_key in ports and ports[port_key]:
            return int(ports[port_key][0].get("HostPort", internal_port))
    return None

def extract_api_key_from_config(appdata_path: str, service: str) -> Optional[str]:
    """Extract API key from service config file in appdata"""

    # Common config file locations
    config_paths = {
        "sonarr": ["config.xml", "config/config.xml"],
        "radarr": ["config.xml", "config/config.xml"],
        "prowlarr": ["config.xml", "config/config.xml"],
        "bazarr": ["config/config.yaml", "config.yaml", "data/config/config.yaml"],
        "tautulli": ["config.ini", "Tautulli.db"],
    }

    paths_to_try = config_paths.get(service, ["config.xml"])

    for config_file in paths_to_try:
        full_path = Path(appdata_path) / service / config_file

        # Also try with capitalized service name
        if not full_path.exists():
            full_path = Path(appdata_path) / service.capitalize() / config_file

        if full_path.exists():
            try:
                if config_file.endswith('.xml'):
                    tree = ET.parse(full_path)
                    root = tree.getroot()
                    api_key_elem = root.find('ApiKey')
                    if api_key_elem is not None and api_key_elem.text:
                        return api_key_elem.text
                elif config_file.endswith('.yaml'):
                    with open(full_path) as f:
                        content = f.read()
                        # Simple YAML parsing for api_key
                        match = re.search(r'api_?key[:\s]+["\']?([a-zA-Z0-9]+)["\']?', content, re.IGNORECASE)
                        if match:
                            return match.group(1)
                elif config_file.endswith('.ini'):
                    with open(full_path) as f:
                        content = f.read()
                        match = re.search(r'api_?key\s*=\s*([a-zA-Z0-9]+)', content, re.IGNORECASE)
                        if match:
                            return match.group(1)
            except Exception as e:
                print_warning(f"Failed to parse {full_path}: {e}")

    return None

def discover_from_docker() -> Dict[str, Dict[str, Any]]:
    """Discover services from running Docker containers (Unraid-optimized)"""

    discovered = {}
    containers = get_docker_containers()

    if not containers:
        print_warning("No Docker containers found or Docker not accessible")
        return discovered

    print_info(f"Found {len(containers)} running containers, scanning...")

    for container in containers:
        container_name = container.get("Names", "").lower()
        container_id = container.get("ID", "")

        for service, patterns in CONTAINER_PATTERNS.items():
            if any(pattern in container_name for pattern in patterns):
                # Get container IP
                ip = get_container_ip(container_id)
                port = DEFAULT_PORTS.get(service, 80)

                # Try localhost with mapped port first (more reliable for Unraid)
                host_port = get_container_port_mapping(container_id, port)
                if host_port and check_port("localhost", host_port):
                    url = f"http://localhost:{host_port}"
                elif ip and check_port(ip, port):
                    url = f"http://{ip}:{port}"
                elif check_port("localhost", port):
                    url = f"http://localhost:{port}"
                else:
                    continue

                discovered[service] = {
                    "url": url,
                    "container_id": container_id,
                    "container_name": container_name,
                }
                print_success(f"Found {service} at {url} (container: {container_name})")
                break

    return discovered

def discover_services(hosts: List[str] = None) -> Dict[str, str]:
    """Discover available services by scanning Docker containers and common ports"""

    # First try Docker container discovery (preferred for Unraid)
    docker_discovered = discover_from_docker()
    discovered = {k: v["url"] for k, v in docker_discovered.items()}

    # Fall back to port scanning for any missing services
    if hosts is None:
        hosts = ["localhost", "127.0.0.1"]
        # Try to get Docker network IPs
        try:
            result = subprocess.run(
                ["docker", "network", "inspect", "bridge", "-f", "{{range .IPAM.Config}}{{.Gateway}}{{end}}"],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                gateway = result.stdout.strip()
                # Scan common docker IP range
                base = '.'.join(gateway.split('.')[:3])
                hosts.extend([f"{base}.{i}" for i in range(2, 20)])
        except:
            pass

    print_info("Scanning ports for additional services...")

    for service, port in DEFAULT_PORTS.items():
        if service in discovered:
            continue

        for host in hosts:
            if check_port(host, port):
                url = f"http://{host}:{port}"
                discovered[service] = url
                print_success(f"Found {service} at {url}")
                break

    # Also try Docker hostnames
    for service, port in DEFAULT_PORTS.items():
        if service not in discovered:
            if check_port(service, port):
                url = f"http://{service}:{port}"
                discovered[service] = url
                print_success(f"Found {service} at {url}")

    return discovered

def auto_discover_with_keys(appdata_path: str = None) -> Dict[str, Dict[str, str]]:
    """Discover services AND extract their API keys from config files"""

    if appdata_path is None:
        appdata_path = UNRAID_PATHS.get("appdata", "/mnt/user/appdata")

    discovered = discover_from_docker()

    print_info(f"Extracting API keys from {appdata_path}...")

    for service, info in discovered.items():
        api_key = extract_api_key_from_config(appdata_path, service)
        if api_key:
            info["api_key"] = api_key
            print_success(f"Extracted API key for {service}")
        else:
            print_warning(f"Could not extract API key for {service}")

    return discovered

def verify_service(name: str, url: str, api_key: str = "") -> Tuple[bool, str]:
    """Verify a service is accessible and get its version"""
    client = APIClient(url, api_key)

    # Different endpoints for different services
    endpoints = {
        "sonarr": "/api/v3/system/status",
        "radarr": "/api/v3/system/status",
        "prowlarr": "/api/v1/system/status",
        "bazarr": "/api/system/status",
        "overseerr": "/api/v1/status",
        "plex": "/identity",
        "rdt-client": "/api/settings",
        "tautulli": "/api/v2?cmd=status",
    }

    endpoint = endpoints.get(name, "/api/v1/system/status")

    # For Plex, use X-Plex-Token instead
    if name == "plex" and api_key:
        endpoint = f"/identity?X-Plex-Token={api_key}"
        client.api_key = ""

    status, response = client.get(endpoint)

    if status == 200:
        version = ""
        if isinstance(response, dict):
            version = response.get('version', response.get('Version', ''))
        return True, version
    elif status == 401:
        return False, "Invalid API key"
    elif status == 0:
        return False, f"Connection failed: {response}"
    else:
        return False, f"HTTP {status}"

# ============================================================================
# Configuration Functions
# ============================================================================

def get_existing_items(client: APIClient, endpoint: str, name_field: str = "name") -> Dict[str, dict]:
    """Get existing items from an API endpoint, keyed by name"""
    status, response = client.get(endpoint)
    if status == 200 and isinstance(response, list):
        return {item.get(name_field, ""): item for item in response}
    return {}

def add_download_client_to_arr(
    arr_client: APIClient,
    arr_name: str,
    rdt_host: str,
    rdt_port: int = 6500,
    dry_run: bool = False
) -> bool:
    """Add Rdt-Client as download client to Sonarr/Radarr"""

    # Check if already exists
    existing = get_existing_items(arr_client, "/api/v3/downloadclient")
    if "Chimera-Debrid" in existing:
        print_info(f"Download client already exists in {arr_name}")
        return True

    # Rdt-Client pretends to be qBittorrent
    payload = {
        "enable": True,
        "protocol": "torrent",
        "priority": 1,
        "name": "Chimera-Debrid",
        "implementation": "QBittorrent",
        "configContract": "QBittorrentSettings",
        "fields": [
            {"name": "host", "value": rdt_host},
            {"name": "port", "value": rdt_port},
            {"name": "useSsl", "value": False},
            {"name": "urlBase", "value": ""},
            {"name": "username", "value": ""},
            {"name": "password", "value": ""},
            {"name": "tvCategory" if arr_name == "Sonarr" else "movieCategory",
             "value": "tv-sonarr" if arr_name == "Sonarr" else "radarr"},
            {"name": "recentTvPriority" if arr_name == "Sonarr" else "recentMoviePriority", "value": 0},
            {"name": "olderTvPriority" if arr_name == "Sonarr" else "olderMoviePriority", "value": 0},
            {"name": "initialState", "value": 0},
            {"name": "sequentialOrder", "value": False},
            {"name": "firstAndLast", "value": False},
        ],
        "tags": [],
    }

    if dry_run:
        print_info(f"[DRY-RUN] Would add Chimera-Debrid to {arr_name}")
        return True

    status, response = arr_client.post("/api/v3/downloadclient", payload)

    if status in [200, 201]:
        print_success(f"Added Chimera-Debrid download client to {arr_name}")
        return True
    else:
        print_error(f"Failed to add download client to {arr_name}: {response}")
        return False

def add_root_folder_to_arr(
    arr_client: APIClient,
    arr_name: str,
    path: str,
    dry_run: bool = False
) -> bool:
    """Add root folder to Sonarr/Radarr"""

    # Check if already exists
    status, existing = arr_client.get("/api/v3/rootfolder")
    if status == 200 and isinstance(existing, list):
        for folder in existing:
            if folder.get("path") == path:
                print_info(f"Root folder {path} already exists in {arr_name}")
                return True

    payload = {"path": path}

    if dry_run:
        print_info(f"[DRY-RUN] Would add root folder {path} to {arr_name}")
        return True

    status, response = arr_client.post("/api/v3/rootfolder", payload)

    if status in [200, 201]:
        print_success(f"Added root folder {path} to {arr_name}")
        return True
    else:
        print_error(f"Failed to add root folder to {arr_name}: {response}")
        return False

def sync_prowlarr_to_arrs(
    prowlarr_client: APIClient,
    sonarr_config: Optional[ServiceConfig],
    radarr_config: Optional[ServiceConfig],
    dry_run: bool = False
) -> bool:
    """Sync Prowlarr indexers to Sonarr/Radarr"""

    success = True

    # Get existing applications in Prowlarr
    existing_apps = get_existing_items(prowlarr_client, "/api/v1/applications")

    apps_to_add = []

    if sonarr_config and sonarr_config.verified:
        if "Sonarr" not in existing_apps:
            apps_to_add.append({
                "name": "Sonarr",
                "syncLevel": "fullSync",
                "implementation": "Sonarr",
                "configContract": "SonarrSettings",
                "fields": [
                    {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
                    {"name": "baseUrl", "value": sonarr_config.url},
                    {"name": "apiKey", "value": sonarr_config.api_key},
                    {"name": "syncCategories", "value": [5000, 5010, 5020, 5030, 5040, 5045, 5050]},
                ],
                "tags": [],
            })
        else:
            print_info("Sonarr already configured in Prowlarr")

    if radarr_config and radarr_config.verified:
        if "Radarr" not in existing_apps:
            apps_to_add.append({
                "name": "Radarr",
                "syncLevel": "fullSync",
                "implementation": "Radarr",
                "configContract": "RadarrSettings",
                "fields": [
                    {"name": "prowlarrUrl", "value": "http://prowlarr:9696"},
                    {"name": "baseUrl", "value": radarr_config.url},
                    {"name": "apiKey", "value": radarr_config.api_key},
                    {"name": "syncCategories", "value": [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060]},
                ],
                "tags": [],
            })
        else:
            print_info("Radarr already configured in Prowlarr")

    for app in apps_to_add:
        if dry_run:
            print_info(f"[DRY-RUN] Would add {app['name']} to Prowlarr")
            continue

        status, response = prowlarr_client.post("/api/v1/applications", app)
        if status in [200, 201]:
            print_success(f"Added {app['name']} to Prowlarr")
        else:
            print_error(f"Failed to add {app['name']} to Prowlarr: {response}")
            success = False

    # Trigger sync
    if not dry_run and apps_to_add:
        print_info("Triggering Prowlarr sync...")
        prowlarr_client.post("/api/v1/command", {"name": "ApplicationIndexerSync"})

    return success

def configure_bazarr(
    bazarr_client: APIClient,
    sonarr_config: Optional[ServiceConfig],
    radarr_config: Optional[ServiceConfig],
    dry_run: bool = False
) -> bool:
    """Configure Bazarr to connect to Sonarr/Radarr"""

    # Get current settings
    status, settings = bazarr_client.get("/api/system/settings")
    if status != 200:
        print_error(f"Failed to get Bazarr settings: {settings}")
        return False

    if not isinstance(settings, dict):
        print_error("Unexpected Bazarr settings format")
        return False

    updated = False

    # Configure Sonarr connection
    if sonarr_config and sonarr_config.verified:
        sonarr_settings = settings.get("sonarr", {})
        if not sonarr_settings.get("ip") or sonarr_settings.get("apikey") != sonarr_config.api_key:
            settings["sonarr"] = {
                "ip": sonarr_config.url.replace("http://", "").replace("https://", ""),
                "port": 8989,
                "apikey": sonarr_config.api_key,
                "ssl": False,
                "base_url": "",
                "only_monitored": False,
                "series_sync": 60,
                "episodes_sync": 60,
            }
            updated = True
            print_info("Configured Sonarr connection in Bazarr")

    # Configure Radarr connection
    if radarr_config and radarr_config.verified:
        radarr_settings = settings.get("radarr", {})
        if not radarr_settings.get("ip") or radarr_settings.get("apikey") != radarr_config.api_key:
            settings["radarr"] = {
                "ip": radarr_config.url.replace("http://", "").replace("https://", ""),
                "port": 7878,
                "apikey": radarr_config.api_key,
                "ssl": False,
                "base_url": "",
                "only_monitored": False,
                "movies_sync": 60,
            }
            updated = True
            print_info("Configured Radarr connection in Bazarr")

    if not updated:
        print_info("Bazarr already configured")
        return True

    if dry_run:
        print_info("[DRY-RUN] Would update Bazarr settings")
        return True

    status, response = bazarr_client.post("/api/system/settings", settings)
    if status in [200, 201, 204]:
        print_success("Updated Bazarr settings")
        return True
    else:
        print_error(f"Failed to update Bazarr settings: {response}")
        return False

def configure_overseerr(
    overseerr_client: APIClient,
    sonarr_config: Optional[ServiceConfig],
    radarr_config: Optional[ServiceConfig],
    plex_config: Optional[ServiceConfig],
    dry_run: bool = False
) -> bool:
    """Configure Overseerr to connect to Sonarr/Radarr/Plex"""

    success = True

    # Get existing Radarr servers
    if radarr_config and radarr_config.verified:
        status, existing = overseerr_client.get("/api/v1/settings/radarr")

        if status == 200:
            has_radarr = False
            if isinstance(existing, list):
                has_radarr = any(s.get("name") == "Radarr" for s in existing)

            if not has_radarr:
                payload = {
                    "name": "Radarr",
                    "hostname": radarr_config.url.replace("http://", "").replace("https://", "").split(":")[0],
                    "port": 7878,
                    "apiKey": radarr_config.api_key,
                    "useSsl": False,
                    "activeProfileId": 1,
                    "activeDirectory": "/data/media/movies",
                    "is4k": False,
                    "minimumAvailability": "released",
                    "isDefault": True,
                    "externalUrl": radarr_config.url,
                }

                if dry_run:
                    print_info("[DRY-RUN] Would add Radarr to Overseerr")
                else:
                    status, response = overseerr_client.post("/api/v1/settings/radarr", payload)
                    if status in [200, 201]:
                        print_success("Added Radarr to Overseerr")
                    else:
                        print_error(f"Failed to add Radarr to Overseerr: {response}")
                        success = False
            else:
                print_info("Radarr already configured in Overseerr")

    # Get existing Sonarr servers
    if sonarr_config and sonarr_config.verified:
        status, existing = overseerr_client.get("/api/v1/settings/sonarr")

        if status == 200:
            has_sonarr = False
            if isinstance(existing, list):
                has_sonarr = any(s.get("name") == "Sonarr" for s in existing)

            if not has_sonarr:
                payload = {
                    "name": "Sonarr",
                    "hostname": sonarr_config.url.replace("http://", "").replace("https://", "").split(":")[0],
                    "port": 8989,
                    "apiKey": sonarr_config.api_key,
                    "useSsl": False,
                    "activeProfileId": 1,
                    "activeDirectory": "/data/media/tv",
                    "activeLanguageProfileId": 1,
                    "is4k": False,
                    "isDefault": True,
                    "externalUrl": sonarr_config.url,
                }

                if dry_run:
                    print_info("[DRY-RUN] Would add Sonarr to Overseerr")
                else:
                    status, response = overseerr_client.post("/api/v1/settings/sonarr", payload)
                    if status in [200, 201]:
                        print_success("Added Sonarr to Overseerr")
                    else:
                        print_error(f"Failed to add Sonarr to Overseerr: {response}")
                        success = False
            else:
                print_info("Sonarr already configured in Overseerr")

    return success

# ============================================================================
# Main Commands
# ============================================================================

def load_config() -> Config:
    """Load configuration from file"""
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE) as f:
                return Config.from_dict(json.load(f))
        except Exception as e:
            print_warning(f"Failed to load config: {e}")
    return Config()

def save_config(config: Config):
    """Save configuration to file"""
    # Create config directory if it doesn't exist (for Unraid persistence)
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config.to_dict(), f, indent=2)
    print_info(f"Configuration saved to {CONFIG_FILE}")

def interactive_setup() -> Config:
    """Interactive setup wizard"""
    print_header("Media Stack Configurator - Setup Wizard")

    config = load_config()

    # Discover services
    print_step(1, 4, "Discovering services...")
    discovered = discover_services()

    if not discovered:
        print_warning("No services discovered automatically.")
        print_info("You can manually enter service URLs below.")

    # Configure each service
    print_step(2, 4, "Configuring services...")

    services = [
        ("sonarr", "Sonarr", "TV show management"),
        ("radarr", "Radarr", "Movie management"),
        ("prowlarr", "Prowlarr", "Indexer management"),
        ("bazarr", "Bazarr", "Subtitle management"),
        ("overseerr", "Overseerr", "Request management"),
        ("plex", "Plex", "Media server"),
        ("rdt_client", "Rdt-Client", "Real-Debrid download client"),
    ]

    for key, name, desc in services:
        url_key = key.replace('_', '-')
        current = getattr(config, key)

        default_url = discovered.get(url_key, "")
        if current and current.url:
            default_url = current.url

        print(f"\n{Colors.BOLD}{name}{Colors.RESET} ({desc})")

        url = input(f"  URL [{default_url}]: ").strip() or default_url
        if not url:
            print_info(f"Skipping {name}")
            continue

        api_key = ""
        if key != "rdt_client":  # Rdt-Client doesn't usually need API key
            default_key = current.api_key if current else ""
            api_key = input(f"  API Key [{default_key[:8] + '...' if default_key else ''}]: ").strip() or default_key

        # Verify service
        verified, version = verify_service(url_key, url, api_key)
        if verified:
            print_success(f"Connected to {name}" + (f" (v{version})" if version else ""))
            setattr(config, key, ServiceConfig(
                name=name,
                url=url,
                api_key=api_key,
                enabled=True,
                verified=True,
                version=version
            ))
        else:
            print_error(f"Failed to connect to {name}: {version}")
            enable = input("  Add anyway? [y/N]: ").strip().lower() == 'y'
            if enable:
                setattr(config, key, ServiceConfig(
                    name=name,
                    url=url,
                    api_key=api_key,
                    enabled=True,
                    verified=False
                ))

    # Configure paths
    print_step(3, 4, "Configuring paths...")

    config.movies_path = input(f"  Movies path [{config.movies_path}]: ").strip() or config.movies_path
    config.tv_path = input(f"  TV shows path [{config.tv_path}]: ").strip() or config.tv_path
    config.downloads_path = input(f"  Downloads path [{config.downloads_path}]: ").strip() or config.downloads_path

    # Save configuration
    print_step(4, 4, "Saving configuration...")
    save_config(config)

    return config

def cmd_discover(args):
    """Discover available services"""
    print_header("Service Discovery")

    discovered = discover_services()

    if not discovered:
        print_warning("No services discovered.")
        return 1

    print(f"\n{Colors.BOLD}Discovered {len(discovered)} services:{Colors.RESET}")
    for service, url in discovered.items():
        verified, version = verify_service(service, url)
        status = f"{Colors.GREEN}✓{Colors.RESET}" if verified else f"{Colors.RED}✗{Colors.RESET}"
        print(f"  {status} {service}: {url}")

    return 0

def auto_configure(appdata_path: str = None) -> Config:
    """Automatically discover and configure all services"""
    print_header("Auto-Configuration Mode")

    config = Config()

    # Auto-discover services with API keys
    discovered = auto_discover_with_keys(appdata_path)

    # Map discovered services to config
    service_mapping = {
        "sonarr": "sonarr",
        "radarr": "radarr",
        "prowlarr": "prowlarr",
        "bazarr": "bazarr",
        "overseerr": "overseerr",
        "plex": "plex",
        "rdt-client": "rdt_client",
        "tautulli": "tautulli",
        "zurg": "zurg",
    }

    for service_key, config_key in service_mapping.items():
        if service_key in discovered:
            info = discovered[service_key]
            url = info.get("url", "")
            api_key = info.get("api_key", "")

            # Verify the service
            verified, version = verify_service(service_key, url, api_key)

            setattr(config, config_key, ServiceConfig(
                name=service_key.replace("-", " ").title().replace(" ", "-"),
                url=url,
                api_key=api_key,
                enabled=True,
                verified=verified,
                version=version if verified else ""
            ))

            if verified:
                print_success(f"{service_key}: Verified (v{version})" if version else f"{service_key}: Verified")
            elif api_key:
                print_warning(f"{service_key}: Discovered but verification failed")
            else:
                print_warning(f"{service_key}: Discovered but no API key found")

    # Set paths based on Unraid conventions
    if appdata_path:
        config.appdata_path = appdata_path

    print_info(f"\nAuto-discovered {len(discovered)} services")
    return config


def cmd_configure(args):
    """Run full configuration"""
    print_header("Media Stack Configuration")

    # Auto mode - fully automatic discovery and configuration
    if hasattr(args, 'auto') and args.auto:
        config = auto_configure(args.appdata if hasattr(args, 'appdata') else None)
    # Load or create config
    elif args.interactive or not CONFIG_FILE.exists():
        config = interactive_setup()
    else:
        config = load_config()

    dry_run = args.dry_run
    if dry_run:
        print_warning("DRY-RUN MODE - No changes will be made")

    total_steps = 5
    current_step = 0

    # Step 1: Verify all services
    current_step += 1
    print_step(current_step, total_steps, "Verifying services...")

    services_ok = True
    for key in ['sonarr', 'radarr', 'prowlarr', 'rdt_client']:
        svc = getattr(config, key)
        if svc and svc.enabled:
            url_key = key.replace('_', '-')
            verified, version = verify_service(url_key, svc.url, svc.api_key)
            if verified:
                print_success(f"{svc.name} is accessible")
                svc.verified = True
            else:
                print_error(f"{svc.name} is not accessible: {version}")
                svc.verified = False
                services_ok = False

    if not services_ok:
        print_warning("Some services are not accessible. Configuration may be incomplete.")

    # Step 2: Configure download clients
    current_step += 1
    print_step(current_step, total_steps, "Configuring download clients...")

    if config.rdt_client and config.rdt_client.verified:
        rdt_host = config.rdt_client.url.replace("http://", "").replace("https://", "").split(":")[0]
        rdt_port = int(config.rdt_client.url.split(":")[-1]) if ":" in config.rdt_client.url.split("/")[-1] else 6500

        if config.sonarr and config.sonarr.verified:
            sonarr_client = APIClient(config.sonarr.url, config.sonarr.api_key)
            add_download_client_to_arr(sonarr_client, "Sonarr", rdt_host, rdt_port, dry_run)

        if config.radarr and config.radarr.verified:
            radarr_client = APIClient(config.radarr.url, config.radarr.api_key)
            add_download_client_to_arr(radarr_client, "Radarr", rdt_host, rdt_port, dry_run)
    else:
        print_warning("Rdt-Client not configured, skipping download client setup")

    # Step 3: Configure root folders
    current_step += 1
    print_step(current_step, total_steps, "Configuring root folders...")

    if config.sonarr and config.sonarr.verified:
        sonarr_client = APIClient(config.sonarr.url, config.sonarr.api_key)
        add_root_folder_to_arr(sonarr_client, "Sonarr", config.tv_path, dry_run)

    if config.radarr and config.radarr.verified:
        radarr_client = APIClient(config.radarr.url, config.radarr.api_key)
        add_root_folder_to_arr(radarr_client, "Radarr", config.movies_path, dry_run)

    # Step 4: Configure Prowlarr sync
    current_step += 1
    print_step(current_step, total_steps, "Configuring Prowlarr sync...")

    if config.prowlarr and config.prowlarr.verified:
        prowlarr_client = APIClient(config.prowlarr.url, config.prowlarr.api_key)
        sync_prowlarr_to_arrs(prowlarr_client, config.sonarr, config.radarr, dry_run)
    else:
        print_warning("Prowlarr not configured, skipping indexer sync")

    # Step 5: Configure Bazarr and Overseerr
    current_step += 1
    print_step(current_step, total_steps, "Configuring auxiliary services...")

    if config.bazarr and config.bazarr.verified:
        bazarr_client = APIClient(config.bazarr.url, config.bazarr.api_key)
        configure_bazarr(bazarr_client, config.sonarr, config.radarr, dry_run)

    if config.overseerr and config.overseerr.verified:
        overseerr_client = APIClient(config.overseerr.url, config.overseerr.api_key)
        configure_overseerr(overseerr_client, config.sonarr, config.radarr, config.plex, dry_run)

    # Summary
    print_header("Configuration Complete")

    if dry_run:
        print_warning("DRY-RUN MODE - No changes were made")
        print_info("Run without --dry-run to apply changes")
    else:
        print_success("Media stack has been configured!")
        save_config(config)

    return 0

def cmd_status(args):
    """Check integration status"""
    print_header("Media Stack Status")

    config = load_config()

    if not CONFIG_FILE.exists():
        print_error("No configuration found. Run 'configure' first.")
        return 1

    # Check each service
    print(f"\n{Colors.BOLD}Service Status:{Colors.RESET}")

    for key in ['sonarr', 'radarr', 'prowlarr', 'bazarr', 'overseerr', 'plex', 'rdt_client', 'tautulli', 'zurg']:
        svc = getattr(config, key, None)
        if svc:
            url_key = key.replace('_', '-')
            verified, version = verify_service(url_key, svc.url, svc.api_key)
            if verified:
                print_success(f"{svc.name}: {svc.url}" + (f" (v{version})" if version else ""))
            else:
                print_error(f"{svc.name}: {svc.url} - {version}")
        else:
            print(f"  {Colors.DIM}○ {key}: not configured{Colors.RESET}")

    # Check integrations
    print(f"\n{Colors.BOLD}Integrations:{Colors.RESET}")

    # Check Sonarr download clients
    if config.sonarr and config.sonarr.verified:
        client = APIClient(config.sonarr.url, config.sonarr.api_key)
        status, response = client.get("/api/v3/downloadclient")
        if status == 200 and isinstance(response, list):
            debrid = any(c.get("name") == "Chimera-Debrid" for c in response)
            if debrid:
                print_success("Sonarr → Rdt-Client connected")
            else:
                print_warning("Sonarr → Rdt-Client not configured")

    # Check Radarr download clients
    if config.radarr and config.radarr.verified:
        client = APIClient(config.radarr.url, config.radarr.api_key)
        status, response = client.get("/api/v3/downloadclient")
        if status == 200 and isinstance(response, list):
            debrid = any(c.get("name") == "Chimera-Debrid" for c in response)
            if debrid:
                print_success("Radarr → Rdt-Client connected")
            else:
                print_warning("Radarr → Rdt-Client not configured")

    # Check Prowlarr applications
    if config.prowlarr and config.prowlarr.verified:
        client = APIClient(config.prowlarr.url, config.prowlarr.api_key)
        status, response = client.get("/api/v1/applications")
        if status == 200 and isinstance(response, list):
            apps = [a.get("name") for a in response]
            if "Sonarr" in apps:
                print_success("Prowlarr → Sonarr synced")
            else:
                print_warning("Prowlarr → Sonarr not configured")
            if "Radarr" in apps:
                print_success("Prowlarr → Radarr synced")
            else:
                print_warning("Prowlarr → Radarr not configured")

    print(f"\n{Colors.BOLD}Paths:{Colors.RESET}")
    print_info(f"Movies: {config.movies_path}")
    print_info(f"TV Shows: {config.tv_path}")
    print_info(f"Downloads: {config.downloads_path}")

    return 0

def cmd_extract_keys(args):
    """Extract and display API keys from service config files"""
    print_header("API Key Extraction")

    appdata_path = args.appdata

    if not Path(appdata_path).exists():
        print_error(f"Appdata path not found: {appdata_path}")
        return 1

    print_info(f"Scanning {appdata_path} for service configurations...")

    services = ["sonarr", "radarr", "prowlarr", "bazarr", "tautulli"]
    found_keys = {}

    for service in services:
        api_key = extract_api_key_from_config(appdata_path, service)
        if api_key:
            found_keys[service] = api_key
            print_success(f"{service}: {api_key[:8]}...{api_key[-4:]}")
        else:
            print_warning(f"{service}: Not found")

    if found_keys:
        print(f"\n{Colors.BOLD}Copy these to your configuration:{Colors.RESET}")
        for service, key in found_keys.items():
            print(f"  {service.upper()}_API_KEY={key}")

    return 0


def cmd_reset(args):
    """Reset configuration"""
    if CONFIG_FILE.exists():
        if args.force or input("Delete configuration? [y/N]: ").strip().lower() == 'y':
            CONFIG_FILE.unlink()
            print_success("Configuration deleted")
        else:
            print_info("Cancelled")
    else:
        print_info("No configuration to delete")
    return 0

# ============================================================================
# Main Entry Point
# ============================================================================

def main():
    parser = argparse.ArgumentParser(
        description="Media Stack Configurator - Automated cross-configuration for arr suite",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s discover             Scan for available services
  %(prog)s configure            Run interactive configuration
  %(prog)s configure --dry-run  Preview changes without applying
  %(prog)s status               Check current integration status
  %(prog)s reset                Clear saved configuration
        """
    )

    subparsers = parser.add_subparsers(dest='command', help='Available commands')

    # discover
    discover_parser = subparsers.add_parser('discover', help='Discover available services')

    # configure
    configure_parser = subparsers.add_parser('configure', help='Configure media stack integrations')
    configure_parser.add_argument('--dry-run', action='store_true', help='Preview changes without applying')
    configure_parser.add_argument('--interactive', '-i', action='store_true', help='Force interactive mode')
    configure_parser.add_argument('--auto', '-a', action='store_true', help='Fully automatic mode - discover services and extract API keys')
    configure_parser.add_argument('--appdata', type=str, default='/mnt/user/appdata', help='Path to appdata directory (default: /mnt/user/appdata)')

    # status
    status_parser = subparsers.add_parser('status', help='Check integration status')

    # extract-keys
    extract_parser = subparsers.add_parser('extract-keys', help='Extract API keys from service config files')
    extract_parser.add_argument('--appdata', type=str, default='/mnt/user/appdata', help='Path to appdata directory')

    # reset
    reset_parser = subparsers.add_parser('reset', help='Reset configuration')
    reset_parser.add_argument('--force', '-f', action='store_true', help='Skip confirmation')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 0

    commands = {
        'discover': cmd_discover,
        'configure': cmd_configure,
        'status': cmd_status,
        'reset': cmd_reset,
        'extract-keys': cmd_extract_keys,
    }

    return commands[args.command](args)

if __name__ == "__main__":
    sys.exit(main())
