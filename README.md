# Someguy's Scripts

This is a collection of tools, config files, and scripts which were designed by myself (@someguy123)
to make my life easier. You may or may not find something useful in here.

# License

Someguy's scripts are licensed under the **GNU AGPLv3**. Please be sure to attribute @someguy123 if
making your own modifications of this. The majority of code has been authored by myself.

See the file `LICENSE` for more information.

Parts of [Oh-My-Zsh](https://github.com/robbyrussell/oh-my-zsh) have been used in this project, and as such I've included
their license file (MIT) at `OMZ_LICENSE.txt`. This does not affect the license of this project, which is the **GNU AGPLv3**.

# Server Provisioner (core.sh)

![Screenshot of Menu after install](https://i.imgur.com/zdaW4xs.png)

Some people like Ansible, some people like Chef, I personally put more faith in good ol' bash scripts.

The file `core.sh` is a tool to help provision new servers, which can:

 - Install various useful packages such as `htop`, `unzip`, `fail2ban` and more. (no more "ugh, why isn't htop installed")
 - Installing configuration files such as `.zshrc`, `.vimrc` and `.tmux.conf` (don't worry it won't overwrite anything without asking first)
 - Installing [Oh-My-Zsh](https://github.com/robbyrussell/oh-my-zsh)
 - Setting the default shell to zsh
 - Randomizing the SSH port
 - Turning off SSH `PasswordAuthentication`

It uses an interactive menu, so you can just run `./core.sh` and select what you want to do.

The script was designed for Ubuntu 16.04 and 18.04, it may or may not work on other debian-based distributions assuming
you adjust the `INSTALL_PKGS`.

You can override INSTALL_PKGS at runtime, like so:

```
export INSTALL_PKGS=(nginx mysql-server php)
./core.sh
```

# Docker

A basic `Dockerfile` is included for testing out the scripts with [Docker](https://www.docker.com/).

Mostly useful for testing out the scripts inside of an instant Ubuntu 18.04 lightweight VM, so that
you can verify it's not going to harm your systems.

**Run in docker:**

```
git clone https://github.com/someguy123/someguy-scripts
cd someguy-scripts
docker build -t sgscripts .
docker run -it sgscripts
```

# Various shell functions and aliases (zsh_files + dotfiles/zshrc)

Some of the files may or may not work with Bash, but I make no guarantees. 
They were all developed and tested on `zsh` on Mac OSX.

You can pick and choose files from `zsh_file` as needed, just `source` them in your `.zshrc`.

It's strongly recommended to load `colors.zsh` and `gnusafe.zsh` for the files to work.

The example `.zshrc` in `dotfiles` (which is installed by the server provisioner) shows the correct order to load them.

### Colours (colors.zsh)

This is a small script containing terminal colour variables, such as `$RED` and `$BLUE`.

They're used extensively by the other scripts, so be sure to `source` it!

### SSH Tools (ssh.zsh)

**ssh-reset** - Remove a known host from your known_hosts file

Simply specify the IP or hostname, depending on how you connect to it.

It makes a timestamped backup in /tmp in-case something goes wrong. To help detect problems
it prints the number of lines removed, and will abort if it detects the backup copy failed.

(yes I know ssh-keygen has this, but it doesn't on OSX)

```
$ ssh-reset 1.2.3.4
Backuping up /Users/someguy/.ssh/known_hosts to /tmp/known_hosts-2018-10-06_(00-09-36)+0100
/Users/someguy/.ssh/known_hosts -> /tmp/known_hosts-2018-10-06_(00-09-36)+0100
Removing host 1.2.3.4
Lines removed: 1
Backup file @ /tmp/known_hosts-2018-10-06_(00-09-36)+0100
```

**await-ssh** - Tired of typing ssh over and over while waiting for the ssh daemon to wake up?

`await-ssh` will use `ping -o` to wait until the server comes back online, and then try to SSH in.

**Warning: `ping -o` only works on Mac OSX (and maybe some BSDs), there is no Linux equivelent switch.**

**Pull requests to make this work on both Linux and OSX would be appreciated**

It's compatible with hosts kept in `~/.ssh/config`, no need to type the full user@host if you have it in your config.

If `ssh` returns a non-zero code, it will do another ping check, and retry again when it's back up.

Note that this disables `StrictHostKeyChecking` and sets the host key file to `/dev/null`, as I most
frequently use this when (re-)installing a server. You can always edit the file for your own needs :)

```
$ await-ssh my-server
Waiting for root@1.2.3.4 on port 1234 to come back online
Host 1.2.3.4 appears online. Waiting a few seconds before connecting
The authenticity of host '[1.2.3.4]:1234 ([1.2.3.4]:1234)' can't be established.
ECDSA key fingerprint is SHA256:abcdef12345abcd12345.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '[1.2.3.4]:1234' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 16.04.5 LTS (GNU/Linux 4.4.0-109-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage
Last login: Thu Oct  4 17:45:53 2018 from 2.3.4.5
root@my-server ~ #
```

### GnuSafe - for cross compatible shell scripts (gnusafe.zsh)

**gnusafe** - An extremely useful function for making cross-compatible shell scripts for BSD and Linux

Use it in your scripts as simple as `gnusafe || return 1 || exit 1`

 - Works with both bash and zsh
 - Ability to bypass the detection if you know grep/sed/awk are all GNU by doing `export FORCE_UNIX=1`
 - Detects if the user is running Linux or not. If not, assumes that they may be on some sort-of BSD such as OSX. (there is no reliable way of detecting BSD tools vs GNU tools other than `uname -s` != `Linux`)
 - If they are on Linux
   - Alias `gsed`, `gawk` and `ggrep` to the normal versions, to ensure any usage of those work as expected. 
   - It will also generate an alias for `egrep` if it's not found.

 - If not on Linux:
   - Attempts to detect GNU prefixed tools, such as `gsed`, `gawk`, and `ggrep`. 
     - If they're found, it will quietly alias grep, awk, and sed to the GNU versions. A shell trap is set up to unalias on exit, preventing problems for the user after the script is done.
     - If they're not found, it will spit out a red error message, informing the user on how to resolve this, including homebrew installation instructions for OSX users.

![GnuSafe Example](https://i.imgur.com/yHDltDx.png)

### Better Rsync (rsync.zsh)

**brsync** - No need to type `rsync -av --progress` over and over again, nor the awkward `--rsh 'ssh -p 1234'` for servers on a non-default SSH port.

Example:

```
$ brsync port 1234 root@1.2.3.4:/myfolder localfolder
```

This is equivelent to:

```
$ rsync --rsh="ssh -p 1234" -av --progress root@1.2.3.4:/myfolder localfolder
```

Works for local files too:

```
➜  someguy-scripts $ brsync zsh_files/ /Users/someguy/.zsh_files
building file list ...
8 files to consider
./
gnusafe.zsh
        3764 100%    0.00kB/s    0:00:00 (xfer#1, to-check=5/8)

sent 4028 bytes  received 48 bytes  8152.00 bytes/sec
total size is 16965  speedup is 4.16
➜  someguy-scripts $
```

### OSX Specific (osx.zsh)

**service** - Easier access to `brew services`, designed to match Linux's `service` command, and works with the name/action in any order. Also added `service status`, because I could never remember `brew services list`

Use like you would on Linux:

```
$ service status
Name     Status  User  Plist
bind     started root  /Library/LaunchDaemons/homebrew.mxcl.bind.plist
dnsmasq  started root  /Library/LaunchDaemons/homebrew.mxcl.dnsmasq.plist
fail2ban started someguy /Users/someguy/Library/LaunchAgents/homebrew.mxcl.fail2ban.plist
mysql    stopped
openvpn  stopped
$ service mysql start
==> Successfully started `mysql` (label: homebrew.mxcl.mysql)
$ service stop mysql
Stopping `mysql`... (might take a while)
==> Successfully stopped `mysql` (label: homebrew.mxcl.mysql)
$
```

No more trying to remember whether `start` goes first, or after the service. It Just Works™.

**crc32** - OSX has a built in checksum utility for CRC sums called `cksum`, but unfortunately it returns the hash in decimal format. This small function will let you see the hexadecimal hash like you would expect.

```
Usage:
  $ echo hello > test.txt
Get hash, length (same as wc -c), filename:
  $ crc32 test.txt
  363a3020 6 test.txt
Get just the hash by itself:
  $ crc32 test.txt | awk '{ print $1 }'
  363a3020
```

**ip** - A very small function, simply because you can't alias `ip` to `ifconfig` without it throwing errors.

This is another helper to ease the context switching between Linux and OSX, so that `ip addr` will run `ifconfig`.

### ZSH Reload Alert (zshreload.zsh)

As you can tell by the amount of shell scripting in this repository, I edit my zshrc a lot, to the point where I had
to split it into several files (the zsh_files folder).

This can be frustrating though, as I sometimes forget to reload after I've edited it.

Using the precmd/preexec hooks, I intercepted the commands I run, so that I get prompted to reload zshrc after
editing it.

![](https://i.imgur.com/eHogjKG.png)

There's also an alias `rldzsh` to save typing `source ~/.zshrc`.

In `dotfiles/zshrc` there is also an alias `zshrc` to open `vim ~/.zshrc`.

### Steem RPC Functions (steem.zsh)

While not useful to most people, I spend a lot of time developing for [Steem](https://www.steem.io). I also spend a
lot of time in the terminal. So, to make debugging and generally querying RPC nodes much easier, I wrote several 
functions to make querying them a breeze.

The default RPC server can be overriden, e.g. `export DEFAULT_STM_RPC="https://api.steemit.com"`, but all commands
allow you to specify an RPC server manually anyway.

`rpc-rq` - For general RPC requests. Extremely flexible.

```
$ rpc-rq get_dynamic_global_properties
```

**Single argument**: host=default, method=$1, params=[]

```
$ rpc-rq https://steemd.privex.io get_dynamic_global_properties
$ rpc-rq get_dynamic_global_properties '[]'
```

**Two arguments**: Detects if first arg is host.

 - If host: host=$1, method=$2, params=[]
 - If not:  host=default, method=$1, params=$2

```
$ rpc-rq https://steemd.privex.io get_dynamic_global_properties '[]'
```

**Three args**: host=$1 method=$2 params=$3
