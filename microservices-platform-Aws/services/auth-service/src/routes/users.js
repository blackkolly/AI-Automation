const express = require("express");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcryptjs");
const Joi = require("joi");

const router = express.Router();

// JWT configuration
const JWT_SECRET = process.env.JWT_SECRET || "your-secret-key";

// Authentication middleware
const authenticateToken = async (req, res, next) => {
  try {
    const authHeader = req.headers["authorization"];
    const token = authHeader && authHeader.split(" ")[1];

    if (!token) {
      return res.status(401).json({
        error: "Access token required",
        message: "Please provide a valid access token",
      });
    }

    const decoded = jwt.verify(token, JWT_SECRET);

    // Check if session is still valid
    const db = req.app.locals.db;
    const sessionResult = await db.query(
      "SELECT user_id FROM user_sessions WHERE token_jti = $1 AND expires_at > NOW()",
      [decoded.jti]
    );

    if (sessionResult.rows.length === 0) {
      return res.status(401).json({
        error: "Session expired",
        message: "Your session has expired. Please log in again.",
      });
    }

    req.user = decoded;
    next();
  } catch (error) {
    if (error.name === "JsonWebTokenError") {
      return res.status(403).json({
        error: "Invalid token",
        message: "The provided token is invalid",
      });
    }
    if (error.name === "TokenExpiredError") {
      return res.status(401).json({
        error: "Token expired",
        message: "The provided token has expired",
      });
    }

    req.app.locals.logger.error("Authentication error:", error);
    res.status(500).json({
      error: "Authentication failed",
      message: "An internal error occurred during authentication",
    });
  }
};

// Validation schemas
const updateProfileSchema = Joi.object({
  firstName: Joi.string().min(2).max(50).optional(),
  lastName: Joi.string().min(2).max(50).optional(),
  email: Joi.string().email().optional(),
});

const changePasswordSchema = Joi.object({
  currentPassword: Joi.string().required(),
  newPassword: Joi.string().min(8).required(),
});

// Get user profile
router.get("/profile", authenticateToken, async (req, res) => {
  try {
    const db = req.app.locals.db;

    const result = await db.query(
      `
      SELECT id, email, first_name, last_name, role, is_active, email_verified, created_at, updated_at
      FROM users 
      WHERE id = $1
    `,
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: "User not found",
        message: "User profile not found",
      });
    }

    const user = result.rows[0];

    res.json({
      success: true,
      user: {
        id: user.id,
        email: user.email,
        firstName: user.first_name,
        lastName: user.last_name,
        role: user.role,
        isActive: user.is_active,
        emailVerified: user.email_verified,
        createdAt: user.created_at,
        updatedAt: user.updated_at,
      },
    });
  } catch (error) {
    req.app.locals.logger.error("Get profile error:", error);
    res.status(500).json({
      error: "Failed to get profile",
      message: "An internal error occurred while fetching user profile",
    });
  }
});

// Update user profile
router.put("/profile", authenticateToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const logger = req.app.locals.logger;

    // Validate request body
    const { error, value } = updateProfileSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: "Validation failed",
        details: error.details.map((d) => d.message),
      });
    }

    const { firstName, lastName, email } = value;
    const updates = [];
    const values = [];
    let paramCount = 1;

    // Build dynamic update query
    if (firstName !== undefined) {
      updates.push(`first_name = $${paramCount}`);
      values.push(firstName);
      paramCount++;
    }

    if (lastName !== undefined) {
      updates.push(`last_name = $${paramCount}`);
      values.push(lastName);
      paramCount++;
    }

    if (email !== undefined) {
      // Check if email is already taken by another user
      const emailCheck = await db.query(
        "SELECT id FROM users WHERE email = $1 AND id != $2",
        [email, req.user.id]
      );

      if (emailCheck.rows.length > 0) {
        return res.status(409).json({
          error: "Email already taken",
          message:
            "This email address is already associated with another account",
        });
      }

      updates.push(`email = $${paramCount}`);
      values.push(email);
      paramCount++;
    }

    if (updates.length === 0) {
      return res.status(400).json({
        error: "No updates provided",
        message: "At least one field must be provided for update",
      });
    }

    // Add updated_at timestamp
    updates.push(`updated_at = CURRENT_TIMESTAMP`);
    values.push(req.user.id);

    const query = `
      UPDATE users 
      SET ${updates.join(", ")} 
      WHERE id = $${paramCount}
      RETURNING id, email, first_name, last_name, role, updated_at
    `;

    const result = await db.query(query, values);
    const updatedUser = result.rows[0];

    logger.info(`User profile updated: ${updatedUser.email}`);

    res.json({
      success: true,
      message: "Profile updated successfully",
      user: {
        id: updatedUser.id,
        email: updatedUser.email,
        firstName: updatedUser.first_name,
        lastName: updatedUser.last_name,
        role: updatedUser.role,
        updatedAt: updatedUser.updated_at,
      },
    });
  } catch (error) {
    req.app.locals.logger.error("Update profile error:", error);
    res.status(500).json({
      error: "Profile update failed",
      message: "An internal error occurred while updating profile",
    });
  }
});

