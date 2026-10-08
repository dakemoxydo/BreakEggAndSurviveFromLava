"""Accept one Studio world snapshot on localhost, inside the project workspace."""
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import json

target = Path(__file__).resolve().parents[1] / '.tools/world-snapshot.json'
chunks = {}
class Receiver(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path != '/snapshot':
            self.send_error(404)
            return
        data = self.rfile.read(int(self.headers['Content-Length']))
        decoded = json.loads(data)
        if isinstance(decoded, dict):
            chunks[decoded['chunk']] = decoded['data']
            if len(chunks) == decoded['total']:
                value = json.loads(''.join(chunks[i] for i in range(1, decoded['total'] + 1)))
                target.write_text(json.dumps(value), encoding='utf-8')
        else:
            assert isinstance(decoded, list)
            target.write_text(json.dumps(decoded), encoding='utf-8')
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b'saved')
        print(f'Received {len(data)} bytes', flush=True)
HTTPServer(('127.0.0.1', 8866), Receiver).serve_forever()
