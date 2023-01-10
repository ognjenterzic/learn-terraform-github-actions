terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.26.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.0.1"
    }
  }
  required_version = ">= 1.1.0"

  cloud {
    organization = "hashicorp-learn-ot"

    workspaces {
      name = "gh-actions-demo"
    }
  }
}

provider "aws" {
  region = "us-west-2"
}

################################################################################################################################

resource "aws_vpc" "my-vpc-ot" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "vpc-ot"
  }

}

#####INTERNET GATEWAY

resource "aws_internet_gateway" "my-internetgw-ot" {
  vpc_id = aws_vpc.my-vpc-ot.id

  tags = {
    Name = "internet gateway-ot"
  }
}

#####CUSTOM ROUTE TABLE

resource "aws_route_table" "my-routetable-ot" {
  vpc_id = aws_vpc.my-vpc-ot.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my-internetgw-ot.id
  }

tags ={
Name="Route table-ot"
}

}

#####SUBNET

resource "aws_subnet" "my-subnet-ot" {
  vpc_id = aws_vpc.my-vpc-ot.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-2a"
  map_public_ip_on_launch = true

  tags = {
    Name = "Subnet-ot"
  }

}

#####ASSOCIATE SUBNET WITH ROUTE TABLE

resource "aws_route_table_association" "my-associate-ot" {
  subnet_id = aws_subnet.my-subnet-ot.id
  route_table_id = aws_route_table.my-routetable-ot.id

}

#####CREATE A SECURITY GROUP TO ALLOW PORT 22, 80, 443

resource "aws_security_group" "allow-web" {
  name = "allow_web_traffic"
  description = "This will allow web traffic"
  vpc_id = aws_vpc.my-vpc-ot.id

 ingress {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }

  ingress {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  ingress {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
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
    Name = "allow_web"
  }
  
}

#####CREATE A NETWORK INTERFACE WITH AN IP IN THE SUBNET THAT WAS CREATED EARLIER

resource "aws_network_interface" "my-network-interface-ot" {
  subnet_id = aws_subnet.my-subnet-ot.id
  private_ips = ["10.0.1.50"]
  security_groups = [ aws_security_group.allow-web.id]

  tags = {
    Name = "Network interface-ot"
  }
}

##### ELASTIC IP ASSIGN TO THE NETWORK INTERFACE CREATED IN THE PREVIOUS STEP

resource "aws_eip" "my-elastic-ip-ot" {
  vpc = true
  network_interface = aws_network_interface.my-network-interface-ot.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [
    aws_internet_gateway.my-internetgw-ot,aws_instance.my-instance-ot
  ]
  
tags = {
  Name = "Elastic ip-ot"
}

}

resource "aws_instance" "my-instance-ot" {
  ami = "ami-830c94e3"
  instance_type = "t2.micro"
  availability_zone = "us-west-2a"
  key_name = "main-key"
 
  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.my-network-interface-ot.id
  }

   user_data = <<-EOF
        #! /bin/bash
        sudo apt update -y 
        sudo apt install -y apache2
        sed -i -e 's/80/8080/' /etc/apache2/ports.conf
        echo "Hello World" > /var/www/html/index.html
        systemctl restart apache2
        EOF

    tags = {
      Name : "Web-Server"
    }    
  
}

output "web-address" {
  value = "${aws_instance.my-instance-ot.public_dns}:8080"
}

