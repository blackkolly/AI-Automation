/**
 * User Journey End-to-End Tests
 * 
 * These tests simulate complete user workflows across the entire application,
 * including frontend interactions, API calls, and data persistence.
 */

const { test, expect } = require('@playwright/test');

test.describe('User Registration and Login Journey', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the application
    await page.goto('/');
    
    // Wait for the page to load completely
    await page.waitForLoadState('networkidle');
  });

  test('should complete full user registration flow', async ({ page }) => {
    // Navigate to registration page
    await page.click('[data-testid="register-link"]');
    await expect(page).toHaveURL('/register');

    // Fill registration form
    await page.fill('[data-testid="email-input"]', 'e2e-test@example.com');
    await page.fill('[data-testid="name-input"]', 'E2E Test User');
    await page.fill('[data-testid="password-input"]', 'SecurePassword123!');
    await page.fill('[data-testid="confirm-password-input"]', 'SecurePassword123!');

    // Submit registration form
    await page.click('[data-testid="register-button"]');

    // Wait for registration success
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await expect(page.locator('[data-testid="success-message"]')).toContainText('Registration successful');

    // Should redirect to login page
    await expect(page).toHaveURL('/login');
  });

  test('should handle registration validation errors', async ({ page }) => {
    await page.click('[data-testid="register-link"]');

    // Try to submit with invalid data
    await page.fill('[data-testid="email-input"]', 'invalid-email');
    await page.fill('[data-testid="name-input"]', '');
    await page.fill('[data-testid="password-input"]', '123');
    await page.click('[data-testid="register-button"]');

    // Check for validation errors
    await expect(page.locator('[data-testid="email-error"]')).toContainText('Invalid email format');
    await expect(page.locator('[data-testid="name-error"]')).toContainText('Name is required');
    await expect(page.locator('[data-testid="password-error"]')).toContainText('Password too weak');
  });

  test('should login with valid credentials', async ({ page }) => {
    // First register a user (using API to speed up test)
    await page.request.post('/api/users', {
      data: {
        email: 'login-test@example.com',
        name: 'Login Test User',
        password: 'SecurePassword123!'
      }
    });

    // Navigate to login page
    await page.click('[data-testid="login-link"]');
    await expect(page).toHaveURL('/login');

    // Fill login form
    await page.fill('[data-testid="email-input"]', 'login-test@example.com');
    await page.fill('[data-testid="password-input"]', 'SecurePassword123!');

    // Submit login form
    await page.click('[data-testid="login-button"]');

    // Should redirect to dashboard
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="welcome-message"]')).toContainText('Welcome, Login Test User');
  });

  test('should display error for invalid login credentials', async ({ page }) => {
    await page.click('[data-testid="login-link"]');

    // Try to login with invalid credentials
    await page.fill('[data-testid="email-input"]', 'nonexistent@example.com');
    await page.fill('[data-testid="password-input"]', 'WrongPassword');
    await page.click('[data-testid="login-button"]');

    // Should show error message
    await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
    await expect(page.locator('[data-testid="error-message"]')).toContainText('Invalid credentials');
  });
});

