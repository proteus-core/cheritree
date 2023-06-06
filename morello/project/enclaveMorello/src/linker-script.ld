/*
 ============================================================================
 Name        : linker-script.ld
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : linker script to define secure and non-secure memory regions
               and set up regions for the stack
 ============================================================================
 */
 
 
  /* 
  Set up memory regions and properties
  Attributes are writable (w), readable (r), or executable (x). 
  Flash memory is usually (rx), while ram is (rwx). 
  NOTE: Marking a region as non-writable does not make it write protected,
  attributes here describe the properties of the memory, not set it. 
  
  DRAM0 - 2GB is split into the following regions
  Note: to enforce this, the MMU at each EL will also have to be set up
  */
  
  /*Added extra shared memory as separate region to reduce elf zero padding*/
 
MEMORY
{

 lower_dram0_bot (rwx) : ORIGIN = 0x80000000, LENGTH = 0x10000000
 lower_dram0_top (rwx) : ORIGIN = 0x90000000, LENGTH = 0x10000000
 lower_dram0_top_shared (rwx) : ORIGIN = 0xA00F0000, LENGTH = 0x20000
 upper_dram0_all (rwx) : ORIGIN = 0xC0000000, LENGTH = 0x10000000
 
}

STACK_SIZE = 0x20000;
/*STACK_START_SECURE = 0xBFFD0000;*/ /* no longer used - place EL1S stack at top of secure memory*/
/*STACK_START_NONSECURE = 0xFFFD0000;*/ /* no longer used -  /* place EL1N stack at top of non secure memory*/
HEAP_EL1_SIZE = 10240; /*10kB - for unique alloc for enclave memory*/
START_EL1_PCC = 0x80000000; /*address to start EL1 PCC, needs to be multiples of 0x100000  - this is start of DRAM*/
START_EL2_PCC = 0x80000000; /*address to start EL1 PCC, needs to be multiples of 0x100000  - this is start of DRAM*/

