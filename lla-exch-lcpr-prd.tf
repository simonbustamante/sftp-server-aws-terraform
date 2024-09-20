locals {
  profile_prd = "876881173184_LLA-DL_DevOps"
  region_prd = "us-east-1"
  server_name_tag_prd = "sftp_lcpr_plume_prd"
  # role_prd = "arn:aws:iam::876881173184:role/lla-exch-lcpr-prod-transfer-family-role"
  user_name_prd = "sftp_lcpr_plume_prd_user"
  entry_prd = "/lcpr/plume"
  target_prd = "/source.lcpr.prod/lcpr/plume"
  pub_prv_key_prd = "sftp_lcpr_plume_prd_key"
  password_pub_prv_key_prd = "LlaLcpr2024!#"
  csv_output_file = "sftp_credentials_prd.csv"
}

provider "aws" {
  alias   = "prd"
  profile = local.profile_prd
  region  = local.region_prd
}

# create role
resource "aws_iam_role" "transfer_family_role_prd" {
  provider = aws.prd
  name               = "lla-exch-lcpr-prod-transfer-family-role"
  assume_role_policy = file("lla-exch-lcpr-prod-transfer-family-role.json")
  lifecycle {
    prevent_destroy = true
  }
}

# create policy
resource "aws_iam_policy" "transfer_family_policy_prd" {
  provider = aws.prd
  name        = "lla-exch-lcpr-prod-transfer-family-policy"
  description = "IAM policy for Transfer Family role to access S3 bucket and manage Transfer resources"

  policy = file("lla-exch-lcpr-prod-transfer-family-policy.json")
  lifecycle {
    prevent_destroy = true
  }
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "transfer_family_policy_attachment_prd" {
  provider  = aws.prd
  role      = aws_iam_role.transfer_family_role_prd.name
  policy_arn = aws_iam_policy.transfer_family_policy_prd.arn
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
    role              = aws_iam_role.transfer_family_role_prd.arn
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
    command = "aws transfer update-server --region ${local.region_prd} --server-id ${aws_transfer_server.sftp_server_prd.id} --protocol-details SetStatOption=ENABLE_NO_OP --profile ${local.profile_prd}"
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

resource "null_resource" "export_to_csv_prd" {
  provisioner "local-exec" {
    command = "echo 'user_name,password,endpoint' > ${local.csv_output_file} && echo '${local.user_name_prd},${local.password_pub_prv_key_prd},sftp://${aws_transfer_server.sftp_server_prd.endpoint}' >> ${local.csv_output_file}"
  }
  depends_on = [aws_transfer_ssh_key.ssh_key_prd]
}
