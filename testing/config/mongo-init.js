// MongoDB initialization script for test database
db.getSiblingDB('test_microservices');

// Create test collections
db.createCollection('users');
db.createCollection('orders');
db.createCollection('products');
db.createCollection('sessions');

// Insert test data
db.users.insertMany([
  {
    _id: ObjectId('507f1f77bcf86cd799439011'),
    username: 'testuser1',
    email: 'test1@example.com',
    password: '$2b$10$hash1',
    createdAt: new Date(),
    status: 'active'
  },
  {
    _id: ObjectId('507f1f77bcf86cd799439012'),
    username: 'testuser2', 
    email: 'test2@example.com',
    password: '$2b$10$hash2',
    createdAt: new Date(),
    status: 'active'
  }
]);

db.products.insertMany([
  {
    _id: ObjectId('507f1f77bcf86cd799439021'),
    name: 'Test Product 1',
    description: 'A test product for testing',
    price: 29.99,
    category: 'electronics',
    inStock: true
  },
  {
    _id: ObjectId('507f1f77bcf86cd799439022'),
    name: 'Test Product 2',
    description: 'Another test product',
    price: 49.99,
    category: 'books',
    inStock: true
  }
]);

// Create indexes
db.users.createIndex({ email: 1 }, { unique: true });
db.users.createIndex({ username: 1 }, { unique: true });
db.products.createIndex({ name: 1 });
db.orders.createIndex({ userId: 1 });
db.sessions.createIndex({ userId: 1 });

print('Test database initialized successfully');
