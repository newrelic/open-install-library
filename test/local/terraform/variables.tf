variable "profile" {
  default = "default"
}

variable "region" {
  default = "eu-west-1"
}

variable "instance" {
  default = "t2.micro"
}

variable "public_key" {
  default = "~/.ssh/id_rsa.pub"
}

variable "private_key" {
  default = "~/.ssh/id_rsa"
}

variable "environment_tag" {
  default = "us-development"
}

variable "owning_team_tag" {
  default = "OPENSOURCE"
}

variable "product_tag" {
  default = "infrastructure"
}

variable "distros" {
  description = "Distributions to test install (co-indexed with amis and ami_users)"
  type        = list(string)
  default     = ["amazon2", "amazon"]
}

variable "amis" {
  description = "AMIs for the distributions to test install"
  type        = list(string)
  default     = ["ami-08a2aed6e0a6f9c7d", "ami-0a7c31280fbd23a86"]
}

variable "ami_users" {
  description = "Users for the distributions to test install"
  type        = list(string)
  default     = ["ec2-user", "ec2-user"]
}
