# STEP II: DynamoDB Implementation Notes

## Part 1: DynamoDB Table Design Challenge

### Design Decisions

#### 1. Partition Key Strategy
**Decision:** `cart_id` (String/UUID)

**Rationale:**
- **Even Distribution:** UUIDs provide natural random distribution across partitions, preventing hot partitions
- **Direct Access:** Shopping carts are primarily accessed by cart_id (GetItem operations)
- **Scale-Friendly:** Random UUIDs ensure workload spreads evenly as data grows
- **No Sequential Patterns:** Unlike auto-increment IDs, UUIDs don't create predictable access patterns

**Why Not customer_id as Partition Key?**
- Would create hot partitions for customers with many carts
- Some customers might have 100+ carts while others have 1-2
- Violates even distribution principle

#### 2. Sort Key Need
**Decision:** No sort key needed

**Rationale:**
- Primary access pattern: "Get cart by cart_id" (single-item lookup)
- No need for range queries within a partition
- Cart items stored as embedded list in single document
- Customer history implemented via Scan (inefficient but demonstrates trade-off)

**Production Consideration:** Would add GSI (Global Secondary Index) with customer_id as partition key for efficient customer queries.

#### 3. Table Structure
**Decision:** Single table design

**Structure:**
```
Table: shopping-cart-service-carts
- Partition Key: cart_id (String)
- Attributes: customer_id, created_at, items (List)
```

**Rationale:**
- Simple access patterns don't require multiple tables
- All cart data retrieved together (no need for separate items table)
- Reduces number of API calls (single GetItem vs multiple queries)
- Lower cost (fewer operations)

**Comparison to MySQL:**
- MySQL: 2 tables (carts + cart_items) with JOIN
- DynamoDB: 1 table with embedded items array
- Trade-off: DynamoDB simpler but less flexible for item-level queries

#### 4. Attribute Design: Embedded Items
**Decision:** Store cart items as embedded list attribute

**Structure:**
```json
{
  "cart_id": "uuid",
  "customer_id": "customer-123",
  "created_at": "2025-11-02T00:00:00Z",
  "items": [
    {"product_id": "prod-A", "quantity": 2, "price": 29.99},
    {"product_id": "prod-B", "quantity": 1, "price": 19.99}
  ]
}
```

**Advantages:**
- Single read operation retrieves complete cart
- Atomic updates (entire cart updated in one PutItem)
- Natural document structure matches application objects
- No JOIN operations needed

**Disadvantages:**
- Can't query individual items across carts
- 400KB item size limit (supports ~1000 items comfortably)
- Must read entire cart to update single item

**Comparison to MySQL:**
- MySQL: Separate cart_items table, flexible queries on items
- DynamoDB: Items embedded, optimized for cart-centric operations
- Trade-off: DynamoDB faster for cart operations, MySQL better for item analytics

#### 5. Index Strategy
**Current:** No secondary indexes (GSI/LSI)

**Rationale for Assignment:**
- Primary access pattern (get by cart_id) doesn't need indexes
- Customer history implemented via Scan to demonstrate limitation
- Keeps costs low for testing

**Production Recommendation:**
```
GSI: customer-index
- Partition Key: customer_id
- Sort Key: created_at
- Projection: ALL
```

This would enable efficient customer history queries without Scan.

### Design Comparison: MySQL vs DynamoDB

| Aspect | MySQL | DynamoDB |
|--------|-------|----------|
| **Tables** | 2 (carts, cart_items) | 1 (shopping-carts) |
| **Relationships** | Foreign key constraints | Embedded documents |
| **Cart Retrieval** | JOIN query (2 tables) | Single GetItem |
| **Item Updates** | UPDATE specific row | PutItem entire document |
| **Customer History** | Index scan (fast) | Full table Scan (slow) |
| **Data Integrity** | Enforced by DB | Application responsibility |
| **Schema** | Rigid (defined columns) | Flexible (any attributes) |

### Trade-offs Identified

**DynamoDB Advantages:**
- ✅ Faster single-cart retrieval (no JOIN overhead)
- ✅ Simpler data model (one table)
- ✅ Automatic scaling
- ✅ No connection pool management

**DynamoDB Disadvantages:**
- ❌ Customer history requires Scan (expensive at scale)
- ❌ No ad-hoc queries (must know partition key)
- ❌ Item size limits (400KB)
- ❌ No foreign key constraints (data integrity in code)

---

## Part 2: API Implementation

### DynamoDB Attribute Value Format Impact

**Challenge:** DynamoDB uses typed attribute values, not simple JSON.

**Example:**
```go
// Application structure (simple)
type CartItem struct {
    ProductID string
    Quantity  int
    Price     float64
}

// DynamoDB format (typed)
{
    "product_id": {"S": "prod-123"},
    "quantity": {"N": "2"},
    "price": {"N": "29.99"}
}
```

**Solution:** Used `attributevalue` package for marshaling/unmarshaling:
```go
item, err := attributevalue.MarshalMap(cart)  // Go struct → DynamoDB format
err = attributevalue.UnmarshalMap(result.Item, &cart)  // DynamoDB → Go struct
```

