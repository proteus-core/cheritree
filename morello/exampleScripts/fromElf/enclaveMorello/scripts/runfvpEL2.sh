#---------------------------------------------------------------------------
# Step 3 -fvp
# run fvp Morello at EL2
#---------------------------------------------------------------------------

#edit these paths
DIRMOR="/home/projects/morello_workspace"
DIRSCRIPTS="/home/projects/morello/exampleScripts"


 $DIRMOR/model_011_33/FVP_Morello/models/Linux64_GCC-6.4/FVP_Morello \
--data Morello_Top.css.scp.armcortexm7ct=$DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/scp_romfw.bin@0x0 \
--data Morello_Top.css.mcp.armcortexm7ct=$DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/mcp_romfw.bin@0x0 \
-C Morello_Top.soc.scp_qspi_loader.fname=$DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/scp_fw.bin \
-C Morello_Top.soc.mcp_qspi_loader.fname=$DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/mcp_fw.bin \
-C css.scp.armcortexm7ct.INITVTOR=0x0 \
-C css.mcp.armcortexm7ct.INITVTOR=0x0 \
-C css.trustedBootROMloader.fname=$DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/bl1.bin \
-C board.ap_qspi_loader.fname=$DIRSCRIPTS/fromElf/enclaveMorello/fvpbinaries/withCapabilities/fip.bin \
-C css.pl011_uart_ap.out_file=uart0.log \
-C css.scp.pl011_uart_scp.out_file=scp.log \
-C css.mcp.pl011_uart0_mcp.out_file=mcp.log \
-C css.pl011_uart_ap.unbuffered_output=1 \
--run --cadi-server

#--run

#created location of files
#fip.bin and bl1.bin for program code
#-C css.trustedBootROMloader.fname=/<path>/morello_workspace/bsp/arm-tf/build/morello/release/bl1.bin \
#-C board.ap_qspi_loader.fname=/<path>/morello_workspace/bsp/arm-tf/build/morello/release/fip.bin \

#other fvp firmware files
#scp_romfw.bin mcp_romfw.bin scp_fw.bin mcp_fw.bin standard fvp firmware
# /<path>/morello_workspace/output/fvp/firmware/

