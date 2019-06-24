#### Tag variables ####
variable "pipeline-name" {
  type    = string
  default = "dateline-pipeline"
}

#### Terraform resource name variables ####
variable "lambda_function_name" {
  type    = string
  default = "dateline-lambda"
}

variable "lambda_role_name" {
  type    = string
  default = "dateline-lambda-role"
}

variable "secret_name" {
  type    = string
  default = "dateline-lambda-tvdb"
}

variable "sns_topic_name" {
  type    = string
  default = "dateline-lambda-sns"
}

variable "sns_sms_endpoint" {
  type    = string
  default = "+15555555555"
}

#### secret values for tvdb api ####
# Use the TF_VAR_[varname] environment variables to set these via CircleCI
variable "apikey" {
  type    = string
  default = "replace this with your tvdb apikey"
}

variable "userkey" {
  type    = string
  default = "replace this with your tvdb userkey"
}

variable "username" {
  type    = string
  default = "replace this with your tvdb username"
}

#### locals ####
locals {
  common_tags = {
    application = "dateline-lambda"
    environment = "sandbox"
    pipeline    = var.pipeline-name
  }

  tvdbkeys = {
    apikey   = var.apikey
    userkey  = var.userkey
    username = var.username
  }
}