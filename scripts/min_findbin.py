#!/usr/bin/env python3
#################################################################################################################
# findbin.py - This is a dependency-free python3.x script, which is designed to work as a drop-in shim for
# 'command', 'command -v', 'which', and 'whereis'.
#
# This script is part of Someguy's Scripts - a toolkit designed for provisioning *nix systems the way that
# Someguy123 likes 'em :)
#
# Official Someguy's Scripts repo: https://github.com/Someguy123/someguy-scripts 
#################################################################################################################
_G='{}: {}: command not found'
_F='command'
_E='which'
_D='utf-8'
_C=None
_B=True
_A=False
from pathlib import Path
from os import getenv as env
from typing import Union,Optional,List,Tuple,Dict
import sys,os,subprocess,shlex
def is_true(x):return str(x).lower()in['1','true','yes','t','y','tru','+']
RECURSE=is_true(env('PATH_RECURSE','0'))
QUIET=is_true(env('QUIET','0'))
DEBUG=is_true(env('DEBUG','0'))
VERB_FLAG=_A
PATH_DEFAULTS=is_true(env('PATH_DEFAULTS','1'))
_PATH_DEFAULT_LIST='~/.local/bin:/snap/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin'
PATH_DEFAULT_LIST=[Path(A.strip()).expanduser().resolve()for A in env('PATH_DEFAULT_LIST',_PATH_DEFAULT_LIST).split(':')]
PATH=env('PATH',env('path',env('Path',''))).strip()
PATH=[Path(A.strip()).expanduser().resolve()for A in PATH.split(':')]
ERROR_CODE=127
def _add_paths(plist,pathz,expanduser=_B,resolve=_B):
	C=plist;B=pathz;B=list(B)
	for A in B:A=A if isinstance(A,Path)else Path(str(A));A=A.expanduser()if expanduser else A;A=A.resolve()if resolve else A;C.append(A)
	return C
def add_paths(plist,*A,expanduser=_B,resolve=_B):return _add_paths(plist,A,expanduser=expanduser,resolve=resolve)
def _debug(*A,file=sys.stderr,**B):
	if DEBUG:print(' [DEBUG] ',*A,file=file,**B)
if PATH_DEFAULTS:
	for pd in PATH_DEFAULT_LIST:
		if pd not in PATH:PATH.append(pd)
argx=list(sys.argv)
self_cmd=argx.pop(0)
self_bin=env('SELF_BIN',self_cmd.split('/')[-1])
binlist=[]
'\nbinlist = list of binaries passed on the command line for us to try and find.\n'
if self_bin==_E:ERROR_CODE=1
def is_exe(fpath):
	A=fpath
	try:return os.path.isfile(A)and os.access(A,os.X_OK)
	except (PermissionError,FileNotFoundError):return _A
while len(argx)>0:
	a=argx.pop(0)
	if len(binlist)>0:binlist.append(str(a))
	elif a in['-v','-V']:VERB_FLAG=_B
	elif a in['-r','-R']:RECURSE=_B
	elif a in['-q','-Q']:QUIET=_B
	elif a in['-vv','-VV','-dbg','-debug','--dbg','--debug']:DEBUG=_B
	elif len(binlist)==0 and a.startswith('-'):0
	else:binlist.append(str(a))
SHOULD_EXEC=not VERB_FLAG and self_bin==_F
matched_paths={}
matched_bool={binlist[0]:_A}if SHOULD_EXEC else{A:_A for A in binlist}
class IgnoreFile(Exception):0
def validate_file(file,multi=_A,known_paths=_C,fail=_B):
	C=fail;B=known_paths;A=file;A=A if isinstance(A,Path)else Path(A)
	try:
		if A.is_dir()or not A.is_file():
			_debug("Path {} isn't a file - may be a folder or FIFO etc. - Skipping.".format(str(A)))
			if C:raise IgnoreFile
			return _A
		if not multi and B is not _C and str(A.name)in B:
			_debug('Binary name {name} has already been matched to a higher priority path: {mp}'.format(name=str(A.name),mp=B[str(A.name)]))
			if C:raise IgnoreFile
			return _A
	except (PermissionError,FileNotFoundError)as D:
		_debug("Got unexpected error while scanning path '{}'. Reason: {} {}".format(str(A),type(D),str(D)))
		if C:raise D
		return _A
	return _B
