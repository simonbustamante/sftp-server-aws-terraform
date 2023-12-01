locals {
  profile_prd = "525196274797_AWSAdministratorAccess"
  region_prd = "us-east-1"
  server_name_tag_prd = "sftp_zeus_server_hq_rpa_prd"
  role_prd = "arn:aws:iam::525196274797:role/svc-role-data-mic-development-integrations"
  user_name_prd = "sftp_zeus_user_hq_rpa_prd"
  entry_prd = "/zeus_rpa_sftp"
  target_prd = "/s3-hq-raw-prd-finan/zeus_rpa_sftp"
  pub_prv_key_prd = "sftp_user_key_hq_rpa_prd"
  email_pub_prv_key_prd = "zeus-hq-rpa@youremail.com"
  password_pub_prv_key_prd = "yourpass"
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
        Name    = "sftp_user_prd"
        Purpose = "SFTP access to zeus_sftp folder in s3-hq-anl-prd-ntwrk"
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
    command = "if [ -f ${local.pub_prv_key_prd} ]; then rm -f ${local.pub_prv_key_prd}* ; fi; ssh-keygen -t rsa -b 4096 -C ${local.email_pub_prv_key_prd} -f ${local.pub_prv_key_prd} -N ${local.password_pub_prv_key_prd}"
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

