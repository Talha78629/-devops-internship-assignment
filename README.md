# DevOps Internship Assignment — GCP Terraform Multi-VM Deployment

## Architecture

```
                          Internet
                              │
                    HTTP :8080│
                              ▼
               ┌──────────────────────────┐
               │      api-gateway-vm      │
               │  Public IP:  <assigned>  │
               │  Private IP: 10.10.1.10  │
               │  Port: 8080              │
               └────────────┬─────────────┘
                            │
                  Internal HTTP (private subnet)
                            │
               ┌────────────▼─────────────┐
               │     python-worker-vm     │
               │  Public IP:  NONE        │
               │  Private IP: 10.10.1.20  │
               │  Port: 5000              │
               └────────────┬─────────────┘
                            │
                  Internal HTTP (private subnet)
                            │
               ┌────────────▼─────────────┐
               │   typescript-worker-vm   │
               │  Public IP:  NONE        │
               │  Private IP: 10.10.1.30  │
               │  Port: 4000              │
               └──────────────────────────┘

VPC: quickstart-vpc
Subnet: quickstart-private-subnet (10.10.1.0/24)
Cloud NAT: allows private VMs to reach the internet for package installs
```

**RPC Flow:**
```
Client → API Gateway :8080 → Python Worker :5000 → TypeScript Worker :4000 → JSON response
```

---

## Repository Structure

```
.
├── terraform/
│   ├── main.tf                    # VPC, subnet, Cloud Router, Cloud NAT, VMs, firewall rules
│   ├── variables.tf
│   ├── outputs.tf
│   └── startup-scripts/
│       ├── api-gateway.sh         # Installs Node.js, creates Express app, registers systemd service
│       ├── python-worker.sh       # Installs Python, creates Flask app, registers systemd service
│       └── typescript-worker.sh   # Installs Node.js/ts-node, creates app, registers systemd service
└── README.md
```

---

## Quick Start: Redeploy from Scratch

### Prerequisites

