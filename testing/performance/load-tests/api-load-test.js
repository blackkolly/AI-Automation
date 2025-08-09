/**
 * API Load Testing Script using K6
 * 
 * This script tests the performance and scalability of our microservices APIs
 * under various load conditions including:
 * - Smoke tests (1 user)
 * - Load tests (normal expected load)
 * - Stress tests (above normal load)
 * - Spike tests (sudden load increases)
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
    { duration: '1m', target: 1 },
    
    // Load test - ramp up to normal load
    { duration: '2m', target: 10 },
    { duration: '5m', target: 10 },
    
    // Stress test - ramp up to above normal load
    { duration: '2m', target: 20 },
    { duration: '5m', target: 20 },
    
    // Spike test - sudden increase
    { duration: '1m', target: 50 },
    { duration: '2m', target: 50 },
    
    // Scale down
    { duration: '2m', target: 10 },
    { duration: '1m', target: 0 },
  ],
  
  thresholds: {
    // Performance requirements
    http_req_duration: ['p(95)<200'], // 95% of requests must complete below 200ms
    http_req_duration: ['p(99)<500'], // 99% of requests must complete below 500ms
    http_req_failed: ['rate<0.01'],   // Error rate must be below 1%
    error_rate: ['rate<0.01'],        // Custom error rate below 1%
    
    // Throughput requirements
    http_reqs: ['rate>100'],          // Minimum 100 requests per second
    
    // Specific endpoint thresholds
    'http_req_duration{endpoint:users}': ['p(95)<150'],
    'http_req_duration{endpoint:orders}': ['p(95)<250'],
    'http_req_duration{endpoint:auth}': ['p(95)<100'],
  },
};

// Test data
const BASE_URL = __ENV.BASE_URL || 'http://localhost:3001';
const testUsers = [];
let authTokens = [];

// Setup function - runs once before the test
export function setup() {
  console.log('🚀 Starting performance test setup...');
  
  // Create test users for authentication
  const users = [];
  for (let i = 0; i < 20; i++) {
    const user = {
      email: `perf-test-${i}@example.com`,
      name: `Performance Test User ${i}`,
      password: 'SecurePassword123!'
    };
    
    const response = http.post(`${BASE_URL}/api/users`, JSON.stringify(user), {
      headers: { 'Content-Type': 'application/json' },
      tags: { endpoint: 'setup' }
    });
    
    if (response.status === 201) {
      users.push(user);
    }
  }
  
  console.log(`✅ Created ${users.length} test users`);
  return { users };
}

// Main test function
export default function(data) {
  const user = data.users[Math.floor(Math.random() * data.users.length)];
  
  // Test scenario weights (percentage of traffic each endpoint receives)
  const scenario = Math.random();
  
  if (scenario < 0.3) {
    testUserAuthentication(user);
  } else if (scenario < 0.6) {
    testUserOperations(user);
  } else if (scenario < 0.8) {
    testOrderOperations(user);
  } else {
    testMixedOperations(user);
  }
  
  // Realistic user think time
  sleep(Math.random() * 3 + 1); // 1-4 seconds
}

function testUserAuthentication(user) {
  const params = {
    headers: { 'Content-Type': 'application/json' },
    tags: { endpoint: 'auth', operation: 'login' }
  };
  
  // Login
  const loginResponse = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({
      email: user.email,
      password: user.password
    }),
    params
  );
  
  const loginSuccess = check(loginResponse, {
    'login status is 200': (r) => r.status === 200,
    'login response time < 200ms': (r) => r.timings.duration < 200,
    'login returns token': (r) => JSON.parse(r.body).token !== undefined,
  });
  
  errorRate.add(!loginSuccess);
  responseTime.add(loginResponse.timings.duration);
  requestCount.add(1);
  
  if (loginSuccess) {
    const token = JSON.parse(loginResponse.body).token;
    
    // Test token validation with protected endpoint
    const protectedResponse = http.get(`${BASE_URL}/api/users/me`, {
      headers: { 
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
      },
      tags: { endpoint: 'users', operation: 'profile' }
    });
    
    check(protectedResponse, {
      'protected endpoint status is 200': (r) => r.status === 200,
      'protected endpoint response time < 150ms': (r) => r.timings.duration < 150,
    });
    
    requestCount.add(1);
  }
}

function testUserOperations(user) {
  const token = authenticateUser(user);
  if (!token) return;
  
  const authHeaders = {
    headers: { 
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    },
    tags: { endpoint: 'users' }
  };
  
  // Get user profile
  const profileResponse = http.get(`${BASE_URL}/api/users/me`, authHeaders);
  
  check(profileResponse, {
    'get profile status is 200': (r) => r.status === 200,
    'get profile response time < 150ms': (r) => r.timings.duration < 150,
    'profile contains user data': (r) => {
      const body = JSON.parse(r.body);
      return body.email && body.name;
    }
  });
  
  requestCount.add(1);
  
  // Update user profile
  const updateData = {
    name: `Updated ${user.name} ${Date.now()}`
  };
  
  const updateResponse = http.put(
    `${BASE_URL}/api/users/me`,
    JSON.stringify(updateData),
    { ...authHeaders, tags: { endpoint: 'users', operation: 'update' } }
  );
  
  check(updateResponse, {
    'update profile status is 200': (r) => r.status === 200,
    'update profile response time < 200ms': (r) => r.timings.duration < 200,
  });
  
  requestCount.add(1);
}

function testOrderOperations(user) {
  const token = authenticateUser(user);
  if (!token) return;
  
  const authHeaders = {
    headers: { 
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  };
  
  // Create order
  const orderData = {
    productId: `product-${Math.floor(Math.random() * 100)}`,
    quantity: Math.floor(Math.random() * 5) + 1,
    price: Math.floor(Math.random() * 10000) + 500
  };
  
  const createOrderResponse = http.post(
    `${BASE_URL}/api/orders`,
    JSON.stringify(orderData),
    { ...authHeaders, tags: { endpoint: 'orders', operation: 'create' } }
  );
  
  const orderCreated = check(createOrderResponse, {
    'create order status is 201': (r) => r.status === 201,
    'create order response time < 250ms': (r) => r.timings.duration < 250,
    'order has valid ID': (r) => JSON.parse(r.body).id !== undefined,
  });
  
  requestCount.add(1);
  
  if (orderCreated) {
    const orderId = JSON.parse(createOrderResponse.body).id;
    
    // Get order details
    const orderResponse = http.get(
      `${BASE_URL}/api/orders/${orderId}`,
      { ...authHeaders, tags: { endpoint: 'orders', operation: 'get' } }
    );
    
    check(orderResponse, {
      'get order status is 200': (r) => r.status === 200,
      'get order response time < 200ms': (r) => r.timings.duration < 200,
    });
    
    requestCount.add(1);
  }
  
  // Get user orders list
  const ordersListResponse = http.get(
    `${BASE_URL}/api/orders?page=1&limit=10`,
    { ...authHeaders, tags: { endpoint: 'orders', operation: 'list' } }
  );
  
  check(ordersListResponse, {
    'get orders list status is 200': (r) => r.status === 200,
    'get orders list response time < 300ms': (r) => r.timings.duration < 300,
    'orders list has pagination': (r) => {
      const body = JSON.parse(r.body);
      return body.pagination !== undefined;
    }
  });
  
  requestCount.add(1);
}

function testMixedOperations(user) {
  const token = authenticateUser(user);
  if (!token) return;
  
  const authHeaders = {
    headers: { 
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  };
  
  // Simulate a realistic user session with multiple operations
  const operations = [
    () => http.get(`${BASE_URL}/api/users/me`, authHeaders),
    () => http.get(`${BASE_URL}/api/orders?page=1&limit=5`, authHeaders),
    () => http.get(`${BASE_URL}/api/products?category=electronics`, authHeaders),
    () => http.post(`${BASE_URL}/api/orders`, JSON.stringify({
      productId: `product-${Math.floor(Math.random() * 50)}`,
      quantity: 1,
      price: 2999
    }), authHeaders),
  ];
  
  // Execute 2-4 random operations
  const numOperations = Math.floor(Math.random() * 3) + 2;
  for (let i = 0; i < numOperations; i++) {
    const operation = operations[Math.floor(Math.random() * operations.length)];
    const response = operation();
    
    check(response, {
      'mixed operation successful': (r) => r.status >= 200 && r.status < 400,
      'mixed operation response time acceptable': (r) => r.timings.duration < 500,
    });
    
    requestCount.add(1);
    sleep(0.5); // Short pause between operations
  }
}

function authenticateUser(user) {
  const loginResponse = http.post(
    `${BASE_URL}/api/auth/login`,
    JSON.stringify({
      email: user.email,
      password: user.password
    }),
    {
      headers: { 'Content-Type': 'application/json' },
      tags: { endpoint: 'auth', operation: 'login_helper' }
    }
  );
  
  if (loginResponse.status === 200) {
    return JSON.parse(loginResponse.body).token;
  }
  
  console.error(`Failed to authenticate user ${user.email}: ${loginResponse.status}`);
  return null;
}

// Teardown function - runs once after the test
export function teardown(data) {
  console.log('🧹 Cleaning up performance test data...');
  
  // Optional: Clean up test data
  // Note: In a real scenario, you might want to keep test data for analysis
  
  console.log('✅ Performance test completed');
}

// Export test scenarios for different load patterns
export const smokeTest = {
  executor: 'constant-vus',
  vus: 1,
  duration: '1m',
};

export const loadTest = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 10 },
    { duration: '2m', target: 0 },
  ],
};

export const stressTest = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '2m', target: 10 },
    { duration: '5m', target: 10 },
    { duration: '2m', target: 20 },
    { duration: '5m', target: 20 },
    { duration: '2m', target: 0 },
  ],
};

export const spikeTest = {
  executor: 'ramping-vus',
  startVUs: 0,
  stages: [
    { duration: '1m', target: 10 },
    { duration: '30s', target: 50 },
    { duration: '30s', target: 10 },
    { duration: '1m', target: 0 },
  ],
};
