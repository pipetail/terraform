# terraform

Terraform modules that [pipetail](https://pipetail.io) runs in production, each released and versioned on its own, plus the examples and CI that prove them.

Pin a module by its release tag. Modules carry `terraform test` suites under `tests/`, and most examples are applied to a real account every week.

## Modules

| Module | What it creates | Latest | Example |
|---|---|---|---|
| [`aws-bootstrap`](modules/aws-bootstrap) | S3 state bucket with access logging, optional DynamoDB lock table | `aws-bootstrap-v1.0.0` | [06](examples/06-minimal-aws-terraform-bootstrap) |
| [`aws-events-to-slack`](modules/aws-events-to-slack) | Lambda that forwards AWS Health, maintenance, budget and security events to Slack | `aws-events-to-slack-v1.8.2` | [05](examples/05-aws-complete) |
| [`certificate`](modules/certificate) | ACM certificate with DNS validation, plus a us-east-1 copy for CloudFront | `certificate-v1.0.0` | [05](examples/05-aws-complete) |
| [`cloudtrail`](modules/cloudtrail) | Multi-region CloudTrail to an encrypted S3 bucket and CloudWatch Logs | `cloudtrail-v1.0.0` | none yet |
| [`cluster-autoscaler`](modules/cluster-autoscaler) | Cluster Autoscaler Helm release with an IRSA role | `cluster-autoscaler-v1.0.0` | none yet |
| [`eks`](modules/eks) | EKS cluster with Bottlerocket node groups, access entries and KMS secrets encryption | `eks-v1.0.0` | [05](examples/05-aws-complete) |
| [`github-oidc`](modules/github-oidc) | GitHub Actions OIDC provider and a role trusted only by named subjects | `github-oidc-v1.0.0` | [03](examples/03-aws-github-actions-oidc) |
| [`kms`](modules/kms) | Shared KMS key with rotation and scoped grants for CloudWatch Logs and CloudTrail | `kms-v1.0.0` | none yet |
| [`pipetail-cloud-health-ingest`](modules/pipetail-cloud-health-ingest) | EventBridge rule that sends AWS Health events to pipetail.cloud | `pipetail-cloud-health-ingest-v1.0.2` | none |
| [`pipetail-cloud-role`](modules/pipetail-cloud-role) | Read-only cross-account role for pipetail.cloud, trusted with an external id | `pipetail-cloud-role-v2.2.0` | none |
| [`wireguard-ec2`](modules/wireguard-ec2) | WireGuard VPN host on EC2 from a Packer-built AMI | `wireguard-ec2-v1.0.1` | [04](examples/04-aws-wireguard-vpn) |

The "Latest" column is a snapshot. The [releases page](https://github.com/pipetail/terraform/releases) is always current.

## Using a module

Pin the module's own release tag:

```hcl
module "github_oidc" {
  source = "github.com/pipetail/terraform//modules/github-oidc?ref=github-oidc-v1.0.0"

  repository_name = "example-org/example-repo"
}
```

Each module is released as `<module>-vX.Y.Z` when a change to it lands on `master`. The version bump comes from the squash-merged PR title: `fix(<module>):` is a patch, `feat(<module>):` a minor, and `!` or a `BREAKING CHANGE:` footer a major. A PR whose title scope does not match the one module it changes fails CI. Changes to a module's `.md` files or `tests/` directory are not released.

`aws-events-to-slack`, `pipetail-cloud-role` and `pipetail-cloud-health-ingest` keep their own release workflows. The repo-wide `v0.0.x` tags are no longer cut.

## Examples

Each example is its own Terraform root with its own state. PRs get a `terraform plan` for every example they affect. A merge applies it, except for example 05, which is plan-only.

| Example | What it shows | Proven by |
|---|---|---|
| [01-minimal-aws-cloudformation-bootstrap](examples/01-minimal-aws-cloudformation-bootstrap) | State backend created with CloudFormation. Legacy: prefer 06. | weekly apply |
| [02-minimal-gcp-tf-bootstrap](examples/02-minimal-gcp-tf-bootstrap) | GCP state bucket and the project services it needs | weekly apply |
| [03-aws-github-actions-oidc](examples/03-aws-github-actions-oidc) | CI role for GitHub Actions without static keys | weekly apply |
| [04-aws-wireguard-vpn](examples/04-aws-wireguard-vpn) | VPN host from a Packer AMI built in CI | weekly apply |
| [05-aws-complete](examples/05-aws-complete) | A full account: EKS, Aurora, ElastiCache, ALB, CloudTrail, flow logs, budgets | plan on every PR |
| [06-minimal-aws-terraform-bootstrap](examples/06-minimal-aws-terraform-bootstrap) | State backend created with Terraform and the `aws-bootstrap` module | weekly apply |

## How changes are checked

- [docs/ci.md](docs/ci.md): the workflows, pre-commit hooks, lock files and Renovate.
- [docs/policies.md](docs/policies.md): the custom conftest policies, tflint and checkov.
- [docs/conventions.md](docs/conventions.md): repository layout, state locking, state migrations and naming.

## Contributing

Install the hooks once with `pre-commit install`. They run on the files each commit changes. CI runs the same hooks on every PR, plus the policy checks on the whole tree and every module's `terraform test` suite.

PR titles follow [Conventional Commits](https://www.conventionalcommits.org) and name the module they change as the scope.

Thanks to [@vranystepan](https://github.com/vranystepan) and [@vdovhanych](https://github.com/vdovhanych).
