"""Launch the independent Node service in isolated integration checks."""
import json
import os
import shutil
import socket
import subprocess
import time
from pathlib import Path
from urllib.request import Request, urlopen


class NodeSidecar:
    def __init__(self, source, config, database):
        self.source, self.config, self.database = Path(source), config, Path(database)
        self.process = None

    def start(self, port=0):
        if not port:
            with socket.socket() as sock:
                sock.bind(('127.0.0.1', 0))
                port = sock.getsockname()[1]
        self.server_port = port
        config_file = self.database.with_suffix('.config.json')
        config_file.write_text(json.dumps({**self.config, 'api_token_env': 'SIDECAR_CHECK_TOKEN'}), encoding='utf-8')
        env = {**os.environ, 'SIDECAR_CHECK_TOKEN': self.config['api_token']}
        self.process = subprocess.Popen([shutil.which('node'), str(self.source / 'src' / 'cli.js'),
            '--config', str(config_file), '--database', str(self.database), '--port', str(port)],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
        for _ in range(100):
            if self.process.poll() is not None:
                raise RuntimeError('Node sidecar exited during startup')
            try:
                req = Request(f'http://127.0.0.1:{port}/v1/health', headers={'Authorization': 'Bearer ' + self.config['api_token']})
                with urlopen(req, timeout=.5) as response:
                    if response.status == 200:
                        return self
            except OSError:
                time.sleep(.05)
        self.close()
        raise RuntimeError('Node sidecar startup timed out')

    def close(self):
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
            self.process = None
