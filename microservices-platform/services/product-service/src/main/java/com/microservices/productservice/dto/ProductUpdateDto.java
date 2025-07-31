package com.microservices.productservice.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import io.swagger.v3.oas.annotations.media.Schema;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;

@Schema(description = "Product update data")
public class ProductUpdateDto {

    @JsonProperty("name")
    @Schema(description = "Product name", example = "Premium Laptop")
    @Size(min = 2, max = 255, message = "Product name must be between 2 and 255 characters")
    private String name;

    @JsonProperty("description")
    @Schema(description = "Product description", example = "High-performance laptop for professionals")
    @Size(max = 1000, message = "Product description cannot exceed 1000 characters")
    private String description;

    @JsonProperty("price")
    @Schema(description = "Product price", example = "1299.99")
    @DecimalMin(value = "0.01", message = "Price must be greater than 0")
    @Digits(integer = 10, fraction = 2, message = "Price must have at most 2 decimal places")
    private BigDecimal price;

    @JsonProperty("category")
    @Schema(description = "Product category", example = "Electronics")
    @Size(min = 2, max = 100, message = "Category must be between 2 and 100 characters")
    private String category;

    @JsonProperty("stock")
    @Schema(description = "Stock quantity", example = "25")
    @Min(value = 0, message = "Stock cannot be negative")
    private Integer stock;

    @JsonProperty("imageUrl")
    @Schema(description = "Product image URL", example = "https://example.com/images/laptop.jpg")
    @Size(max = 500, message = "Image URL cannot exceed 500 characters")
    private String imageUrl;

    @JsonProperty("active")
    @Schema(description = "Product active status", example = "true")
    private Boolean active;

    // Constructors
    public ProductUpdateDto() {}

    public ProductUpdateDto(String name, String description, BigDecimal price, 
                           String category, Integer stock, String imageUrl, Boolean active) {
        this.name = name;
        this.description = description;
        this.price = price;
        this.category = category;
        this.stock = stock;
        this.imageUrl = imageUrl;
        this.active = active;
    }

    // Getters and Setters
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
}
