provider "aws" {
  region = "us-west-2"
}

resource "aws_eip" "nat" {
  count = 1

  vpc = true
}

module "vpc" {

  source = "terraform-aws-modules/vpc/aws"
  version = "3.18.1"
  
  name = var.ProjectName
  cidr = "10.42.0.0/16"

  azs                = ["${var.AwsRegion}a", "${var.AwsRegion}b", "${var.AwsRegion}c"]
  private_subnets    = ["10.42.0.0/24", "10.42.1.0/24", "10.42.2.0/24"]
  public_subnets     = ["10.42.10.0/24", "10.42.11.0/24", "10.42.12.0/24"]
  database_subnets   = ["10.42.20.0/24", "10.42.21.0/24", "10.42.22.0/24"]
 
  enable_nat_gateway  = true
  single_nat_gateway  = true
  reuse_nat_ips       = true
  external_nat_ip_ids = "${aws_eip.nat.*.id}" 

}
