#!/usr/bin/env sh
#
# Put files in the imos-toolbox bucket.
# Storage of the files should follow imos-data rules,
# mainly the md5 metadata entry.
#
# $1 - the input file
#
# Example:
# send_testfile.sh my-file
#
# author: hugo.oliveira@utas.edu.au
#

put() {
bucket="imos-toolbox";
file=$1
filemd5=$(openssl dgst -md5 "$file" | cut -d "=" -f2 | cut -d " " -f2);
filemd5_b64=$(openssl dgst -md5 -binary "$file" | openssl enc -base64);
echo "Sending $file ..."
aws s3api put-object --bucket "$bucket" --key "$file" --body "$file" --content-md5 "$filemd5_b64" --metadata "md5=$filemd5"
}

put $1 || (echo failed to upload $1;exit 1)
