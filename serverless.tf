# SNS Topic for order notifications
resource "aws_sns_topic" "order_notifications" {
  name = "order-notifications-topic"
}

# SQS Queue for processing orders
resource "aws_sqs_queue" "order_queue" {
  name = "order-processing-queue"
 visibility_timeout_seconds = 300
}

# Subscribe SQS Queue to SNS Topic
resource "aws_sns_topic_subscription" "sqs_subscription" {
  topic_arn              = aws_sns_topic.order_notifications.arn
  protocol               = "sqs"
  endpoint               = aws_sqs_queue.order_queue.arn
  endpoint_auto_confirms = true
}

# Add SQS Policy to allow SNS to send messages
resource "aws_sqs_queue_policy" "sqs_policy" {
  queue_url = aws_sqs_queue.order_queue.url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "SQS:SendMessage"
        Resource  = aws_sqs_queue.order_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.order_notifications.arn
          }
        }
      }
    ]
  })
}

# DynamoDB table for orders
resource "aws_dynamodb_table" "orders_table" {
  name         = "Orders"
  hash_key     = "order_id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "order_id"
    type = "S"
  }
}

# DynamoDB table for inventory
resource "aws_dynamodb_table" "inventory_table" {
  name         = "Inventory"
  hash_key     = "item_id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "item_id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "processed_orders" {
  name         = "processed-orders-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "order_id"

  attribute {
    name = "order_id"
    type = "S"
  }

  tags = {
    Name = "processed-orders-table"
  }
}


# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for Lambda to write to CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_cloudwatch" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# IAM Policy for Lambda to interact with SQS
resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name = "lambda_sqs_policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.order_queue.arn
      }
    ]
  })
}

# IAM Policy for Lambda to interact with DynamoDB
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_dynamodb" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# IAM Policy for Lambda to send emails via SES
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment_ses" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}

# Create a zip archive of the Lambda function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_function"
  output_path = "${path.module}/lambda_function.zip"
}

# Lambda Function for order processing
resource "aws_lambda_function" "order_processing_lambda" {
  function_name = "process-order"

  filename         = data.archive_file.lambda_zip.output_path
  runtime          = "python3.12"
  handler          = "lambda_function.lambda_handler"
  role             = aws_iam_role.lambda_exec_role.arn
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      ORDER_TABLE     = aws_dynamodb_table.orders_table.name
      INVENTORY_TABLE = aws_dynamodb_table.inventory_table.name
      PROCESSED_ORDERS_TABLE = aws_dynamodb_table.processed_orders.name
    }
  }
}

# Trigger Lambda on SQS Messages
resource "aws_lambda_event_source_mapping" "lambda_sqs_trigger" {
  event_source_arn = aws_sqs_queue.order_queue.arn
  function_name    = aws_lambda_function.order_processing_lambda.arn
  batch_size       = 10
  enabled          = true
}
