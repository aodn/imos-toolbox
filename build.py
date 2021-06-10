#!/usr/bin/env python3
"""This script will build the imos stand-alone toolbox GUI using the Matlab compiler.

Support both Linux and Windows. See the `--arch` flag.

Usage:
    build.py [--arch=<architecture> --check-repo-only --dry-run --build-java-deps  --root_path=<imostoolboxpath> --matlab_path=<mccpath> --dist_path=<distpath>]

Options:
    -h --help    Show this screen.
    --version    Show version.
    --arch=<architecture>    One of win64,glnxa64,maci64.
    --check-repo-only   Just do a Repository check, no build steps.
    --dry-run   Just do all the checks, but don't build anything
    --build-java-deps    Build of java libraries.
    --matlab_path=<matlabpath>    The Matlab install path.
    --root_path=<imostoolboxpath>    The repository root path
    --dist_path=<distpath>    Where Compiled items should be stored

"""

import os
import sys
import platform
import subprocess as sp
from socket import gethostname
from getpass import getuser
from pathlib import Path
from shutil import copy
from typing import List, Tuple
from docopt import docopt
from git import Repo

VALID_ARCHS = ["glnxa64", "win64", "maci64"]
ARCH_NAMES = {
    "glnxa64": "Linux64",
    "maci64": "Mac64",
    "win64": "Win64",
}
VERSION_FILE = ".standalone_canonical_version"
MATLAB_VERSION = "R2018b"

#below are the toolboxes root folder within R2018b/
MATLAB_TOOLBOXES_TO_INCLUDE: List[str] = [
    ['signal','signal'],
    ['stats','stats'],
    ['images','imuitools'],
]

DEFAULT_MATLAB_ROOT_PATH = {
    "glnxa64": os.path.join("/opt/MATLAB/", MATLAB_VERSION),
    "maci64": os.path.join("/Applications/MATLAB/", MATLAB_VERSION),
    "win64": os.path.join("C:\\Program Files\\", "\\MATLAB\\", MATLAB_VERSION),
}

MATLAB_ROOT_PATH_OPTS = {
    "glnxa64": [
        "/opt/",
        "/usr/local/",
        os.path.join("/home", getuser()),
        os.path.join("/home", getuser(), "." + gethostname(), "apps"),
    ],
    "maci64": ["/Applications/", "/Users", "/"],
    "win64": ["C:\\Program Files\\"],
}

MATLAB_COMPILER_FILENAME = {"glnxa64": "mcc", "maci64": "mcc", "win64": "mcc.bat"}


def find_matlab_rootpath(arch_str):
    """Locate the matlab installation root path."""

    default_root_path = Path(DEFAULT_MATLAB_ROOT_PATH[arch_str])
    if default_root_path.exists():
        return str(default_root_path)

    print(f"Matlab is not installed in the default directory. Searching some common options for arch={arch_str}...")

    lookup_folders = MATLAB_ROOT_PATH_OPTS[arch_str]
    for folder in lookup_folders:
        rootpath = Path(folder, "MATLAB", MATLAB_VERSION)
        if rootpath.exists():
            return rootpath
    raise ValueError("Unable to find matlab root path")


def run(command: str):
    """Run a command at shell/cmdline."""
    return sp.run(command, shell=True, stdout=sp.PIPE, stderr=sp.PIPE)