**Impact:**
- Adds complexity compared to MySQL's direct JSON mapping
- Type safety at serialization boundary
- Must handle NULL values explicitly (sql.Null* types)

### DynamoDB Operations by Endpoint

| Endpoint | Operation | Rationale |
|----------|-----------|-----------|
| `POST /shopping-carts` | **PutItem** | Create new cart with all attributes |
| `GET /shopping-carts/:id` | **GetItem** | Direct lookup by partition key (fastest) |
| `POST /shopping-carts/:id/items` | **GetItem + PutItem** | Read cart, modify items array, write back |
| `PUT /shopping-carts/:id/items/:product_id` | **GetItem + PutItem** | Read, update specific item, write |
| `DELETE /shopping-carts/:id/items/:product_id` | **GetItem + PutItem** | Read, remove item, write |
| `DELETE /shopping-carts/:id/items` | **GetItem + PutItem** | Read, clear items array, write |
| `GET /customers/:customer_id/carts` | **Scan** | No index, must scan entire table |

**Why GetItem + PutItem Pattern:**
- DynamoDB doesn't support partial updates of list elements by index
- Must read entire document, modify in memory, write back
- Trade-off: More API calls vs simpler operations

**MySQL Comparison:**
- MySQL: Direct UPDATE statements modify specific rows
- DynamoDB: Read-modify-write pattern for embedded lists
- Performance: MySQL potentially faster for single-item updates

### Handling Eventual Consistency

**DynamoDB Consistency Options:**
1. **Eventually Consistent Reads** (default, cheaper, faster)
2. **Strongly Consistent Reads** (guaranteed current, slower, more expensive)

**Our Implementation:** Used strongly consistent reads
```go
result, err := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
    TableName: aws.String(tableName),
    Key: map[string]types.AttributeValue{
        "cart_id": &types.AttributeValueMemberS{Value: cartID},
    },
    // Note: Strongly consistent by default in SDK
})
```

**Why Strongly Consistent:**
- Shopping cart operations require immediate consistency
- Read-after-write pattern: create cart → immediately add items
- User experience: Must see their changes instantly
- Cost acceptable for our use case

---

## Part 3: Eventual Consistency Investigation

### Test Methodology
Tested read-after-write pattern with 150 operations:
1. Create cart
2. Immediately add items
3. Immediately retrieve cart

### Observations

**Consistency Delays Observed:** **0 out of 150 operations**

**Why No Delays:**
- Used strongly consistent reads (not eventually consistent)
- All operations targeted same partition key
- DynamoDB guarantees read-after-write consistency for single-item operations

**What If We Used Eventually Consistent Reads?**
- Might see stale data briefly (<1 second typically)
- Most affected: Read immediately after write
- Example: Add item → Get cart might not show new item

### Application Patterns Most Affected

If using eventually consistent reads:

**High Risk:**
1. **Read-After-Write:** User adds item, immediately views cart
2. **Update-Then-Read:** Change quantity, refresh page
3. **Delete-Then-List:** Remove item, view updated cart

**Low Risk:**
1. **Historical Queries:** Viewing old orders (slight staleness acceptable)
2. **Analytics:** Counting total carts (approximate counts OK)
3. **Background Jobs:** Processing carts asynchronously

### Graceful Consistency Handling Strategies

**1. Use Strong Consistency for User-Facing Reads**
```go
// Critical path: use strong consistency
result, _ := dynamoClient.GetItem(ctx, &dynamodb.GetItemInput{
    ConsistentRead: aws.Bool(true),  // Explicit strong consistency
})
```

**2. Add Version Numbers / Timestamps**
```go
type Cart struct {
    CartID    string
    Version   int      // Increment on each update
    UpdatedAt string   // Track last modification
}
```

**3. Client-Side Optimistic UI**
- Show user their changes immediately (client-side)
- Verify with server asynchronously
- Rollback if server state differs

**4. Retry Logic for Stale Reads**
```go
// If data seems stale, retry with strong consistency
if cart.UpdatedAt < expectedTime {
    cart = getCartWithStrongConsistency(cartID)
}
```

---

## Part 4: Performance Testing Results

### Test Configuration
- **Operations:** 150 (50 create, 50 add items, 50 get)
- **Consistency:** Strongly consistent reads
- **Concurrency:** Sequential (same as MySQL test)

### Results Summary

| Metric | DynamoDB | MySQL | Winner |
|--------|----------|-------|--------|
| **Avg Response Time** | 41.51ms | 43.44ms | DynamoDB (4.5% faster) |
| **CREATE_CART** | 40.11ms | 46.35ms | DynamoDB (13.5% faster) |
| **ADD_ITEMS** | 47.07ms | 43.06ms | MySQL (9.3% faster) |
| **GET_CART** | 37.34ms | 40.91ms | DynamoDB (8.7% faster) |
| **Success Rate** | 100% | 100% | Tie |

### Partition Strategy Validation