def find_binaries(*F,force_tuple=_A,skip_none=_B,multi=_A,find_ext=_A,known_paths=_C,bin_bool=_C):
	O='*';H=multi;G=bin_bool;E=known_paths;F=list(F);B=[]
	for C in PATH:
		_debug('Searching for binaries in path {}.'.format(str(C)))
		if find_ext:
			for I in F:
				L='{}.*'.format(I);J=C.glob(I)if not RECURSE else C.rglob(I);M=C.glob(L)if not RECURSE else C.rglob(L)
				for D in J:
					if str(D)in B:continue
					if not validate_file(D,multi=H,known_paths=E,fail=_A):continue
					B.append(str(D))
				for D in M:
					if str(D)in B:continue
					if not validate_file(D,multi=H,known_paths=E,fail=_A):continue
					B.append(str(D))
		else:
			J=C.glob(O)if not RECURSE else C.rglob(O)
			for A in J:
				K=_C
				if not validate_file(A,multi=H,known_paths=E,fail=_A):continue
				if str(A.name)in F:
					_debug('Found binary in path {} which is present in binary list: {}'.format(str(C),str(A.name)));K=N=str(A)
					if E is not _C and str(A.name)not in E:E[str(A.name)]=N
					if G is not _C and(str(A.name)not in G or G[str(A.name)]==_A):G[str(A.name)]=_B
				if K is _C and skip_none:continue
				B.append(K)
	if not force_tuple and len(B)==1:return B[0]
	return tuple(B)
if SHOULD_EXEC:
	mainbin=find_binaries(binlist[0],force_tuple=_B)[0];bin_args=binlist[1:]
	if mainbin is _C or mainbin=='':print(_G.format(self_cmd,binlist[0]),file=sys.stderr);sys.exit(127)
	fargs=[mainbin]+bin_args;_debug('Running command with subprocess.call: {}'.format(fargs));popx=subprocess.Popen(fargs,stdout=subprocess.PIPE,stderr=subprocess.PIPE,stdin=subprocess.PIPE)
	if not sys.stdin.isatty():
		rd=sys.stdin.read(128)
		while rd not in[_C,_A,b'','']:popx.stdin.write(rd.encode(_D));rd=sys.stdin.read(128)
		try:popx.stdin.flush()
		except Exception as e:_debug('Exception while flushing stdin: {} {}'.format(type(e),str(e)))
		try:popx.stdin.close()
		except Exception as e:_debug('Exception while closing stdin: {} {}'.format(type(e),str(e)))
	rd=popx.stdout.read(128)
	while rd not in[_C,_A,b'','']:
		sys.stdout.write(rd.decode(_D));rd=popx.stdout.read(128)
		try:sys.stdout.flush()
		except Exception as e:_debug('Exception while flushing sys.stdout: {} {}'.format(type(e),str(e)))
		try:popx.stdout.close()
		except Exception as e:_debug('Exception while closing popx stdout: {} {}'.format(type(e),str(e)))
	rd=popx.stderr.read(128)
	while rd not in[_C,_A,b'','']:
		sys.stderr.write(rd.decode(_D));rd=popx.stderr.read(128)
		try:sys.stderr.flush()
		except Exception as e:_debug('Exception while flushing stderr: {} {}'.format(type(e),str(e)))
		try:popx.stderr.close()
		except Exception as e:_debug('Exception while closing popx stderr: {} {}'.format(type(e),str(e)))
	code=popx.wait(60*60*2);sys.exit(code)
if self_bin=='whereis':
	add_paths(PATH,*['/usr/share/man/man{}'.format(A)for A in range(1,9)],'/etc','/opt');RECURSE=_B
	for bl in binlist:flist=find_binaries(bl,force_tuple=_B,multi=_B,find_ext=_B);print('{}: {}'.format(bl,' '.join(flist)))
	sys.exit(0)
find_binaries(*binlist,known_paths=matched_paths,bin_bool=matched_bool)
if len(matched_paths)==0:
	if self_bin==_F:print(_G.format(self_cmd,binlist[0]),file=sys.stderr)
	elif self_bin==_E:
		if not QUIET:print('{}: command not found'.format(binlist[0]))
	else:print("{}: ERROR - Binary '{}' was not found in search path. command not found".format(self_cmd,binlist[0]),file=sys.stderr)
	sys.exit(ERROR_CODE)
for bl in binlist:
	if bl in matched_paths:
		mt=matched_paths[bl]
		if not QUIET:print(str(mt))
		_debug("Bin List item '{}' was matched to path: {}".format(bl,mt))
	elif not QUIET and len(binlist)>1:print('-')
_debug('Matched paths: {}'.format(matched_paths))
_debug('Matched bools: {}'.format(matched_bool))
sys.exit(0 if len(matched_bool)>=len(binlist)and all(list(matched_bool.values()))else 1)
