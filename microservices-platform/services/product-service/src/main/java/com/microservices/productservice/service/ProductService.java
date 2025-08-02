package com.microservices.productservice.service;

import com.microservices.productservice.dto.ProductCreateRequest;
import com.microservices.productservice.dto.ProductResponse;
import com.microservices.productservice.dto.ProductSearchRequest;
import com.microservices.productservice.dto.ProductUpdateRequest;
import com.microservices.productservice.model.Product;
import com.microservices.productservice.repository.ProductRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.stream.Collectors;

/**
 * Product Service
 * 
 * Business logic layer for product operations including CRUD operations,
 * search functionality, inventory management, and business validations.
 * 
 * @author Microservices Platform Team
 */
@Service
@Transactional
public class ProductService {

    private static final Logger logger = LoggerFactory.getLogger(ProductService.class);

    private final ProductRepository productRepository;

    @Autowired
    public ProductService(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }

    /**
     * Create a new product
     */
    public ProductResponse createProduct(ProductCreateRequest request) {
        logger.info("Creating new product with SKU: {}", request.getSku());

        // Validate SKU uniqueness
        if (productRepository.existsBySku(request.getSku())) {
            throw new IllegalArgumentException("Product with SKU '" + request.getSku() + "' already exists");
        }

        Product product = new Product();
        product.setName(request.getName());
        product.setSku(request.getSku());
        product.setDescription(request.getDescription());
        product.setPrice(request.getPrice());
        product.setCategory(request.getCategory());
        product.setStockQuantity(request.getStockQuantity() != null ? request.getStockQuantity() : 0);
        product.setImageUrl(request.getImageUrl());
        product.setBrand(request.getBrand());
        product.setWeight(request.getWeight());
        product.setWeightUnit(request.getWeightUnit());
        product.setActive(true);

        Product savedProduct = productRepository.save(product);
        logger.info("Product created successfully with ID: {}", savedProduct.getId());

        return convertToResponse(savedProduct);
    }

    /**
     * Get product by ID
     */
    @Transactional(readOnly = true)
    public ProductResponse getProductById(Long id) {
        logger.debug("Fetching product with ID: {}", id);

        Product product = productRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Product not found with ID: " + id));

        return convertToResponse(product);
    }

    /**
     * Get product by SKU
     */
    @Transactional(readOnly = true)
    public ProductResponse getProductBySku(String sku) {
        logger.debug("Fetching product with SKU: {}", sku);

        Product product = productRepository.findBySku(sku)
                .orElseThrow(() -> new IllegalArgumentException("Product not found with SKU: " + sku));

        return convertToResponse(product);
    }

    /**
     * Update product
     */
    public ProductResponse updateProduct(Long id, ProductUpdateRequest request) {
        logger.info("Updating product with ID: {}", id);

        Product product = productRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Product not found with ID: " + id));

        // Validate SKU uniqueness if changed
        if (request.getSku() != null && !request.getSku().equals(product.getSku())) {
            if (productRepository.existsBySkuAndIdNot(request.getSku(), id)) {
                throw new IllegalArgumentException("Product with SKU '" + request.getSku() + "' already exists");
            }
            product.setSku(request.getSku());
        }

        // Update fields if provided
        if (request.getName() != null) product.setName(request.getName());
        if (request.getDescription() != null) product.setDescription(request.getDescription());
        if (request.getPrice() != null) product.setPrice(request.getPrice());
        if (request.getCategory() != null) product.setCategory(request.getCategory());
        if (request.getStockQuantity() != null) product.setStockQuantity(request.getStockQuantity());
        if (request.getImageUrl() != null) product.setImageUrl(request.getImageUrl());
        if (request.getBrand() != null) product.setBrand(request.getBrand());
        if (request.getWeight() != null) product.setWeight(request.getWeight());
        if (request.getWeightUnit() != null) product.setWeightUnit(request.getWeightUnit());
        if (request.getActive() != null) product.setActive(request.getActive());

        Product updatedProduct = productRepository.save(product);
        logger.info("Product updated successfully with ID: {}", updatedProduct.getId());

        return convertToResponse(updatedProduct);
    }

    /**
     * Delete product (soft delete by setting active = false)
     */
    public void deleteProduct(Long id) {
        logger.info("Deleting product with ID: {}", id);

        Product product = productRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Product not found with ID: " + id));

        product.setActive(false);
        productRepository.save(product);

        logger.info("Product soft deleted successfully with ID: {}", id);
    }

    /**
     * Get all products with pagination
     */
    @Transactional(readOnly = true)
    public Page<ProductResponse> getAllProducts(int page, int size, String sortBy, String sortDirection) {
        logger.debug("Fetching products - page: {}, size: {}, sortBy: {}, direction: {}", 
                    page, size, sortBy, sortDirection);

        Sort sort = Sort.by(Sort.Direction.fromString(sortDirection), sortBy);
        Pageable pageable = PageRequest.of(page, size, sort);

        Page<Product> products = productRepository.findByActiveTrue(pageable);
        return products.map(this::convertToResponse);
    }