def create_java_call_sig_compile(root_path: str) -> str:
    """Create the call to build java dependencies."""
    java_path = os.path.join(root_path, "Java")
    return f"cd {java_path} && ant install && cd {root_path}"


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
    info["username"] = getuser()
    info["is_dirty"] = repo.is_dirty()
    info["branch"] = str(repo.active_branch)
    info["tag"] = str(repo.git.describe("--tags"))
    info["modified_files"] = [x.a_path for x in repo.index.diff(None)]
    info["staged_files"] = [x.a_path for x in repo.index.diff("HEAD")]
    info["untracked_files"] = repo.untracked_files

    info["is_tag_release"] = len(info["tag"].split("-")) < 3
    info["is_master"] = info["branch"] == "master"
    info["is_clean"] = not info["is_dirty"] and not info["staged_files"]
    info["is_official_release"] = info["is_tag_release"] and info["is_clean"]

    version = ""
    if info["is_official_release"]:
        version += info["tag"]
    else:
        version += info["branch"]
        version += "|" + info["username"]
        version += "|" + info["tag"]
        if info["is_dirty"]:
            version += "|dirty"

    info["version"] = version
    return info


def find_files_and_folders(path: str) -> (list, list):
    """Find both files and folders recursively in a current path."""
    pfolder: Path.PosixPath = Path(path)
    all_folders: list = [
        x
        for x in pfolder.glob("**/")
        if x.is_dir()
        and "/." not in x.as_posix()
        and "/dist/" not in x.as_posix()
        and "/snapshot/" not in x.as_posix()
    ]
    all_files: list = [
        x
        for x in pfolder.glob("**/*")
        if x.is_file()
        and "/." not in x.as_posix()
        and "/dist/" not in x.as_posix()
        and "/snapshot" not in x.as_posix()
    ]
    return all_folders, all_files


def find_items(folder: str) -> dict:
    """Find all the files within the repository that are not testfiles."""
    [all_folders, all_files] = find_files_and_folders(folder)

    items = {}

    items["path_folders"] = [
        x.as_posix()
        for x in all_folders
        if "/+" not in x.as_posix() and "testfiles" not in x.parts
    ]

    items["standard_classes"] = [
        x.as_posix()
        for x in all_folders
        if "/@" in x.as_posix() and "/+" not in x.parent.as_posix()
    ]
    items["standard_packages"] = [
        x.as_posix()
        for x in all_folders
        if "/+" in x.as_posix() and "/+" not in x.parent.as_posix()
    ]

    items["standard_mfiles"] = [
        x.as_posix()
        for x in all_files
        if x.suffix == ".m"
        and x.parts[-1] != "tmpbuild.m"
        and "/+" not in x.parent.as_posix()
    ]
    items["standard_matfiles"] = [
        x.as_posix()
        for x in all_files
        if "data/testfiles/" not in x.as_posix()
        if x.suffix == ".mat" and "/+" not in x.parent.as_posix()
    ]

    items["standard_miscfiles"] = [
        x.as_posix()
        for x in all_files
        if "data/testfiles/" not in x.as_posix()
        and x.suffix != ".mat"
        and x.suffix != ".m"
        and x.suffix != ".log"
        and x.suffix != ".nc"
        and x.suffix != ".pdf"
        and x.suffix != ".py"
        and x.suffix != ".sh"
        and x.suffix != ".jar"  # automatic added by mcc.
        and "imosToolbox_" not in x.as_posix()
        and ".git" not in x.as_posix()
    ]
    return items


def get_required_files(root_path: str, info: dict) -> (list, list):
    """obtain the mfiles and matfiles for binary compilation."""
    items = find_items(root_path)
    allmfiles = items["standard_mfiles"]
    allmatfiles = items["standard_matfiles"]
    allpackages = items["standard_packages"]
    allmiscfiles = items["standard_miscfiles"]

    if info["untracked_files"]:
        print(f"Warning: {root_path} got untracked files - Ignoring them all...")
        for ufile in info["untracked_files"]:
            if ufile in allmfiles:
                allmfiles.remove(ufile)
            if ufile in allmatfiles:
                allmatfiles.remove(ufile)
            if ufile in allmiscfiles:
                allmiscfiles.remove(ufile)

    mind = [ind for ind, file in enumerate(allmfiles) if "imosToolbox.m" in file]
    mentry = allmfiles.pop(mind[0])

    allmfiles = [mentry] + allmfiles
    datafiles = allmatfiles + allmiscfiles

    return allmfiles, datafiles, allpackages


