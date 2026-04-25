"""SSE entrypoint for telegram-mcp.

The upstream main.py runs the MCP server over stdio, which doesn't work 
in a Docker sidecar scenario where OpenClaw communicates via HTTP/SSE.

This entrypoint:
1. Imports the MCP app and Telegram clients from main.py
2. Connects all configured Telegram clients
3. Warms entity caches (StringSession has no persistent cache)
4. Starts the MCP server with SSE transport on 0.0.0.0:8932
"""

import asyncio
import sys
import os

# Ensure nest_asyncio is applied before anything else
import nest_asyncio
nest_asyncio.apply()

from main import mcp, clients, _configure_allowed_roots_from_cli


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
