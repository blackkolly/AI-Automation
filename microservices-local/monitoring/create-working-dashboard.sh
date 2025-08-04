#!/bin/bash

echo "🔧 Creating a working Grafana dashboard with your metrics..."

# Test that we can query the metrics first
echo "📊 Testing metrics availability..."
curl -s "http://localhost:9090/api/v1/query?query=http_requests_total" | grep -q "success" && echo "✅ http_requests_total found"
curl -s "http://localhost:9090/api/v1/query?query=product_views_total" | grep -q "success" && echo "✅ product_views_total found"
curl -s "http://localhost:9090/api/v1/query?query=orders_total" | grep -q "success" && echo "✅ orders_total found"
curl -s "http://localhost:9090/api/v1/query?query=service_up" | grep -q "success" && echo "✅ service_up found"

echo ""
echo "🎯 All metrics are available! Creating dashboard..."

# Create a simple dashboard via Grafana API
curl -X POST \
  -H "Content-Type: application/json" \
  -u admin:admin123 \
  http://localhost:30300/api/dashboards/db \
  -d '{
    "dashboard": {
      "id": null,
      "uid": "metrics-test-dashboard",
      "title": "Metrics Test App Dashboard",
      "tags": ["microservices", "test"],
      "timezone": "browser",
      "refresh": "5s",
      "time": {
        "from": "now-15m",
        "to": "now"
      },
      "panels": [
        {
          "id": 1,
          "title": "HTTP Requests Total",
          "type": "stat",
          "targets": [
            {
              "expr": "http_requests_total",
              "legendFormat": "Total Requests",
              "refId": "A"
            }
          ],
          "gridPos": {"h": 8, "w": 6, "x": 0, "y": 0},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "thresholds"},
              "unit": "short",
              "thresholds": {
                "steps": [
                  {"color": "green", "value": null}
                ]
              }
            }
          }
        },
        {
          "id": 2,
          "title": "Product Views Total",
          "type": "stat",
          "targets": [
            {
              "expr": "product_views_total",
              "legendFormat": "Product Views",
              "refId": "A"
            }
          ],
          "gridPos": {"h": 8, "w": 6, "x": 6, "y": 0},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "thresholds"},
              "unit": "short",
              "thresholds": {
                "steps": [
                  {"color": "blue", "value": null}
                ]
              }
            }
          }
        },
        {
          "id": 3,
          "title": "Orders Total",
          "type": "stat",
          "targets": [
            {
              "expr": "orders_total",
              "legendFormat": "Orders",
              "refId": "A"
            }
          ],
          "gridPos": {"h": 8, "w": 6, "x": 12, "y": 0},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "thresholds"},
              "unit": "short",
              "thresholds": {
                "steps": [
                  {"color": "orange", "value": null}
                ]
              }
            }
          }
        },
        {
          "id": 4,
          "title": "Service Status",
          "type": "stat",
          "targets": [
            {
              "expr": "service_up",
              "legendFormat": "Service Up",
              "refId": "A"
            }
          ],
          "gridPos": {"h": 8, "w": 6, "x": 18, "y": 0},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "thresholds"},
              "unit": "short",
              "thresholds": {
                "steps": [
                  {"color": "red", "value": 0},
                  {"color": "green", "value": 1}
                ]
              }
            }
          }
        },
        {
          "id": 5,
          "title": "HTTP Requests Rate (per minute)",
          "type": "timeseries",
          "targets": [
            {
              "expr": "rate(http_requests_total[1m]) * 60",
              "legendFormat": "Requests/min",
              "refId": "A"
            }
          ],
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "palette-classic"},
              "unit": "reqpm"
            }
          }
        },
        {
          "id": 6,
          "title": "Product Views Rate (per minute)",
          "type": "timeseries",
          "targets": [
            {
              "expr": "rate(product_views_total[1m]) * 60",
              "legendFormat": "Views/min",
              "refId": "A"
            }
          ],
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "palette-classic"},
              "unit": "short"
            }
          }
        }
      ]
    },
    "overwrite": true
  }'

echo ""
echo "🎉 Dashboard created successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Go to http://localhost:30300"
echo "   2. Navigate to Dashboards → Browse"
echo "   3. Look for 'Metrics Test App Dashboard'"
echo "   4. You should see live data from your metrics-test-app!"
echo ""
