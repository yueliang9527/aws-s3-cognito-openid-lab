# Create Cognito and associate IAM Roles

//resource "aws_iam_openid_connect_provider" "oidc1" {
//  client_id_list = ["${var.oidc_audience}"]
//  thumbprint_list = []
//  url = "${var.oidc_url}"
//}

resource "aws_cognito_identity_pool" "identity_pool" {
  identity_pool_name = "identity_${random_string.suffix.result}"
  allow_unauthenticated_identities = false
  openid_connect_provider_arns = [var.openid_provider_arn]
}

resource "aws_iam_role" "cognito_unauthenticated_role" {
  name = "cognito-unauthenticated-${random_string.suffix.result}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.domain}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${var.domain}:aud": "${var.clientId}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role" "cognito_authenticated_role" {
  name = "cognito-authenticated-${random_string.suffix.result}"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${var.domain}"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "${var.domain}:aud": "${var.clientId}"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "s3_access_policy" {
  role = aws_iam_role.cognito_authenticated_role.id
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListYourObjects",
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.s3.bucket}"
            ],
            "Condition": {
                "StringLike": {
                    "s3:prefix": [
                        "${var.app}/$${${var.domain}:sub}"
                    ]
                }
            }
        },
        {
            "Sid": "ReadWriteDeleteYourObjects",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.s3.bucket}/${var.app}/$${${var.domain}:sub}",
                "arn:aws:s3:::${aws_s3_bucket.s3.bucket}/${var.app}/$${${var.domain}:sub}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_cognito_identity_pool_roles_attachment" "identity_roles_attachment" {
  identity_pool_id = aws_cognito_identity_pool.identity_pool.id
  roles = {
    authenticated = aws_iam_role.cognito_authenticated_role.arn
    unauthenticated = aws_iam_role.cognito_unauthenticated_role.arn
  }
}

