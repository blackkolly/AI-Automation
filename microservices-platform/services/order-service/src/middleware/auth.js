const jwt = require('jsonwebtoken');
const logger = require('../utils/logger');

const authMiddleware = (req, res, next) => {
    try {
        const authHeader = req.headers.authorization;
        
        if (!authHeader) {
            return res.status(401).json({
                error: 'Authorization header missing'
            });
        }

        const token = authHeader.startsWith('Bearer ') 
            ? authHeader.slice(7) 
            : authHeader;

        if (!token) {
            return res.status(401).json({
                error: 'Token missing'
            });
        }

        // Verify JWT token
        const decoded = jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key');
        
        // Add user info to request
        req.user = {
            id: decoded.id || decoded.userId,
            email: decoded.email,
            role: decoded.role || 'user'
        };

        logger.info(`Authenticated user: ${req.user.id}`);
        next();
    } catch (error) {
        logger.error('Authentication error:', error);
        
        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({
                error: 'Invalid token'
            });
        }
        
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                error: 'Token expired'
            });
        }

        return res.status(500).json({
            error: 'Authentication failed'
        });
    }
};

module.exports = authMiddleware;
