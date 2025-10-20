resource "aws_vpc" "vpc-main" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id                  = aws_vpc.vpc-main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet1"
    "kubernetes.io.cluster/eks-cluster-smachno" = "shared"
    "kubernetes.io.role/elb"                      = "1"
  }
}
resource "aws_subnet" "subnet2" {
  vpc_id                  = aws_vpc.vpc-main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet2"
    "kubernetes.io.cluster/eks-cluster-smachno" = "shared"
    "kubernetes.io.role/elb"                      = "1"
  }
}
resource "aws_subnet" "subnet3" {
  vpc_id                  = aws_vpc.vpc-main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "eu-central-1c"
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet3"
    "kubernetes.io.cluster/eks-cluster-smachno" = "shared"
    "kubernetes.io.role/elb"                      = "1"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc-main.id
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc-main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.subnet3.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_security_group" "nodes_sg" {
  name   = "eks-nodes-sg"
  vpc_id = aws_vpc.vpc-main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = aws_vpc.vpc-main.id

  # Дозволяємо вхідний трафік на порт PostgreSQL (5432)
  # ТІЛЬКИ від наших робочих вузлів
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.nodes_sg.id] # <--- Ключове правило безпеки
  }
}