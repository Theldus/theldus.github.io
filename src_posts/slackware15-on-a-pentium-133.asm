%include "macros.inc"
SET_POST_TITLE Slackware 15 on a Pentium 133 MHz (32MB of RAM)
SET_POST_DNBR  1
SET_POST_DATES 2023-01-15, 2025-03-24

%include "header.inc"

%define LNK_INIT \
    "https://gist.github.com/Theldus/9825bc2ad9c4aee299cd312f956ff8ce"
%define LNK_CONFIG \
    "https://gist.github.com/Theldus/2b4f7ac6d5245f126df80a86897327e1"
%define LNK_DIFF \
    "https://gist.github.com/Theldus/4493412cc953a0a72c6a92534406af05"

IMG "/assets/img/slack15p133.png", \
    Slackware running on Pentium 133 MHz

S Introduction
PS
This mini-howto is intended to briefly address what was done in the video above:
running Slackware 15.0, a recent Linux distro, on an old hw, from the 90s.
PE

PS_I
If you have 64MB of RAM or more, you can skip this entire tutorial,
Slackware 15 works out-of-the-box. If you have less than that, move on.
PE

SS Taking things out
PS
There are two major issues with booting a recent kernel in an environment with
32MB of RAM (and by that I mean any distro): initrd and kernel.
PE

SSS INITRD
PS
INITRD is supposedly a mini-version of your operating system, or at least the
bare minimum needed for the rest of your system to load; you can think of it as
a high-level bootloader.
PE

PS
The problem with Slackware here is that its INITRD tries to do too much: it
brings a non-static Busybox (and with it also the dynamic libraries it depends
on), plus a set of tools that arent really necessary for
most users: such as LUKS, btrfs, RAID and etc.
PE

PS
With that in mind, we can do the following:
PE

UL_S
    LI_S Put a static Busybox (preferably based on Musl) LI_E
    LI_S Remove all shared libraries from initrd LI_E
    LI_S Remove all executables that are different from Busybox, we really
        dont need them! LI_E
    LI_S Replace your 'init' script with LINK(LNK_INIT, this) one. This script is
        just a modified version of the original one, which doesn't invoke/use
        the extra tools I mentioned above and leaves the system in a minimally
        consistent state. LI_E
UL_E

PS
With that, it was possible to reduce the initrd from ~22MB to ~900kB, a huge
improvement.
PE

SSS Kernel
PS
Unfortunately the INITRD alone is not enough: even a 'Hello World'-initrd does
not work, since the kernel refuses to load. So here things start to get
complicated...
PE

PS_N
A small note: don't start with 'tinyconfig'! I wasted
B(a lot) of time trying to add things to get something usable and failed at all
of them. Start with 'i386_defconfig' and I(remove) whatever you don't need)
PE

SSSS 1 - Kernel base address
PS
The first thing to do is modify the kernel's physical start address. By default,
it starts at 16MB, and leaves very little room for the kernel and the rest of the
system (memory before that is not used!):
PE

BC_S
-CONFIG_PHYSICAL_START=0x1000000
+CONFIG_PHYSICAL_START=0x200000
BC_E

PS Using 2MB as the BC(base physical) address should be OK, I hope… at
least I didn’t have any problems here. PE

SSSS 2 - Remove drivers and (almost) everything else
UL_S
    LI_S There is no formula for what you should or shouldn't remove, just use \
    common sense: you do not want Linux not recognizing your disk controller,
    for example (and yes, I removed it and spent a lot of time trying to
    understand why the disk was not recognized 😂) LI_E

    LI_S Remove kernel features too (but wisely): if you're not going to use
    networking, remove the entire TCP stack!, if you're not going to use USB,
    remove support too, etc. LI_E

    LI_S Backup any .configs that work, and diff your configs as well. You do not
    want to lose a config that you've been working on all day. Also, you also
    want to understand why one config makes the kernel heavier than the other. LI_E

    LI_S Use VMs: you're about to put Slackware on an old PC, which is supposedly
    500x slower (no kidding) than a current quad-core PC. If it works in a VM,
    it *might* work in real HW (disregarding issues with (lack of) drivers). LI_E

    LI_S Use all modules as 'built-in': since you'll only use what you strictly
    need, there's no need to generate external modules, and it simplifies the
    initrd too. LI_E
UL_E

PS
With that you should have a minimal kernel that boots and runs on 32M of RAM.
PE

PS
My LINK(LNK_CONFIG, config), which supports networking, ext4 and a few other
things... The diff between the config above and the i386_defconfig:
LINK(LNK_DIFF, diff)
PE

S Final thoughts
PS
I didn't cover everything I wanted to here: you still have to shrink your
Slackware install to fit on your old PC's disk... here I got about ~4.5GB by
removing: xap, xfce, kde, tex, tcl, rust, mozilla-*, LLVM, gnome-*, Qt, GTK...
(and everything X-related) and libraries I know I wouldn't use.
PE

PS
I'd also like to answer a possible 'Why?': it sounded like fun, and it was,
*a lot*. In addition, it also serves to prove that Linux is *not dead* on old
PCs, and to be honest, I found the performance quite acceptable: it is perfectly
possible to use VIM, IRC client, browse via Lynx and chat on Telegram via nchat,
to illustrate some use cases.
PE

PS
If you've done something similar based on this, please let me know =).
PE

%include "footer.inc"
