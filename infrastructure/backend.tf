
terraform {
  backend "s3" {
    bucket       = "aci-capstone1-remote-state"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}