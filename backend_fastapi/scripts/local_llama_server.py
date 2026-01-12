"""
Simple local LLaMA inference HTTP server.

Runs in a separate process from the main FastAPI backend to avoid
segmentation faults / bus errors when using llama-cpp-python under uvicorn.

Endpoint:
    POST /generate
    Body: {"prompt": "...", "max_new_tokens": 512}
    Response: {"text": "..."}
"""

from __future__ import annotations

import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from app.core.local_services import _get_llama_model


class LlamaHandler(BaseHTTPRequestHandler):
    server_version = "LocalLlamaHTTP/0.1"

    def _send_json(self, status: int, payload: Any) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self) -> None:  # type: ignore[override]
        if self.path != "/generate":
            self._send_json(404, {"error": "Not found"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            self._send_json(400, {"error": "Invalid Content-Length"})
            return

        try:
            raw = self.rfile.read(length)
            data = json.loads(raw or b"{}")
        except Exception:
            self._send_json(400, {"error": "Invalid JSON"})
            return

        prompt: str = data.get("prompt") or ""
        max_new_tokens: int = int(data.get("max_new_tokens") or 512)

        if not prompt:
            self._send_json(400, {"error": "Missing 'prompt'"})
            return

        try:
            model = _get_llama_model()
            output = model(
                prompt,
                max_tokens=max_new_tokens,
                temperature=0.8,
                top_p=0.9,
                repeat_penalty=1.05,
                stop=["</s>", "<|user|>", "<|system|>"],
            )
            text = output["choices"][0]["text"].strip()
            self._send_json(200, {"text": text})
        except Exception as e:
            self._send_json(500, {"error": f"Inference failed: {e}"})


def run(host: str = "0.0.0.0", port: int = 8090) -> None:
    server = ThreadingHTTPServer((host, port), LlamaHandler)
    print(f"Local LLaMA server running on http://{host}:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Shutting down local LLaMA server...")
    finally:
        server.server_close()


if __name__ == "__main__":
    run()

