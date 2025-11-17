#!/bin/bash

# AWS Deployment Script for CS6650 hw10
# This script deploys all microservices to AWS ECS

set -e  # Exit on error

echo "========================================="
echo "AWS Microservices Deployment Script"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="us-west-2"
CLUSTER_NAME="microservices-cluster"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "AWS Account ID: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo ""

# Function to print success
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print info
info() {
    echo -e "${YELLOW}→${NC} $1"
}

# Step 1: Login to ECR
info "Step 1: Logging into AWS ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
success "Logged into ECR"
echo ""

# Step 2: Create ECR repositories if they don't exist
info "Step 2: Creating ECR repositories..."
REPOS=("product-service" "product-service-bad" "shopping-cart-service" "credit-card-authorizer" "warehouse-service" "rabbitmq")

for REPO in "${REPOS[@]}"; do
    aws ecr describe-repositories --repository-names $REPO --region $AWS_REGION > /dev/null 2>&1 || \
    aws ecr create-repository --repository-name $REPO --region $AWS_REGION > /dev/null 2>&1
    success "Repository: $REPO"
done
echo ""

# Step 3: Build and push Docker images
info "Step 3: Building and pushing Docker images..."

# Product Service
info "Building Product Service..."
cd product-service
docker build -t product-service:latest .
docker tag product-service:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/product-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/product-service:latest
success "Product Service pushed"
cd ..

# Product Service Bad
info "Building Product Service (Bad)..."
cd product-service-bad
docker build -t product-service-bad:latest .
docker tag product-service-bad:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/product-service-bad:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/product-service-bad:latest
success "Product Service (Bad) pushed"
cd ..

# Shopping Cart Service
info "Building Shopping Cart Service..."
cd shopping-cart-service
docker build -t shopping-cart-service:latest .
docker tag shopping-cart-service:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/shopping-cart-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/shopping-cart-service:latest
success "Shopping Cart Service pushed"
cd ..

# Credit Card Authorizer
info "Building Credit Card Authorizer..."
cd credit-card-authorizer
docker build -t credit-card-authorizer:latest .
docker tag credit-card-authorizer:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/credit-card-authorizer:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/credit-card-authorizer:latest
success "Credit Card Authorizer pushed"
cd ..

# Warehouse Service
info "Building Warehouse Service..."
cd warehouse-service
docker build -t warehouse-service:latest .
docker tag warehouse-service:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/warehouse-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/warehouse-service:latest
success "Warehouse Service pushed"
cd ..

# RabbitMQ
info "Pushing RabbitMQ image..."
docker pull rabbitmq:3-management
docker tag rabbitmq:3-management $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/rabbitmq:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/rabbitmq:latest
success "RabbitMQ pushed"

echo ""
success "All images built and pushed!"
echo ""

# Step 4: Create ECS cluster
info "Step 4: Creating ECS cluster..."
aws ecs create-cluster --cluster-name $CLUSTER_NAME --region $AWS_REGION > /dev/null 2>&1 || true
success "ECS cluster ready: $CLUSTER_NAME"
echo ""

echo "========================================="
echo "Deployment Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Go to AWS Console → ECS"
echo "2. Create task definitions for each service"
echo "3. Create ECS services"
echo "4. Configure Load Balancer"
echo ""
echo "Or use Terraform for automated infrastructure setup!"
echo ""