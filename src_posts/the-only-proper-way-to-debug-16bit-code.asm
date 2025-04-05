%include "macros.inc"
SET_POST_TITLE The only proper way to debug 16-bit code on Qemu+GDB
SET_POST_DNBR  1
SET_POST_DATES 2023-12-24, 2025-04-04

%include "header.inc"

<p align="right"><i>(or nearly so...)</i></p>

%define LNK_INIT \
    "https://gist.github.com/Theldus/9825bc2ad9c4aee299cd312f956ff8ce"

PS
GDB is undeniably an extremely versatile debugger, with the ability to add
breakpoints, watchpoints, dump memory, registers, and the source code (along
with its corresponding assembly). These features make it the perfect Swiss
Army knife for most programmers. In addition to that, the possibility of
implementing a 'GDB Stub' and automatically supporting GDB in your application
makes it an almost universal debugger for a variety of tasks.
PE

PS
Qemu, like other virtual machines (such as 86Box), also implements debugging
via GDB Stub, which enormously facilitates the development of bootloaders,
operating systems, and more. The support for 32-bit and 64-bit code is quite
good, and I have never seen any complaints about it. However, for 16-bit/real
mode...
PE

SS Is debugging in 16-bit/real mode really that bad?

PS
If you have ever tried to debug 16-bit code on Qemu, you know how painful it can
be:
PE

OL_S
LI_S GDB thinks your code is in 32-bit, and the disassembly is obviously
incorrect. LI_E

LI_S Even with correct disassembly, using BC(CS:EIP) causes GDB to disassemble the
wrong code segment, as it relies on linear memory, instead of segmented memory.
LI_E

LI_S The same occurs with stack dumps and other things that use memory
segmentation. LI_E
OL_E

PS Reasons 1) and 2) make it impossible to use Qemu+GDB in a 'normal' way without
resorting to some kind of workaround.
PE

PS
Usually, when debugging 16-bit code, people either switch to another VM, such as
Bochs (which has a native debugger for 16-bit and is very good), or use GDB
scripts to try to work around the problem, like:
PE

%define LNK_REMOTEDBG  "https://ternet.fr/gdb_real_mode.html"
%define LNK_GDBREALMODE  \
    "https://github.com/kvakil/0asm/blob/master/gdb-real-mode"
%define LNK_GDBFIRMWARE \
"https://stackoverflow.com/questions/62513643/qemu-gdb-does-not-show-instructions-of-firmware"
%define LNK_GDBGUI "https://sourceware.org/gdb/wiki/GDB%20Front%20Ends"

UL_S
LI_S LINK(LNK_REMOTEDBG, Remote debugging of real mode code with gdb) LI_E
LI_S LINK(LNK_GDBREALMODE, gdb-real-mode-code)
LI_S LINK(LNK_GDBFIRMWARE, QEMU gdb does not show instructions of firmware)
UL_E

PS
The use of scripts is generally okay but ties you to the GDB command line
interface and prevents the use of any LINK(LNK_GDBGUI, GUI for it). Personally,
I am quite familiar with the CLI, as I have been using it for many years, but it
can be a barrier for newcomers (although the learning curve is not that steep).
PE

SS Attempting to Fix This...
PS
The issues mentioned above arise because GDB is a very generic debugger,
supported by many architectures, and x86 is a rather... unique architecture, so
Qemu needs to make choices!
PE

PS
In the same order as in the previous section, here are some responses:
PE

OL_S
LI_S Qemu I(tells) GDB that the target architecture is 32-bit, forcing users to
perform various acrobatics with XML files, and so on, just to adjust the
disassembly correctly. LI_E

LI_S GDB is unaware of segmented memory, only linear memory... thus, GDB requests
incorrect memory addresses from Qemu! LI_E
OL_E

PS Can this be fixed? YES, lets patch Qemu! PE

SS Patching Qemu!
PS
The following patch was created for qemu-8.2.0-rc4 and successfully tested with
GDB 9.2, but it can certainly be applied without issues to other versions:
PE

BC_FILE(website/assets/src/qemugdb.patch)

PS This patch does three things, in the order they occur: PE

OL_S
LI_S Changes the way the BC(x86_gdb_arch_name()) function works: this function is
called by BC(get_feature_xml()) in BC(gdbstub.c) and is responsible for returning
the corresponding string of the target architecture. Previously, Qemu returned
BC(i386:x86-64) when invoked with BC(qemu-system-x86_64) and BC(i386) when
invoked with BC(qemu-system-i386). This patch checks the current CPU mode and
returns BC(i386) when in protected mode and BC(i8086) when in real mode. This
completely  eliminates XML file workarounds and ensures that GDB correctly
identifies the architecture, enabling correct disassembly. LI_E

