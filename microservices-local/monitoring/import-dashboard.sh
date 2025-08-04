#!/bin/bash

echo "🎯 Setting up Grafana Dashboard with your metrics..."

# First, let's create the dashboard JSON
cat > /tmp/microservices-dashboard.json << 'EOF'
{
  "dashboard": {
    "id": null,
    "title": "Microservices Metrics Dashboard",
    "tags": ["microservices", "kubernetes"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1,
        "title": "HTTP Requests Total",
        "type": "stat",
        "targets": [
          {
            "expr": "http_requests_total",
            "legendFormat": "{{service}} - Total Requests"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 0,
          "y": 0
        },
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "green", "value": null},
                {"color": "yellow", "value": 100},
                {"color": "red", "value": 500}
              ]
            }
          }
        }
      },
      {
        "id": 2,
        "title": "Service Status",
        "type": "stat",
        "targets": [
          {
            "expr": "service_up",
            "legendFormat": "{{service}}"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 6,
          "y": 0
        },
        "fieldConfig": {
          "defaults": {
            "color": {
              "mode": "thresholds"
            },
            "thresholds": {
              "steps": [
                {"color": "red", "value": null},
                {"color": "green", "value": 1}
              ]
            }
          }
        }
      },
      {
        "id": 3,
        "title": "Product Views",
        "type": "stat",
        "targets": [
          {
            "expr": "product_views_total",
            "legendFormat": "Product Views"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 12,
          "y": 0
        }
      },
      {
        "id": 4,
        "title": "Orders Created",
        "type": "stat",
        "targets": [
          {
            "expr": "orders_total",
            "legendFormat": "Orders"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 6,
          "x": 18,
          "y": 0
        }
      },
      {
        "id": 5,
        "title": "HTTP Request Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(http_requests_total[1m])*60",
            "legendFormat": "Requests per minute"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 0,
          "y": 8
        }
      },
      {
        "id": 6,
        "title": "Business Metrics Rate",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(product_views_total[1m])*60",
            "legendFormat": "Product Views/min"
          },
          {
            "expr": "rate(orders_total[1m])*60",
            "legendFormat": "Orders/min"
          }
        ],
        "gridPos": {
          "h": 8,
          "w": 12,
          "x": 12,
          "y": 8
        }
      }
    ],
    "time": {
      "from": "now-15m",
      "to": "now"
    },
    "refresh": "5s"
  }
}
EOF

echo "1. Dashboard JSON created"

# Get Grafana pod name
GRAFANA_POD=$(kubectl get pod -n monitoring -l app=grafana -o jsonpath="{.items[0].metadata.name}")
echo "2. Found Grafana pod: $GRAFANA_POD"

# Copy dashboard to Grafana pod
kubectl cp /tmp/microservices-dashboard.json monitoring/$GRAFANA_POD:/tmp/dashboard.json
echo "3. Dashboard copied to Grafana pod"

# Import dashboard using Grafana API
echo "4. Importing dashboard via API..."
kubectl exec -n monitoring $GRAFANA_POD -- curl -X POST \
  http://admin:admin123@localhost:3000/api/dashboards/db \
  -H "Content-Type: application/json" \
  -d @/tmp/dashboard.json

echo ""
echo "🎉 Dashboard should now be available!"
echo "📊 Go to: http://localhost:30300"
echo "🔑 Login: admin / admin123"
echo "📈 Look for 'Microservices Metrics Dashboard' in your dashboards"

# Generate some traffic to see live data
echo ""
echo "5. Generating traffic for live dashboard data..."
for i in {1..20}; do
    kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/products > /dev/null 2>&1 &
    kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/orders > /dev/null 2>&1 &
    if [ $((i % 5)) -eq 0 ]; then
        echo "Generated $i requests... (check dashboard for live updates)"
    fi
done

wait
echo "✅ Traffic generation complete - check your dashboard!"
