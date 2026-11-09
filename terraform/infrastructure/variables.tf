
variable "project_name" {
  description = "Name of the project."
  type        = string
  default     = "banxico-api"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "development"
}

variable "aws_region" {
  description = "AWS region where the infrastructure will be deployed."
  type        = string
  default     = "us-east-2"
}

variable "vpc_cidr" {
  description = "CIDR block assigned to the VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)

  default = [
    "10.20.1.0/24",
    "10.20.2.0/24"
  ]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly two public subnets are required."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)

  default = [
    "10.20.11.0/24",
    "10.20.12.0/24"
  ]

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Exactly two private subnets are required."
  }
}
