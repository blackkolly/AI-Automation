/**
 * User Service Unit Tests
 * 
 * These tests verify the core business logic of the User Service
 * without external dependencies (databases, APIs, etc.)
 */

const UserService = require('../../src/services/UserService');
const UserRepository = require('../../src/repositories/UserRepository');
const EmailService = require('../../src/services/EmailService');
const ValidationError = require('../../src/errors/ValidationError');

// Mock external dependencies
jest.mock('../../src/repositories/UserRepository');
jest.mock('../../src/services/EmailService');

describe('UserService', () => {
  let userService;
  let mockUserRepository;
  let mockEmailService;

  beforeEach(() => {
    // Clear all mocks
    jest.clearAllMocks();
    
    // Create mock instances
    mockUserRepository = new UserRepository();
    mockEmailService = new EmailService();
    
    // Create service instance with mocked dependencies
    userService = new UserService(mockUserRepository, mockEmailService);
  });

  describe('createUser', () => {
    const validUserData = {
      email: 'test@example.com',
      name: 'Test User',
      password: 'SecurePassword123!'
    };

    it('should create a user with valid data', async () => {
      // Arrange
      const expectedUser = {
        id: 'user-123',
        ...validUserData,
        password: 'hashedPassword',
        createdAt: new Date(),
        updatedAt: new Date()
      };

      mockUserRepository.findByEmail.mockResolvedValue(null);
      mockUserRepository.create.mockResolvedValue(expectedUser);
      mockEmailService.sendWelcomeEmail.mockResolvedValue(true);

      // Act
      const result = await userService.createUser(validUserData);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(mockUserRepository.findByEmail).toHaveBeenCalledWith(validUserData.email);
      expect(mockUserRepository.create).toHaveBeenCalledWith(
        expect.objectContaining({
          email: validUserData.email,
          name: validUserData.name,
          password: expect.not.stringMatching(validUserData.password) // Password should be hashed
        })
      );
      expect(mockEmailService.sendWelcomeEmail).toHaveBeenCalledWith(expectedUser);
    });

    it('should throw ValidationError for invalid email', async () => {
      // Arrange
      const invalidUserData = {
        ...validUserData,
        email: 'invalid-email'
      };

      // Act & Assert
      await expect(userService.createUser(invalidUserData))
        .rejects
        .toThrow(ValidationError);
      
      expect(mockUserRepository.findByEmail).not.toHaveBeenCalled();
      expect(mockUserRepository.create).not.toHaveBeenCalled();
    });

    it('should throw ValidationError for weak password', async () => {
      // Arrange
      const weakPasswordData = {
        ...validUserData,
        password: '123'
      };

      // Act & Assert
      await expect(userService.createUser(weakPasswordData))
        .rejects
        .toThrow(ValidationError);
      
      expect(mockUserRepository.findByEmail).not.toHaveBeenCalled();
      expect(mockUserRepository.create).not.toHaveBeenCalled();
    });

    it('should throw error if user already exists', async () => {
      // Arrange
      const existingUser = { id: 'existing-user', email: validUserData.email };
      mockUserRepository.findByEmail.mockResolvedValue(existingUser);

      // Act & Assert
      await expect(userService.createUser(validUserData))
        .rejects
        .toThrow('User already exists');
      
      expect(mockUserRepository.findByEmail).toHaveBeenCalledWith(validUserData.email);
      expect(mockUserRepository.create).not.toHaveBeenCalled();
    });

    it('should handle email service failure gracefully', async () => {
      // Arrange
      const expectedUser = {
        id: 'user-123',
        ...validUserData,
        password: 'hashedPassword',
        createdAt: new Date(),
        updatedAt: new Date()
      };

      mockUserRepository.findByEmail.mockResolvedValue(null);
      mockUserRepository.create.mockResolvedValue(expectedUser);
      mockEmailService.sendWelcomeEmail.mockRejectedValue(new Error('Email service down'));

      // Act
      const result = await userService.createUser(validUserData);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(mockEmailService.sendWelcomeEmail).toHaveBeenCalledWith(expectedUser);
      // User should still be created even if email fails
    });
  });

  describe('getUserById', () => {
    it('should return user when found', async () => {
      // Arrange
      const userId = 'user-123';
      const expectedUser = {
        id: userId,
        email: 'test@example.com',
        name: 'Test User',
        createdAt: new Date(),
        updatedAt: new Date()
      };

      mockUserRepository.findById.mockResolvedValue(expectedUser);

      // Act
      const result = await userService.getUserById(userId);

      // Assert
      expect(result).toEqual(expectedUser);
      expect(mockUserRepository.findById).toHaveBeenCalledWith(userId);
    });

    it('should return null when user not found', async () => {
      // Arrange
      const userId = 'non-existent-user';
      mockUserRepository.findById.mockResolvedValue(null);

      // Act
      const result = await userService.getUserById(userId);

      // Assert
      expect(result).toBeNull();
      expect(mockUserRepository.findById).toHaveBeenCalledWith(userId);
    });

    it('should throw ValidationError for invalid user ID format', async () => {
      // Arrange
      const invalidUserId = '';

      // Act & Assert
      await expect(userService.getUserById(invalidUserId))
        .rejects
        .toThrow(ValidationError);
      
      expect(mockUserRepository.findById).not.toHaveBeenCalled();
    });
  });

  describe('updateUser', () => {
    const userId = 'user-123';
    const updateData = {
      name: 'Updated Name',
      email: 'updated@example.com'
    };

    it('should update user successfully', async () => {
      // Arrange
      const existingUser = {
        id: userId,
        email: 'old@example.com',
        name: 'Old Name',
        createdAt: new Date(),
        updatedAt: new Date()
      };

      const updatedUser = {
        ...existingUser,
        ...updateData,
        updatedAt: new Date()
      };

      mockUserRepository.findById.mockResolvedValue(existingUser);
      mockUserRepository.update.mockResolvedValue(updatedUser);

      // Act
      const result = await userService.updateUser(userId, updateData);

      // Assert
      expect(result).toEqual(updatedUser);
      expect(mockUserRepository.findById).toHaveBeenCalledWith(userId);
      expect(mockUserRepository.update).toHaveBeenCalledWith(userId, updateData);
    });

    it('should throw error when user not found', async () => {
      // Arrange
      mockUserRepository.findById.mockResolvedValue(null);

      // Act & Assert
      await expect(userService.updateUser(userId, updateData))
        .rejects
        .toThrow('User not found');
      
      expect(mockUserRepository.findById).toHaveBeenCalledWith(userId);
      expect(mockUserRepository.update).not.toHaveBeenCalled();
    });

    it('should validate email format when updating email', async () => {
      // Arrange
      const existingUser = { id: userId, email: 'old@example.com', name: 'Old Name' };
      const invalidUpdateData = { email: 'invalid-email' };

      mockUserRepository.findById.mockResolvedValue(existingUser);

      // Act & Assert
      await expect(userService.updateUser(userId, invalidUpdateData))
        .rejects
        .toThrow(ValidationError);
      
      expect(mockUserRepository.update).not.toHaveBeenCalled();
    });
  });

  describe('deleteUser', () => {
    const userId = 'user-123';

    it('should delete user successfully', async () => {
      // Arrange
      const existingUser = {
        id: userId,
        email: 'test@example.com',
        name: 'Test User'
      };

      mockUserRepository.findById.mockResolvedValue(existingUser);
      mockUserRepository.delete.mockResolvedValue(true);

      // Act
      const result = await userService.deleteUser(userId);

      // Assert
      expect(result).toBe(true);
      expect(mockUserRepository.findById).toHaveBeenCalledWith(userId);
      expect(mockUserRepository.delete).toHaveBeenCalledWith(userId);
    });

    it('should throw error when user not found', async () => {
      // Arrange
      mockUserRepository.findById.mockResolvedValue(null);

      // Act & Assert
      await expect(userService.deleteUser(userId))
        .rejects
        .toThrow('User not found');
      
      expect(mockUserRepository.findById).toHaveBeenCalledWith(userId);
      expect(mockUserRepository.delete).not.toHaveBeenCalled();
    });
  });

  describe('validateUserData', () => {
    it('should validate correct user data', () => {
      // Arrange
      const validData = {
        email: 'test@example.com',
        name: 'Test User',
        password: 'SecurePassword123!'
      };

      // Act
      const result = userService.validateUserData(validData);

      // Assert
      expect(result.isValid).toBe(true);
      expect(result.errors).toHaveLength(0);
    });

    it('should return validation errors for invalid data', () => {
      // Arrange
      const invalidData = {
        email: 'invalid-email',
        name: '',
        password: '123'
      };

      // Act
      const result = userService.validateUserData(invalidData);

      // Assert
      expect(result.isValid).toBe(false);
      expect(result.errors).toContain('Invalid email format');
      expect(result.errors).toContain('Name is required');
      expect(result.errors).toContain('Password too weak');
    });
  });

  describe('hashPassword', () => {
    it('should hash password correctly', async () => {
      // Arrange
      const plainPassword = 'SecurePassword123!';

      // Act
      const hashedPassword = await userService.hashPassword(plainPassword);

      // Assert
      expect(hashedPassword).not.toBe(plainPassword);
      expect(hashedPassword).toMatch(/^\$2[aby]\$\d+\$/); // bcrypt format
      expect(hashedPassword.length).toBeGreaterThan(50);
    });

    it('should generate different hashes for same password', async () => {
      // Arrange
      const plainPassword = 'SecurePassword123!';

      // Act
      const hash1 = await userService.hashPassword(plainPassword);
      const hash2 = await userService.hashPassword(plainPassword);

      // Assert
      expect(hash1).not.toBe(hash2);
    });
  });

  describe('performance tests', () => {
    it('should create user within performance threshold', async () => {
      // Arrange
      const userData = global.testUtils.generateTestUser();
      mockUserRepository.findByEmail.mockResolvedValue(null);
      mockUserRepository.create.mockResolvedValue(userData);
      mockEmailService.sendWelcomeEmail.mockResolvedValue(true);

      // Act
      const startTime = Date.now();
      await userService.createUser(userData);
      const endTime = Date.now();
      const executionTime = endTime - startTime;

      // Assert
      expect(executionTime).toBeWithinPerformanceThreshold(1000); // Should complete within 1 second
    });
  });
});
