%include "macros.inc"
SET_POST_TITLE The weird way AIX handles syscalls
SET_POST_DNBR  2
SET_POST_DATES 2026-03-11, 2026-03-11

%include "header.inc"

%define LNK_AIX_USER "https://github.com/Theldus/aix-user"
%define LNK_SYSCALL_LIST "https://blog.theldus.moe/aix-user/"

PS
As some of you may know, I'm building a
LINK(LNK_AIX_USER, user-space AIX emulator), and for documenting purposes
I've decided it's time to write about how syscalls work on AIX, because... it
took me too much time to figure this out, and this is not documented anywhere,
so I thought this could be a good read for the curious, and a document for
me =).
PE

S Kernel as a library
PS
First of all, I need to point out how AIX kernel differs from other kernels.
Contrary to Linux, for example, AIX's kernel is also 'loaded' as a library
and even shows up on BC(ldd):
PE

BC_S
(aix) # ldd gettime
gettime needs:
         /usr/lib/libc.a(shr.o)
         /unix
         /usr/lib/libcrypt.a(shr.o)
BC_E

PS
A further inspection reveals it being a dependency of libc, as you can see on
BC(aix-dump) (provided in my LINK(LNK_AIX_USER, aix-user) project):
PE

BC_S
(linux) $ ./tools/aix-dump libc/shr.o | grep LIBPATH -A 8
LIBPATH: (/usr/lib:/lib)
Import ID#1:
  Path:   (/)
  Base:   (unix)
  Member: ((null))
Import ID#2:
  Path:   ((null))
  Base:   (libcrypt.a)
  Member: (shr.o)
BC_E

PS
You might question why this happens, and the answer is pretty clear when you
see a typical process map:
PE

BC_S
(aix) # procmap -X 5767430
5767430 : /home/asm/gettime 

Start-ADD         End-ADD               SIZE MODE  PSIZ  TYPE       VSID             MAPPED OBJECT
0                 10000000           262144K r--   s     KERTXT     2002              
10000000          100014e2                5K r-x   s     MAINTEXT   812492           gettime 
20000f2d          20001318                0K rw-   s     MAINDATA   81a49a           gettime 
20001318          20001318                0K rw-   s     HEAP       81a49a            
2df23000          2ff23000            32768K rw-   s     STACK      81a49a            
d0100c80          d056e6aa             4534K r-x   s     SLIBTEXT   813493           /usr/lib/libc.a[shr.o] 
d05b3100          d05b39a1                2K r-x   s     SLIBTEXT   813493           /usr/lib/libcrypt.a[shr.o] 
f07868e0          f0863e10              885K rw-   s     PLIBDATA   804484           /usr/lib/libc.a[shr.o] 
f08645c8          f08646e4                0K rw-   s     PLIBDATA   804484   
BC_E

PS
As can be seen, the first 256MiB is a RO-memory of type BC(KERTXT), so yes,
this is the kernel memory mapped directly into userspace, and libc (and
programs) I(heavily) relies on this, in order to share important data
structures, and etc.
PE

PS_N
Fun note: As you might have guessed, accesses to '0x0' address are valid and
do B(not) produce a SEGFAULT, instead, just return '0', as this is the current
value stored there. I wonder how many bugs are hidden on AIX's programs for
this simple 'feature' alone.
PE

PS_N
As you saw on 'ldd', libraries are shipped in two ways on AIX: as a direct
XCOFF32/64 binary or as an archive. The archive version contains multiple
'modules' inside it, each module is an XCOFF32/64 file, so despite the
misleading name, .a files are also shared libraries.
PE

S How AIX syscalls actually work then?
PS
A normal PPC syscall on I(Linux) looks like this:
PE

BC_S
1000a9d0 <__getpid>:
1000a9d0:       38 00 00 14     li      r0,20
1000a9d4:       44 00 00 02     sc
1000a9d8:       4e 80 00 20     blr
1000a9dc:       60 00 00 00     nop
BC_E

PS
Register r0 holds the syscall number, BC(sc) issues the syscall and r3 holds
the return value.
PE

PS
On AIX this greatly differs: despite the same 'sc' instruction is issued at
some point, libc does B(not) know the syscall number in advance, it instead
relies on BC(/unix) for this.
PE

PS
Remember when I said that the kernel is I(also) a 'library'? so, every syscall
on AIX is simply a function call to the 'library' "/unix", and this library,
in turn, issues the actual syscall. For the same BC(getpid(2)) we have:
PE

BC_S
(aix) # objdump -d libc/shr.o
...
00022ef0 <._getpid>:
   22ef0:   81 82 07 8c     l       r12,1932(r2)
   22ef4:   90 41 00 14     st      r2,20(r1)
   22ef8:   80 0c 00 00     l       r0,0(r12)
   22efc:   80 4c 00 04     l       r2,4(r12)
   22f00:   7c 09 03 a6     mtctr   r0
   22f04:   4e 80 04 20     bctr
...
BC_E

PS
Here enter the interesting thing: since we're calling an external function, AIX
needs to I(find) the actual address of the kernel function and it does so
through the BC(r2) register, aka TOC register (or Table of Contents).
PE

