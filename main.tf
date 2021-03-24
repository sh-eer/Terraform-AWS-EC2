terraform {
  required_providers {
      aws = {
          source = "hashicorp/aws"
          version = "~> 3.0"
      }
  }
}
#configure the provider
provider "aws" {
  region  = "eu-west-2"
}

# Create VPX
resource "aws_vpc" "test" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Test"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.test.id
}

# Create Custom Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.test.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Crate a Subnet
resource "aws_subnet" "public_1" {
  vpc_id     = aws_vpc.test.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.rt.id
}

# Create Security Group to allow ports
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.test.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web_and_ssh_for_all"
  }
}

# Create a Network Interface with an IP in Subnet
resource "aws_network_interface" "web_server_nic" {
  subnet_id       = aws_subnet.public_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

# Assign an elastic IP to the network interface
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web_server_nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}

# Create Ubuntu Server and Install/Enable Apache 
resource "aws_instance" "web_server" {
  ami           = "ami-096cb92bb3580c759"
  instance_type = "t2.micro"
  availability_zone = "eu-west-2a"
  key_name = "test"

  network_interface {
    device_index          = 0
    network_interface_id  = aws_network_interface.web_server_nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo Hello there, thank you for visiting > /var/www/html/index.html'
              EOF

  tags = {
    Name = "HelloWorld"
  }
}
