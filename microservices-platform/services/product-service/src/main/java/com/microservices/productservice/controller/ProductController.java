package com.microservices.productservice.controller;

import com.microservices.productservice.dto.*;
import com.microservices.productservice.service.ProductService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.responses.ApiResponses;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.List;

/**
 * Product Controller
 * 
 * REST API controller for product management operations.
 * Provides endpoints for CRUD operations, search, and inventory management.
 * 
 * @author Microservices Platform Team
 */
@RestController
@RequestMapping("/api/products")
@Tag(name = "Product Management", description = "APIs for managing products in the catalog")
@CrossOrigin(origins = "*", maxAge = 3600)
public class ProductController {

    private static final Logger logger = LoggerFactory.getLogger(ProductController.class);

    private final ProductService productService;

    @Autowired
    public ProductController(ProductService productService) {
        this.productService = productService;
    }

    /**
     * Create a new product
     */
    @PostMapping
    @Operation(summary = "Create a new product", description = "Creates a new product in the catalog")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "201", description = "Product created successfully"),
        @ApiResponse(responseCode = "400", description = "Invalid product data"),
        @ApiResponse(responseCode = "409", description = "Product with SKU already exists")
    })
    public ResponseEntity<ApiResponse<ProductResponse>> createProduct(
            @Valid @RequestBody ProductCreateRequest request) {
        logger.info("Creating product with SKU: {}", request.getSku());

        try {
            ProductResponse product = productService.createProduct(request);
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                true, 
                "Product created successfully", 
                product
            );
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (IllegalArgumentException e) {
            logger.error("Failed to create product: {}", e.getMessage());
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                false, 
                e.getMessage(), 
                null
            );
            return ResponseEntity.badRequest().body(response);
        }
    }

    /**
     * Get product by ID
     */
    @GetMapping("/{id}")
    @Operation(summary = "Get product by ID", description = "Retrieves a product by its ID")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Product found"),
        @ApiResponse(responseCode = "404", description = "Product not found")
    })
    public ResponseEntity<ApiResponse<ProductResponse>> getProductById(
            @Parameter(description = "Product ID") @PathVariable Long id) {
        logger.debug("Fetching product with ID: {}", id);

        try {
            ProductResponse product = productService.getProductById(id);
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                true, 
                "Product retrieved successfully", 
                product
            );
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            logger.error("Product not found with ID: {}", id);
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                false, 
                e.getMessage(), 
                null
            );
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Get product by SKU
     */
    @GetMapping("/sku/{sku}")
    @Operation(summary = "Get product by SKU", description = "Retrieves a product by its SKU")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Product found"),
        @ApiResponse(responseCode = "404", description = "Product not found")
    })
    public ResponseEntity<ApiResponse<ProductResponse>> getProductBySku(
            @Parameter(description = "Product SKU") @PathVariable String sku) {
        logger.debug("Fetching product with SKU: {}", sku);

        try {
            ProductResponse product = productService.getProductBySku(sku);
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                true, 
                "Product retrieved successfully", 
                product
            );
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            logger.error("Product not found with SKU: {}", sku);
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                false, 
                e.getMessage(), 
                null
            );
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Update product
     */
    @PutMapping("/{id}")
    @Operation(summary = "Update product", description = "Updates an existing product")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Product updated successfully"),
        @ApiResponse(responseCode = "400", description = "Invalid product data"),
        @ApiResponse(responseCode = "404", description = "Product not found"),
        @ApiResponse(responseCode = "409", description = "SKU already exists")
    })
    public ResponseEntity<ApiResponse<ProductResponse>> updateProduct(
            @Parameter(description = "Product ID") @PathVariable Long id,
            @Valid @RequestBody ProductUpdateRequest request) {
        logger.info("Updating product with ID: {}", id);

        try {
            ProductResponse product = productService.updateProduct(id, request);
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                true, 
                "Product updated successfully", 
                product
            );
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            logger.error("Failed to update product: {}", e.getMessage());
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                false, 
                e.getMessage(), 
                null
            );
            if (e.getMessage().contains("not found")) {
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.badRequest().body(response);
        }
    }

    /**
     * Delete product
     */
    @DeleteMapping("/{id}")
    @Operation(summary = "Delete product", description = "Soft deletes a product (sets active = false)")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Product deleted successfully"),
        @ApiResponse(responseCode = "404", description = "Product not found")
    })
    public ResponseEntity<ApiResponse<Void>> deleteProduct(
            @Parameter(description = "Product ID") @PathVariable Long id) {
        logger.info("Deleting product with ID: {}", id);

        try {
            productService.deleteProduct(id);
            ApiResponse<Void> response = new ApiResponse<>(
                true, 
                "Product deleted successfully", 
                null
            );
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            logger.error("Failed to delete product: {}", e.getMessage());
            ApiResponse<Void> response = new ApiResponse<>(
                false, 
                e.getMessage(), 
                null
            );
            return ResponseEntity.notFound().build();
        }
    }

    /**
     * Get all products with pagination
     */
    @GetMapping
    @Operation(summary = "Get all products", description = "Retrieves all products with pagination and sorting")
    @ApiResponse(responseCode = "200", description = "Products retrieved successfully")
    public ResponseEntity<ApiResponse<Page<ProductResponse>>> getAllProducts(
            @Parameter(description = "Page number (0-based)") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Page size") @RequestParam(defaultValue = "20") int size,
            @Parameter(description = "Sort by field") @RequestParam(defaultValue = "name") String sortBy,
            @Parameter(description = "Sort direction") @RequestParam(defaultValue = "ASC") String sortDirection) {
        
        logger.debug("Fetching products - page: {}, size: {}, sortBy: {}, direction: {}", 
                    page, size, sortBy, sortDirection);

        Page<ProductResponse> products = productService.getAllProducts(page, size, sortBy, sortDirection);
        ApiResponse<Page<ProductResponse>> response = new ApiResponse<>(
            true, 
            "Products retrieved successfully", 
            products
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Search products with advanced criteria
     */
    @PostMapping("/search")
    @Operation(summary = "Search products", description = "Advanced search with multiple criteria")
    @ApiResponse(responseCode = "200", description = "Search completed successfully")
    public ResponseEntity<ApiResponse<Page<ProductResponse>>> searchProducts(
            @RequestBody ProductSearchRequest request) {
        logger.debug("Searching products with criteria: {}", request);

        Page<ProductResponse> products = productService.searchProducts(request);
        ApiResponse<Page<ProductResponse>> response = new ApiResponse<>(
            true, 
            "Search completed successfully", 
            products
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Get products by category
     */
    @GetMapping("/category/{category}")
    @Operation(summary = "Get products by category", description = "Retrieves products in a specific category")
    @ApiResponse(responseCode = "200", description = "Products retrieved successfully")
    public ResponseEntity<ApiResponse<Page<ProductResponse>>> getProductsByCategory(
            @Parameter(description = "Category name") @PathVariable String category,
            @Parameter(description = "Page number") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Page size") @RequestParam(defaultValue = "20") int size) {
        
        logger.debug("Fetching products by category: {}", category);

        Page<ProductResponse> products = productService.getProductsByCategory(category, page, size);
        ApiResponse<Page<ProductResponse>> response = new ApiResponse<>(
            true, 
            "Products retrieved successfully", 
            products
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Get products by brand
     */
    @GetMapping("/brand/{brand}")
    @Operation(summary = "Get products by brand", description = "Retrieves products of a specific brand")
    @ApiResponse(responseCode = "200", description = "Products retrieved successfully")
    public ResponseEntity<ApiResponse<Page<ProductResponse>>> getProductsByBrand(
            @Parameter(description = "Brand name") @PathVariable String brand,
            @Parameter(description = "Page number") @RequestParam(defaultValue = "0") int page,
            @Parameter(description = "Page size") @RequestParam(defaultValue = "20") int size) {
        
        logger.debug("Fetching products by brand: {}", brand);

        Page<ProductResponse> products = productService.getProductsByBrand(brand, page, size);
        ApiResponse<Page<ProductResponse>> response = new ApiResponse<>(
            true, 
            "Products retrieved successfully", 
            products
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Get all categories
     */
    @GetMapping("/categories")
    @Operation(summary = "Get all categories", description = "Retrieves all product categories")
    @ApiResponse(responseCode = "200", description = "Categories retrieved successfully")
    public ResponseEntity<ApiResponse<List<String>>> getAllCategories() {
        logger.debug("Fetching all categories");

        List<String> categories = productService.getAllCategories();
        ApiResponse<List<String>> response = new ApiResponse<>(
            true, 
            "Categories retrieved successfully", 
            categories
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Get all brands
     */
    @GetMapping("/brands")
    @Operation(summary = "Get all brands", description = "Retrieves all product brands")
    @ApiResponse(responseCode = "200", description = "Brands retrieved successfully")
    public ResponseEntity<ApiResponse<List<String>>> getAllBrands() {
        logger.debug("Fetching all brands");

        List<String> brands = productService.getAllBrands();
        ApiResponse<List<String>> response = new ApiResponse<>(
            true, 
            "Brands retrieved successfully", 
            brands
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Update stock quantity
     */
    @PutMapping("/{id}/stock")
    @Operation(summary = "Update stock", description = "Updates the stock quantity of a product")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Stock updated successfully"),
        @ApiResponse(responseCode = "400", description = "Invalid stock quantity"),
        @ApiResponse(responseCode = "404", description = "Product not found")
    })
    public ResponseEntity<ApiResponse<ProductResponse>> updateStock(
            @Parameter(description = "Product ID") @PathVariable Long id,
            @Parameter(description = "New stock quantity") @RequestParam Integer quantity) {
        
        logger.info("Updating stock for product ID: {} to quantity: {}", id, quantity);

        try {
            ProductResponse product = productService.updateStock(id, quantity);
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                true, 
                "Stock updated successfully", 
                product
            );
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            logger.error("Failed to update stock: {}", e.getMessage());
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                false, 
                e.getMessage(), 
                null
            );
            if (e.getMessage().contains("not found")) {
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.badRequest().body(response);
        }
    }

    /**
     * Add stock
     */
    @PostMapping("/{id}/stock/add")
    @Operation(summary = "Add stock", description = "Adds stock to a product")
    @ApiResponses(value = {
        @ApiResponse(responseCode = "200", description = "Stock added successfully"),
        @ApiResponse(responseCode = "400", description = "Invalid quantity"),
        @ApiResponse(responseCode = "404", description = "Product not found")
    })
    public ResponseEntity<ApiResponse<ProductResponse>> addStock(
            @Parameter(description = "Product ID") @PathVariable Long id,
            @Parameter(description = "Quantity to add") @RequestParam Integer quantity) {
        
        logger.info("Adding stock for product ID: {} by quantity: {}", id, quantity);

        try {
            ProductResponse product = productService.addStock(id, quantity);
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                true, 
                "Stock added successfully", 
                product
            );
            return ResponseEntity.ok(response);
        } catch (IllegalArgumentException e) {
            logger.error("Failed to add stock: {}", e.getMessage());
            ApiResponse<ProductResponse> response = new ApiResponse<>(
                false, 
                e.getMessage(), 
                null
            );
            if (e.getMessage().contains("not found")) {
                return ResponseEntity.notFound().build();
            }
            return ResponseEntity.badRequest().body(response);
        }
    }

    /**
     * Get low stock products
     */
    @GetMapping("/low-stock")
    @Operation(summary = "Get low stock products", description = "Retrieves products with stock below threshold")
    @ApiResponse(responseCode = "200", description = "Low stock products retrieved successfully")
    public ResponseEntity<ApiResponse<List<ProductResponse>>> getLowStockProducts(
            @Parameter(description = "Stock threshold") @RequestParam(defaultValue = "10") Integer threshold) {
        
        logger.debug("Fetching low stock products with threshold: {}", threshold);

        List<ProductResponse> products = productService.getLowStockProducts(threshold);
        ApiResponse<List<ProductResponse>> response = new ApiResponse<>(
            true, 
            "Low stock products retrieved successfully", 
            products
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Check product availability
     */
    @GetMapping("/{id}/availability")
    @Operation(summary = "Check availability", description = "Checks if a product is available for purchase")
    @ApiResponse(responseCode = "200", description = "Availability checked successfully")
    public ResponseEntity<ApiResponse<Boolean>> checkAvailability(
            @Parameter(description = "Product ID") @PathVariable Long id,
            @Parameter(description = "Required quantity") @RequestParam(defaultValue = "1") Integer quantity) {
        
        logger.debug("Checking availability for product ID: {} with quantity: {}", id, quantity);

        boolean available = productService.isProductAvailable(id, quantity);
        ApiResponse<Boolean> response = new ApiResponse<>(
            true, 
            "Availability checked successfully", 
            available
        );
        return ResponseEntity.ok(response);
    }

    /**
     * Health check endpoint
     */
    @GetMapping("/health")
    @Operation(summary = "Health check", description = "Product service health check")
    @ApiResponse(responseCode = "200", description = "Service is healthy")
    public ResponseEntity<ApiResponse<String>> healthCheck() {
        ApiResponse<String> response = new ApiResponse<>(
            true, 
            "Product service is healthy", 
            "OK"
        );
        return ResponseEntity.ok(response);
    }
}