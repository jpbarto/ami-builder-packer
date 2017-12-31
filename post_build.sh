#!$(which bash)

IMAGE_IDS=`grep 'artifact,0,id' build.log | cut -d, -f6 | sed 's/%!(PACKER_COMMA)/ /g'`

for id in ${IMAGE_IDS}
do
  IMAGE_REGION=`echo ${id} | cut -d: -f1`
  IMAGE_ID=`echo ${id} | cut -d: -f2`
  echo "Recording the creation of image ${IMAGE_ID} in ${IMAGE_REGION}"

  echo "\"${IMAGE_REGION}:${IMAGE_ID}\"," >> ami_ids.json
done

# Packer doesn't return non-zero status; we must do that if Packer build failed
test -s ami_ids.json || exit 1

# issue a notification that the images have been built
IMAGE_RESOURCES=`sed -e '$ s/,$//' ami_ids.json`
cat > ami_builder_event.json <<EOF
[
  {
    "Source": "com.ami.builder",
    "DetailType": "AmiBuilder",
    "Detail": "{ \"AmiStatus\": \"Created\", \"StartedBy\": \"${CODEBUILD_INITIATOR}\", \"SourceVersion\": \"${CODEBUILD_RESOLVED_SOURCE_VERSION}\", \"CodeBuildId\": \"${CODEBUILD_BUILD_ID}\" }",
    "Resources": [
      ${IMAGE_RESOURCES}
    ]
  }
]
EOF
cat ami_builder_event.json
aws events put-events --entries file://ami_builder_event.json
