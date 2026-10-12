"""Local synthetic fixture; never sends user text or contacts external servers."""
import http.server
import json
import pathlib
import subprocess
import threading
import time

class Handler(http.server.BaseHTTPRequestHandler):
    redirected = False

    def log_message(self, *_):
        pass

    def do_GET(self):
        Handler.redirected = True
        self.send_error(500)

    def do_POST(self):
        if self.path not in ("/v1/chat/completions", "/api/generate"):
            Handler.redirected = True
        request = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        mode = request["model"]
        status = 200
        reply = {"choices": [{"message": {"content": "Corrected text."}, "finish_reason": "stop"}]}
        if self.path == "/api/generate":
            reply = {"response": "b;", "done": True, "done_reason": "stop"}
        body = json.dumps(reply).encode()
        if mode == "slow":
            time.sleep(0.5)
        if mode == "invalid-json":
            body = b"not JSON"
        elif mode == "http-error":
            status = 503
        elif mode == "redirect":
            status = 302
        elif mode == "oversized":
            body = b"x" * (1024 * 1024 + 1)
        elif mode == "truncated":
            if "choices" in reply:
                reply["choices"][0]["finish_reason"] = "length"
            else:
                reply["done_reason"] = "length"
            body = json.dumps(reply).encode()
        try:
            self.send_response(status)
            if mode == "redirect":
                self.send_header("Location", f"http://127.0.0.1:{self.server.server_port}/should-not-be-requested")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler) as server:
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    root = pathlib.Path(__file__).resolve().parent.parent
    result = subprocess.run([str(root / "build/core_tests"), "--http-tests",
                             f"http://127.0.0.1:{server.server_port}/v1/chat/completions"])
    server.shutdown()
    assert not Handler.redirected, "Client followed a redirect!"
    raise SystemExit(result.returncode)
