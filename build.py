#!/usr/bin/env python3
""" Build the imos stand-alone toolbox GUI using only the Matlab compiler.

This script ignores untracked and testfiles within the repository and weakly
attach a string version to the binary filename.
The string is related to the repo state.

Usage:
  build.py  --arch=<architecture> [--root_path=<imostoolboxpath> --mcc_path=<mccpath> --dist_path=<distpath>]

Options:
  -h --help     Show this screen.
  --version     Show version.
  --mcc_path=<mccpath>           The Matlab runtime Path
  --root_path=<imostoolboxpath>  The repository root path
  --dist_path=<distpath>  Where Compiled items should be stored
  --arch=<architecture>   One of win64,glnxa64,maci64
"""

import os
import subprocess as sp
from getpass import getuser
from pathlib import Path
from shutil import move
from typing import List

from docopt import docopt
from git import Repo

VALID_ARCHS = ['glnxa64', 'win64', 'maci64']
ARCH_NAMES = {
    'glnxa64': 'Linux64',
    'maci64': 'Mac64',
    'win64': 'Win64',
}
VERSION_FILE = '.standalone_canonical_version'


def run(x: str):
    return sp.Popen(x, stdout=sp.PIPE,
                    shell=True).communicate()[0].decode('utf-8').strip()


def create_java_call_sig_compile(root_path: str) -> str:
    java_path = os.path.join(root_path, 'Java/')
    return f"cd {java_path};ant install;cd {root_path}"


def git_info(root_path: str) -> dict:
    """ Return git information
    info['username']
    info['is_dirty']
    info['branch']
    info['tag']
    info['modified_files']
    info['staged_files']
    info['untracked_files']
    info['is_tag_release']
    info['is_master']
    info['is_clean']
    info['is_official_release']
    info['version']
    """
    repo = Repo(root_path)
    if repo.bare:
        raise TypeError(f"{root_path} is not a git repository")

    info = {}
    info['username'] = getuser()
    info['is_dirty'] = repo.is_dirty()
    info['branch'] = str(repo.active_branch)
    info['tag'] = str(repo.git.describe('--tags'))
    info['modified_files'] = [x.a_path for x in repo.index.diff(None)]
    info['staged_files'] = [x.a_path for x in repo.index.diff("HEAD")]
    info['untracked_files'] = repo.untracked_files

    info['is_tag_release'] = len(info['tag'].split('-')) < 3
    info['is_master'] = info['branch'] == 'master'
    info['is_clean'] = not info['is_dirty'] and not info['staged_files']
    info['is_official_release'] = info['is_tag_release'] and info['is_clean']

    version = ''
    if info['is_official_release']:
        version += info['tag']
    else:
        version += info['branch']
        version += '-' + info['username']
        version += '-' + info['tag']
        if info['is_dirty']:
            version += '-dirty'

    info['version'] = version
    return info


def find_files(folder: str, ftype: str) -> list:
    """ Find all the files within the repository that are not testfiles """
    for file in Path(folder).glob(os.path.join('**/', ftype)):
        filepath = file.as_posix()
        if 'data/testfiles' not in filepath:
            yield filepath


def get_required_files(root_path: str, info: dict) -> (list, list):
    """ obtain the mfiles and matfiles for binary compilation """
    allmfiles = list(find_files(root_path, '*.m'))
    allmatfiles = list(find_files(root_path, '*.mat'))
    if info['is_dirty']:
        print(f"Warning: {root_path} repository is dirty")
    if info['modified_files']:
        print(f"Warning: {root_path} got modified files not staged")
    if info['staged_files']:
        print(f"Warning: {root_path} got staged files not commited")
    if info['untracked_files']:
        print(
            f"Warning: {root_path} got untracked files - Ignoring them all...")
        for ufile in info['untracked_files']:
            if ufile in allmfiles:
                allmfiles.remove(ufile)
            if ufile in allmatfiles:
                allmatfiles.remove(ufile)

    mind = [
        ind for ind, file in enumerate(allmfiles) if 'imosToolbox.m' in file
    ]
    mentry = allmfiles.pop(mind[0])
    allmfiles = [mentry] + allmfiles
    return allmfiles, allmatfiles


def create_mcc_call_sig(mcc_path: str, root_path: str, dist_path: str,
                        mfiles: List[str], matfiles: List[str],
                        output_name: str) -> str:
    standalone_flags = '-m'
    verbose_flag = '-v'
    outdir_flag = f"-d \'{dist_path}\'"
    clearpath_flag = '-N'
    outname_flag = f"-o \'{output_name}\'"
    verbose_flag = '-v'
    warning_flag = '-w enable'
    mfiles_str = ' '.join([f"\'{file}\'" for file in mfiles])
    matfiles_str = ' '.join([f"-a \'{file}\'" for file in matfiles])
    return ' '.join([
        mcc_path, standalone_flags, verbose_flag, outdir_flag, clearpath_flag,
        outname_flag, verbose_flag, warning_flag, mfiles_str, matfiles_str
    ])


def get_args(args: dict) -> (str, str, str, str):
    """process the cmdline arguments to return the root_path, dist_path, mcc binary, and architecture"""
    if not args['--root_path']:
        root_path = os.getcwd()
    else:
        root_path = args['--root_path']

    if not args['--dist_path']:
        dist_path = os.path.join(root_path, 'dist')
        exists = os.path.lexists(dist_path)
        if not exists:
            os.mkdir(dist_path)
    else:
        dist_path = args['--dist_path']

    if not args['--mcc_path']:
        mcc = 'mcc'
    else:
        mcc = args['--mcc_path']

    if args['--arch'] in VALID_ARCHS:
        ind = VALID_ARCHS.index(args['--arch'])
        arch = VALID_ARCHS[ind]
    else:
        raise Exception(
            f"{args['--arch']} is not one of the valid architectures {VALID_ARCHS}"
        )
    return root_path, dist_path, mcc, arch


def gen_outname(arch: str, version: str) -> (str, str):
    """ return a temporary name and a final name for the toolbox binary.
    This is required since mcc do not support underscores in names
    """
    return f"tmp_imosToolbox_{ARCH_NAMES[arch]}", f"imosToolbox_{ARCH_NAMES[arch]}_{version}"


def write_version(afile: str, version: str) -> None:
    with open(afile, 'w') as file:
        file.writelines([version + '\n'])


if __name__ == '__main__':
    args = docopt(__doc__, version='0.1')
    root_path, dist_path, mcc, arch = get_args(args)
    repo_info = git_info(root_path)

    print("Starting build process.")
    print(f"Marking {repo_info['version']} as the standalone version")
    write_version(VERSION_FILE, repo_info['version'])

    temp_output_name, output_name = gen_outname(arch, repo_info['version'])

    print("Gathering files to be included")
    mfiles, matfiles = get_required_files(root_path, repo_info)
    java_call = create_java_call_sig_compile(root_path)
    mcc_call = create_mcc_call_sig(mcc, root_path, dist_path, mfiles, matfiles,
                                   temp_output_name)

    print("Current repo information:")
    print(repo_info)
    print(f"Calling {java_call}..")
    java_status = run(java_call)
    if not java_status:
        raise Exception(f"{java_call} failed")
    print(f"Calling {mcc_call}...")
    mcc_status = run(mcc_call)
    if not mcc_status:
        raise Exception(f"{mcc_call} failed")
    print(f"Updating binary at {root_path}....")
    move(os.path.join(dist_path, temp_output_name),
         os.path.join(root_path, output_name))
    print("Build Finished.")