// Change password
router.put("/password", authenticateToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const logger = req.app.locals.logger;

    // Validate request body
    const { error, value } = changePasswordSchema.validate(req.body);
    if (error) {
      return res.status(400).json({
        error: "Validation failed",
        details: error.details.map((d) => d.message),
      });
    }

    const { currentPassword, newPassword } = value;

    // Get current user with password hash
    const result = await db.query(
      "SELECT password_hash FROM users WHERE id = $1",
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: "User not found",
        message: "User account not found",
      });
    }

    const user = result.rows[0];

    // Verify current password
    const isCurrentPasswordValid = await bcrypt.compare(
      currentPassword,
      user.password_hash
    );
    if (!isCurrentPasswordValid) {
      return res.status(400).json({
        error: "Invalid current password",
        message: "The current password you provided is incorrect",
      });
    }

    // Hash new password
    const saltRounds = 12;
    const newPasswordHash = await bcrypt.hash(newPassword, saltRounds);

    // Update password
    await db.query(
      "UPDATE users SET password_hash = $1, updated_at = CURRENT_TIMESTAMP WHERE id = $2",
      [newPasswordHash, req.user.id]
    );

    // Invalidate all existing sessions for security
    await db.query("DELETE FROM user_sessions WHERE user_id = $1", [
      req.user.id,
    ]);

    logger.info(`Password changed for user: ${req.user.email}`);

    res.json({
      success: true,
      message: "Password changed successfully. Please log in again.",
    });
  } catch (error) {
    req.app.locals.logger.error("Change password error:", error);
    res.status(500).json({
      error: "Password change failed",
      message: "An internal error occurred while changing password",
    });
  }
});

// Get user sessions
router.get("/sessions", authenticateToken, async (req, res) => {
  try {
    const db = req.app.locals.db;

    const result = await db.query(
      `
      SELECT token_jti, expires_at, created_at
      FROM user_sessions 
      WHERE user_id = $1 AND expires_at > NOW()
      ORDER BY created_at DESC
    `,
      [req.user.id]
    );

    res.json({
      success: true,
      sessions: result.rows.map((session) => ({
        id: session.token_jti,
        expiresAt: session.expires_at,
        createdAt: session.created_at,
        isCurrent: session.token_jti === req.user.jti,
      })),
    });
  } catch (error) {
    req.app.locals.logger.error("Get sessions error:", error);
    res.status(500).json({
      error: "Failed to get sessions",
      message: "An internal error occurred while fetching user sessions",
    });
  }
});

// Revoke specific session
router.delete("/sessions/:sessionId", authenticateToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const logger = req.app.locals.logger;
    const { sessionId } = req.params;

    // Check if session belongs to the user
    const sessionCheck = await db.query(
      "SELECT user_id FROM user_sessions WHERE token_jti = $1",
      [sessionId]
    );

    if (sessionCheck.rows.length === 0) {
      return res.status(404).json({
        error: "Session not found",
        message: "The specified session was not found",
      });
    }

    if (sessionCheck.rows[0].user_id !== req.user.id) {
      return res.status(403).json({
        error: "Unauthorized",
        message: "You can only revoke your own sessions",
      });
    }

    // Revoke the session
    await db.query("DELETE FROM user_sessions WHERE token_jti = $1", [
      sessionId,
    ]);

    logger.info(`Session revoked: ${sessionId} for user: ${req.user.email}`);

    res.json({
      success: true,
      message: "Session revoked successfully",
    });
  } catch (error) {
    req.app.locals.logger.error("Revoke session error:", error);
    res.status(500).json({
      error: "Session revocation failed",
      message: "An internal error occurred while revoking session",
    });
  }
});

// Revoke all sessions (except current)
router.delete("/sessions", authenticateToken, async (req, res) => {
  try {
    const db = req.app.locals.db;
    const logger = req.app.locals.logger;

    // Revoke all sessions except the current one
    const result = await db.query(
      "DELETE FROM user_sessions WHERE user_id = $1 AND token_jti != $2",
      [req.user.id, req.user.jti]
    );

    logger.info(
      `${result.rowCount} sessions revoked for user: ${req.user.email}`
    );

    res.json({
      success: true,
      message: `${result.rowCount} sessions revoked successfully`,
    });
  } catch (error) {
    req.app.locals.logger.error("Revoke all sessions error:", error);
    res.status(500).json({
      error: "Session revocation failed",
      message: "An internal error occurred while revoking sessions",
    });
  }
});

module.exports = router;
