JQ_INSTALLED=`command -v jq`
echo "installed ${JQ_INSTALLED}"
CONTAINER_IDS=`docker ps | awk '{print $1}' | grep -v "CONTAINER"`
for CONTAINER_ID in $CONTAINER_IDS;
do
  IMAGE_DETAILS=`docker inspect $CONTAINER_ID | jq '.[] | { name: .Config.Labels."defra.cdp.git.repo.name", digest: .Image } | select(.name != null)'`
  if [ "$IMAGE_DETAILS" != '' ]; then
  DIGEST=`echo $IMAGE_DETAILS | jq '.digest' | tr -d '"'`
  FULL_SERVICE_NAME=`echo $IMAGE_DETAILS | jq '.name' | tr -d '"'`
  SERVICE_NAME=`echo $FULL_SERVICE_NAME | sed "s/DEFRA\///"`
  TAG_FILTER=".results[] | { name: .name, digest: .digest } | select (.digest == \"$DIGEST\") | select (.name != \"latest\") | pick(.name)"
  TAG_1=`curl -s https://registry.hub.docker.com/v2/repositories/defradigital/$SERVICE_NAME/tags | jq "$TAG_FILTER"`
  TAG=`curl -s https://registry.hub.docker.com/v2/repositories/defradigital/$SERVICE_NAME/tags | jq "$TAG_FILTER" | jq .name`
  echo $SERVICE_NAME $TAG 1: $TAG_1 $TAG_FILTER
  fi
done
