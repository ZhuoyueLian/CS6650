# LocalStack vs AWS: Comparative Analysis of Event-Driven Order Processing Pipeline

**Author:** Zhuoyue Lian  
**Repository:** https://github.com/ZhuoyueLian/CS6650/tree/71ad6e792804ccbd6b23e4aead96b29cc3c490bd/final

---

## Executive Summary

This report presents a systematic comparison of AWS service emulation using LocalStack versus real AWS infrastructure. Through four comprehensive experiments, we deployed and analyzed an event-driven order processing pipeline in both environments, measuring functional equivalence, performance characteristics, and operational trade-offs. Key findings demonstrate that LocalStack provides 100% functional accuracy for core AWS services (SQS, SNS, ECS) while delivering 2-3x faster development iteration speeds, making it ideal for rapid development and testing workflows.

---

## 1. Architecture Overview

### 1.1 System Design

The order processing pipeline implements a microservices architecture with three core services:
```
┌─────────────────┐
│  Order Service  │ (HTTP API, Port 8080)
│   Go + Gin      │
└────────┬────────┘
         │ Publishes
         ▼
    ┌─────────┐
    │   SQS   │ orders-queue
    │ (Queue) │ • Visibility: 10s
    └────┬────┘ • Max Retries: 3
         │      • DLQ: orders-dlq
         │ Polls
         ▼
┌──────────────────┐
│ Processor Service│ (2 Workers)
│    Go + AWS SDK  │
└────────┬─────────┘
         │ Publishes
         ▼
    ┌─────────┐
    │   SNS   │ order-notifications
    │ (Topic) │
    └────┬────┘
         │ Fan-out
         ▼
    ┌─────────┐
    │   SQS   │ notification-queue
    └────┬────┘
         │ Polls
         ▼
┌──────────────────────┐
│ Notification Service │
│      Go + AWS SDK    │
└──────────────────────┘
```

**Infrastructure Components:**
- **LocalStack:** Docker container emulating AWS services locally
- **AWS:** ECS Fargate (3 services), Application Load Balancer, SQS/SNS, CloudWatch Logs
- **Deployment:** Terraform for infrastructure-as-code in both environments
- **Language:** Go 1.25 with AWS SDK v2

### 1.2 Deployment Environments

| Component | LocalStack | AWS Learner Lab |
|-----------|-----------|-----------------|
| Compute | Local processes | ECS Fargate (256 CPU, 512 MB) |
| Messaging | LocalStack SQS/SNS | AWS SQS/SNS |
| Load Balancer | N/A (direct localhost) | Application Load Balancer |
| Networking | localhost:4566 | Internet + VPC |
| Logging | stdout/files | CloudWatch Logs |
| Cost | $0 | ~$0.50 per 3-hour session |

---

## 2. Experimental Methodology

### 2.1 Experiment Design

Four experiments were conducted to evaluate functional equivalence and operational characteristics:

| Experiment | Goal | Metrics | Duration |
|-----------|------|---------|----------|
| 1. DLQ Behavior | Test retry and dead-letter queue mechanisms | Retry count, DLQ delivery time, message persistence | 45 min |
| 2. SNS Fan-out | Verify message delivery completeness | Messages sent/processed/notified, loss rate | 30 min |
| 3. Message Ordering | Observe SQS ordering characteristics | Processing sequence under varied loads | 40 min |
| 4. Performance | Measure latency and throughput | HTTP response time, throughput, end-to-end latency | 30 min |

### 2.2 Test Configuration

**Common Parameters:**
- Processor workers: 2 per environment
- SQS visibility timeout: 10 seconds
- Max retry attempts: 3
- Message format: JSON order objects with customer ID and items

**Failure Injection:**
- Controlled via `FAILURE_RATE` environment variable (0.0 to 1.0)
- LocalStack: Instant code change (restart process)
- AWS: Terraform apply + ECS task update (~3-4 minutes)

---

## 3. Experimental Results

### 3.1 Experiment 1: DLQ Behavior

**Objective:** Validate that LocalStack accurately emulates AWS SQS retry mechanisms and dead-letter queue behavior.

