#!/bin/bash
if [ ! -z "$DEBUG" ]; then set -x; fi
mkdir /data 2>/dev/null >/dev/null
RANDOM=$(printf "%d" "0x$(head -c4 /dev/urandom | od -t x1 -An | tr -d ' ')")

if [ -z "$WORKERS" ]; then
  WORKERS=2
fi

echo "####"
echo "#### Telegram Proxy"
echo "####"
echo
SECRET_CMD=""
if [ ! -z "$SECRET" ]; then
  echo "[+] Using the explicitly passed secret: '$SECRET'."
elif [ -f /data/secret ]; then
  SECRET="$(cat /data/secret)"
  echo "[+] Using the secret in /data/secret: '$SECRET'."
else
  if [[ ! -z "$SECRET_COUNT" ]]; then
    if [[ ! ( "$SECRET_COUNT" -ge 1 &&  "$SECRET_COUNT" -le 16 ) ]]; then
      echo "[F] Can generate between 1 and 16 secrets."
      exit 5
    fi
  else
    SECRET_COUNT="1"
  fi

  echo "[+] No secret passed. Will generate $SECRET_COUNT random ones."
  SECRET="$(dd if=/dev/urandom bs=16 count=1 2>&1 | od -tx1  | head -n1 | tail -c +9 | tr -d ' ')"
  for pass in $(seq 2 $SECRET_COUNT); do
    SECRET="$SECRET,$(dd if=/dev/urandom bs=16 count=1 2>&1 | od -tx1  | head -n1 | tail -c +9 | tr -d ' ')"
  done
fi

if echo "$SECRET" | grep -qE '^[0-9a-fA-F]{32}(,[0-9a-fA-F]{32}){,15}$'; then
  SECRET="$(echo "$SECRET" | tr '[:upper:]' '[:lower:]')"
  SECRET_CMD="-S $(echo "$SECRET" | sed 's/,/ -S /g')"
  echo -- "$SECRET_CMD" > /data/secret_cmd
  echo "$SECRET" > /data/secret
else
  echo '[F] Bad secret format: should be 32 hex chars (for 16 bytes) for every secret; secrets should be comma-separated.'
  exit 1
fi

if [ ! -z "$TAG" ]; then
  echo "[+] Using the explicitly passed tag: '$TAG'."
fi

TAG_CMD=""
if [[ ! -z "$TAG" ]]; then
  if echo "$TAG" | grep -qE '^[0-9a-fA-F]{32}$'; then
    TAG="$(echo "$TAG" | tr '[:upper:]' '[:lower:]')"
    TAG_CMD="-P $TAG"
  else
    echo '[!] Bad tag format: should be 32 hex chars (for 16 bytes).'
    echo '[!] Continuing.'
  fi
fi

curl -s https://core.telegram.org/getProxyConfig -o /etc/telegram/backend.conf || {
  echo '[F] Cannot download proxy configuration from Telegram servers.'
  exit 2
}
CONFIG=/etc/telegram/backend.conf

IP="$(curl -s -4 "https://digitalresistance.dog/myIp")"
INTERNAL_IP="$(ip -4 route get 8.8.8.8 | grep '^8\.8\.8\.8\s' | grep -Po 'src\s+\d+\.\d+\.\d+\.\d+' | awk '{print $2}')"

if [[ -z "$IP" ]]; then
  echo "[F] Cannot determine external IP address."
  exit 3
fi

if [[ -z "$INTERNAL_IP" ]]; then
  echo "[F] Cannot determine internal IP address."
  exit 4
fi

echo "[*] Final configuration:"
I=1
echo "$SECRET" | tr ',' '\n' | while read S; do
  echo "[*]   Secret $I: $S"
  echo "[*]   tg:// link for secret $I auto configuration: tg://proxy?server=${IP}&port=${PORT}&secret=${S}"
  echo "[*]   t.me link for secret $I: https://t.me/proxy?server=${IP}&port=${PORT}&secret=${S}"
  I=$(($I+1))
done

[ ! -z "$TAG" ] && echo "[*]   Tag: $TAG" || echo "[*]   Tag: no tag"
echo "[*]   External IP: $IP"
echo "[*]   Make sure to fix the links in case you run the proxy on a different port."
echo
echo '[+] Starting proxy...'
sleep 1
exec /usr/local/bin/mtproto-proxy -p $HTTP_PORT -H $PORT --http-stats -M "$WORKERS" -C 60000 --aes-pwd /etc/telegram/hello-explorers-how-are-you-doing -u root $CONFIG --allow-skip-dh --nat-info "$INTERNAL_IP:$IP" $SECRET_CMD $TAG_CMD
