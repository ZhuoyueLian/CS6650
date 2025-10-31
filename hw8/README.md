# Homework 8: MySQL vs DynamoDB Comparison

## Assignment Completion Status

✅ **STEP I: MySQL Implementation** - Complete
- RDS MySQL database deployed with proper schema
- Shopping cart API with 3 endpoints implemented
- 150 operations tested (50 create, 50 add items, 50 get)
- Performance: 43.44ms average, 100% success rate
- Documentation: `docs/step1_mysql_notes.md`

✅ **STEP II: DynamoDB Implementation** - Complete
- DynamoDB table deployed with single-table design
- Identical shopping cart API implemented
- 150 operations tested with same methodology
- Performance: 41.51ms average, 100% success rate
- Same API specification as MySQL for fair comparison

✅ **STEP III: Database Comparison** - Complete
- Combined results file created and verified
- Performance analysis with statistical comparison
- Real-world scenario recommendations with evidence
- Learning reflections and insights documented
- CloudWatch metrics captured and analyzed
- Documentation: `docs/step3_comparison_report.md`

---

## Performance Results Summary

| Metric | MySQL | DynamoDB | Winner |
|--------|-------|----------|--------|
| Avg Response Time | 43.44ms | 41.51ms | DynamoDB (4.5% faster) |
| P99 Latency | 117.74ms | 85.92ms | DynamoDB (27% faster) |
| Success Rate | 100% | 100% | Tie |
| CREATE_CART | 46.35ms | 40.11ms | DynamoDB (13.5% faster) |
| ADD_ITEMS | 43.06ms | 47.07ms | MySQL (9.3% faster) |
| GET_CART | 40.91ms | 37.34ms | DynamoDB (8.7% faster) |

**Key Finding:** Both databases performed excellently (<50ms requirement). Choice should be based on access patterns, scale requirements, and operational preferences rather than raw performance.

---

## Project Structure
```
hw8/
├── README.md                           # This file
├── terraform/                          # Infrastructure as Code
│   ├── main.tf                        # Main configuration (RDS + DynamoDB)
│   ├── variables.tf                   # Configuration variables
│   ├── outputs.tf                     # Output values
│   └── modules/
│       ├── rds/                       # MySQL RDS module
│       ├── dynamodb/                  # DynamoDB module
│       ├── ecs/                       # ECS service module
│       ├── alb/                       # Load balancer module
│       └── network/                   # VPC/networking module
├── src/                               # MySQL shopping cart service (Go)
│   ├── main.go                        # MySQL implementation
│   ├── go.mod
│   ├── go.sum
│   └── Dockerfile
├── src-dynamodb/                      # DynamoDB shopping cart service (Go)
│   ├── main.go                        # DynamoDB implementation
│   ├── go.mod
│   ├── go.sum
│   └── Dockerfile
├── test-results/                      # Performance test results
│   ├── mysql_test_results.json        # MySQL 150 operations
│   ├── dynamodb_test_results.json     # DynamoDB 150 operations
│   └── combined_results.json          # Merged results for analysis
├── docs/                              # Documentation
│   ├── step1_mysql_notes.md          # MySQL implementation notes
│   ├── step3_comparison_report.md     # Comprehensive comparison
│   ├── performance_analysis.json      # Statistical analysis
│   └── screenshots/                   # CloudWatch metrics
├── test_mysql.py                      # MySQL load test script
├── test_dynamodb.py                   # DynamoDB load test script
└── analyze_results.py                 # Performance analysis script
```

---

## How to Run

### Prerequisites
- AWS Learner Lab access
- Terraform installed
- Docker installed
- Go 1.24 installed
- Python 3 with requests library

### Deploy Infrastructure
```bash
cd terraform

# Initialize Terraform
terraform init

# Deploy both MySQL and DynamoDB services
terraform apply

# Note the ALB URLs from outputs
```

### Run Performance Tests
```bash
# Test MySQL service
python3 test_mysql.py

# Test DynamoDB service  
python3 test_dynamodb.py

# Analyze and compare results
python3 analyze_results.py
```

### Cleanup
```bash
cd terraform
terraform destroy -auto-approve
```

---

## Key Learnings

1. **Performance is similar** - Both databases achieved <50ms average response times
2. **Access patterns matter** - DynamoDB excels at simple key-value, MySQL better for complex queries
3. **Operational complexity differs** - DynamoDB requires zero management, MySQL needs connection pooling and tuning
4. **Cost models diverge** - DynamoDB cheaper at low volume, MySQL cheaper at sustained high volume
5. **Polyglot persistence wins** - Use the right database for each use case

---

## Technologies Used

- **Languages:** Go (backend), Python (testing), HCL (Terraform)
- **Databases:** MySQL 8.0.39 (RDS), DynamoDB
- **Infrastructure:** AWS ECS (Fargate), ECR, ALB, VPC, CloudWatch
- **Tools:** Terraform, Docker, AWS CLI
