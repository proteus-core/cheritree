/*
 ============================================================================
 Name        : performance.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2021
 Description : EL2/EL3 functions to measure number of cycles using the cycle counter register
               This code will be placed in EL2/EL3 memory section
 ============================================================================
 */


//*****************************************
// FUNCTIONS
//*****************************************

    // Performance counter settings
	//PMCCNTR_EL0 is the cycle counter
	//PMCCFILTR_EL0 and PMCR_EL0 control the cycle counter

	//PMCCFILTR_EL0.P[31] = 0 count cycles in EL1
	//PMCCFILTR_EL0.NSK[29] = .P count cycles in EL1 non secure
	//PMCCFILTR_EL0.NSH[27] = 1 count cycles in EL2
	//PMCCFILTR_EL0.SH[24] != .NSH count cycles in EL2 secure
	//PMCCFILTR_EL0.M[26] = .P count cycles in EL3

	//PMCR_EL0.D[3]=0 count every clock cycle
	//PMCR_EL0.C[2]=1 reset counter
	//PMCR_EL0.E[0]=1 enable counter

    //PMCNTENSET_EL0 [31]=1 enable cycle count register
    //PMCNTENCLR_EL0 [31]=1 disable cycle count register

//AUTOMATICALLY PLACED IN LOWER DRAM FOR EL2/3
//count cycles in EL1 and EL2
void setup_cycle_counterEL1and2(void)
{
	asm volatile(//set for EL1 and EL2
			     "MOV x13, #0\n\t"
			     //PMCCFILTR_EL0.NSH[27] = 1 count cycles in EL2
			     "ORR  x13, x13, #(1 << 27)\n\t"
				 "MSR  PMCCFILTR_EL0, x13\n\t"
				 //reset counter
			     //get current register value
			     "MRS x13, PMCR_EL0\n\t"
			     // bit[2] reset and bit[0] enable counter
				"ORR  x13, x13, #(1 << 2)\n\t"
			    "ORR  x13, x13, #(1 << 0)\n\t"
			    "MSR  PMCR_EL0, x13\n\t"
			    "ISB\n\t"
			    // remove reset, and count every clock cycle
			    // create mask 1111 1111 1111 0011
			    "MOV x14, #0xFFFF\n\t"
			    "MOVK x14, #0xFFF3,LSL #16\n\t"
			    // and mask with contents of register to set bit[2] and bit[3] to zero
			    "AND x13, x13, x14\n\t" // disable
			    "MSR PMCR_EL0, x13\n\t" // Write
			    "ISB\n\t"
			::: "x13", "x14", "cc");
}


//reset counter
void reset_cycle_counter(void)
{
	asm volatile(
				 //reset counter
			     //get current register value
			     "MRS x13, PMCR_EL0\n\t"
			     // bit[2] reset
				"ORR  x13, x13, #(1 << 2)\n\t"
			    "MSR  PMCR_EL0, x13\n\t"
			    "ISB\n\t"
			    // remove reset
			    // create mask 1111 1111 1111 1011
			    "MOV x14, #0xFFFF\n\t"
			    "MOVK x14, #0xFFFB,LSL #16\n\t"
			    // and mask with contents of register to remove bit[2]
			    "AND x13, x13, x14\n\t" // disable
			    "MSR PMCR_EL0, x13\n\t" // Write
			    "ISB\n\t"
			::: "x13", "x14", "cc");
}


//count cycles in EL1 only
void setup_cycle_counterEL1(void)
{

	asm volatile(//set for EL1
				 "MSR  PMCCFILTR_EL0, xzr\n\t"
				 //reset counter
			     //get current register value
			     "MRS x13, PMCR_EL0\n\t"
			     // bit[2] reset and bit[0] enable counter
				"ORR  x13, x13, #(1 << 2)\n\t"
			    "ORR  x13, x13, #(1 << 0)\n\t"
			    "MSR  PMCR_EL0, x13\n\t"
			    "ISB\n\t"
			    // remove reset, and count every clock cycle
			    // create mask 1111 1111 1111 0011
			    "MOV x14, #0xFFFF\n\t"
			    "MOVK x14, #0xFFF3,LSL #16\n\t"
			    // and mask with contents of register to set bit[2] and bit[3] to zero
			    "AND x13, x13, x14\n\t" // disable
			    "MSR PMCR_EL0, x13\n\t" // Write
			    "ISB\n\t"
			::: "x13", "x14", "cc");
}

unsigned long int read_cycle_counter(void)
{

    unsigned long int countVal;
	asm volatile("MRS  %x[countVal_ass], PMCCNTR_EL0\n\t" :[countVal_ass] "+r" (countVal)::);
	return countVal;
}

void enable_cycle_counter(void)
{
	asm volatile(//get current register value
			     //"MRS x13, PMCR_EL0\n\t"
			     "MRS x13, PMCNTENSET_EL0\n\t"
			     // bit[0]  enable
				 //"ORR  x13, x13, #(1 << 0)\n\t"
			     "ORR  x13, x13, #(1 << 31)\n\t"
			     // set register value and enable
			     //"MSR  PMCR_EL0, x13\n\t"
			     "MSR  PMCNTENSET_EL0, x13\n\t"
			     "ISB\n\t"
				 ::: "x13", "cc");
}

void disable_cycle_counter(void)
{

	asm volatile(//get current register value
			    "MRS x13, PMCNTENCLR_EL0\n\t"
			     // bit[31]  disable
			    "ORR  x13, x13, #(1 << 31)\n\t"
			    //set register
			    "MSR  PMCNTENCLR_EL0, x13\n\t"
			    "ISB\n\t"
				::: "x13", "cc");
}
