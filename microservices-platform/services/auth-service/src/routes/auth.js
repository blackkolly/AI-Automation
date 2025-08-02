const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const { v4: uuidv4 } = require('uuid');

const router = express.Router();

// Validation schemas
const registerSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().min(8).required(),
  firstName: Joi.string().min(2).max(50).required(),
  lastName: Joi.string().min(2).max(50).required()
});

const loginSchema = Joi.object({
  email: Joi.string().email().required(),
  password: Joi.string().required()
});

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '24h';
const REFRESH_TOKEN_EXPIRES_IN = process.env.REFRESH_TOKEN_EXPIRES_IN || '7d';

// Helper function to generate tokens
const generateTokens = (user) => {
  const jti = uuidv4();
  
  const accessToken = jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
      jti: jti
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );

  const refreshToken = jwt.sign(
    {
      id: user.id,
      jti: jti,
      type: 'refresh'
    },
    JWT_SECRET,
    { expiresIn: REFRESH_TOKEN_EXPIRES_IN }
  );

  return { accessToken, refreshToken, jti };
};

// Register endpoint
router.post('/register', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const logger = req.app.locals.logger;

    // Validate request body
    const { error, value } = registerSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(d => d.message)
      });
    }

    const { email, password, firstName, lastName } = value;

    // Check if user already exists
    const existingUser = await db.query(
      'SELECT id FROM users WHERE email = $1',
      [email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(409).json({
        error: 'User already exists',
        message: 'A user with this email address already exists'
      });
    }

    // Hash password
    const saltRounds = 12;
    const passwordHash = await bcrypt.hash(password, saltRounds);

    // Create user
    const result = await db.query(`
      INSERT INTO users (email, password_hash, first_name, last_name, role)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING id, email, first_name, last_name, role, created_at
    `, [email, passwordHash, firstName, lastName, 'user']);

    const user = result.rows[0];

    // Generate tokens
    const { accessToken, refreshToken, jti } = generateTokens(user);

    // Store session
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
    await db.query(
      'INSERT INTO user_sessions (user_id, token_jti, expires_at) VALUES ($1, $2, $3)',
      [user.id, jti, expiresAt]
    );

    logger.info(`User registered successfully: ${user.email}`);

    res.status(201).json({
      success: true,
      message: 'User registered successfully',
      user: {
        id: user.id,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        role: user.role
      },
      tokens: {
        accessToken,
        refreshToken,
        expiresIn: JWT_EXPIRES_IN
      }
    });

  } catch (error) {
    req.app.locals.logger.error('Registration error:', error);
    res.status(500).json({
      error: 'Registration failed',
      message: 'An internal error occurred during registration'
    });
  }
});

// Login endpoint
router.post('/login', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const logger = req.app.locals.logger;

    // Validate request body
    const { error, value } = loginSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: 'Validation failed',
        details: error.details.map(d => d.message)
      });
    }

    const { email, password } = value;

    // Find user
    const result = await db.query(`
      SELECT id, email, password_hash, first_name, last_name, role, is_active
      FROM users 
      WHERE email = $1
    `, [email]);

    if (result.rows.length === 0) {
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Email or password is incorrect'
      });
    }

    const user = result.rows[0];

    // Check if user is active
    if (!user.is_active) {
      return res.status(401).json({
        error: 'Account disabled',
        message: 'Your account has been disabled. Please contact support.'
      });
    }

    // Verify password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({
        error: 'Invalid credentials',
        message: 'Email or password is incorrect'
      });
    }

    // Generate tokens
    const { accessToken, refreshToken, jti } = generateTokens(user);

    // Store session
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
    await db.query(
      'INSERT INTO user_sessions (user_id, token_jti, expires_at) VALUES ($1, $2, $3)',
      [user.id, jti, expiresAt]
    );

    logger.info(`User logged in successfully: ${user.email}`);

    res.json({
      success: true,
      message: 'Login successful',
      user: {
        id: user.id,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        role: user.role
      },
      tokens: {
        accessToken,
        refreshToken,
        expiresIn: JWT_EXPIRES_IN
      }
    });

  } catch (error) {
    req.app.locals.logger.error('Login error:', error);
    res.status(500).json({
      error: 'Login failed',
      message: 'An internal error occurred during login'
    });
  }
});

