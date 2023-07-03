/*
 ============================================================================
 Name        : enclaveIDManager.c
 Author      : CAP-TEE
 Version     :
 Copyright   : CAP-TEE 2022
 Description : Enclave ID counter
 ============================================================================
 */
//*****************************************
// DEFINES AND INCLUDES
//*****************************************

//system/lib includes
#include <EL2Code/instructions/enclaveIDManager.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h> //to use bool/true/false
//program includes

//---------------------------------------------------------
//Define parameters for enclave ID counter
//---------------------------------------------------------

//number of enclave id values available to generate
const int numEnclaveIds = (OTYPE_RANGE_END - OTYPE_RANGE_START)/4;

//initialise an enclave ID counter
int IDCounter = 0;

//********************************************
// FUNCTIONS
//********************************************
//--------------------------------------------
//validRange
//function to check valid input o-type range
//function only used in this file
//--------------------------------------------
//Output:
//boolean: pass check (true) / fail check (false)
//--------------------------------------------
bool validRange()
{
const int otypeEnd = OTYPE_RANGE_END;
const int otypeStart =	OTYPE_RANGE_START;
if (otypeStart >= 0 && otypeEnd >= 0 && (otypeEnd - otypeStart) % 4 == 0)
	{return true;} //pass
else
	{return false;} //fail
}

//--------------------------------------------
//initIDCounter
//initialise the counter if there is a valid o-type range
//--------------------------------------------
//Output:
//int: 0 success, 1 unsuccessful
//--------------------------------------------
int initIDCounter()
{
	//check input range of counter is valid
	if (validRange() == true)
	{
		//start id counter at 1 because Morello otype needs
		//to be > 3 else fails BRS instruction check later
		IDCounter = 1;
		return 0;
	}
	else
	{
		IDCounter = numEnclaveIds + 1; //set to bigger than max value
		return -1;
	}
}


//--------------------------------------------
//generateEnclaveID
//generate a temporary enclave ID to go in the table
//--------------------------------------------
//Output:
//int: 0 success, 1 unsuccessful
//--------------------------------------------
int generateEnclaveID()
{
	int nextID;
	//check counter does not exceed maximum number can generate
	if (IDCounter < numEnclaveIds + 1)
	{
		nextID = IDCounter;
		IDCounter++;
		return nextID;
	}
	//else fail
	else
	{
		return -1;
	}
}

