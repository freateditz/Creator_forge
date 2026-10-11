#!/usr/bin/env python3
"""
CreatorForge Native Messaging Host
Bridges the browser extension and the CreatorForge desktop application
using the Chromium Native Messaging protocol.

Protocol (extension side):  4-byte LE length prefix + UTF-8 JSON body
Protocol (IPC side):        newline-delimited JSON over a Unix socket (macOS)
                            or TCP loopback with a session token (Windows)

All user-supplied values from the browser are forwarded to the desktop app
for independent validation. This host performs only framing, not content
validation.

Usage: invoked automatically by Chrome/Edge via the native messaging manifest.
       Do not invoke directly unless testing.
"""

from __future__ import annotations

import json
import os
import socket
import struct
import sys
import time
import traceback

# On Windows, Python opens stdin/stdout in text mode with CRLF translation.
# The Native Messaging protocol uses raw binary 4-byte length prefixes, so
# CRLF translation must be disabled before any reads or writes.
if sys.platform == "win32":
    import msvcrt
    msvcrt.setmode(sys.stdin.fileno(), os.O_BINARY)   # type: ignore[attr-defined]
    msvcrt.setmode(sys.stdout.fileno(), os.O_BINARY)  # type: ignore[attr-defined]

# ── Constants ─────────────────────────────────────────────────────────────────

PROTOCOL_VERSION = 1
MAX_NM_MESSAGE_SIZE = 1024 * 1024      # 1 MB (Chrome hard limit is ~1 MB)
IPC_CONNECT_TIMEOUT_S = 3.0
IPC_READ_TIMEOUT_S = 30.0
APP_NOT_RUNNING_ERROR = (
    "CreatorForge is not running. Please start the application and try again."
)

# ── Logging (stderr only — stdout is reserved for NM protocol) ────────────────

def _log(msg: str) -> None:
    print(f"[creator_forge_host] {msg}", file=sys.stderr, flush=True)


# ── Native Messaging I/O ──────────────────────────────────────────────────────

def nm_read(stdin=None) -> dict | None:
    """Read one Native Messaging message from stdin.

    Returns None when stdin is closed (browser disconnected).
    Raises IOError / ValueError on protocol violations.
    """
    stream = stdin if stdin is not None else sys.stdin.buffer
    raw = stream.read(4)
    if len(raw) == 0:
        return None  # EOF — browser closed the port
    if len(raw) < 4:
        raise IOError(f"Truncated length prefix: expected 4 bytes, got {len(raw)}")

    msg_len = struct.unpack("<I", raw)[0]
    if msg_len == 0:
        return {}
    if msg_len > MAX_NM_MESSAGE_SIZE:
        raise ValueError(f"Message too large: {msg_len} bytes (limit {MAX_NM_MESSAGE_SIZE})")

    body = stream.read(msg_len)
    if len(body) < msg_len:
        raise IOError(f"Truncated body: expected {msg_len} bytes, got {len(body)}")

    return json.loads(body.decode("utf-8"))


def nm_write(obj: dict, stdout=None) -> None:
    """Write one Native Messaging message to stdout."""
    stream = stdout if stdout is not None else sys.stdout.buffer
    body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
    stream.write(struct.pack("<I", len(body)))
    stream.write(body)
    stream.flush()


def nm_error(request_id: str, error: str) -> None:
    nm_write({
        "version": PROTOCOL_VERSION,
        "type": "ERROR",
        "requestId": request_id,
        "error": error,
    })


# ── IPC connection file location ──────────────────────────────────────────────

def _conn_file_path() -> str:
    """Return the absolute path to the IPC connection descriptor file.

    This file is written by CreatorForge at startup and contains the
    socket path (macOS) or host/port/token (Windows).
    """
    if sys.platform == "darwin":
        home = os.path.expanduser("~")
        return os.path.join(
            home, "Library", "Application Support",
            "creator_forge", "ipc", "creator_forge.conn",
        )
    if sys.platform == "win32":
        appdata = os.environ.get("APPDATA") or os.path.expanduser("~")
        return os.path.join(appdata, "creator_forge", "ipc", "creator_forge.conn")
    # Linux / other
    xdg = os.environ.get("XDG_DATA_HOME") or os.path.join(
        os.path.expanduser("~"), ".local", "share"
    )
    return os.path.join(xdg, "creator_forge", "ipc", "creator_forge.conn")