    /**
     * Search products with multiple criteria
     */
    @Transactional(readOnly = true)
    public Page<ProductResponse> searchProducts(ProductSearchRequest request) {
        logger.debug("Searching products with criteria: {}", request);

        Sort sort = Sort.by(Sort.Direction.fromString(request.getSortDirection()), request.getSortBy());
        Pageable pageable = PageRequest.of(request.getPage(), request.getSize(), sort);

        Page<Product> products = productRepository.searchProducts(
                request.getName(),
                request.getCategory(),
                request.getBrand(),
                request.getMinPrice(),
                request.getMaxPrice(),
                request.getInStock(),
                pageable
        );

        return products.map(this::convertToResponse);
    }

    /**
     * Get products by category
     */
    @Transactional(readOnly = true)
    public Page<ProductResponse> getProductsByCategory(String category, int page, int size) {
        logger.debug("Fetching products by category: {}", category);

        Pageable pageable = PageRequest.of(page, size, Sort.by("name"));
        Page<Product> products = productRepository.findByCategoryAndActiveTrue(category, pageable);
        return products.map(this::convertToResponse);
    }

    /**
     * Get products by brand
     */
    @Transactional(readOnly = true)
    public Page<ProductResponse> getProductsByBrand(String brand, int page, int size) {
        logger.debug("Fetching products by brand: {}", brand);

        Pageable pageable = PageRequest.of(page, size, Sort.by("name"));
        Page<Product> products = productRepository.findByBrandAndActiveTrue(brand, pageable);
        return products.map(this::convertToResponse);
    }

    /**
     * Get all categories
     */
    @Transactional(readOnly = true)
    public List<String> getAllCategories() {
        logger.debug("Fetching all categories");
        return productRepository.findDistinctCategories();
    }

    /**
     * Get all brands
     */
    @Transactional(readOnly = true)
    public List<String> getAllBrands() {
        logger.debug("Fetching all brands");
        return productRepository.findDistinctBrands();
    }

    /**
     * Update stock quantity
     */
    public ProductResponse updateStock(Long id, Integer quantity) {
        logger.info("Updating stock for product ID: {} to quantity: {}", id, quantity);

        Product product = productRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Product not found with ID: " + id));

        if (quantity < 0) {
            throw new IllegalArgumentException("Stock quantity cannot be negative");
        }

        product.setStockQuantity(quantity);
        Product updatedProduct = productRepository.save(product);

        logger.info("Stock updated successfully for product ID: {}", id);
        return convertToResponse(updatedProduct);
    }

    /**
     * Reduce stock (for order processing)
     */
    public void reduceStock(Long id, Integer quantity) {
        logger.info("Reducing stock for product ID: {} by quantity: {}", id, quantity);

        Product product = productRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Product not found with ID: " + id));

        if (quantity <= 0) {
            throw new IllegalArgumentException("Quantity to reduce must be positive");
        }

        if (product.getStockQuantity() < quantity) {
            throw new IllegalArgumentException("Insufficient stock. Available: " + product.getStockQuantity() + ", Requested: " + quantity);
        }

        product.reduceStock(quantity);
        productRepository.save(product);

        logger.info("Stock reduced successfully for product ID: {}", id);
    }

    /**
     * Add stock (for restocking)
     */
    public ProductResponse addStock(Long id, Integer quantity) {
        logger.info("Adding stock for product ID: {} by quantity: {}", id, quantity);

        Product product = productRepository.findById(id)
                .orElseThrow(() -> new IllegalArgumentException("Product not found with ID: " + id));

        if (quantity <= 0) {
            throw new IllegalArgumentException("Quantity to add must be positive");
        }

        product.addStock(quantity);
        Product updatedProduct = productRepository.save(product);

        logger.info("Stock added successfully for product ID: {}", id);
        return convertToResponse(updatedProduct);
    }

    /**
     * Get low stock products
     */
    @Transactional(readOnly = true)
    public List<ProductResponse> getLowStockProducts(Integer threshold) {
        logger.debug("Fetching low stock products with threshold: {}", threshold);

        List<Product> products = productRepository.findLowStockProducts(threshold);
        return products.stream()
                .map(this::convertToResponse)
                .collect(Collectors.toList());
    }

    /**
     * Check product availability
     */
    @Transactional(readOnly = true)
    public boolean isProductAvailable(Long id, Integer quantity) {
        Optional<Product> productOpt = productRepository.findById(id);
        if (productOpt.isEmpty()) {
            return false;
        }

        Product product = productOpt.get();
        return product.isAvailable() && product.getStockQuantity() >= quantity;
    }

    /**
     * Convert Product entity to ProductResponse DTO
     */
    private ProductResponse convertToResponse(Product product) {
        ProductResponse response = new ProductResponse();
        response.setId(product.getId());
        response.setName(product.getName());
        response.setSku(product.getSku());
        response.setDescription(product.getDescription());
        response.setPrice(product.getPrice());
        response.setCategory(product.getCategory());
        response.setStockQuantity(product.getStockQuantity());
        response.setImageUrl(product.getImageUrl());
        response.setActive(product.getActive());
        response.setBrand(product.getBrand());
        response.setWeight(product.getWeight());
        response.setWeightUnit(product.getWeightUnit());
        response.setCreatedAt(product.getCreatedAt());
        response.setUpdatedAt(product.getUpdatedAt());
        response.setInStock(product.isInStock());
        response.setAvailable(product.isAvailable());
        return response;
    }
}