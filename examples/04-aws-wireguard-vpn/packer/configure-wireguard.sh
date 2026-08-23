#!/usr/bin/env bash
set -euo pipefail

root_dir="${WIREGUARD_ROOT:-}"
wireguard_dir="${root_dir}/etc/wireguard"
keys_dir="${wireguard_dir}/keys"
runtime_dir="${root_dir}/run/wireguard"
runtime_config="${wireguard_dir}/runtime.json"
config_template="${root_dir}/usr/local/share/wireguard/wg0.conf.tftpl"
wireguard_service="wg-quick@wg0.service"

secret_json=""
private_key_tmp=""
public_key_tmp=""
config_tmp=""

cleanup() {
  local path
  for path in "${secret_json}" "${private_key_tmp}" "${public_key_tmp}" "${config_tmp}"; do
    if [[ -n "${path}" ]]; then
      rm -f "${path}"
    fi
  done
}

stop_wireguard() {
  systemctl stop "${wireguard_service}" > /dev/null 2>&1 || true
}

fail() {
  stop_wireguard
  printf '%s\n' "$1" >&2
  exit 1
}

trap cleanup EXIT
umask 077
stop_wireguard

[[ -f "${runtime_config}" ]] || fail "WireGuard runtime configuration is missing."
[[ -f "${config_template}" ]] || fail "WireGuard configuration template is missing."

secret_arn="$(jq -er '.secret_arn | select(type == "string" and length > 0)' "${runtime_config}" 2> /dev/null)" || fail "WireGuard runtime configuration has an invalid secret ARN."
aws_region="$(jq -er '.region | select(type == "string" and length > 0)' "${runtime_config}" 2> /dev/null)" || fail "WireGuard runtime configuration has an invalid AWS region."
expected_public_key="$(jq -er '.public_key | select(type == "string" and test("^[A-Za-z0-9+/]{43}=$"))' "${runtime_config}" 2> /dev/null)" || fail "WireGuard runtime configuration has an invalid public key."

install -d -m 0700 "${keys_dir}" "${runtime_dir}"
secret_json="$(mktemp "${runtime_dir}/secret.XXXXXX")"

if ! aws secretsmanager get-secret-value \
  --secret-id "${secret_arn}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text > "${secret_json}" 2> /dev/null; then
  fail "Unable to retrieve the WireGuard private key."
fi

if ! jq -e 'type == "object" and (.private_key | type == "string")' "${secret_json}" > /dev/null 2>&1; then
  fail "WireGuard secret is not valid JSON."
fi

private_key_tmp="$(mktemp "${keys_dir}/.privatekey.XXXXXX")"
if ! jq -r '.private_key' "${secret_json}" > "${private_key_tmp}" 2> /dev/null; then
  fail "WireGuard secret is not valid JSON."
fi

if ! grep -Eq '^[A-Za-z0-9+/]{43}=$' "${private_key_tmp}"; then
  fail "WireGuard secret contains an invalid private key."
fi

public_key_tmp="$(mktemp "${keys_dir}/.publickey.XXXXXX")"
if ! wg pubkey < "${private_key_tmp}" > "${public_key_tmp}" 2> /dev/null; then
  fail "WireGuard secret contains an invalid private key."
fi

derived_public_key="$(< "${public_key_tmp}")"
if [[ "${derived_public_key}" != "${expected_public_key}" ]]; then
  fail "WireGuard private key does not match the configured public key."
fi

if [[ "$(grep -Fxc 'PrivateKey = __WIREGUARD_PRIVATE_KEY__' "${config_template}")" -ne 1 ]]; then
  fail "WireGuard configuration template has an invalid private-key placeholder."
fi

config_tmp="$(mktemp "${wireguard_dir}/.wg0.conf.XXXXXX")"
while IFS= read -r line || [[ -n "${line}" ]]; do
  if [[ "${line}" == "PrivateKey = __WIREGUARD_PRIVATE_KEY__" ]]; then
    printf 'PrivateKey = ' >> "${config_tmp}"
    cat "${private_key_tmp}" >> "${config_tmp}"
  else
    printf '%s\n' "${line}" >> "${config_tmp}"
  fi
done < "${config_template}"

chmod 0600 "${private_key_tmp}" "${public_key_tmp}" "${config_tmp}"
mv -f "${private_key_tmp}" "${keys_dir}/privatekey"
private_key_tmp=""
mv -f "${public_key_tmp}" "${keys_dir}/publickey"
public_key_tmp=""
mv -f "${config_tmp}" "${wireguard_dir}/wg0.conf"
config_tmp=""

if ! systemctl start "${wireguard_service}" > /dev/null 2>&1; then
  fail "WireGuard failed to start with the validated configuration."
fi

printf 'WireGuard configuration loaded.\n'