SECTIONS
{

	/* ---------lower_dram0_bot-------------------------------*/
	
    .rodata : 
    { 
        /* start of el3/2 memory */
        _start_el3_2 = .;
    	*(.rodata*) 
    } > lower_dram0_bot
   
   /* el3 program code */
   
   .text : 
   { 
       _start_el3_text = .;
	   *(.text*) 
   } > lower_dram0_bot
   
    /* Align to 16 bytes (64 bits)*/
   . = ALIGN(16);
   __bss_start__ = .;
   .bss :
    {
        *(.bss*)
    } > lower_dram0_bot
    __bss_end__ = ALIGN(16);
    
    /* ------------lower_dram0_top----------------------------*/
   
    /* el2 program code */
    
    .NONSECUREsection_el2 :
    {
    . = ALIGN(8);
    __NONSECUREsection_el2_start__ = .;
    *(.NONSECUREel2entrysection_ass_el2*)  
    *(.NONSECUREsection_c_el2*)  
    *(.NONSECUREel2nmmusection_ass_el2*)
    *(.NONSECUREttel2nsection_ass_el2*)
    *(.NONSECURE_stg1ForEl1nmmusection_ass_el2*)
    *(.NONSECURE_stg2ForEl1nmmusection_ass_el2*)
    *(.NONSECUREvectortableel2N_ass_el2*)
    *(.NONSECUREhandlerFuncSectionEL2_c_el2*)
    *(.NONSECUREeretEL1Nsection_ass_el2*) 
    *(.NONSECUREuartFuncSection_c_el2*)
    *(.NONSECUREuartStructSection_c_el2*) 
    } > lower_dram0_top
     
     /*moved to separate section to remove zero padding from the elf file to reduce its size*/
      .NONSECUREsection_el2_pcc_bounds ALIGN(131072): {
    /* need to align end of el2 code section to 0x20000hex, 131072 */
    /* because nearest bounds limit can set is 0x90020000  for EL2 PCC */
    /* otherwise exact bounds clears the tag bit */
    /* non-exact bounds does not clear tag, but 0x9002000 is nearest bounds it can set */
     /*. = ALIGN(131072); */
    __NONSECUREsection_el2_end__ = .;
    } > lower_dram0_top
   
    /*move to before shared memory as don't want EL1 access to this */
    /* non secure stack */
    
    .stack_el2n (NOLOAD): ALIGN(65536)
    {
    	/* align stack to 16 bytes */
        /*. = ALIGN(16);*/
        _stack_el2n_limit = .;
        . = . + STACK_SIZE;
        /*. = ALIGN(8);*/
        _stack_el2n_base = .;
    } > lower_dram0_top 
    
   
   /*-------------------lower_dram0_top_shared----------------------------*/
   
    /* EL1 translation tables in shared el1-RO/el2-RW memory 0xA00F0000*/
     .NONSECUREel1ttSection :
    {
     . = 0xA00F0000;
     __tt_start__ = .;
     *(.NONSECUREttstg1ForEl1nsection_ass_el2*)
     *(.NONSECUREttstg2ForEl1nsection_ass_el2*)
     __tt_end__ = .;
    } > lower_dram0_top_shared
    
     /* EL1 vector tables in shared memory, and handler funcs */
     .NONSECUREel1vtSection :
    {
     . = 0xA00F2000;
     __vt_start__ = .;
     *(.NONSECUREvectortableel1N_ass_el2*)
     *(.NONSECUREhandlerFuncSectionEL1_c_el2*)
     __vt_end__ = .;
    } > lower_dram0_top_shared
    
     
            
     /* --------------upper_dram0_all--------------------------*/
     
    /*NON-SECURE SECTIONS IF THEY EXIST*/
    
    /*el1 read only data section*/
    
    NONSECUREsection_el1_rodata :
    {
    /* start of el1 memory */
    _start_el1 = .;
    . = ALIGN(16);
    __NONSECUREsection_el1_rodata_start__ = .;
    *(.el1_rodata*)
    __NONSECUREsection_el1_rodata_end__ = .;
    } > upper_dram0_all
    
     /*el1 bss section*/
    
    .NONSECUREsection_el1_bss :
    {
    . = ALIGN(16);
    __NONSECUREsection_el1_bss_start__ = .;
    *(.el1_bss*)
    __NONSECUREsection_el1_bss_end__ = .;
    } > upper_dram0_all
       
    
    /* el1n program code */
        
   .NONSECUREsection_el1n :
    {
    . = ALIGN(16);
    __NONSECUREsection_el1n_start__ = .;
    *(.NONSECUREel1entrysection_ass_el1*)
    *(.NONSECUREel1ntestsection_ass_el1*)
    *(.NONSECUREsection_c_el1*)
	*(.NONSECUREStringSection_c_el1*)
	*(.NONSECUREuartFuncSection_c*)
    *(.NONSECUREuartStructSection_c*)
    } > upper_dram0_all
    
     /*moved to separate section to remove zero padding from the elf file to reduce its size*/
      .NONSECUREsection_el1_pcc_bounds ALIGN(1048576): {	
    /* need to align end of el1 code section to 0x100000hex, 1048576 */
    /* because nearest bounds limit can set is 0xc010000  for EL1 PCC */
    /* otherwise exact bounds clears the tag bit */
    /* non-exact bounds does not clear tag, but 0xc010000 is nearest bounds it can set */
    /* . = ALIGN(1048576); */
    __NONSECUREsection_el1n_end__ = .;
    } > upper_dram0_all
    
   
  /*..................................*/
  /* enclave code */
  
    . = ALIGN(16);
  .enclave.sensor.text   :
  {
  enclave_code_start = .;
    /*sensor_code_start = .;*/
    *(.enclave.sensor.text)
    . = ALIGN(16);
     sensor_code_end = .;
  }> upper_dram0_all
  .enclave.user.text   :
  {
    . = ALIGN(16);
   /* user_code_start = .;*/
    *(.enclave.user.text)
  }> upper_dram0_all
  .enclave.sensor.id   :
  {
    *(.enclave.sensor.id)
    . = ALIGN(16);
    user_code_end = .;
    enclave_code_end = .;
  } > upper_dram0_all
  /*..................................*/ 
    
    /*..................................*/ 
    /*No proper heap defined
    /*..................................*/
    
 
    /*..................................*/  
    /* non secure stack */
        /* align to 0x10000 (2^16 bits) boundary because of stack size*/
    /* and setting bounds of stack capability due to bounds compression */
    /* If you do not align, the tag bit gets cleared when setting the bounds */
    .stack_el1n (NOLOAD): ALIGN(65536)
    {
    	/* align stack to 16 bytes */
        /*. = ALIGN(16);*/
        _stack_el1n_limit = .;
        . = . + STACK_SIZE;
        _stack_el1n_base = .;
    } > upper_dram0_all
   /*..................................*/ 
   
   
   /*..................................*/ 
  /* enclave memory for unique alloc*/  
  /* set a section called .heap with a fixed size here */
  /* with a base and a limit that are opposite to stack as */
  /* heap grows up and stack grows down */
       .heap_el1n (NOLOAD): ALIGN(16)
    {
        _heap_el1n_base = .;
        . = . + HEAP_EL1_SIZE;
        _heap_el1n_limit = .;
        _el1n_end = .;
    } > upper_dram0_all 
    /*..................................*/
    
    
    
    . = ALIGN(16);      
    end = .; /* non capability heap starts here for EL3*/
    __end__ = .; /* added for Morello-purecap -doesn't compile without this, might need to move further up to indicate where heap should start */
}
	 /* ----------------------------------------------------*/

