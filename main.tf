data "aws_vpc" "default" {
  id = var.vpc_id
}

data "aws_subnet" "default" {
  vpc_id            = data.aws_vpc.default.id
  availability_zone = var.aws_zone
}

data "aws_route53_zone" "selected" {
  name = "${var.dns_zone}."
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

data "template_cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud-init.yml"
    content_type = "text/cloud-config"
    content      = file("cloud-init.yml")
  }

  part {
    content_type = "text/x-shellscript"
    content = templatefile("setup.sh", {
      tf_version     = var.snikket_version
      tf_domain      = var.domain
      tf_admin_email = var.admin_email

      tf_import_test_data = var.import_test_data
    })
  }
}

resource "aws_security_group" "allow_ssh" {
  name_prefix = "snikket_allow_ssh"
  description = "Allow SSH access from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_snikket_all" {
  name_prefix = "snikket_allow_ports"
  description = "Allow access to a Snikket server from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "XMPP c2s"
    from_port   = 5222
    to_port     = 5223
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "XMPP s2s"
    from_port   = 5269
    to_port     = 5269
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "XMPP proxy service"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_stun_turn_server" {
  name_prefix = "snikket_allow_turn"
  description = "Allow access to a STUN/TURN server"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "STUN (TCP)"
    from_port   = 3478
    to_port     = 3479
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "STUN (UDP)"
    from_port   = 3478
    to_port     = 3479
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TURN (TCP)"
    from_port   = 5349
    to_port     = 5350
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TURN (UDP)"
    from_port   = 5349
    to_port     = 5350
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TURN relay (UDP)"
    from_port   = 49152
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "snikket" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3a.nano"

  subnet_id                   = data.aws_subnet.default.id
  associate_public_ip_address = true
  vpc_security_group_ids = [
    aws_security_group.allow_snikket_all.id,
    aws_security_group.allow_stun_turn_server.id,
    aws_security_group.allow_ssh.id
  ]

  key_name = var.key_name

  user_data_base64 = data.template_cloudinit_config.config.rendered

  tags = {
    Name = "snikket (${var.domain})"
  }
}

resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = data.aws_route53_zone.selected.name
  type    = "A"
  ttl     = "60"
  records = [aws_instance.snikket.public_ip]
}

resource "aws_route53_record" "groups" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "groups"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_route53_record.primary.name]
}

resource "aws_route53_record" "share" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "share"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_route53_record.primary.name]
}
