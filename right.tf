module "vpc_right" {
  source = "cloudposse/vpc/aws"
  name       = "right"
  cidr_block = "10.0.0.0/16"
}

module "dynamic_subnets_right" {
  source             = "cloudposse/dynamic-subnets/aws"
  name               = "right"
  availability_zones = ["us-east-2a","us-east-2b","us-east-2c"]
  vpc_id             = module.vpc_right.vpc_id
  igw_id             = module.vpc_right.igw_id
  cidr_block         = "10.0.0.0/16"
}

module "instance_right" {
  source = "cloudposse/ec2-instance/aws"
  instance_type               = "t2.micro"
  vpc_id                      = module.vpc_right.vpc_id
  subnet                      = module.dynamic_subnets_right.private_subnet_ids[0]
  name                        = "right"
  instance_profile            = aws_iam_instance_profile.ssm_profile.id
  security_group_rules        = [
    {
      type        = "egress"
      from_port   = 0
      to_port     = 65535
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_security_group" "right_vpc_endpoint" {
  name   = "right vpc endpoint"
  vpc_id = module.vpc_right.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "right" {
  vpc_id              = module.vpc_right.vpc_id
  subnet_ids          = module.dynamic_subnets_right.private_subnet_ids
  service_name        = aws_vpc_endpoint_service.left.service_name
  vpc_endpoint_type   = "Interface"

  security_group_ids = [
    aws_security_group.right_vpc_endpoint.id
  ]
}
