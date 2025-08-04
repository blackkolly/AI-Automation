#!/bin/bash

echo "🔧 Setting up Grafana with Prometheus data source..."

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
until curl -s http://localhost:3000/api/health >/dev/null 2>&1; do
    echo "   Waiting for Grafana..."
    sleep 2
done

echo "✅ Grafana is ready!"

# Add Prometheus data source
echo "🔗 Adding Prometheus data source..."
curl -X POST \
  -H "Content-Type: application/json" \
  -u admin:admin \
  http://localhost:3000/api/datasources \
  -d '{
    "name": "Prometheus",
    "type": "prometheus",
    "url": "http://prometheus:9090",
    "access": "proxy",
    "isDefault": true
  }'

echo ""
echo "✅ Prometheus data source added!"

# Create a simple dashboard
echo "📊 Creating dashboard..."
curl -X POST \
  -H "Content-Type: application/json" \
  -u admin:admin \
  http://localhost:3000/api/dashboards/db \
  -d '{
    "dashboard": {
      "title": "Microservices Metrics",
      "panels": [
        {
          "id": 1,
          "title": "HTTP Requests Rate",
          "type": "stat",
          "targets": [
            {
              "expr": "rate(http_requests_total[1m])",
              "legendFormat": "Requests/sec"
            }
          ],
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 0},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "palette-classic"},
              "unit": "reqps"
            }
          }
        },
        {
          "id": 2,
          "title": "Product Views",
          "type": "stat",
          "targets": [
            {
              "expr": "product_views_total",
              "legendFormat": "Total Views"
            }
          ],
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 0},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "palette-classic"},
              "unit": "short"
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
              "legendFormat": "Orders"
            }
          ],
          "gridPos": {"h": 8, "w": 12, "x": 0, "y": 8},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "palette-classic"},
              "unit": "short"
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
              "legendFormat": "Service Up"
            }
          ],
          "gridPos": {"h": 8, "w": 12, "x": 12, "y": 8},
          "fieldConfig": {
            "defaults": {
              "color": {"mode": "palette-classic"},
              "unit": "short",
              "thresholds": {
                "steps": [
                  {"color": "red", "value": 0},
                  {"color": "green", "value": 1}
                ]
              }
            }
          }
        }
      ],
      "time": {"from": "now-5m", "to": "now"},
      "refresh": "5s"
    },
    "overwrite": true
  }'

echo ""
echo "🎉 Dashboard created successfully!"
echo ""
echo "📝 Access your dashboard:"
echo "   🌐 Grafana: http://localhost:3000"
echo "   👤 Login: admin/admin"
echo "   📊 Dashboard: Microservices Metrics"
echo ""
