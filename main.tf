provider "aws" {
  version = "~> 2.9"
  region  = "us-east-1"
}

#### Backend Bucket ####
resource "aws_s3_bucket" "tf-state-bucket" {
  # Update backend.tf with new value
  bucket = "aws-dateline-lambda-state-bucket"
  versioning {
    enabled = true
  }
  acl           = "private"
  force_destroy = true

  tags = local.common_tags
}

#### Backend Dynamodb Table ####
resource "aws_dynamodb_table" "tf-state-table" {
  # Update backend.tf with new value
  name         = "aws-dateline-lambda-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }

  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "tvdb" {
  name                    = var.secret_name
  recovery_window_in_days = 0

  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "tvdb" {
  secret_id     = aws_secretsmanager_secret.tvdb.id
  secret_string = "${jsonencode(local.tvdbkeys)}"
}

resource "aws_sns_topic" "notification" {
  name = var.sns_topic_name

  tags = local.common_tags
}

resource "aws_sns_topic_subscription" "sms" {
  topic_arn = aws_sns_topic.notification.arn
  protocol  = "sms"
  endpoint  = var.sns_sms_endpoint
}

resource "aws_cloudwatch_log_group" "example" {
  name              = "/aws/lambda/${var.lambda_function_name}"
  retention_in_days = 14

  tags = local.common_tags
}

resource "aws_dynamodb_table" "episode-table" {
  # Update backend.tf with new value
  name         = "dateline-lambda"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "internalId"
  attribute {
    name = "internalId"
    type = "S"
  }

  tags = local.common_tags
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "source"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "test_lambda" {
  filename         = "lambda.zip"
  function_name    = "dateline-lambda"
  role             = "${aws_iam_role.lambdarole.arn}"
  handler          = "lambda.handler"
  timeout          = 60
  memory_size      = 128
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  runtime          = "python3.6"

  environment {
    variables = {
      topicArn  = aws_sns_topic.notification.arn
      secretArn = aws_secretsmanager_secret.tvdb.arn
      tableName = aws_dynamodb_table.episode-table.name
    }
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_event_rule" "every_hour" {
  name                = "every-hour"
  description         = "Fires every hour"
  schedule_expression = "rate(1 hour)"
}

resource "aws_cloudwatch_event_target" "check_foo_every_five_minutes" {
  rule      = "${aws_cloudwatch_event_rule.every_hour.name}"
  target_id = "dateline-lambda"
  arn       = "${aws_lambda_function.test_lambda.arn}"
}

resource "aws_lambda_permission" "allow_cloudwatch_to_call_check_foo" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.test_lambda.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.every_hour.arn}"
}

resource "aws_resourcegroups_group" "dateline-lambda" {
  name = "rg-${var.pipeline-name}"

  resource_query {
    query = <<JSON
{
  "ResourceTypeFilters": [
    "AWS::AllSupported"
  ],
  "TagFilters": [
    {
      "Key": "pipeline",
      "Values": ["${var.pipeline-name}"]
    }
  ]
}
JSON
  }
}