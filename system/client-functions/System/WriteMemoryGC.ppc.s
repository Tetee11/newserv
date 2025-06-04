# This function is required for loading DOLs. If it's not present, newserv can't
# serve DOL files to GameCube clients.

# This is also the file I've chosen to document how to write code for newserv's
# functions subsystem. There are three kinds of functions: includes, patches,
# and general functions.

# - General functions are not version-specific (usually) but are architecture-
#   specific. This file, WriteMemoryGC, is a general function for all PowerPC
#   versions of PSO, which means all GameCube versions. General functions are
#   named like NAME.ARCH.s, where ARCH is sh4, ppc, or x86.

# - Includes are snippets of code that are intended to be used as part of other
#   general functions and patches. Includes are named like NAME.ARCH.inc.s,
#   where ARCH has the same meaning as above. These can be used with the
#   .include directive; there is an example of this in the code below.

# - Patches are functions that are available to run upon client request. They
#   can be made available in the Patches menu or via the $patch command.
#   Patches should be named like PATCHNAME.VERS.patch.s, where VERS denotes
#   which specific game version the patch is for. These version codes are
#   listed in README.md, and directly correspond to values returned by the
#   VersionDetect functions, also in this directory.

# For example, to use this function to write the bytes 38 00 00 05 to the
# address 8010521C, send_function_call could be called like this:
#   auto fn = s->function_code_index->name_to_function.at("WriteMemoryGC");
#   unordered_map<string, uint32_t> label_writes(
#       {{"dest_addr", 0x8010521C}, {"size", 4}});
#   string suffix("\x38\x00\x00\x05", 4);
#   send_function_call(
#       c,  // Client to send function call to
#       fn,  // The function's code
#       label_writes,  // Variables to pass in to the function's code
#       suffix);  // Data to append after the code (not all functions use this)
# The meanings of label_writes and suffix are described in the comments below.
# Note that there is no way to specify label_writes or suffix for patches
# requested by the client, so those features should only be used in general
# functions.

# The .versions directive may be used in patches (but not in includes or
# general functions) and enables parameterization. If .version is used, then
# the patch may later use expressions like <VERS value1 value2 ...> to generate
# the same patch with different values for different game versions. In each
# <VERS> expression, the number of values must match the number of versions
# given in the .versions directive.
# .versions VRS1 VRS2 VRS3 ...

# These directives tell newserv what to show to the player in the Patches menu.
# Neither of them is required; if the name is omitted, the filename is used
# instead.
.meta name="Write memory"
.meta description="Writes data to any location in memory"

# To hide a patch from the Patches menu (so it can only be used with the $patch
# command), this directive can be used. This has no effect if used in includes
# or general functions.
# .meta hide_from_patches_menu

# The entry_ptr label is required for all functions. It should point to a
# .offsetof directive that itself points to the actual entrypoint.
entry_ptr:
# All labels starting with reloc signify that the following PPC word (big-endian
# 32-bit value) is to be relocated at runtime. That is, when the code runs on
# the client, the PPC word will contain the actual memory address relative to
# the running code instead of the offset that it holds at assembly time. The
# entry_ptr label should almost always have a reloc label next to it.
reloc0:
  .offsetof start

start:
  mflr    r12
  bl      get_block_ptr
  mr      r6, r3        # r6 = address of dest_addr label

copy_block:
  lwz     r3, [r6]      # r3 = dest ptr
  subi    r3, r3, 1     # subtract 1 so we can use stbu
  lwz     r5, [r6 + 4]  # r5 = size (bytes remaining)
  add     r5, r5, r3    # r5 = dest end ptr (last byte to be written)
  addi    r4, r6, 7     # r4 = src ptr (starting at -1 so we can use lbzu)
copy_block__again:
  lbzu    r0, [r4 + 1]
  stbu    [r3 + 1], r0
  cmp     r3, r5
  bne     copy_block__again

  # Flush the data cache and clear the instruction cache at the written region
  lwz     r3, [r6]      # r3 = dest ptr
  lwz     r4, [r6 + 4]  # r4 = size
  # A .include directive essentially pastes in the code from the referenced
  # file. Here, we use the code from the file FlushCachedCode.inc.s. When
  # compiling includes, newserv first looks in the same directory as the
  # function's source, then looks in system/client-functions/System.
  .include FlushCachedCode

  # Return the address after the last byte written. The value returned in r3
  # from the function is sent back to the server in a B3 command. newserv uses
  # the return value during DOL loading to know which section of the DOL file to
  # send next, or to send the RunDOL function if all sections have been loaded.
  lwz     r3, [r6]      # r3 = dest ptr
  lwz     r4, [r6 + 4]  # r4 = size
  add     r3, r3, r4
  mtlr    r12
  blr

get_block_ptr__ret:
  mflr    r3
  mtlr    r10
  blr
get_block_ptr:
  # We use a trick here to get the address of the dest_addr label: since bl puts
  # the immediately-following address into the link register, we "call"
  # get_block_ptr__ret and get the dest_addr pointer out of the LR. We then put
  # r10 back into the LR so get_block_ptr__ret returns to the caller.
  mflr    r10
  bl      get_block_ptr__ret

# These fields are filled in right before the command is sent to the client.
# Specifically, the label_writes argument to send_function_call is responsible
# for this. The label_writes argument is a map of label name to value, and
# send_function_call simply writes the given values after the given labels. This
# is a way to pass arbitrary arguments to a function at call time.
dest_addr:
  .zero
size:
  .zero

# Finally, we use the suffix argument to instruct send_function_call to append
# the data we want to write to memory immediately after the assembled code.
# (The data_to_write label here is for documentation purposes only; the suffix
# argument always appends data after the end of all the assembled code.)
data_to_write:
