#!/bin/sh
yum update -y
yum install -y gcc python27-pip python27-devel
cd /package
pip install -r requirements.txt -t .