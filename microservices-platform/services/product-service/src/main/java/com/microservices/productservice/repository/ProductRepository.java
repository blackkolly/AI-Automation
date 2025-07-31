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

@Repository
public interface ProductRepository extends JpaRepository<Product, Long> {

    // Find by SKU
    Optional<Product> findBySku(String sku);

    // Check if SKU exists
    boolean existsBySku(String sku);

    // Find active products
    Page<Product> findByActiveTrue(Pageable pageable);

    // Find by category
    Page<Product> findByCategoryAndActiveTrue(String category, Pageable pageable);
    List<Product> findByCategoryAndActiveTrue(String category);

    // Find by price range
    Page<Product> findByPriceBetweenAndActiveTrue(BigDecimal minPrice, BigDecimal maxPrice, Pageable pageable);

    // Search by name or description
    @Query("SELECT p FROM Product p WHERE " +
           "(LOWER(p.name) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(p.description) LIKE LOWER(CONCAT('%', :search, '%'))) AND " +
           "p.active = true")
    Page<Product> searchByNameOrDescription(@Param("search") String search, Pageable pageable);

    @Query("SELECT p FROM Product p WHERE " +
           "(LOWER(p.name) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(p.description) LIKE LOWER(CONCAT('%', :search, '%'))) AND " +
           "p.active = true")
    List<Product> searchByNameOrDescription(@Param("search") String search);

    // Alias for pageable search (for consistency)
    @Query("SELECT p FROM Product p WHERE " +
           "(LOWER(p.name) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(p.description) LIKE LOWER(CONCAT('%', :search, '%'))) AND " +
           "p.active = true")
    Page<Product> searchByNameOrDescriptionPageable(@Param("search") String search, Pageable pageable);

    // Complex search with multiple filters
    @Query("SELECT p FROM Product p WHERE " +
           "(:category IS NULL OR p.category = :category) AND " +
           "(:minPrice IS NULL OR p.price >= :minPrice) AND " +
           "(:maxPrice IS NULL OR p.price <= :maxPrice) AND " +
           "(:search IS NULL OR LOWER(p.name) LIKE LOWER(CONCAT('%', :search, '%')) OR " +
           "LOWER(p.description) LIKE LOWER(CONCAT('%', :search, '%'))) AND " +
           "p.active = true")
    Page<Product> findWithFilters(@Param("category") String category,
                                  @Param("minPrice") BigDecimal minPrice,
                                  @Param("maxPrice") BigDecimal maxPrice,
                                  @Param("search") String search,
                                  Pageable pageable);

    // Get all distinct categories
    @Query("SELECT DISTINCT p.category FROM Product p WHERE p.active = true ORDER BY p.category")
    List<String> findDistinctCategories();

    // Find products with low stock
    @Query("SELECT p FROM Product p WHERE p.stock <= :threshold AND p.active = true")
    List<Product> findLowStockProducts(@Param("threshold") Integer threshold);

    // Get products by IDs
    List<Product> findByIdInAndActiveTrue(List<Long> ids);
}
