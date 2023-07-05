package riscv.plugins

import riscv._

import spinal.core._

class BranchUnit(branchStage: Stage) extends Plugin[Pipeline] {
  object BranchCondition extends SpinalEnum {
    val NONE, EQ, NE, LT, GE, LTU, GEU = newElement()
  }

  object Data {
    object BU_IS_BRANCH extends PipelineData(Bool())
    object BU_WRITE_RET_ADDR_TO_RD extends PipelineData(Bool())
    object BU_IGNORE_TARGET_LSB extends PipelineData(Bool())
    object BU_CONDITION extends PipelineData(BranchCondition())
  }

  override def setup(): Unit = {
    val alu = pipeline.getService[IntAluService]
    val issuer = pipeline.getService[IssueService]

    pipeline.getService[DecoderService].configure {config =>
      config.addDefault(Map(
        Data.BU_IS_BRANCH -> False,
        Data.BU_WRITE_RET_ADDR_TO_RD -> False,
        Data.BU_IGNORE_TARGET_LSB -> False,
        Data.BU_CONDITION -> BranchCondition.NONE
      ))

      config.addDecoding(Opcodes.JAL, InstructionType.J, Map(
        Data.BU_IS_BRANCH -> True,
        Data.BU_WRITE_RET_ADDR_TO_RD -> True
      ))

      issuer.setDestination(Opcodes.JAL, branchStage)

      alu.addOperation(Opcodes.JAL, alu.AluOp.ADD,
                       alu.Src1Select.PC, alu.Src2Select.IMM)

      config.addDecoding(Opcodes.JALR, InstructionType.I, Map(
        Data.BU_IS_BRANCH -> True,
        Data.BU_WRITE_RET_ADDR_TO_RD -> True,
        Data.BU_IGNORE_TARGET_LSB -> True
      ))

      issuer.setDestination(Opcodes.JALR, branchStage)

      alu.addOperation(Opcodes.JALR, alu.AluOp.ADD,
                       alu.Src1Select.RS1, alu.Src2Select.IMM)

      val branchConditions = Map(
        Opcodes.BEQ  -> BranchCondition.EQ,
        Opcodes.BNE  -> BranchCondition.NE,
        Opcodes.BLT  -> BranchCondition.LT,
        Opcodes.BGE  -> BranchCondition.GE,
        Opcodes.BLTU -> BranchCondition.LTU,
        Opcodes.BGEU -> BranchCondition.GEU
      )

      for ((opcode, condition) <- branchConditions) {
        config.addDecoding(opcode, InstructionType.B, Map(
          Data.BU_IS_BRANCH -> True,
          Data.BU_CONDITION -> condition
        ))

        issuer.setDestination(opcode, branchStage)

        alu.addOperation(opcode, alu.AluOp.ADD,
                         alu.Src1Select.PC, alu.Src2Select.IMM)
      }
    }
  }

  override def build(): Unit = {
    branchStage plug new Area {
      import branchStage._

      val aluResultData = pipeline.getService[IntAluService].resultData
      val target = aluResultData.dataType()
      target := value(aluResultData)

      when (value(Data.BU_IGNORE_TARGET_LSB)) {
        target(0) := False
      }

      val misaligned = target(1 downto 0).orR

      val src1, src2 = UInt(config.xlen bits)
      src1 := value(pipeline.data.RS1_DATA)
      src2 := value(pipeline.data.RS2_DATA)

      val eq = src1 === src2
      val ne = !eq
      val lt = src1.asSInt < src2.asSInt
      val ltu = src1 < src2
      val ge = !lt
      val geu = !ltu

      val condition = value(Data.BU_CONDITION)

      val branchTaken = condition.mux(
        BranchCondition.NONE -> True,
        BranchCondition.EQ   -> eq,
        BranchCondition.NE   -> ne,
        BranchCondition.LT   -> lt,
        BranchCondition.GE   -> ge,
        BranchCondition.LTU  -> ltu,
        BranchCondition.GEU  -> geu
      )

      val jumpService = pipeline.getService[JumpService]

      when (arbitration.isValid && value(Data.BU_IS_BRANCH)) {
        when (condition =/= BranchCondition.NONE) {
          arbitration.rs1Needed := True
          arbitration.rs2Needed := True
        }

        when (branchTaken && !arbitration.isStalled) {
          jumpService.jump(branchStage, target)

          when (value(Data.BU_WRITE_RET_ADDR_TO_RD)) {
            output(pipeline.data.RD_DATA) := input(pipeline.data.NEXT_PC)
            output(pipeline.data.RD_VALID) := True
          }
        }
      }
    }
  }
}
