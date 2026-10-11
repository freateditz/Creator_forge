#!/usr/bin/env python3
"""
End-to-end integration test for the native host protocol.

Does NOT require a real browser or running CreatorForge instance.
Tests message framing, app-not-running behavior, and IPC roundtrip
with a local mock server.

Run with:
    python3 native-host/test_e2e.py
or:
    python3 -m pytest native-host/test_e2e.py -v
"""

from __future__ import annotations

import json
import os
import socket
import struct
import sys
import tempfile
import threading
import time
import unittest
from io import BytesIO

sys.path.insert(0, os.path.dirname(__file__))
import creator_forge_host as host


# ── Helpers ───────────────────────────────────────────────────────────────────

def _encode_nm(obj: dict) -> bytes:
    body = json.dumps(obj).encode("utf-8")
    return struct.pack("<I", len(body)) + body


def _decode_nm(data: bytes) -> dict:
    assert len(data) >= 4
    length = struct.unpack("<I", data[:4])[0]
    return json.loads(data[4:4 + length])


# ── TestNmProtocolIntegration ─────────────────────────────────────────────────

class TestNmProtocolIntegration(unittest.TestCase):
    """Verify that encode→decode roundtrips are lossless."""

    def test_simple_dict_roundtrip(self):
        original = {"type": "PING", "requestId": "r-001", "version": 1}
        encoded = _encode_nm(original)
        decoded = host.nm_read(stdin=BytesIO(encoded))
        self.assertEqual(decoded, original)

    def test_unicode_roundtrip(self):
        original = {"title": "Ünïcödé テスト 🎬", "url": "https://example.com/v.mp4"}
        out = BytesIO()
        host.nm_write(original, stdout=out)
        recovered = _decode_nm(out.getvalue())
        self.assertEqual(recovered["title"], original["title"])

    def test_large_payload_roundtrip(self):
        original = {"data": "x" * 50_000, "requestId": "big"}
        out = BytesIO()
        host.nm_write(original, stdout=out)
        recovered = _decode_nm(out.getvalue())
        self.assertEqual(len(recovered["data"]), 50_000)

    def test_empty_body_roundtrip(self):
        encoded = struct.pack("<I", 0)
        result = host.nm_read(stdin=BytesIO(encoded))
        self.assertEqual(result, {})


# ── TestBrowserToHostMessages ─────────────────────────────────────────────────

class TestBrowserToHostMessages(unittest.TestCase):
    """Verify nm_read correctly parses each message type the extension sends."""

    def _read(self, obj: dict) -> dict:
        return host.nm_read(stdin=BytesIO(_encode_nm(obj)))

    def test_ping(self):
        msg = {"type": "PING", "requestId": "r1", "version": 1}
        result = self._read(msg)
        self.assertEqual(result["type"], "PING")
        self.assertEqual(result["requestId"], "r1")

    def test_download_request(self):
        msg = {
            "type": "DOWNLOAD_REQUEST",
            "requestId": "r2",
            "version": 1,
            "url": "https://example.com/video.mp4",
            "pageUrl": "https://example.com",
            "pageTitle": "Example",
            "downloadType": "videoAndAudio",
        }
        result = self._read(msg)
        self.assertEqual(result["url"], "https://example.com/video.mp4")
        self.assertEqual(result["downloadType"], "videoAndAudio")

    def test_analyze_media(self):
        msg = {
            "type": "ANALYZE_MEDIA",
            "requestId": "r3",
            "version": 1,
            "url": "https://example.com/clip.mp4",
            "pageUrl": "https://example.com",
            "pageTitle": "Clip page",
        }
        result = self._read(msg)
        self.assertEqual(result["type"], "ANALYZE_MEDIA")

    def test_connection_status(self):
        msg = {"type": "CONNECTION_STATUS", "requestId": "r4", "version": 1}
        result = self._read(msg)
        self.assertEqual(result["type"], "CONNECTION_STATUS")

    def test_nm_write_framing(self):
        obj = {"type": "PONG", "requestId": "r1", "version": 1}
        out = BytesIO()
        host.nm_write(obj, stdout=out)
        data = out.getvalue()
        length = struct.unpack("<I", data[:4])[0]
        self.assertEqual(length, len(data) - 4)
        recovered = json.loads(data[4:].decode("utf-8"))
        self.assertEqual(recovered["type"], "PONG")

    def test_nm_write_does_not_add_newlines(self):
        out = BytesIO()
        host.nm_write({"k": "v"}, stdout=out)
        raw = out.getvalue()
        body = raw[4:]
        self.assertNotIn(b"\n", body)


# ── TestHostAppNotRunning ─────────────────────────────────────────────────────