LI_S Changes the value returned for ESP: instead of returning the actual ESP
value, it returns the corresponding physical address: BC(SS*0x10+ESP). This
simplifies stack dumps, such as: BC(x/10wx $esp). It also allows alternative GUIs
to GDB to display the stack normally. LI_E

LI_S Same as 2) but for EIP: instead of returning the actual EIP value, it
returns the corresponding physical address: BC(CS*0x10+EIP). This allows GDB to
know the current physical address and correctly disassemble instructions. LI_E
OL_E

PS And thats basically it, as you can see: PE

IMG "/assets/img/gdbqemu16.png", Qemu reset vector correctly disassembled on GDB
IMG "/assets/img/gdbguiqemu16.png", Qemu reset vector correctly disassembled on \
gdbgui

S Is there a catch?

PS Is that it? Just apply this small patch and you're done? Goodbye problems?
Almost... PE

PS
As I mentioned in the beginning, x86 is a complicated architecture, even more so
to make it work generically enough in GDB. There's a single pending issue that I
believe has no solution on the Qemu side: mode switches!
PE

%define LNK_GDBRSP \
"https://sourceware.org/gdb/current/onlinedocs/gdb.html/Remote-Protocol.html"

PS
When a connection with GDB is established, the architecture, registers, and so on
are negotiated for correct disassembly. However, as mentioned before, GDB sees
real-mode and protected-mode as two distinct architectures: BC(i8086) and
BC(i386)! When there is a mode switch (BC(real <-> protected)), GDB is unaware
that there has been a change in architecture (because... let's face it, normally
that doesn't happen, an architecture doesn't change... right?) and starts
disassembling instructions incorrectly! To make matters worse, there is nothing
in the LINK(LNK_GDBRSP, GDB Remote Serial Protocol) (at least I haven't found
anything... any help would be much appreciated) that specifies a runtime
architecture switch.
PE

PS
The workaround? Manually change the architecture in the GDB console:
BC(set architecture i8086) and BC(set architecture i386), or ask GDB for help.
The following BC(.gdbinit) script is enough:
PE

BC_S
set $rm=1
define hook-stop
if ($cr0 & 1) == 1
  if $rm == 1
      set architecture i386
      set $rm=0
  end
else
  if $rm == 0
      set architecture i8086
      set $rm=1
  end
end
end
BC_E

PS
the above script checks the current mode whenever GDB pauses, whether via a
single-step, breakpoint, and etc... and set the architecture accordingly.
PE

PS_I
B(To be clear:) This patch allows GDB to B(correctly identify) the architecture
(based on the current processor mode) at the time of the GDB I(attachment). Any
mode changes I(after) the attachment are not automatically detected. If your code
runs only in real mode from the beginning to end, chances are you won't have any
issues.
PE

S Why Doesn't Qemu Do Something Similar?
PS Probably Qemu devs don't care much about 16-bit/real-mode, but perhaps more
importantly: Qemu doesn't want to deceive GDB! Note that in these patches, Qemu
starts 'lying' about the true values of EIP, ESP, and so on... all of this is
done so that GDB interprets their physical addresses instead of BC(SEG:OFF). PE

%define LNK_86Box "https://github.com/86Box/86Box"

PS Is it so important not to lie like that? It depends... this patch only changes
the values reported to GDB, so nothing interferes on the execution of the VM
itself. Moreover, the GDB Stub of LINK(LNK_86Box, 86Box) does something quite
similar to what is proposed here, and debugging in 16-bit/real-mode with it is
quite smooth. PE

PS
However, the part about correctly identifying the architecture could exist in
Qemu (during GDB attachment, as this patch does), but again, debugging 16-bit
code doesn't seem so crucial for Qemu-devs, and I don't blame them for it.
PE

S Final Thoughts
PS
Debugging 16-bit/real-mode code in GDB has always been a challenge, whether in
Qemu or other environments, which is why Bochs has its own debugger, DOSBox as
well, and so on. However, it is indeed possible to solve most of the problems
and  it is perfectly feasible to use GDB for debugging 16-bit code.
PE

%define LNK_BREAD "https://github.com/Theldus/bread"

PS
Some time ago, I developed a debugger for 16-bit code called LINK(LNK_BREAD,\
BREAD), capable of debugging BIOS ROM and DOS programs, also via GDB Stub,
applying the same concepts explored here.
PE

PS
That said, despite the catchy title, the proposed patch doesn't solve I(all)
problems (as mentioned earlier), but I believe it resolves a good portion of
them, without the need to create extensive GDB scripts to try to work around
debugging issues.
PE

PS
For better support of BC(i8086), the GDB RSP protocol needs to undergo changes,
such as supporting dynamic architecture changes at runtime.
PE

%include "footer.inc"
