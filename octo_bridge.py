"""Custom localhost HTTP bridge. Painter API calls run on the Qt main thread."""
import ast
import base64
import contextlib
import io
import json
import queue
import threading
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from PySide6.QtCore import QTimer
import substance_painter as sp

PORT = 60043
_requests = queue.Queue()
_namespace = {"__name__": "octo_remote"}
_server = None
_timer = None


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def do_POST(self):
        if self.path != "/run.json":
            self.send_error(404)
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            if not 0 < length <= 1048576:
                raise ValueError("Invalid request size")
            payload = json.loads(self.rfile.read(length))
            code = base64.b64decode(payload["python"], validate=True).decode("utf-8")
            reply = queue.Queue(maxsize=1)
            _requests.put((code, reply))
            result = reply.get(timeout=25)
        except Exception:
            result = {"error": traceback.format_exc()}
        encoded = json.dumps(result).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def _drain():
    # QTimer invokes this on Painter's main thread, never the HTTP worker.
    try:
        code, reply = _requests.get_nowait()
    except queue.Empty:
        return
    try:
        tree = ast.parse(code)
        final = tree.body.pop() if tree.body and isinstance(tree.body[-1], ast.Expr) else None
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            exec(compile(tree, "<octo-bridge>", "exec"), _namespace)
            value = eval(compile(ast.Expression(final.value), "<octo-bridge>", "eval"), _namespace) if final else None
        result = {"result": value, "stdout": stdout.getvalue()}
        json.dumps(result)
    except Exception:
        result = {"error": traceback.format_exc()}
    reply.put(result)


def start_plugin():
    global _server, _timer
    if _server:
        return
    _server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    _server.daemon_threads = True
    _timer = QTimer()
    _timer.setInterval(50)
    _timer.timeout.connect(_drain)
    _timer.start()
    threading.Thread(target=_server.serve_forever, daemon=True).start()
    sp.logging.info("Octo bridge listening on 127.0.0.1:60043")


def close_plugin():
    global _server, _timer
    if _timer:
        _timer.stop()
        _timer = None
    if _server:
        _server.shutdown()
        _server.server_close()
        _server = None
