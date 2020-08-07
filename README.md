# Deploy Snikket to AWS using Terraform

Terraform is a tool for describing "infrastructure as code". This project
contains a description of a Snikket deployment on AWS. By running it on
an AWS account Terraform will automatically set up a brand new configured
Snikket instance.

This repository is intended for development, testing and demo purposes, rather
than a production setup.

See terraform.tfvars.example for configuration options you need to provide
before running terraform.

Your chosen domain name needs to already be delegated to Route53 (as a "hosted
zone"), and you need a VPC (all new AWS accounts have one by default).
