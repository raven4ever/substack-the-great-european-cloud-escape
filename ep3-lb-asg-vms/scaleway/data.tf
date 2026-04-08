data "scaleway_marketplace_image" "ubuntu" {
  label = "ubuntu_noble"
  instance_type = local.instance_type
}

data "cloudinit_config" "app" {
  gzip          = false
  base64_encode = false

  part {
    content_type = "text/cloud-config"
    filename     = "cloud-config.yaml"
    content = yamlencode({
      package_update  = true
      package_upgrade = true
      packages        = ["python3", "python3-venv"]
      users = [
        {
          name                = "vmuser"
          plain_text_passwd   = var.vm_password
          lock_passwd         = false
          shell               = "/bin/bash"
          sudo                = "ALL=(ALL) NOPASSWD:ALL"
          ssh_authorized_keys = []
        },
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
