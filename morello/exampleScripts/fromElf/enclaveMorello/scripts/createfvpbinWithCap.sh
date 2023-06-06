#---------------------------------------------------------------------------
# step 2 for fvp
# create prog at EL2 binaries for FVP
#---------------------------------------------------------------------------

#The commands below will generate fip.bin and bl1.bin under the <morello_workspace>/bsp/arm-tf/build/morello/release/ directory. It assumes the rest of the firmware has been built already
#The rest of the fvp firmware is located under <morello_workspace>/output/fvp/firmware/

#run this "createfvpbinWithCap" file from the Morello_workspace directory
#./../morello/exampleScripts/fromElf/enclaveMorello/scripts/createfvpbinWithCap.sh 

#edit these paths
DIRMOR="/home/projects/morello_workspace"
DIRSCRIPTS="/home/projects/morello/exampleScripts"

make -C $DIRMOR"/bsp/arm-tf" PLAT=morello TARGET_PLATFORM=fvp clean
MBEDTLS_DIR=$DIRMOR"/bsp/deps/mbedtls" CROSS_COMPILE=$DIRMOR"/tools/clang/bin/llvm-" make -C $DIRMOR"/bsp/arm-tf" CC=$DIRMOR"/tools/clang/bin/clang" LD=$DIRMOR"/tools/clang/bin/ld.lld" PLAT=morello ARCH=aarch64 TARGET_PLATFORM=fvp ENABLE_MORELLO_CAP=1 E=0 TRUSTED_BOARD_BOOT=1 GENERATE_COT=1 ARM_ROTPK_LOCATION="devel_rsa" ROT_KEY=$DIRMOR"/bsp/arm-tf/plat/arm/board/common/rotpk/arm_rotprivk_rsa.pem" BL33=$DIRSCRIPTS/fromElf/enclaveMorello/progbinaries/withCapabilities/enclaveMorello all fip

#copy files to project directory "/fvpbinaries"
#cp -a source/. destination/
#copy fip.bin and bl1.bin for program code
cp -a $DIRMOR/bsp/arm-tf/build/morello/release/fip.bin $DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/fip.bin
cp -a $DIRMOR/bsp/arm-tf/build/morello/release/bl1.bin $DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/bl1.bin
#copy scp_romfw.bin mcp_romfw.bin scp_fw.bin mcp_fw.bin standard fvp firmware
cp -a $DIRMOR/output/fvp/firmware/scp_romfw.bin $DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/scp_romfw.bin
cp -a $DIRMOR/output/fvp/firmware/mcp_romfw.bin $DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/mcp_romfw.bin
cp -a $DIRMOR/output/fvp/firmware/scp_fw.bin $DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/scp_fw.bin
cp -a $DIRMOR/output/fvp/firmware/mcp_fw.bin $DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/mcp_fw.bin