def create_mcc_call_sig(
    matlab_root_path: str,
    mcc_path: str,
    root_path: str,
    dist_path: str,
    output_name: str,
    arch: str,
    mfiles: list = None,
    datafiles: list = None,
    matpackages: list = None,
    class_folders: list = None,
) -> List[str]:
    """Create the mcc call signature based on argument options."""
    standalone_flags = "-m"
    verbose_flag = "-v"
    outdir_flag = f"-d {dist_path}"
    clearpath_flag = "-N"
    outname_flag = f"-o {output_name}"
    verbose_flag = "-v"
    warning_flag = "-w enable"
    mfiles_str = " ".join([f"{file}" for file in mfiles])
    datafiles_str = " ".join([f"-a {file}" for file in datafiles])
    matpackages_str = " ".join([f"-a {folder}" for folder in matpackages])

    if MATLAB_TOOLBOXES_TO_INCLUDE:
        extra_toolbox_paths = [
            os.path.join(matlab_root_path, "toolbox", *x) #beware of path joins in windows
            for x in MATLAB_TOOLBOXES_TO_INCLUDE
        ]

    mcc_arguments = " ".join(
        [
            standalone_flags,
            verbose_flag,
            outdir_flag,
            clearpath_flag,
            outname_flag,
            verbose_flag,
            warning_flag,
            mfiles_str,
            datafiles_str,
            matpackages_str,
        ],
    )

    if arch == "win64":
        # overcome the incapacity to execute a file with a valid full path in windows
        mcc_path = 'mcc'
        # overcome cmd.exe char limitation creating a tmp mfile and asking
        # matlab to evaluate a string. (yes...)
        tmpscript = os.path.join(root_path, "tmpbuild.m")
        with open(tmpscript, "w") as tmpfile:
            # overcome limitation of spaces within eval.
            if MATLAB_TOOLBOXES_TO_INCLUDE:
                # include other paths in the build call
                extra_requirements = " ".join(
                    ["-I " + "'" + x + "'" for x in extra_toolbox_paths],
                )
                cmdline = f'eval("{mcc_path} {mcc_arguments} {extra_requirements}")'
            else:
                cmdline = f'eval("{mcc_path} {mcc_arguments}")'

            tmpfile.write(cmdline)
        external_call = (
            f"matlab -nodesktop -nosplash -wait -r \"run('{tmpscript}');exit\""
        )
        rm_call = f"del {tmpscript}"
        rlist = [external_call, rm_call]
    else:
        # no need for extra quotes in linux, since we are in the shell.
        if MATLAB_TOOLBOXES_TO_INCLUDE:
            extra_requirements = " ".join(["-I " + x for x in extra_toolbox_paths])
            rlist = [" ".join([mcc_path, mcc_arguments, extra_requirements])]
        else:
            rlist = [" ".join([mcc_path, mcc_arguments])]
    return rlist


def get_args(args: dict) -> Tuple[str, str, str, str, str, str]:
    """process the cmdline arguments."""

    if not args["--root_path"]:
        root_path = os.getcwd()
    else:
        root_path = args["--root_path"]

    if not args["--dist_path"]:
        dist_path = os.path.join(root_path, "dist")
        exists = os.path.lexists(dist_path)
        if not exists:
            os.mkdir(dist_path)
    else:
        dist_path = args["--dist_path"]


    if not args["--arch"]:
        bits,linkage = platform.architecture()
        if bits != '64bit':
            raise Exception("32bit platforms are not supported.")

        if linkage == 'ELF':
            arch = 'glnxa64'
        elif linkage == 'WindowsPE':
            arch = 'win64'
        else:
            raise Exception(f"Architecture {linkage} is not supported")
    else:
        if args["--arch"] in VALID_ARCHS:
            ind = VALID_ARCHS.index(args["--arch"])
            arch = VALID_ARCHS[ind]
        else:
            raise Exception(
                f"{args['--arch']} is not one of the valid architectures {VALID_ARCHS}",
            )

    compiler_filename = MATLAB_COMPILER_FILENAME[arch]

    if args["--matlab_path"] and isinstance(args["--matlab_path"], str):
        matlab_root_path = Path(args["--matlab_path"])
        if matlab_root_path.exists():
            mcc_path = Path(matlab_root_path, "bin", compiler_filename)
    else:
        matlab_root_path = find_matlab_rootpath(arch)
        mcc_path = Path(matlab_root_path, "bin", compiler_filename)

    if not mcc_path.exists():
        raise Exception(
            f"Missing the mcc compiler at {matlab_root_path}. Please install the Matlab compiler toolbox."
        )
    else:
        mcc_path = str(mcc_path)

    return (
        root_path,
        dist_path,
        matlab_root_path,
        mcc_path,
        arch,
        args["--build-java-deps"],
    )


