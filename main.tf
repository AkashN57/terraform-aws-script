#1 Create VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"
   tags = {
    Name = "production-vpc"
  }
}
#2 Create Internet Gateway
resource "aws_internet_gateway" "prod-gw" {
  vpc_id = aws_vpc.prod-vpc.id

  tags = {
    Name = "production-gw"
  }
}
#3 Create Custom Route Table
resource "aws_route_table" "production-crt" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.prod-gw.id
  }

  tags = {
    Name = "production-crt"
  }
}
#4 Create Subnet
resource "aws_subnet" "production-subnet" {
  vpc_id     = aws_vpc.prod-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "production-subnet"
  }
}
#5 Associate Subnet with Route Table
resource "aws_route_table_association" "production-rt-assoc" {
  subnet_id      = aws_subnet.production-subnet.id
  route_table_id = aws_route_table.production-crt.id
}
#6 Create Security Group to Allow Port 80, 22, 443
resource "aws_security_group" "allow_tls" {
  name        = "allow_web_traffic"
  description = "Allow inbound web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description      = "Allow HTTPS from VPC"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    #ipv6_cidr_blocks = [aws_vpc.prod-vpc.ipv6_cidr_block]
  }
  ingress {
    description      = "Allow HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.prod-vpc.ipv6_cidr_block]
  }
  ingress {
    description      = "Allow SSH from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = [aws_vpc.prod-vpc.ipv6_cidr_block]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    # ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web_traffic"
  }
}
#7 Create Network Interface with an IP in the Subnet that was created in step 4
resource "aws_network_interface" "production-ni" {
  subnet_id       = aws_subnet.production-subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_tls.id]

  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }
}
#8 Assign an Elastic IP to the Network Interface created in step 7
resource "aws_eip" "one" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.production-ni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.prod-gw ]
}

output "server_public_ip" {
  value = aws_eip.one.public_ip
}

#9 Create Ubuntu VM with an Apache Web Server and Security Group from step 6 using the Network Interface from step 7
resource "aws_instance" "production-vm" {
  ami           = "ami-0dba2cb6798deb6d8"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "demo-key-pair"
  network_interface {
    network_interface_id = aws_network_interface.production-ni.id
    device_index         = 0
  }
 
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo Hello World > /var/www/html/index.html'
              EOF 
            
  tags = {
    Name = "production-vm"
  }

}

output "vm-private-ip" {
  value = aws_instance.production-vm.private_ip
}