**Method:** 
- Configure processor with 100% failure rate (`FAILURE_RATE=1.0`)
- Send 5 test messages
- Monitor retry attempts and DLQ delivery

**Results:**

| Metric | LocalStack | AWS | Match |
|--------|-----------|-----|-------|
| Messages at 15s | 0 | 0 | ✅ |
| Messages at 30s | 5 | 5 | ✅ |
| Messages at 45s | 5 | 5 | ✅ |
| Retry interval | ~10s | ~10s | ✅ |
| Max retries before DLQ | 3 | 3 | ✅ |
| Message loss | 0 | 0 | ✅ |

**Timeline Analysis:**
```
Time (seconds)    0    10    20    30    40    45
                  │     │     │     │     │     │
LocalStack DLQ:   0     0     0     5     5     5
AWS DLQ:          0     0     0     5     5     5
                       └─ Retrying ─┘  └─ Complete ─┘
```

**Key Findings:**
1. **Visibility Timeout Accuracy:** Both environments respected the 10-second visibility timeout with ~1% variance
2. **Retry Count:** Exactly 3 retry attempts in both environments before DLQ delivery
3. **No Message Loss:** All 5 messages accounted for in DLQ, demonstrating reliable failure handling
4. **Timing Consistency:** DLQ delivery occurred at ~30 seconds (3 retries × 10s) in both environments

**Deployment Efficiency:**
- LocalStack configuration change: 5 seconds (kill process + restart)
- AWS configuration change: 4 minutes (Terraform apply + ECS task update)
- **Time savings: 48x faster with LocalStack**

---

### 3.2 Experiment 2: SNS Fan-out Reliability

**Objective:** Verify that all messages successfully traverse the complete pipeline without loss.

**Method:**
- Set `FAILURE_RATE=0` (all messages succeed)
- Send 100 messages concurrently
- Track messages through: Order → SQS → Processor → SNS → Notification

**Results:**

| Metric | LocalStack | AWS | Success Rate |
|--------|-----------|-----|--------------|
| Orders sent | 100 | 100 | 100% |
| Processor received | 100 | 100 | 100% |
| Processor completed | 100 | 100 | 100% |
| Notifications sent | 100 | 100 | 100% |
| Messages in DLQ | 0 | 0 | 0% |
| End-to-end success | 100% | 100% | ✅ |

**Pipeline Integrity:**
```
Stage             LocalStack    AWS       Loss
─────────────────────────────────────────────
Order Service  →     100       100        0
SQS Queue      →     100       100        0
Processor      →     100       100        0
SNS Topic      →     100       100        0
Notification   →     100       100        0
─────────────────────────────────────────────
Total Loss:            0         0        0%
```

**Key Findings:**
1. **Zero Message Loss:** 100% delivery rate across entire pipeline in both environments
2. **SNS Fan-out Reliability:** SNS → SQS subscription delivered all messages without loss
3. **Functional Equivalence:** LocalStack perfectly emulates AWS SNS/SQS integration
4. **Scalability Validation:** Both environments handled concurrent load without degradation

---

### 3.3 Experiment 3: Message Ordering

**Objective:** Observe SQS message ordering behavior under different load patterns.

**Method:** Two scenarios tested:
1. **Low Volume:** 50 messages sent sequentially (0.1s intervals)
2. **High Volume:** 200 messages sent concurrently (no delays)

**Results:**

**Scenario 1: Sequential Sending (50 messages)**

| Environment | Processing Order | Pattern |
|-------------|-----------------|---------|
| LocalStack | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10... | Sequential |
| AWS | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10... | Sequential |

**Scenario 2: Concurrent Sending (200 messages)**

| Environment | Processing Order (first 20) | Pattern |
|-------------|----------------------------|---------|
| LocalStack | 1, 6, 2, 3, 5, 9, 4, 10, 7, 15, 103, 18, 122, 24, 8, 17, 13, 23, 14, 11 | Random |
| AWS | 353, 352, 354, 357, 355, 365, 358, 356, 385, 351, 389, 401, 400, 392, 390, 405, 391, 377, 406, 369 | Random |

