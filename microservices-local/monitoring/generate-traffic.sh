#!/bin/bash

echo "Starting continuous traffic generation for metrics..."
echo "This will generate requests every 2 seconds to create live metrics data"
echo "Press Ctrl+C to stop"
echo

# Function to generate a burst of requests
generate_burst() {
    local count=$1
    echo "Generating burst of $count requests..."
    
    for i in $(seq 1 $count); do
        # Generate product views
        kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/products > /dev/null 2>&1 &
        
        # Generate some orders (less frequently)
        if [ $((i % 3)) -eq 0 ]; then
            kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/orders > /dev/null 2>&1 &
        fi
        
        # Generate health checks
        if [ $((i % 5)) -eq 0 ]; then
            kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/health > /dev/null 2>&1 &
        fi
    done
    
    wait # Wait for all background requests to complete
}

# Generate initial burst
generate_burst 20

# Continuous generation
counter=1
while true; do
    echo "$(date): Generating traffic batch $counter"
    
    # Vary the load to create interesting graphs
    if [ $((counter % 10)) -eq 0 ]; then
        # Every 10th iteration, create a larger burst
        generate_burst 15
        echo "  -> Generated high load burst"
    elif [ $((counter % 5)) -eq 0 ]; then
        # Every 5th iteration, create medium load
        generate_burst 8
        echo "  -> Generated medium load"
    else
        # Normal load
        generate_burst 3
        echo "  -> Generated normal load"
    fi
    
    # Show current metrics every 10 iterations
    if [ $((counter % 10)) -eq 0 ]; then
        echo "Current metrics:"
        kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/metrics | head -4
        echo
    fi
    
    counter=$((counter + 1))
    sleep 2
done
