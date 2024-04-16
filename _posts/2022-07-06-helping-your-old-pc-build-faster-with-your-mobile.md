---
title: Helping your 'old' PC build faster with your mobile device 
author: theldus
date: 2022-07-06 12:17:00 -0300
categories: [Linux, Performance]
tags: [linux, performance]
render_with_liquid: false
---

It all happened when I decided to run Geekbench 5 on my phone: surprisingly the single-core performance matched my 'old'¹ [Pentium T3200](https://browser.geekbench.com/v5/cpu/15805478) and [surpassed](https://browser.geekbench.com/v5/cpu/15738237) it in multicore. Since I've been having fun with distcc for the last few days, I asked myself: '_Can my phone really help my old laptop build faster? nah, hard to believe... but let's try_'.

Without further ado: YES. Not only can my phone be faster, but it can significantly help in the build process, I believe the results below speak for themselves:

[![asciicast](https://asciinema.org/a/506149.svg)](https://asciinema.org/a/506149)
_Building Git (#30cc8d0) on a Pentium T3200, 8m30s_

[![asciicast](https://asciinema.org/a/506150.svg)](https://asciinema.org/a/506150)
_Building Git (#30cc8d0) on a Pentium T3200 (2x 2.0 GHz)+ Snapdragon 636 (4x1.8 + 4x1.6 GHz), 2m9s_

My environment:
- Pentium Dual Core T3200 (2x 2.0 GHz) w/ Slackware 15 and Clang 13.0.0
- Motorola G7 Plus (Snapdragon 636, 4x1.8 GHz + 4x1.6 GHz) running Android 10, Termux v0.118.0 and Clang 14.0.6.
- distcc in pump mode

**Note:**
1: Although my laptop is 13 years old, it's still fully capable of running Slackware 15 with XFCE decently, so I can't see it as 'old' or 'outdated': although it's not my main PC anymore, it's still able to do basic everyday things. This entire article is dedicated to people who have a similar HW and who might be able to benefit from it in some way.

# How to do it?
(If you are already happy with the results and have no intention of reproducing this, you can stop here)

Well, all you need is an old PC and a smartphone that supports [Termux](https://termux.dev/). (Preferably, it's interesting to run Geekbench on both sides to get an initial idea: if your phone is *much* slower than your PC, there probably won't be any performance gains and may even slow down the build process, given the overhead that distcc adds to the build process.)

Surprisingly there aren't many things to do, the most difficult part Termux already does for you, but below are the instructions to be done on your phone and on your PC.

## 1) Install and configure Clang, distcc and OpenSSH on your smartphone:
Assuming Termux is already installed, install and configure these packages as below:
```bash
# Phone

# 1a) Install them
$ pkg install distcc clang openssh

#
# 1b) Configure distcc symlinks:
# Distcc needs a 'whitelist' of trusted compilers it can run on...
# By default this is not set. Let's do this by creating symlinks
# from the compilers to distcc.
#
$ mkdir $PREFIX/lib/distcc
$ cd $PREFIX/lib/distcc
$ ln -sf ../../bin/distcc c++
$ ln -sf ../../bin/distcc c89
$ ln -sf ../../bin/distcc c99
$ ln -sf ../../bin/distcc cc
$ ln -sf ../../bin/distcc clang
$ ln -sf ../../bin/distcc clang++
$ ln -sf ../../bin/distcc g++
$ ln -sf ../../bin/distcc gcc

#
# 1c) Configure Clang to build for x86_64
#
# As Clang can support several targets with a single installation, there
# is no need to compile a new GCC or Clang for your Android, the Clang
# provided by Termux is enough (and this helps us immensely...
# Cross-Compiling is laborious, time consuming and easily error prone).
#
# We do this by tricking distcc: create a file called 'clang' with execute
# permissions in your Termux $HOME, inside it set the target to x86_64,
# something like:
#
$ cd $HOME
$ echo '#!/data/data/com.termux/files/usr/bin/bash' > clang
$ echo '$PREFIX/bin/clang --target=x86_64-linux-gnu "$@"' >> clang
$ chmod +x clang
$ export PATH=$PWD:$PATH

# 1d) Launch distcc daemon
$ distccd --daemon --allow <your-pc-local-ip> --log-file dist.log

# 1e) Configure a password for OpenSSH login
$ passwd
New password:
Retype new password:
New password was successfully set.

# 1f) Start sshd daemon (stop with: pkill sshd)
$ sshd
```
**Note:** Steps 1e) and 1f) are only necessary if you want to copy files to mobile using SSH. If you have/want to use other means, disregard this (and don't install OpenSSH).

## 2) On your PC, install distcc and move the system headers to your phone
```bash
#
# 2a) Install distcc:
# On Debian-like distros:
#
$ sudo apt install distcc

# 2b) Run distcc daemon
$ distccd --daemon --allow <your-phone-local-ip> --log-file dist.log

#
# 2c) Get the host headers and copy them to your smartphone
# (this can be skipped if you do not want to use pump mode!)
#
# Here's the trickiest part of all: although your phone clang's can
# generate object files for x86_64, it doesn't have the headers of
# an x86_64 environment. Also, your phone needs to have all headers
# for all dependencies to be built as well.
#
# That's why many people end up using Docker or similar solutions, to
# standardize as best as possible all the hosts involved. Here we are
# going to cheat: just copy all the headers from your PC (mine ~480MB
# unpacked) to your phone and it will automagically have the x86_64
# headers _and_ the headers of all the dependencies involved ;-).
#
$ cd ~/
$ tar cfz host_include.tar.gz /usr/include
$ scp -P 8022 host_include.tar.gz user@<your-phone-local-ip>:~/
```

**Note 1:** Step 2 is only needed if you want to use distcc in pump mode (highly recommended!).

**Note 2:** If you chose not to install OpenSSH, copy host_include.tar.gz to your Termux $HOME by other means, such as accessing your downloads folder via $HOME/storage/downloads.

**Note 3:** I'm assuming here that your PC _already_ have all the tools to build stuff _without_ distcc (Clang, Make and etc).

## 3) On your phone, 'replace' the Termux system header with the new one
Now that everything is in place, the only thing that needs to be done is to 'replace' the Termux headers with the new ones:
```bash
$ cd ~/

# Backup your original include folder
$ mv $PREFIX/include $PREFIX/android_include

# Extract your brand new include to the proper place
$ tar xf host_include.tar.gz
$ mv include $PREFIX/include
```

## Ready to run, go!
Now everything should be configured and ready to run. Distcc only requires it to be invoked instead of your traditional CC and CXX.

To build Git using distcc (as illustrated in asciinema at the beginning):
```bash
# PC:
#
# Clone Git repo
$ git clone https://github.com/git/git.git
$ cd git/

#
# Configure the distcc environment variable, saying the IPs and amount
# of jobs that each one will run, like:
#   export DISTCC_HOSTS=192.168.0.5/2,cpp,lzo 192.168.0.6/8,cpp,lzo"
#
# Will instruct distcc to use 2 hosts:
# - 192.168.0.5 with 2 cores
# - 192.168.0.6 with 8 cores
# the number of hosts can be arbitrarily long. The order of the IPs
# specifies the priority distcc will give to them.
#
$ export DISTCC_HOSTS=<ip-address-your-pc>/<num-cores>,cpp,lzo <ip-address-your-phone>/<num-cores>,cpp,lzo

# Build
$ time pump make -j<total-cores> CC="distcc clang"
```
and that's it, distcc should start the 'include-server' and distribute the jobs among the hosts on the network. To see the current status between hosts, you can `watch -n0.5 distccmon-text`.

# Remarks
- As you can see, I didn't use the same Clang version between hosts. This isn't exactly mandatory and can compile all the programs I've tested without problems, however, it's interesting to try not to use versions that are too far apart: new (or old) code can produce build errors on very new or old compilers. This is also discussed in the distcc [FAQ](https://www.distcc.org/faq.html).

- I _strongly_ recommend using 'pump' mode: in my (little) experience with distcc, if your main PC (the one that invokes make) is slow, it ends up getting heavily overloaded preprocessing each header before sending it to the other hosts. Using pump mode significantly decreases overhead on the main PC and allows for better CPU usage on each host. In my tests, laptop+phone __without__ pump mode managed to compile in 6 minutes, instead of 2m9s (with pump).

- This setup is unable to generate x86_64 __executable__ binaries from Android, but only x86_64 object files, thats is exactly what distcc needs. For the linking process to work, the x86_64 libraries must also be present. Which is not necessary for distcc.

# Final thoughts
I have to say: I'm *very* impressed with the results. I didn't expect my phone to be faster than my old laptop, let alone that it could significantly help the builds with distcc.

Speaking of feasibility, I think using distcc with your smartphone is really viable and that it can really help people with 'older' hardware. Of course, I don't expect you to use your phone to install every package on Gentoo! (please don't!). But it seems feasible to me for 'fast' builds (something around 30 minutes without distcc), after all: if people usually spend several hours playing games on mobile (which use CPU + GPU intensively), what are a few minutes helping your poor PC ?

# Useful links
[distcc website](https://www.distcc.org/)

[distcc man page](https://linux.die.net/man/1/distcc)

[distcc Arch Wiki](https://wiki.archlinux.org/title/Distcc)

[Termux](https://termux.dev/)
