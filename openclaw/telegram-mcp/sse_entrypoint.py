"""SSE entrypoint for telegram-mcp.

The upstream main.py runs the MCP server over stdio, which doesn't work
in a Docker sidecar scenario where OpenClaw communicates via HTTP/SSE.

This entrypoint:
1. Imports the MCP app and Telegram clients from main.py
2. Parses proxy settings from OPENCLAW_PROXY_URL (Telethon needs explicit proxy config)
3. Connects all configured Telegram clients
4. Warms entity caches (StringSession has no persistent cache)
5. Starts the MCP SSE server via Starlette + Uvicorn on 0.0.0.0:8932
"""

import asyncio
import sys
import os
from urllib.parse import urlparse

import nest_asyncio
nest_asyncio.apply()

from main import mcp, clients, _configure_allowed_roots_from_cli


def _parse_proxy():
    """Parse OPENCLAW_PROXY_URL into a Telethon-compatible proxy dict.

    Telethon ignores HTTP_PROXY/HTTPS_PROXY env vars because it uses
    raw TCP (MTProto), not HTTP. We must configure the proxy explicitly
    on each TelegramClient instance.

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

    import python_socks
    if scheme in ("socks5", "socks5h"):
        proxy_type = python_socks.ProxyType.SOCKS5
    elif scheme in ("socks4", "socks4a"):
        proxy_type = python_socks.ProxyType.SOCKS4
    else:
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
    """Patch all Telegram clients to use the proxy before connecting."""
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


def _build_sse_app():
    """Build a Starlette ASGI app that serves MCP over SSE.

    This bypasses FastMCP.run() which may not accept host/port kwargs
    in all versions of the mcp SDK.
    """
    from mcp.server.sse import SseServerTransport
    from starlette.applications import Starlette
    from starlette.routing import Route, Mount
    from starlette.responses import JSONResponse

    sse_transport = SseServerTransport("/messages/")

    async def handle_sse(request):
        async with sse_transport.connect_sse(
            request.scope, request.receive, request._send
        ) as (read_stream, write_stream):
            await mcp._mcp_server.run(
                read_stream,
                write_stream,
                mcp._mcp_server.create_initialization_options(),
            )

    async def handle_health(request):
        return JSONResponse({"status": "ok"})

    app = Starlette(
        routes=[
            Route("/sse", endpoint=handle_sse),
            Mount("/messages/", app=sse_transport.handle_post_message),
            Route("/health", endpoint=handle_health),
        ],
    )
    return app


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

        app = _build_sse_app()

        import uvicorn
        config = uvicorn.Config(app, host=host, port=port, log_level="info")
        server = uvicorn.Server(config)
        await server.serve()

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
