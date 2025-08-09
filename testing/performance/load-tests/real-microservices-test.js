/**
 * REAL API Load Testing Script for YOUR Kubernetes Microservices Platform
 * 
 * This script tests YOUR actual microservices:
 * - API Gateway (localhost:30000)
 * - Auth Service (localhost:30001) 
 * - Product Service (localhost:30002)
 * - Order Service (localhost:30003)
 * - Frontend (localhost:30080)
 */

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('error_rate');
const responseTime = new Trend('response_time');
const requestCount = new Counter('request_count');

// Test configuration
export const options = {
  stages: [
    // Smoke test
    { duration: '30s', target: 1 },
    
    // Load test - ramp up to normal load
    { duration: '1m', target: 5 },
    { duration: '2m', target: 5 },
    
    // Stress test - ramp up to above normal load
    { duration: '1m', target: 10 },
    { duration: '1m', target: 10 },
    
    // Scale down
    { duration: '30s', target: 0 },
  ],
  
  thresholds: {
    // Performance requirements for YOUR services
    http_req_duration: ['p(95)<500'], // 95% of requests must complete below 500ms
    http_req_duration: ['p(99)<1000'], // 99% of requests must complete below 1000ms
    http_req_failed: ['rate<0.05'],   // Error rate must be below 5%
    error_rate: ['rate<0.05'],        // Custom error rate below 5%
    
    // Specific endpoint thresholds for YOUR services
    'http_req_duration{service:api-gateway}': ['p(95)<300'],
    'http_req_duration{service:auth-service}': ['p(95)<400'],
    'http_req_duration{service:product-service}': ['p(95)<400'],
    'http_req_duration{service:order-service}': ['p(95)<400'],
    'http_req_duration{service:frontend}': ['p(95)<500'],
  },
};

// YOUR actual service URLs
const SERVICES = {
  API_GATEWAY: 'http://localhost:30000',
  AUTH_SERVICE: 'http://localhost:30001', 
  PRODUCT_SERVICE: 'http://localhost:30002',
  ORDER_SERVICE: 'http://localhost:30003',
  FRONTEND: 'http://localhost:30080'
};

// Setup function - runs once before the test
export function setup() {
  console.log('🚀 Starting performance test for YOUR Kubernetes Microservices Platform...');
  
  // Test service availability first
  const serviceTests = [];
  
  Object.entries(SERVICES).forEach(([name, url]) => {
    try {
      const response = http.get(`${url}/health`, {
        timeout: '10s',
        tags: { service: name.toLowerCase().replace('_', '-') }
      });
      
      serviceTests.push({
        service: name,
        url: url,
        available: response.status === 200,
        status: response.status
      });
      
      console.log(`${name}: ${response.status === 200 ? '✅ Available' : '❌ Not Available'} (${response.status})`);
    } catch (error) {
      serviceTests.push({
        service: name,
        url: url,
        available: false,
        error: error.message
      });
      console.log(`${name}: ❌ Not Available (${error.message})`);
    }
  });
  
  return { services: serviceTests };
}

// Main test function
export default function(data) {
  // Test different scenarios based on YOUR services
  const scenario = Math.random();
  
  if (scenario < 0.3) {
    testHealthEndpoints();
  } else if (scenario < 0.5) {
    testAuthenticationFlow();
  } else if (scenario < 0.7) {
    testProductServiceOperations();
  } else if (scenario < 0.9) {
    testOrderServiceOperations();
  } else {
    testFrontendAccess();
  }
  
  // Realistic user think time
  sleep(Math.random() * 2 + 1); // 1-3 seconds
}

function testHealthEndpoints() {
  // Test all YOUR service health endpoints
  Object.entries(SERVICES).forEach(([serviceName, serviceUrl]) => {
    const healthResponse = http.get(`${serviceUrl}/health`, {
      tags: { 
        service: serviceName.toLowerCase().replace('_', '-'),
        operation: 'health-check'
      }
    });
    
    const healthCheck = check(healthResponse, {
      [`${serviceName} health check status is 200`]: (r) => r.status === 200,
      [`${serviceName} health check response time < 500ms`]: (r) => r.timings.duration < 500,
      [`${serviceName} health check returns valid JSON`]: (r) => {
        try {
          const body = JSON.parse(r.body);
          return body.status === 'healthy' || body.service !== undefined;
        } catch {
          return false;
        }
      },
    });
    
    errorRate.add(!healthCheck);
    responseTime.add(healthResponse.timings.duration);
    requestCount.add(1);
  });
}

