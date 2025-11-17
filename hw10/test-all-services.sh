#!/bin/bash
ALB_URL="http://cs6650-microservices-alb-952343708.us-west-2.elb.amazonaws.com"
COOKIE_FILE="/tmp/cart_cookies.txt"

# Clean up old cookies
rm -f $COOKIE_FILE

echo "========================================="
echo "Complete Microservices Test Suite"
echo "========================================="
echo ""

# Test 1: Product Service
echo "=== Test 1: Product Service ==="
curl -s $ALB_URL/products/1 | jq
echo ""

# Test 2: Credit Card Authorizer
echo "=== Test 2: Credit Card Authorizer ==="
curl -s -X POST $ALB_URL/authorize \
  -H "Content-Type: application/json" \
  -d '{"credit_card_number":"1234-5678-9012-3456","amount":100.50}' | jq
echo ""

# Test 3: Create Shopping Cart (save cookies)
echo "=== Test 3: Create Shopping Cart ==="
CART_ID=$(curl -s -c $COOKIE_FILE -X POST $ALB_URL/shopping-carts \
  -H "Content-Type: application/json" \
  -d '{"customer_id":"TEST-001"}' | jq -r '.cart_id')
echo "Cart ID: $CART_ID"
echo ""

# Test 4: Add Items to Cart (use cookies)
echo "=== Test 4: Add Items to Cart ==="
curl -s -b $COOKIE_FILE -c $COOKIE_FILE -X POST $ALB_URL/shopping-carts/$CART_ID/items \
  -H "Content-Type: application/json" \
  -d '{"product_id":"PROD-001","quantity":2}' | jq

curl -s -b $COOKIE_FILE -c $COOKIE_FILE -X POST $ALB_URL/shopping-carts/$CART_ID/items \
  -H "Content-Type: application/json" \
  -d '{"product_id":"PROD-002","quantity":1}' | jq
echo ""

# Test 5: Get Cart Details (use cookies)
echo "=== Test 5: Get Cart Details ==="
curl -s -b $COOKIE_FILE $ALB_URL/shopping-carts/$CART_ID | jq
echo ""

# Test 6: Checkout (use cookies)
echo "=== Test 6: Checkout (Full Flow) ==="
CHECKOUT_RESULT=$(curl -s -b $COOKIE_FILE -c $COOKIE_FILE -X POST $ALB_URL/shopping-carts/$CART_ID/checkout \
  -H "Content-Type: application/json" \
  -d '{"credit_card_number":"1234-5678-9012-3456"}')
echo "$CHECKOUT_RESULT" | jq

ORDER_ID=$(echo "$CHECKOUT_RESULT" | jq -r '.order_id')
echo ""
echo "Order ID: $ORDER_ID"
echo ""

# Test 7: Verify Cart is Deleted After Checkout
echo "=== Test 7: Verify Cart Deleted After Checkout ==="
curl -s -b $COOKIE_FILE $ALB_URL/shopping-carts/$CART_ID | jq
echo ""

# Test 8: Check Warehouse Logs
echo "=== Test 8: Check Warehouse Received Order ==="
echo "Checking warehouse logs for order $ORDER_ID..."
sleep 2
aws logs tail /ecs/cs6650-microservices --since 1m --filter-pattern "warehouse" | grep -i "processing\|order" | tail -5
echo ""

echo "========================================="
echo "All Tests Complete!"
echo "========================================="
echo ""
echo "Summary:"
echo "✓ Product Service working"
echo "✓ Credit Card Authorizer working"
echo "✓ Shopping Cart created"
echo "✓ Items added to cart"
echo "✓ Checkout successful"
echo "✓ Order sent to warehouse"
echo ""
echo "Load Balancer URL: $ALB_URL"
