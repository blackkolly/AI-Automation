# Output values for the Terraform configuration

# VPC Outputs
output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "database_subnet_ids" {
  description = "List of IDs of database subnets"
  value       = aws_subnet.database[*].id
}

output "nat_gateway_ids" {
  description = "List of IDs of the NAT Gateways"
  value       = aws_nat_gateway.main[*].id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

# EKS Outputs
output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.eks_cluster.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.eks_cluster.arn
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "cluster_primary_security_group_id" {
  description = "The cluster primary security group ID created by EKS"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_groups" {
  description = "EKS node groups"
  value = {
    for k, v in aws_eks_node_group.main : k => {
      arn           = v.arn
      status        = v.status
      capacity_type = v.capacity_type
      instance_types = v.instance_types
      ami_type      = v.ami_type
    }
  }
}

# Database Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = false
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "rds_db_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "rds_username" {
  description = "RDS instance username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "rds_security_group_id" {
  description = "RDS security group ID"
  value       = aws_security_group.rds.id
}

# Redis Outputs
output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
}

output "redis_port" {
  description = "Redis cluster port"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_security_group_id" {
  description = "Redis security group ID"
  value       = aws_security_group.redis.id
}

# ECR Outputs
output "ecr_repositories" {
  description = "ECR repository URLs"
  value = {
    for k, v in aws_ecr_repository.services : k => v.repository_url
  }
}

output "ecr_registry_id" {
  description = "ECR registry ID"
  value       = data.aws_caller_identity.current.account_id
}

# S3 Outputs
output "s3_bucket_name" {
  description = "S3 bucket name for application data"
  value       = aws_s3_bucket.app_data.bucket
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.app_data.arn
}

output "s3_bucket_domain_name" {
  description = "S3 bucket domain name"
  value       = aws_s3_bucket.app_data.bucket_domain_name
}

# KMS Outputs
output "kms_key_id" {
  description = "KMS key ID"
  value       = aws_kms_key.main.key_id
}

output "kms_key_arn" {
  description = "KMS key ARN"
  value       = aws_kms_key.main.arn
}

# IAM Outputs
output "worker_iam_role_name" {
  description = "EKS worker node IAM role name"
  value       = aws_iam_role.eks_node_group.name
}

output "worker_iam_role_arn" {
  description = "EKS worker node IAM role ARN"
  value       = aws_iam_role.eks_node_group.arn
}

output "pod_execution_role_arn" {
  description = "Pod execution role ARN for Fargate"
  value       = aws_iam_role.fargate_pod_execution.arn
}

# Load Balancer Outputs
output "load_balancer_security_group_id" {
  description = "Load balancer security group ID"
  value       = aws_security_group.alb.id
}

# CloudWatch Outputs
output "cloudwatch_log_group_name" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.eks.name
}

output "cloudwatch_log_group_arn" {
  description = "CloudWatch log group ARN"
  value       = aws_cloudwatch_log_group.eks.arn
}

# Region and AZ Outputs
output "aws_region" {
  description = "AWS region"
  value       = var.aws_region
}

output "availability_zones" {
  description = "List of availability zones"
  value       = data.aws_availability_zones.available.names
}

# OIDC Provider Output
output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster for the OpenID Connect identity provider"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider"
  value       = aws_iam_openid_connect_provider.eks.arn
}

# Network ACL Outputs
output "private_network_acl_id" {
  description = "ID of the private network ACL"
  value       = aws_network_acl.private.id
}

output "public_network_acl_id" {
  description = "ID of the public network ACL"
  value       = aws_network_acl.public.id
}

# Route Table Outputs
output "private_route_table_ids" {
  description = "List of IDs of the private route tables"
  value       = aws_route_table.private[*].id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

# Security Group Outputs
output "additional_security_group_ids" {
  description = "Additional security group IDs"
  value = {
    eks_additional = aws_security_group.eks_additional.id
    monitoring     = aws_security_group.monitoring.id
  }
}

# Kafka Outputs (if using MSK)
output "kafka_bootstrap_brokers" {
  description = "Kafka bootstrap brokers"
  value       = var.environment == "prod" ? aws_msk_cluster.main[0].bootstrap_brokers : null
}

output "kafka_zookeeper_connect_string" {
  description = "Kafka Zookeeper connection string"
  value       = var.environment == "prod" ? aws_msk_cluster.main[0].zookeeper_connect_string : null
}

# Cost Optimization Outputs
output "estimated_monthly_cost" {
  description = "Estimated monthly cost (this is a placeholder - actual cost tracking should use AWS Cost Explorer)"
  value = {
    eks_cluster = "~$73/month"
    worker_nodes = "~$${var.node_group_desired_size * 50}/month (based on m5.large instances)"
    rds = "~$15/month (db.t3.micro)"
    redis = "~$15/month (cache.t3.micro)"
    nat_gateway = "~$45/month per NAT Gateway"
    load_balancer = "~$23/month"
    storage = "Variable based on usage"
  }
}

# Monitoring Endpoints
output "monitoring_endpoints" {
  description = "Monitoring service endpoints (will be available after Helm deployments)"
  value = {
    prometheus = "prometheus.${var.domain_name != "" ? var.domain_name : "localhost"}"
    grafana = "grafana.${var.domain_name != "" ? var.domain_name : "localhost"}"
    jaeger = "jaeger.${var.domain_name != "" ? var.domain_name : "localhost"}"
    alertmanager = "alertmanager.${var.domain_name != "" ? var.domain_name : "localhost"}"
  }
}

# GitOps Configuration
output "gitops_config" {
  description = "GitOps configuration"
  value = {
    argocd_enabled = var.enable_argocd
    repo_url = var.gitops_repo_url
    cluster_name = "${var.project_name}-${var.environment}"
  }
}

# Next Steps Information
output "next_steps" {
  description = "Next steps to complete the setup"
  value = [
    "1. Update kubeconfig: aws eks update-kubeconfig --region ${var.aws_region} --name ${var.project_name}-${var.environment}",
    "2. Install Helm: Run the kubernetes/helm-setup.sh script",
    "3. Deploy monitoring stack: helm install prometheus-stack prometheus-community/kube-prometheus-stack",
    "4. Deploy ArgoCD: kubectl apply -f kubernetes/monitoring/argocd/",
    "5. Configure DNS records if using custom domain",
    "6. Deploy application services using GitOps or direct Helm charts"
  ]
}
