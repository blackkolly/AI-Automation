# 🌐 External URLs for Observability Stack

## 📊 **Current Working URLs (No Port Forwarding Required)**

### **✅ Prometheus - Metrics & Monitoring**

- **URL**: http://ab58fe70bf87f485f9a173654802a55b-e11584559552f59d1.elb.us-west-2.amazonaws.com:9090
- **Service**: prometheus-external (LoadBalancer)
- **Status**: ✅ Active
- **Use Cases**:
  - View metrics and time-series data
  - Execute PromQL queries
  - Monitor service health
  - View targets and service discovery

### **✅ Grafana - Dashboards & Visualization**

- **URL**: http://a51beef0d692b401cca58dca52f31494d-675101656.us-west-2.elb.amazonaws.com:3000
- **Service**: grafana-external (LoadBalancer)
- **Status**: ✅ Active
- **Default Credentials**:
  - Username: `admin`
  - Password: `prom-operator`
- **Use Cases**:
  - Visual dashboards
  - Custom metrics visualization
  - Alerting rules management
  - Multi-service monitoring

### **✅ AlertManager - Alert Management**

- **URL**: http://a1f827d1df1884a3aab2ef5dec0b12ae3-1161678287.us-west-2.elb.amazonaws.com:9093
- **Service**: alertmanager-external (LoadBalancer)
- **Status**: ✅ Active
- **Use Cases**:
  - View active alerts
  - Manage alert routing
  - Configure notification channels
  - Silence/acknowledge alerts

---

## ✅ **Jaeger - Distributed Tracing (NOW AVAILABLE)**

### **✅ Jaeger External URL (No Port Forwarding Required)**

- **URL**: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:16686
- **Service**: jaeger-external (LoadBalancer)
- **Status**: ✅ Active
- **Use Cases**:
  - View distributed traces across microservices
  - Analyze request flow and latency
  - Debug performance bottlenecks
  - Monitor service dependencies

### **✅ Jaeger Collector Endpoint**

- **URL**: http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com:14268
- **Service**: Trace ingestion endpoint for applications
- **Use**: Configure this URL in your microservices for trace submission

---

## 🔧 **Troubleshooting LoadBalancer Issues**

### **If Jaeger LoadBalancer Remains Pending**:

#### **Check AWS Load Balancer Controller**

```bash
# Verify AWS Load Balancer Controller is running
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

#### **Check Service Events**

```bash
# Check service events for error messages
kubectl describe service jaeger -n monitoring | grep Events -A 10
```

#### **Check Node Security Groups**

```bash
# Ensure security groups allow LoadBalancer traffic
aws ec2 describe-security-groups --group-ids <worker-node-security-group>
```

---

## 🚀 **Force Create External LoadBalancer Service**

If the current LoadBalancer remains pending, create a new external service:

```yaml
# Save as jaeger-external-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: jaeger-external
  namespace: monitoring
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
spec:
  type: LoadBalancer
  selector:
    app: jaeger
  ports:
    - name: ui
      port: 16686
      targetPort: 16686
      protocol: TCP
    - name: collector-http
      port: 14268
      targetPort: 14268
      protocol: TCP
```

```bash
# Apply the service
kubectl apply -f jaeger-external-service.yaml

# Monitor service creation
kubectl get service jaeger-external -n monitoring -w
```

---

## 📝 **Quick Access Summary**

| Tool             | Status   | URL                                                                                   | Port  |
| ---------------- | -------- | ------------------------------------------------------------------------------------- | ----- |
| **Prometheus**   | ✅ Ready | http://ab58fe70bf87f485f9a173654802a55b-e11584559552f59d1.elb.us-west-2.amazonaws.com | 9090  |
| **Grafana**      | ✅ Ready | http://a51beef0d692b401cca58dca52f31494d-675101656.us-west-2.elb.amazonaws.com        | 3000  |
| **AlertManager** | ✅ Ready | http://a1f827d1df1884a3aab2ef5dec0b12ae3-1161678287.us-west-2.elb.amazonaws.com       | 9093  |
| **Jaeger**       | ✅ Ready | http://a4e39c89eab724914a7324ac7bc6c913-e75a576a9f50743a.elb.us-west-2.amazonaws.com  | 16686 |

---

## 🎯 **Demo-Ready Commands**

### **Test Prometheus (Working Now)**

```bash
curl "http://ab58fe70bf87f485f9a173654802a55b-e11584559552f59d1.elb.us-west-2.amazonaws.com:9090/api/v1/targets"
```

### **Test Grafana (Working Now)**

```bash
curl "http://a51beef0d692b401cca58dca52f31494d-675101656.us-west-2.elb.amazonaws.com:3000/api/health"
```

### **Test AlertManager (Working Now)**

```bash
curl "http://a1f827d1df1884a3aab2ef5dec0b12ae3-1161678287.us-west-2.elb.amazonaws.com:9093/api/v1/status"
```

---

_Last Updated: August 3, 2025_  
_External URLs Status: 4/4 Active_ ✅
