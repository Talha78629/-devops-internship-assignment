#!/bin/bash
apt update -y
apt install -y nodejs npm nginx

mkdir -p /opt/api-gateway
cd /opt/api-gateway

cat > package.json <<'EOF'
{
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "axios": "^1.6.0",
    "express": "^4.18.2"
  }
}
EOF

cat > server.js <<'EOF'
const express = require("express");
const axios = require("axios");

const app = express();
app.use(express.json());

const PYTHON_WORKER_URL = "http://10.10.1.20:5000/infer";

app.get("/", (req, res) => {
  res.json({
    service: "api-gateway",
    status: "running"
  });
});

app.post("/infer", async (req, res) => {
  try {
    const response = await axios.post(PYTHON_WORKER_URL, {
      prompt: req.body.prompt
    });

    res.json({
      gateway: "api-gateway",
      message: "Request routed through API Gateway to Python Worker",
      result: response.data
    });
  } catch (error) {
    res.status(500).json({
      error: "Failed to call Python worker",
      details: error.message
    });
  }
});

app.listen(8080, "0.0.0.0", () => {
  console.log("API Gateway listening on port 8080");
});
EOF

npm install

cat > /etc/systemd/system/api-gateway.service <<'EOF'
[Unit]
Description=API Gateway Service
After=network.target

[Service]
WorkingDirectory=/opt/api-gateway
ExecStart=/usr/bin/node /opt/api-gateway/server.js
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable api-gateway
systemctl start api-gateway

echo "API Gateway VM Ready" > /var/www/html/index.html