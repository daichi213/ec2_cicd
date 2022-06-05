variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "aws_region" {
  default = "ap-northeast-1"
}
variable "aws_zone" {
  default = "ap-northeast-1a"
}

provider "aws" {
  profile    = "${var.aws_iam_username}"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
  version    = "~> 3.0"
}

# ====================
#
# VPC
#
# ====================
resource "aws_vpc" "locker_app_vpc" {
  cidr_block                       = "10.1.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "locker_app_vpc"
  }
}


# ====================
#
# Internet Gateway
#
# ====================
resource "aws_internet_gateway" "locker_app_gateway" {
  vpc_id = aws_vpc.locker_app_vpc.id

  tags = {
    Name = "locker_app_gateway"
  }
}
# ====================
#
# Subnet
#
# ====================
resource "aws_subnet" "public_1a" {
  vpc_id            = "${aws_vpc.locker_app_vpc.id}"
  cidr_block        = cidrsubnet(aws_vpc.locker_app_vpc.cidr_block, 8, 1)
  availability_zone = "ap-northeast-1a"
  # trueにするとインスタンスにパブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = true

  tags = {
    Name = "public_1a"
  }
}


# ====================
#
# Route Table
#
# ====================
resource "aws_route_table" "locker_app_route_table" {
  vpc_id = aws_vpc.locker_app_vpc.id

  tags = {
    Name = "locker_app_route_table"
  }
}

resource "aws_route" "locker_app_route" {
  gateway_id             = aws_internet_gateway.locker_app_gateway.id
  route_table_id         = aws_route_table.locker_app_route_table.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "example" {
  subnet_id      = "${aws_subnet.public_1a.id}"
  route_table_id = "${aws_route_table.locker_app_route_table.id}"
}

# ====================
#
# Security Group
#
# ====================
resource "aws_security_group" "security_rule" {
  vpc_id = aws_vpc.locker_app_vpc.id
  name   = "security_rule"

  tags = {
    Name = "security_rule"
  }
}

# インバウンドルール(ssh接続用)
resource "aws_security_group_rule" "in_ssh" {
  security_group_id = aws_security_group.security_rule.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
}

# インバウンドルール(pingコマンド用)
resource "aws_security_group_rule" "in_icmp" {
  security_group_id = aws_security_group.security_rule.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = -1
  to_port           = -1
  protocol          = "icmp"
}

# インバウンドルール(httpアクセス用)
# resource "aws_security_group_rule" "in_http" {
#   security_group_id = aws_security_group.security_rule.id
#   type              = "ingress"
#   cidr_blocks       = ["0.0.0.0/0"]
#   from_port         = 80
#   to_port           = 80
#   protocol          = "tcp"
# }

# インバウンドルール(httpsアクセス用)
# resource "aws_security_group_rule" "in_https" {
#   security_group_id = aws_security_group.security_rule.id
#   type              = "ingress"
#   cidr_blocks       = ["0.0.0.0/0"]
#   from_port         = 443
#   to_port           = 443
#   protocol          = "tcp"
# }

# アウトバウンドルール(全開放)
resource "aws_security_group_rule" "out_all" {
  security_group_id = aws_security_group.security_rule.id
  type              = "egress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
}

# ====================
#
# Elastic IP
#
# ====================
resource "aws_eip" "my_eip" {
  instance   = aws_instance.locker_app_instance.id
  vpc        = true
  depends_on = [aws_internet_gateway.locker_app_gateway]
}

# ====================
#
# EC2 Instance
#
# ====================
resource "aws_instance" "locker_app_instance" {
  ami                    = "ami-0ce107ae7af2e92b5"
  vpc_security_group_ids = [aws_security_group.security_rule.id]
  subnet_id              = aws_subnet.public_1a.id
  key_name               = aws_key_pair.my_key_pair.id
  instance_type          = "t2.micro"
  monitoring             = false
  tags = {
    Name = "locker_app_instance"
  }
  lifecycle {
    prevent_destroy = false
  }
}

# ====================
#
# Key Pair
#
# ====================
# sshで接続する際は「ec2-user」で接続できる
resource "aws_key_pair" "my_key_pair" {
  key_name   = "my_key_pair"
  public_key = file(".ssh/my_key_pair")
}

# ====================
#
# IAM Role
#
# ====================
resource "aws_iam_instance_profile" "instance_role" {
    name = "JenkinsAccess"
    roles = ["${aws_iam_role.instance_role.name}"]
}

resource "aws_iam_role" "instance_role" {
    name = "JenkinsAccess"
    assume_role_policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "sts:AssumeRole"
              ],
              "Principal": {
                  "Service": [
                      "ec2.amazonaws.com"
                  ]
              }
          }
      ]
    })
}

resource "aws_iam_policy" "code_pipeline_policy" {
  name        = "code_pipeline_policy"
  path        = "/"
  description = "The policy for a code pipeline"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Statement": [
        {
            "Action": [
                "codepipeline:AcknowledgeJob",
                "codepipeline:GetJobDetails",
                "codepipeline:PollForJobs",
                "codepipeline:PutJobFailureResult",
                "codepipeline:PutJobSuccessResult"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ],
    "Version": "2012-10-17"
  })
}

# ====================
#
# IAM Role
#
# ====================

