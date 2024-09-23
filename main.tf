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

  azs             = ["us-east-1a","us-east-1b"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24"]


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
module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "inventorydb"

  engine            = "mysql"
  engine_version    = "8.0.35"
  instance_class    = "db.t3.micro"
  allocated_storage = 5

  db_name  = "inventorydb"
  username = "tobi"
  password = "badejomessi"
  port     = "3306"

  vpc_security_group_ids = [aws_security_group.terraform_sg.id]

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"
# DB parameter group
  family = "mysql8.0"

  # DB option group
  major_engine_version = "8.0"

  tags = {
    Owner       = "user"
    Environment = "free"
  }

  # DB subnet group
  create_db_subnet_group = true
  subnet_ids             = [module.vpc.private_subnets[0], module.vpc.private_subnets[1]]

}