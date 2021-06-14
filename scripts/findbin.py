#!/usr/bin/env python3
#################################################################################################################
# findbin.py - This is a dependency-free python3.x script, which is designed to work as a drop-in shim for
# 'command', 'command -v', 'which', and 'whereis'.
#
# This script is part of Someguy's Scripts - a toolkit designed for provisioning *nix systems the way that
# Someguy123 likes 'em :)
#
# Official Someguy's Scripts repo: https://github.com/Someguy123/someguy-scripts 
#
# Usage:
#
# Simply place it in a common PATH location for the binaries you need to emulate/replace, for example:
# 
#   - /usr/bin/command
#   - /usr/bin/whereis
#   - /usr/bin/which
#   - /bin/command
#   - /bin/which
#   - /usr/local/bin/command
#   - /usr/local/bin/which
#   - /usr/local/bin/whereis
#
# 
# It attempts to emulate the behaviour of each system command, depending on what it's binary is called,
# so if you store this file at /usr/bin/command or /bin/command - it will automatically be emulating
# the behaviour of 'command'. While if placed at /usr/bin/which - it will emulate 'which',
# same goes for 'whereis'.
#
# For 'command', if '-v' / '-V' aren't specified, then it will use the first argument as the binary to
# locate and execute, and the remaining arguments to be passed through to the binary's args, which
# matches the behaviour of native 'command' without '-v'.
#
# If you run 'command -v ls' for example, it will simply output the location of the binary if known, or display
# a message matching the system 'command' error message: "/usr/bin/command: ls: command not found",
# with the return/error code 127 (just like native 'command').
#
# If you place this file at '/usr/bin/whereis' (or another 'whereis' location), it will act quite differently
# to 'command'. Instead of just searching for an exact binary, it will instead recursively search various
# locations (including non-binary locations) for files named XXX or have any arbitrary extension (XXX.*),
# for example 'whereis bash' might output: 'bash: /usr/local/bin/bash /etc/bash.bashrc /usr/share/man/man1/bash.1.gz'
#
#################################################################################################################
from pathlib import Path
from os import getenv as env
from typing import Union, Optional, List, Tuple, Dict
import sys
import os
import subprocess
import shlex

def is_true(x) -> bool: return str(x).lower() in ['1', 'true', 'yes', 't', 'y', 'tru', '+']

RECURSE = is_true(env('PATH_RECURSE', '0'))
QUIET = is_true(env('QUIET', '0'))
DEBUG = is_true(env('DEBUG', '0'))
VERB_FLAG = False
PATH_DEFAULTS = is_true(env('PATH_DEFAULTS', '1'))
_PATH_DEFAULT_LIST = '~/.local/bin:/snap/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin'
PATH_DEFAULT_LIST: List[Path] = [Path(p.strip()).expanduser().resolve() for p in env('PATH_DEFAULT_LIST', _PATH_DEFAULT_LIST).split(':')]
PATH = env('PATH', env('path', env('Path', ''))).strip()
PATH: List[Path] = [Path(p.strip()).expanduser().resolve() for p in PATH.split(':')]
ERROR_CODE = 127


def _add_paths(plist: List[Path], pathz: List[Union[str, Path]], expanduser=True, resolve=True) -> List[Path]:
    pathz = list(pathz)
    for p in pathz:
        p = p if isinstance(p, Path) else Path(str(p))
        p = p.expanduser() if expanduser else p
        p = p.resolve() if resolve else p
        plist.append(p)
    return plist


def add_paths(plist: List[Path], *pathz: Union[str, Path], expanduser=True, resolve=True) -> List[Path]:
    return _add_paths(plist, pathz, expanduser=expanduser, resolve=resolve)


def _debug(*args, file=sys.stderr, **kwargs):
    if DEBUG:
        print(' [DEBUG] ', *args, file=file, **kwargs)


if PATH_DEFAULTS:
    for pd in PATH_DEFAULT_LIST:
        if pd not in PATH:
            PATH.append(pd)


