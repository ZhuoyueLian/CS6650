# STEP III: Database Comparison & Analysis

## Part 0: Data Verification ✓

**Verification Status:**
- MySQL test results: 150 operations ✓
- DynamoDB test results: 150 operations ✓
- Combined results file created: `test-results/combined_results.json` ✓

---

## Part 1: Performance Comparison Table

### Overall Performance Metrics

| Metric | MySQL | DynamoDB | Winner | Margin |
|--------|-------|----------|--------|--------|
| Avg Response Time (ms) | 43.44 | 41.51 | **DynamoDB** | 4.5% |
| P50 Response Time (ms) | 40.63 | 37.71 | **DynamoDB** | 7.2% |
| P95 Response Time (ms) | 53.09 | 60.02 | **MySQL** | 13.0% |
| P99 Response Time (ms) | 117.74 | 85.92 | **DynamoDB** | 27.0% |
| Success Rate (%) | 100.00 | 100.00 | **Tie** | 0.00% |
| Total Operations | 150 | 150 | - | - |

**Data Source:** `test-results/combined_results.json`

### Operation-Specific Breakdown

| Operation | MySQL Avg (ms) | DynamoDB Avg (ms) | Faster By |
|-----------|----------------|-------------------|-----------|
| CREATE_CART | 46.35 | 40.11 | **DynamoDB** (6.24ms, 13.5%) |
| ADD_ITEMS | 43.06 | 47.07 | **MySQL** (4.01ms, 9.3%) |
| GET_CART | 40.91 | 37.34 | **DynamoDB** (3.57ms, 8.7%) |

---

## Part 2: Consistency Model Impact Assessment

### ACID vs Eventual Consistency

**MySQL (ACID):**
- Strong consistency guarantees on all operations
- Immediate consistency after writes
- No observed consistency delays in testing
- All read-after-write operations returned correct data immediately

**DynamoDB (Eventual Consistency):**
- By default uses eventual consistency for reads
- We used strongly consistent reads (GetItem) in our implementation
- No consistency issues observed during testing with strongly consistent reads
- Read-after-write pattern worked correctly 100% of the time

**Observed Behavior:**
- Test Pattern: Create cart → immediately add item → immediately retrieve cart
- MySQL: 100% consistency (as expected with ACID)
- DynamoDB: 100% consistency (using strongly consistent reads)
- **No eventual consistency delays observed** with our access patterns

**User Experience Implications:**
- For shopping cart use case: Both provide acceptable consistency
- MySQL guarantees immediate consistency by design
- DynamoDB can match this with strongly consistent read option (at slightly higher cost)
- If we used eventually consistent reads, some operations might see stale data briefly

---

## Part 3: Resource Efficiency Analysis

### Resource Utilization Patterns

**MySQL (RDS):**
- **Provisioned Resources:** db.t3.micro (2 vCPU, 1GB RAM) running continuously
- **Connection Management:** Requires connection pooling (25 max, 5 idle configured)
- **Observed CPU:** ~3.67% average during testing
- **Database Connections:** 2 connections maintained by ECS tasks
- **Predictability:** Fixed cost regardless of usage
- **Scaling:** Requires manual intervention or pre-configured read replicas

**DynamoDB:**
- **Provisioned Resources:** Serverless, pay-per-request billing mode
- **Connection Management:** HTTP-based API, no persistent connections needed
- **Auto-scaling:** Handles traffic spikes automatically
- **Predictability:** Cost varies with usage (reads/writes)
- **Scaling:** Automatic and instant, no configuration needed

**Capacity Planning Implications:**
- **MySQL:** Need to size instance for peak load, pay for idle capacity
- **DynamoDB:** Only pay for actual operations, no idle costs
- **MySQL:** Scaling requires downtime or complex read replica setup
- **DynamoDB:** Scales infinitely without intervention

---

## Part 4: Real-World Scenario Recommendations

### Scenario A: Startup MVP
**Context:** 100 users/day, 1 developer, limited budget, quick launch

**Recommendation:** **DynamoDB**

**Key Evidence:**
- Zero infrastructure management (41.51ms avg response time proves performance)
- No connection pool complexity to debug
- Pay only for actual usage (~$0.50/month for 100 users/day)
- MySQL would cost $15-20/month minimum (24/7 RDS instance)
- Faster time to market (no database tuning needed)

### Scenario B: Growing Business
**Context:** 10K users/day, 5 developers, moderate budget, feature expansion

**Recommendation:** **MySQL**

**Key Evidence:**
- Better ADD_ITEMS performance (43.06ms vs 47.07ms)
- Team can leverage SQL expertise for complex queries
- Predictable costs with reserved instances
- Rich ecosystem of tools (query analyzers, ORMs, migration tools)
- Better for complex reporting queries not in our test

### Scenario C: High-Traffic Events
**Context:** 50K normal, 1M spike users, revenue-critical, can invest in infrastructure

**Recommendation:** **DynamoDB**

