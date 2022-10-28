###The following are secure variables. They should either be passed during planning and applying or by the deployment system in use. 

variable "KeyPairPublicKey" {
  type         = string
  description  = "Public Key that will be installed on the ec2 hosts."
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
  
