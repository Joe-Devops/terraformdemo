###Load everything required for the plan to proceeed. 
#Load the AWS Provider and set its region.
provider "aws" {
  region = "us-west-2"
}

#Set a data source and filter to help pull the correct AMI ID later.  
data "aws_ami" "amazon_linux" {
  most_recent = true  
  owners = ["amazon"]

  filter {
    name = "description"
    values = ["Amazon Linux 2 Kernel 5.10 AMI 2.0.20221004.0 x86_64 HVM gp2", ]
  }
}

###Provision resources that will be used by modules. 
#Provision an elastic IP that can be reused by the NAT gateway and wont be destroyed when the NAT gateway has to be recreated. 
resource "aws_eip" "nat" {
  count = 1
  vpc = true
}

#Provision an ec2 key pair using provided variables. This allows us to easily insert a custom key pair on deployment. 
resource "aws_key_pair" "Ec2KeyPair" {
  key_name    = "${var.ProjectName}Ec2Key"
  public_key  = "${var.KeyPairPublicKey}"
}

#Create a VPC with public, private, and database subnets and allow the private and database subnets to connect to the internet
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

#Create an EC2 instance in a private subnet
module "ec2-instance-private" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.1.4"
 
  name = "${var.ProjectName}Ec2Private"
 
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "${var.ProjectName}Ec2Key"
  subnet_id              = module.vpc.private_subnets[0]
  monitoring             = true

  vpc_security_group_ids = ["${module.sg-ec2-private.security_group_id}", ]
}

#Create an EC2 instance in a public subnet that can be used as a bastion host
module "ec2-instance-public" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.1.4"

  name = "${var.ProjectName}Ec2Public"
 
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  key_name               = "${var.ProjectName}Ec2Key"
  subnet_id              = module.vpc.public_subnets[0]
  monitoring             = true
  
  vpc_security_group_ids = ["${module.sg-ec2-public.security_group_id}", ]
}

#Create the security groups that we will need for our various resources. 
module "sg-ec2-public" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.16.0"

  name                   = "${var.ProjectName}SgEc2Public"
  description            = "Security group for publicly facing bastion host that allows inbound SSH traffic."
  vpc_id                 = "${module.vpc.vpc_id}"

  egress_rules           = ["all-all",]

  ingress_cidr_blocks    = ["76.95.169.14/32"]
  ingress_rules          = ["ssh-tcp"]
}

module "sg-ec2-private" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.16.0"

  vpc_id                 = "${module.vpc.vpc_id}"
  name                   = "${var.ProjectName}SgEc2Private"
  description            = "Security group for private Ec2 host that allows inbound SSH from public ec2 security group."

  egress_rules           = ["all-all",]

  number_of_computed_ingress_with_source_security_group_id = 1
  computed_ingress_with_source_security_group_id = [
    {
      description              = "Allows SSH from the public subnet security group"
      from_port                = 22
      to_port                  = 22
      protocol                 = "tcp"
      source_security_group_id = "${module.sg-ec2-public.security_group_id}"
    }
  ]
}

module "sg-rds" {
  source   = "terraform-aws-modules/security-group/aws"
  version  = "4.16.0"
  
  vpc_id                 = "${module.vpc.vpc_id}"
  name                   = "${var.ProjectName}SgRds"
  description            = "Security group for postgres instances that allows inbound traffic from public ec2 security group." 
  egress_rules           = ["all-all",]
  
  number_of_computed_ingress_with_source_security_group_id = 2
  computed_ingress_with_source_security_group_id = [
    {
      description               = "Allows postgres traffic from the public subnet security group"
      from_port                 = 5432
      to_port                   = 5432
      protocol                  = "tcp"
      source_security_group_id  = "${module.sg-ec2-public.security_group_id}"
    }
    ,    
    {
      description               = "Allows postgres traffic from the private subnet security group"
      from_port                 = 5432
      to_port                   = 5432
      protocol                  = "tcp"
      source_security_group_id  = "${module.sg-ec2-private.security_group_id}"
    }
  ]
}
    
