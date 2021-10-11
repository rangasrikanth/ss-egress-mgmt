
terraform {
  required_version = "~> 1.0"
  # backend "s3" {
  #   region = "ap-southeast-1"
  # }
}

provider "aws" {
  alias  = "mgmt"
  region = var.region

   default_tags {
  tags = {
      Environment  = "DR"
      map-migrated = "d-server-028afp2uqxwg3m"

    }
}
}
# Second account owns the VPC and creates the VPC attachment.
provider "aws" {
  alias   = "egress"
  region  = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.account_number}:role/JenkinsAssumedRoleNew2"
  }
   default_tags {
  tags = {
      Environment  = "DR"
      map-migrated = "d-server-028afp2uqxwg3m"

    }
   }
}


provider "aws" {
  alias   = "shared-services"
  region  = var.region
  assume_role {
    role_arn = "arn:aws:iam::${var.account_number_ss}:role/JenkinsAssumedRoleNew2"
  }
 default_tags {
tags = {
      Environment  = "DR"
      map-migrated = "d-server-028afp2uqxwg3m"

    }
}
}