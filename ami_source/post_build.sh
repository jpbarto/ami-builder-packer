#!$(which bash)

IMAGE_IDS=`grep 'artifact,0,id' build.log | cut -d, -f6 | sed 's/%!(PACKER_COMMA)/ /g'`
echo Grepped ${IMAGE_IDS}
echo ${PRIVATE_KEY} | base64 -d > tmp_private.pem
echo ${PRIVATE_KEY}

for id in ${IMAGE_IDS}
do
  echo ${id}
  IMAGE_REGION=`echo ${id} | cut -d: -f1`
  IMAGE_ID=`echo ${id} | cut -d: -f2`
  echo "Preparing to tag image ${IMAGE_ID} in ${IMAGE_REGION}"

  # generate a signature for the AMI ID
  echo "${IMAGE_REGION}:${IMAGE_ID}" > ami_signature.txt;
  openssl rsautl -sign -inkey tmp_private.pem -in ami_signature.txt -out ami_signature.sign;
  # split the signature and write it as a tag to the AMI
  IMAGE_SIGNATURE=`base64 -i ami_signature.sign`;
  echo "Created signature ${IMAGE_SIGNATURE}"
  IMG_SIG_P1=`echo ${IMAGE_SIGNATURE} | cut -b 1-250`;
  IMG_SIG_P2=`echo ${IMAGE_SIGNATURE} | cut -b 251-500`;
  aws ec2 create-tags --resources ${IMAGE_ID} --region ${IMAGE_REGION} --tags Key="compliance:signature:part1",Value="${IMG_SIG_P1}" Key="compliance:signature:part2",Value="${IMG_SIG_P2}"

  # record the tagging of the AMI
  echo "\"${IMAGE_REGION}:${IMAGE_ID}\"," >> ami_ids.json
  echo "Tagged image ${IMAGE_ID} in ${IMAGE_REGION}"
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
