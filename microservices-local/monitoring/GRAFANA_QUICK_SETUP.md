## 🎯 **Quick Grafana Setup - Your Metrics Are Ready!**

### ✅ **Good News: Your Metrics Are Working!**

- Prometheus is successfully scraping your application
- Current metrics: 107 HTTP requests, 21 product views, 19 orders
- All services are UP and healthy

### 🚀 **How to See Metrics in Grafana Dashboard:**

**Step 1: Access Grafana**

- Go to: http://localhost:30300
- Login: `admin` / `admin123`

**Step 2: Add Prometheus Data Source**

1. Click the **gear icon** (⚙️) on the left sidebar
2. Click **"Data Sources"**
3. Click **"Add data source"**
4. Select **"Prometheus"**
5. In the URL field, enter: `http://prometheus.monitoring.svc.cluster.local:9090`
6. Click **"Save & Test"** (should show green checkmark)

**Step 3: Create Your First Dashboard**

1. Click **"+"** in the left sidebar
2. Click **"Dashboard"**
3. Click **"Add new panel"**
4. In the query field, enter: `http_requests_total`
5. Click **"Apply"**

**Step 4: Add More Panels**
Create additional panels with these queries:

- **Product Views**: `product_views_total`
- **Orders**: `orders_total`
- **Service Health**: `service_up`
- **Request Rate**: `rate(http_requests_total[5m])`

### 📊 **Sample Dashboard Queries**

Copy and paste these into new panels:

```promql
# Total HTTP Requests
http_requests_total

# Request Rate (per second)
rate(http_requests_total[5m])

# Product Views Rate
rate(product_views_total[5m])

# Orders Rate
rate(orders_total[5m])

# Service Status (1 = UP, 0 = DOWN)
service_up
```

### 🔄 **Generate Live Data**

Run this to create more metrics while you watch:

```bash
./generate-traffic.sh
```

### 🎨 **Dashboard Tips**

- Set time range to "Last 15 minutes" for live data
- Set refresh to "5s" for real-time updates
- Use "Time series" for graphs, "Stat" for single values

Your application metrics are working perfectly! Just need to set up the Grafana visualization. 📈