argx = list(sys.argv)
self_cmd = argx.pop(0)
self_bin = env('SELF_BIN', self_cmd.split('/')[-1])

binlist: List[str] = []
"""
binlist = list of binaries passed on the command line for us to try and find.
"""

if self_bin == 'which': ERROR_CODE = 1

def is_exe(fpath: Union[str, Path]) -> bool:
    try:
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)
    except (PermissionError, FileNotFoundError):
        return False


while len(argx) > 0:
    a = argx.pop(0)
    if len(binlist) > 0: binlist.append(str(a))
    elif a in ['-v', '-V']: VERB_FLAG = True
    elif a in ['-r', '-R']: RECURSE = True
    elif a in ['-q', '-Q']: QUIET = True
    elif a in ['-vv', '-VV', '-dbg', '-debug', '--dbg', '--debug']: DEBUG = True
    elif len(binlist) == 0 and a.startswith('-'): pass
    else: binlist.append(str(a))

SHOULD_EXEC = not VERB_FLAG and self_bin == 'command'

matched_paths = {}
matched_bool = {binlist[0]: False} if SHOULD_EXEC else {k: False for k in binlist}

#for bl in binlist:

class IgnoreFile(Exception):
    pass


def validate_file(file: Union[str, Path], multi=False, known_paths: dict = None, fail=True):
    file = file if isinstance(file, Path) else Path(file)
    try:
        if file.is_dir() or not file.is_file(): 
            _debug("Path {} isn't a file - may be a folder or FIFO etc. - Skipping.".format(str(file)))
            if fail: raise IgnoreFile
            return False

        if not multi and known_paths is not None and str(file.name) in known_paths:
            _debug("Binary name {name} has already been matched to a higher priority path: {mp}".format(
                name=str(file.name), mp=known_paths[str(file.name)])
            )
            if fail: raise IgnoreFile
            return False
    except (PermissionError, FileNotFoundError) as e:
        _debug("Got unexpected error while scanning path '{}'. Reason: {} {}".format(str(file), type(e), str(e)))
        if fail: raise e
        return False
    return True


def find_binaries(
    *names: str, force_tuple=False, skip_none=True, multi=False, find_ext=False, known_paths: dict = None, bin_bool: dict = None
) -> Union[str, Tuple[str, ...]]:
    names: List[str] = list(names)
    found_paths = []
    for pt in PATH:
        _debug("Searching for binaries in path {}.".format(str(pt)))

        if find_ext:
            for nm in names:
                extnm = "{}.*".format(nm)
                globber = pt.glob(nm) if not RECURSE else pt.rglob(nm)
                globber_ext = pt.glob(extnm) if not RECURSE else pt.rglob(extnm)
                for g in globber:
                    if str(g) in found_paths: continue
                    if not validate_file(g, multi=multi, known_paths=known_paths, fail=False): continue
                    found_paths.append(str(g))
                for g in globber_ext:
                    if str(g) in found_paths: continue
                    if not validate_file(g, multi=multi, known_paths=known_paths, fail=False): continue
                    found_paths.append(str(g))
        else:
            globber = pt.glob('*') if not RECURSE else pt.rglob('*')

            for pb in globber:
                pname = None
                # try:
                if not validate_file(pb, multi=multi, known_paths=known_paths, fail=False): continue
                if str(pb.name) in names:
                    _debug("Found binary in path {} which is present in binary list: {}".format(str(pt), str(pb.name)))
                    pname = mt = str(pb)

                    if known_paths is not None and str(pb.name) not in known_paths: known_paths[str(pb.name)] = mt
                    if bin_bool is not None and (str(pb.name) not in bin_bool or bin_bool[str(pb.name)] == False):
                        bin_bool[str(pb.name)] = True
                if pname is None and skip_none: continue
                found_paths.append(pname)
                # except (PermissionError, FileNotFoundError) as e:
                #     _debug("Got unexpected error while scanning path '{}'. Reason: {} {}".format(str(pb), type(e), str(e)))
                # except IgnoreFile:
                #     pass
                # finally:
                #     if pname is None and skip_none: continue
    if not force_tuple and len(found_paths) == 1: return found_paths[0]
    return tuple(found_paths)
            