test.describe('Order Management Journey', () => {
  let userToken;

  test.beforeEach(async ({ page }) => {
    // Create test user and login via API
    const userResponse = await page.request.post('/api/users', {
      data: {
        email: 'order-test@example.com',
        name: 'Order Test User',
        password: 'SecurePassword123!'
      }
    });

    const loginResponse = await page.request.post('/api/auth/login', {
      data: {
        email: 'order-test@example.com',
        password: 'SecurePassword123!'
      }
    });

    const loginData = await loginResponse.json();
    userToken = loginData.token;

    // Set auth token in browser
    await page.goto('/');
    await page.evaluate((token) => {
      localStorage.setItem('authToken', token);
    }, userToken);

    await page.goto('/dashboard');
  });

  test('should create a new order successfully', async ({ page }) => {
    // Navigate to create order page
    await page.click('[data-testid="create-order-button"]');
    await expect(page).toHaveURL('/orders/new');

    // Fill order form
    await page.selectOption('[data-testid="product-select"]', 'product-123');
    await page.fill('[data-testid="quantity-input"]', '2');

    // Submit order
    await page.click('[data-testid="submit-order-button"]');

    // Wait for success message
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await expect(page.locator('[data-testid="success-message"]')).toContainText('Order created successfully');

    // Should redirect to orders list
    await expect(page).toHaveURL('/orders');

    // Verify order appears in the list
    await expect(page.locator('[data-testid="order-item"]').first()).toBeVisible();
    await expect(page.locator('[data-testid="order-status"]').first()).toContainText('pending');
  });

  test('should display order validation errors', async ({ page }) => {
    await page.click('[data-testid="create-order-button"]');

    // Try to submit without selecting product
    await page.fill('[data-testid="quantity-input"]', '0');
    await page.click('[data-testid="submit-order-button"]');

    // Check validation errors
    await expect(page.locator('[data-testid="product-error"]')).toContainText('Product is required');
    await expect(page.locator('[data-testid="quantity-error"]')).toContainText('Quantity must be greater than 0');
  });

  test('should view order details', async ({ page }) => {
    // Create order via API
    const orderResponse = await page.request.post('/api/orders', {
      headers: {
        'Authorization': `Bearer ${userToken}`
      },
      data: {
        productId: 'product-123',
        quantity: 3,
        price: 2999
      }
    });

    const orderData = await orderResponse.json();

    // Navigate to orders page
    await page.goto('/orders');

    // Click on order to view details
    await page.click(`[data-testid="order-${orderData.id}"]`);
    await expect(page).toHaveURL(`/orders/${orderData.id}`);

    // Verify order details
    await expect(page.locator('[data-testid="order-id"]')).toContainText(orderData.id);
    await expect(page.locator('[data-testid="order-quantity"]')).toContainText('3');
    await expect(page.locator('[data-testid="order-price"]')).toContainText('$29.99');
    await expect(page.locator('[data-testid="order-status"]')).toContainText('pending');
  });

  test('should filter orders by status', async ({ page }) => {
    // Create multiple orders with different statuses via API
    const orders = [
      { productId: 'product-1', quantity: 1, price: 1000, status: 'pending' },
      { productId: 'product-2', quantity: 2, price: 2000, status: 'completed' },
      { productId: 'product-3', quantity: 3, price: 3000, status: 'pending' }
    ];

    for (const order of orders) {
      await page.request.post('/api/orders', {
        headers: { 'Authorization': `Bearer ${userToken}` },
        data: order
      });
    }

    await page.goto('/orders');

    // Filter by pending status
    await page.selectOption('[data-testid="status-filter"]', 'pending');
    await page.click('[data-testid="apply-filter-button"]');

    // Should show only pending orders
    const orderItems = page.locator('[data-testid="order-item"]');
    await expect(orderItems).toHaveCount(2);

    const statusElements = page.locator('[data-testid="order-status"]');
    for (let i = 0; i < await statusElements.count(); i++) {
      await expect(statusElements.nth(i)).toContainText('pending');
    }
  });

  test('should handle pagination in orders list', async ({ page }) => {
    // Create multiple orders to test pagination
    for (let i = 0; i < 15; i++) {
      await page.request.post('/api/orders', {
        headers: { 'Authorization': `Bearer ${userToken}` },
        data: {
          productId: `product-${i}`,
          quantity: 1,
          price: 1000 + i
        }
      });
    }

    await page.goto('/orders');

    // Should show first page with 10 orders
    const orderItems = page.locator('[data-testid="order-item"]');
    await expect(orderItems).toHaveCount(10);

    // Check pagination info
    await expect(page.locator('[data-testid="pagination-info"]')).toContainText('1-10 of 15');

    // Navigate to next page
    await page.click('[data-testid="next-page-button"]');
    await expect(orderItems).toHaveCount(5);
    await expect(page.locator('[data-testid="pagination-info"]')).toContainText('11-15 of 15');
  });
});

