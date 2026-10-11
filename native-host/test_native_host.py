#!/usr/bin/env python3
"""
Unit and integration tests for creator_forge_host.py

Run with:  python3 -m pytest native-host/test_native_host.py -v
or:        python3 native-host/test_native_host.py
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
from unittest.mock import MagicMock, patch

# Import the module under test.
sys.path.insert(0, os.path.dirname(__file__))
import creator_forge_host as host


# ── NM framing helpers ────────────────────────────────────────────────────────

def _encode_nm(obj: dict) -> bytes:
    body = json.dumps(obj).encode("utf-8")
    return struct.pack("<I", len(body)) + body


def _decode_nm(data: bytes) -> dict:
    assert len(data) >= 4, f"Too short: {len(data)}"
    length = struct.unpack("<I", data[:4])[0]
    return json.loads(data[4: 4 + length])


# ── nm_read tests ────────────────────────────────────────────────────────────

class TestNmRead(unittest.TestCase):

    def _nm_read(self, data: bytes):
        return host.nm_read(stdin=BytesIO(data))

    def test_reads_valid_message(self):
        data = _encode_nm({"type": "PING", "requestId": "r1"})
        result = self._nm_read(data)
        self.assertEqual(result["type"], "PING")

    def test_returns_none_on_eof(self):
        result = self._nm_read(b"")
        self.assertIsNone(result)

    def test_raises_on_truncated_length(self):
        with self.assertRaises(IOError):
            self._nm_read(b"\x00\x00")

    def test_raises_on_oversized_message(self):
        large_len = host.MAX_NM_MESSAGE_SIZE + 1
        header = struct.pack("<I", large_len)
        with self.assertRaises(ValueError):
            self._nm_read(header)

    def test_raises_on_truncated_body(self):
        msg = {"type": "PING", "requestId": "r1"}
        body = json.dumps(msg).encode("utf-8")
        # Write correct length but only half the body.
        bad = struct.pack("<I", len(body)) + body[:len(body) // 2]
        with self.assertRaises(IOError):
            self._nm_read(bad)

    def test_returns_empty_dict_for_zero_length(self):
        result = self._nm_read(struct.pack("<I", 0))
        self.assertEqual(result, {})


# ── nm_write tests ────────────────────────────────────────────────────────────

class TestNmWrite(unittest.TestCase):

    def test_writes_correct_framing(self):
        out = BytesIO()
        host.nm_write({"type": "PONG", "requestId": "r1"}, stdout=out)
        data = out.getvalue()
        result = _decode_nm(data)
        self.assertEqual(result["type"], "PONG")

    def test_length_prefix_matches_body(self):
        out = BytesIO()
        host.nm_write({"key": "value"}, stdout=out)
        data = out.getvalue()
        declared_len = struct.unpack("<I", data[:4])[0]
        self.assertEqual(declared_len, len(data) - 4)

    def test_unicode_content_survives_roundtrip(self):
        obj = {"title": "日本語テスト 🎬"}
        out = BytesIO()
        host.nm_write(obj, stdout=out)
        result = _decode_nm(out.getvalue())
        self.assertEqual(result["title"], obj["title"])


# ── IPC connection file ───────────────────────────────────────────────────────

class TestConnFilePath(unittest.TestCase):

    def test_returns_string(self):
        path = host._conn_file_path()
        self.assertIsInstance(path, str)
        self.assertTrue(len(path) > 0)

    def test_load_returns_none_for_missing_file(self):
        with patch("creator_forge_host._conn_file_path", return_value="/nonexistent/path.json"):
            result = host._load_conn_info()
        self.assertIsNone(result)

    def test_load_returns_none_for_invalid_json(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            f.write("not valid json {{{")
            tmp = f.name
        try:
            with patch("creator_forge_host._conn_file_path", return_value=tmp):
                result = host._load_conn_info()
            self.assertIsNone(result)
        finally:
            os.unlink(tmp)

    def test_load_returns_dict_for_valid_json(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
            json.dump({"version": 1, "socket": "/tmp/test.sock"}, f)
            tmp = f.name
        try:
            with patch("creator_forge_host._conn_file_path", return_value=tmp):
                result = host._load_conn_info()
            self.assertEqual(result["socket"], "/tmp/test.sock")
        finally:
            os.unlink(tmp)


# ── recv_line ─────────────────────────────────────────────────────────────────

class TestRecvLine(unittest.TestCase):

    def _make_mock_socket(self, chunks: list[bytes]) -> MagicMock:
        mock = MagicMock()
        side_effects = list(chunks) + [b""]
        mock.recv.side_effect = side_effects
        return mock

    def test_reads_single_line(self):
        data = b'{"type":"PONG"}\n'
        mock_sock = self._make_mock_socket([data])
        result = host._recv_line(mock_sock)
        self.assertEqual(result, '{"type":"PONG"}')

    def test_reads_fragmented_line(self):
        mock_sock = self._make_mock_socket([b'{"type"', b':"PONG"}\n'])
        result = host._recv_line(mock_sock)
        self.assertEqual(result, '{"type":"PONG"}')

    def test_returns_none_on_empty(self):
        mock_sock = self._make_mock_socket([])
        result = host._recv_line(mock_sock)
        self.assertIsNone(result)

    def test_returns_none_on_timeout(self):
        mock_sock = MagicMock()
        mock_sock.recv.side_effect = socket.timeout
        result = host._recv_line(mock_sock)
        self.assertIsNone(result)


# ── ipc_roundtrip ────────────────────────────────────────────────────────────

class TestIpcRoundtrip(unittest.TestCase):

    def _make_mock_socket(self, response: dict | None) -> MagicMock:
        mock = MagicMock()
        mock.sendall.return_value = None
        if response is not None:
            line = (json.dumps(response) + "\n").encode("utf-8")
            mock.recv.side_effect = [line, b""]
        else:
            mock.recv.side_effect = [b""]
        return mock

    def test_returns_parsed_response(self):
        resp = {"type": "PONG", "requestId": "r1"}
        mock_sock = self._make_mock_socket(resp)
        result = host.ipc_roundtrip(mock_sock, {"type": "PING", "requestId": "r1"})
        self.assertEqual(result["type"], "PONG")

    def test_returns_none_on_send_failure(self):
        mock_sock = MagicMock()
        mock_sock.sendall.side_effect = BrokenPipeError
        result = host.ipc_roundtrip(mock_sock, {"type": "PING"})
        self.assertIsNone(result)

    def test_returns_none_when_no_response(self):
        mock_sock = self._make_mock_socket(None)
        result = host.ipc_roundtrip(mock_sock, {"type": "PING"})
        self.assertIsNone(result)

    def test_returns_none_on_malformed_json_response(self):
        mock_sock = MagicMock()
        mock_sock.sendall.return_value = None
        mock_sock.recv.side_effect = [b"not json\n", b""]
        result = host.ipc_roundtrip(mock_sock, {"type": "PING"})
        self.assertIsNone(result)


# ── TCP socket (Unix-only) ────────────────────────────────────────────────────

@unittest.skipIf(sys.platform == "win32", "Unix socket test skipped on Windows")
class TestUnixSocketIntegration(unittest.TestCase):
    """Light integration test: real Unix socket server that echoes messages."""

    def setUp(self):
        self.tmp = tempfile.mktemp(suffix=".sock")
        self._start_echo_server()

    def tearDown(self):
        self._stop_echo_server()
        try:
            os.unlink(self.tmp)
        except FileNotFoundError:
            pass

    def _start_echo_server(self):
        self._server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._server.bind(self.tmp)
        self._server.listen(1)
        self._server_thread = threading.Thread(target=self._serve, daemon=True)
        self._server_thread.start()

    def _serve(self):
        try:
            conn, _ = self._server.accept()
            data = b""
            while True:
                chunk = conn.recv(4096)
                if not chunk:
                    break
                data += chunk
                if b"\n" in data:
                    line, remainder = data.split(b"\n", 1)
                    # Echo back the same message as a response.
                    conn.sendall(line + b"\n")
                    data = remainder
            conn.close()
        except Exception:
            pass

    def _stop_echo_server(self):
        try:
            self._server.close()
        except Exception:
            pass

    def test_connect_and_roundtrip(self):
        sock = host._connect_unix(self.tmp)
        try:
            msg = {"type": "PING", "requestId": "rt1"}
            resp = host.ipc_roundtrip(sock, msg)
            self.assertIsNotNone(resp)
            self.assertEqual(resp["type"], "PING")
        finally:
            sock.close()


# ── Protocol version ─────────────────────────────────────────────────────────

class TestProtocolVersion(unittest.TestCase):

    def test_version_is_integer(self):
        self.assertIsInstance(host.PROTOCOL_VERSION, int)

    def test_version_is_positive(self):
        self.assertGreater(host.PROTOCOL_VERSION, 0)


# ── Extension ID validation ───────────────────────────────────────────────────

class TestExtensionIdValidation(unittest.TestCase):
    """
    Tests for the extension-ID validation logic used by the install scripts.
    The validation rules are:
      - Exactly 32 characters.
      - Lowercase letters only (a-z).  Chrome uses a-p but we accept a-z.
    These tests validate the same regex used in install_macos.sh and
    install_windows.ps1 so that script and test stay in sync.
    """

    # ── Helpers ────────────────────────────────────────────────────────────────

    @staticmethod
    def _is_valid_id(extension_id: str) -> bool:
        """Mirror of the validation in the install scripts."""
        import re
        return bool(re.fullmatch(r"[a-z]{32}", extension_id))

    @staticmethod
    def _make_origin(extension_id: str) -> str:
        return f"chrome-extension://{extension_id}/"

    # ── Valid IDs ──────────────────────────────────────────────────────────────

    def test_valid_lowercase_32_chars(self):
        valid_id = "a" * 32
        self.assertTrue(self._is_valid_id(valid_id))

    def test_valid_real_world_style(self):
        # Typical Chrome extension ID — 32 lowercase letters.
        self.assertTrue(self._is_valid_id("nkbihfbeogaeaoehlefnkodbefgpgknn"))

    def test_valid_all_a_through_p(self):
        # Chrome IDs use letters a-p; ensure our validator accepts them.
        self.assertTrue(self._is_valid_id("abcdefghijklmnopabcdefghijklmnop"))

    # ── Missing / empty ID ─────────────────────────────────────────────────────

    def test_empty_string_rejected(self):
        self.assertFalse(self._is_valid_id(""))

    def test_none_equivalent_empty_rejected(self):
        self.assertFalse(self._is_valid_id(""))

    # ── Wrong length ───────────────────────────────────────────────────────────

    def test_too_short_31_chars_rejected(self):
        self.assertFalse(self._is_valid_id("a" * 31))

    def test_too_long_33_chars_rejected(self):
        self.assertFalse(self._is_valid_id("a" * 33))

    def test_zero_length_rejected(self):
        self.assertFalse(self._is_valid_id("a" * 0))

    # ── Invalid characters ─────────────────────────────────────────────────────

    def test_uppercase_rejected(self):
        self.assertFalse(self._is_valid_id("A" * 32))

    def test_digits_rejected(self):
        # Chrome extension IDs do not contain digits; reject them.
        self.assertFalse(self._is_valid_id("0123456789abcdefghijklmnopqrstuv"))

    def test_hyphen_rejected(self):
        self.assertFalse(self._is_valid_id("abcdefghijklmnopabcdefghijklmno-"))

    def test_space_rejected(self):
        self.assertFalse(self._is_valid_id("abcdefghijklmnopabcdefghijklmno "))

    # ── Origin URL generation ──────────────────────────────────────────────────

    def test_origin_format_correct(self):
        ext_id = "nkbihfbeogaeaoehlefnkodbefgpgknn"
        origin = self._make_origin(ext_id)
        self.assertEqual(origin, "chrome-extension://nkbihfbeogaeaoehlefnkodbefgpgknn/")

    def test_origin_starts_with_chrome_extension(self):
        origin = self._make_origin("a" * 32)
        self.assertTrue(origin.startswith("chrome-extension://"))

    def test_origin_ends_with_trailing_slash(self):
        origin = self._make_origin("a" * 32)
        self.assertTrue(origin.endswith("/"))

    def test_origin_contains_no_wildcards(self):
        origin = self._make_origin("a" * 32)
        self.assertNotIn("*", origin)

    def test_generated_origin_matches_id(self):
        ext_id = "abcdefghijklmnopabcdefghijklmnop"
        origin = self._make_origin(ext_id)
        self.assertIn(ext_id, origin)


if __name__ == "__main__":
    unittest.main(verbosity=2)
