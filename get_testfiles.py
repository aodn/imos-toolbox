#!/usr/bin/env python3
"""
get_testfiles

Usage:
  get_testfiles [--outdir=<outdir> (-v | --verbose)]
  get_testfiles (-h | --help)

Options:
  -h --help     Show this screen.
  --outdir=<outdir> The directory to save the bucket content.

"""
__package__ = 'imos-toolbox'

import hashlib
import os
import sys

import boto3
from botocore.exceptions import ClientError
from docopt import docopt

DEFAULT_BUCKET = 'imos-toolbox'
DEFAULT_OUTDIR = os.path.join(os.path.dirname(os.path.realpath(__file__)))
NTRY = 10


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


def get_md5(client, bucket: str, keyname: str) -> str:
    """Get the md5 of a key in s3"""
    metadata = client.head_object(Bucket=bucket, Key=keyname)
    etag = metadata['ETag'][1:-1]
    if '-' in etag and metadata['Metadata']:
        md5 = metadata['Metadata']['s3cmd-attrs'].split(':')[-1]
    else:
        md5 = etag
    return md5


if __name__ == '__main__':

    args = docopt(__doc__, version='get_testfiles 0.1')
    outdir = args['--outdir']
    verbose = args['--verbose'] or args['-v']
    if not outdir:
        outdir = DEFAULT_OUTDIR

    client = boto3.client('s3')
    s3 = boto3.resource('s3')
    bucket = s3.Bucket(DEFAULT_BUCKET)

    if verbose:
        print(f"Getting test files in {DEFAULT_BUCKET} bucket...")

    for s3obj in bucket.objects.all():
        kname = s3obj.key
        path, filename = os.path.split(kname)
        dest_file = os.path.join(outdir, kname)
        dest_folder = os.path.join(outdir, path)

        try:
            md5sum = get_md5(client, DEFAULT_BUCKET, kname)
            do_md5_check = True
        except (ClientError, KeyError):
            md5sum = None
            do_md5_check = False

        if not os.path.exists(dest_folder):
            if verbose:
                print(f"Creating folder {dest_folder}")
            os.makedirs(dest_folder)

        if os.path.exists(dest_file):
            if do_md5_check:
                if check_md5(dest_file, md5sum):
                    if verbose:
                        print(f"m5dsum match - Skipping {dest_file}")
                    continue
                else:
                    if verbose:
                        print(f"md5sum diff - Overwriting {dest_file}")

        ntry = 0
        while ntry < NTRY:
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

        if ntry == NTRY:
            print('Aborted - try attempt exceeded')
            sys.exit(-1)

    print(f'SUCCESS syncing {DEFAULT_BUCKET}')