def _load_conn_info() -> dict | None:
    path = _conn_file_path()
    if not os.path.exists(path):
        _log(f"IPC conn file not found: {path}")
        return None
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception as exc:
        _log(f"Failed to parse IPC conn file: {exc}")
        return None


# ── IPC socket connection ─────────────────────────────────────────────────────

def _connect_unix(socket_path: str) -> socket.socket:
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(IPC_CONNECT_TIMEOUT_S)
    sock.connect(socket_path)
    sock.settimeout(IPC_READ_TIMEOUT_S)
    return sock


def _connect_tcp(host: str, port: int, token: str | None) -> socket.socket:
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(IPC_CONNECT_TIMEOUT_S)
    sock.connect((host, port))
    sock.settimeout(IPC_READ_TIMEOUT_S)

    if token:
        # Send token handshake frame.
        handshake = json.dumps({"token": token}) + "\n"
        sock.sendall(handshake.encode("utf-8"))
        # Read acknowledgement.
        ack_data = _recv_line(sock)
        if ack_data:
            ack = json.loads(ack_data)
            _log(f"TCP handshake ack: {ack.get('type')}")

    return sock


def connect_to_app() -> socket.socket | None:
    info = _load_conn_info()
    if info is None:
        return None

    try:
        if "socket" in info:
            return _connect_unix(info["socket"])
        if "port" in info:
            return _connect_tcp(
                info.get("host", "127.0.0.1"),
                int(info["port"]),
                info.get("token"),
            )
    except Exception as exc:
        _log(f"IPC connect failed: {exc}")

    return None


# ── IPC send / receive ────────────────────────────────────────────────────────

def _recv_line(sock: socket.socket) -> str | None:
    """Read bytes until a newline and return the line (without the newline)."""
    buf = b""
    while True:
        try:
            chunk = sock.recv(4096)
        except socket.timeout:
            _log("IPC read timed out.")
            return None
        except OSError:
            return None
        if not chunk:
            return None
        buf += chunk
        if b"\n" in buf:
            line, _ = buf.split(b"\n", 1)
            return line.decode("utf-8")


def ipc_roundtrip(sock: socket.socket, msg: dict) -> dict | None:
    """Send a message to CreatorForge and return the parsed response."""
    payload = json.dumps(msg, ensure_ascii=False) + "\n"
    try:
        sock.sendall(payload.encode("utf-8"))
    except Exception as exc:
        _log(f"IPC send failed: {exc}")
        return None

    line = _recv_line(sock)
    if line is None:
        return None
    try:
        return json.loads(line)
    except json.JSONDecodeError as exc:
        _log(f"Bad JSON from app: {exc}")
        return None


# ── Main loop ─────────────────────────────────────────────────────────────────

def main() -> None:
    _log("Starting.")

    app_socket: socket.socket | None = connect_to_app()
    if app_socket is None:
        _log("CreatorForge not running; will return APP_NOT_RUNNING for all requests.")

    while True:
        try:
            msg = nm_read()
        except (IOError, ValueError, UnicodeDecodeError, json.JSONDecodeError) as exc:
            _log(f"nm_read error: {exc}")
            break

        if msg is None:
            _log("stdin closed — exiting.")
            break

        if not isinstance(msg, dict):
            nm_error("", "Expected a JSON object.")
            continue

        request_id = msg.get("requestId") or ""

        if app_socket is None:
            # Attempt reconnect once before giving up.
            app_socket = connect_to_app()

        if app_socket is None:
            nm_error(request_id, APP_NOT_RUNNING_ERROR)
            continue

        response = ipc_roundtrip(app_socket, msg)
        if response is None:
            # Connection dropped; try to reconnect for the next message.
            _log("IPC connection lost; reconnecting.")
            try:
                app_socket.close()
            except Exception:
                pass
            app_socket = connect_to_app()
            nm_error(request_id, "Lost connection to CreatorForge. Please retry.")
            continue

        nm_write(response)

    if app_socket:
        try:
            app_socket.close()
        except Exception:
            pass

    _log("Exiting.")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        pass
    except Exception as exc:
        _log(f"Unhandled exception: {traceback.format_exc()}")
        sys.exit(1)
