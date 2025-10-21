# Compare downloaded Docker image digest against the digest listed on DockerHub
# to determine the exact version number (when the image was pulled using tag 'latest')
echo " "
echo "Image versions"
echo "=============="
SPECIFIC_VERSIONS=`docker ps | awk '{print $2}' | grep -v ':latest$' | grep 'defradigital/forms' | cut -c14-`
LATEST_VERSIONS=`docker ps | awk '{print $2}' | grep  ':latest$' | grep 'defradigital/forms' | rev | cut -c8- | rev`

LATEST_VERSIONS_ARR=($LATEST_VERSIONS)
IMAGES=`docker images --digests --format '{{ .Repository }} {{ .Digest }}' | grep defradigital/forms | sort`
echo -n "."
OUTPUT_VERSIONS=""
while IFS= read -r line || [[ -n $line ]]; do
  SERVICE_NAME=`echo $line | awk '{print $1}'`
  DIGEST=`echo $line | awk '{print $2}'`
  if printf '%s\0' "${LATEST_VERSIONS_ARR[@]}" | grep -Fxqz -- $SERVICE_NAME; then
    CURL_URL="https://registry.hub.docker.com/v2/repositories/$SERVICE_NAME/tags"
    TAG_FILTER=".results[] | { name: .name, digest: .digest } | select (.digest == \"$DIGEST\") | select (.name != \"latest\") | pick(.name)"
    URL_RESPONSE=`curl -s $CURL_URL`
    URL_RESP_LOWER=`echo $URL_RESPONSE | tr '[:upper:]' '[:lower:]'`
    if [[ $URL_RESP_LOWER != *"not found"* ]]; then
      TAG=`echo $URL_RESPONSE | jq "$TAG_FILTER" | jq .name`
      if [[ $PREV_SERVICE_NAME != $SERVICE_NAME ]]; then
        OUTPUT_VERSIONS+="${SERVICE_NAME:13} ${TAG}\n"
      fi
    fi
    echo -n "."
  fi
done < <(printf '%s' "$IMAGES")
echo " "
echo -en $OUTPUT_VERSIONS | sort -r | sort -u -k1,1
echo $SPECIFIC_VERSIONS
echo " "
