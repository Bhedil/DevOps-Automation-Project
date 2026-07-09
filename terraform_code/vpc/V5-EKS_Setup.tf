provider "aws" {
    region = "ap-southeast-3"
}

variable "use_ignore_changes" {
  type    = bool
  default = true
}

resource "aws_instance" "demo-server" {
    # 1. Handle the true/false switch entirely inside for_each
    for_each = var.use_ignore_changes ? toset(["jenkins-master", "build-slave", "ansible"]) : toset([])
    ami = "ami-039f9d16a13e3a0a7"
    instance_type = "t3.micro"
    key_name = "ansible-lab"
    //security_groups = [ "demo-sg" ]
    vpc_security_group_ids = [aws_security_group.demo-sg.id]
    subnet_id = aws_subnet.dpp-public-subnet-01.id

    tags = {
        Name = "${each.key}"
    }

    # ignore the changes of this resource based on the tags created manually in the console
    # lifecycle {
    #     ignore_changes = [tags]
    # }

    # This completely freezes the instances from any further Terraform updates
    lifecycle {
        ignore_changes = all
    }

}

resource "aws_security_group" "demo-sg" {
    name = "demo-sg"
    description = "SSH Access"
    vpc_id = aws_vpc.dpp-vpc.id

    ingress {
        description = "SSH Access"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks  = [ "0.0.0.0/0" ]
    }

    ingress {
        description = "Jenkins port"
        from_port   = 8080
        to_port     = 8080
        protocol    = "tcp"
        cidr_blocks  = [ "0.0.0.0/0" ]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
        ipv6_cidr_blocks = [ "::/0" ]
    }

    tags = {
      Name = "ssh-port"
    }
}

resource "aws_vpc" "dpp-vpc" {
    cidr_block = "10.1.0.0/16"
    tags = {
      Name = "dpp-vpc"
    }

}

resource "aws_subnet" "dpp-public-subnet-01" {
    vpc_id = aws_vpc.dpp-vpc.id
    cidr_block = "10.1.1.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "ap-southeast-3a"
    tags = {
      Name = "dpp-public-subnet-01"
    }
}

resource "aws_subnet" "dpp-public-subnet-02" {
    vpc_id = aws_vpc.dpp-vpc.id
    cidr_block = "10.1.2.0/24"
    map_public_ip_on_launch = "true"
    availability_zone = "ap-southeast-3b"
    tags = {
      Name = "dpp-public-subnet-02"
    }
}

resource "aws_internet_gateway" "dpp-igw" {
    vpc_id = aws_vpc.dpp-vpc.id
    tags = {
      Name = "dpp-igw"
    }
}

resource "aws_route_table" "dpp-public-rt" {
    vpc_id = aws_vpc.dpp-vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.dpp-igw.id
    }
}

resource "aws_route_table_association" "dpp-rta-public-subnet-01" {
    subnet_id = aws_subnet.dpp-public-subnet-01.id
    route_table_id = aws_route_table.dpp-public-rt.id
}

resource "aws_route_table_association" "dpp-rta-public-subnet-02" {
    subnet_id = aws_subnet.dpp-public-subnet-02.id
    route_table_id = aws_route_table.dpp-public-rt.id
}

//If i want to destroy the eks cluster, i just need to comment this 2 modules below and apply it using terraform apply not destroy
module "sgs" {
    source = "../sg_eks"
    vpc_id = aws_vpc.dpp-vpc.id
}

module "eks" {
    source = "../eks"
    vpc_id = aws_vpc.dpp-vpc.id
    subnet_ids = [aws_subnet.dpp-public-subnet-01.id,aws_subnet.dpp-public-subnet-02.id]
    sg_ids = module.sgs.security_group_public
}