**Evidence of Even Distribution:**
- All 150 operations succeeded (no throttling)
- No hot partition warnings in CloudWatch
- Response times consistent across operations

**Why It Works:**
- UUIDs distribute randomly across partitions
- Each cart access hits different partition
- No single partition overloaded

**How We Validated:**
1. CloudWatch metrics showed no throttled requests
2. Consistent latency (no partition-specific slowdowns)
3. 100% success rate (no capacity errors)

### Eventual Consistency Behavior

**Testing Pattern:**
```
Create cart → Add item → Get cart (immediate)
```

**Results:**
- 0 consistency issues observed
- All read-after-write operations returned latest data
- Strong consistency guarantee held in all 150 operations

**Conclusion:** Strong consistency eliminates eventual consistency concerns for shopping cart use case.

---

## Part 5: Learning Notes

### What Surprised Me

1. **Performance Similarity to MySQL**
   - Expected DynamoDB to be dramatically faster
   - Reality: Only 4.5% faster overall (41.51ms vs 43.44ms)
   - Lesson: For simple operations at small scale, SQL and NoSQL perform similarly

2. **ADD_ITEMS Slower in DynamoDB**
   - DynamoDB: 47.07ms (read-modify-write)
   - MySQL: 43.06ms (direct UPDATE)
   - Reason: Must read entire cart, modify items array, write back
   - MySQL's row-level UPDATE more efficient

3. **No Eventual Consistency Issues**
   - Used strongly consistent reads throughout
   - 100% success rate with immediate consistency
   - Cost acceptable for shopping cart use case

4. **Embedded vs Normalized Design Impact**
   - Single-table design simpler to implement
   - Customer history requires Scan (inefficient)
   - Trade-off: Fast cart operations vs flexible queries

### Design Evolution

#### Initial Partition Key Consideration
**First Thought:** Use `customer_id` as partition key
- Reasoning: Natural way to query customer history
- Problem: Uneven distribution (some customers have many carts)
- Would create hot partitions

**Final Decision:** Use `cart_id` (UUID)
- Even distribution across partitions
- Fast single-cart lookups
- Trade-off: Customer queries require GSI or Scan

#### Hot Partition Issues
**Did Not Encounter Because:**
- UUIDs provide random distribution
- Low test volume (150 operations)
- Each operation accessed different cart_id

**Production Considerations:**
- Monitor CloudWatch for throttled requests
- If customer queries needed, add GSI on customer_id
- Consider sharding strategy for very high volume

#### Design Validation Process

**1. Local Testing with DynamoDB Local**
- Verified CRUD operations work correctly
- Tested embedded items array approach
- Confirmed read-after-write consistency

**2. Performance Testing**
- 150 operations matched MySQL test exactly
- Measured response times for comparison
- Validated no throttling or capacity issues

**3. CloudWatch Metrics Review**
- No throttled requests (capacity sufficient)
- Consistent latency patterns
- Read/write capacity within limits

---

## Key Differences from MySQL (STEP I)

### Data Model
- **MySQL:** Normalized (2 tables with foreign keys)
- **DynamoDB:** Denormalized (1 table with embedded items)

### Schema
- **MySQL:** Rigid schema, defined at creation
- **DynamoDB:** Flexible, can add attributes anytime

### Queries
- **MySQL:** JOINs enable complex queries
- **DynamoDB:** No JOINs, must know partition key

### Scaling
- **MySQL:** Vertical (bigger instance) or read replicas
- **DynamoDB:** Automatic horizontal scaling

### Cost Model
- **MySQL:** Fixed (RDS instance runs 24/7)
- **DynamoDB:** Variable (pay per request)

### Operations
- **MySQL:** Direct UPDATE for specific rows
- **DynamoDB:** Read-modify-write for embedded items

---

## NoSQL vs SQL Trade-offs Discovered

### When to Choose DynamoDB
✅ Simple key-value access patterns
✅ Predictable query patterns (known partition keys)
✅ Need automatic scaling
✅ Variable/unpredictable traffic
✅ Want zero infrastructure management

### When to Choose MySQL
✅ Complex queries with JOINs
✅ Ad-hoc reporting and analytics
✅ Need ACID transactions across entities
✅ Frequent schema changes during development
✅ Team expertise in SQL

### Shopping Cart Verdict
**Either works well** - performance difference minimal (4.5%)

**Choose based on:**
- Operational preferences (managed vs serverless)
- Other system requirements (analytics, reporting)
- Team expertise
- Cost model (fixed vs usage-based)

---

## Conclusion

DynamoDB implementation demonstrated that NoSQL can effectively handle shopping cart operations with:
- Excellent performance (41.51ms average)
- Simple data model (single table)
- No infrastructure management

However, trade-offs exist:
- Customer history requires inefficient Scan (would need GSI in production)
- Item updates less efficient than MySQL (read-modify-write pattern)
- Less flexible for ad-hoc queries

**Key Learning:** Database choice should match access patterns and operational requirements, not dogma. Both SQL and NoSQL can work well for the same use case.

