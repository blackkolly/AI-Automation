## Application Metrics Dashboard Setup

### ✅ Your metrics application is now running and generating data!

**Current Status:**

- **Metrics App**: Running in `microservices` namespace
- **Prometheus**: Collecting metrics on port 30090
- **Grafana**: Dashboard available on port 30300

### 🎯 Access Your Dashboards

1. **Grafana Dashboard**: http://localhost:30300

   - Username: `admin`
   - Password: `admin123`

2. **Prometheus**: http://localhost:30090

### 📊 Create Grafana Dashboard

Since automated dashboard provisioning can be complex, here's how to manually create your metrics dashboard:

#### Step 1: Access Grafana

1. Go to http://localhost:30300
2. Login with `admin` / `admin123`

#### Step 2: Create New Dashboard

1. Click the "+" icon in the left sidebar
2. Select "Dashboard"
3. Click "Add new panel"

#### Step 3: Add Metrics Panels

**Panel 1: HTTP Request Rate**

- Query: `rate(http_requests_total[5m])`
- Panel Type: Time series
- Title: "HTTP Request Rate"

**Panel 2: Product Views**

- Query: `rate(product_views_total[5m])`
- Panel Type: Time series
- Title: "Product Views per Second"

**Panel 3: Orders Created**

- Query: `rate(orders_total[5m])`
- Panel Type: Time series
- Title: "Orders per Second"

**Panel 4: Service Status**

- Query: `service_up`
- Panel Type: Stat
- Title: "Service Health"

**Panel 5: Total Requests**

- Query: `http_requests_total`
- Panel Type: Stat
- Title: "Total HTTP Requests"

**Panel 6: Total Product Views**

- Query: `product_views_total`
- Panel Type: Stat
- Title: "Total Product Views"

### 🔄 Generate Test Traffic

To see live metrics, run this command to generate traffic:

```bash
# Generate continuous traffic (run in another terminal)
while true; do
  kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/products > /dev/null 2>&1
  kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/orders > /dev/null 2>&1
  sleep 1
done
```

### 📈 Available Metrics

Your application exposes these Prometheus metrics:

- `http_requests_total{service="test-app"}` - Total HTTP requests
- `product_views_total{service="test-app"}` - Total product page views
- `orders_total{service="test-app"}` - Total orders created
- `service_up{service="test-app"}` - Service health status (1 = up, 0 = down)

### 🎨 Dashboard Tips

1. **Time Range**: Set to "Last 15 minutes" for live data
2. **Refresh**: Set auto-refresh to 5s or 10s
3. **Rate Functions**: Use `rate()` function for per-second rates
4. **Aggregation**: Use `sum()`, `avg()`, `max()` for multiple services

### 🔍 Troubleshooting

If you don't see metrics:

1. **Check Prometheus Targets**:

   - Go to http://localhost:30090/targets
   - Look for your service targets (should be "UP")

2. **Check Metrics Endpoint**:

   ```bash
   kubectl exec -n microservices deployment/metrics-test-app -- wget -qO- http://localhost:3000/metrics
   ```

3. **Verify Prometheus Query**:
   - Go to http://localhost:30090/graph
   - Try query: `http_requests_total`

Your monitoring stack is now fully operational! 🚀
