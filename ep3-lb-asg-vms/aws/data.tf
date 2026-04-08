data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "cloudinit_config" "app" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    content = yamlencode({
      package_update  = true
      package_upgrade = true
      packages        = ["python3", "python3-venv", "amazon-ssm-agent"]
      runcmd = [
        ["systemctl", "enable", "amazon-ssm-agent"],
        ["systemctl", "start", "amazon-ssm-agent"],
      ]
    })
  }

  part {
    content_type = "text/x-shellscript"
    filename     = "setup.sh"
    content      = file(format("%s/setup.sh", local.app_dir))
  }

  part {
    content_type = "text/cloud-config"
    filename     = "write-files.yaml"
    content = yamlencode({
      write_files = [
        {
          path        = "/app/app.py"
          permissions = "0644"
          content     = file(format("%s/app.py", local.app_dir))
        },
        {
          path        = "/app/requirements.txt"
          permissions = "0644"
          content     = file(format("%s/requirements.txt", local.app_dir))
        },
        {
          path        = "/etc/systemd/system/app.service"
          permissions = "0644"
          content     = file(format("%s/app.service", local.app_dir))
        },
      ]
    })
  }
}