if SHOULD_EXEC:
    mainbin = find_binaries(binlist[0], force_tuple=True)[0]
    bin_args = binlist[1:]
    if mainbin is None or mainbin == '':
        print("{}: {}: command not found".format(self_cmd, binlist[0]), file=sys.stderr)
        sys.exit(127)
    fargs = [mainbin] + bin_args
    # fargs = shlex.join(bin_args)
    _debug("Running command with subprocess.call: {}".format(fargs))
    popx = subprocess.Popen(fargs, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    if not sys.stdin.isatty():
        rd = sys.stdin.read(128)
        while rd not in [None, False, b'', '']:
            popx.stdin.write(rd.encode('utf-8'))
            rd = sys.stdin.read(128)
        # popx.stdin.write(b"\u0004")
        
        try:
            popx.stdin.flush()
        except Exception as e:
            _debug("Exception while flushing stdin: {} {}".format(type(e), str(e)))
        try:
            popx.stdin.close()
        except Exception as e:
            _debug("Exception while closing stdin: {} {}".format(type(e), str(e)))

    rd = popx.stdout.read(128)
    while rd not in [None, False, b'', '']:
        sys.stdout.write(rd.decode('utf-8'))
        rd = popx.stdout.read(128)
        try:
            sys.stdout.flush()
        except Exception as e:
            _debug("Exception while flushing sys.stdout: {} {}".format(type(e), str(e)))
        try:
            popx.stdout.close()
        except Exception as e:
            _debug("Exception while closing popx stdout: {} {}".format(type(e), str(e)))
    rd = popx.stderr.read(128)
    while rd not in [None, False, b'', '']:
        sys.stderr.write(rd.decode('utf-8'))
        rd = popx.stderr.read(128)
        try:
            sys.stderr.flush()
        except Exception as e:
            _debug("Exception while flushing stderr: {} {}".format(type(e), str(e)))
        try:
            popx.stderr.close()
        except Exception as e:
            _debug("Exception while closing popx stderr: {} {}".format(type(e), str(e)))
    
    code = popx.wait(60 * 60 * 2)
    
    # procres: subprocess.CompletedProcess = subprocess.run(fargs, stdout=subprocess.PIPE, stderr=subprocess.PIPE, stdin=subprocess.PIPE)
    # code = subprocess.call(shlex.join(bin_args), bufsize=32, executable=mainbin, stdout=subprocess.STDOUT)
    # sys.exit(code)
    # sys.exit(procres.returncode)
    sys.exit(code)


if self_bin == 'whereis':
    add_paths(
        PATH, *['/usr/share/man/man{}'.format(i) for i in range(1,9)], '/etc', '/opt'
    )
    RECURSE = True
    for bl in binlist:
        flist = find_binaries(bl, force_tuple=True, multi=True, find_ext=True)
        print("{}: {}".format(bl, ' '.join(flist)))
    sys.exit(0)

find_binaries(*binlist, known_paths=matched_paths, bin_bool=matched_bool)

if len(matched_paths) == 0:
    if self_bin == 'command':
        print("{}: {}: command not found".format(self_cmd, binlist[0]), file=sys.stderr)
    elif self_bin == 'which':
        if not QUIET: print("{}: command not found".format(binlist[0]))
    else:
        print("{}: ERROR - Binary '{}' was not found in search path. command not found".format(self_cmd, binlist[0]), file=sys.stderr)
    sys.exit(ERROR_CODE)

for bl in binlist:
    if bl in matched_paths:
        mt = matched_paths[bl]
        if not QUIET:
            print(str(mt))
        _debug("Bin List item '{}' was matched to path: {}".format(bl, mt))
    elif not QUIET and len(binlist) > 1:
        print("-")
        


_debug("Matched paths: {}".format(matched_paths))
_debug("Matched bools: {}".format(matched_bool))
sys.exit(0 if len(matched_bool) >= len(binlist) and all(list(matched_bool.values())) else 1)


