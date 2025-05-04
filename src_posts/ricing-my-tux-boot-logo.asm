%include "macros.inc"
SET_POST_TITLE Ricing my Tux boot logo
SET_POST_DNBR  1
SET_POST_DATES 2025-04-21, 2025-05-03

%include "header.inc"

%define LNK_INIT \
    "https://gist.github.com/Theldus/9825bc2ad9c4aee299cd312f956ff8ce"

IMG_L "/assets/img/boot-logo/waifus_b4_after.png", \
    Before and after: one waifu/image for each CPU core, \
    https://www.youtube.com/watch?v=MCWX04aM0mI

PS
I've been using Slackware as my main OS for over 10 years, and one thing I have
always liked is the 'Tuxes' at the top representing the number of cores I have.
I know this isn't exclusive to Slackware, but anyone who's used it with LILO
knows exactly what I'm talking about.
PE

PS
Anyway, I've always wanted to customize the Tux with something more, shall we
say, interesting. However, I never intended in putting a single image to
replace the Tux, seems boring, why not several? For example, showing
specifically the number of cores I have.
PE

PS
This post shows what is needed to do to add as many images as we want, and
display them individually on the screen, just as shown in the first image of
this post. I(Spoiler:) we have to patch the kernel!.
PE

PS_N
The entire procedure shown here is focused on Slackware, but all the steps
can be perfectly adapted to any Linux distro.
PE

S How does it work?
PS
There's no official way to, for example, via GRUB or LILO arguments, define
images to be loaded during startup, but Linux being open-source, that won't
stop us, right?
PE

PS
I believe the whole process can be divided into three steps:
PE

UL_S
LI_S Image preparation LI_E
LI_S Image integration into the build process LI_E
LI_S Patches to the drawing routines to consider multiple images! LI_E
UL_E

SS 1) Image preparation
PS
The images must meet the following criteria:
PE

UL_S
LI_S B((Mandatory)) Be in PPM (plain-text) in a 224-color palette! LI_E
LI_S B((Mandatory)) Be 80x80! Actually, I didn't see anything that forces it to
be I(exactly) this resolution, but since all the images follow this standard,
it's better to follow it too! LI_E
LI_S (Optional) Black background, a colored background would be weird,
perhaps LI_E
UL_E

PS
All the steps above can be summarized with the following command:
PE

BC_S
$ pngtopnm img1.png | ppmquant -fs 223 | pnmtoplainpnm > logo_cpu0_clut224.ppm
$ pngtopnm img2.png | ppmquant -fs 223 | pnmtoplainpnm > logo_cpu1_clut224.ppm
$ pngtopnm img3.png | ppmquant -fs 223 | pnmtoplainpnm > logo_cpu2_clut224.ppm
$ pngtopnm img4.png | ppmquant -fs 223 | pnmtoplainpnm > logo_cpu3_clut224.ppm
...
BC_E

%define LNK_logoswaifu \
"https://raw.githubusercontent.com/Theldus/theldus.github.io/refs/heads/master/website/assets/img/boot-logo/logos_waifu.zip"

PS_I
For those who liked my images, you can download the 8 I've created, already in
PPM format and at 80x80 resolution, LINK(LNK_logoswaifu, here).
PE

SS 2) Integrating images into the kernel build
PS
Once you have the converted images, move them to:
BC(/usr/src/linux-XYZ/drivers/video/logo) and apply the patch below to add them
to the build system: Kconfig and Makefile, as in:
PE

BC_S
# 1) Move the images to the kernel logo folder
$ cp logo_cpu0_clut224.ppm /usr/src/linux-XYZ/drivers/video/logo
$ ...
$ cp logo_cpu4_clut224.ppm /usr/src/linux-XYZ/drivers/video/logo

# 2) Apply the logo.patch to the kernel
$ cd /usr/src/linux-XYZ/drivers/video/logo
$ patch -p1 < /path/to/logo.patch
BC_E

SSSS logo.patch
BC_FILE(website/assets/src/boot-logo/logo.patch)

PS The idea is simple: the config BC(LOGO_CPUSWAIFUS_CLUT224) is added to the
build system ('y' as default), and the object files corresponding to the images
(to be generated automatically) are linked to this config, i.e., they are only
added if the kernel is compiled with this config enabled. PE

SS 3) Patching the drawing routines!