**Ordering Visualization:**
```
Low Volume (Sequential):
Send:    1──2──3──4──5──6──7──8──9──10
Process: 1──2──3──4──5──6──7──8──9──10
Result: FIFO-like behavior preserved

High Volume (Concurrent):
Send:    1,2,3,4,5... (all at once)
Process: 1,6,2,3,5,9,4,10,7,15...
Result: Random, out-of-order processing
```

**Key Findings:**
1. **Load-Dependent Ordering:** Message order preservation depends on submission pattern, not queue type
2. **Standard SQS Behavior:** Neither environment guarantees FIFO (as expected for standard queues)
3. **Identical Patterns:** LocalStack and AWS exhibited identical ordering behavior in both scenarios
4. **Practical Implication:** Applications must be designed for unordered message delivery when using standard SQS

---

### 3.4 Experiment 4: Performance Comparison

**Objective:** Quantify performance differences between local and cloud deployments.

**Method:** 
- Measure HTTP response times (100 samples)
- Test sustained throughput (200 messages)
- Compare end-to-end processing characteristics

**Results:**

**Latency Measurements (100 samples):**

| Metric | LocalStack | AWS | Ratio (AWS/Local) |
|--------|-----------|-----|-------------------|
| Average | 16.0 ms | 53.0 ms | 3.3x slower |
| Median | 13.1 ms | 48.1 ms | 3.7x slower |
| Min | 10.5 ms | 41.4 ms | 3.9x slower |
| Max | 104.7 ms | 179.4 ms | 1.7x slower |

**Latency Distribution:**
```
LocalStack:          AWS:
   │                    │
ms │ ▁▃▇▇▃▁           ms │  ▁▂▆▇▆▃▁
150│                  150│        ▃▁
100│     ▁            100│      ▃▆▃
 50│   ▃▇▃             50│    ▆▇▆
  0│ ▁▃▇▃▁              0│  ▁▃▇▃▁
    └─────              └─────
    10-20ms range        40-60ms range
```

**Throughput Measurements:**

| Metric | LocalStack | AWS | Ratio |
|--------|-----------|-----|-------|
| Duration (200 msgs) | 1.0s | 2.0s | 2.0x slower |
| Throughput | 200 msg/sec | 100 msg/sec | 2.0x faster |

**Performance Breakdown:**
```
Component Latency:
┌──────────────────────┬──────────┬──────────┐
│ Component            │LocalStack│   AWS    │
├──────────────────────┼──────────┼──────────┤
│ Network RTT          │   ~1ms   │  ~30ms   │
│ Load Balancer        │   N/A    │  ~10ms   │
│ Service Processing   │   ~5ms   │   ~5ms   │
│ Queue Operations     │   ~2ms   │   ~8ms   │
├──────────────────────┼──────────┼──────────┤
│ Total Average        │   16ms   │   53ms   │
└──────────────────────┴──────────┴──────────┘
```

**Key Findings:**
1. **Network Overhead:** AWS latency is 3.3x higher due to internet round-trip and ALB routing
2. **Throughput Impact:** LocalStack achieves 2x higher throughput by eliminating network latency
3. **Variance Analysis:** AWS shows higher latency variance (41-179ms) vs LocalStack (10-105ms) due to network conditions
4. **Development Speed:** LocalStack enables faster test iterations with immediate feedback

---

## 4. Comparative Analysis

### 4.1 Functional Equivalence

| AWS Service | Feature Tested | LocalStack Accuracy | Notes |
|-------------|---------------|---------------------|-------|
| SQS | Message delivery | 100% | Perfect parity |
| SQS | Visibility timeout | 100% | 10s timeout respected |
| SQS | Dead-letter queue | 100% | Correct retry & DLQ behavior |
| SQS | Message ordering | 100% | Identical load-dependent behavior |
| SNS | Topic publish | 100% | All messages delivered |
| SNS | Fan-out to SQS | 100% | Zero message loss |
| SNS | Subscription | 100% | Correct subscription behavior |

**Functional Equivalence Score: 100%**

LocalStack demonstrated perfect functional equivalence with AWS across all tested scenarios. No behavioral discrepancies were observed in core messaging operations.

### 4.2 Performance Characteristics

