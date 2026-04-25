"""SSE entrypoint for telegram-mcp.

The upstream main.py runs the MCP server over stdio, which doesn't work
in a Docker sidecar scenario where OpenClaw communicates via HTTP/SSE.

This entrypoint:
1. Imports the MCP app and Telegram clients from main.py
2. Parses proxy settings from OPENCLAW_PROXY_URL (Telethon needs explicit proxy config)
3. Connects all configured Telegram clients
4. Warms entity caches (StringSession has no persistent cache)
5. Starts the MCP server with SSE transport on 0.0.0.0:8932
"""

import asyncio
import sys
import os
from urllib.parse import urlparse

import nest_asyncio
nest_asyncio.apply()

from main import mcp, clients, _configure_allowed_roots_from_cli


def _parse_proxy():
    """Parse OPENCLAW_PROXY_URL into a Telethon-compatible proxy tuple.

    Telethon ignores HTTP_PROXY/HTTPS_PROXY env vars because it uses
    raw TCP (MTProto), not HTTP. We must configure the proxy explicitly
    on each TelegramClient instance.

    Supports:
      - http://user:pass@host:port  → HTTP CONNECT proxy
      - socks5://user:pass@host:port → SOCKS5 proxy

    Returns None if no proxy is configured.
    """
    proxy_url = os.getenv("OPENCLAW_PROXY_URL", "").strip()
    if not proxy_url:
        return None

    parsed = urlparse(proxy_url)
    if not parsed.hostname or not parsed.port:
        print(f"[sse_entrypoint] WARNING: Could not parse proxy URL: {proxy_url}", file=sys.stderr)
        return None

    scheme = (parsed.scheme or "http").lower()

    # python-socks proxy types that Telethon understands
    import python_socks
    if scheme in ("socks5", "socks5h"):
        proxy_type = python_socks.ProxyType.SOCKS5
    elif scheme in ("socks4", "socks4a"):
        proxy_type = python_socks.ProxyType.SOCKS4
    else:
        # Default to HTTP CONNECT (works for http:// scheme)
        proxy_type = python_socks.ProxyType.HTTP

    proxy = {
        'proxy_type': proxy_type,
        'addr': parsed.hostname,
        'port': parsed.port,
        'rdns': True,
    }
    if parsed.username:
        proxy['username'] = parsed.username
    if parsed.password:
        proxy['password'] = parsed.password

    print(f"[sse_entrypoint] Proxy configured: {scheme}://{parsed.hostname}:{parsed.port}", file=sys.stderr)
    return proxy


def _apply_proxy_to_clients(proxy):
    """Patch all Telegram clients to use the proxy before connecting.

    Telethon stores proxy config in client._proxy, used when
    creating new connections. Setting it before .start() works.
    """
    if not proxy:
        return

    for name, client in clients.items():
        client._proxy = proxy
        print(f"[sse_entrypoint] Proxy applied to client '{name}'", file=sys.stderr)


async def _start_clients():
    """Connect all discovered Telegram clients and warm caches."""
    labels = ", ".join(clients.keys())
    print(f"[sse_entrypoint] Starting {len(clients)} Telegram client(s) ({labels})...", file=sys.stderr)

    await asyncio.gather(*(cl.start() for cl in clients.values()))

    print("[sse_entrypoint] Warming entity caches...", file=sys.stderr)
    await asyncio.gather(*(cl.get_dialogs() for cl in clients.values()))

    print(f"[sse_entrypoint] Telegram client(s) ready ({labels}).", file=sys.stderr)


async def _main_sse():
    """Start clients, then run SSE server."""
    try:
        # Configure proxy BEFORE connecting
        proxy = _parse_proxy()
        _apply_proxy_to_clients(proxy)

        await _start_clients()

        host = os.getenv("MCP_SSE_HOST", "0.0.0.0")
        port = int(os.getenv("MCP_SSE_PORT", "8932"))

        print(f"[sse_entrypoint] Starting MCP SSE server on {host}:{port}...", file=sys.stderr)

        # FastMCP's run() with transport="sse" starts a Starlette/Uvicorn server
        mcp.run(transport="sse", host=host, port=port)

    except Exception as e:
        print(f"[sse_entrypoint] Fatal error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        try:
            await asyncio.gather(
                *(cl.disconnect() for cl in clients.values()), return_exceptions=True
            )
        except Exception:
            pass


def main():
    _configure_allowed_roots_from_cli(sys.argv[1:])
    asyncio.run(_main_sse())


if __name__ == "__main__":
    main()
