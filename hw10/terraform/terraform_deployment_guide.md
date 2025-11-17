# Terraform Deployment Guide

## Complete File Structure

```
cs6650-hw10-microservices/
├── terraform/
│   ├── main.tf                 # Main infrastructure config
│   ├── variables.tf            # Variable definitions
│   ├── terraform.tfvars        # Variable values
│   └── outputs.tf              # Outputs after deployment
├── product-service/
├── shopping-cart-service/
├── credit-card-authorizer/
├── warehouse-service/
└── ... (other services)
```

## Step 1: Setup AWS Credentials

```bash
# In AWS Learner Lab, click "AWS Details" → "Show"
# Copy credentials
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_DEFAULT_REGION=us-west-2

# Verify
aws sts get-caller-identity
```

## Step 2: Build and Push Docker Images

You MUST push images to ECR BEFORE running Terraform (Terraform expects images to exist).

```bash
# Run the deployment script
./deploy-to-aws.sh
```

Or manually:

```bash
# Get account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Login to ECR
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com

# For each service, create repo, build, tag, and push
# Example for shopping-cart-service:
aws ecr create-repository --repository-name shopping-cart-service --region us-west-2
cd shopping-cart-service
docker build -t shopping-cart-service .
docker tag shopping-cart-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/shopping-cart-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/shopping-cart-service:latest
cd ..

# Repeat for all services:
# - product-service
# - product-service-bad
# - credit-card-authorizer
# - warehouse-service
# - rabbitmq (pull and push: docker pull rabbitmq:3-management)
```

## Step 3: Initialize Terraform

```bash
cd terraform

# Initialize Terraform (downloads providers)
terraform init
```

## Step 4: Review Plan

```bash
# See what Terraform will create
terraform plan

# You should see it will create:
# - 6 ECR repositories
# - 1 ECS cluster
# - 6 ECS task definitions
# - 6 ECS services
# - 1 Application Load Balancer
# - 4 Target Groups
# - Security groups, CloudWatch logs, etc.
```

## Step 5: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply

# Type 'yes' when prompted

# This takes 5-10 minutes
```

## Step 6: Get Deployment Info

After deployment completes, Terraform will show outputs:

```bash
# View outputs
terraform output

# Get Load Balancer URL
terraform output load_balancer_url

# Get test commands
terraform output test_commands
```

## Step 7: Wait for Services to Start

```bash
# Services take 2-3 minutes to start after Terraform completes
# Check service status
aws ecs list-services --cluster cs6650-microservices-cluster

# Check if tasks are running
aws ecs list-tasks --cluster cs6650-microservices-cluster
```

## Step 8: Test Deployment

```bash
# Get the Load Balancer DNS
ALB_DNS=$(terraform output -raw load_balancer_dns)

# Test Product Service
curl http://$ALB_DNS/products/1

# Test Shopping Cart Service
curl -X POST http://$ALB_DNS/shopping-carts \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"TEST-001"}'

# Test CCA
curl -X POST http://$ALB_DNS/authorize \
  -H "Content-Type: application/json" \
  -d '{"credit_card_number":"1234-5678-9012-3456","amount":100.50}'

