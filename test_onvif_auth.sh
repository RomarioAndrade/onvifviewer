#!/usr/bin/env bash
# Testa autenticacao ONVIF (WS-UsernameToken) contra uma camera.
# Uso: ./test_onvif_auth.sh <ip:porta> <usuario> <senha>
set -euo pipefail

HOST="${1:?uso: $0 <ip:porta> <usuario> <senha>}"
USER="${2:?informe o usuario}"
PASS="${3:?informe a senha}"
URL="http://$HOST/onvif/device_service"

# --- Monta o WS-Security UsernameToken (PasswordDigest) ---
# nonce = 16 bytes aleatorios; Created = timestamp UTC ISO8601
NONCE_RAW=$(head -c16 /dev/urandom)
NONCE_B64=$(printf '%s' "$NONCE_RAW" | base64 | tr -d '\n')
CREATED=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# PasswordDigest = base64( sha1( nonce_raw + created + senha ) )
DIGEST=$( { printf '%s' "$NONCE_RAW"; printf '%s%s' "$CREATED" "$PASS"; } \
          | openssl dgst -sha1 -binary | base64 | tr -d '\n' )

read -r -d '' BODY <<XML || true
<?xml version="1.0" encoding="UTF-8"?>
<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope">
 <s:Header>
  <Security s:mustUnderstand="1"
    xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">
   <UsernameToken>
    <Username>$USER</Username>
    <Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">$DIGEST</Password>
    <Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">$NONCE_B64</Nonce>
    <Created xmlns="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">$CREATED</Created>
   </UsernameToken>
  </Security>
 </s:Header>
 <s:Body>
  <GetDeviceInformation xmlns="http://www.onvif.org/ver10/device/wsdl"/>
 </s:Body>
</s:Envelope>
XML

echo "=== POST $URL  (Created=$CREATED) ==="
curl -s -m 8 "$URL" \
  -H 'Content-Type: application/soap+xml; charset=utf-8' \
  --data "$BODY" -w "\n--- HTTP %{http_code} ---\n"
