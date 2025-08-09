/**
 * API Integration Tests
 * 
 * These tests verify the complete API functionality including:
 * - HTTP endpoints
 * - Database integration
 * - Authentication/Authorization
 * - Request/Response validation
 * - Error handling
 */

const request = require('supertest');
const { MongoMemoryServer } = require('mongodb-memory-server');
const app = require('../../src/app');
const User = require('../../src/models/User');
const Order = require('../../src/models/Order');

describe('API Integration Tests', () => {
  let mongoServer;
  let mongoUri;

  // Setup test database
  beforeAll(async () => {
    mongoServer = await MongoMemoryServer.create();
    mongoUri = mongoServer.getUri();
    process.env.MONGODB_URI = mongoUri;
    
    // Initialize database connection
    await require('../../src/config/database').connect();
  });

  // Cleanup test database
  afterAll(async () => {
    await require('../../src/config/database').disconnect();
    await mongoServer.stop();
  });

  // Clean database between tests
  beforeEach(async () => {
    await User.deleteMany({});
    await Order.deleteMany({});
  });

  describe('User API Endpoints', () => {
    describe('POST /api/users', () => {
      const validUserData = {
        email: 'test@example.com',
        name: 'Test User',
        password: 'SecurePassword123!'
      };

      it('should create a new user with valid data', async () => {
        const response = await request(app)
          .post('/api/users')
          .send(validUserData)
          .expect(201);

        expect(response.body).toMatchObject({
          id: expect.any(String),
          email: validUserData.email,
          name: validUserData.name,
          createdAt: expect.any(String),
          updatedAt: expect.any(String)
        });

        expect(response.body).not.toHaveProperty('password');

        // Verify user was created in database
        const userInDb = await User.findById(response.body.id);
        expect(userInDb).toBeTruthy();
        expect(userInDb.email).toBe(validUserData.email);
      });

      it('should return 400 for invalid email', async () => {
        const response = await request(app)
          .post('/api/users')
          .send({
            ...validUserData,
            email: 'invalid-email'
          })
          .expect(400);

        expect(response.body).toMatchObject({
          error: 'Validation Error',
          message: expect.stringContaining('email')
        });
      });

      it('should return 400 for weak password', async () => {
        const response = await request(app)
          .post('/api/users')
          .send({
            ...validUserData,
            password: '123'
          })
          .expect(400);

        expect(response.body).toMatchObject({
          error: 'Validation Error',
          message: expect.stringContaining('password')
        });
      });

      it('should return 409 for duplicate email', async () => {
        // Create first user
        await request(app)
          .post('/api/users')
          .send(validUserData)
          .expect(201);

        // Try to create user with same email
        const response = await request(app)
          .post('/api/users')
          .send(validUserData)
          .expect(409);

        expect(response.body).toMatchObject({
          error: 'Conflict',
          message: expect.stringContaining('already exists')
        });
      });

      it('should handle concurrent user creation', async () => {
        const promises = Array.from({ length: 5 }, (_, index) =>
          request(app)
            .post('/api/users')
            .send({
              ...validUserData,
              email: `test${index}@example.com`
            })
        );

        const responses = await Promise.all(promises);
        
        responses.forEach(response => {
          expect(response.status).toBe(201);
          expect(response.body).toHaveProperty('id');
        });

        const usersInDb = await User.find({});
        expect(usersInDb).toHaveLength(5);
      });
    });

    describe('GET /api/users/:id', () => {
      let createdUser;

      beforeEach(async () => {
        const response = await request(app)
          .post('/api/users')
          .send({
            email: 'test@example.com',
            name: 'Test User',
            password: 'SecurePassword123!'
          });
        createdUser = response.body;
      });

      it('should return user by ID', async () => {
        const response = await request(app)
          .get(`/api/users/${createdUser.id}`)
          .expect(200);

        expect(response.body).toMatchObject({
          id: createdUser.id,
          email: createdUser.email,
          name: createdUser.name
        });

        expect(response.body).not.toHaveProperty('password');
      });

      it('should return 404 for non-existent user', async () => {
        const nonExistentId = '507f1f77bcf86cd799439011';
        
        const response = await request(app)
          .get(`/api/users/${nonExistentId}`)
          .expect(404);

        expect(response.body).toMatchObject({
          error: 'Not Found',
          message: 'User not found'
        });
      });

      it('should return 400 for invalid user ID format', async () => {
        const response = await request(app)
          .get('/api/users/invalid-id')
          .expect(400);

        expect(response.body).toMatchObject({
          error: 'Validation Error',
          message: expect.stringContaining('Invalid ID format')
        });
      });
    });

    describe('PUT /api/users/:id', () => {
      let createdUser;
      let authToken;

      beforeEach(async () => {
        // Create user and get auth token
        const userResponse = await request(app)
          .post('/api/users')
          .send({
            email: 'test@example.com',
            name: 'Test User',
            password: 'SecurePassword123!'
          });
        createdUser = userResponse.body;

        // Login to get auth token
        const loginResponse = await request(app)
          .post('/api/auth/login')
          .send({
            email: 'test@example.com',
            password: 'SecurePassword123!'
          });
        authToken = loginResponse.body.token;
      });

      it('should update user with valid data', async () => {
        const updateData = {
          name: 'Updated Name',
          email: 'updated@example.com'
        };

        const response = await request(app)
          .put(`/api/users/${createdUser.id}`)
          .set('Authorization', `Bearer ${authToken}`)
          .send(updateData)
          .expect(200);

        expect(response.body).toMatchObject({
          id: createdUser.id,
          name: updateData.name,
          email: updateData.email,
          updatedAt: expect.any(String)
        });

        // Verify update in database
        const userInDb = await User.findById(createdUser.id);
        expect(userInDb.name).toBe(updateData.name);
        expect(userInDb.email).toBe(updateData.email);
      });

      it('should return 401 without authentication', async () => {
        const response = await request(app)
          .put(`/api/users/${createdUser.id}`)
          .send({ name: 'Updated Name' })
          .expect(401);

        expect(response.body).toMatchObject({
          error: 'Unauthorized',
          message: 'Authentication required'
        });
      });

      it('should return 403 when updating other user', async () => {
        // Create another user
        const otherUserResponse = await request(app)
          .post('/api/users')
          .send({
            email: 'other@example.com',
            name: 'Other User',
            password: 'SecurePassword123!'
          });

        const response = await request(app)
          .put(`/api/users/${otherUserResponse.body.id}`)
          .set('Authorization', `Bearer ${authToken}`)
          .send({ name: 'Hacked Name' })
          .expect(403);

        expect(response.body).toMatchObject({
          error: 'Forbidden',
          message: 'Access denied'
        });
      });
    });
  });

  describe('Order API Endpoints', () => {
    let testUser;
    let authToken;

    beforeEach(async () => {
      // Create test user
      const userResponse = await request(app)
        .post('/api/users')
        .send({
          email: 'test@example.com',
          name: 'Test User',
          password: 'SecurePassword123!'
        });
      testUser = userResponse.body;

      // Login to get auth token
      const loginResponse = await request(app)
        .post('/api/auth/login')
        .send({
          email: 'test@example.com',
          password: 'SecurePassword123!'
        });
      authToken = loginResponse.body.token;
    });

    describe('POST /api/orders', () => {
      const validOrderData = {
        productId: 'product-123',
        quantity: 2,
        price: 1999
      };

      it('should create order with valid data', async () => {
        const response = await request(app)
          .post('/api/orders')
          .set('Authorization', `Bearer ${authToken}`)
          .send(validOrderData)
          .expect(201);

        expect(response.body).toMatchObject({
          id: expect.any(String),
          userId: testUser.id,
          productId: validOrderData.productId,
          quantity: validOrderData.quantity,
          price: validOrderData.price,
          status: 'pending',
          createdAt: expect.any(String)
        });

        // Verify order in database
        const orderInDb = await Order.findById(response.body.id);
        expect(orderInDb).toBeTruthy();
        expect(orderInDb.userId.toString()).toBe(testUser.id);
      });

      it('should return 401 without authentication', async () => {
        const response = await request(app)
          .post('/api/orders')
          .send(validOrderData)
          .expect(401);

        expect(response.body).toMatchObject({
          error: 'Unauthorized',
          message: 'Authentication required'
        });
      });

      it('should return 400 for invalid order data', async () => {
        const response = await request(app)
          .post('/api/orders')
          .set('Authorization', `Bearer ${authToken}`)
          .send({
            productId: '',
            quantity: -1,
            price: 'invalid'
          })
          .expect(400);

        expect(response.body).toMatchObject({
          error: 'Validation Error',
          message: expect.any(String)
        });
      });
    });

    describe('GET /api/orders', () => {
      beforeEach(async () => {
        // Create multiple orders for testing
        const orders = [
          { productId: 'product-1', quantity: 1, price: 1000 },
          { productId: 'product-2', quantity: 2, price: 2000 },
          { productId: 'product-3', quantity: 3, price: 3000 }
        ];

        for (const order of orders) {
          await request(app)
            .post('/api/orders')
            .set('Authorization', `Bearer ${authToken}`)
            .send(order);
        }
      });

      it('should return user orders with pagination', async () => {
        const response = await request(app)
          .get('/api/orders?page=1&limit=2')
          .set('Authorization', `Bearer ${authToken}`)
          .expect(200);

        expect(response.body).toMatchObject({
          orders: expect.arrayContaining([
            expect.objectContaining({
              id: expect.any(String),
              userId: testUser.id,
              status: 'pending'
            })
          ]),
          pagination: {
            page: 1,
            limit: 2,
            total: 3,
            pages: 2
          }
        });

        expect(response.body.orders).toHaveLength(2);
      });

      it('should filter orders by status', async () => {
        // Update one order status
        const orders = await Order.find({ userId: testUser.id });
        await Order.findByIdAndUpdate(orders[0]._id, { status: 'completed' });

        const response = await request(app)
          .get('/api/orders?status=pending')
          .set('Authorization', `Bearer ${authToken}`)
          .expect(200);

        expect(response.body.orders).toHaveLength(2);
        response.body.orders.forEach(order => {
          expect(order.status).toBe('pending');
        });
      });
    });
  });

  describe('Authentication Flow', () => {
    const userData = {
      email: 'auth@example.com',
      name: 'Auth User',
      password: 'SecurePassword123!'
    };

    beforeEach(async () => {
      await request(app)
        .post('/api/users')
        .send(userData);
    });

    describe('POST /api/auth/login', () => {
      it('should login with valid credentials', async () => {
        const response = await request(app)
          .post('/api/auth/login')
          .send({
            email: userData.email,
            password: userData.password
          })
          .expect(200);

        expect(response.body).toMatchObject({
          token: expect.any(String),
          user: {
            id: expect.any(String),
            email: userData.email,
            name: userData.name
          }
        });

        expect(response.body.user).not.toHaveProperty('password');
      });

      it('should return 401 for invalid credentials', async () => {
        const response = await request(app)
          .post('/api/auth/login')
          .send({
            email: userData.email,
            password: 'WrongPassword'
          })
          .expect(401);

        expect(response.body).toMatchObject({
          error: 'Unauthorized',
          message: 'Invalid credentials'
        });
      });

      it('should return 404 for non-existent user', async () => {
        const response = await request(app)
          .post('/api/auth/login')
          .send({
            email: 'nonexistent@example.com',
            password: 'AnyPassword'
          })
          .expect(404);

        expect(response.body).toMatchObject({
          error: 'Not Found',
          message: 'User not found'
        });
      });
    });

    describe('POST /api/auth/logout', () => {
      let authToken;

      beforeEach(async () => {
        const loginResponse = await request(app)
          .post('/api/auth/login')
          .send({
            email: userData.email,
            password: userData.password
          });
        authToken = loginResponse.body.token;
      });

      it('should logout successfully', async () => {
        const response = await request(app)
          .post('/api/auth/logout')
          .set('Authorization', `Bearer ${authToken}`)
          .expect(200);

        expect(response.body).toMatchObject({
          message: 'Logout successful'
        });

        // Verify token is invalidated
        await request(app)
          .get('/api/users/me')
          .set('Authorization', `Bearer ${authToken}`)
          .expect(401);
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle 404 for non-existent endpoints', async () => {
      const response = await request(app)
        .get('/api/non-existent')
        .expect(404);

      expect(response.body).toMatchObject({
        error: 'Not Found',
        message: 'Endpoint not found'
      });
    });

    it('should handle malformed JSON', async () => {
      const response = await request(app)
        .post('/api/users')
        .set('Content-Type', 'application/json')
        .send('{ invalid json }')
        .expect(400);

      expect(response.body).toMatchObject({
        error: 'Bad Request',
        message: expect.stringContaining('JSON')
      });
    });

    it('should handle database connection errors', async () => {
      // Simulate database disconnect
      await require('../../src/config/database').disconnect();

      const response = await request(app)
        .get('/api/users/507f1f77bcf86cd799439011')
        .expect(500);

      expect(response.body).toMatchObject({
        error: 'Internal Server Error',
        message: 'Database connection error'
      });

      // Reconnect for other tests
      await require('../../src/config/database').connect();
    });
  });

  describe('Performance Tests', () => {
    it('should handle high concurrent user creation', async () => {
      const startTime = Date.now();
      
      const promises = Array.from({ length: 50 }, (_, index) =>
        request(app)
          .post('/api/users')
          .send({
            email: `perf-test-${index}@example.com`,
            name: `Performance Test User ${index}`,
            password: 'SecurePassword123!'
          })
      );

      const responses = await Promise.all(promises);
      const endTime = Date.now();
      const executionTime = endTime - startTime;

      // All requests should succeed
      responses.forEach(response => {
        expect(response.status).toBe(201);
      });

      // Should complete within reasonable time
      expect(executionTime).toBeWithinPerformanceThreshold(10000); // 10 seconds

      // Verify all users were created
      const usersInDb = await User.find({});
      expect(usersInDb).toHaveLength(50);
    });

    it('should handle API response time requirements', async () => {
      // Create test user
      const userResponse = await request(app)
        .post('/api/users')
        .send({
          email: 'perf@example.com',
          name: 'Performance User',
          password: 'SecurePassword123!'
        });

      const startTime = Date.now();
      
      await request(app)
        .get(`/api/users/${userResponse.body.id}`)
        .expect(200);
        
      const endTime = Date.now();
      const responseTime = endTime - startTime;

      expect(responseTime).toBeWithinPerformanceThreshold(200); // Should respond within 200ms
    });
  });
});
