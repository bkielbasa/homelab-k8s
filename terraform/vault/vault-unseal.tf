# AWS KMS auto-unseal for Vault.
#
# Vault calls KMS Encrypt/Decrypt on pod start to seal/unseal itself instead of
# requiring Shamir keys. After the one-time seal migration (run manually with
# `vault operator unseal -migrate`), pod restarts no longer need human input.
#
# The Shamir keys become *recovery keys* post-migration — keep them; they are
# still needed for root-token generation and disaster recovery.

resource "aws_kms_key" "vault_unseal" {
  description             = "Homelab Vault auto-unseal"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    purpose = "vault-auto-unseal"
  }
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/homelab-vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}

resource "aws_iam_user" "vault_unseal" {
  name = "homelab-vault-unseal"
}

resource "aws_iam_user_policy" "vault_unseal" {
  name = "kms-unseal"
  user = aws_iam_user.vault_unseal.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:DescribeKey",
      ]
      Resource = aws_kms_key.vault_unseal.arn
    }]
  })
}

resource "aws_iam_access_key" "vault_unseal" {
  user = aws_iam_user.vault_unseal.name
}

# Bootstrap-stable secret: cannot come from Vault itself (it would be sealed),
# so it lives in TF state (encrypted in S3) and is rendered directly into a
# Kubernetes Secret consumed by the Vault pods as env vars at startup.
resource "kubernetes_secret" "vault_unseal_aws" {
  metadata {
    name      = "vault-unseal-aws"
    namespace = "vault"
  }

  data = {
    AWS_ACCESS_KEY_ID     = aws_iam_access_key.vault_unseal.id
    AWS_SECRET_ACCESS_KEY = aws_iam_access_key.vault_unseal.secret
  }
}
