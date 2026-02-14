#!/usr/bin/env python3
"""
Check for port conflicts in Docker Compose files.
"""

import os
import sys
import yaml
from pathlib import Path
from collections import defaultdict

def check_port_conflicts():
    """Check all docker-compose files for port conflicts."""
    port_usage = defaultdict(list)
    errors = []

    # Reserved ports that should not be used
    reserved_ports = {
        '443': 'VPN (xray-reality)',
        '80': 'Nginx Proxy Manager',
        '81': 'Nginx Proxy Manager Admin',
        '3456': 'Claude Monitor',
        '5173': 'Claude Monitor Dev',
        '5432': 'PostgreSQL',
        '5221': 'Cecelia Brain',
        '5211': 'Cecelia Workspace (Production)',
        '5212': 'Cecelia Workspace (Development)',
        '5679': 'n8n',
        '8080': 'VPN Subscription'
    }

    print("🔌 Checking for port conflicts...")

    # Find all docker-compose files
    compose_files = list(Path('.').rglob('docker-compose*.y*ml'))

    if not compose_files:
        print("ℹ️  No docker-compose files found")
        return 0

    print(f"  Found {len(compose_files)} docker-compose files")

    for compose_file in compose_files:
        print(f"  Checking {compose_file}")

        try:
            with open(compose_file, 'r') as f:
                data = yaml.safe_load(f)

            if not data or 'services' not in data:
                continue

            for service_name, service in data['services'].items():
                if 'ports' in service and service['ports']:
                    for port_mapping in service['ports']:
                        if isinstance(port_mapping, (str, int)):
                            # Parse port mapping (e.g., "8080:80" or "8080")
                            port_str = str(port_mapping)
                            parts = port_str.split(':')
                            host_port = parts[0].split('/')[0]  # Remove protocol if present

                            port_usage[host_port].append({
                                'file': str(compose_file),
                                'service': service_name
                            })

        except Exception as e:
            print(f"  ⚠️ Warning: Could not parse {compose_file}: {e}")

    # Check for conflicts between services
    for port, services in port_usage.items():
        if len(services) > 1:
            error_msg = f"Port {port} conflict detected:"
            for svc in services:
                error_msg += f"\n    - {svc['file']}: {svc['service']}"
            errors.append(error_msg)

    # Check against reserved ports
    for port, services in port_usage.items():
        if port in reserved_ports:
            for svc in services:
                # Allow if service name matches reservation
                service_lower = svc['service'].lower()
                reserved_lower = reserved_ports[port].lower()

                # Check if service name contains any part of the reserved name
                if not any(part in service_lower for part in reserved_lower.split()):
                    errors.append(
                        f"Port {port} is reserved for {reserved_ports[port]} "
                        f"but used by {svc['service']} in {svc['file']}"
                    )

    # Report results
    if errors:
        print("\n❌ Port conflicts detected:")
        for error in errors:
            print(f"  {error}")
        return 1
    else:
        print("✅ No port conflicts detected")
        return 0

if __name__ == "__main__":
    sys.exit(check_port_conflicts())