// Logout endpoint
router.post('/logout', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const logger = req.app.locals.logger;
    
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
      return res.status(401).json({
        error: 'No token provided',
        message: 'Authorization token is required'
      });
    }

    // Verify and decode token
    const decoded = jwt.verify(token, JWT_SECRET);
    
    // Remove session from database
    await db.query(
      'DELETE FROM user_sessions WHERE token_jti = $1',
      [decoded.jti]
    );

    logger.info(`User logged out successfully: ${decoded.email}`);

    res.json({
      success: true,
      message: 'Logout successful'
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return res.status(401).json({
        error: 'Invalid token',
        message: 'The provided token is invalid'
      });
    }

    req.app.locals.logger.error('Logout error:', error);
    res.status(500).json({
      error: 'Logout failed',
      message: 'An internal error occurred during logout'
    });
  }
});

// Refresh token endpoint
router.post('/refresh', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const logger = req.app.locals.logger;
    
    const { refreshToken } = req.body;

    if (!refreshToken) {
      return res.status(401).json({
        error: 'Refresh token required',
        message: 'Refresh token must be provided'
      });
    }

    // Verify refresh token
    const decoded = jwt.verify(refreshToken, JWT_SECRET);
    
    if (decoded.type !== 'refresh') {
      return res.status(401).json({
        error: 'Invalid token type',
        message: 'Token is not a refresh token'
      });
    }

    // Check if session exists and is valid
    const sessionResult = await db.query(
      'SELECT user_id FROM user_sessions WHERE token_jti = $1 AND expires_at > NOW()',
      [decoded.jti]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(401).json({
        error: 'Invalid session',
        message: 'Session has expired or is invalid'
      });
    }

    // Get user details
    const userResult = await db.query(`
      SELECT id, email, first_name, last_name, role, is_active
      FROM users 
      WHERE id = $1 AND is_active = true
    `, [decoded.id]);

    if (userResult.rows.length === 0) {
      return res.status(401).json({
        error: 'User not found',
        message: 'User account not found or inactive'
      });
    }

    const user = userResult.rows[0];

    // Generate new tokens
    const { accessToken, refreshToken: newRefreshToken, jti } = generateTokens(user);

    // Remove old session and create new one
    await db.query('DELETE FROM user_sessions WHERE token_jti = $1', [decoded.jti]);
    
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000); // 7 days
    await db.query(
      'INSERT INTO user_sessions (user_id, token_jti, expires_at) VALUES ($1, $2, $3)',
      [user.id, jti, expiresAt]
    );

    logger.info(`Token refreshed successfully: ${user.email}`);

    res.json({
      success: true,
      message: 'Token refreshed successfully',
      tokens: {
        accessToken,
        refreshToken: newRefreshToken,
        expiresIn: JWT_EXPIRES_IN
      }
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.status(401).json({
        error: 'Invalid refresh token',
        message: 'The refresh token is invalid or expired'
      });
    }

    req.app.locals.logger.error('Token refresh error:', error);
    res.status(500).json({
      error: 'Token refresh failed',
      message: 'An internal error occurred during token refresh'
    });
  }
});

// Token validation endpoint (for other services)
router.post('/validate', async (req, res) => {
  try {
    const db = req.app.locals.db;
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({
        error: 'Token required',
        message: 'Token must be provided for validation'
      });
    }

    // Verify token
    const decoded = jwt.verify(token, JWT_SECRET);

    // Check if session is still valid
    const sessionResult = await db.query(
      'SELECT user_id FROM user_sessions WHERE token_jti = $1 AND expires_at > NOW()',
      [decoded.jti]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(401).json({
        valid: false,
        error: 'Session expired'
      });
    }

    res.json({
      valid: true,
      user: {
        id: decoded.id,
        email: decoded.email,
        role: decoded.role
      }
    });

  } catch (error) {
    if (error.name === 'JsonWebTokenError' || error.name === 'TokenExpiredError') {
      return res.json({
        valid: false,
        error: 'Invalid or expired token'
      });
    }

    req.app.locals.logger.error('Token validation error:', error);
    res.status(500).json({
      error: 'Validation failed',
      message: 'An internal error occurred during token validation'
    });
  }
});

module.exports = router;