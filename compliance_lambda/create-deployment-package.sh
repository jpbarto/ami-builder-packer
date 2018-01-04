#!/bin/sh

#####
#
# Copy the Lambda code and install its Linux-compiled dependencies into dist-build.  
# When done zip the directory's contents and place the zip into dist.
#
#####

# clean the target and working space
rm -fr dist dist-build
mkdir dist dist-build

# copy the Lambda function, requirements file and Docker build script to the working space
cp lambda.py dist-build
cp requirements.txt dist-build
cp build-deps.sh dist-build

# Download / compile Lambda-compatible versions of the Python module dependencies
cd dist-build
docker run -ti --rm -v ${PWD}:/package:rw amazonlinux sh '/package/build-deps.sh'

# zip the directory contents to create a Lambda deployment package
zip -r ../dist/compliance_lambda.zip *