test.describe('User Profile Management', () => {
  let userToken;

  test.beforeEach(async ({ page }) => {
    // Setup authenticated user
    const userResponse = await page.request.post('/api/users', {
      data: {
        email: 'profile-test@example.com',
        name: 'Profile Test User',
        password: 'SecurePassword123!'
      }
    });

    const loginResponse = await page.request.post('/api/auth/login', {
      data: {
        email: 'profile-test@example.com',
        password: 'SecurePassword123!'
      }
    });

    const loginData = await loginResponse.json();
    userToken = loginData.token;

    await page.goto('/');
    await page.evaluate((token) => {
      localStorage.setItem('authToken', token);
    }, userToken);

    await page.goto('/profile');
  });

  test('should update user profile successfully', async ({ page }) => {
    // Update profile information
    await page.fill('[data-testid="name-input"]', 'Updated Profile User');
    await page.fill('[data-testid="email-input"]', 'updated-profile@example.com');

    await page.click('[data-testid="save-profile-button"]');

    // Wait for success message
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await expect(page.locator('[data-testid="success-message"]')).toContainText('Profile updated successfully');

    // Verify changes persist after page reload
    await page.reload();
    await expect(page.locator('[data-testid="name-input"]')).toHaveValue('Updated Profile User');
    await expect(page.locator('[data-testid="email-input"]')).toHaveValue('updated-profile@example.com');
  });

  test('should change password successfully', async ({ page }) => {
    // Navigate to change password section
    await page.click('[data-testid="change-password-tab"]');

    // Fill password change form
    await page.fill('[data-testid="current-password-input"]', 'SecurePassword123!');
    await page.fill('[data-testid="new-password-input"]', 'NewSecurePassword456!');
    await page.fill('[data-testid="confirm-new-password-input"]', 'NewSecurePassword456!');

    await page.click('[data-testid="change-password-button"]');

    // Wait for success message
    await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
    await expect(page.locator('[data-testid="success-message"]')).toContainText('Password changed successfully');

    // Verify can login with new password
    await page.click('[data-testid="logout-button"]');
    await page.click('[data-testid="login-link"]');

    await page.fill('[data-testid="email-input"]', 'profile-test@example.com');
    await page.fill('[data-testid="password-input"]', 'NewSecurePassword456!');
    await page.click('[data-testid="login-button"]');

    await expect(page).toHaveURL('/dashboard');
  });
});

