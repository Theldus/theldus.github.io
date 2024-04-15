---
title: Slackware 15 on a Pentium 133 MHz (32MB of RAM)
author: theldus
date: 2023-01-15 23:16:00 -0300
categories: [Linux, Slackware]
tags: [linux, slackware]
render_with_liquid: false
---

<p align="center">
<img align="center" src="/assets/img/slack15p133.png" alt="Slackware running (video)">
<br>
<a href="https://www.youtube.com/watch?v=9y-1LYChmDA" target="_blank">Slackware running (video)</a>
</p>

## Introduction
This mini-howto is intended to briefly address what was done in the video above: running Slackware 15.0,
a recent Linux distro, on an old hw, from the 90s.

> If you have 64MB of RAM or more, you can skip this entire tutorial, Slackware 15 works out-of-the-box. If you have less than that, move on.
{: .prompt-info }

## Taking things out
There are two major issues with booting a recent kernel in an environment with 32MB of RAM (and by that I mean
any distro): initrd and kernel.

### INITRD
INITRD is supposedly a 'mini-version' of your operating system, or at least the bare minimum needed for the
rest of your system to load; you can think of it as a 'high-level bootloader'.

The problem with Slackware here is that its INITRD tries to do too much: it brings a non-static Busybox
(and with it also the dynamic libraries it depends on), plus a set of tools that aren't really necessary for
most users: such as LUKS, btrfs, RAID and etc.

With that in mind, we can do the following:
With that in mind, we can do the following:
- Put a static Busybox (preferably based on Musl)
- Remove all shared libraries from initrd
- Remove all executables that are different from Busybox, we really don't need them!
- Replace your 'init' script with [this](https://gist.github.com/Theldus/9825bc2ad9c4aee299cd312f956ff8ce) one. This script is just a modified version of
the original one, which doesn't invoke/use the extra tools I mentioned above and leaves the system in a minimally consistent state.

With that, it was possible to reduce the initrd from ~22MB to ~900kB, a huge improvement.

### Kernel
Unfortunately the INITRD alone is not enough: even a 'Hello World'-initrd does not work, since the kernel
refuses to load. So here things start to get complicated...

_(A small note: don't start with 'tinyconfig'! I wasted *a lot* of time trying to add things to get something usable and failed at all of them. Start with 'i386_defconfig' and __remove__ whatever you don't need)._

#### 1) Kernel base address
The first thing to do is modify the kernel's physical start address. By default, it starts at 16MB, and leaves very little room for the kernel and the rest of the system (memory before that is not used!):
```diff
-CONFIG_PHYSICAL_START=0x1000000
+CONFIG_PHYSICAL_START=0x200000
```
Using 2MB as the base physical address should be OK, I hope... at least I didn't have any problems here.

#### 2) Remove drivers and (almost) everything else
- There's no formula for what you should or shouldn't remove, just use common sense: you don't want Linux not recognizing your disk controller, for example (and yes, I removed it and spent a lot of time trying to understand why the disk wasn't recognized 😂).
- Remove kernel features too (but wisely): if you're not going to use networking, remove the entire TCP stack!, if you're not going to use USB, remove support too, etc.
- Backup any .configs that work, and diff your configs as well. You don't want to lose a config that you've been working on all day. Also, you also want to understand why one config makes the kernel heavier than the other.
- Use VMs: you're about to put Slackware on an old PC, which is supposedly 500x slower (no kidding) than a current quad-core PC. If it works in a VM, it *might* work in real HW; (disregarding issues with (lack of) drivers).
- Use all modules as 'built-in': since you'll only use what you strictly need, there's no need to generate external modules, and it simplifies the initrd too.

With that you should have a minimal kernel that boots and runs on 32M of RAM.

My [.config](https://gist.github.com/Theldus/2b4f7ac6d5245f126df80a86897327e1), which supports networking, ext4 and a few other things...
The diff between the config above and the i386_defconfig: [diff](https://gist.github.com/Theldus/4493412cc953a0a72c6a92534406af05)

## Final thoughts
I didn't cover everything I wanted to here: you still have to shrink your Slackware install to fit on your old PC's disk... here I got about ~4.5GB by removing:
xap, xfce, kde, tex, tcl, rust, mozilla-*, LLVM, gnome-*, Qt, GTK... (and everything X-related) and libraries I know I wouldn't use.

I'd also like to answer a possible 'Why?': it sounded like fun, and it was, *a lot*. In addition, it also serves to prove
that Linux is *not dead* on old PCs, and to be honest, I found the performance quite acceptable: it is perfectly possible to
use VIM, IRC client, browse via Lynx and chat on Telegram via nchat; to illustrate some use cases.

If you've done something similar based on this, please let me know =).
