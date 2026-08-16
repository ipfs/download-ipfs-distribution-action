#!/usr/bin/env python3

import json
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

log_path, port_path = sys.argv[1:3]


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        with open(log_path, "a", encoding="utf-8") as log:
            log.write(json.dumps({"path": self.path, "authorization": self.headers.get("Authorization")}) + "\n")
        if self.path == "/asset":
            self.send_response(302)
            self.send_header("Location", f"http://localhost:{self.server.server_port}/cdn")
            self.end_headers()
            return
        if self.path == "/cdn":
            body = b"fixture archive"
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            threading.Thread(target=self.server.shutdown, daemon=True).start()
            return
        self.send_response(404)
        self.end_headers()

    def log_message(self, _format, *_args):
        return


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
with open(port_path, "w", encoding="utf-8") as port_file:
    port_file.write(str(server.server_port))
server.serve_forever()