def write_version(afile: str, version: str) -> None:
    with open(afile, "w") as file:
        file.writelines([version + "\n"])


# TODO: make a state machien class for this mess.
if __name__ == "__main__":
    args = docopt(__doc__, version="0.1")

    root_path, dist_path, matlab_root_path, mcc_path, arch, build_java = get_args(args)
    repo_info = git_info(root_path)

    print(f"Starting build process for {ARCH_NAMES[arch]}")
    print(
        f"The repository version mashup [branch|user|tag|rstatus] is : {repo_info['version']}"
    )
    print("Current repo information:")
    for k, v in repo_info.items():
        print(f"    {k}:{v}")

    if not repo_info["untracked_files"]:
        print("Warning: Untracked files in the repository. These will NOT be included.")

    if not repo_info["staged_files"]:
        print(
            "Warning: Found non-commited changes! These modifications will be included in the stand-alone app!"
        )

    if not repo_info["modified_files"]:
        print(
            "Warning: Found non-staged files in the repository! These modifications will be included in the stand-alone app!"
        )

    if args['--check-repo-only']:
        sys.exit()

    if not args['--dry-run']:
        write_version(VERSION_FILE, repo_info["version"])

    # output name of binary is restricted in mcc
    tmp_name = f"imosToolbox_{ARCH_NAMES[arch]}"

    print("Gathering files to be included...")
    mfiles, datafiles, matpackages = get_required_files(root_path, repo_info)
    java_call = create_java_call_sig_compile(root_path)

    mcc_call = create_mcc_call_sig(
        matlab_root_path,
        mcc_path,
        root_path,
        dist_path,
        tmp_name,
        arch,
        mfiles=mfiles,
        datafiles=datafiles,
        matpackages=matpackages,
    )

    if build_java:
        print(f"Building Java dependencies")
        print(f"Calling `{java_call}`")
        if not args['--dry-run']:
            rstatus = run(java_call)
            if rstatus.returncode is not 0:
                raise Exception(f"`{java_call}` command failed. Stderr is: {rstatus.stderr}")
            else:
                if not rstatus.stdout:
                    print(f"{rstatus.stdout}")
    else:
        print(f"Building Java dependencies skipped.")

    print(f"Building Matlab dependencies")
    print(f"Calling `{mcc_call}`")
    for mcall in mcc_call:
        print(f"Executing the mcc call: {mcall}")
        if not args['--dry-run']:
            ok = run(mcall)
            if not ok:
                raise Exception(f"{mcall} failed")

    print(f"Updating binary at {root_path}")
    # mcc append .exe to end of file
    if not args['--dry-run']:
        if arch == "win64":
            copy(
                os.path.join(dist_path, tmp_name + ".exe"),
                os.path.join(root_path, tmp_name + ".exe"),
            )
        else:
            copy(
                os.path.join(dist_path, tmp_name),
                os.path.join(root_path, tmp_name + ".bin"),
            )

    print("Build Finished.")
