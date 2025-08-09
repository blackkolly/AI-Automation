const { MongoMemoryServer } = require('mongodb-memory-server');
const { RedisMemoryServer } = require('redis-memory-server');
const path = require('path');

// Load environment variables for testing
require('dotenv').config({
  path: path.resolve(__dirname, '.env.test')
});

// Global test configuration
global.TEST_CONFIG = {
  timeout: 30000,
  retries: 2,
  mongodb: null,
  redis: null
};

// Console methods to ignore during tests
const originalError = console.error;
const originalWarn = console.warn;

// Global setup - runs once before all tests
beforeAll(async () => {
  // Suppress specific console outputs during tests
  console.error = (...args) => {
    if (
      typeof args[0] === 'string' && 
      (args[0].includes('Warning:') || args[0].includes('Deprecation'))
    ) {
      return;
    }
    originalError.call(console, ...args);
  };
  
  console.warn = (...args) => {
    if (
      typeof args[0] === 'string' && 
      args[0].includes('ExperimentalWarning')
    ) {
      return;
    }
    originalWarn.call(console, ...args);
  };

  // Start in-memory MongoDB for integration tests
  if (process.env.USE_MEMORY_DB === 'true') {
    global.TEST_CONFIG.mongodb = await MongoMemoryServer.create({
      instance: {
        port: 27017,
        dbName: 'test_microservices'
      }
    });
    process.env.MONGODB_URI = global.TEST_CONFIG.mongodb.getUri();
  }

  // Start in-memory Redis for integration tests
  if (process.env.USE_MEMORY_REDIS === 'true') {
    global.TEST_CONFIG.redis = new RedisMemoryServer({
      instance: {
        port: 6379
      }
    });
    await global.TEST_CONFIG.redis.start();
    process.env.REDIS_URI = await global.TEST_CONFIG.redis.getConnectionString();
  }

  // Set test environment variables
  process.env.NODE_ENV = 'test';
  process.env.LOG_LEVEL = 'error';
  process.env.PORT = '0'; // Use random available port
  
  console.log('🧪 Test environment initialized');
});

// Global cleanup - runs once after all tests
afterAll(async () => {
  // Restore console methods
  console.error = originalError;
  console.warn = originalWarn;

  // Stop in-memory databases
  if (global.TEST_CONFIG.mongodb) {
    await global.TEST_CONFIG.mongodb.stop();
  }
  
  if (global.TEST_CONFIG.redis) {
    await global.TEST_CONFIG.redis.stop();
  }

  // Force cleanup of any remaining handles
  if (process.env.NODE_ENV === 'test') {
    setTimeout(() => {
      process.exit(0);
    }, 1000);
  }

  console.log('🧹 Test environment cleaned up');
});

// Individual test setup
beforeEach(() => {
  // Clear all mocks before each test
  jest.clearAllMocks();
  
  // Reset any global state
  if (global.testState) {
    global.testState = {};
  }
});

// Individual test cleanup
afterEach(async () => {
  // Clean up any test data
  if (process.env.CLEANUP_AFTER_EACH === 'true') {
    // Add cleanup logic here
  }
});

// Global error handler for unhandled rejections
process.on('unhandledRejection', (reason, promise) => {
  console.error('Unhandled Rejection at:', promise, 'reason:', reason);
  // Don't exit in test environment, just log
});

// Global error handler for uncaught exceptions
process.on('uncaughtException', (error) => {
  console.error('Uncaught Exception:', error);
  // Don't exit in test environment, just log
});

// Custom matchers for Jest
expect.extend({
  // Custom matcher for API response testing
  toBeValidApiResponse(received) {
    const pass = received && 
                 typeof received.status === 'number' &&
                 received.status >= 200 && 
                 received.status < 400;
    
    if (pass) {
      return {
        message: () => `expected ${received} not to be a valid API response`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be a valid API response`,
        pass: false,
      };
    }
  },

  // Custom matcher for database record testing
  toBeValidDatabaseRecord(received) {
    const pass = received && 
                 received._id && 
                 received.createdAt && 
                 received.updatedAt;
    
    if (pass) {
      return {
        message: () => `expected ${received} not to be a valid database record`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be a valid database record`,
        pass: false,
      };
    }
  },

  // Custom matcher for performance testing
  toBeWithinPerformanceThreshold(received, threshold) {
    const pass = received <= threshold;
    
    if (pass) {
      return {
        message: () => `expected ${received}ms not to be within performance threshold of ${threshold}ms`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received}ms to be within performance threshold of ${threshold}ms`,
        pass: false,
      };
    }
  }
});

// Test utilities available globally
global.testUtils = {
  // Generate random test data
  generateTestUser: () => ({
    id: Math.random().toString(36).substr(2, 9),
    email: `test-${Date.now()}@example.com`,
    name: `Test User ${Date.now()}`,
    createdAt: new Date(),
    updatedAt: new Date()
  }),

  // Generate random test order
  generateTestOrder: () => ({
    id: Math.random().toString(36).substr(2, 9),
    userId: Math.random().toString(36).substr(2, 9),
    productId: Math.random().toString(36).substr(2, 9),
    quantity: Math.floor(Math.random() * 10) + 1,
    price: Math.floor(Math.random() * 10000) + 100,
    status: 'pending',
    createdAt: new Date(),
    updatedAt: new Date()
  }),

  // Wait utility for async operations
  wait: (ms) => new Promise(resolve => setTimeout(resolve, ms)),

  // Retry utility for flaky operations
  retry: async (fn, maxAttempts = 3, delay = 1000) => {
    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (error) {
        if (attempt === maxAttempts) {
          throw error;
        }
        await global.testUtils.wait(delay);
      }
    }
  }
};

// Mock implementations for external services
global.mockImplementations = {
  // Mock HTTP client
  mockHttpClient: {
    get: jest.fn(),
    post: jest.fn(),
    put: jest.fn(),
    delete: jest.fn(),
    patch: jest.fn()
  },

  // Mock database client
  mockDatabaseClient: {
    connect: jest.fn(),
    disconnect: jest.fn(),
    create: jest.fn(),
    findById: jest.fn(),
    findAll: jest.fn(),
    update: jest.fn(),
    delete: jest.fn()
  },

  // Mock message queue client
  mockMessageQueue: {
    connect: jest.fn(),
    disconnect: jest.fn(),
    publish: jest.fn(),
    subscribe: jest.fn(),
    unsubscribe: jest.fn()
  }
};

console.log('🏗️ Jest setup completed successfully');
