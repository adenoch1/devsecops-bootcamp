# -----------------------------------------------------------------------
# VPC Endpoints (Week 5 Stage 2)
#
# Keeps ECS task traffic to AWS services off the NAT gateway / public
# internet path. Honest cost note (documented in weeks/week-05-progressive-
# delivery/README.md too): at 2 AZs and 3 interface endpoints, this likely
# costs MORE per month than the single NAT gateway it doesn't replace
# (~$0.01/hr per endpoint per AZ vs. one NAT gateway). This is a security
# posture improvement, not a cost optimization — the NAT gateway stays, as
# a fallback for anything not covered by an endpoint.
#
# Security group scoped to the VPC CIDR rather than the ECS tasks SG
# specifically: the ECS security group lives in the ecs module, which
# itself depends on this network module's outputs (subnets), so scoping to
# that SG here would create a circular module dependency. VPC-CIDR scoping
# still means only resources inside this VPC can reach the endpoints.
# -----------------------------------------------------------------------

resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpce-sg"
  description = "Interface VPC endpoints - HTTPS from within the VPC only"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from within the VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Required by AWS PrivateLink for endpoint network interfaces"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-sg"
  })
}

# Gateway endpoint for S3 (free) - ECR image layers are actually fetched
# from S3 under the hood, so this covers image pulls even though it looks
# unrelated to ECR at first glance. Attached to both route tables since
# gateway endpoints have no hourly cost either way.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], aws_route_table.private[*].id)

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-s3"
  })
}

locals {
  interface_endpoints = {
    ecr_api = "ecr.api"
    ecr_dkr = "ecr.dkr"
    logs    = "logs"
    # Week 5 Stage 3: the X-Ray daemon sidecar calls the X-Ray API to ship
    # trace segments — without this it'd go out via the NAT gateway instead,
    # the one path this whole endpoints.tf file exists to avoid.
    xray = "xray"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_endpoints

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${data.aws_region.current.region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-${each.key}"
  })
}

data "aws_region" "current" {}
