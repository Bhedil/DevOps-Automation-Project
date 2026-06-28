provider "aws" {
    region = "ap-southeast-3"
}

resource "aws_instance" "demo-server" {
    ami = "ami-0e46b9cac0942842d"
    instance_type = "t3.micro"
    key_name = "ansible-lab"
}

