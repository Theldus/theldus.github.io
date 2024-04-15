---
title: The only proper way to debug 16-bit code on Qemu+GDB 
author: theldus
date: 2023-12-24 17:42:00 -0300
categories: [C, OSDev, Debugging]
tags: [c, osdev, debugging]
render_with_liquid: false
---

<p align="right"><i>(or nearly so...)</i></p>

GDB is undeniably an extremely versatile debugger, with the ability to add breakpoints, watchpoints, dump memory, registers, and the source code (along with its corresponding assembly). These features make it the perfect Swiss Army knife for most programmers. In addition to that, the possibility of implementing a 'GDB Stub' and automatically supporting GDB in your application makes it an almost universal debugger for a variety of tasks.

Qemu, like other virtual machines (such as 86Box), also implements debugging via GDB Stub, which enormously facilitates the development of bootloaders, operating systems, and more. The support for 32-bit and 64-bit code is quite good, and I have never seen any complaints about it. However, for 16-bit/real mode...

## Is debugging in 16-bit/real mode really that bad?
If you have ever tried to debug 16-bit code on Qemu, you know how painful it can be:
1. GDB thinks your code is in 32-bit, and the disassembly is obviously incorrect.
2. Even with correct disassembly, using `CS:EIP` causes GDB to disassemble the wrong code segment, as it relies on linear memory, instead of segmented memory.
3. The same occurs with stack dumps and other things that use memory segmentation.

Reasons 1) and 2) make it impossible to use Qemu+GDB in a 'normal' way without resorting to some kind of workaround.

Usually, when debugging 16-bit code, people either switch to another VM, such as Bochs (which has a native debugger for 16-bit and is very good), or use GDB scripts to try to work around the problem, like:
- [Remote debugging of real mode code with gdb]
- [gdb-real-mode-code]
- [QEMU gdb does not show instructions of firmware]

The use of scripts is generally okay but ties you to the GDB command line interface and prevents the use of any [GUI for it]. Personally, I am quite familiar with the CLI, as I have been using it for many years, but it can be a barrier for newcomers (although the learning curve is not that steep).

## Attempting to Fix This...
The issues mentioned above arise because GDB is a very generic debugger, supported by many architectures, and x86 is a rather... unique architecture, so Qemu needs to make choices!

In the same order as in the previous section, here are some responses:

1. Qemu _tells_ GDB that the target architecture is 32-bit, forcing users to perform various acrobatics with XML files, and so on, just to adjust the disassembly correctly.
2. GDB is unaware of segmented memory, only linear memory... thus, GDB requests incorrect memory addresses from Qemu!

Can this be fixed? YES, let's patch Qemu!

## Patching Qemu!
The following patch was created for qemu-8.2.0-rc4 and successfully tested with GDB 9.2, but it can certainly be applied without issues to other versions:

```patch
diff -x build -ruN qemu-8.2.0-rc4-old/target/i386/cpu.c qemu-8.2.0-rc4-new/target/i386/cpu.c
--- qemu-8.2.0-rc4-old/target/i386/cpu.c    2023-12-13 16:44:49.000000000 -0300
+++ qemu-8.2.0-rc4-new/target/i386/cpu.c    2023-12-18 18:07:05.973940391 -0300
@@ -5923,7 +5923,21 @@
 #ifdef TARGET_X86_64
     return "i386:x86-64";
 #else
-    return "i386";
+    X86CPU *cpu = X86_CPU(cs);
+    CPUX86State *env = &cpu->env;
+
+    /*
+     * ## Handle initial CPU architecture ##
+     *
+     * Check if protected mode or real mode.
+     * This is only useful when the GDB is attaching,
+     * mode switches after that aren't reflected
+     * here.
+     */
+    if (env->cr[0] & 1)
+      return "i386";
+    else
+      return "i8086";
 #endif
 }

diff -x build -ruN qemu-8.2.0-rc4-old/target/i386/gdbstub.c qemu-8.2.0-rc4-new/target/i386/gdbstub.c
--- qemu-8.2.0-rc4-old/target/i386/gdbstub.c    2023-12-13 16:44:49.000000000 -0300
+++ qemu-8.2.0-rc4-new/target/i386/gdbstub.c    2023-12-18 18:06:37.161940501 -0300
@@ -118,7 +118,22 @@
                 return gdb_get_regl(mem_buf, 0);
             }
         } else {
-            return gdb_get_reg32(mem_buf, env->regs[gpr_map32[n]]);
+            /*
+             * ## Handle ESP ##
+             * If in protected-mode, do as usual...
+             */
+            if (env->cr[0] & 1) {
+                return gdb_get_reg32(mem_buf, env->regs[gpr_map32[n]]);
+            }
+
+            /* If real mode & !ESP, do as usual... */
+            if (n != R_ESP) {
+                return gdb_get_reg32(mem_buf, env->regs[gpr_map32[n]]);
+            }
+
+            /* If ESP, return it converted. */
+            return gdb_get_reg32(mem_buf,
+                (env->segs[R_SS].selector * 0x10) + env->regs[gpr_map32[n]]);
         }
     } else if (n >= IDX_FP_REGS && n < IDX_FP_REGS + 8) {
         int st_index = n - IDX_FP_REGS;
@@ -144,7 +159,20 @@
                     return gdb_get_reg64(mem_buf, env->eip & 0xffffffffUL);
                 }
             } else {
-                return gdb_get_reg32(mem_buf, env->eip);
+                /*
+                 * ## Handle EIP ##
+                 * qemu-system-i386 is handled here!
+                 */
+
+                /* If in protected-mode, do as usual... */
+                if (env->cr[0] & 1) {
+                    return gdb_get_reg32(mem_buf, env->eip);
+
+                /* Otherwise, returns the physical address. */
+                } else {
+                    return gdb_get_reg32(mem_buf,
+                        (env->segs[R_CS].selector * 0x10) + env->eip);
+                }
             }
         case IDX_FLAGS_REG:
             return gdb_get_reg32(mem_buf, env->eflags);

```

