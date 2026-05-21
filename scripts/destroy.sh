#!/bin/bash

set -e

PROJECT_ID=$1
SSH_SOURCE_IP=$2

if [ -z "$PROJECT_ID" ] || [ -z "$SSH_SOURCE_IP" ]; then
  echo "Usage: ./destroy.sh <PROJECT_ID> <YOUR_PUBLIC_IPV4>/32"
  echo "Example: ./destroy.sh devops-internship-assignment 49.37.xx.xx/32"
  exit 1
fi

echo "Setting GCP project..."
gcloud config set project "$PROJECT_ID"

echo "Destroying Terraform resources..."
cd terraform
terraform destroy \
  -var="project_id=$PROJECT_ID" \
  -var="ssh_source_ip=$SSH_SOURCE_IP"

echo "Destroy completed."