test.describe('Cross-Service Integration', () => {
  test('should handle microservices communication flow', async ({ page }) => {
    // This test verifies the complete flow across multiple microservices
    
    // 1. User Service: Create user
    const userResponse = await page.request.post('/api/users', {
      data: {
        email: 'integration-test@example.com',
        name: 'Integration Test User',
        password: 'SecurePassword123!'
      }
    });
    expect(userResponse.status()).toBe(201);

    // 2. Auth Service: Login user
    const loginResponse = await page.request.post('/api/auth/login', {
      data: {
        email: 'integration-test@example.com',
        password: 'SecurePassword123!'
      }
    });
    expect(loginResponse.status()).toBe(200);
    const { token } = await loginResponse.json();

    // 3. Order Service: Create order
    const orderResponse = await page.request.post('/api/orders', {
      headers: { 'Authorization': `Bearer ${token}` },
      data: {
        productId: 'integration-product',
        quantity: 1,
        price: 9999
      }
    });
    expect(orderResponse.status()).toBe(201);
    const orderData = await orderResponse.json();

    // 4. Payment Service: Process payment
    const paymentResponse = await page.request.post('/api/payments', {
      headers: { 'Authorization': `Bearer ${token}` },
      data: {
        orderId: orderData.id,
        amount: 9999,
        paymentMethod: 'credit_card'
      }
    });
    expect(paymentResponse.status()).toBe(201);

    // 5. Verify order status updated
    const updatedOrderResponse = await page.request.get(`/api/orders/${orderData.id}`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    const updatedOrder = await updatedOrderResponse.json();
    expect(updatedOrder.status).toBe('paid');

    // 6. UI Verification: Check order status in UI
    await page.goto('/');
    await page.evaluate((token) => {
      localStorage.setItem('authToken', token);
    }, token);

    await page.goto('/orders');
    await expect(page.locator(`[data-testid="order-${orderData.id}"] [data-testid="order-status"]`))
      .toContainText('paid');
  });
});

test.describe('Error Handling and Edge Cases', () => {
  test('should handle network timeouts gracefully', async ({ page }) => {
    // Simulate slow network
    await page.route('/api/users', async route => {
      await new Promise(resolve => setTimeout(resolve, 35000)); // 35 second delay
      await route.continue();
    });

    await page.goto('/register');
    await page.fill('[data-testid="email-input"]', 'timeout-test@example.com');
    await page.fill('[data-testid="name-input"]', 'Timeout Test');
    await page.fill('[data-testid="password-input"]', 'SecurePassword123!');
    
    await page.click('[data-testid="register-button"]');

    // Should show timeout error
    await expect(page.locator('[data-testid="error-message"]')).toBeVisible({ timeout: 40000 });
    await expect(page.locator('[data-testid="error-message"]')).toContainText('Request timeout');
  });

  test('should handle server errors gracefully', async ({ page }) => {
    // Mock server error
    await page.route('/api/users', route => {
      route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({
          error: 'Internal Server Error',
          message: 'Database connection failed'
        })
      });
    });

    await page.goto('/register');
    await page.fill('[data-testid="email-input"]', 'error-test@example.com');
    await page.fill('[data-testid="name-input"]', 'Error Test');
    await page.fill('[data-testid="password-input"]', 'SecurePassword123!');
    
    await page.click('[data-testid="register-button"]');

    // Should show server error message
    await expect(page.locator('[data-testid="error-message"]')).toBeVisible();
    await expect(page.locator('[data-testid="error-message"]')).toContainText('Server error occurred');
  });

  test('should handle authentication token expiry', async ({ page }) => {
    // Set expired token
    await page.goto('/');
    await page.evaluate(() => {
      localStorage.setItem('authToken', 'expired.jwt.token');
    });

    // Try to access protected route
    await page.goto('/orders');

    // Should redirect to login
    await expect(page).toHaveURL('/login');
    await expect(page.locator('[data-testid="error-message"]')).toContainText('Session expired');
  });
});

test.describe('Performance and Load Testing', () => {
  test('should handle multiple concurrent user sessions', async ({ browser }) => {
    const contexts = [];
    const promises = [];

    // Create 5 concurrent user sessions
    for (let i = 0; i < 5; i++) {
      const context = await browser.newContext();
      contexts.push(context);
      
      const page = await context.newPage();
      
      const promise = (async () => {
        await page.goto('/register');
        await page.fill('[data-testid="email-input"]', `concurrent-${i}@example.com`);
        await page.fill('[data-testid="name-input"]', `Concurrent User ${i}`);
        await page.fill('[data-testid="password-input"]', 'SecurePassword123!');
        await page.click('[data-testid="register-button"]');
        
        await expect(page.locator('[data-testid="success-message"]')).toBeVisible();
        return page;
      })();
      
      promises.push(promise);
    }

    // Wait for all sessions to complete
    const pages = await Promise.all(promises);
    
    // Verify all registrations succeeded
    pages.forEach((page, index) => {
      expect(page.url()).toContain('/login');
    });

    // Cleanup
    for (const context of contexts) {
      await context.close();
    }
  });

  test('should load pages within performance thresholds', async ({ page }) => {
    // Test homepage load time
    const startTime = Date.now();
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    const homeLoadTime = Date.now() - startTime;

    expect(homeLoadTime).toBeLessThan(3000); // Should load within 3 seconds

    // Test dashboard load time (authenticated page)
    const userResponse = await page.request.post('/api/users', {
      data: {
        email: 'perf-test@example.com',
        name: 'Performance Test',
        password: 'SecurePassword123!'
      }
    });

    const loginResponse = await page.request.post('/api/auth/login', {
      data: {
        email: 'perf-test@example.com',
        password: 'SecurePassword123!'
      }
    });

    const { token } = await loginResponse.json();
    await page.evaluate((token) => {
      localStorage.setItem('authToken', token);
    }, token);

    const dashboardStartTime = Date.now();
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    const dashboardLoadTime = Date.now() - dashboardStartTime;

    expect(dashboardLoadTime).toBeLessThan(5000); // Should load within 5 seconds
  });
});
