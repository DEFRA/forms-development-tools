docker images --digests
IMAGES=`docker images --digests --format 'json'`
echo Images $IMAGES

# for IMAGE in $IMAGES;
# do
#   echo Image $IMAGE
#   echo ImageJSON `echo $IMAGE | jq '.'`
#   DIGEST=`echo $IMAGE | jq '.digest' | tr -d '"'`
#   SERVICE_NAME=`echo $IMAGE | jq '.name' | tr -d '"'`
#   echo ServiceName $SERVICE_NAME
  # echo ServiceName $SERVICE_NAME >> ../logs.txt
#   CURL_URL="https://registry.hub.docker.com/v2/repositories/$SERVICE_NAME/tags"
#   TAG_FILTER=".results[] | { name: .name, digest: .digest } | select (.digest == \"$DIGEST\") | select (.name != \"latest\") | pick(.name)"

#   TAG_FILTER3=".results[] | { name: .name, digest: .digest }"

#   TAG_3=`curl -s $CURL_URL | jq "$TAG_FILTER3"`
#   echo Temp3 $TAG_3
#   echo Temp3 Filter $TAG_FILTER
#   TAG=`curl -s $CURL_URL | jq "$TAG_FILTER" | jq .name`
#   echo $SERVICE_NAME $TAG
# done
