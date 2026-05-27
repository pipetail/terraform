# aws-events-to-slack

Forwards AWS events, maintenance alerts, and budget notifications to Slack via a small
Node.js Lambda. The module wires up the Lambda and its event sources:

- **AWS Health** events (EventBridge), with configurable category filtering.
- **Daily scheduled check** for pending maintenance, engine/EKS EOL, expiring certificates,
  stale AMIs/snapshots, old IAM access keys, and unused savings plans.
- **Budget & cost-anomaly** alerts (SNS + Cost Explorer anomaly monitor).
- **CloudTrail** security API calls and console logins (optional).
- **RDS** event notifications (optional).
- A **CloudWatch error alarm** on the Lambda, delivered to SNS email subscribers.

## Lambda distribution

The Lambda package is **not** vendored in consumer repos and there is **no S3 deployment
bucket**. Each tagged release of this repository publishes a reproducible
`aws-events-to-slack-<version>.zip` (plus its `.b64sha256`) as a GitHub release asset.
At apply time the module downloads the pinned `var.lambda_version` artifact and deploys it
directly as the function package. Set `lambda_version` to the released version and that is
the only artifact a consumer needs to track.

```hcl
module "aws_events_to_slack" {
  source = "github.com/pipetail/terraform//modules/aws-events-to-slack?ref=aws-events-to-slack-v1.0.0"

  lambda_version = "1.0.0"
  account_name   = "my-account"
  regions        = "eu-west-1"
  slack_channel  = "#aws-health"
}
```

Requires `curl` to be available wherever Terraform applies (CI runners and most workstations
already have it).

## AWS Health regions

AWS Health delivers events for global services (IAM, CloudFront, Route 53, ...) to
`us-east-1`, while regional events arrive in their own region. To capture the global ones,
deploy a second, Health-only instance through a `us-east-1` aliased provider with
`create_account_global_resources = false` and a distinct `name`. See
`examples/05-aws-complete/events.tf`.

## Slack credentials

`slack_webhook_secret_arn` is the ARN of an externally-managed Secrets Manager secret holding a
`WEBHOOK_URL` key and, optionally, a `SLACK_BOT_TOKEN` key. The secret is created and owned outside
this module. When a bot token and `slack_channel` are present the function posts via
`chat.postMessage`, otherwise it falls back to the incoming webhook.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.0 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_ce_anomaly_monitor.cost](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_monitor) | resource |
| [aws_ce_anomaly_subscription.cost](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_subscription) | resource |
| [aws_cloudwatch_event_rule.cloudtrail_api_calls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.cloudtrail_console_login](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.daily_check](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_rule.health_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.cloudtrail_api_calls](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.cloudtrail_console_login](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.daily_check](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_event_target.health_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_metric_alarm.lambda_errors](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_permission.eventbridge_cloudtrail_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.eventbridge_cloudtrail_login](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.eventbridge_daily_check](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.eventbridge_health](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.sns_budget_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.sns_db_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_sns_topic.budgets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic.db_monitoring](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic.lambda_alerts](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.budgets](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.budget_alerts_to_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.db_monitoring_to_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_sns_topic_subscription.lambda_alerts_email](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [null_resource.lambda_package](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_secretsmanager_secret_version.slack_webhook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |
| [http_http.lambda_package_hash](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_key_warning_days"></a> [access\_key\_warning\_days](#input\_access\_key\_warning\_days) | Warn when IAM access keys are older than this many days | `number` | `365` | no |
| <a name="input_account_name"></a> [account\_name](#input\_account\_name) | AWS account name for Slack notifications | `string` | n/a | yes |
| <a name="input_anomaly_threshold"></a> [anomaly\_threshold](#input\_anomaly\_threshold) | Cost anomaly threshold in USD | `string` | `"50"` | no |
| <a name="input_cloudtrail_enabled"></a> [cloudtrail\_enabled](#input\_cloudtrail\_enabled) | Enable CloudTrail security event forwarding via EventBridge | `bool` | `false` | no |
| <a name="input_create_account_global_resources"></a> [create\_account\_global\_resources](#input\_create\_account\_global\_resources) | Create account-global resources (daily scheduled check, budget/cost-anomaly SNS, Cost Explorer anomaly monitor). Set false on secondary-region instances that should only capture regional EventBridge events. | `bool` | `true` | no |
| <a name="input_daily_check_schedule"></a> [daily\_check\_schedule](#input\_daily\_check\_schedule) | EventBridge schedule expression for the daily maintenance/EOL/hygiene check | `string` | `"cron(0 9 * * ? *)"` | no |
| <a name="input_health_event_categories"></a> [health\_event\_categories](#input\_health\_event\_categories) | AWS Health event categories (eventTypeCategory) to forward. Empty list (default) forwards all categories. Valid values: issue, accountNotification, scheduledChange, investigation. | `list(string)` | `[]` | no |
| <a name="input_lambda_version"></a> [lambda\_version](#input\_lambda\_version) | Version of the published aws-events-to-slack Lambda package to deploy. Resolves to the GitHub release asset aws-events-to-slack-<version>.zip from tag aws-events-to-slack-v<version>. | `string` | n/a | yes |
| <a name="input_log_retention_days"></a> [log\_retention\_days](#input\_log\_retention\_days) | CloudWatch log group retention in days for the Lambda | `number` | `30` | no |
| <a name="input_name"></a> [name](#input\_name) | Name prefix for all created resources (function, IAM role, event rules, SNS topics). Use a distinct value per module instance to avoid collisions. | `string` | `"aws-events-to-slack"` | no |
| <a name="input_notification_emails"></a> [notification\_emails](#input\_notification\_emails) | List of emails to notify on Lambda errors | `list(string)` | `[]` | no |
| <a name="input_rds_monitoring_enabled"></a> [rds\_monitoring\_enabled](#input\_rds\_monitoring\_enabled) | Enable RDS monitoring SNS topic and Lambda subscription | `bool` | `false` | no |
| <a name="input_regions"></a> [regions](#input\_regions) | Comma-separated AWS regions for multi-region checks | `string` | n/a | yes |
| <a name="input_slack_channel"></a> [slack\_channel](#input\_slack\_channel) | Slack channel ID to post notifications to | `string` | n/a | yes |
| <a name="input_slack_webhook_secret_arn"></a> [slack\_webhook\_secret\_arn](#input\_slack\_webhook\_secret\_arn) | ARN of an externally-managed Secrets Manager secret holding WEBHOOK\_URL and optionally SLACK\_BOT\_TOKEN keys | `string` | n/a | yes |
| <a name="input_thresholds_url"></a> [thresholds\_url](#input\_thresholds\_url) | Optional URL shown in budget alerts pointing to where alert thresholds are configured. When empty, the link is omitted. | `string` | `""` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Lambda function timeout in seconds | `number` | `300` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_db_monitoring_sns_topic_arn"></a> [db\_monitoring\_sns\_topic\_arn](#output\_db\_monitoring\_sns\_topic\_arn) | ARN of the RDS monitoring SNS topic |
| <a name="output_lambda_function_arn"></a> [lambda\_function\_arn](#output\_lambda\_function\_arn) | ARN of the Lambda function |
| <a name="output_lambda_function_name"></a> [lambda\_function\_name](#output\_lambda\_function\_name) | Name of the Lambda function |
| <a name="output_sns_topic_arn"></a> [sns\_topic\_arn](#output\_sns\_topic\_arn) | ARN of the SNS topic for budget alerts (null when account-global resources are disabled) |
<!-- END_TF_DOCS -->
