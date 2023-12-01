# Terraform Configuration for SFTP Servers on AWS

This document outlines the Terraform setup for deploying SFTP servers on AWS for Development, Production, and UAT environments. We use AWS Transfer Family to create and manage these servers.

## Project Structure

The code is divided into three main sections, each corresponding to a different environment: Development (DEV), Production (PRD), and User Acceptance Testing (UAT).

### Common Configuration

All environments share a common structure that includes:

- **Provider Configuration**: Configures the AWS provider with specific profiles and regions.
- **Resource Definitions**: Defines the necessary AWS resources, such as SFTP servers and users.
- **Local Values**: Stores reusable values like roles, usernames, and directory configurations.

### Local Variables

Local variables for each environment are defined at the beginning of the file. For example, for the development environment:

```hcl
locals {
  profile_dev = "507964037226_AWSAdministratorAccess"
  region_dev = "us-east-1"
  // other values...
}
```

Replace these with your specific configurations.

### AWS Resources

The main resources include:

- **AWS Transfer Server**: Creates an SFTP server.
- **AWS Transfer User**: Configures users for SFTP access.
- **SSH Keys Management**: Generates and manages SSH keys for users.

### Resource Example

Here’s an example of how an SFTP server is defined for the development environment:

```hcl
resource "aws_transfer_server" "sftp_server_dev" {
    provider = aws.dev
    // other parameters...
}
```

Repeat this pattern for the Production and UAT environments, adjusting the local variables and resources as necessary.

## Usage

To apply this Terraform configuration:

1. Ensure you have Terraform installed and configured.
2. Clone this repository to your local machine.
3. Navigate to the project directory and run `terraform init` to initialize the project.
4. Apply the configuration with `terraform apply`.

## Important Notes

- Be sure to review and understand each part of the configuration before applying it.
- Consider security best practices, such as proper handling of SSH keys and passwords.