This patch does three things, in the order they occur:
1. Changes the way the `x86_gdb_arch_name()` function works: this function is called by `get_feature_xml()` in `gdbstub.c` and is responsible for returning the corresponding string of the target architecture. Previously, Qemu returned `i386:x86-64` when invoked with `qemu-system-x86_64` and `i386` when invoked with `qemu-system-i386`. This patch checks the current CPU mode and returns `i386` when in protected mode and `i8086` when in real mode. This completely eliminates XML file workarounds and ensures that GDB correctly identifies the architecture, enabling correct disassembly.

2. Changes the value returned for ESP: instead of returning the actual ESP value, it returns the corresponding physical address: `SS*0x10+ESP`. This simplifies stack dumps, such as: `x/10wx $esp`. It also allows alternative GUIs to GDB to display the stack normally.

3. Same as 2) but for EIP: instead of returning the actual EIP value, it returns the corresponding physical address: `CS*0x10+EIP`. This allows GDB to know the current physical address and correctly disassemble instructions.

And that's basically it, as you can see:
![Qemu reset vector correctly disassembled on GDB](/assets/img/gdbqemu16.png)

Same with gdbgui:
![Qemu reset vector correctly disassembled on gdbgui](/assets/img/gdbguiqemu16.png)

## Is there a catch?
Is that it? Just apply this small patch and you're done? Goodbye problems? Almost...

As I mentioned in the beginning, x86 is a complicated architecture, even more so to make it work generically enough in GDB. There's a single pending issue that I believe has no solution on the Qemu side: mode switches!

When a connection with GDB is established, the architecture, registers, and so on are negotiated for correct disassembly. However, as mentioned before, GDB sees real-mode and protected-mode as two distinct architectures: `i8086` and `i386`! When there is a mode switch (`real <-> protected`), GDB is unaware that there has been a change in architecture (because... let's face it, normally that doesn't happen, an architecture doesn't change... right?) and starts disassembling instructions incorrectly! To make matters worse, there is nothing in the [GDB Remote Serial Protocol] (at least I haven't found anything... any help would be much appreciated) that specifies a runtime architecture switch.

The workaround? Manually change the architecture in the GDB console: `set architecture i8086` and `set architecture i386`, or ask GDB for help. The following `.gdbinit` script is enough:

```gdb
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
```

the above script checks the current mode whenever GDB pauses, whether via a single-step, breakpoint, and etc... and set the architecture accordingly.

> **To be clear:** This patch allows GDB to **correctly identify** the architecture (based on the current processor mode) at the time of the GDB _attachment_. Any mode changes _after_ the attachment are not automatically detected. If your code runs only in real mode from the beginning to end, chances are you won't have any issues.
{: .prompt-info }

## Why Doesn't Qemu Do Something Similar?
Probably Qemu devs don't care much about 16-bit/real-mode, but perhaps more importantly: Qemu doesn't want to deceive GDB! Note that in these patches, Qemu starts 'lying' about the true values of EIP, ESP, and so on... all of this is done so that GDB interprets their physical addresses instead of `SEG:OFF`.

Is it so important not to lie like that? It depends... this patch only changes the values reported to GDB, so nothing interferes on the execution of the VM itself. Moreover, the GDB Stub of [86Box] does something quite similar to what is proposed here, and debugging in 16-bit/real-mode with it is quite smooth.

However, the part about correctly identifying the architecture could exist in Qemu (during GDB attachment, as this patch does), but again, debugging 16-bit code doesn't seem so crucial for Qemu-devs, and I don't blame them for it.

## Final Thoughts
Debugging 16-bit/real-mode code in GDB has always been a challenge, whether in Qemu or other environments, which is why Bochs has its own debugger, DOSBox as well, and so on. However, it is indeed possible to solve most of the problems and it is perfectly feasible to use GDB for debugging 16-bit code.

Some time ago, I developed a debugger for 16-bit code called [BREAD], capable of debugging BIOS ROM and DOS programs, also via GDB Stub, applying the same concepts explored here.

That said, despite the catchy title, the proposed patch doesn't solve _all_ problems (as mentioned earlier), but I believe it resolves a good portion of them, without the need to create extensive GDB scripts to try to work around debugging issues.

For better support of `i8086`, the GDB RSP protocol needs to undergo changes, such as supporting dynamic architecture changes at runtime.

<!-- Links -->
[GDB Remote Serial Protocol]: https://sourceware.org/gdb/current/onlinedocs/gdb.html/Remote-Protocol.html
[86Box]: https://github.com/86Box/86Box
[Remote debugging of real mode code with gdb]: https://ternet.fr/gdb_real_mode.html
[gdb-real-mode-code]: https://github.com/kvakil/0asm/blob/master/gdb-real-mode
[QEMU gdb does not show instructions of firmware]: https://stackoverflow.com/questions/62513643/qemu-gdb-does-not-show-instructions-of-firmware
[GUI for it]: https://sourceware.org/gdb/wiki/GDB%20Front%20Ends
[BREAD]: https://github.com/Theldus/bread
