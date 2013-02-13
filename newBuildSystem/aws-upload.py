#!/usr/bin/env python

# This script uploads a file to Amazon S3.
# It uses the key specified in AWS_ACCESS_KEY and gets the secret from the Keychain.

AWS_ACCESS_KEY = 'AKIAIDCNEPBLS2IMO55A'
BUCKET = 'gpgtools'


import sys, os
from subprocess import check_output, CalledProcessError

try:
    from boto.s3.connection import S3Connection
    from boto.exception import S3ResponseError
except ImportError:
    sys.exit("Can't find boto! Use \"sudo easy_install boto\" to install it.")

	
if len(sys.argv) != 2:
	exit('Usage: aws-upload.py file')

file = sys.argv[1]
if not os.path.isfile(file):
	exit('File not found "' + file + '"')

filename = os.path.basename(file)

try:
	secret = check_output(["security", "find-generic-password", "-w", "-a", "AKIAIDCNEPBLS2IMO55A"])
	secret = secret[:-1]
except CalledProcessError:
	exit("Can't get AWS secret access key! Do you have it in your keychain?")


try:
	connection = S3Connection(AWS_ACCESS_KEY, secret)
	bucket = connection.get_bucket(BUCKET)
	awsfile = bucket.new_key(filename)

	awsfile.set_contents_from_filename(file)
	awsfile.set_acl('public-read')
except S3ResponseError, e:
	if e.status == 403:
		exit("Login failed, please check your Amazon credentials!")
	elif e.status == 404:
		exit("The bucket doen't exist!")
	else:
		exit("Unknown error (" + e.status + ")!")
else:
	print "https://s3.amazonaws.com/" + BUCKET + "/" + filename

