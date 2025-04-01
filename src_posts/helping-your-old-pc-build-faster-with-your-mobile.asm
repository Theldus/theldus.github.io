%include "macros.inc"
SET_POST_TITLE Helping your 'old' PC build faster with your mobile device
SET_POST_DNBR  1
SET_POST_DATES 2022-07-06, 2025-03-31

%include "header.inc"

%define LNK_T3200_GB \
    "https://browser.geekbench.com/v5/cpu/15805478"
%define LNK_G7PLUS_GB \
    "https://browser.geekbench.com/v5/cpu/15738237"
%define LNK_TERMUX "https://termux.dev/"

PS
It all happened when I decided to run Geekbench 5 on my phone: surprisingly the
single-core performance matched my 'old'¹ LINK(LNK_T3200_GB, Pentium T3200)
and LINK(LNK_G7PLUS_GB, surpassed) it in multicore. Since I have been having fun
with distcc for the last few days, I asked myself: I(Can my phone really help \
my old laptop build faster? nah, hard to believe... but lets try)'.
PE

PS
Without further ado: YES. Not only can my phone be faster, but it can
significantly help in the build process, I believe the results below speak for
themselves:
PE

IMG_L "https://asciinema.org/a/506149.svg", \
    Building Git (#30cc8d0) on a Pentium T3200 - 8m30s, \
    "https://asciinema.org/a/506149"

IMG_L "https://asciinema.org/a/506150.svg", \
    Building Git (#30cc8d0) on a Pentium T3200 (2x 2.0 GHz) + Snapdragon 636 \
    (4x1.8 + 4x1.6 GHz), \
    "https://asciinema.org/a/506150"

PS B(My environment:) PE
UL_S
    LI_S Pentium Dual Core T3200 (2x 2.0 GHz) w/ Slackware 15 and Clang 13.0.0 LI_E
    LI_S Motorola G7 Plus (Snapdragon 636, 4x1.8 GHz + 4x1.6 GHz) running
    Android 10, Termux v0.118.0 and Clang 14.0.6. LI_E
    LI_S distcc in pump mode LI_E
UL_E

PS_N
Although my laptop is 13 years old, it's still fully capable of running Slackware
15 with XFCE decently, so I can't see it as 'old' or 'outdated': although it's
not my main PC anymore, it's still able to do basic everyday things. This entire
article is dedicated to people who have a similar HW and who might be able to
benefit from it in some way.
PE

S(How to do it?)
PS
(If you are already happy with the results and have no intention of reproducing
this, you can stop here)
PE

PS
Well, all you need is an old PC and a smartphone that supports LINK(LNK_TERMUX,\
Termux). (Preferably, it's interesting to run Geekbench on both sides to get an
initial idea: if your phone is *much* slower than your PC, there probably won't
be any performance gains and may even slow down the build process, given the
overhead that distcc adds to the build process.)
PE

PS
Surprisingly there aren't many things to do, the most difficult part Termux
already does for you, but below are the instructions to be done on your phone
and on your PC.
PE

SSS(1 - Install and configure: Clang, distcc and OpenSSH on your phone:)

PS Assuming Termux is already installed, install and configure these packages
as below: PE

BC_S
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
BC_E

PS
B(Note: ) Steps 1e) and 1f) are only necessary if you want to copy files to mobile using
SSH. If you have/want to use other means, disregard this (and don't install
OpenSSH).
PE

SSS(2 - On your PC, install distcc and move the system headers to your phone)

BC_S
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
BC_E

PS B(Note 1:) Step 2 is only needed if you want to use distcc in pump mode (highly recommended!). PE

PS B(Note 2:) If you chose not to install OpenSSH, copy host_include.tar.gz to your Termux $HOME by other means, such as accessing your downloads folder via $HOME/storage/downloads. PE

PS B(Note 3:) I'm assuming here that your PC I(already) have all the tools to
build stuff I(without) distcc (Clang, Make and etc). PE

SSS(3 - On your phone, 'replace' the Termux system header with the new one)

PS
Now that everything is in place, the only thing that needs to be done is to 'replace' the Termux headers with the new ones:
PE

BC_S
$ cd ~/

# Backup your original include folder
$ mv $PREFIX/include $PREFIX/android_include

# Extract your brand new include to the proper place
$ tar xf host_include.tar.gz
$ mv include $PREFIX/include
BC_E

SSS(Ready to run, go!)
PS Now everything should be configured and ready to run. Distcc only requires it
to be invoked instead of your traditional CC and CXX. PE

BC_S
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
BC_E

PS and that's it, distcc should start the 'include-server' and distribute the
jobs among the hosts on the network. To see the current status between hosts,
you can BC(watch -n0.5 distccmon-text). PE

%define LNK_FAQ "https://www.distcc.org/faq.html"

S(Remarks)
UL_S

LI_S As you can see, I didn't use the same Clang version between hosts. This
isn't exactly mandatory and can compile all the programs I've tested without
problems, however, it's interesting to try not to use versions that are too far
apart: new (or old) code can produce build errors on very new or old compilers.
This is also discussed in the distcc LINK(LNK_FAQ, FAQ). LI_E

LI_S I I(strongly) recommend using 'pump' mode: in my (little) experience with
distcc, if your main PC (the one that invokes make) is slow, it ends up getting
heavily overloaded preprocessing each header before sending it to the other
hosts. Using pump mode significantly decreases overhead on the main PC and allows
for better CPU usage on each host. In my tests, laptop+phone B(without) pump
mode managed to compile in 6 minutes, instead of 2m9s (with pump). LI_E

LI_S This setup is unable to generate x86_64 B(executable) binaries from Android,
but only x86_64 object files, thats is exactly what distcc needs. For the linking
process to work, the x86_64 libraries must also be present. Which is not
necessary for distcc. LI_E

UL_E

S(Final thoughts)
PS I have to say: I'm I(very) impressed with the results. I didn't expect my
phone to be faster than my old laptop, let alone that it could significantly help
the builds with distcc. PE

PS Speaking of feasibility, I think using distcc with your smartphone is really
viable and that it can really help people with 'older' hardware. Of course, I
don't expect you to use your phone to install every package on Gentoo! (please
don't!). But it seems feasible to me for 'fast' builds (something around 30
minutes without distcc), after all: if people usually spend several hours playing
games on mobile (which use CPU + GPU intensively), what are a few minutes helping
your poor PC ? PE

S(Useful links)
%define LNK_DCC_SITE "https://www.distcc.org/"
%define LNK_DCC_MAN  "https://linux.die.net/man/1/distcc"
%define LNK_DCC_WIKI "https://wiki.archlinux.org/title/Distcc"
%define LNK_TERMUX   "https://termux.dev/"

PS LINK(LNK_DCC_SITE, distcc website) PE
PS LINK(LNK_DCC_MAN, distcc man page) PE
PS LINK(LNK_DCC_WIKI, distcc Arch Wiki) PE
PS LINK(LNK_TERMUX, Termux) PE



%include "footer.inc"
