

# First account owns the transit gateway and accepts the VPC attachment.


locals {
  region = var.region
}
data "aws_caller_identity" "egress" {
  provider = aws.egress
}

data "aws_caller_identity" "mgmt" {
  provider = aws.mgmt
}

module "mgmtvpc" {

  source = "terraform-aws-modules/vpc/aws"

  providers = {
    aws = aws.mgmt
  }
  version = "~> 3.0"

  #name = "${var.region}-${mgt-account}-vpc"
  cidr = var.vpc_cidr_block_mngmt

  azs = ["${local.region}a", "${local.region}b", "${local.region}c"]

  private_subnets = [cidrsubnet(var.vpc_cidr_block_mngmt, 2, 0), cidrsubnet(var.vpc_cidr_block_mngmt,2, 1), cidrsubnet(var.vpc_cidr_block_mngmt, 2, 2)]
 
  enable_ipv6     = false

  enable_nat_gateway = false
  single_nat_gateway = true
  create_igw         = false

  tags = {
    Environment = var.env
  }

  vpc_tags = {
    Name = "${var.region}-${var.mgt-account}-vpc"
  }
}

module "egresvpc" {

  source = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.egress
  }
  version = "~> 3.0"

  name = "egress-vpc"
  cidr = var.vpc_cidr_block_egress

  azs            = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets = [cidrsubnet(var.vpc_cidr_block_egress, 2, 0), cidrsubnet(var.vpc_cidr_block_egress, 2, 1), cidrsubnet(var.vpc_cidr_block_egress, 2, 2)]
  enable_ipv6    = false

  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  create_igw             = true

  public_subnet_tags = {
    Name = "egress-public-subnet"
  }

  tags = {

    Environment = var.env
  }

  vpc_tags = {
    Name = "egress-vpc"
  }
}

module "tgw" {

  source = "terraform-aws-modules/transit-gateway/aws"

  providers = {
    aws = aws.shared-services
  }

  name            = "tgw-mgnt"
  description     = "My TGW shared with several other AWS accounts"
 
  tags = {
    Purpose = "tgw-mgmt"
  }
}

resource "aws_ram_resource_share" "tgw-share" {
  provider = aws.shared-services

  name = "tgw-share"

  tags = {
    Name = "tgw-share"
  }
}

# Share the transit gateway...
resource "aws_ram_resource_association" "tgw-share-resource-asso" {
  provider = aws.shared-services

  resource_arn       = module.tgw.ec2_transit_gateway_arn
  resource_share_arn = aws_ram_resource_share.tgw-share.id
}

# ...with the second account.
resource "aws_ram_principal_association" "tgw-share-principal-egress-asso" {
  provider = aws.shared-services

  principal          = data.aws_caller_identity.egress.account_id
  resource_share_arn = aws_ram_resource_share.tgw-share.id
}

resource "aws_ram_principal_association" "tgw-share-principal-mgmt-asso" {
  provider = aws.shared-services

  principal          = data.aws_caller_identity.mgmt.account_id
  resource_share_arn = aws_ram_resource_share.tgw-share.id
}

# Create the VPC attachment in the egress account...
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-mgmtvpc-attach" {
  provider = aws.mgmt

   depends_on = [
    aws_ram_resource_association.tgw-share-resource-asso,
    aws_ram_principal_association.tgw-share-principal-mgmt-asso
  ]

  subnet_ids         = module.mgmtvpc.private_subnets
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = module.mgmtvpc.vpc_id

  tags = {
    Name = "tgw-mgmt-vpc-attachment"
    
  }
}


# Create the VPC attachment in the mgmt account...
resource "aws_ec2_transit_gateway_vpc_attachment" "tgw-egressvpc-attach" {
  provider = aws.egress

  depends_on = [
    aws_ram_resource_association.tgw-share-resource-asso,
    aws_ram_principal_association.tgw-share-principal-egress-asso
  ]

  subnet_ids         = module.egresvpc.public_subnets
  transit_gateway_id = module.tgw.ec2_transit_gateway_id
  vpc_id             = module.egresvpc.vpc_id

  tags = {
    Name = "tgw-egress-vpc-attachment"

  }
}

# ...and accept it in the first account.
resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "tgw-vpc-attach-accep-mgmt" {
  provider = aws.shared-services

  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw-mgmtvpc-attach.id

  tags = {
    Name = "Mgmt VPC Attachment Assocition"
    Side = "Accepter"
  }
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "tgw-vpc-attach-accep-egress" {
  provider = aws.shared-services

  transit_gateway_attachment_id = aws_ec2_transit_gateway_vpc_attachment.tgw-egressvpc-attach.id

  tags = {
    Name = "Egress VPC Attachment Assocition"
    Side = "Accepter"
  }
}
