#### Json template for the lambda iam policy ####
data "template_file" "lambda-policy-template" {
  template = "${file("policy.json.tpl")}"
  vars = {
    secret-arn         = aws_secretsmanager_secret.tvdb.arn
    sns-topic-arn      = aws_sns_topic.notification.arn
    dynamodb-table-arn = aws_dynamodb_table.episode-table.arn
  }
}

#### Lambda policy resource ####
resource "aws_iam_policy" "lambda-policy" {
  name   = "${var.lambda_function_name}-policy"
  policy = "${data.template_file.lambda-policy-template.rendered}"
}

#### Lambda assume role policy ####
data "aws_iam_policy_document" "lambda-assume-role-policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

#### Lambda execution role  ####
resource "aws_iam_role" "lambdarole" {
  name               = var.lambda_role_name
  description        = "lambda execution role for ${var.lambda_function_name}"
  assume_role_policy = "${data.aws_iam_policy_document.lambda-assume-role-policy.json}"

  tags = local.common_tags
}

#### Lambda execution role policy attachment ####
resource "aws_iam_role_policy_attachment" "lambda-policy-attach" {
  role       = aws_iam_role.lambdarole.name
  policy_arn = aws_iam_policy.lambda-policy.arn
}