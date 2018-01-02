#!/bin/sh
cp -R lib/python2.7/site-packages/* dist-build
cp lambda.py dist-build
cd dist-build
zip -r ../dist/compliance_lambda.zip *
