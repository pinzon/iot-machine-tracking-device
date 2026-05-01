#!/usr/bin/env bash
set -euo pipefail

export AWS_PROFILE=personal

THING_NAME="water-pump-01"
POLICY_NAME="water-pump-policy"
MQTT_TOPIC="iot/machine/status"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
WIFI_CONF="${DATA_DIR}/wifi.conf"

mkdir -p "$DATA_DIR"

# Create a sample wifi.conf if missing (line 1: SSID, line 2: password)
if [[ ! -f "$WIFI_CONF" ]]; then
  cat > "$WIFI_CONF" <<EOF
YOUR_SSID
YOUR_PASSWORD
EOF
  echo "Created sample ${WIFI_CONF} — edit it before uploadfs."
fi

# Get account ID and region for policy ARN
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

echo "Provisioning IoT Thing: ${THING_NAME}"
echo "Account: ${ACCOUNT_ID}, Region: ${REGION}"

# Create Thing
if aws iot describe-thing --thing-name "$THING_NAME" &>/dev/null; then
  echo "Thing '${THING_NAME}' already exists, skipping creation."
else
  aws iot create-thing --thing-name "$THING_NAME"
  echo "Created Thing: ${THING_NAME}"
fi

# Create certificate (written directly to data/ for LittleFS upload)
echo "Creating certificate..."
CERT_OUTPUT=$(aws iot create-keys-and-certificate \
  --set-as-active \
  --certificate-pem-outfile "${DATA_DIR}/device.pem.crt" \
  --private-key-outfile "${DATA_DIR}/private.pem.key" \
  --public-key-outfile "${DATA_DIR}/public.pem.key" \
  --output json)

CERT_ARN=$(echo "$CERT_OUTPUT" | python3 -c "import sys,json; print(json.load(sys.stdin)['certificateArn'])")
echo "Certificate ARN: ${CERT_ARN}"

# public key isn't used by firmware
rm -f "${DATA_DIR}/public.pem.key"

# Download Amazon Root CA 1
echo "Downloading Amazon Root CA 1..."
curl -sS -o "${DATA_DIR}/root-ca.pem" \
  "https://www.amazontrust.com/repository/AmazonRootCA1.pem"

# Create IoT policy
POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:Connect",
      "Resource": "arn:aws:iot:${REGION}:${ACCOUNT_ID}:client/${THING_NAME}"
    },
    {
      "Effect": "Allow",
      "Action": "iot:Publish",
      "Resource": "arn:aws:iot:${REGION}:${ACCOUNT_ID}:topic/${MQTT_TOPIC}"
    }
  ]
}
EOF
)

if aws iot get-policy --policy-name "$POLICY_NAME" &>/dev/null; then
  echo "Policy '${POLICY_NAME}' already exists, skipping creation."
else
  aws iot create-policy \
    --policy-name "$POLICY_NAME" \
    --policy-document "$POLICY_DOC"
  echo "Created policy: ${POLICY_NAME}"
fi

# Attach policy to certificate
aws iot attach-policy \
  --policy-name "$POLICY_NAME" \
  --target "$CERT_ARN"
echo "Attached policy to certificate."

# Attach Thing to certificate
aws iot attach-thing-principal \
  --thing-name "$THING_NAME" \
  --principal "$CERT_ARN"
echo "Attached Thing to certificate."

# Get endpoint
ENDPOINT=$(aws iot describe-endpoint --endpoint-type iot:Data-ATS --query endpointAddress --output text)

echo ""
echo "===== Provisioning complete ====="
echo ""
echo "Endpoint: ${ENDPOINT}"
echo ""
echo "Certs written to: ${DATA_DIR}/ (ready for LittleFS upload)"
echo ""
echo "Update MQTT_HOST in firmware/src/config.h:"
echo "  MQTT_HOST = ${ENDPOINT}"
echo ""
echo "Then flash with:"
echo "  pio run -t uploadfs   # upload certs + wifi.conf"
echo "  pio run -t upload     # upload firmware"
