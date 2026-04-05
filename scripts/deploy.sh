#!/usr/bin/env bash
set -euo pipefail

# From repo root: configure AWS CLI, then:
#   ./scripts/deploy.sh us-east-1 latest
#
# First deploy: run `terraform apply` in ./terraform before this script so ECR exists.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGION="${1:-us-east-1}"
TAG="${2:-latest}"

cd "$ROOT/terraform"
REPO_URL="$(terraform output -raw ecr_repository_url)"
CLUSTER="$(terraform output -raw ecs_cluster_name)"
SERVICE="$(terraform output -raw ecs_service_name)"

cd "$ROOT"
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${REPO_URL%%/*}"

docker build -t "$REPO_URL:$TAG" .
docker push "$REPO_URL:$TAG"

aws ecs update-service \
  --region "$REGION" \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --force-new-deployment \
  >/dev/null

echo "Pushed $REPO_URL:$TAG and triggered ECS rollout."