**Key Evidence:**
- Automatic scaling handles 20x traffic spikes without configuration
- P99 latency better under load (85.92ms vs 117.74ms)
- No connection pool exhaustion issues
- MySQL would need complex read replica setup + load balancer
- DynamoDB handled our 150 operations with zero throttling

### Scenario D: Global Platform
**Context:** Millions of users, multi-region, 24/7 availability, enterprise requirements

**Recommendation:** **Hybrid (Both)**

**Key Evidence:**
- **DynamoDB for shopping carts:** Low latency globally (41.51ms avg), auto-replication
- **MySQL for order history:** Complex queries, ACID guarantees for financial data
- Use DynamoDB Global Tables for <50ms latency worldwide
- Use MySQL with read replicas for analytics and reporting
- Our test shows both meet performance requirements (both <50ms)

---

## Part 5: Evidence-Based Architecture Recommendations

### Shopping Cart Winner: **DynamoDB**

**Supporting Evidence:**
1. **Faster overall:** 41.51ms vs 43.44ms (4.5% improvement)
2. **Better CREATE performance:** 40.11ms vs 46.35ms (13.5% improvement)
3. **Better GET performance:** 37.34ms vs 40.91ms (8.7% improvement)
4. **Better P99 latency:** 85.92ms vs 117.74ms (27% improvement)
5. **Simpler architecture:** No connection pooling, no schema migrations

**When to Choose MySQL Instead:**
- Need complex multi-table JOINs for analytics
- Team strongly prefers SQL and has no NoSQL experience
- Existing MySQL infrastructure and expertise in place
- Need transaction spanning multiple entities (orders + inventory + shipping)
- Compliance requires on-premise database

### Polyglot Database Strategy

For a complete e-commerce system:

| Component | Database Choice | Reasoning |
|-----------|----------------|-----------|
| **Shopping Carts** | DynamoDB | Fast reads/writes (37-40ms), auto-scaling, session data |
| **User Sessions** | DynamoDB | TTL for auto-expiration, fast key-value lookups |
| **Product Catalog** | MySQL | Complex filtering, full-text search, relationships |
| **Order History** | MySQL | ACID transactions, complex queries, financial audit trail |
| **User Profiles** | DynamoDB | Simple CRUD, fast lookups by user_id |
| **Inventory** | MySQL | Strong consistency critical, complex queries |
| **Analytics** | MySQL | Complex aggregations, JOINs across tables |

**Rationale:**
- Use DynamoDB where speed and scale matter (hot path)
- Use MySQL where data relationships and consistency are critical
- Our tests prove both can meet <50ms requirement
- Choose based on access patterns, not arbitrary preferences

---

## Part 6: Learning Reflection

### What Surprised You?

1. **Performance Similarity:** Expected larger performance gap. Both achieved <50ms avg (MySQL: 43.44ms, DynamoDB: 41.51ms). Only 4.5% difference.

2. **MySQL P95 Performance:** MySQL had better P95 latency (53.09ms vs 60.02ms), suggesting more consistent performance under our test load.

3. **DynamoDB ADD_ITEMS Slower:** Expected DynamoDB to win all operations, but MySQL was 9.3% faster at ADD_ITEMS (43.06ms vs 47.07ms). Likely because our implementation does full document rewrites in DynamoDB vs efficient UPDATE in MySQL.

4. **No Consistency Issues:** Despite DynamoDB's eventual consistency model, using strongly consistent reads eliminated all consistency problems.

5. **Infrastructure Complexity:** RDS took 5-8 minutes to provision; DynamoDB table created in <30 seconds.

### What Failed Initially?

1. **MySQL Version Compatibility:** Initial attempt used MySQL 8.0.35 which wasn't available in us-west-2. Had to check available versions and switch to 8.0.39.

2. **Missing go.sum:** First Docker build failed because I forgot to run `go mod tidy` after creating go.mod. Build error was cryptic about cache keys.

3. **ALB Name Length:** DynamoDB ALB name exceeded 32-character AWS limit. Had to shorten "shopping-cart-service-dynamodb" to "shopping-cart-service-ddb".

4. **Unused Imports:** DynamoDB service had unused `strconv` import causing build failure. Forgot to remove helper function copied from MySQL version.

### Key Insights Gained

**When would you definitely choose MySQL?**
- Complex reporting queries requiring JOINs across multiple tables
- Strong ACID guarantees required (financial transactions)
- Team expertise is primarily in SQL
- Need rich ecosystem tools (Sequelize, ActiveRecord, query builders)
- Database relationships are central to the domain model

**When would you definitely choose DynamoDB?**
- Simple key-value or document access patterns (like shopping carts)
- Need automatic scaling for unpredictable traffic
- Global distribution required (multi-region <50ms latency)
- Want zero infrastructure management
- Access patterns known upfront and can be modeled efficiently

**What would you tell another student starting this assignment?**
1. **Design schema carefully first** - think through indexes and access patterns before coding
2. **Test locally before deploying** - Docker build errors easier to debug locally
3. **Check AWS service availability** - not all versions/services in all regions
4. **Document as you go** - easier than trying to remember details later
5. **Both databases can work well** - choice depends on specific requirements, not religion
6. **Keep tests identical** - only way to make fair comparison
7. **Pay attention to details** - name length limits, unused imports can waste hours

