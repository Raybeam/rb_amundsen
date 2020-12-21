
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

locals {
  prefix = "rb-pipeline"
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
  elk_domain = "${local.prefix}-elk-domain"
}

provider "aws" {
  profile = "tf"
  region  = "us-west-2"
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_eip" "nat" {
  count = 1

  vpc = true
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "${local.prefix}-vpc"

  cidr = "10.0.0.0/16"

  azs             = ["us-west-2a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  enable_nat_gateway  = true
  single_nat_gateway  = true
  reuse_nat_ips       = true
  external_nat_ip_ids = aws_eip.nat.*.id

  tags = local.tags

  vpc_tags = {
    Name = "rb_pipeline"
  }
}


data "aws_ami" "neo4j" {
  most_recent = true

  filter {
    name   = "name"
    values = ["neo4j-community-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["385155106615"] # Canonical
}

resource "aws_security_group" "ssh_access" {
  vpc_id = module.vpc.vpc_id
  name   = "#{local.prefix}-ssh"

  ingress {
    cidr_blocks      = var.ingress_cidr_block
    ipv6_cidr_blocks = var.ipv6_ingress_cidr_block
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
  }


  tags = local.tags
}

resource "aws_security_group" "neo4j_access" {
  vpc_id = module.vpc.vpc_id
  name   = "#{local.prefix}-neo4j"

  ingress {
    cidr_blocks      = var.ingress_cidr_block
    ipv6_cidr_blocks = var.ipv6_ingress_cidr_block
    from_port        = 7474
    to_port          = 7474
    protocol         = "tcp"
  }

  ingress {
    cidr_blocks      = var.ingress_cidr_block
    ipv6_cidr_blocks = var.ipv6_ingress_cidr_block
    from_port        = 7473
    to_port          = 7473
    protocol         = "tcp"
  }

  ingress {
    cidr_blocks      = var.ingress_cidr_block
    ipv6_cidr_blocks = var.ipv6_ingress_cidr_block
    from_port        = 7687
    to_port          = 7687
    protocol         = "tcp"
  }


  tags = local.tags
}

resource "aws_key_pair" "self" {
  key_name   = "bbriski"
  public_key = var.public_key
}


# t3.small
resource "aws_instance" "neo4j" {
  ami           = data.aws_ami.neo4j.id
  instance_type = "t3.small"

  subnet_id                   = element(module.vpc.public_subnets, 0)
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.neo4j_access.id, aws_security_group.ssh_access.id, module.vpc.default_security_group_id]
  key_name               = aws_key_pair.self.key_name

  tags = local.tags
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  owners = ["099720109477"] # Canonical
}

# t3.small
resource "aws_instance" "amundsen" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.small"

  subnet_id                   = element(module.vpc.public_subnets, 0)
  associate_public_ip_address = true

  vpc_security_group_ids = [aws_security_group.amundsen.id, aws_security_group.ssh_access.id, module.vpc.default_security_group_id]
  key_name               = aws_key_pair.self.key_name

  tags = local.tags
}

resource "aws_security_group" "es" {
  vpc_id = module.vpc.vpc_id
  name   = "#{local.prefix}-es"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = module.vpc.public_subnets_cidr_blocks
  }


  tags = local.tags
}

resource "aws_security_group" "amundsen" {
  vpc_id = module.vpc.vpc_id
  name   = "#{local.prefix}-amundsen"

  ingress {
    cidr_blocks      = var.ingress_cidr_block
    ipv6_cidr_blocks = var.ipv6_ingress_cidr_block
    from_port        = 5002
    to_port          = 5002
    protocol         = "tcp"
  }


  tags = local.tags
}

resource "aws_iam_service_linked_role" "es" {
  aws_service_name = "es.amazonaws.com"
}

resource "aws_elasticsearch_domain" "es" {
  domain_name           = local.elk_domain
  elasticsearch_version = "7.9"

  cluster_config {
    instance_count = 1

    instance_type = "r5.large.elasticsearch"
  }

  vpc_options {
    subnet_ids = module.vpc.public_subnets

    security_group_ids = [
      aws_security_group.es.id
    ]
  }

  ebs_options {
    ebs_enabled = true
    volume_size = 10
  }

  access_policies = <<CONFIG
{
  "Version": "2012-10-17",
  "Statement": [
      {
          "Action": "es:*",
          "Principal": "*",
          "Effect": "Allow",
          "Resource": "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.elk_domain}/*"
      }
  ]
}
  CONFIG

  snapshot_options {
    automated_snapshot_start_hour = 23
  }

  tags = {
    Domain = local.elk_domain
  }
}

output "elk_endpoint" {
  value = aws_elasticsearch_domain.es.endpoint
}

output "elk_kibana_endpoint" {
  value = aws_elasticsearch_domain.es.kibana_endpoint
}
