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
    values = var.AmiDescription 
  }
}

###Provision resources that will be used by modules. 
#Provision an elastic IP that can be reused by the NAT gateway and wont be destroyed when the NAT gateway has to be recreated. 
resource "aws_eip" "nat" {
  count = var.VpcNatElasticCount
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
 
  cidr = var.VpcCidr
  azs                = ["${var.AwsRegion}a", "${var.AwsRegion}b", "${var.AwsRegion}c"]
  private_subnets    = var.VpcPrivateSubnetsCidr
  public_subnets     = var.VpcPublicSubnetsCidr
  database_subnets   = var.VpcDatabaseSubnetsCidr
 
  enable_nat_gateway  = var.VpcEnableNatGateway
  single_nat_gateway  = var.VpcSingleNatGateway
  reuse_nat_ips       = true
  external_nat_ip_ids = "${aws_eip.nat.*.id}" 
}

#Create an EC2 instance in a private subnet
module "ec2-instance-private" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.1.4"
 
  name = "${var.ProjectName}Ec2Private"
 
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.Ec2PrivateType
  key_name               = "${var.ProjectName}Ec2Key"
  subnet_id              = module.vpc.private_subnets[0]
  monitoring             = var.Ec2PrivateMonitoring

  vpc_security_group_ids = ["${module.sg-ec2-private.security_group_id}", ]
}

#Create an EC2 instance in a public subnet that can be used as a bastion host
module "ec2-instance-public" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "4.1.4"

  name = "${var.ProjectName}Ec2Public"
 
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.Ec2PublicType
  key_name               = "${var.ProjectName}Ec2Key"
  subnet_id              = module.vpc.public_subnets[0]
  monitoring             = var.Ec2PublicMonitoring
  
  vpc_security_group_ids = ["${module.sg-ec2-public.security_group_id}", ]
}

#Create the RDS instance in the database subnets. 
module "rds-postgres" {
  source  = "terraform-aws-modules/rds/aws"
  version = "5.1.0"

  identifier = "rds-postgres"

  engine               = var.RdsEngine
  engine_version       = var.RdsEngineVersion
  family               = var.RdsFamily
  major_engine_version = var.RdsMajorEngineVersion
  multi_az             = var.RdsMultiAvailabilityZone
  instance_class       = var.RdsInstanceClass
  allocated_storage    = var.RdsAllocatedStorage

  db_name  = "${var.ProjectName}"
  username = var.RdsDatabaseAdminUsername
  port     = var.RdsDatabasePort

  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = ["${module.sg-rds.security_group_id}",]
  
}

#Create the security groups that we will need for our various resources. 
module "sg-ec2-public" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "4.16.0"

  name                   = "${var.ProjectName}SgEc2Public"
  description            = "Security group for publicly facing bastion host that allows inbound SSH traffic."
  vpc_id                 = "${module.vpc.vpc_id}"

  egress_rules           = ["all-all",]

  ingress_cidr_blocks    = var.Ec2PublicInboundSshCidr
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

###Create python lambda functions for stopping and starting the private ec2 instance and schedule them to stop at 6pm PT every day and start at 8AM PT every day. 
 
#Zip the directory for upload to aws
data "archive_file" "lambda-package" {
  type             = "zip"
  source_file      = "${path.module}/python/ec2-instance.py"
  output_file_mode = "0666"
  output_path      = "${path.module}/artifacts/python-package.zip"
}

#Create the functions for stopping and starting. 
module "lambda-ec2-stop" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.2.1"
  
  function_name          = "${var.ProjectName}LambdaStop"
  description            = "Stops an ec2 instance or instances"
  handler                = "ec2-instance.stopec2instance"
  runtime                = "python3.8"
  publish                = true
  create_package         = false
  local_existing_package = "${path.module}/artifacts/python-package.zip"

  environment_variables = {
       InstanceId = module.ec2-instance-private.id
  }
  attach_policy_json = true
  policy_json        = <<-EOT
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:stopinstances"
                ],
                "Resource": ["${module.ec2-instance-private.arn}"]
            }
        ]
    }
  EOT
}
module "lambda-ec2-start"{
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.2.1"
  
  function_name          = "${var.ProjectName}LambdaStart"
  description            = "Starts an ec2 instance or instances"
  handler                = "ec2-instance.startec2instance"
  runtime                = "python3.8"
  publish                = true
  create_package         = false
  local_existing_package = "${path.module}/artifacts/python-package.zip"
  
  environment_variables = {
      InstanceId = module.ec2-instance-private.id
  }
  attach_policy_json = true
  policy_json        = <<-EOT
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "ec2:startinstances"
                ],
                "Resource": ["${module.ec2-instance-private.arn}"]
            }
        ]
    }
  EOT
}

resource "aws_cloudwatch_event_rule" "cw-event-start" {
  name                = "${var.ProjectName}ScheduledStart"
  description         = "Triggers a lambda to start an instance on a schedule"
  schedule_expression = "cron(0 15 * * ? *)"
}

resource "aws_cloudwatch_event_target" "cw-event-target-start" {
  rule = aws_cloudwatch_event_rule.cw-event-start.name
  arn  = module.lambda-ec2-start.lambda_function_arn
}

resource "aws_lambda_permission" "cw-event-permission-start" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda-ec2-start.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cw-event-start.arn
}

resource "aws_cloudwatch_event_rule" "cw-event-stop" {
  name                = "${var.ProjectName}ScheduledStop"
  description         = "Triggers a lambda to stop an instance on a schedule"
  schedule_expression = "cron(0 1 * * ? *)"
}

resource "aws_cloudwatch_event_target" "cw-event-target-stop" {
  rule = aws_cloudwatch_event_rule.cw-event-stop.name
  arn  = module.lambda-ec2-stop.lambda_function_arn
}

resource "aws_lambda_permission" "cw-event-permission-stop" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action         = "lambda:InvokeFunction"
  function_name  = module.lambda-ec2-stop.lambda_function_name
  principal      = "events.amazonaws.com"
  source_arn     = aws_cloudwatch_event_rule.cw-event-stop.arn
}
