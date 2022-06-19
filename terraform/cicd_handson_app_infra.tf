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
resource "aws_vpc" "cicd_handson_app_vpc" {
  cidr_block                       = "10.1.0.0/16"
  enable_dns_hostnames             = true
  enable_dns_support               = true
  instance_tenancy                 = "default"
  assign_generated_ipv6_cidr_block = true

  tags = {
    Name = "cicd_handson_app_vpc"
  }
}


# ====================
#
# Subnet(Public)
#
# ====================
resource "aws_subnet" "public_1a" {
  vpc_id            = "${aws_vpc.cicd_handson_app_vpc.id}"
  cidr_block        = "10.1.10.0/24"
  availability_zone = "ap-northeast-1a"
  # trueにするとインスタンスにパブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = true

  tags = {
    Name = "public_1a"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id            = "${aws_vpc.cicd_handson_app_vpc.id}"
  cidr_block        = "10.1.20.0/24"
  availability_zone = "ap-northeast-1b"
  # trueにするとインスタンスにパブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = true

  tags = {
    Name = "public_1b"
  }
}

# ====================
#
# Subnet(Private)
#
# ====================
resource "aws_subnet" "private_1a" {
  vpc_id            = "${aws_vpc.cicd_handson_app_vpc.id}"
  cidr_block        = "10.1.15.0/24"
  availability_zone = "ap-northeast-1a"
  # trueにするとインスタンスにパブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = false

  tags = {
    Name = "private_1a"
  }
}

resource "aws_subnet" "private_1b" {
  vpc_id            = "${aws_vpc.cicd_handson_app_vpc.id}"
  cidr_block        = "10.1.25.0/24"
  availability_zone = "ap-northeast-1b"
  # trueにするとインスタンスにパブリックIPアドレスを自動的に割り当ててくれる
  map_public_ip_on_launch = false

  tags = {
    Name = "private_1b"
  }
}

# ====================
#
# Internet Gateway
#
# ====================
resource "aws_internet_gateway" "cicd_handson_app_gateway" {
  vpc_id = aws_vpc.cicd_handson_app_vpc.id

  tags = {
    Name = "cicd_handson_app_gateway"
  }
}


####################
# NATGW
####################
resource "aws_eip" "natgw" {
  vpc = true

  tags = {
    Name = "natgw-fargate-deploy"
  }
}

resource "aws_nat_gateway" "natgw" {
  allocation_id = aws_eip.natgw.id
  subnet_id     = aws_subnet.public_1a.id

  tags = {
    Name = "natgw"
  }

  depends_on = [aws_internet_gateway.igw]
}


# ====================
#
# Route Table
#
# ====================
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.cicd_handson_app_vpc.id

  tags = {
    Name = "public"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.cicd_handson_app_vpc.id

  tags = {
    Name = "private"
  }
}

# ====================
#
# Route
#
# ====================
resource "aws_route" "public" {
  gateway_id             = aws_internet_gateway.cicd_handson_app_gateway.id
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
}


# ====================
#
# Route Table Association
#
# ====================
resource "aws_route_table_association" "public_1a_route_table_association" {
  subnet_id      = "${aws_subnet.public_1a.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "public_1b_route_table_association" {
  subnet_id      = "${aws_subnet.public_1b.id}"
  route_table_id = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "private_1a_route_table_association" {
  subnet_id      = "${aws_subnet.private_1a.id}"
  route_table_id = "${aws_route_table.private.id}"
}

resource "aws_route_table_association" "private_1b_route_table_association" {
  subnet_id      = "${aws_subnet.private_1b.id}"
  route_table_id = "${aws_route_table.private.id}"
}


# ====================
#
# Security Group
#
# ====================
resource "aws_security_group" "security_rule" {
  vpc_id = aws_vpc.cicd_handson_app_vpc.id
  name   = "security_rule"

  tags = {
    Name = "security_rule"
  }
}

# ====================
#
# Security Rules
#
# ====================
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
resource "aws_security_group_rule" "in_http" {
  security_group_id = aws_security_group.security_rule.id
  type              = "ingress"
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
}

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
# EC2 Instance
#
# ====================
resource "aws_instance" "jenkins" {
  ami                    = "ami-0ce107ae7af2e92b5"
  vpc_security_group_ids = [aws_security_group.security_rule.id]
  subnet_id              = aws_subnet.public_1a.id
  key_name               = aws_key_pair.my_key_pair.id
  instance_type          = "t2.micro"
  monitoring             = false
  tags = {
    Name = "jenkins"
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_instance" "development" {
  ami                    = "ami-0ce107ae7af2e92b5"
  vpc_security_group_ids = [aws_security_group.security_rule.id]
  subnet_id              = aws_subnet.public_1a.id
  key_name               = aws_key_pair.my_key_pair.id
  instance_type          = "t2.micro"
  monitoring             = false
  tags = {
    Name = "development"
  }
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_instance" "production" {
  ami                    = "ami-0ce107ae7af2e92b5"
  vpc_security_group_ids = [aws_security_group.security_rule.id]
  subnet_id              = aws_subnet.public_1a.id
  key_name               = aws_key_pair.my_key_pair.id
  instance_type          = "t2.micro"
  monitoring             = false
  tags = {
    Name = "production"
  }
  lifecycle {
    prevent_destroy = false
  }
}

# ====================
#
# Elastic IP
#
# ====================
resource "aws_eip" "jenkins_eip" {
  instance   = aws_instance.jenkins.id
  vpc        = true
  depends_on = [aws_internet_gateway.cicd_handson_app_gateway]
}

resource "aws_eip" "development_eip" {
  instance   = aws_instance.development.id
  vpc        = true
  depends_on = [aws_internet_gateway.cicd_handson_app_gateway]
}

resource "aws_eip" "production_eip" {
  instance   = aws_instance.production.id
  vpc        = true
  depends_on = [aws_internet_gateway.cicd_handson_app_gateway]
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
    description = "The role for a instance with jenkins"
    assume_role_policy = file("./roles/instance_role.json")
}

resource "aws_iam_role" "codepipeline_service_role" {
    name        = "codepipeline_service_role"
    description = "The role for a code pipeline"
    policy = file("./roles/code_pipeline_assume_role.json")
}


# ====================
#
# IAM Policy
#
# ====================
resource "aws_iam_policy" "code_pipeline_policy" {
  name        = "code_pipeline_policy"
  role        = aws_iam_role.code_pipeline_service_role.name
  description = "The policy for a code pipeline"
  policy = file("./policies/code_pipeline_policy.json")
}

resource "aws_iam_policy" "instance_with_jenkins_policy" {
  name        = "instance_with_jenkins_policy"
  role        = aws_iam_role.instance_role.name
  description = "The policy for a code pipeline"
  policy = file("./policies/instance_with_jenkins_policy.json")
}

# ====================
#
# Code Commit
#
# ====================
resource "aws_codecommit_repository" "cicd_handson_app_repo" {
  repository_name = "cicd_handson_app_repo"
  description     = "The repository for CI/CD tutorial on AWS"
}


# ====================
#
# S3
#
# ====================
resource "aws_s3_bucket" "pipeline" {
  bucket = "s3-fargate-deploy"
  acl    = "private"
}


# ====================
#
# CodePipeline
#
# ====================
resource "aws_codepipeline" "cp-01" {
  name     = local.cp-01["name"]
  role_arn = aws_iam_role.cp-01-role.arn

  artifact_store {
    location = aws_s3_bucket.artifact_store.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      run_order        = 1
      name             = "Source"
      namespace        = "SourceVariables"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        RepositoryName       = aws_codecommit_repository.repo-01.repository_name
        BranchName           = "master"
        OutputArtifactFormat = "CODE_ZIP"
        PollForSourceChanges = "false"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name            = "Build"
      namespace       = "BuildVariables"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = ["SourceArtifact"]
      ## output_artifacts = ["BuildArtifact"]
      version = "1"

      configuration = {
        ProjectName = aws_codebuild_project.cb-01.name
      }
    }
  }

}

# TODO 大元
resource "aws_codepipeline" "pipeline" {
  name     = "pipeline-fargate-deploy"
  role_arn = aws_iam_role.codepipeline_service_role.arn
 
  artifact_store {
    location = aws_s3_bucket.pipeline.bucket
    type     = "S3"
  }
 
  stage {
    name = "Source"
 
    action {
      run_order        = 1
      name             = "Source"
      namespace        = "SourceVariables"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeCommit"
      version          = "1"
      output_artifacts = ["source_output"]
 
      configuration = {
        Owner                = "Teraoka-Org"
        Repo                 = "fargate-deploy-test"
        Branch               = "master"
        PollForSourceChanges = "false"
      }
    }
  }
 
  stage {
    name = "Build"
 
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"
 
      configuration = {
        ProjectName = aws_codebuild_project.project.name
      }
    }
  }
 
  stage {
    name = "Deploy"
 
    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ECS"
      input_artifacts = ["build_output"]
      version         = "1"
 
      configuration = {
        ClusterName = aws_ecs_cluster.cluster.arn
        ServiceName = aws_ecs_service.service.name
        FileName    = "imagedef.json"
      }
    }
  }
}
 
resource "aws_codepipeline_webhook" "webhook" {
  name            = "webhook-fargate-deploy"
  authentication  = "GITHUB_HMAC"
  target_action   = "Source"
  target_pipeline = aws_codepipeline.pipeline.name
 
  authentication_configuration {
    secret_token = aws_ssm_parameter.github_personal_access_token.value
  }
 
  filter {
    json_path    = "$.ref"
    match_equals = "refs/heads/{Branch}"
  }
}