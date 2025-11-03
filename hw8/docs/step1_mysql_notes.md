# STEP I: MySQL Implementation Notes

## Database Schema Design

### Tables Created:
1. **carts table**
   - cart_id (INT, PRIMARY KEY, AUTO_INCREMENT)
   - customer_id (VARCHAR(255))
   - created_at (TIMESTAMP)
   - Index: idx_customer_id for fast customer lookups

2. **cart_items table**
   - item_id (INT, PRIMARY KEY, AUTO_INCREMENT)
   - cart_id (INT, FOREIGN KEY → carts)
   - product_id (VARCHAR(255))
   - quantity (INT)
   - price (DECIMAL(10,2))
   - Index: idx_cart_id for fast cart item lookups

### Design Decisions:

**Why Two Tables?**
- Normalized design prevents data duplication
- Supports multiple items per cart efficiently
- Foreign key constraint maintains referential integrity
- ON DELETE CASCADE automatically cleans up orphaned items

**Index Strategy:**
- Primary keys (cart_id, item_id) automatically indexed
- Added idx_customer_id for customer history queries
- Added idx_cart_id on cart_items for JOIN performance

**Key Strategy:**
- **Primary Keys**: AUTO_INCREMENT integers (cart_id, item_id) for performance
- **Foreign Keys**: cart_id in cart_items references carts(cart_id)
- **Constraints**: ON DELETE CASCADE automatically removes orphaned items
- **Unique Constraint**: (cart_id, product_id) prevents duplicate products per cart

**Transaction Design:**
- **Engine**: InnoDB for ACID compliance and row-level locking
- **Isolation Level**: REPEATABLE READ (MySQL default)
  - Prevents dirty reads and non-repeatable reads
  - Uses gap locking to prevent phantom reads
- **Concurrent Scenarios**:
  - Multiple users modifying different carts: No conflicts (different rows)
  - Same user adding items from different sessions: Row-level locks serialize access
  - Cart deletion while adding items: Foreign key constraint prevents orphans
- **Connection Pooling**: 25 max connections prevent resource exhaustion
- **Lock Duration**: Minimal - only during actual UPDATE/INSERT operations

## Schema Design Trade-offs and Considerations

### Current Design Decisions:
- **INT vs BIGINT**: Used INT for cart_id and item_id (sufficient for assignment scale)
  - **Production consideration**: BIGINT would be better for long-term scalability
  
- **No updated_at/deleted_at**: Simplified design for learning objectives
  - **Production consideration**: Would add these for audit trails and soft deletes
  
- **Denormalized cart_items**: Product info stored directly in cart_items
  - **Trade-off**: Faster queries (no JOINs) vs potential data duplication
  - **Production consideration**: Might split into cart_items + products tables if managing full catalog

### Why These Choices Work for This Assignment:
- Demonstrates core SQL concepts (tables, foreign keys, indexes, JOINs)
- Meets performance requirements
- Allows fair comparison with DynamoDB
- Focuses on SQL vs NoSQL learning objectives rather than perfect schema design

### What I Would Change for Production:
1. Use BIGINT for all primary keys
2. Add updated_at, deleted_at timestamps
3. Add cart status field (active, checked_out, abandoned)
4. Consider normalized product table if managing catalog
5. Add more comprehensive indexing strategy

## Performance Testing Results

**Test Configuration:**
- 150 operations (50 create, 50 add items, 50 get)
- Sequential execution
- Single region (us-west-2)

**Results:**
- **Success Rate**: 100% (150/150)
- **Average Response Time**: 43.44 ms
- **CREATE_CART**: 46.35 ms avg
- **ADD_ITEMS**: 43.06 ms avg
- **GET_CART**: 40.91 ms avg

**Performance exceeds requirements** (< 50ms average)

## Implementation Journey

### What Worked Well:
- Connection pooling configuration prevented connection exhaustion
- Schema design with proper indexes achieved sub-50ms queries
- Foreign key constraints maintained data integrity automatically
- ECS environment variables made DB configuration simple

### Issues Discovered:
1. **Initial Issue**: MySQL version 8.0.35 not available in us-west-2
   - **Solution**: Updated to 8.0.39 after checking available versions

2. **Initial N+1 Query Problem**: 
   - First implementation used separate queries for cart + items
   - Response times were above requirement
   - **Solution**: Implemented single JOIN query reducing to 40-45ms   

3. **Foreign Key Constraint Violations**:
   - Error: Adding items to non-existent carts
   - Solution: Added cart existence check before item operations

### Key Learnings:
- RDS takes 5-8 minutes to provision (plan accordingly)
- Connection pooling is critical for concurrent access
- Proper indexing makes a huge difference in query performance
- Schema normalization provides clean separation of concerns

## Comparison with Week 5 In-Memory Approach

**MySQL Advantages:**
- Data persists across service restarts
- ACID guarantees for data consistency
- Complex queries possible with SQL JOINs
- Mature tooling and monitoring

**Trade-offs:**
- Added latency vs in-memory (43ms vs ~5ms)
- Infrastructure complexity (RDS management)
- Connection pool management required
- Cost considerations for database instance

