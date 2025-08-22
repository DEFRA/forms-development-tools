IMAGES="`docker images --digests | awk '{printf "%s %s\n", $1, $3}' | sed '1d'`"

while IFS= read -r line || [[ -n $line ]]; do
  SERVICE_NAME=`echo $line | awk '{print $1}'`
  DIGEST=`echo $line | awk '{print $2}'`
  # echo ServiceName $SERVICE_NAME
  # echo Digest $DIGEST
  if [[ "$SERVICE_NAME" == defradigital* ]]; then
    CURL_URL="https://registry.hub.docker.com/v2/repositories/$SERVICE_NAME/tags"
    TAG_FILTER=".results[] | { name: .name, digest: .digest } | select (.digest == \"$DIGEST\") | select (.name != \"latest\") | pick(.name)"
    URL_RESPONSE=`curl -s $CURL_URL`
    URL_RESP_LOWER=`echo $URL_RESPONSE | tr '[:upper:]' '[:lower:]'`
    if [[ $URL_RESP_LOWER != *"not found"* ]]; then
      TAG=`echo $URL_RESPONSE | jq "$TAG_FILTER" | jq .name`
      echo $SERVICE_NAME $TAG
    fi
  fi
done < <(printf '%s' "$IMAGES")
