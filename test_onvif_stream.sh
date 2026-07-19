#!/usr/bin/env bash
# Testa o fluxo completo de stream ONVIF: GetProfiles -> GetStreamUri -> ffprobe
# Uso: ./test_onvif_stream.sh <ip:porta> <usuario> <senha>
set -uo pipefail

HOST="${1:?uso: $0 <ip:porta> <usuario> <senha>}"
USER="${2:?informe o usuario}"
PASS="${3:?informe a senha}"
DEV_URL="http://$HOST/onvif/device_service"
MEDIA_URL="http://$HOST/onvif/media_service"

# --- helper: monta header WS-Security UsernameToken e faz o POST ---
soap() {
  local url="$1" body="$2"
  local nonce_raw nonce_b64 created digest
  nonce_raw=$(head -c16 /dev/urandom)
  nonce_b64=$(printf '%s' "$nonce_raw" | base64 | tr -d '\n')
  created=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  digest=$( { printf '%s' "$nonce_raw"; printf '%s%s' "$created" "$PASS"; } \
            | openssl dgst -sha1 -binary | base64 | tr -d '\n' )
  curl -s -m 10 "$url" -H 'Content-Type: application/soap+xml; charset=utf-8' --data \
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<s:Envelope xmlns:s=\"http://www.w3.org/2003/05/soap-envelope\"
 xmlns:trt=\"http://www.onvif.org/ver10/media/wsdl\" xmlns:tt=\"http://www.onvif.org/ver10/schema\">
 <s:Header><Security s:mustUnderstand=\"1\"
   xmlns=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd\">
  <UsernameToken><Username>$USER</Username>
   <Password Type=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest\">$digest</Password>
   <Nonce EncodingType=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary\">$nonce_b64</Nonce>
   <Created xmlns=\"http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd\">$created</Created>
  </UsernameToken></Security></s:Header>
 <s:Body>$body</s:Body></s:Envelope>"
}

echo "### 1) GetProfiles em $MEDIA_URL"
PROFILES=$(soap "$MEDIA_URL" '<trt:GetProfiles/>')
TOKEN=$(printf '%s' "$PROFILES" | grep -oE 'token="[^"]+"' | head -1 | sed 's/token="//;s/"//')
echo "    Profiles encontrados: $(printf '%s' "$PROFILES" | grep -oE 'token="[^"]+"' | wc -l)  | usando token: '${TOKEN:-<nenhum>}'"
if [ -z "$TOKEN" ]; then
  echo "    !! Nao consegui token. Resposta crua:"; printf '%s\n' "$PROFILES" | head -c 800; echo; exit 1
fi

echo "### 2) GetStreamUri (RTP-Unicast/RTSP) para o token '$TOKEN'"
STREAM=$(soap "$MEDIA_URL" \
"<trt:GetStreamUri>
  <trt:StreamSetup><tt:Stream>RTP-Unicast</tt:Stream>
   <tt:Transport><tt:Protocol>RTSP</tt:Protocol></tt:Transport></trt:StreamSetup>
  <trt:ProfileToken>$TOKEN</trt:ProfileToken></trt:GetStreamUri>")
RTSP=$(printf '%s' "$STREAM" | grep -oE 'rtsp://[^< ]+' | head -1)
echo "    RTSP URL: ${RTSP:-<nenhuma>}"
if [ -z "$RTSP" ]; then
  echo "    !! Sem URL. Resposta crua:"; printf '%s\n' "$STREAM" | head -c 800; echo; exit 1
fi

# injeta credenciais na URL rtsp (rtsp://user:pass@host/...)
RTSP_AUTH=$(printf '%s' "$RTSP" | sed -E "s#rtsp://#rtsp://$USER:$PASS@#")

echo "### 3) ffprobe no stream (5s)"
ffprobe -rtsp_transport tcp -v error -timeout 8000000 \
  -show_entries stream=codec_type,codec_name,width,height,avg_frame_rate \
  -of default=noprint_wrappers=1 "$RTSP_AUTH" 2>&1 | head -30
echo "### fim"
