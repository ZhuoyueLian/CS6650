#!/bin/bash

echo "========================================="
echo "Redeploy Script for CS6650 hw10"
echo "========================================="
echo ""

cd terraform

# Import existing ECR repositories
echo "Step 1: Importing ECR repositories..."
terraform import aws_ecr_repository.product_service product-service 2>/dev/null || true
terraform import aws_ecr_repository.product_service_bad product-service-bad 2>/dev/null || true
terraform import aws_ecr_repository.shopping_cart_service shopping-cart-service 2>/dev/null || true
terraform import aws_ecr_repository.credit_card_authorizer credit-card-authorizer 2>/dev/null || true
terraform import aws_ecr_repository.warehouse_service warehouse-service 2>/dev/null || true
terraform import aws_ecr_repository.rabbitmq rabbitmq 2>/dev/null || true

echo "✓ ECR repositories imported"
echo ""

# Deploy infrastructure
echo "Step 2: Deploying infrastructure..."
terraform apply -auto-approve

echo ""
echo "✓ Infrastructure deployed!"
echo ""
echo "Next steps:"
echo "1. Wait 2 minutes for services to start"
echo "2. Get RabbitMQ IP and update task definitions (see RESUME_TOMORROW.md)"
echo "3. Run load tests"
echo ""
