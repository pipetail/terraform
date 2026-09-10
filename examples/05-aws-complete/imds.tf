# Account-level metadata defaults per Region: an instance launched without its own
# metadata_options still requires IMDSv2. Running instances are not changed, and anything
# that sets its own options keeps overriding this.
#
# No hop limit is set here. Each metadata option is resolved separately, so an account-level
# hop limit would reach launch templates that set only http_tokens, and raising them to 2
# would let a container reach the metadata service and read the instance role.
#
# The setting is one per account per Region. The other examples in this repo apply to the
# same account and deliberately declare none.
resource "aws_ec2_instance_metadata_defaults" "main" {
  http_tokens = "required"
}

resource "aws_ec2_instance_metadata_defaults" "virginia" {
  provider = aws.virginia

  http_tokens = "required"
}