%define LNK_fbmem_v66 \
"https://github.com/torvalds/linux/blob/v6.6/drivers/video/fbdev/core/fbmem.c"

%define LNK_fblogo_v67 \
"https://github.com/torvalds/linux/blob/v6.7/drivers/video/fbdev/core/fb_logo.c"

PS
In short, the main logic for drawing the Tux resides in the files:
UL_S
LI_S LINK(LNK_fbmem_v66, /usr/src/linux-XYZ/drivers/video/fbdev/core/fbmem.c)
(if kernel < v6.7) LI_E
LI_S LINK(LNK_fblogo_v67, /usr/src/linux-XYZ/drivers/video/fbdev/core/fb_logo.c)
(if kernel >= v6.7) LI_E
UL_E

And it works as follows: the function BC(fb_show_logo()) is invoked with the
image rotation parameter and the framebuffer structure. It, in turn, obtains the
number of online CPU cores and invokes BC(fb_show_logo_line()), which, in addition
to other parameters, receives the logo to be drawn.
PE

PS
This second function performs additional checks and prepares an additional
structure, dynamically allocated for drawing the logo, which is finally done by
the third function, BC(fb_do_show_logo()). This last function, which receives
this newly allocated structure, draws the same image BC(num) times.
PE

In general terms:

BC_S
Function signatures:
--------------------
int fb_show_logo(struct fb_info *info, int rotate);

Params:
  fb_info: Holds many framebuffer important properties
           (include/linux/fb.h)
  rotate:  Whether the logo should be rotated or not
           0 = no rotation

===

static int fb_show_logo_line(
  struct fb_info *info,
  int rotate,
  const struct linux_logo *logo,
  int y,
  unsigned int n);

Params:
  logo: actual linux logo (include/linux/linux_logo.h)
      struct linux_logo {
        int type;
        unsigned int width;
        unsigned int height;
        unsigned int clutsize;
        const unsigned char *clut;
        const unsigned char *data;
      };
  y: Y-coordinate to draw, starts at 0
  n: Number of times the logo should repeat

===

void fb_do_show_logo(
  struct fb_info  *info,
  struct fb_image *image,
  int rotate,
  unsigned int num)

 Params:
   fb_image: A dynamically allocated copy of linux_logo with
             additional data. (include/uapi/linux/fb.h)
      struct fb_image {
        __u32 dx;            /* Where to place image         */
        __u32 dy;
        __u32 width;         /* Size of image                */
        __u32 height;
        __u32 fg_color;      /* Only used when a mono bitmap */
        __u32 bg_color;
        __u8  depth;         /* Depth of the image           */
        const char *data;    /* Pointer to image data        */
        struct fb_cmap cmap; /* color map info               */
      };

A typical execution for 224-color image, no rotation, 4 cores:
--------------------------------------------------------------
fb_show_logo (info, 0)
  | ncpus = 4
  |
   \->  fb_show_logo_line(info, 0, actual_logo, 0, ncpus)
          | struct fb_image = <copy> actual_logo
          |
           \-> fb_do_show_logo(info, fb_image, 0, ncpus)
BC_E

PS
Can you see where this is going? The whole mechanism is basically ready, and we
do not need significant changes for this to work. Note, for example, that the
BC(fb_do_show_logo()) function already considers the starting X-axis for
drawing the next Tux, but this is defined as 0 in the previous function
(in BC(image.dx = 0)).
PE

PS
The following patch (BC(core-fbmem.patch)) then does three main things:
OL_S

LI_S
Modifies the function signatures so that the X-axis can be considered when
drawing the other images.
LI_E

LI_S
Adds the list of images defined earlier.
LI_E

LI_S
Defines a new function, which then iterates over the list of images,
I(recalculating) the X-axis, and passing only '1' as the number of redraws,
since BC(fb_do_show_logo()) should draw a different image each time.
LI_E

OL_E
PE

PS Apply it with: PE
BC_S
$ cd /usr/src/linux-XYZ/drivers/video/fbdev/core
$ patch -p1 < /path/to/core-fbmem.patch
BC_E


SSSS core-fbmem.patch (kernel < v6.7)
BC_FILE(website/assets/src/boot-logo/core-fbmem.patch)

