.meta name="Disable idle DC"
.meta description="Disables the idle\ndisconnect timeout"

entry_ptr:
reloc0:
  .offsetof start
start:
  .include  WriteCodeBlocksGC

  .data     0x80092C78
  .data     0x00000004
  li        r3, 0

  .data     0x00000000
  .data     0x00000000
