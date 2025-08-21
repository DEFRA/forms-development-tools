CONTAINER_IDS=`docker ps | awk '{print $1}' | grep -v "CONTAINER"`
for CONTAINER_ID in $CONTAINER_IDS;
do
  IMAGE_DETAILS=`docker inspect $CONTAINER_ID | jq '.[] | { name: .Config.Labels."defra.cdp.service.name", digest: .Image } | select(.name != null)'`
  if [ "$IMAGE_DETAILS" != '' ]; then
  DIGEST=`echo $IMAGE_DETAILS | jq '.digest' | tr -d '"'`
  SERVICE_NAME=`echo $IMAGE_DETAILS | jq '.name' | tr -d '"'`
  echo ServiceName $SERVICE_NAME
  echo INSPECT `docker inspect $CONTAINER_ID | jq '.[] | { image: .Image, name: .Name, composeImage: .Config.Labels."defra.docker.compose.image", serviceName: .Config.Labels."defra.cdp.service.name" }'`
  docker inspect $CONTAINER_ID
  echo ServiceName $SERVICE_NAME >> ../logs.txt
  docker inspect $CONTAINER_ID >> ../logs.txt
  CURL_URL="https://registry.hub.docker.com/v2/repositories/defradigital/$SERVICE_NAME/tags"
  TAG_FILTER=".results[] | { name: .name, digest: .digest } | select (.digest == \"$DIGEST\") | select (.name != \"latest\") | pick(.name)"

  TAG_FILTER3=".results[] | { name: .name, digest: .digest }"

  TAG_3=`curl -s $CURL_URL | jq "$TAG_FILTER3"`
  echo Temp3 $TAG_3
  echo Temp3 Filter $TAG_FILTER
  TAG=`curl -s $CURL_URL | jq "$TAG_FILTER" | jq .name`
  echo $SERVICE_NAME $TAG
  fi
done
