# DevOps Internship Assignment — GCP Terraform Deployment

## Project Overview

This project deploys a multi-VM worker architecture on Google Cloud Platform using Terraform.

The architecture includes:

- A custom VPC
- A private subnet
- Cloud Router and Cloud NAT
- One public API Gateway VM
- Two private worker VMs
- Internal RPC-style communication between workers
- A public JSON HTTP API exposed only through the API Gateway

The API Gateway receives a JSON request, forwards it to the Python Worker, and the Python Worker calls the TypeScript Worker over the private subnet. The final response is returned as JSON.

---

## Architecture Diagram

```text
Internet
   |
   | HTTP :8080
   v
+----------------------+
| API Gateway VM       |
| Public IP: Yes       |
| Private IP: 10.10.1.10
| Port: 8080           |
+----------+-----------+
           |
           | Internal RPC / HTTP
           v
+----------------------+
| Python Worker VM     |
| Public IP: No        |
| Private IP: 10.10.1.20
| Port: 5000           |
+----------+-----------+
           |
           | Internal RPC / HTTP
           v
+----------------------+
| TypeScript Worker VM |
| Public IP: No        |
| Private IP: 10.10.1.30
| Port: 4000           |
+----------------------+
```

---

## Infrastructure Created

Terraform provisions the following GCP resources:

- VPC: `quickstart-vpc`
- Subnet: `quickstart-private-subnet`
- Cloud Router: `quickstart-router`
- Cloud NAT: `quickstart-nat`
- VM: `api-gateway-vm`
- VM: `python-worker-vm`
- VM: `typescript-worker-vm`
- Firewall rules for:
  - Public API access on port `8080`
  - SSH access
  - Internal worker communication
  - Internal ICMP testing
  - IAP SSH access

---

## VM Layout

| VM Name | Role | Private IP | Public IP |
|---|---|---|---|
| api-gateway-vm | Public JSON API Gateway | 10.10.1.10 | Yes |
| python-worker-vm | Python Worker | 10.10.1.20 | No |
| typescript-worker-vm | TypeScript Worker | 10.10.1.30 | No |

Only the API Gateway VM is reachable from the public internet. The worker VMs run in the private subnet and do not have external IP addresses.

---

## Worker Flow

```text
Client curl request
   ↓
API Gateway VM :8080
   ↓
Python Worker VM :5000
   ↓
TypeScript Worker VM :4000
   ↓
JSON response returned to client
```

---

## API Endpoint

### Health Check

```bash
curl http://<API_GATEWAY_PUBLIC_IP>:8080/
```

Expected response:

```json
{
  "service": "api-gateway",
  "status": "running"
}
```

---

## Inference API Request

Replace `<API_GATEWAY_PUBLIC_IP>` with the Terraform output value.

### Linux / Git Bash

```bash
curl -X POST http://<API_GATEWAY_PUBLIC_IP>:8080/infer \
-H "Content-Type: application/json" \
-d '{"prompt":"Hello from DevOps assignment"}'
```

### Windows CMD

```bash
curl -X POST http://<API_GATEWAY_PUBLIC_IP>:8080/infer ^
-H "Content-Type: application/json" ^
-d "{\"prompt\":\"Hello from DevOps assignment\"}"
```

---

## Sample Response

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

## Deployment Scripts and Services

Each VM is configured using a startup script.

| VM | Startup Script | Service |
|---|---|---|
| API Gateway | `terraform/startup-scripts/api-gateway.sh` | `api-gateway.service` |
| Python Worker | `terraform/startup-scripts/python-worker.sh` | `python-worker.service` |
| TypeScript Worker | `terraform/startup-scripts/typescript-worker.sh` | `ts-worker.service` |

The startup scripts install the required runtime, create the application files, install dependencies, and register systemd services.

---

## Redeployment Instructions

### 1. Prerequisites

Install:

- Google Cloud CLI
- Terraform
- Git

Authenticate with GCP:

```bash
gcloud auth login
gcloud auth application-default login
```

Set your project:

```bash
gcloud config set project <PROJECT_ID>
```

Enable required APIs:

```bash
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
```

---

### 2. Clone the Repository

```bash
git clone https://github.com/Talha78629/-devops-internship-assignment.git
cd -devops-internship-assignment
```

---

### 3. Get Public IPv4 Address

```bash
curl -4 ifconfig.me
```

Use the output as `<YOUR_PUBLIC_IPV4>/32`.

Example:

```text
49.37.xx.xx/32
```

---

### 4. Deploy with Terraform

```bash
cd terraform
terraform init
terraform validate
terraform apply \
-var="project_id=<PROJECT_ID>" \
-var="ssh_source_ip=<YOUR_PUBLIC_IPV4>/32"
```

