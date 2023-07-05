package riscv.plugins.capattest

import spinal.core._

object Opcodes {
  val EInitCode = M"111111110011-----000-----1011011"
  val EInitData = M"0000110----------000-----1011011"
  val EStoreId  = M"0000010----------000-----1011011"
}
