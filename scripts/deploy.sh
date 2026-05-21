#!/bin/bash

set -e

PROJECT_ID=$1
SSH_SOURCE_IP=$2

if [ -z "$PROJECT_ID" ] || [ -z "$SSH_SOURCE_IP" ]; then
  echo "Usage: ./deploy.sh <PROJECT_ID> <YOUR_PUBLIC_IPV4>/32"
  echo "Example: ./deploy.sh devops-internship-assignment 49.37.xx.xx/32"
  exit 1
fi

echo "Setting GCP project..."
gcloud config set project "$PROJECT_ID"

echo "Enabling required APIs..."
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com

echo "Initializing Terraform..."
cd terraform
terraform init

echo "Applying Terraform..."
terraform apply \
  -var="project_id=$PROJECT_ID" \
  -var="ssh_source_ip=$SSH_SOURCE_IP"

echo "Deployment completed."
terraform output