PS_W
The patch above was made and tested only on kernel B(v5.15.19), but B(should)
work without issues on kernels prior to B(v6.7) (i.e., kernels before
2024-01-07). The reason for this is that from v6.7 onwards, a slight refactoring
was done, and pieces of code were moved from BC(fbmem.c) to BC(fb-logo.c)
(in the same folder) for better code organization.

<br><br>

B(However,) the idea remains I(exactly) the same, and therefore, I leave the
possible adaptations, which are trivial, as an exercise for the reader 😁.

<br><br>

I should also point out that there may be small differences even in v5.X
kernels. On another machine I have, which uses B(v5.4.186), there is a tiny
difference in the BC(fb_show_logo()) function, so the patch does not
apply cleanly. I(However), as mentioned, these are small changes that are simple
to fix manually.
PE

%define LNK_newpatch \
https://github.com/Theldus/theldus.github.io/discussions/1#discussioncomment-13004097

PS_N
03-May: A huge thanks to B(@CodeAsm) who ported my patches to v6.14.4, so you 
certainly want to check it out LINK(LNK_newpatch, his patch here).
PE

SS Kernel build!
PS
Once patched, just build the kernel and use it. The exact procedure may vary
depending on your Linux distro, but the procedures below (for Slackware)
should serve as a guide for any environment:
PE

BC_S
$ cd /usr/src/new-linux-XYZ

# Get your current .config and generate a new one based on yours
$ zcat /proc/config.gz > .config
$ make olddefconfig

# Build kernel
$ make -j$(nproc) bzImage

# Build and install modules
$ make -j4 modules && make modules_install

# Copy kernel to /boot and adjust symlinks
$ cp arch/x86/boot/bzImage /boot/vmlinuz-waifu-XYZ
$ cp System.map /boot/System.map-XYZ
$ cp .config /boot/config-XYZ
$ cd /boot
$ rm System.map
$ rm config
$ ln -s System.map-XYZ System.map
$ ln -s config-XYZ config

# Make a initrd with:
$ mkinitrd -c -k XYZ -f ext4 -r /dev/sdx1 -m ext4 -u -o /boot/initrd-waifu.gz

# Update your LILO
$ vim /etc/lilo.conf
...
image = /boot/vmlinuz-waifu-XYZ
  root = /dev/sdx1
  label = XYZ-waifu
  initrd = /boot/initrd-waifu.gz
  read-only
...

$ lilo
$ sudo reboot
BC_E

S !! BONUS !!
PS
I was quite satisfied with the final result, and I didn’t want to make any more 
changes until... my post was removed from a certain subreddit for being 
considered 'fluff'.
PE

PS
Anyway, maybe they just don’t like anime girls? I don’t know, but the posts on 
my blog are B(mine), and here I can be as much of a weeb as I want.
PE

PS
Without further ado, I present to you B(animated boot logos):
PE

YOUTUBE sJZE_rt3x-U, Do you like it?

PS
B(Yes!), you saw it correctly, now we have animation instead of boring static 
Tuxes.
PE

PS The basic idea behind how it works is simple: create a kernel thread and draw 
the logos in a loop indefinitely with some sleep interval between the drawings, 
and voilà, we have animation. PE

PS However, things are never exactly as we expect, and I had two main issues 
that took me quite a while to understand:
PE

OL_S
LI_S
Drawing the logos produced kernel panic during the boot process, and it took me 
a long time to understand that for some reason the kernel was deallocating the 
memory portion related to the logo structures. It simply does not exist during 
the entire lifetime of the kernel, and because of that, I was having segfault at 
the kernel level.
LI_E

LI_S
Even if the previous item was resolved, I also needed some way to I(keep) my 
logos at the top of the screen. You might have noticed that by default the Tuxes 
disappear after a simple BC(clear) or running BC(htop) for example, I don't want 
that!
LI_E

OL_E

PS
The solution for both points wasn't complicated:
PE

OL_S
LI_S
Instead of trying to locate where this happens in the kernel, a simpler solution:
duplicate the structures in a dynamic memory portion that I control (i.e.,
BC(kmalloc()+memcpy())), and this indeed solved the first problem.
LI_E

LI_S
For the second point, enter B(DECOM), or B(DEC Origin Mode).
LI_E

OL_E

SS DEC Origin Mode

%define LNK_vt102 \
"https://elixir.bootlin.com/linux/v5.15.19/source/drivers/tty/vt/vt.c"

