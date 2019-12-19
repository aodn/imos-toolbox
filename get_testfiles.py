#!/usr/bin/env python3
"""
get_testfiles

Usage:
  get_testfiles [--outdir=<outdir>]
  get_testfiles (-h | --help)

Options:
  -h --help     Show this screen.
  --outdir=<outdir> The directory to save the bucket content.

"""
__package__ = 'imos-toolbox'

import hashlib
import os

import boto3
import botocore
from docopt import docopt

DEFAULT_BUCKET = 'imos-toolbox'
DEFAULT_OUTDIR = os.path.join(os.path.dirname(os.path.realpath(__file__)))
DOWNLOAD_ATTEMPTS = 10


def file_md5(fname: str) -> str:
    "Compute md5 of a filename"
    hash_md5 = hashlib.md5()
    with open(fname, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()


def check_md5(
        file: str,
        md5: str,
) -> bool:
    """ Check md5 of a file against a digest """
    return file_md5(file) == md5


def get_md5(client: boto3.client, bucket: str, keyname: str) -> str:
    """Get the md5 of a key in s3"""
    metadata = client.head_object(Bucket=bucket, Key=keyname)
    etag = metadata['ETag'][1:-1]
    if '-' in etag and metadata['Metadata']:
        md5 = metadata['Metadata']['s3cmd-attrs'].split(':')[-1]
    else:
        md5 = etag
    return md5


def gen_param(bucket: boto3.resource) -> (str, str, str):
    """
    Generate the main 3 parameters to save a s3 file locally:
        kname - s3 key name
        dest_folder - destination folder name
        dest_file - destination file name
    """
    for s3obj in bucket.objects.all():
        kname = s3obj.key
        path, filename = os.path.split(kname)
        dest_file = os.path.join(outdir, kname)
        dest_folder = os.path.join(outdir, path)
        yield kname, dest_folder, dest_file


def need_md5_check(client: boto3.client, bucket_name: str,
                   kname: str) -> (str, bool):
    """
    Return a boolean if the file need/can be md5sum
    check, as well as the actual md5sum of the file.
    """
    try:
        md5sum = get_md5(client, DEFAULT_BUCKET, kname)
        do_md5_check = True
    except (botocore.exceptions.ClientError, KeyError):
        md5sum = None
        do_md5_check = False

    return do_md5_check, md5sum


def should_skip_file(dest_file: str, do_md5_check: bool, md5sum: str) -> bool:
    """
    Determine if the file should be downloaded or not, based on
    file existance, capacity for md5sum check, and actual md5sum
    of local and remote file key.
    """
    if os.path.exists(dest_file):
        if do_md5_check:
            if check_md5(dest_file, md5sum):
                print(f"m5dsum match - Skipping {dest_file}")
                return True
            else:
                print(f"md5sum diff - Overwriting {dest_file}")
                return False
    return False


def download_file(client: boto3.client,
                  bucket_name: str,
                  kname: str,
                  dest_file: str,
                  do_md5_check: bool = False,
                  md5sum: str = '',
                  attempts: int = DOWNLOAD_ATTEMPTS) -> None:
    ntry = 0
    while ntry < attempts:
        ntry += 1
        try:
            print(f'Downloading {dest_file} | {md5sum}')
            client.download_file(DEFAULT_BUCKET, kname, dest_file)
        except ClientError:
            continue

        if not do_md5_check:
            break
        else:
            if check_md5(dest_file, md5sum):
                print(f'{dest_file} pass md5sum -> DONE!')
                break
            else:
                print(f'{dest_file} fail md5sum -> Trying again...')

    if ntry == attempts:
        print(f"Try attempt exceeded for s3 key: {kname}")
        return False
    return True


if __name__ == '__main__':

    args = docopt(__doc__, version='get_testfiles 0.1')
    outdir = args['--outdir']

    if not outdir:
        outdir = DEFAULT_OUTDIR

    #make sure we avoid using any AWS setup credentials
    aws_unsigned_config = botocore.config.Config(
        signature_version=botocore.UNSIGNED)
    aws_vars_to_remove = [x for x in os.environ.keys() if 'AWS_' in x]
    [os.environ.pop(x) for x in aws_vars_to_remove]

    client = boto3.client('s3', config=aws_unsigned_config)
    s3 = boto3.resource('s3', config=aws_unsigned_config)
    bucket = s3.Bucket(DEFAULT_BUCKET)

    print(f"Getting test files in {DEFAULT_BUCKET} bucket...")

    for kname, dest_folder, dest_file in gen_param(bucket):
        do_md5_check, md5sum = need_md5_check(client, DEFAULT_BUCKET, kname)

        if not os.path.exists(dest_folder):
            print(f"Creating folder {dest_folder}")
            os.makedirs(dest_folder)

        skip = should_skip_file(dest_file, do_md5_check, md5sum)
        if not skip:
            download_file(client,
                          DEFAULT_BUCKET,
                          kname,
                          dest_file,
                          do_md5_check=do_md5_check,
                          md5sum=md5sum,
                          attempts=DOWNLOAD_ATTEMPTS)
    print(f'SUCCESS syncing {DEFAULT_BUCKET}')
