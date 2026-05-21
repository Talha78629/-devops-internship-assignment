#!/bin/bash
apt update -y
apt install -y nodejs npm

mkdir -p /opt/ts-worker
cd /opt/ts-worker

cat > package.json <<'EOF'
{
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2"
  }
}
EOF

cat > server.js <<'EOF'
const express = require("express");
const app = express();
app.use(express.json());

app.post("/process", (req, res) => {
  res.json({
    worker: "typescript-worker",
    message: "TypeScript worker processed request",
    received_prompt: req.body.prompt
  });
});

app.listen(4000, "0.0.0.0", () => {
  console.log("TypeScript worker listening on port 4000");
});
EOF

npm install

cat > /etc/systemd/system/ts-worker.service <<'EOF'
[Unit]
Description=TypeScript Worker Service
After=network.target

[Service]
WorkingDirectory=/opt/ts-worker
ExecStart=/usr/bin/node /opt/ts-worker/server.js
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ts-worker
systemctl start ts-worker