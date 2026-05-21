#!/bin/bash
apt update -y
apt install -y python3 python3-pip

mkdir -p /opt/python-worker
cd /opt/python-worker

cat > app.py <<'EOF'
from fastapi import FastAPI
from pydantic import BaseModel
import requests

app = FastAPI()

TS_WORKER_URL = "http://10.10.1.30:4000/process"

class InferRequest(BaseModel):
    prompt: str

@app.post("/infer")
def infer(req: InferRequest):
    ts_response = requests.post(TS_WORKER_URL, json={"prompt": req.prompt}, timeout=10)

    return {
        "worker": "python-worker",
        "message": "Python worker received request and called TypeScript worker",
        "prompt": req.prompt,
        "typescript_worker_response": ts_response.json()
    }
EOF

pip3 install fastapi uvicorn requests

cat > /etc/systemd/system/python-worker.service <<'EOF'
[Unit]
Description=Python Worker Service
After=network.target

[Service]
WorkingDirectory=/opt/python-worker
ExecStart=/usr/local/bin/uvicorn app:app --host 0.0.0.0 --port 5000
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable python-worker
systemctl start python-worker