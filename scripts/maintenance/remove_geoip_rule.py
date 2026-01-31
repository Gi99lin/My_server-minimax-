#!/usr/bin/env python3
import json
import sys

# Read config from stdin
config = json.load(sys.stdin)

# Remove geoip:private blocking rule
config['routing']['rules'] = [
    rule for rule in config['routing']['rules']
    if not (rule.get('outboundTag') == 'blocked' and 
            'geoip:private' in rule.get('ip', []))
]

# Write modified config to stdout
json.dump(config, sys.stdout, indent=2)
