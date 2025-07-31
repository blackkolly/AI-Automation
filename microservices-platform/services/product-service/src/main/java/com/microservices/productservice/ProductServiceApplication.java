package com.microservices.productservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * Product Service Application
 * 
 * A production-grade microservice for product catalog management
 * Features:
 * - RESTful API for product operations
 * - PostgreSQL persistence with JPA
 * - Redis caching for performance
 * - JWT authentication integration
 * - Prometheus metrics and distributed tracing
 * - Comprehensive logging and monitoring
 * 
 * @author DevOps Team
 * @version 1.0.0
 */
@SpringBootApplication
@EnableCaching
@EnableTransactionManagement
@EnableAsync
public class ProductServiceApplication {

    public static void main(String[] args) {
        // Set default timezone
        System.setProperty("user.timezone", "UTC");
        
        // Enable JMX for monitoring
        System.setProperty("spring.jmx.enabled", "true");
        
        SpringApplication.run(ProductServiceApplication.class, args);
    }
}