# Full checkout flow
CART_ID=$(curl -s -X POST http://$ALB_DNS/shopping-carts \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"TEST-001"}' | jq -r '.cart_id')

curl -X POST http://$ALB_DNS/shopping-carts/$CART_ID/items \
  -H "Content-Type: application/json" \
  -d '{"product_id":"PROD-001","quantity":2}'

curl -X POST http://$ALB_DNS/shopping-carts/$CART_ID/checkout \
  -H "Content-Type: application/json" \
  -d '{"credit_card_number":"1234-5678-9012-3456"}'
```

## Step 9: Monitor Services

### Check ECS Services
```bash
# Check service status
aws ecs describe-services \
  --cluster cs6650-microservices-cluster \
  --services shopping-cart-service

# Check running tasks
aws ecs list-tasks \
  --cluster cs6650-microservices-cluster \
  --service-name shopping-cart-service
```

### Check CloudWatch Logs
```bash
# View logs
aws logs tail /ecs/cs6650-microservices --follow

# Filter by service
aws logs tail /ecs/cs6650-microservices --follow --filter-pattern "shopping-cart"
```

### Check Load Balancer Health
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arns | jq -r '.shopping_cart_service')
```

## Updating Services

### Update Task Count

Edit `terraform.tfvars`:
```hcl
shopping_cart_service_count = 3  # Changed from 2
```

Then apply:
```bash
terraform apply
```

### Update Docker Images

```bash
# Build and push new image
cd shopping-cart-service
docker build -t shopping-cart-service .
docker tag shopping-cart-service:latest $AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/shopping-cart-service:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.us-west-2.amazonaws.com/shopping-cart-service:latest

# Force new deployment
aws ecs update-service \
  --cluster cs6650-microservices-cluster \
  --service shopping-cart-service \
  --force-new-deployment
```

## Troubleshooting

### Services Not Starting

```bash
# Check task stopped reason
aws ecs describe-tasks \
  --cluster cs6650-microservices-cluster \
  --tasks $(aws ecs list-tasks --cluster cs6650-microservices-cluster --query 'taskArns[0]' --output text)
```

### RabbitMQ Connection Issues

The Shopping Cart and Warehouse services need RabbitMQ's private IP. If there are issues:

```bash
# Get RabbitMQ task
RABBITMQ_TASK=$(aws ecs list-tasks --cluster cs6650-microservices-cluster --service-name rabbitmq-service --query 'taskArns[0]' --output text)

# Get private IP
RABBITMQ_IP=$(aws ecs describe-tasks \
  --cluster cs6650-microservices-cluster \
  --tasks $RABBITMQ_TASK \
  --query 'tasks[0].attachments[0].details[?name==`privateIPv4Address`].value' \
  --output text)

echo "RabbitMQ IP: $RABBITMQ_IP"

# Update task definitions with correct IP if needed
```

### Load Balancer Not Routing

```bash
# Check listener rules
aws elbv2 describe-rules \
  --listener-arn $(aws elbv2 describe-listeners --load-balancer-arn $(terraform output -raw load_balancer_arn) --query 'Listeners[0].ListenerArn' --output text)

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arns | jq -r '.product_service')
```

## Cleanup

### Destroy All Resources

```bash
cd terraform

# Destroy everything
terraform destroy

# Type 'yes' when prompted
```

### Manual Cleanup (if needed)

```bash
# Stop all services
aws ecs update-service --cluster cs6650-microservices-cluster --service shopping-cart-service --desired-count 0

# Delete services
aws ecs delete-service --cluster cs6650-microservices-cluster --service shopping-cart-service --force

# Delete cluster
aws ecs delete-cluster --cluster cs6650-microservices-cluster

# Delete ECR images
aws ecr batch-delete-image --repository-name shopping-cart-service --image-ids imageTag=latest

# Delete repositories
aws ecr delete-repository --repository-name shopping-cart-service --force
```

## Cost Optimization

AWS Learner Lab has limited budget. To minimize costs:

1. **Reduce task counts** in `terraform.tfvars`:
   ```hcl
   product_service_count = 1
   shopping_cart_service_count = 1
   cca_service_count = 1
   ```

2. **Use smaller CPU/Memory**:
   ```hcl
   shopping_cart_cpu = 256
   shopping_cart_memory = 512
   ```

3. **Destroy when not testing**:
   ```bash
   terraform destroy
   ```

4. **Only run load tests during designated times**

## Next Steps

1. ✅ Deploy infrastructure with Terraform
2. ✅ Test all services
3. ✅ Run load tests
4. ✅ Take screenshots for report
5. ✅ Monitor metrics in CloudWatch
6. ✅ Document results

## Common Issues and Solutions

| Issue | Solution |
|-------|----------|
| "Image not found" | Build and push images BEFORE terraform apply |
| "No space left on device" | Docker cleanup: `docker system prune -a` |
| Tasks keep stopping | Check CloudWatch logs for errors |
| Health checks failing | Verify /health endpoint works locally first |
| RabbitMQ connection failed | Check security group allows port 5672 |
| 504 Gateway Timeout | Increase task count or CPU/memory |

## Architecture Overview

```
Client
  ↓
Application Load Balancer (routes by path)
  ↓
┌─────────────┬──────────────────┬────────────────┐
│  /products  │  /shopping-carts │   /authorize   │
↓             ↓                  ↓
Product       Shopping Cart      Credit Card
Service       Service            Authorizer
(2 tasks)     (2 tasks)          (2 tasks)
              ↓                   
          RabbitMQ ────────→ Warehouse
         (1 task)           Service
                           (1 task)
```

Total: 8 Fargate tasks across 6 services