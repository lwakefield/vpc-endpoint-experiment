module "vpc_left" {
  source = "cloudposse/vpc/aws"
  name       = "left"
  cidr_block = "10.0.0.0/16"
}

module "dynamic_subnets_left" {
  source             = "cloudposse/dynamic-subnets/aws"
  name               = "left"
  availability_zones = ["us-east-2a","us-east-2b","us-east-2c"]
  vpc_id             = module.vpc_left.vpc_id
  igw_id             = module.vpc_left.igw_id
  cidr_block         = "10.0.0.0/16"
}

# For testing purposes you can't ping the nlb from an instance in it's
# target group. Instead, spin up another instance, then you can ping
# the nlb domain name.
# https://docs.aws.amazon.com/elasticloadbalancing/latest/network/load-balancer-troubleshooting.html#loopback-timeout
module "instance_left" {
  source = "cloudposse/ec2-instance/aws"
  instance_type               = "t2.micro"
  vpc_id                      = module.vpc_left.vpc_id
  subnet                      = module.dynamic_subnets_left.private_subnet_ids[0]
  name                        = "left"
  instance_profile            = aws_iam_instance_profile.ssm_profile.id
  security_group_rules        = [
    {
      type        = "egress"
      from_port   = 0
      to_port     = 65535
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      type        = "ingress"
      from_port   = 0
      to_port     = 65535
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    },
  ]
}

module "nlb" {
  source                            = "cloudposse/nlb/aws"
  vpc_id                            = module.vpc_left.vpc_id
  subnet_ids                        = module.dynamic_subnets_left.private_subnet_ids
  access_logs_enabled               = false
  internal                          = true
  tcp_enabled                       = true
  cross_zone_load_balancing_enabled = true
  target_group_port                 = 80
  target_group_target_type          = "instance"
}

resource "aws_lb_target_group_attachment" "left" {
  target_group_arn = module.nlb.default_target_group_arn
  target_id        = module.instance_left.id
  port             = 80
}

resource "aws_vpc_endpoint_service" "left" {
  # with this vvv, you need to go into the console and click a button to allow
  # vpc endpoints to connect to the service
  acceptance_required        = true
  network_load_balancer_arns = [module.nlb.nlb_arn]
}
