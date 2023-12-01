locals {
  profile_dev = "507964037226_AWSAdministratorAccess"
  region_dev = "us-east-1"
  server_name_tag_dev = "sftp_zeus_server_hq_rpa_dev"
  role_dev = "arn:aws:iam::507964037226:role/svc-role-data-mic-development-integrations"
  user_name_dev = "sftp_zeus_user_hq_rpa_dev"
  entry_dev = "/zeus_rpa_sftp"
  target_dev = "/s3-hq-raw-dev-finan/zeus_rpa_sftp"
  pub_prv_key_dev = "sftp_user_key_hq_rpa_dev"
  email_pub_prv_key_dev = "zeus-hq-rpa@youremail.com"
  password_pub_prv_key_dev = "yourpass"
}

provider "aws" {
  alias   = "dev"
  profile = local.profile_dev
  region  = local.region_dev
}

resource "aws_transfer_server" "sftp_server_dev" {
    provider = aws.dev
    identity_provider_type = "SERVICE_MANAGED"
    endpoint_type          = "PUBLIC"
    protocols              = ["SFTP"]
    
    tags = {
        Name = local.server_name_tag_dev
        Environment = "dev"
    }
}

resource "aws_transfer_user" "sftp_user_dev" {
    provider          = aws.dev
    server_id         = aws_transfer_server.sftp_server_dev.id
    role              = local.role_dev
    user_name         = local.user_name_dev 
    

    home_directory_type = "PATH"

    # home_directory_mappings {
    #     entry  = local.entry_dev
    #     target = local.target_dev
    # }
    home_directory = local.target_dev

    tags = {
        Name    = "sftp_user_dev"
        Purpose = "SFTP access to zeus_sftp folder in s3-hq-anl-dev-ntwrk"
    }

    depends_on = [aws_transfer_server.sftp_server_dev]
}

resource "null_resource" "setstat_enable_dev" {
  provisioner "local-exec" {
    command = "aws transfer update-server --server-id ${aws_transfer_server.sftp_server_dev.id} --protocol-details SetStatOption=ENABLE_NO_OP --profile ${local.profile_dev}"
  }
  depends_on = [aws_transfer_server.sftp_server_dev]
}

resource "null_resource" "generate_public_private_keys_dev" {
  provisioner "local-exec" {
    command = "if [ -f ${local.pub_prv_key_dev} ]; then rm -f ${local.pub_prv_key_dev}* ; fi; ssh-keygen -t rsa -b 4096 -C ${local.email_pub_prv_key_dev} -f ${local.pub_prv_key_dev} -N ${local.password_pub_prv_key_dev}"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [aws_transfer_server.sftp_server_dev]
}

locals {
  public_key_dev = null_resource.generate_public_private_keys_dev.triggers.always_run != "" ? file("${local.pub_prv_key_dev}.pub") : ""
  depends_on = [null_resource.generate_public_private_keys_dev]
}

resource "aws_transfer_ssh_key" "ssh_key_dev" {
    provider = aws.dev
    server_id = "${aws_transfer_server.sftp_server_dev.id}"
    user_name = local.user_name_dev
    body      = local.public_key_dev
}

