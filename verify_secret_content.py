import json
import base64

# The base64 string from our Secret
encoded = "cGFzc3dvcmRzOgogIGVuYWJsZWQ6IHRydWUKYWNjb3VudDoKICByZWdpc3RyYXRpb246CiAgICBlbmFibGVkOiB0cnVlCiAgICByZXF1aXJlX2VtYWlsX3ZlcmlmaWNhdGlvbjogZmFsc2UK"

decoded = base64.b64decode(encoded).decode('utf-8')
print("=== Expected Secret Content ===")
print(decoded)
print("\n=== YAML Structure ===")
print("passwords:")
print("  enabled: true")
print("account:")
print("  registration:")
print("    enabled: true")
print("    require_email_verification: false")
