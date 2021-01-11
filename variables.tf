variable "ingress_cidr_block" {
  type    = list(any)
  default = ["0.0.0.0/0"]
}

variable "ipv6_ingress_cidr_block" {
  type    = list(any)
  default = ["::/0"]
}

variable "public_key" {
  type    = string
  default = ""
}

variable "neo4j_password" {
  type    = string
  default = ""
}
