

variable "vpc_cidr_block_egress" {
  type = string
}

variable "vpc_cidr_block_mngmt" {
  type = string
}

variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "account_number" {
  type = string
}

variable "account_number_ss" {
  type = string
}


variable "additional_tags" {
  default     = {}
  description = "Additional resource tags"
  type        = map(string)
}