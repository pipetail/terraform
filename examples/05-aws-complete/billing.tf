resource "aws_budgets_budget" "cost" {
  name        = "overall-cost"
  budget_type = "COST"

  limit_amount = "100" // if the bill is higher we are probably doing something wrong here
  limit_unit   = "USD"

  time_unit = "MONTHLY"

  notification {
    comparison_operator = "GREATER_THAN"
    notification_type   = "ACTUAL"

    subscriber_email_addresses = var.notification_emails

    threshold      = 90
    threshold_type = "PERCENTAGE"
  }
}
