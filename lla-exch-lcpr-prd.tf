locals {
  profile_prd = "876881173184_LLA-DL_DevOps"
  region_prd = "us-east-1"
  server_name_tag_prd = "sftp_lcpr_plume_prd"
  role_prd = "arn:aws:iam::876881173184:role/lla-exch-lcpr-prod-transfer-family-role"
  user_name_prd = "sftp_lcpr_plume_prd_user"
  entry_prd = "/lcpr/plume"
  target_prd = "/source.lcpr.prod/lcpr/plume"
  pub_prv_key_prd = "sftp_lcpr_plume_prd_key"
  password_pub_prv_key_prd = "LlaLcpr2024#$!"
}

provider "aws" {
  alias   = "prd"
  profile = local.profile_prd
  region  = local.region_prd
}

resource "aws_transfer_server" "sftp_server_prd" {
    provider = aws.prd
    identity_provider_type = "SERVICE_MANAGED"
    endpoint_type          = "PUBLIC"
    protocols              = ["SFTP"]
    
    tags = {
        Name = local.server_name_tag_prd
        Environment = "prd"
    }
}

resource "aws_transfer_user" "sftp_user_prd" {
    provider          = aws.prd
    server_id         = aws_transfer_server.sftp_server_prd.id
    role              = local.role_prd
    user_name         = local.user_name_prd 
    

    home_directory_type = "PATH"

    # home_directory_mappings {
    #     entry  = local.entry_prd
    #     target = local.target_prd
    # }
    home_directory = local.target_prd

    tags = {
        Name    = "sftp_lcpr_plume_prd"
        Purpose = "SFTP access to Plume in source.lcpr.prod/lcpr/plume"
    }

    depends_on = [aws_transfer_server.sftp_server_prd]
}

resource "null_resource" "setstat_enable_prd" {
  provisioner "local-exec" {
    command = "aws transfer update-server --server-id ${aws_transfer_server.sftp_server_prd.id} --protocol-details SetStatOption=ENABLE_NO_OP --profile ${local.profile_prd}"
  }
  depends_on = [aws_transfer_server.sftp_server_prd]
}

resource "null_resource" "generate_public_private_keys_prd" {
  provisioner "local-exec" {
    command = "if [ -f ${local.pub_prv_key_prd} ]; then rm -f ${local.pub_prv_key_prd}* ; fi; ssh-keygen -t rsa -b 2048 -f ${local.pub_prv_key_prd} -N ${local.password_pub_prv_key_prd}"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [aws_transfer_server.sftp_server_prd]
}

locals {
  public_key_prd = null_resource.generate_public_private_keys_prd.triggers.always_run != "" ? file("${local.pub_prv_key_prd}.pub") : ""
  depends_on_prd = [null_resource.generate_public_private_keys_prd]
}

resource "aws_transfer_ssh_key" "ssh_key_prd" {
    provider = aws.prd
    server_id = "${aws_transfer_server.sftp_server_prd.id}"
    user_name = local.user_name_prd
    body      = local.public_key_prd
}