**How did hands-on implementation change your understanding?**
- **Before:** Thought NoSQL was always faster. **After:** Performance differences minimal for simple operations; architecture and access patterns matter more.
- **Before:** Feared eventual consistency. **After:** Strongly consistent reads in DynamoDB eliminate most concerns; understand when it matters.
- **Before:** Thought MySQL was "old and slow." **After:** Modern MySQL with proper indexes is very fast; our implementation achieved 43ms average.
- **Before:** Schema design seemed straightforward. **After:** Index strategy and foreign keys significantly impact performance; learned about trade-offs like INT vs BIGINT, normalized vs denormalized data.
- **Before:** Believed there's one "best" database. **After:** Each database has strengths; polyglot persistence makes sense for complex systems.

---

## CloudWatch Metrics Analysis

### DynamoDB Performance Metrics

**Read Operations:**
- **Peak Read Usage:** 0.833 units/second at ~21:55 (during test execution)
- **Read Throughput:** 100% capacity consumed during testing (efficient utilization)
- **Throttled Requests:** 0 (excellent - no capacity issues)
- **Successful Read Requests:** ~100 requests peak during test period

**Write Operations:**
- **Peak Write Usage:** 1.67 units/second at ~21:55 (during test execution)
- **Write Throughput:** 100% capacity consumed during testing
- **Throttled Requests:** 0 (no capacity constraints)

**Latency:**
- **Get Latency:** Peak ~36.8 milliseconds
- **Put Latency:** Peak ~18.9 milliseconds
- **Successful Write Requests:** ~100 requests during test

**Key Observations:**
1. ✅ **Zero throttling** - Pay-per-request mode handled our 150 operations perfectly
2. ✅ **Low latency** - Get operations under 40ms, Put operations under 20ms
3. ✅ **100% success rate** - No system errors, no user errors
4. ✅ **Efficient scaling** - Automatic capacity adjustment with no manual intervention
5. ✅ **Predictable performance** - Consistent latency throughout test period

### MySQL (RDS) Performance Metrics

**From Previous Screenshots:**
- **CPU Utilization:** ~3.67% average (very low, indicating over-provisioned)
- **Database Connections:** 2 active connections (from 2 ECS tasks)
- **CPU Credit Balance:** Increasing (db.t3.micro has excess capacity)
- **Burst Balance:** ~100% (minimal I/O usage)
- **Free Storage:** ~15GB available (plenty of headroom)

**Key Observations:**
1. ✅ **Low resource utilization** - Using only 3.67% CPU indicates right-sizing opportunity
2. ✅ **Stable connections** - Connection pooling working correctly (2 connections)
3. ✅ **Fast queries** - 43.44ms average response time with minimal resource usage
4. ⚠️ **Over-provisioned** - Could potentially downsize or use Aurora Serverless
5. ✅ **Consistent performance** - No CPU spikes or connection pool exhaustion

### Cost Implications from CloudWatch Data

**DynamoDB:**
- **Actual Usage:** ~150 operations in test
- **Estimated Cost:** $0.25 per million requests
- **Our Test Cost:** ~$0.000038 (essentially free)
- **Monthly at 10K ops/day:** ~$0.75/month

**MySQL RDS:**
- **Instance:** db.t3.micro running 24/7
- **Utilization:** 3.67% CPU (significantly under-utilized)
- **Cost:** ~$15/month for always-on instance
- **Efficiency:** Paying for 96% idle capacity

**Recommendation:** For low-traffic applications, DynamoDB's pay-per-request is more cost-effective. MySQL becomes competitive at higher sustained loads where the per-operation cost of DynamoDB exceeds the fixed RDS instance cost.

---

## Screenshots Reference

**MySQL CloudWatch Screenshots:**
- RDS CPU Utilization: 3.67% average
- Database Connections: 2 active
- CPU Credit Balance: Increasing
- Captured during test execution on Oct 28, 2025

**DynamoDB CloudWatch Screenshots:**
- Read Usage: 0.833 units/second peak
- Write Usage: 1.67 units/second peak
- Throttled Requests: 0 (no throttling)
- Successful Requests: ~100 reads, ~100 writes
- Get Latency: 36.8ms peak
- Put Latency: 18.9ms peak
- Captured during test execution on Oct 28, 2025

---

## Conclusion

Both MySQL and DynamoDB performed excellently for the shopping cart use case, with <50ms average response times and 100% success rates. DynamoDB showed a slight edge (4.5% faster overall) but MySQL demonstrated more consistent P95 performance. 

**The key learning:** Database selection should be driven by:
1. **Access patterns** (simple key-value vs complex queries)
2. **Scale requirements** (predictable vs unpredictable traffic)
3. **Team expertise** (SQL vs NoSQL familiarity)
4. **Operational preferences** (managed vs self-managed)
5. **Cost model** (fixed vs usage-based pricing)

Rather than declaring a single winner, the best approach is **polyglot persistence** - using the right database for each specific use case within a larger system.

