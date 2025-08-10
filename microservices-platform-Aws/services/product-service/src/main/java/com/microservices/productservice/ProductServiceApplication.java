package com.microservices.productservice;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;

/**
 * Product Service Application
 * 
 * This microservice manages product catalog operations including:
 * - Product CRUD operations
 * - Category management
 * - Inventory tracking
 * - Product search and filtering
 * 
 * @author Microservices Platform Team
 * @version 1.0.0
 */
@SpringBootApplication
@EnableJpaAuditing
public class ProductServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(ProductServiceApplication.class, args);
    }
}