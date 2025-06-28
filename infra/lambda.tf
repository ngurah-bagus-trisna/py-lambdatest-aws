resource "aws_iam_policy" "lambda-policy" {
  name        = "lambdaPolicy"
  path        = "/"
  description = "Allow write to S3 and read System Parameter"

  policy = jsonencode({
    "Version" = "2012-10-17",
    "Statement" = [
      {
        "Sid"    = "AllowPutObject",
        "Effect" = "Allow",
        "Action" = [
          "s3:PutObject"
        ],
        "Resource" = [
          "*"
        ]
      },
      {
        "Sid"    = "AllowGetParameterSSM",
        "Effect" = "Allow",
        "Action" = [
          "ssm:GetParameter"
        ],
        "Resource" = [
          "*"
        ]
      },
      {
        "Sid"    = "AllowGetSecretValue",
        "Effect" = "Allow",
        "Action" = [
          "secretsmanager:GetSecretValue"
        ],
        "Resource" = [
          "*"
        ]
      },
      {
        "Sid": "AllowManageENI",
        "Effect": "Allow",
        "Action": [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        "Resource": "*"
      },
      {
        "Sid": "AllowCloudWatchLogs",
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "*"
      }
    ]
    }
  )
}

resource "aws_iam_role" "reporting_lambda_role" {
  depends_on = [aws_iam_policy.lambda-policy]
  name       = "ReportingLambdaRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  depends_on = [
    aws_iam_policy.lambda-policy,
    aws_iam_role.reporting_lambda_role
  ]
  role       = aws_iam_role.reporting_lambda_role.name
  policy_arn = aws_iam_policy.lambda-policy.arn
}

resource "aws_lambda_function" "db_to_s3_lambda" {
  depends_on = [
    aws_db_instance.nb-db,
    aws_s3_bucket.nb-quest-reports,
    aws_iam_role_policy_attachment.lambda_policy_attachment
  ]
  function_name    = "dbToS3Lambda"
  handler          = "app.lambda_handler"
  runtime          = "python3.12"
  filename         = "${path.module}/lambda.zip"
  role             = aws_iam_role.reporting_lambda_role.arn
  source_code_hash = filebase64sha256("${path.module}/lambda.zip")
  timeout          = 10

  vpc_config {
    subnet_ids = [aws_subnet.nb-subnet["private-net-1"].id]
    security_group_ids = [aws_security_group.rds-sg.id, aws_security_group.web-sg.id]
  }
  
  environment {
    variables = {
      SECRET_NAME = aws_db_instance.nb-db.master_user_secret[0].secret_arn
      BUCKET_NAME = aws_s3_bucket.nb-quest-reports.id
      DB_HOST     = aws_db_instance.nb-db.address
      DB_USER     = aws_db_instance.nb-db.username
      DB_NAME     = aws_db_instance.nb-db.db_name
    }
  }
}