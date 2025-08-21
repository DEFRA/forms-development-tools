CONTAINER_IDS=`docker ps | awk '{print $1}' | grep -v "CONTAINER"`
for CONTAINER_ID in $CONTAINER_IDS;
do
  IMAGE_DETAILS=`docker inspect $CONTAINER_ID | jq '.[] | { name: .Config.Labels."defra.cdp.git.repo.name", digest: .Image } | select(.name != null)'`
  if [ "$IMAGE_DETAILS" != '' ]; then
  DIGEST=`echo $IMAGE_DETAILS | jq '.digest' | tr -d '"'`
  FULL_SERVICE_NAME=`echo $IMAGE_DETAILS | jq '.name' | tr -d '"'`
  SERVICE_NAME=`echo $FULL_SERVICE_NAME | sed "s/DEFRA\///"`
  TAG_FILTER=".results[] | { name: .name, digest: .digest } | select (.digest == \"$DIGEST\") | select (.name != \"latest\") | pick(.name)"
  TAG=`curl -s https://registry.hub.docker.com/v2/repositories/defradigital/$SERVICE_NAME/tags | jq "$TAG_FILTER" | jq .name`
  curl https://registry.hub.docker.com/v2/repositories/defradigital/$SERVICE_NAME/tags
  echo $SERVICE_NAME $TAG
  fi
done
