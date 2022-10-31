resource "aws_cloudwatch_event_rule" "cw-event" {
  name                = "${var.project_name}Scheduled${var.action}"
  description         = "Triggers a lambda to ${var.action} an instance on a schedule."
  schedule_expression = var.schedule_expression
}

resource "aws_cloudwatch_event_target" "cw-event-target" {
  rule = aws_cloudwatch_event_rule.cw-event.name
  arn  = var.target_arn
}

resource "aws_lambda_permission" "cw-event-permission-start" {
  statement_id  = "AllowExecutionFromCloudwatch"
  action        = "lambda:InvokeFunction"
  function_name = var.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cw-event.arn
}