class TestHostAppNotRunning(unittest.TestCase):
    """Verify host responds with APP_NOT_RUNNING when no conn file exists."""

    def _run_host_one_message(self, msg: dict, conn_file: str) -> dict:
        """
        Run one message through the host main loop by monkey-patching
        _conn_file_path to return a non-existent path, simulating the app
        not running.
        """
        original_conn_path = host._conn_file_path

        # Point to a guaranteed-missing path.
        host._conn_file_path = lambda: conn_file

        stdin_data = _encode_nm(msg) + _encode_nm(None.__class__.__new__(dict))

        # We need to simulate the main loop reading one message then EOF.
        # Instead of running main(), test connect_to_app() directly.
        result = host.connect_to_app()
        host._conn_file_path = original_conn_path
        return result

    def test_connect_returns_none_when_conn_file_missing(self):
        with tempfile.TemporaryDirectory() as d:
            missing_path = os.path.join(d, "creator_forge.conn")
            original = host._conn_file_path
            host._conn_file_path = lambda: missing_path
            try:
                result = host.connect_to_app()
                self.assertIsNone(result)
            finally:
                host._conn_file_path = original

    def test_load_conn_info_returns_none_for_missing_file(self):
        with tempfile.TemporaryDirectory() as d:
            original = host._conn_file_path
            host._conn_file_path = lambda: os.path.join(d, "missing.conn")
            try:
                info = host._load_conn_info()
                self.assertIsNone(info)
            finally:
                host._conn_file_path = original

    def test_load_conn_info_parses_valid_file(self):
        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".conn", delete=False
        ) as f:
            json.dump({"version": 1, "host": "127.0.0.1", "port": 9999, "token": "abc"}, f)
            path = f.name

        original = host._conn_file_path
        host._conn_file_path = lambda: path
        try:
            info = host._load_conn_info()
            self.assertIsNotNone(info)
            self.assertEqual(info["port"], 9999)
            self.assertEqual(info["token"], "abc")
        finally:
            host._conn_file_path = original
            os.unlink(path)


# ── TestLocalServerE2e ────────────────────────────────────────────────────────

class TestLocalServerE2e(unittest.TestCase):
    """
    Starts a real TCP server that echoes a canned DOWNLOAD_ACCEPTED response,
    verifying the full IPC roundtrip from ipc_roundtrip() through to JSON parsing.
    """

    def _start_mock_server(self, response: dict) -> tuple[socket.socket, int]:
        """Bind a TCP server that sends one response line and closes."""
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        server.settimeout(5.0)
        port = server.getsockname()[1]
        return server, port

    def _serve_one(self, server: socket.socket, response: dict) -> None:
        try:
            conn, _ = server.accept()
            data = b""
            while b"\n" not in data:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data += chunk
            payload = json.dumps(response, ensure_ascii=False) + "\n"
            conn.sendall(payload.encode("utf-8"))
            conn.close()
        except Exception:
            pass
        finally:
            server.close()

    def test_ipc_roundtrip_success(self):
        canned = {
            "version": 1,
            "type": "DOWNLOAD_ACCEPTED",
            "requestId": "r-e2e",
            "taskId": "task-abc123",
        }
        server, port = self._start_mock_server(canned)
        t = threading.Thread(target=self._serve_one, args=(server, canned), daemon=True)
        t.start()

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5.0)
        sock.connect(("127.0.0.1", port))

        msg = {
            "version": 1,
            "type": "DOWNLOAD_REQUEST",
            "requestId": "r-e2e",
            "url": "https://example.com/video.mp4",
        }
        result = host.ipc_roundtrip(sock, msg)
        sock.close()
        t.join(timeout=2.0)

        self.assertIsNotNone(result)
        self.assertEqual(result["type"], "DOWNLOAD_ACCEPTED")
        self.assertEqual(result["taskId"], "task-abc123")

    def test_ipc_roundtrip_returns_none_on_connection_closed(self):
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        server.settimeout(5.0)
        port = server.getsockname()[1]

        def close_immediately(srv):
            try:
                conn, _ = srv.accept()
                conn.close()
            except Exception:
                pass
            finally:
                srv.close()

        t = threading.Thread(target=close_immediately, args=(server,), daemon=True)
        t.start()

        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5.0)
        sock.connect(("127.0.0.1", port))

        result = host.ipc_roundtrip(sock, {"type": "PING"})
        sock.close()
        t.join(timeout=2.0)

        self.assertIsNone(result)

    def test_conn_file_tcp_connect(self):
        """Verify connect_to_app() can establish a TCP connection using a conn file."""
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", 0))
        server.listen(1)
        server.settimeout(3.0)
        port = server.getsockname()[1]

        accepted = []

        def accept_one(srv):
            try:
                conn, _ = srv.accept()
                accepted.append(conn)
            except Exception:
                pass
            finally:
                srv.close()

        t = threading.Thread(target=accept_one, args=(server,), daemon=True)
        t.start()

        with tempfile.NamedTemporaryFile(
            mode="w", suffix=".conn", delete=False
        ) as f:
            json.dump({"version": 1, "host": "127.0.0.1", "port": port}, f)
            path = f.name

        original = host._conn_file_path
        host._conn_file_path = lambda: path
        try:
            sock = host.connect_to_app()
            self.assertIsNotNone(sock)
            if sock:
                sock.close()
        finally:
            host._conn_file_path = original
            os.unlink(path)
            t.join(timeout=2.0)
            for c in accepted:
                try:
                    c.close()
                except Exception:
                    pass


if __name__ == "__main__":
    unittest.main(verbosity=2)
