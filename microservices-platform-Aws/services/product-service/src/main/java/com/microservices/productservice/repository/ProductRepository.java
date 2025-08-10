package com.microservices.productservice.repository;

import com.microservices.productservice.model.Product;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * Product Repository
 * 
 * Data access layer for Product entity with custom query methods
 * for advanced product search and filtering capabilities.
 * 
 * @author Microservices Platform Team
 */
@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {

    /**
     * Find product by SKU
     */
    Optional<Product> findBySku(String sku);

    /**
     * Find products by category
     */
    List<Product> findByCategory(String category);

    /**
     * Find products by category with pagination
     */
    Page<Product> findByCategory(String category, Pageable pageable);

    /**
     * Find active products
     */
    List<Product> findByActiveTrue();

    /**
     * Find active products with pagination
     */
    Page<Product> findByActiveTrue(Pageable pageable);

    /**
     * Find products by brand
     */
    List<Product> findByBrand(String brand);

    /**
     * Find products in stock
     */
    @Query("SELECT p FROM Product p WHERE p.stockQuantity > 0")
    List<Product> findProductsInStock();

    /**
     * Find products in stock with pagination
     */
    @Query("SELECT p FROM Product p WHERE p.stockQuantity > 0")
    Page<Product> findProductsInStock(Pageable pageable);

    /**
     * Find products by price range
     */
    @Query("SELECT p FROM Product p WHERE p.price BETWEEN :minPrice AND :maxPrice")
    List<Product> findByPriceRange(@Param("minPrice") BigDecimal minPrice, 
                                   @Param("maxPrice") BigDecimal maxPrice);

    /**
     * Find products by price range with pagination
     */
    @Query("SELECT p FROM Product p WHERE p.price BETWEEN :minPrice AND :maxPrice")
    Page<Product> findByPriceRange(@Param("minPrice") BigDecimal minPrice, 
                                   @Param("maxPrice") BigDecimal maxPrice, 
                                   Pageable pageable);

    /**
     * Search products by name (case-insensitive)
     */
    @Query("SELECT p FROM Product p WHERE LOWER(p.name) LIKE LOWER(CONCAT('%', :name, '%'))")
    List<Product> findByNameContainingIgnoreCase(@Param("name") String name);

    /**
     * Search products by name with pagination
     */
    @Query("SELECT p FROM Product p WHERE LOWER(p.name) LIKE LOWER(CONCAT('%', :name, '%'))")
    Page<Product> findByNameContainingIgnoreCase(@Param("name") String name, Pageable pageable);

    /**
     * Advanced search with multiple criteria
     */
    @Query("SELECT p FROM Product p WHERE " +
           "(:name IS NULL OR LOWER(p.name) LIKE LOWER(CONCAT('%', :name, '%'))) AND " +
           "(:category IS NULL OR p.category = :category) AND " +
           "(:brand IS NULL OR p.brand = :brand) AND " +
           "(:minPrice IS NULL OR p.price >= :minPrice) AND " +
           "(:maxPrice IS NULL OR p.price <= :maxPrice) AND " +
           "(:inStock IS NULL OR (:inStock = true AND p.stockQuantity > 0) OR (:inStock = false)) AND " +
           "p.active = true")
    Page<Product> searchProducts(@Param("name") String name,
                                 @Param("category") String category,
                                 @Param("brand") String brand,
                                 @Param("minPrice") BigDecimal minPrice,
                                 @Param("maxPrice") BigDecimal maxPrice,
                                 @Param("inStock") Boolean inStock,
                                 Pageable pageable);

    /**
     * Find products by category and active status
     */
    Page<Product> findByCategoryAndActiveTrue(String category, Pageable pageable);

    /**
     * Find products by brand and active status
     */
    Page<Product> findByBrandAndActiveTrue(String brand, Pageable pageable);

    /**
     * Count products by category
     */
    @Query("SELECT COUNT(p) FROM Product p WHERE p.category = :category AND p.active = true")
    Long countByCategory(@Param("category") String category);

    /**
     * Get all distinct categories
     */
    @Query("SELECT DISTINCT p.category FROM Product p WHERE p.active = true ORDER BY p.category")
    List<String> findDistinctCategories();

    /**
     * Get all distinct brands
     */
    @Query("SELECT DISTINCT p.brand FROM Product p WHERE p.brand IS NOT NULL AND p.active = true ORDER BY p.brand")
    List<String> findDistinctBrands();

    /**
     * Find low stock products
     */
    @Query("SELECT p FROM Product p WHERE p.stockQuantity <= :threshold AND p.active = true")
    List<Product> findLowStockProducts(@Param("threshold") Integer threshold);

    /**
     * Find products created after a specific date
     */
    @Query("SELECT p FROM Product p WHERE p.createdAt >= :fromDate")
    List<Product> findProductsCreatedAfter(@Param("fromDate") java.time.LocalDateTime fromDate);

    /**
     * Check if SKU exists
     */
    boolean existsBySku(String sku);

    /**
     * Check if SKU exists for different product
     */
    @Query("SELECT CASE WHEN COUNT(p) > 0 THEN true ELSE false END FROM Product p WHERE p.sku = :sku AND p.id != :id")
    boolean existsBySkuAndIdNot(@Param("sku") String sku, @Param("id") Long id);

    /**
     * Update stock quantity
     */
    @Query("UPDATE Product p SET p.stockQuantity = :quantity WHERE p.id = :id")
    void updateStockQuantity(@Param("id") Long id, @Param("quantity") Integer quantity);

    /**
     * Bulk update product status
     */
    @Query("UPDATE Product p SET p.active = :active WHERE p.id IN :ids")
    void updateProductStatus(@Param("ids") List<Long> ids, @Param("active") Boolean active);
}