PS
Each loaded library has its own 'Table of Contents' (TOC for short) in memory
and this table holds all relocated symbols. Register BC(r2) always holds the
current TOC, whether from the main executable, from the libc, from /unix and
so on. In the example above, the code is reading the entry '1932' from the
current TOC (libc).
PE

PS
We can easily confirm this via the BC(aix-dump) tool. First of all, we get the
TOC address:
PE

BC_S
(linux) $ ./tools/aix-dump libc/shr.o | grep "o_toc"
  o_toc:        0x7d078
BC_E

PS
then we look at the relocation table, the corresponding entry at
BC(TOC[1932]), or BC(0x7d078 + 1932):
PE

BC_S
(linux) $ ./tools/aix-dump libc/shr.o | grep 7d804
XCOFF32 Relocation Table:
Vaddr         Symndx      Type|Size    Relsect
...
0x0007d804    00000626    00   1f      0002
BC_E

PS
The symbol of index BC(626) corresponds to the symbol BC(626 - 3) at the
symbol table (this occurs because entries 0,1 and 2 are reserved for .text,
.data and .bss):
PE

BC_S
(linux) ./tools/aix-dump libc/shr.o | grep "0623 0x"
XCOFF32 Symbol Table:
IDX  Value      SecNum SymType SymClass IMPid   Name
...
0623 0x00000000 0x0000 0x40    0x0a     0x0001  (_getpid)
BC_E

PS
And bingo!, found it!, as can be noted, BC(_getpid) is of type BC(0x40), which
means it is an imported symbol, and its class means it is of type BC(XMC_DS),
or in simple terms, a function descriptor.
PE

PS
Please also note the BC(IMPid) column (IMPort ID): it means this symbol is
being imported from the first library in our import list, i.e., the /unix.
PE

PS
Anyway, when the kernel is doing its relocations, it loads the symbols from
/unix and puts the TOC entry address of BC(_getpid) at the libc's relocated
TOC address + 1932.
PE

PS
Having said that, knowing that the TOC entry for a 'function descriptor'
follows the structure:
PE

BC_S
/**
 * Control section (csec) function descriptor.
 */
struct xcoff_csec_func_desc {
  u32 address;    /* Address of executable function. */
  u32 toc_anchor; /* TOC anchor base address.        */
  u32 env_ptr;    /* Environment Pointer (??, no idea what is this). */
};
BC_E

PS
we can finally dump and interpret this data:
PE

BC_S
(gdb) p $pc
$2 = (void (*)()) 0xd0123cf4 <_getpid+4>
(gdb) x/3wx $r12
0xff5bd4:       0x00003700      0x00000242      0x00000242
BC_E

PS
But please note something: contrary to an ordinary function descriptor TOC
entry (there are multiple entry types), the entry the kernel provides for
BC(XMC_SV) (i.e., the supervisor call type) contains the syscall handler and
number: the handler resides on 0x3700 (remember that the low-memory is the
kernel?) and 0x242 is actually the syscall number. This becomes more clear when
we dump the memory at 0x3700:
PE

BC_S
(gdb) x/2i 0x3700
0x3700: crorc   4*cr1+eq,4*cr1+eq,4*cr1+eq
0x3704: sc
BC_E

PS
So the BC(__getpid()) function could be simplified to:
PE

BC_S
<__getpid>:
  li r0, 0x3700
  li r2, 0x242
  sc
BC_E

PS
A curious side-effect of all of this: since AIX's libc B(does not) know any
previous information about the syscalls, there are no static binaries on AIX,
only dynamic.
PE

S What about other syscalls
PS
AIX 7.2 TL04 SP2 has roughly 669 syscalls (which I listed
LINK(LNK_SYSCALL_LIST, all of them here)), but the extraction of each one is
not that difficult, once you understand how they are wired up.
PE

PS
First of all: syscalls are symbols that libc imports from /unix, AIX's libc
B(never) attempts to issue a syscall directly. Second, their symbols are
I(usually) (not always) marked as BC(XMC_SV) and BC(XMC_SV3264) (sometimes
are marked just as regular symbols).
PE

PS
Given this predictability, my emulator can not only know when a required
syscall is implemented or not, but nicely print on the screen their name if not
available, cool isn't it? Another interesting thing is: since AIX relies on
relocations to handle syscalls, my emulator does not even need to know their
numbers, only their names!, this makes my emulator more portable across
different AIX versions and this is really cool.
PE

PS
The huge drawback is that there is I(no) way to have static binaries: even if
you attempt to build one, the program will fail to load, the kernel really
expects all the standard machinery of relocations and etc in order to load your
bin, and this took me 2 months to implement one that supposedly works.
PE

S Final thoughts
PS
AIX is an interesting OS/kernel, and despite being actively maintained, it
still carries some of its legacy concepts even on newer kernels (kernel as
library and the 0-page thing is not new, old Unixes also behave this way).
PE

PS
The bad thing, as someone might infer, is its closed-source nature. Despite
having extensive documentation, there is none about syscalls and its ABI, so
the beginning of aix-user was very chaotic, since even simple things like
'where the kernel puts argc/argv at the beginning' is not documented.
PE

PS
I have many other interesting things to write about AIX, maybe on my blog or
directly on the project repo, I just need to manage the time to write them.
PE

%include "footer.inc"
