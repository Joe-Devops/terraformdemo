# Create AWS Resources using Terraform

You are being asked to create AWS resources using Hashicorp's [Terraform](https://terraform.io) tool. This is a 2-step tasks that involves:
* creating the base infrastructure module that lays out the VPC and associated resources.
* creating EC2, Database, and lambda resources that use the VPC module.

You are welcome to use any modules you'd like in the Terraform Registry as long as you can walk us through your usage of them in an interview panel.

Please create a git repo with a main branch and use feature branches and merges to the history of the feature flow.

## Task 1: Create a VPC Infrastructure

### Guidelines
* Use a 10.42.0.0/16 CIDR range for the VPC
* Create separation for public, private and database subnets. You may create additional if you see fit.
* Systems in the private and db subnets should be able to talk to the internet to pull down patches, etc.

## Task 2: Create resources in the VPC

This should be a separate module that references the VPC module in Task 1.

### Instructions
* All instances should use the latest Amazon Linux 2 AMI
* Create a t2.micro EC2 instance in the private subnets
* Create a t2.micro EC2 instance in the public subnets that you can use as a bastion host to access the private hosts.
  * Be ready to show or explain how you would use this host to connect to the private hosts
* Create an RDS - Postgres instance
  * single db instance
  * 13.x version
  * db.t4g.micro instance type
  * in database subnet
* Create Python lambda functions for stopping and starting the private EC2 instance and schedule them to:
  * stop at 6pm PT every day
  * start at 8am PT every day
