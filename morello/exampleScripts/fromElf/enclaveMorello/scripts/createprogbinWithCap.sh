#---------------------------------------------------------------------------
# Step 1
# create program at EL2 BL33 binaries from an elf file, ready to package up for fvp or soc
#---------------------------------------------------------------------------

#run from the fromElf/enclaveMorello/scripts directory

#The commands below will copy the elf output file and turn it into a binary output to run directly on the FVP or soc at EL2

#edit these paths
DIRIMAGE="/home/projects/morello/exampleScripts/fromElf/enclaveMorello/makeImage"
DIRSRC="/home/projects/morello/project/enclaveMorello/build"

#check if destination does not exist
DIR1="../progbinaries"
DIR2="../progbinaries/withCapabilities"
DIR3="../socbinaries"
DIR4="../socbinaries/withCapabilities"
DIR5="../fvpbinaries"
DIR6="../fvpbinaries/withCapabilities"
if test ! -d $DIR1 ; then  echo "creating directory ${DIR1}..."; mkdir ${DIR1}; fi
if test ! -d $DIR2 ; then  echo "creating directory ${DIR2}..."; mkdir ${DIR2}; fi
if test ! -d $DIR3 ; then  echo "creating directory ${DIR3}..."; mkdir ${DIR3}; fi
if test ! -d $DIR4 ; then  echo "creating directory ${DIR4}..."; mkdir ${DIR4}; fi
if test ! -d $DIR5 ; then  echo "creating directory ${DIR5}..."; mkdir ${DIR5}; fi
if test ! -d $DIR6 ; then  echo "creating directory ${DIR6}..."; mkdir ${DIR6}; fi

#copy elf output 
cp -a $DIRSRC/enclaveMorello.elf $DIR2/enclaveMorello.elf

# put program into a loader to load into SDRAM at wanted locations (0x80000000)
$DIRIMAGE/make-bm-image_el2.sh -i ../progbinaries/withCapabilities/enclaveMorello.elf -o ../progbinaries/withCapabilities/enclaveMorello
