# HW4 Part II Reflection - ECR/ECS Workflow Analysis

## Automation Potential with Terraform

The ECR/ECS workflow involved significant manual configuration through the AWS console:
- Creating ECR repository
- Building and pushing Docker images
- Setting up ECS cluster 
- Defining task definitions with CPU/memory specifications
- Configuring networking and security groups
- Running tasks with specific subnet and IP settings

This process could be automated with Terraform using resources like:
- `aws_ecr_repository` for container registry
- `aws_ecs_cluster` for cluster creation
- `aws_ecs_task_definition` for container blueprints
- `aws_ecs_service` for running tasks with desired state management
- `aws_security_group` for network access control

Terraform would provide infrastructure as code benefits: version control, reproducibility, and the ability to tear down/recreate environments consistently.

## EC2 vs ECS Comparison

| Aspect | EC2 | ECS |
|--------|-----|-----|
| **Management Overhead** | High - manual server provisioning, OS updates, scaling | Low - AWS manages underlying infrastructure |
| **Scaling** | Manual instance launch/termination | Automatic based on task definitions and services |
| **Resource Utilization** | Pay for entire instances even if underutilized | Pay only for CPU/memory consumed by containers |
| **Deployment** | Manual application deployment and configuration | Container-based deployment with rollback capabilities |
| **Multi-tenancy** | One application per instance typically | Multiple containers can share compute resources |
| **Operational Complexity** | Requires systems administration skills | Focus on application logic, not infrastructure management |

ECS with Fargate provides serverless container orchestration, while EC2 requires traditional server management approaches.

## VPC and Subnet Architecture

**Virtual Private Cloud (VPC)**: An isolated network environment within AWS where you can launch resources. It provides:
- Network isolation from other AWS customers
- Control over IP address ranges (CIDR blocks)
- Route table and gateway configuration
- Security group and network ACL management

**Subnets**: Subdivisions of a VPC that exist within specific Availability Zones. They enable:
- Logical separation of resources within a VPC
- Different routing rules for public vs private resources
- Distribution of workloads across multiple AZs for high availability

**Default VPC Access**: AWS Academy Learner Lab provides a pre-configured default VPC with:
- Public subnets in multiple Availability Zones
- Internet Gateway for external connectivity
- Default route tables enabling internet access
- Default security groups with basic access rules

This eliminates the need to manually create networking infrastructure for basic deployments.

## TCP vs UDP Protocol Differences

**TCP (Transmission Control Protocol)**:
- Connection-oriented protocol requiring handshake establishment
- Reliable delivery with acknowledgment and retransmission
- Ordered packet delivery guaranteed
- Flow control prevents overwhelming receivers
- Error detection and correction built-in
- Higher overhead due to connection state management

**UDP (User Datagram Protocol)**:
- Connectionless protocol with no handshake required
- Best-effort delivery without delivery guarantees
- No ordering guarantees for packets
- No flow control mechanisms
- Minimal error detection (checksum only)
- Lower overhead and latency

**Use Cases**:
- TCP: Web services, email, file transfer, database connections
- UDP: DNS queries, video streaming, gaming, real-time applications

Our web service used TCP port 8080 because HTTP requires reliable, ordered communication between clients and servers.

## ECS Task Resource Control

Resource allocation in ECS is controlled through task definition parameters:

**CPU Allocation**:
- Specified in CPU units (1024 units = 1 vCPU)
- Can be shared across containers within a task
- Fargate supports specific CPU values: 256, 512, 1024, 2048, 4096 units

**Memory Allocation**:
- Specified in MB
- Must be compatible with CPU selection
- Containers within a task share the allocated memory pool

**Resource Constraints**:
- Hard limits prevent containers from exceeding allocations
- Resource contention handled at the task level
- Insufficient resources cause task launch failures

**Scaling Implications**:
- Larger allocations increase cost but improve performance
- Smaller allocations enable higher task density on underlying infrastructure
- Resource sizing requires understanding application requirements and performance characteristics

Our task used minimal resources (0.25 vCPU, 0.5 GB memory) appropriate for a simple web service, demonstrating how fine-grained resource control enables cost optimization in containerized deployments.