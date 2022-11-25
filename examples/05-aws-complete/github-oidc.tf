// we maintain this via a different example, here we need this for k8s API access
// normally you wouldn't need this
data "aws_iam_role" "github_actions" {
  name = "github_actions_terraform"
}
