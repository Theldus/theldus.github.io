%include "macros.inc"
SET_POST_TITLE Ricing my Tux boot logo
SET_POST_DNBR  1
SET_POST_DATES 2025-04-21, 2025-04-23

%include "header.inc"

%define LNK_INIT \
    "https://gist.github.com/Theldus/9825bc2ad9c4aee299cd312f956ff8ce"

IMG_L "/assets/img/boot-logo/waifus.png", \
    Final result: one waifu/image for each CPU core, \
    https://www.youtube.com/watch?v=MCWX04aM0mI

PS
I've been using Slackware as my main OS for over 10 years, and one thing I have
always liked is the 'Tuxes' at the top representing the number of cores I have.
I know this isn't exclusive to Slackware, but anyone who's used it with LILO
knows exactly what I'm talking about.
PE

PS
Anyway, I've always wanted to customize the Tux with something more, shall we
say, interesting. However, I was never interested in putting a single image to
replace the Tux, because why not several? For example, showing specifically the
number of cores I have.
PE

PS
This post then aims to show what is needed to add as many images as we want and
display them individually on the screen, just as shown in the first image of
this post. I(Spoiler:) we're going to have to patch the kernel!).
PE

PS_N
The entire procedure shown here is geared towards Slackware, but all the steps
can be perfectly adapted according to the Linux distro you use.
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
kernels. On another machine of mine, which uses B(v5.4.186), there is a tiny
difference in the BC(fb_show_logo()) function, which means the patch does not
apply completely. I(However,) as mentioned, these are small enough differences
to be corrected manually.
PE

SS Kernel build!
PS
Once patched, just compile the kernel and use it. The exact procedure may vary
depending on your Linux distribution, but the procedures below for Slackware
should serve as general guidelines for any environment:
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

S Final thoughts
PS
I'm quite happy with the result, and the idea can be expanded to other things,
such as displaying a different logo depending on the CPU model or anything not
defined at compile time.
PE

PS
Realistically, I don't expect others to actually use this, so let it at least
serve as curiosity, that kernel-dev can be fun too, and of course, not
everything goes well the first time:
PE

IMG_S "/assets/img/boot-logo/kpanic.png", 70, \
not-so-scary kernel panic I had during code study 😂 (click to enlarge)

PS
but it's also part of the fun =)
PE

%include "footer.inc"