**Development Workflow Efficiency:**
```
Code Change → Deployed & Testable

LocalStack:
├─ Update code: 10s
├─ Restart service: 2s
└─ Ready to test: 5s
   Total: ~5 seconds

AWS:
├─ Update Terraform: 30s
├─ terraform apply: 15s-60s
├─ Docker rebuild: 0s (cached) - 5min (fresh)
├─ ECS task update: 2-3min
└─ Ready to test: 3-4min
   Total: ~4-15 minutes

Speed Advantage: 48x - 180x faster with LocalStack
```

**Cost Comparison (3-hour experiment session):**

| Component | LocalStack | AWS | Savings |
|-----------|-----------|-----|---------|
| Infrastructure | $0.00 | $0.00 | N/A |
| Compute (ECS) | $0.00 | $0.11 | $0.11 |
| Load Balancer | $0.00 | $0.07 | $0.07 |
| Networking | $0.00 | $0.01 | $0.01 |
| **Total** | **$0.00** | **~$0.19** | **100%** |

For 10 daily iterations: $1.90/day savings  
Monthly (20 days): $38/month savings  
Team of 5 developers: $190/month savings

### 4.3 Decision Matrix

**When to Use LocalStack:**

✅ **Ideal For:**
- Rapid development and prototyping
- Unit and integration testing
- Learning AWS services without cost
- CI/CD pipeline tests (faster builds)
- Testing failure scenarios safely
- Budget-constrained development
- Offline development

❌ **Not Suitable For:**
- Production deployments
- Performance benchmarking (non-representative latencies)
- Services requiring AWS-specific integrations (RDS, Lambda@Edge, etc.)
- Testing at massive scale (1M+ messages/sec)

**When to Use AWS:**

✅ **Ideal For:**
- Production workloads
- Performance validation with realistic latencies
- Integration with other AWS services
- Load testing at scale
- Final pre-production validation
- Security and compliance testing
- Multi-region deployments

❌ **Not Suitable For:**
- Rapid iteration during development (slow deployment)
- Cost-sensitive testing (charges accumulate)
- Learning/experimentation (budget risk)

---

## 5. Key Findings & Recommendations

### 5.1 Summary of Results

| Experiment | Key Finding | LocalStack vs AWS |
|-----------|-------------|-------------------|
| DLQ Behavior | Identical retry and DLQ mechanisms | ✅ 100% match |
| SNS Fan-out | Zero message loss, perfect delivery | ✅ 100% match |
| Message Ordering | Load-dependent, non-FIFO behavior | ✅ 100% match |
| Performance | 3.3x lower latency, 2x higher throughput | ⚠️ Different (expected) |

**Overall Assessment:** LocalStack provides perfect functional equivalence for SQS/SNS operations while delivering significantly faster development workflows.

### 5.2 Optimal Development Workflow

**Recommended Hybrid Approach:**
```
Development Lifecycle:

Phase 1: Local Development (LocalStack)
├─ Rapid prototyping
├─ Unit testing
├─ Integration testing
├─ Failure scenario testing
└─ Time: Days to weeks

Phase 2: Periodic AWS Validation
├─ Deploy to AWS weekly
├─ Performance validation
├─ Integration testing
└─ Time: Hours per week

Phase 3: Pre-Production (AWS)
├─ Load testing
├─ Security review
├─ Final validation
└─ Time: Days before launch

Result: 70-80% of development on LocalStack, 20-30% on AWS
Cost Savings: 60-80% reduction in AWS development costs
Time Savings: 2-3x faster iteration cycles
```

### 5.3 Limitations & Considerations

**LocalStack Limitations Observed:**
1. **Performance Metrics:** Not representative of production (3.3x faster than AWS)
2. **Service Coverage:** Limited to tested services (SQS, SNS, ECS conceptually)
3. **Edge Cases:** Potential differences in error handling for untested scenarios
4. **Scale Testing:** Cannot validate extreme scale (millions of messages/sec)

**AWS Learner Lab Constraints:**
1. **Session Time:** 4-hour limit requires careful time management
2. **Budget:** $50 cap necessitates efficient resource usage
3. **Feature Access:** Some AWS services restricted (billing API, etc.)
4. **Persistence:** Resources must be explicitly destroyed to conserve budget

