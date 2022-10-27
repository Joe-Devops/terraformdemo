variable "ProjectName" {
  type        = string
  description = "Project name that will be used as a label prefix for most items."
  default     = "TerraformDemo"
}

variable "AwsRegion" {
  type        = string
  description = "The AWS Region that infrastructure will be deployed to."
  default     = "us-west-2"
}
