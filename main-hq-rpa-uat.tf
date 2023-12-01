locals {
  profile_uat = "350281604643_AWSAdministratorAccess"
  region_uat = "us-east-1"
  server_name_tag_uat = "sftp_zeus_server_hq_rpa_uat"
  role_uat = "arn:aws:iam::350281604643:role/svc-role-data-mic-development-integrations"
  user_name_uat = "sftp_zeus_user_hq_rpa_uat"
  entry_uat = "/zeus_rpa_sftp"
  target_uat = "/s3-hq-raw-uat-finan/zeus_rpa_sftp"
  pub_prv_key_uat = "sftp_user_key_hq_rpa_uat"
  email_pub_prv_key_uat = "zeus-hq-rpa@youremail.com"
  password_pub_prv_key_uat = "yourpass"
}

provider "aws" {
  alias   = "uat"
  profile = local.profile_uat
  region  = local.region_uat
}

resource "aws_transfer_server" "sftp_server_uat" {
    provider = aws.uat
    identity_provider_type = "SERVICE_MANAGED"
    endpoint_type          = "PUBLIC"
    protocols              = ["SFTP"]
    
    tags = {
        Name = local.server_name_tag_uat
        Environment = "uat"
    }
}

resource "aws_transfer_user" "sftp_user_uat" {
    provider          = aws.uat
    server_id         = aws_transfer_server.sftp_server_uat.id
    role              = local.role_uat
    user_name         = local.user_name_uat 
    

    home_directory_type = "PATH"

    # home_directory_mappings {
    #     entry  = local.entry_uat
    #     target = local.target_uat
    # }
    home_directory = local.target_uat

    tags = {
        Name    = "sftp_user_uat"
        Purpose = "SFTP access to zeus_sftp folder in s3-hq-anl-uat-ntwrk"
    }

    depends_on = [aws_transfer_server.sftp_server_uat]
}

resource "null_resource" "setstat_enable_uat" {
  provisioner "local-exec" {
    command = "aws transfer update-server --server-id ${aws_transfer_server.sftp_server_uat.id} --protocol-details SetStatOption=ENABLE_NO_OP --profile ${local.profile_uat}"
  }
  depends_on = [aws_transfer_server.sftp_server_uat]
}

resource "null_resource" "generate_public_private_keys_uat" {
  provisioner "local-exec" {
    command = "if [ -f ${local.pub_prv_key_uat} ]; then rm -f ${local.pub_prv_key_uat}* ; fi; ssh-keygen -t rsa -b 4096 -C ${local.email_pub_prv_key_uat} -f ${local.pub_prv_key_uat} -N ${local.password_pub_prv_key_uat}"
  }
  triggers = {
    always_run = "${timestamp()}"
  }
  depends_on = [aws_transfer_server.sftp_server_uat]
}

locals {
  public_key_uat = null_resource.generate_public_private_keys_uat.triggers.always_run != "" ? file("${local.pub_prv_key_uat}.pub") : ""
  depends_on_uat = [null_resource.generate_public_private_keys_uat]
}

resource "aws_transfer_ssh_key" "ssh_key_uat" {
    provider = aws.uat
    server_id = "${aws_transfer_server.sftp_server_uat.id}"
    user_name = local.user_name_uat
    body      = local.public_key_uat
}

