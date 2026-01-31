import json
import base64
import sys

try:
    with open('mas_secret_data.txt', 'r') as f:
        # Expecting output from expect script which might have some garbage?
        # The expect script output: spawn ... password ... {json}
        # We need to clean it up or valid json.
        # Actually the expect script just outputted text.
        content = f.read()
        
        # Find the JSON part. It starts with {
        start = content.find('{')
        if start == -1:
            print("No JSON found")
            sys.exit(1)
        json_str = content[start:].strip()
        
        data = json.loads(json_str)
        if 'user-enable-registration-smtp' in data:
            encoded = data['user-enable-registration-smtp']
            decoded = base64.b64decode(encoded).decode('utf-8')
            print("--- DECODED user-enable-registration-smtp ---")
            print(decoded)
        else:
            print("Key user-enable-registration-smtp not found. Keys:", data.keys())

except Exception as e:
    print(f"Error: {e}")
