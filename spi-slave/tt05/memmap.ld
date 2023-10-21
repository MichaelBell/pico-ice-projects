MEMORY {
    /* We are loaded to the top 256 bytes of SRAM, which is above the bootrom
       stack. Note 4 bytes occupied by checksum. */
    SRAM(rx) : ORIGIN = 0x10000200, LENGTH = 256
}

SECTIONS {
    . = ORIGIN(SRAM);
    .text : {
        *(.entry)
        *(.text)
    } >SRAM
}
