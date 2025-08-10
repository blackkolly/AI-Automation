package com.microservices.productservice.dto;

import java.math.BigDecimal;

/**
 * Product Search Request DTO
 * 
 * Data Transfer Object for advanced product search with filtering,
 * sorting, and pagination capabilities.
 * 
 * @author Microservices Platform Team
 */
public class ProductSearchRequest {

    private String name;
    private String category;
    private String brand;
    private BigDecimal minPrice;
    private BigDecimal maxPrice;
    private Boolean inStock;
    private int page = 0;
    private int size = 20;
    private String sortBy = "name";
    private String sortDirection = "ASC";

    // Default constructor
    public ProductSearchRequest() {}

    // Getters and Setters
    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getBrand() {
        return brand;
    }

    public void setBrand(String brand) {
        this.brand = brand;
    }

    public BigDecimal getMinPrice() {
        return minPrice;
    }

    public void setMinPrice(BigDecimal minPrice) {
        this.minPrice = minPrice;
    }

    public BigDecimal getMaxPrice() {
        return maxPrice;
    }

    public void setMaxPrice(BigDecimal maxPrice) {
        this.maxPrice = maxPrice;
    }

    public Boolean getInStock() {
        return inStock;
    }

    public void setInStock(Boolean inStock) {
        this.inStock = inStock;
    }

    public int getPage() {
        return page;
    }

    public void setPage(int page) {
        this.page = Math.max(0, page);
    }

    public int getSize() {
        return size;
    }

    public void setSize(int size) {
        this.size = Math.min(Math.max(1, size), 100); // Limit between 1 and 100
    }

    public String getSortBy() {
        return sortBy;
    }

    public void setSortBy(String sortBy) {
        this.sortBy = sortBy != null ? sortBy : "name";
    }

    public String getSortDirection() {
        return sortDirection;
    }

    public void setSortDirection(String sortDirection) {
        this.sortDirection = ("DESC".equalsIgnoreCase(sortDirection)) ? "DESC" : "ASC";
    }

    @Override
    public String toString() {
        return "ProductSearchRequest{" +
                "name='" + name + '\'' +
                ", category='" + category + '\'' +
                ", brand='" + brand + '\'' +
                ", minPrice=" + minPrice +
                ", maxPrice=" + maxPrice +
                ", inStock=" + inStock +
                ", page=" + page +
                ", size=" + size +
                ", sortBy='" + sortBy + '\'' +
                ", sortDirection='" + sortDirection + '\'' +
                '}';
    }
}
