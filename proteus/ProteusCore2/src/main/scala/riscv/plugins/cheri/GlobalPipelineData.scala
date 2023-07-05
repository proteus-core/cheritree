package riscv.plugins.cheri

import riscv._

class GlobalPipelineData(implicit context: Context) {
  object CS1_DATA extends PipelineData(RegCapability())
  object CS2_DATA extends PipelineData(RegCapability())
  object CD_DATA extends PipelineData(RegCapability())
}
