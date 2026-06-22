import html
import os
import re
import shutil
import tarfile
import tempfile
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlparse


DATA_DIRECTORY = Path(os.environ.get("ARTIFACT_DATA_DIRECTORY", "/data")).resolve()
REPORT_ID_PATTERN = re.compile(r"^[A-Za-z0-9._-]+$")


class ArtifactRequestHandler(SimpleHTTPRequestHandler):
    server_version = "ConcourseArtifactServer/1.0"

    def do_GET(self):
        path = urlparse(self.path).path

        if path == "/health":
            self._send_text(200, "ok\n")
            return

        if path in ("/", "/reports", "/reports/"):
            self._send_report_index()
            return

        if not path.startswith("/reports/"):
            self.send_error(404)
            return

        super().do_GET()

    def do_POST(self):
        path = urlparse(self.path).path
        match = re.fullmatch(r"/reports/([^/]+)", path)

        if match is None:
            self.send_error(404)
            return

        report_id = unquote(match.group(1))
        if REPORT_ID_PATTERN.fullmatch(report_id) is None:
            self.send_error(400, "Invalid report identifier")
            return

        content_length = self.headers.get("Content-Length")
        if content_length is None:
            self.send_error(411, "Content-Length is required")
            return

        DATA_DIRECTORY.mkdir(parents=True, exist_ok=True)
        target_directory = DATA_DIRECTORY / report_id

        try:
            with tempfile.TemporaryDirectory(dir=DATA_DIRECTORY) as temporary_directory:
                temporary_path = Path(temporary_directory)
                archive_path = temporary_path / "report.tar.gz"
                extract_path = temporary_path / "extracted"
                extract_path.mkdir()

                with archive_path.open("wb") as archive:
                    remaining = int(content_length)
                    while remaining > 0:
                        chunk = self.rfile.read(min(remaining, 1024 * 1024))
                        if not chunk:
                            raise ValueError("Upload ended before Content-Length bytes were received")
                        archive.write(chunk)
                        remaining -= len(chunk)

                with tarfile.open(archive_path, "r:gz") as archive:
                    archive.extractall(extract_path, filter="data")

                if target_directory.exists():
                    shutil.rmtree(target_directory)
                shutil.move(str(extract_path), str(target_directory))
        except (OSError, tarfile.TarError, ValueError) as error:
            self.send_error(400, f"Unable to store report: {error}")
            return

        report_url = f"/reports/{report_id}/allure-report/index.html"
        self.send_response(201)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write(f"{report_url}\n".encode())

    def translate_path(self, path):
        parsed_path = urlparse(path).path
        relative_path = unquote(parsed_path.removeprefix("/reports/")).lstrip("/")
        candidate = (DATA_DIRECTORY / relative_path).resolve()

        if candidate != DATA_DIRECTORY and DATA_DIRECTORY not in candidate.parents:
            return str(DATA_DIRECTORY / "__not_found__")

        return str(candidate)

    def _send_report_index(self):
        DATA_DIRECTORY.mkdir(parents=True, exist_ok=True)
        report_ids = sorted(
            (path.name for path in DATA_DIRECTORY.iterdir() if path.is_dir()),
            reverse=True,
        )
        links = "\n".join(
            f'<li><a href="/reports/{html.escape(report_id)}/allure-report/index.html">'
            f"{html.escape(report_id)}</a></li>"
            for report_id in report_ids
        )
        document = (
            "<!doctype html><html><head><meta charset=\"utf-8\">"
            "<title>Concourse Allure Reports</title></head><body>"
            f"<h1>Concourse Allure Reports</h1><ul>{links}</ul></body></html>"
        )
        encoded_document = document.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded_document)))
        self.end_headers()
        self.wfile.write(encoded_document)

    def _send_text(self, status, value):
        encoded_value = value.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(encoded_value)))
        self.end_headers()
        self.wfile.write(encoded_value)


if __name__ == "__main__":
    DATA_DIRECTORY.mkdir(parents=True, exist_ok=True)
    ThreadingHTTPServer(("0.0.0.0", 8081), ArtifactRequestHandler).serve_forever()
