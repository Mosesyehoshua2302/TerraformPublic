terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 4.9.0"
    }
  }
}

provider "aws" {
 region = "us-east-2"
 access_key = "AKIA4GR7DU6IAEHATGVW"
 secret_key = "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"
}

#create a VPC
resource "aws_vpc" "first" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "first"
  }
}

#create an internet gateway
resource "aws_internet_gateway" "first_gw" {
  vpc_id = aws_vpc.first.id

  tags = {
    Name = "first_gw"
  }
}

# create custom route table
resource "aws_route_table" "first_RT" {
  vpc_id = aws_vpc.first.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.first_gw.id
  }

  tags = {
    Name = "route_table"
  }
}

#create a subnet
resource "aws_subnet" "first_subnet" {
  vpc_id     = aws_vpc.first.id
  availability_zone = "us-east-2b"
  cidr_block = "10.0.3.0/24"

  tags = {
    Name = "First_subnet"
  }
}

#associate subnet with route table
resource "aws_route_table_association" "first_a" {
  subnet_id      = aws_subnet.first_subnet.id
  route_table_id = aws_route_table.first_RT.id
}

#create security group 
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow inbound/outbound web traffic"
  vpc_id      = aws_vpc.first.id

  ingress {
    description      = "HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  #who is allowed to access
  }
 ingress {
    description      = "SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  #who is allowed to access
  }
  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}
#creating NIC
resource "aws_network_interface" "first_NIC" {
  subnet_id       = aws_subnet.first_subnet.id
  private_ips     = ["10.0.3.50"]
  security_groups = [aws_security_group.allow_web_traffic.id]

}
#creating elastic IP
resource "aws_eip" "first_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.first_NIC.id
  associate_with_private_ip = "10.0.3.50"
  depends_on = [
    aws_internet_gateway.first_gw
  ]
}

#creating server
resource "aws_instance" "first_instance" {
  ami           = "ami-064ff912f78e3e561" 
  instance_type = "t2.micro"
  availability_zone = "us-east-2b"
  key_name  = "terraform-key"
 
 
 network_interface {
   device_index = 0
   network_interface_id = aws_network_interface.first_NIC.id
 }

user_data = <<-EOF
          #!/bin/bash
          sudo apt update -y
          sudo apt install apache2 -y
          sudo systemctl start apache2
          sudo bash -c "echo this is my first web server > /var/www/html/index.html"
EOF
tags = {
  "Name" = "Web Server"
}
}