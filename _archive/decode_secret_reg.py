import json
import base64
import sys

try:
    with open('mas_secret_check_registration.txt', 'r') as f:
        content = f.read()
        start = content.find('{')
        if start != -1:
            json_str = content[start:].strip()
            data = json.loads(json_str)
            if 'user-enable-registration-smtp' in data:
                encoded = data['user-enable-registration-smtp']
                decoded = base64.b64decode(encoded).decode('utf-8')
                print("--- DECODED ---")
                print(decoded)
            else:
                print("Key not found")
        else:
            print("No JSON found")
except Exception as e:
    print(f"Error: {e}")
