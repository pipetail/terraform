# WireGuard VPN server on EC2
This is a simple WireGuard server setup on AWS EC2. A very small EC2 instance running a VPN server.

The key is simplicity. Terraform provisions all necessary infrastructure, Packer builds ubuntu-based AMI.

WireGuard peer configuration is not hot-reloaded. Every peer change requires a new AMI, but the server private key is fetched from Secrets Manager when the instance boots.

## generate keys
first generate WireGuard key-pair (for a better guide refer to the [official docs](https://www.wireguard.com/quickstart/))
```
umask 077
wg genkey > privatekey
wg pubkey < privatekey > publickey
```

Save the keys to Secrets Manager:
```
aws secretsmanager create-secret --name wireguard --description "WireGuard keys" --secret-string '{"public_key":"'"$(<publickey)"'","private_key":"'"$(<privatekey)"'"}' --region eu-west-1
```

Copy the public key into `terraform.tfvars` as `wireguard_public_key`. Terraform uses this nonsensitive value for the client configuration and to verify the private key fetched at boot. Terraform never reads the secret value.

## terraform apply - first part
run terraform apply to create VPC resources

the following will FAIL with an error, something like: `Error: creating EC2 Instance: AuthFailure: Not authorized for images: [ami-01234xxxxxxx]`
```
terraform apply
```

The error doesn't matter now, the ami is not built yet, we just need the VPC resources (public subnet id mainly)

Disclaimer: The reason we need a public subnet is for packer to be able to spin up an EC2 instance that can be reached over ssh from internet, public subnet is the easiest solution in our networking setup here, you may not be able to such a thing if your AWS account's networking is different or limited by centralized team / org.

Next check the terraform outputs:

```
Changes to Outputs:
  + packer_inputs = {
      + aws_region = "eu-west-1"
      + subnet_id  = "subnet-abcdefsffdfxxxxx"
    }

```

grab the `subnet_id` value and paste it into `./packer/wireguard-prod.pkvars.hcl`

same goes for the `aws_region` in case you changed it

## wireguard client config
Open your WireGuard client, create a new empty tunnel config

Enter `Name`

Copy the client tunnel's `Public key` into `./packer/wg0-prod.conf.tftpl` and save the file.

Keep the WireGuard window open, on the side in the terminal run:

```
terraform output -raw vpn_config
```

this will give your something like the following:

```
// this should come right under your PrivateKey in [Interface] block
// .2 is the first available address as of now, don't forget to bump this up
Address = 10.1.0.2/32

[Peer]
PublicKey = 3I1I4p+FGkOoCjNHSmmyNDkGY8vmkSRSkg7q6DiS4go=
AllowedIPs = 10.0.0.0/16
Endpoint = wg.example.org:41194
```

copy the important part (throw away the comments) and APPEND it into the WireGuard config

(also, you might want to bump up the `.2` -> `.3` above to show you used this IP for yourself)

your config should look something like this:

```
[Interface]
PrivateKey = YourPrivateKeyInBase64=
Address = 10.1.0.2/32

[Peer]
PublicKey = 3I1I4p+FGkOoCjNHSmmyNDkGY8vmkSRSkg7q6DiS4go=
AllowedIPs = 10.0.0.0/16
Endpoint = wg.example.org:41194
```

`Save` the config.

## packer build
run packer build to create our ami

```
cd packer
packer build --var-file wireguard-prod.pkvars.hcl wireguard.pkr.hcl
```

if everything goes well, at the end of the output you should see something like this:

```
==> amazon-ebs.wireguard: Stopping the source instance...
    amazon-ebs.wireguard: Stopping instance
==> amazon-ebs.wireguard: Waiting for the instance to stop...
==> amazon-ebs.wireguard: Creating AMI wireguard-1 from instance i-0a044bbd795fb364b
    amazon-ebs.wireguard: AMI: ami-05dff77713a4fa273
==> amazon-ebs.wireguard: Waiting for AMI to become ready...
==> amazon-ebs.wireguard: Skipping Enable AMI deprecation...
==> amazon-ebs.wireguard: Adding tags to AMI (ami-05dff77713a4fa273)...
==> amazon-ebs.wireguard: Tagging snapshot: snap-01751236bce1c8530
==> amazon-ebs.wireguard: Creating AMI tags
    amazon-ebs.wireguard: Adding tag: "Name": "wireguard"
==> amazon-ebs.wireguard: Creating snapshot tags
==> amazon-ebs.wireguard: Terminating the source AWS instance...
==> amazon-ebs.wireguard: Cleaning up any extra volumes...
==> amazon-ebs.wireguard: No volumes to clean up, skipping
==> amazon-ebs.wireguard: Deleting temporary security group...
==> amazon-ebs.wireguard: Deleting temporary keypair...
Build 'amazon-ebs.wireguard' finished after 5 minutes 53 seconds.

==> Wait completed after 5 minutes 53 seconds

==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs.wireguard: AMIs were created:
eu-west-1: ami-05dff77713a4fa273
```

pick the outputted ami `ami-YOUR_OWN_VALUE` and paste it into `./terraform.tfvars` as a value of `wireguard_ami`

## terraform apply - second part

now return to the folder with terraform resources and run `terraform apply` again

```
cd ..
terraform apply
```

everything should finish without any errors now

## WireGuard connect

Open up WireGuard client, choose your config and click `Activate`.

The status should turn green and everything should work as expected now.

## Server private key

The AMI contains WireGuard, AWS CLI, the non-secret peer configuration template, and a boot service. It contains no server private key or rendered `wg0.conf`.

At boot, the service waits for networking and cloud-init, then retrieves the `wireguard` secret using the EC2 instance role. The role can read only that secret. The service validates the key, derives its public key, compares it with `wireguard_public_key`, writes the key and `wg0.conf` with mode `0600`, and starts WireGuard. If retrieval or validation fails, WireGuard remains stopped and systemd retries the service.

The existing key still needs a separate rotation procedure. Retire older secret-bearing AMIs and historical state snapshots after deploying and testing the runtime-fetch image.

## Adding up your teammates
If you want to add more users to use your VPN, you'll need to create a new AMI (and there's going to be a short downtime).

On the target machine, open up WireGuard client and follow the steps just like in [wireguard client config](#wireguard-client-config) but instead of editing the existing `[Peer]` block, append a new one:

```
[Peer]
PublicKey = insertanotherpublickeyhere=
AllowedIPs = 10.1.0.3/32
PersistentKeepalive = 25
```

the `AllowedIPs` has to be unique for every VPN user, here we simply use the next available IP address in our VPN subnet `10.1.0.3/32` for this peer.

Run the Packer build again after editing the template. The CI workflow owns `ami_version`; do not edit it by hand.

take the new AMI, paste it in terraform and run apply

that's it, the old EC2 instance with be destroyed and new one spins up

if something goes wrong, you can always use the previous AMI id to "rollback".

## TODO
Terraform and Packer are not connected here. We are just taking outputs of one and feeding it to the other and then again the other way around.
That is annoying. That could definitely be improved.

Hotreloading the config (from S3 perhaps) instead of creating new AMIs could be nice, but optional (I prefer the simple approach here, baked in configs in build artefacts, no dependencies on config servers and possibility of rollbacks, i.e. hotreloading sounds great until somebody messes up the config on s3 and VPN stops working for everybody or when S3 / networking has outtage).

Terraform and Packer both run in automation.