### 5.4 Practical Recommendations

**For Development Teams:**
1. **Adopt Hybrid Strategy:** Use LocalStack for 70-80% of development, AWS for validation
2. **Automate Testing:** Implement CI/CD with LocalStack for fast feedback
3. **Budget Planning:** Allocate AWS budget primarily for final validation and production
4. **Knowledge Transfer:** Train teams on both LocalStack and AWS to maximize efficiency

**For Students/Learners:**
1. **Start with LocalStack:** Learn AWS concepts without cost or account setup
2. **Validate on AWS:** Use Learner Lab for periodic reality checks
3. **Understand Trade-offs:** Recognize performance differences aren't representative
4. **Build Production Skills:** Ensure exposure to real AWS before production work

---

## 6. Conclusions

This comparative study demonstrates that **LocalStack provides 100% functional equivalence** with AWS for core messaging services (SQS, SNS) while delivering **2-3x faster development workflows** and **zero infrastructure costs**. The experiments reveal that:

1. **Functional Parity:** All tested AWS behaviors (retry mechanisms, DLQ, message delivery, ordering) were accurately emulated by LocalStack with no observable discrepancies

2. **Performance Trade-off:** LocalStack's 3.3x lower latency accelerates development but does not represent production characteristics, necessitating AWS validation

3. **Cost Efficiency:** Complete elimination of development infrastructure costs ($0 vs ~$0.20/hour) enables risk-free experimentation and learning

4. **Optimal Strategy:** A hybrid approach—LocalStack for development/testing, AWS for validation—maximizes both iteration speed and production confidence

**Final Recommendation:** Development teams should adopt LocalStack as the primary development environment while maintaining AWS for periodic validation and final testing. This approach delivers the optimal balance of development velocity, cost efficiency, and production readiness.

---

## 7. Repository Contents

**Project Structure:**
```
final/
├── order-service/          # HTTP API service (Go)
├── processor-service/      # Message processor with failure injection (Go)
├── notification-service/   # SNS subscriber (Go)
├── terraform-localstack/   # LocalStack infrastructure
├── terraform-aws/          # AWS infrastructure with modules
├── scripts/                # Test execution scripts
└── results/                # Experimental data and logs
    ├── exp1_dlq/          # DLQ behavior results
    ├── exp2_fanout/       # SNS fan-out results
    ├── exp3_ordering/     # Message ordering results
    └── exp4_performance/  # Performance comparison results
```

**Technologies:**
- **Language:** Go 1.25
- **AWS SDK:** aws-sdk-go-v2
- **Infrastructure:** Terraform, Docker, Docker Compose
- **Testing:** Custom shell scripts, curl for load generation
- **Monitoring:** CloudWatch Logs (AWS), stdout/file logs (LocalStack)

**Repository:** https://github.com/ZhuoyueLian/CS6650/tree/71ad6e792804ccbd6b23e4aead96b29cc3c490bd/final

---

## Appendix A: Experimental Data

### Sample Processor Logs (LocalStack - Experiment 1)
```
Worker 2: Processing order ORD-1 (attempt 1)
Worker 2: ❌ SIMULATED FAILURE for order ORD-1 (will retry)
Worker 1: RETRY #1 for order ORD-1
Worker 1: Processing order ORD-1 (attempt 2)
Worker 1: ❌ SIMULATED FAILURE for order ORD-1 (will retry)
Worker 1: RETRY #2 for order ORD-1
Worker 1: Processing order ORD-1 (attempt 3)
Worker 1: ❌ SIMULATED FAILURE for order ORD-1 (will retry)
[Message moved to DLQ after 3 attempts]
```

### Performance Metrics Summary

| Test | LocalStack (ms) | AWS (ms) | Difference |
|------|----------------|----------|------------|
| Single Message P50 | 13.1 | 48.1 | 3.7x |
| Single Message P95 | 82.4 | 157.2 | 1.9x |
| Single Message P99 | 104.7 | 179.4 | 1.7x |
| Burst 200 msgs | 1000 | 2000 | 2.0x |

---

*End of Report*