terraform {
  backend "s3" {
    bucket         = "teing-ranyansh-random-freeyans" # Replace with your S3 bucket name
    key            = "state/terraform.tfstate"        # Path to store the state file in the bucket
    region         = "us-east-1"                      # AWS region of the S3 bucket (e.g., us-east-1)
    dynamodb_table = "terraform-lock-table"           # DynamoDB table for state locking (optional but recommended)
    encrypt        = true                             # Encrypt state file at rest using SSE-S3 (default: true)
  }
}
provider "aws" {
  region = var.region
}
data "aws_ssm_parameter" "ami_id" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]


}
resource "aws_s3_bucket" "terraform_state" {
  bucket = "teing-ranyansh-random-freeyans"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [aws_s3_bucket_ownership_controls.example]

  bucket = aws_s3_bucket.terraform_state.id
  acl    = "private"
}
resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}


resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}


resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-lock-table"
  billing_mode = "PAY_PER_REQUEST" # No need to manage capacity
  hash_key     = "LockID"          # Primary key is 'LockID'

  attribute {
    name = "LockID"
    type = "S" # 'S' for string
  }
}


resource "aws_security_group" "terraform_sg" {
  vpc_id = module.vpc.vpc_id
  name   = join("_", ["sg", module.vpc.vpc_id])
  dynamic "ingress" {
    for_each = var.rules
    content {
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      protocol    = ingress.value["proto"]
      cidr_blocks = ingress.value["cidr_blocks"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Terraform-Dynamic-SG"
  }
}

resource "aws_instance" "First_personal_project" {
  ami                         = data.aws_ssm_parameter.ami_id.value
  subnet_id                   = module.vpc.public_subnets[0]
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  user_data                   = fileexists("scripts.sh") ? file("scripts.sh") : null
  security_groups             = [aws_security_group.terraform_sg.id]
  tags = {
    Name = "terraform"
  }
}
