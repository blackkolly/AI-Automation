package com.microservices.productservice.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;

import java.math.BigDecimal;
import java.time.LocalDateTime;

@Schema(description = "Product information")
public class ProductDto {

    @JsonProperty("id")
    @Schema(description = "Product ID", example = "1")
    private Long id;

    @JsonProperty("name")
    @Schema(description = "Product name", example = "Premium Laptop")
    private String name;

    @JsonProperty("description")
    @Schema(description = "Product description", example = "High-performance laptop for professionals")
    private String description;

    @JsonProperty("price")
    @Schema(description = "Product price", example = "1299.99")
    private BigDecimal price;

    @JsonProperty("category")
    @Schema(description = "Product category", example = "Electronics")
    private String category;

    @JsonProperty("stock")
    @Schema(description = "Available stock quantity", example = "25")
    private Integer stock;

    @JsonProperty("sku")
    @Schema(description = "Stock Keeping Unit", example = "LPT-001")
    private String sku;

    @JsonProperty("imageUrl")
    @Schema(description = "Product image URL", example = "https://example.com/images/laptop.jpg")
    private String imageUrl;

    @JsonProperty("active")
    @Schema(description = "Product active status", example = "true")
    private Boolean active;

    @JsonProperty("createdAt")
    @Schema(description = "Creation timestamp")
    private LocalDateTime createdAt;

    @JsonProperty("updatedAt")
    @Schema(description = "Last update timestamp")
    private LocalDateTime updatedAt;

    // Constructors
    public ProductDto() {}

    public ProductDto(Long id, String name, String description, BigDecimal price, 
                      String category, Integer stock, String sku, String imageUrl, 
                      Boolean active, LocalDateTime createdAt, LocalDateTime updatedAt) {
        this.id = id;
        this.name = name;
        this.description = description;
        this.price = price;
        this.category = category;
        this.stock = stock;
        this.sku = sku;
        this.imageUrl = imageUrl;
        this.active = active;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
    }

    // Getters and Setters
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public void setPrice(BigDecimal price) {
        this.price = price;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public Integer getStock() {
        return stock;
    }

    public void setStock(Integer stock) {
        this.stock = stock;
    }

    public String getSku() {
        return sku;
    }

    public void setSku(String sku) {
        this.sku = sku;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }

    public Boolean getActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
