package com.microservices.productservice.service;

import com.microservices.productservice.dto.ProductDto;
import com.microservices.productservice.dto.ProductCreateDto;
import com.microservices.productservice.dto.ProductUpdateDto;
import com.microservices.productservice.model.Product;
import com.microservices.productservice.repository.ProductRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.stream.Collectors;

@Service
@Transactional
public class ProductService {

    private static final Logger logger = LoggerFactory.getLogger(ProductService.class);

    @Autowired
    private ProductRepository productRepository;

    // Get all products with pagination and filters
    @Transactional(readOnly = true)
    public Page<ProductDto> getAllProducts(Pageable pageable, String category, 
                                          BigDecimal minPrice, BigDecimal maxPrice, String search) {
        logger.debug("Getting products with filters - category: {}, minPrice: {}, maxPrice: {}, search: {}", 
                    category, minPrice, maxPrice, search);

        Page<Product> products = productRepository.findWithFilters(category, minPrice, maxPrice, search, pageable);
        return products.map(this::convertToDto);
    }

    // Get product by ID
    @Transactional(readOnly = true)
    public ProductDto getProductById(Long id) {
        logger.debug("Getting product with ID: {}", id);
        
        Product product = productRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Product not found with ID: " + id));
        
        if (!product.getActive()) {
            throw new RuntimeException("Product is not active with ID: " + id);
        }
        
        return convertToDto(product);
    }

    // Create new product
    public ProductDto createProduct(ProductCreateDto createDto) {
        logger.debug("Creating new product with SKU: {}", createDto.getSku());

        // Check if SKU already exists
        if (productRepository.existsBySku(createDto.getSku())) {
            throw new RuntimeException("Product with SKU already exists: " + createDto.getSku());
        }

        Product product = new Product();
        product.setName(createDto.getName());
        product.setDescription(createDto.getDescription());
        product.setPrice(createDto.getPrice());
        product.setCategory(createDto.getCategory());
        product.setStock(createDto.getStock());
        product.setSku(createDto.getSku());
        product.setImageUrl(createDto.getImageUrl());
        product.setActive(createDto.getActive() != null ? createDto.getActive() : true);

        Product savedProduct = productRepository.save(product);
        logger.info("Product created successfully with ID: {}", savedProduct.getId());
        
        return convertToDto(savedProduct);
    }

    // Update existing product
    public ProductDto updateProduct(Long id, ProductUpdateDto updateDto) {
        logger.debug("Updating product with ID: {}", id);

        Product product = productRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Product not found with ID: " + id));

        // Update fields only if they are provided
        if (updateDto.getName() != null) {
            product.setName(updateDto.getName());
        }
        if (updateDto.getDescription() != null) {
            product.setDescription(updateDto.getDescription());
        }
        if (updateDto.getPrice() != null) {
            product.setPrice(updateDto.getPrice());
        }
        if (updateDto.getCategory() != null) {
            product.setCategory(updateDto.getCategory());
        }
        if (updateDto.getStock() != null) {
            product.setStock(updateDto.getStock());
        }
        if (updateDto.getImageUrl() != null) {
            product.setImageUrl(updateDto.getImageUrl());
        }
        if (updateDto.getActive() != null) {
            product.setActive(updateDto.getActive());
        }

        Product savedProduct = productRepository.save(product);
        logger.info("Product updated successfully with ID: {}", savedProduct.getId());
        
        return convertToDto(savedProduct);
    }

    // Delete product (soft delete by setting active to false)
    public void deleteProduct(Long id) {
        logger.debug("Deleting product with ID: {}", id);

        Product product = productRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Product not found with ID: " + id));

        product.setActive(false);
        productRepository.save(product);
        
        logger.info("Product deleted successfully with ID: {}", id);
    }

    // Get products by category
    @Transactional(readOnly = true)
    public List<ProductDto> getProductsByCategory(String category) {
        logger.debug("Getting products for category: {}", category);
        
        List<Product> products = productRepository.findByCategoryAndActiveTrue(category);
        return products.stream()
            .map(this::convertToDto)
            .collect(Collectors.toList());
    }

    // Get products by category with pagination
    @Transactional(readOnly = true)
    public Page<ProductDto> getProductsByCategory(String category, Pageable pageable) {
        logger.debug("Getting products for category: {} with pagination", category);
        
        Page<Product> products = productRepository.findByCategoryAndActiveTrue(category, pageable);
        return products.map(this::convertToDto);
    }

    // Get all products with pagination (overloaded method)
    @Transactional(readOnly = true)
    public Page<ProductDto> getAllProducts(Pageable pageable) {
        logger.debug("Getting all products with pagination");
        
        Page<Product> products = productRepository.findByActiveTrue(pageable);
        return products.map(this::convertToDto);
    }

    // Search products
    @Transactional(readOnly = true)
    public List<ProductDto> searchProducts(String query, Integer limit) {
        logger.debug("Searching products with query: {}, limit: {}", query, limit);
        
        List<Product> products = productRepository.searchByNameOrDescription(query);
        
        return products.stream()
            .limit(limit != null ? limit : products.size())
            .map(this::convertToDto)
            .collect(Collectors.toList());
    }

    // Search products with pagination
    @Transactional(readOnly = true)
    public Page<ProductDto> searchProducts(String query, Pageable pageable) {
        logger.debug("Searching products with query: {} with pagination", query);
        
        Page<Product> products = productRepository.searchByNameOrDescriptionPageable(query, pageable);
        return products.map(this::convertToDto);
    }

    // Get all categories
    @Transactional(readOnly = true)
    public List<String> getAllCategories() {
        logger.debug("Getting all product categories");
        return productRepository.findDistinctCategories();
    }

    // Update product stock
    public ProductDto updateProductStock(Long id, Integer stock) {
        logger.debug("Updating stock for product ID: {} to quantity: {}", id, stock);

        Product product = productRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Product not found with ID: " + id));

        product.setStock(stock);
        Product savedProduct = productRepository.save(product);
        
        logger.info("Product stock updated successfully for ID: {}", id);
        return convertToDto(savedProduct);
    }

    // Update stock (alias method for controller)
    public ProductDto updateStock(Long id, Integer stock) {
        return updateProductStock(id, stock);
    }

    // Check product availability
    @Transactional(readOnly = true)
    public boolean checkAvailability(Long id, Integer quantity) {
        logger.debug("Checking availability for product ID: {} with quantity: {}", id, quantity);

        Product product = productRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Product not found with ID: " + id));

        boolean available = product.getActive() && product.getStock() >= quantity;
        logger.debug("Product availability check result: {}", available);
        
        return available;
    }

    // Convert Product entity to ProductDto
    private ProductDto convertToDto(Product product) {
        return new ProductDto(
            product.getId(),
            product.getName(),
            product.getDescription(),
            product.getPrice(),
            product.getCategory(),
            product.getStock(),
            product.getSku(),
            product.getImageUrl(),
            product.getActive(),
            product.getCreatedAt(),
            product.getUpdatedAt()
        );
    }
}
