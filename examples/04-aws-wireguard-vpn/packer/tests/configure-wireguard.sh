#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_under_test="${script_dir}/../configure-wireguard.sh"
config_template="${script_dir}/../wg0-prod.conf.tftpl"
scratch_dir="$(mktemp -d)"
trap 'rm -rf "${scratch_dir}"' EXIT

fake_bin="${scratch_dir}/bin"
mkdir -p "${fake_bin}"

cat > "${fake_bin}/aws" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${AWS_STUB_LOG}"
if [[ "${AWS_STUB_MODE}" == "failure" ]]; then
  printf '%s\n' "${AWS_STUB_SECRET_JSON}"
  printf '%s\n' "${AWS_STUB_SECRET_JSON}" >&2
  exit 1
fi
printf '%s\n' "${AWS_STUB_SECRET_JSON}"
EOF

cat > "${fake_bin}/systemctl" << 'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${SYSTEMCTL_STUB_LOG}"
EOF

chmod +x "${fake_bin}/aws" "${fake_bin}/systemctl"

private_key="$(wg genkey)"
public_key="$(printf '%s\n' "${private_key}" | wg pubkey)"
other_private_key="$(wg genkey)"
other_public_key="$(printf '%s\n' "${other_private_key}" | wg pubkey)"
secret_arn="arn:aws:secretsmanager:eu-west-1:123456789012:secret:wireguard-test"
aws_region="eu-west-1"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

file_mode() {
  if stat -c '%a' "$1" > /dev/null 2>&1; then
    stat -c '%a' "$1"
  else
    stat -f '%Lp' "$1"
  fi
}

setup_case() {
  local case_name="$1"
  local expected_public_key="$2"
  local case_dir="${scratch_dir}/${case_name}"
  local root_dir="${case_dir}/root"

  mkdir -p "${root_dir}/etc/wireguard" "${root_dir}/usr/local/share/wireguard"
  cp "${config_template}" "${root_dir}/usr/local/share/wireguard/wg0.conf.tftpl"
  jq -n \
    --arg secret_arn "${secret_arn}" \
    --arg region "${aws_region}" \
    --arg public_key "${expected_public_key}" \
    '{secret_arn: $secret_arn, region: $region, public_key: $public_key}' \
    > "${root_dir}/etc/wireguard/runtime.json"
  chmod 600 "${root_dir}/etc/wireguard/runtime.json"
  : > "${case_dir}/aws.log"
  : > "${case_dir}/systemctl.log"
}

invoke() {
  local case_name="$1"
  local secret_json="$2"
  local aws_mode="$3"
  local expected_status="$4"
  local case_dir="${scratch_dir}/${case_name}"
  local output_file="${case_dir}/output.log"
  local status

  set +e
  PATH="${fake_bin}:${PATH}" \
    WIREGUARD_ROOT="${case_dir}/root" \
    AWS_STUB_LOG="${case_dir}/aws.log" \
    AWS_STUB_MODE="${aws_mode}" \
    AWS_STUB_SECRET_JSON="${secret_json}" \
    SYSTEMCTL_STUB_LOG="${case_dir}/systemctl.log" \
    "${script_under_test}" > "${output_file}" 2>&1
  status=$?
  set -e

  [[ "${status}" -eq "${expected_status}" ]] || fail "${case_name} exited ${status}, expected ${expected_status}"
  ! grep -Fq "${private_key}" "${output_file}" || fail "${case_name} printed a private key"
  ! grep -Fq "${other_private_key}" "${output_file}" || fail "${case_name} printed a private key"
}

assert_never_started() {
  local case_name="$1"
  ! grep -Fxq 'start wg-quick@wg0.service' "${scratch_dir}/${case_name}/systemctl.log" || fail "${case_name} started WireGuard"
}

valid_secret="$(jq -cn --arg private_key "${private_key}" --arg public_key "${public_key}" '{private_key: $private_key, public_key: $public_key}')"
other_secret="$(jq -cn --arg private_key "${other_private_key}" --arg public_key "${other_public_key}" '{private_key: $private_key, public_key: $public_key}')"

setup_case success "${public_key}"
invoke success "${valid_secret}" success 0
grep -Fxq "secretsmanager get-secret-value --secret-id ${secret_arn} --region ${aws_region} --query SecretString --output text" "${scratch_dir}/success/aws.log" || fail "AWS request was not scoped to the configured secret and region"
grep -Fxq 'stop wg-quick@wg0.service' "${scratch_dir}/success/systemctl.log" || fail "WireGuard was not stopped before configuration"
grep -Fxq 'start wg-quick@wg0.service' "${scratch_dir}/success/systemctl.log" || fail "WireGuard was not started after configuration"
grep -Fxq "PrivateKey = ${private_key}" "${scratch_dir}/success/root/etc/wireguard/wg0.conf" || fail "rendered config does not contain the fetched key"
grep -Fxq 'ListenPort = 41194' "${scratch_dir}/success/root/etc/wireguard/wg0.conf" || fail "rendered config lost non-secret settings"
[[ "$(file_mode "${scratch_dir}/success/root/etc/wireguard/wg0.conf")" == "600" ]] || fail "wg0.conf mode is not 0600"
[[ "$(file_mode "${scratch_dir}/success/root/etc/wireguard/keys/privatekey")" == "600" ]] || fail "private key mode is not 0600"

config_digest="$(shasum -a 256 "${scratch_dir}/success/root/etc/wireguard/wg0.conf")"
key_digest="$(shasum -a 256 "${scratch_dir}/success/root/etc/wireguard/keys/privatekey")"
invoke success "${valid_secret}" success 0
[[ "$(shasum -a 256 "${scratch_dir}/success/root/etc/wireguard/wg0.conf")" == "${config_digest}" ]] || fail "idempotent rerun changed wg0.conf"
[[ "$(shasum -a 256 "${scratch_dir}/success/root/etc/wireguard/keys/privatekey")" == "${key_digest}" ]] || fail "idempotent rerun changed the key file"

setup_case invalid_json "${public_key}"
invoke invalid_json 'not-json' success 1
grep -Fq 'WireGuard secret is not valid JSON.' "${scratch_dir}/invalid_json/output.log" || fail "invalid JSON error is unclear"
assert_never_started invalid_json

setup_case invalid_key "${public_key}"
invalid_key_secret="$(jq -cn --arg private_key 'not-a-wireguard-key' '{private_key: $private_key}')"
invoke invalid_key "${invalid_key_secret}" success 1
grep -Fq 'WireGuard secret contains an invalid private key.' "${scratch_dir}/invalid_key/output.log" || fail "invalid key error is unclear"
assert_never_started invalid_key

setup_case mismatch "${public_key}"
invoke mismatch "${other_secret}" success 1
grep -Fq 'WireGuard private key does not match the configured public key.' "${scratch_dir}/mismatch/output.log" || fail "public-key mismatch error is unclear"
assert_never_started mismatch

setup_case aws_failure "${public_key}"
invoke aws_failure "${valid_secret}" failure 1
grep -Fq 'Unable to retrieve the WireGuard private key.' "${scratch_dir}/aws_failure/output.log" || fail "AWS failure error is unclear"
assert_never_started aws_failure

printf 'configure-wireguard tests passed\n'
