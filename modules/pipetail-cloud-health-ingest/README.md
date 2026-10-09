# pipetail-cloud-health-ingest

Forwards the AWS Health events of one Region to pipetail.cloud through an EventBridge rule, API
destination and connection, with an SQS dead-letter queue for events that could not be
delivered. The ingest key is not a Terraform input, so it never enters state: the connection is
created with a placeholder, and after apply you set the real key once with the snippet under
"Set the ingest key". Create one instance for each Region that holds resources, plus one in
us-east-1, where AWS delivers the Health events that are not tied to a Region.

## Usage

```hcl
module "pipetail_cloud_health_ingest" {
  source = "github.com/pipetail/terraform//modules/pipetail-cloud-health-ingest?ref=pipetail-cloud-health-ingest-v2.0.0"
}
```

## Set the ingest key

Generate the key in pipetail.cloud under Settings. Then run this snippet once for each instance of
the module, with `region` set to that instance's Region and `name` set to its `name` input. It
needs bash or zsh.

```bash
(
  set -e
  region="eu-central-1"
  name="pipetail-cloud-health-ingest"
  d="$(mktemp -d)"; trap 'rm -rf "$d"' EXIT
  printf 'Paste the AWS Health ingest key (input hidden): ' >&2
  IFS= read -rs key; printf '\n' >&2
  printf '{"Name":"%s","AuthParameters":{"ApiKeyAuthParameters":{"ApiKeyName":"X-Pipetail-Ingest-Key","ApiKeyValue":"%s"}}}' "$name" "$key" > "$d/connection.json"
  aws events update-connection --region "$region" --cli-input-json "file://$d/connection.json"
)
```

The snippet writes the key straight to EventBridge, so the key never enters Terraform state. It
also keeps the key out of the process arguments and the shell history. `printf` is a shell builtin
that writes the key into a temporary file, and the `trap` removes that file even if you interrupt
the snippet. To rotate the key, run the snippet again with the new value. No apply is needed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.24.0, < 7.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.24.0, < 7.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_event_api_destination.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_api_destination) | resource |
| [aws_cloudwatch_event_connection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_connection) | resource |
| [aws_cloudwatch_event_rule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_iam_role.invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.invoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_sqs_queue.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.dlq](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_api_endpoint"></a> [api\_endpoint](#input\_api\_endpoint) | pipetail.cloud endpoint the events are posted to. The default is the portal's ingest URL; override it only if pipetail.cloud gives you a different one. | `string` | `"https://api.pipetail.cloud/ingest/aws-health"` | no |
| <a name="input_create_dlq"></a> [create\_dlq](#input\_create\_dlq) | Create an SQS dead-letter queue holding events EventBridge could not deliver. With this off, an event EventBridge gives up on is dropped and no copy of it exists anywhere. | `bool` | `true` | no |
| <a name="input_invocation_rate_limit_per_second"></a> [invocation\_rate\_limit\_per\_second](#input\_invocation\_rate\_limit\_per\_second) | Ceiling on how many events per second EventBridge sends to the endpoint. AWS Health is low-volume, so the default leaves ample headroom. Events above the ceiling back up behind it and expire once they pass the target's maximum event age. | `number` | `10` | no |
| <a name="input_name"></a> [name](#input\_name) | Base name for the EventBridge connection, API destination, rule and dead-letter queue (suffixed -dlq). All four are Regional, so the same name is safe in every Region; the IAM role is global and is created from this as a prefix with a unique suffix appended by AWS, so instantiating the module in several Regions never collides on it. | `string` | `"pipetail-cloud-health-ingest"` | no |
| <a name="input_target_id"></a> [target\_id](#input\_target\_id) | Target id on the EventBridge rule. Changing a target's id forces EventBridge to replace it, so set this to the existing id when adopting a target that was created outside the module; leave the default everywhere else. | `string` | `"pipetail-cloud-ingest"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_destination_arn"></a> [api\_destination\_arn](#output\_api\_destination\_arn) | ARN of the API destination the rule delivers to |
| <a name="output_dlq_arn"></a> [dlq\_arn](#output\_dlq\_arn) | ARN of the dead-letter queue, or null when create\_dlq is false |
| <a name="output_dlq_queue_url"></a> [dlq\_queue\_url](#output\_dlq\_queue\_url) | URL of the dead-letter queue to read undelivered events from, or null when create\_dlq is false |
| <a name="output_rule_arn"></a> [rule\_arn](#output\_rule\_arn) | ARN of the EventBridge rule matching AWS Health events in this Region |
<!-- END_TF_DOCS -->