For Windows CMD:

```bash
cd terraform
terraform init
terraform validate
terraform apply ^
-var="project_id=<PROJECT_ID>" ^
-var="ssh_source_ip=<YOUR_PUBLIC_IPV4>/32"
```

Type `yes` when Terraform asks for confirmation.

---

### 5. Get API Gateway Public IP

```bash
terraform output api_gateway_public_ip
```

---

### 6. Test the API

```bash
curl http://<API_GATEWAY_PUBLIC_IP>:8080/
```

Then test the full worker flow:

```bash
curl -X POST http://<API_GATEWAY_PUBLIC_IP>:8080/infer \
-H "Content-Type: application/json" \
-d '{"prompt":"Hello from DevOps assignment"}'
```

---

## Network Hygiene Validation

Check VM IPs:

```bash
gcloud compute instances list
```

Expected result:

```text
api-gateway-vm        has external IP
python-worker-vm      no external IP
typescript-worker-vm  no external IP
```

The worker VMs should not be reachable from the public internet.

From a local machine, these commands should fail:

```bash
curl http://10.10.1.20:5000/infer
curl http://10.10.1.30:4000/process
```

Only the API Gateway endpoint should be publicly reachable:

```bash
http://<API_GATEWAY_PUBLIC_IP>:8080
```

---

## Debugging Commands

SSH into API Gateway:

```bash
gcloud compute ssh api-gateway-vm --zone=us-central1-a
```

Check API Gateway service:

```bash
sudo systemctl status api-gateway
sudo journalctl -u api-gateway -n 50
```

Check Python Worker service:

```bash
sudo systemctl status python-worker
sudo journalctl -u python-worker -n 50
```

Check TypeScript Worker service:

```bash
sudo systemctl status ts-worker
sudo journalctl -u ts-worker -n 50
```

Check listening ports:

```bash
sudo ss -tulnp | grep 8080
sudo ss -tulnp | grep 5000
sudo ss -tulnp | grep 4000
```

Test private connectivity from API Gateway:

```bash
curl http://10.10.1.20:5000/docs
curl -X POST http://10.10.1.30:4000/process \
-H "Content-Type: application/json" \
-d '{"prompt":"internal test"}'
```

---

## Production Hardening

Before putting this into production, I would harden the setup in the following ways:

1. Place the API Gateway behind a managed HTTPS Load Balancer.
2. Use TLS certificates instead of plain HTTP.
3. Add API authentication using API keys, OAuth, JWT, or IAM-aware access.
4. Restrict public access further using allowlisted IP ranges where possible.
5. Use least-privilege service accounts for each VM.
6. Move startup script logic into versioned images, containers, or Ansible playbooks.
7. Store secrets and configuration in Google Secret Manager instead of scripts.
8. Enable Cloud Logging and Cloud Monitoring for centralized observability.
9. Add health checks and auto-healing instance groups.
10. Store Terraform state remotely in a GCS bucket with versioning.
11. Add CI/CD validation for Terraform format, validate, and plan.
12. Add alerting for service failure, high CPU, memory pressure, and error rates.

---

## If the Model Were 100x Larger

If the model were 100x larger, I would change the architecture significantly.

Instead of running the model on small CPU-only VMs, I would use GPU-backed instances or a managed inference platform. A larger model would require more memory, faster disk, better networking, and possibly GPU acceleration for acceptable latency.

I would also separate inference into a dedicated scalable model-serving layer. The API Gateway would only handle request validation and routing, while model workers would run behind an internal load balancer or on GKE with autoscaling. For high traffic, I would introduce Pub/Sub or Cloud Tasks so requests can be queued, retried, and processed reliably.

For large models, model loading time and cold starts become important. I would keep model workers warm, use container images with preloaded dependencies, consider model quantization, and add horizontal scaling based on queue depth or request latency.

If the workload required GPUs, I would use dedicated GPU node pools, monitor GPU utilization, and apply autoscaling carefully because GPU instances are expensive. I would also add batching where possible to improve throughput.

---

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy \
-var="project_id=<PROJECT_ID>" \
-var="ssh_source_ip=<YOUR_PUBLIC_IPV4>/32"
```

For Windows CMD:

```bash
cd terraform
terraform destroy ^
-var="project_id=<PROJECT_ID>" ^
-var="ssh_source_ip=<YOUR_PUBLIC_IPV4>/32"
```

---

## Notes

This implementation demonstrates a reproducible multi-VM worker deployment on GCP using Terraform. The workers communicate over private IPs inside the subnet, while only the API Gateway exposes a public JSON HTTP endpoint.