Install the following tools:
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
- [Terraform](https://developer.hashicorp.com/terraform/install) (>= 1.3)
- Git

### Step 1 — Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

Enable required APIs:

```bash
gcloud services enable compute.googleapis.com iam.googleapis.com
```

### Step 2 — Clone the Repository

```bash
git clone https://github.com/Talha78629/-devops-internship-assignment.git
cd -devops-internship-assignment
```

### Step 3 — Get Your Public IP (for SSH firewall allowlist)

```bash
curl -4 ifconfig.me
```

You'll use this as `YOUR_PUBLIC_IPV4/32` in the next step (e.g. `49.37.xx.xx/32`).

### Step 4 — Deploy with Terraform

```bash
cd terraform
terraform init
terraform validate
terraform apply \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="ssh_source_ip=YOUR_PUBLIC_IPV4/32"
```

> **Windows CMD:**
> ```cmd
> terraform apply ^
>   -var="project_id=YOUR_PROJECT_ID" ^
>   -var="ssh_source_ip=YOUR_PUBLIC_IPV4/32"
> ```

Type `yes` when prompted. Deployment takes ~3–5 minutes including VM startup scripts.

### Step 5 — Get the API Gateway IP

```bash
terraform output api_gateway_public_ip
```

---

## API Usage

### Health Check

```bash
curl http://API_GATEWAY_PUBLIC_IP:8080/
```

Expected response:

```json
{
  "service": "api-gateway",
  "status": "running"
}
```

### Inference Request

**Linux / macOS / Git Bash:**

```bash
curl -X POST http://API_GATEWAY_PUBLIC_IP:8080/infer \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello from DevOps assignment"}'
```

**Windows CMD:**

```cmd
curl -X POST http://API_GATEWAY_PUBLIC_IP:8080/infer ^
  -H "Content-Type: application/json" ^
  -d "{\"prompt\":\"Hello from DevOps assignment\"}"
```

### Sample Response

```json
{
  "gateway": "api-gateway",
  "message": "Request routed through API Gateway to Python Worker",
  "result": {
    "worker": "python-worker",
    "message": "Python worker received request and called TypeScript worker",
    "prompt": "Hello from DevOps assignment",
    "typescript_worker_response": {
      "worker": "typescript-worker",
      "message": "TypeScript worker processed request",
      "received_prompt": "Hello from DevOps assignment"
    }
  }
}
```

---

## Network Hygiene Validation

Verify that only the API Gateway has a public IP:

```bash
gcloud compute instances list
```

Expected:

```
NAME                     EXTERNAL_IP
api-gateway-vm           <assigned>
python-worker-vm         (none)
typescript-worker-vm     (none)
```

These requests should **fail** (workers are not publicly reachable):

```bash
curl http://10.10.1.20:5000/infer    # times out — no public route
curl http://10.10.1.30:4000/process  # times out — no public route
```

Only this should succeed:

```bash
curl http://API_GATEWAY_PUBLIC_IP:8080/
```

---

## Debugging

SSH into the API Gateway (the only VM with a public IP):

```bash
gcloud compute ssh api-gateway-vm --zone=us-central1-a
```

Check service status:

```bash
sudo systemctl status api-gateway
sudo systemctl status python-worker
sudo systemctl status ts-worker
```

View recent logs:

```bash
sudo journalctl -u api-gateway -n 50
sudo journalctl -u python-worker -n 50
sudo journalctl -u ts-worker -n 50
```

Check listening ports:

```bash
sudo ss -tulnp | grep -E '8080|5000|4000'
```

Test internal connectivity from the API Gateway:

```bash
curl http://10.10.1.20:5000/docs
curl -X POST http://10.10.1.30:4000/process \
  -H "Content-Type: application/json" \
  -d '{"prompt": "internal test"}'
```

---

## Production Hardening

Before putting this stack in production, I would make the following changes:

**Security and access control:** Place the API Gateway behind a managed HTTPS load balancer with a TLS certificate — plain HTTP over port 8080 is not acceptable for production traffic. Add API authentication (API keys, JWT, or GCP IAM-aware proxy) so the endpoint is not open to anyone. Where possible, restrict public ingress to known IP ranges. Assign least-privilege service accounts to each VM rather than relying on the default compute account.

**Secrets management:** The startup scripts currently embed configuration inline. In production, secrets and environment config should be stored in Google Secret Manager and fetched at runtime. Startup script logic should be moved into versioned container images or Ansible playbooks so deployments are reproducible and auditable.

**Observability and reliability:** Enable Cloud Logging and Cloud Monitoring for centralized log aggregation and metrics. Add uptime checks and alerting on service failure, high error rates, and resource pressure (CPU, memory). Replace standalone VMs with managed instance groups that have health checks and auto-healing enabled.

**Infrastructure state:** Terraform state should be stored remotely in a GCS bucket with versioning enabled, rather than locally. Add a CI/CD pipeline that runs `terraform fmt`, `validate`, and `plan` on every pull request before any `apply`.

---

## Scaling to a 100x Larger Model

The current architecture uses small CPU-only VMs which are appropriate for lightweight request routing and simple compute. A 100x larger model would require a fundamentally different approach.

**Compute:** The model-serving layer would need GPU-backed instances (e.g., `n1-standard` with attached A100s or `a2-highgpu` families) or a managed inference platform such as Vertex AI. Model loading time becomes significant at this scale, so workers should be kept warm rather than started on demand, and container images should have all dependencies and model weights preloaded.

**Architecture:** The API Gateway would be separated from the inference layer entirely — it would handle only request validation, authentication, and routing. Model workers would run behind an internal load balancer, or on GKE with horizontal pod autoscaling triggered by queue depth or request latency. For high or bursty traffic, I would introduce Pub/Sub or Cloud Tasks to queue requests so they can be retried and processed reliably without dropping under load.

**Efficiency:** At this scale, model quantization (INT8/INT4) and batching multiple requests into a single forward pass become important for throughput and cost. GPU utilization should be monitored closely since GPU instances are expensive, and autoscaling should be tuned carefully to avoid over-provisioning while still handling traffic spikes.

---

## Cleanup

```bash
cd terraform
terraform destroy \
  -var="project_id=YOUR_PROJECT_ID" \
  -var="ssh_source_ip=YOUR_PUBLIC_IPV4/32"
```