function testAuthenticationFlow() {
  // Test YOUR auth service endpoints
  const loginResponse = http.post(`${SERVICES.AUTH_SERVICE}/auth/login`, 
    JSON.stringify({
      email: 'test@example.com',
      password: 'password123'
    }), {
      headers: { 'Content-Type': 'application/json' },
      tags: { service: 'auth-service', operation: 'login' }
    }
  );
  
  const loginSuccess = check(loginResponse, {
    'auth service login status is 200': (r) => r.status === 200,
    'auth service login response time < 400ms': (r) => r.timings.duration < 400,
    'auth service returns token': (r) => {
      try {
        const body = JSON.parse(r.body);
        return body.token !== undefined;
      } catch {
        return false;
      }
    },
  });
  
  errorRate.add(!loginSuccess);
  responseTime.add(loginResponse.timings.duration);
  requestCount.add(1);
  
  if (loginSuccess) {
    // Test token validation
    const token = JSON.parse(loginResponse.body).token;
    
    const validateResponse = http.post(`${SERVICES.AUTH_SERVICE}/auth/validate`,
      JSON.stringify({ token: token }), {
        headers: { 'Content-Type': 'application/json' },
        tags: { service: 'auth-service', operation: 'validate' }
      }
    );
    
    check(validateResponse, {
      'auth service validate status is 200': (r) => r.status === 200,
      'auth service validate response time < 300ms': (r) => r.timings.duration < 300,
    });
    
    requestCount.add(1);
  }
}

function testProductServiceOperations() {
  // Test YOUR product service endpoints
  const productsResponse = http.get(`${SERVICES.PRODUCT_SERVICE}/products`, {
    tags: { service: 'product-service', operation: 'list-products' }
  });
  
  const productsCheck = check(productsResponse, {
    'product service list status is 200': (r) => r.status === 200,
    'product service list response time < 400ms': (r) => r.timings.duration < 400,
    'product service returns products array': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body) && body.length > 0;
      } catch {
        return false;
      }
    },
  });
  
  errorRate.add(!productsCheck);
  responseTime.add(productsResponse.timings.duration);
  requestCount.add(1);
  
  // Test specific product endpoint
  const productResponse = http.get(`${SERVICES.PRODUCT_SERVICE}/products/1`, {
    tags: { service: 'product-service', operation: 'get-product' }
  });
  
  check(productResponse, {
    'product service get product status is 200': (r) => r.status === 200,
    'product service get product response time < 300ms': (r) => r.timings.duration < 300,
  });
  
  requestCount.add(1);
}

function testOrderServiceOperations() {
  // Test YOUR order service endpoints
  const ordersResponse = http.get(`${SERVICES.ORDER_SERVICE}/orders`, {
    tags: { service: 'order-service', operation: 'list-orders' }
  });
  
  const ordersCheck = check(ordersResponse, {
    'order service list status is 200': (r) => r.status === 200,
    'order service list response time < 400ms': (r) => r.timings.duration < 400,
    'order service returns orders array': (r) => {
      try {
        const body = JSON.parse(r.body);
        return Array.isArray(body);
      } catch {
        return false;
      }
    },
  });
  
  errorRate.add(!ordersCheck);
  responseTime.add(ordersResponse.timings.duration);
  requestCount.add(1);
  
  // Test order creation
  const newOrderResponse = http.post(`${SERVICES.ORDER_SERVICE}/orders`,
    JSON.stringify({
      userId: 1,
      products: [1, 2],
      total: 1249.98
    }), {
      headers: { 'Content-Type': 'application/json' },
      tags: { service: 'order-service', operation: 'create-order' }
    }
  );
  
  check(newOrderResponse, {
    'order service create order accepts request': (r) => r.status >= 200 && r.status < 400,
    'order service create order response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  requestCount.add(1);
}

function testFrontendAccess() {
  // Test YOUR frontend
  const frontendResponse = http.get(SERVICES.FRONTEND, {
    tags: { service: 'frontend', operation: 'load-page' }
  });
  
  const frontendCheck = check(frontendResponse, {
    'frontend loads successfully': (r) => r.status === 200,
    'frontend response time < 500ms': (r) => r.timings.duration < 500,
    'frontend returns HTML': (r) => r.headers['Content-Type'] && r.headers['Content-Type'].includes('text/html'),
  });
  
  errorRate.add(!frontendCheck);
  responseTime.add(frontendResponse.timings.duration);
  requestCount.add(1);
}

function testAPIGatewayRouting() {
  // Test YOUR API Gateway routing
  const statusResponse = http.get(`${SERVICES.API_GATEWAY}/api/status`, {
    tags: { service: 'api-gateway', operation: 'status' }
  });
  
  check(statusResponse, {
    'api gateway status endpoint works': (r) => r.status === 200,
    'api gateway status response time < 300ms': (r) => r.timings.duration < 300,
  });
  
  requestCount.add(1);
}

// Teardown function - runs once after the test
export function teardown(data) {
  console.log('🧹 Performance test completed for YOUR Microservices Platform');
  
  console.log('\n📊 Service Availability Summary:');
  data.services.forEach(service => {
    const status = service.available ? '✅ Available' : '❌ Unavailable';
    console.log(`${service.service}: ${status}`);
  });
  
  console.log('\n✅ Real performance test of YOUR Kubernetes microservices completed');
}

// Export test scenarios for YOUR services
export const healthCheckTest = {
  executor: 'constant-vus',
  vus: 1,
  duration: '30s',
};

export const serviceLoadTest = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '1m', target: 3 },
    { duration: '2m', target: 3 },
    { duration: '1m', target: 0 },
  ],
};

export const stressTest = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '1m', target: 5 },
    { duration: '2m', target: 5 },
    { duration: '1m', target: 10 },
    { duration: '1m', target: 10 },
    { duration: '1m', target: 0 },
  ],
};
