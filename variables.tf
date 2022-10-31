###The following are secure variables. They should either be passed during planning and applying or by the deployment system in use. 

variable "KeyPairPublicKey" {
  type         = string
  description  = "Public Key that will be installed on the ec2 hosts."
  sensitive    = true
}

variable "AwsAccessKey" {
  type        = string
  default     = null
  sensitive   = true
}

variable "AwsSecretKey" {
  type        = string
  default     = null
  sensitive   = true
}

###The following are required variables with default values. These can be updated if necessary. 

variable "ProjectName" {
  type         = string
  description  = "Project name that will be used to name various resources."
  default      = "TerraformDemo"
}

variable "AwsRegion" {
  type         = string
  description  = "The AWS region that infrastruture will be deployed to." 
  default      = "us-west-2"
}

#Vpc variables 

variable "VpcCidr" {
  type         = string
  description  = "Defines the ipv4 network for the vpc you are creating."
  default      = "10.42.0.0/16"
}

variable "VpcPrivateSubnetsCidr" {
  type         = list(string)
  description  = "Creates a private subnet for each defined cidr block listed."
  default      = ["10.42.0.0/24", "10.42.1.0/24", "10.42.2.0/24"]
}

variable "VpcPublicSubnetsCidr" {
  type         = list(string)
  description  = "Creates a public subnet for each defined cidr block listed." 
  default      = ["10.42.10.0/24", "10.42.11.0/24", "10.42.12.0/24"]
}

variable "VpcDatabaseSubnetsCidr" {
  type         = list(string)
  description  = "Creates a database subnet for each defined cidr block listed."
  default      = ["10.42.20.0/24", "10.42.21.0/24", "10.42.22.0/24"]
}

variable "VpcEnableNatGateway" {
  type         = bool
  default      = true
}
 
variable "VpcSingleNatGateway" {
  type         = bool
  default      = true
}

variable "VpcNatElasticCount" {
  type         = string
  description  = "Deploys this many elastic IPs to associate to NAT gateways." 
  default      = "1"
}

#Ec2 Variables 

variable "AmiDescription" {
  type        = list(string)
  description = "Used to lookup the AMI that will be deployed as ec2 instances."
  default     = ["Amazon Linux 2 Kernel 5.10 AMI 2.0.20221004.0 x86_64 HVM gp2", ]
}

variable "Ec2PublicType" {
  type        = string
  description = "The instance class that will be assigned to the public ec2 instance."
  default     = "t2.micro"
}

variable "Ec2PublicMonitoring" {
  type        = bool
  default     = true
}

variable "Ec2PublicInboundSshCidr" {
  type        = list(string)
  default     = ["76.95.169.14/32",]
}

variable "Ec2PrivateType" {
  type        = string
  description = "The instance class that wll be assigned to the private ec2 instance."
  default     = "t2.micro"
}

variable "Ec2PrivateMonitoring" {
  type        = bool
  default     = true
}


#Rds variables 

variable "RdsEngine" {
  type        = string
  default     = "postgres"
}

variable "RdsEngineVersion" {
  type        = string
  default     = "13.7"
}

variable "RdsFamily" {
  type        = string
  default     = "postgres13"
}

variable "RdsMajorEngineVersion" {
  type        = string
  default     = "13"
}

variable "RdsMultiAvailabilityZone" {
  type        = bool
  default     = false
}

variable "RdsInstanceClass" {
  type        = string
  default     = "db.t4g.micro"
}

variable "RdsAllocatedStorage" {
  type        = string
  default     = "20"
}

variable "RdsDatabaseAdminUsername" {
  type        = string
  default     = "dbadmin"
}

variable "RdsDatabasePort" {
  type        = string
  default     = "5432"
}

#Lambda variables

variable "LambdaRuntime" {
  type        = string
  default     = "python3.8"
}