PS
While I was reading the VT102 driver in the Linux kernel
(LINK(LNK_vt102, drivers/tty/vt.c)) to I(try) to gain some insight about what
could be done, I came across some curious things: some TTY routines
(like BC(gotoxy())) have some checks for BC(vt_decom). If BC(vt_decom) was
enabled, then conveniently the TTY considered a 'top' for calculating the
Y-coordinates, that is, movements were relative to a margin, not 0-based, and
bingo!, this is I(exactly) what we're looking for.
PE

PS_N
DEC Origin Mode (DECOM) is a terminal control mode inherited from the old VT100 
and VT102 terminals. When active, it redefines the cursor coordinate system to 
consider an upper limit (top margin) and, in some cases, lower limit (bottom 
margin), instead of treating the entire screen as an absolute grid. This allows 
operations such as cursor movement, scrolling, and line erasure to be performed 
only within a delimited region, useful for applications that need to preserve 
headers or footers. In the Linux kernel, this behavior is controlled by the
BC(vt_decom) flag!
PE

%define LNK_fbcon \
"https://elixir.bootlin.com/linux/v5.15.19/source/drivers/video/fbdev/core/fbcon.c#L658"

PS
This 'top', in turn, is conveniently calculated by the
BC(fbcon_prepare_logo()) routine (LINK(LNK_fbcon, drivers/video/fbdev/fbcon.c)) 
and in fact the top is considered by the TTY when performing scrolls, otherwise, 
the Tuxes at the top wouldn't make sense, right? However, there were two issues:
B(a)) the "decom" mode wasn't enabled by default,
B(b)) even if it was, a "tty reset" disables the mode I(and) clears the
previously defined top coordinates.
PE

PS
The challenge then became to investigate the kernel source for: B(a)) places
where DECOM mode was forcefully disabled (such as on TTY reset!), B(b)) places
where the top could be reset. Once these points were identified, it was then
possible to make my images remain at the top indefinitely without interfering
with other applications.
PE

SS New kernel patch!
PS
The patch below, again, was made and tested on kernel B(v5.15.19), and can be 
applied without issues up to the most recent LTS: B(v5.15.181) (2025-05-02). For 
newer or older versions, please make the necessary adjustments.
PE

PS
To apply it, just do:
PE

BC_S
$ cd /usr/src/linux-5.15.181
$ patch -p1 < /path/to/patch-animated.patch
patching file drivers/tty/vt/vt.c
patching file drivers/video/fbdev/core/fbcon.c
Hunk #1 succeeded at 1260 (offset -3 lines).
Hunk #2 succeeded at 2082 (offset 38 lines).
Hunk #3 succeeded at 2191 (offset 38 lines).
patching file drivers/video/fbdev/core/fbmem.c
Hunk #1 succeeded at 38 (offset 2 lines).
Hunk #2 succeeded at 192 (offset 2 lines).
Hunk #3 succeeded at 492 (offset 2 lines).
Hunk #4 succeeded at 552 with fuzz 1 (offset 2 lines).
Hunk #5 succeeded at 626 (offset 2 lines).
Hunk #6 succeeded at 721 (offset 2 lines).
Hunk #7 succeeded at 880 (offset 2 lines).
patching file drivers/video/logo/Kconfig
patching file drivers/video/logo/Makefile
patching file include/linux/fb.h
Hunk #2 succeeded at 625 (offset 12 lines).
BC_E

PS Patch: PE
BC_FILE(website/assets/src/boot-logo/patch-animated.patch)

%define LNK_torakoppm \
"https://raw.githubusercontent.com/Theldus/theldus.github.io/refs/heads/master/website/assets/img/boot-logo/logos_torako_animated.zip"

PS Sorry for the size, but this time the patch grew a bit more than I expected. 
The frame sequence (if you want to use Torako) can be
LINK(LNK_torakoppm, downloaded here). PE

S Final thoughts
PS
I'm quite happy with the result, and the idea can be expanded to many other
things, such as displaying a different logo depending on the CPU model, and any
other things not defined at build time.
PE

PS
Realistically, I don't expect others to actually use this, but I had a lot of
fun doing this, and I B(had) to share. Things not always goes smooth, though:
PE

IMG_S "/assets/img/boot-logo/kpanic.png", 70, \
not-so-scary kernel panic I had during my patch 😂 (click to enlarge)

PS
but it's also part of the fun =).
PE

%include "footer.inc"
