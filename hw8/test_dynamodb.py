#!/usr/bin/env python3
"""
DynamoDB Shopping Cart Load Test
Runs 150 operations: 50 create, 50 add items, 50 get
Saves results to dynamodb_test_results.json
"""

import requests
import json
import time
from datetime import datetime, timezone

# Configuration
BASE_URL = "http://shopping-cart-service-ddb-alb-1105742360.us-west-2.elb.amazonaws.com"
OUTPUT_FILE = "test-results/dynamodb_test_results.json"

def test_create_cart(customer_id):
    """Create a new shopping cart"""
    start_time = time.time()
    
    try:
        response = requests.post(
            f"{BASE_URL}/shopping-carts",
            json={"customer_id": customer_id},
            timeout=10
        )
        
        response_time = (time.time() - start_time) * 1000  # Convert to ms
        
        return {
            "operation": "create_cart",
            "response_time": round(response_time, 2),
            "success": response.status_code == 201 or response.status_code == 200,
            "status_code": response.status_code,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "cart_id": response.json().get("cart_id") if response.ok else None
        }
    except Exception as e:
        response_time = (time.time() - start_time) * 1000
        return {
            "operation": "create_cart",
            "response_time": round(response_time, 2),
            "success": False,
            "status_code": 0,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "error": str(e)
        }

def test_add_items(cart_id, product_id):
    """Add items to an existing cart"""
    start_time = time.time()
    
    try:
        response = requests.post(
            f"{BASE_URL}/shopping-carts/{cart_id}/items",
            json={
                "product_id": product_id,
                "quantity": 1,
                "price": 19.99
            },
            timeout=10
        )
        
        response_time = (time.time() - start_time) * 1000
        
        return {
            "operation": "add_items",
            "response_time": round(response_time, 2),
            "success": response.status_code == 200,
            "status_code": response.status_code,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    except Exception as e:
        response_time = (time.time() - start_time) * 1000
        return {
            "operation": "add_items",
            "response_time": round(response_time, 2),
            "success": False,
            "status_code": 0,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "error": str(e)
        }

def test_get_cart(cart_id):
    """Get a cart with all items"""
    start_time = time.time()
    
    try:
        response = requests.get(
            f"{BASE_URL}/shopping-carts/{cart_id}",
            timeout=10
        )
        
        response_time = (time.time() - start_time) * 1000
        
        return {
            "operation": "get_cart",
            "response_time": round(response_time, 2),
            "success": response.status_code == 200,
            "status_code": response.status_code,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
    except Exception as e:
        response_time = (time.time() - start_time) * 1000
        return {
            "operation": "get_cart",
            "response_time": round(response_time, 2),
            "success": False,
            "status_code": 0,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "error": str(e)
        }

def main():
    print("=" * 60)
    print("DynamoDB Shopping Cart Load Test")
    print("=" * 60)
    print(f"Target: {BASE_URL}")
    print(f"Test Plan: 50 create + 50 add items + 50 get = 150 operations")
    print("=" * 60)
    
    results = []
    cart_ids = []
    
    # Phase 1: Create 50 carts
    print("\nPhase 1: Creating 50 shopping carts...")
    for i in range(50):
        customer_id = f"customer-ddb-{i+1}"
        result = test_create_cart(customer_id)
        results.append(result)
        
        if result["success"] and result.get("cart_id"):
            cart_ids.append(result["cart_id"])
        
        if (i + 1) % 10 == 0:
            print(f"  Created {i + 1}/50 carts...")
    
    print(f"✓ Phase 1 complete. {len(cart_ids)} carts created successfully.")
    
    # Phase 2: Add items to 50 carts
    print("\nPhase 2: Adding items to 50 carts...")
    for i in range(50):
        # Use created cart IDs
        if i < len(cart_ids):
            cart_id = cart_ids[i]
        else:
            print(f"  Warning: Not enough cart IDs, skipping add_items {i+1}")
            continue
            
        product_id = f"product-ddb-{i+1}"
        
        result = test_add_items(cart_id, product_id)
        results.append(result)
        
        if (i + 1) % 10 == 0:
            print(f"  Added items to {i + 1}/50 carts...")
    
    print(f"✓ Phase 2 complete.")
    
    # Phase 3: Get 50 carts
    print("\nPhase 3: Retrieving 50 carts...")
    for i in range(50):
        if i < len(cart_ids):
            cart_id = cart_ids[i]
        else:
            print(f"  Warning: Not enough cart IDs, skipping get_cart {i+1}")
            continue
        
        result = test_get_cart(cart_id)
        results.append(result)
        
        if (i + 1) % 10 == 0:
            print(f"  Retrieved {i + 1}/50 carts...")
    
    print(f"✓ Phase 3 complete.")
    
    # Save results
    print(f"\nSaving results to {OUTPUT_FILE}...")
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(results, f, indent=2)
    
    # Calculate statistics
    print("\n" + "=" * 60)
    print("TEST RESULTS SUMMARY")
    print("=" * 60)
    
    total_ops = len(results)
    successful_ops = sum(1 for r in results if r["success"])
    failed_ops = total_ops - successful_ops
    
    # Calculate stats by operation type
    for op_type in ["create_cart", "add_items", "get_cart"]:
        op_results = [r for r in results if r["operation"] == op_type]
        if op_results:
            response_times = [r["response_time"] for r in op_results]
            successes = sum(1 for r in op_results if r["success"])
            
            print(f"\n{op_type.upper()}:")
            print(f"  Operations: {len(op_results)}")
            print(f"  Success: {successes}/{len(op_results)}")
            print(f"  Avg Response Time: {sum(response_times)/len(response_times):.2f} ms")
            print(f"  Min Response Time: {min(response_times):.2f} ms")
            print(f"  Max Response Time: {max(response_times):.2f} ms")
    
    print(f"\nOVERALL:")
    print(f"  Total Operations: {total_ops}")
    print(f"  Successful: {successful_ops} ({successful_ops/total_ops*100:.1f}%)")
    print(f"  Failed: {failed_ops}")
    
    all_response_times = [r["response_time"] for r in results]
    print(f"  Overall Avg Response Time: {sum(all_response_times)/len(all_response_times):.2f} ms")
    
    print("\n" + "=" * 60)
    print(f"✓ Results saved to: {OUTPUT_FILE}")
    print("=" * 60)

if __name__ == "__main__":
    main()
