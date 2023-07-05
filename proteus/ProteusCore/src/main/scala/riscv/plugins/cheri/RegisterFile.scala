package riscv.plugins.cheri

import riscv._
import spinal.core._
import spinal.lib._

class RegisterFile(readStage: Stage, writeStage: Stage)
                  (implicit context: Context)
  extends Plugin[Pipeline] with RegisterFileService {
  private case class ExternalReadIo()
    extends Bundle with RegisterFileReadIo with IMasterSlave {
    val valid = Bool()
    val cs = UInt(5 bits)
    val csData = RegCapability()

    override def read(cs: UInt): Capability = {
      this.cs := cs
      this.valid := True
      this.csData
    }

    override def asMaster(): Unit = {
      in(valid, cs)
      out(csData)
    }
  }

  private var externalReadIo: Option[ExternalReadIo] = None

  override def addExternalReadIo(stage: Stage): RegisterFileReadIo = {
    assert(externalReadIo.isEmpty)

    val area = stage plug new Area {
      val regReadIo = slave(ExternalReadIo())
      regReadIo.valid := False
      regReadIo.cs.assignDontCare()
    }

    externalReadIo = Some(area.regReadIo)
    area.regReadIo
  }

  override def setup(): Unit = {
    val decoder = pipeline.getService[DecoderService]

    decoder.configure {config =>
      config.addDefault(context.data.CD_DATA, RegCapability.Null)
    }

    val hazardInfo = DataHazardInfo(
      RegisterType.CAP,
      context.data.CS1_DATA,
      context.data.CS2_DATA,
      context.data.CD_DATA
    )

    pipeline.getService[DataHazardService].addHazard(hazardInfo)
  }

  override def build(): Unit = {
    case class ReadIo() extends Bundle with IMasterSlave {
      val cs1 = UInt(5 bits)
      val cs2 = UInt(5 bits)
      val cs1Data = RegCapability()
      val cs2Data = RegCapability()

      override def asMaster(): Unit = {
        in(cs1, cs2)
        out(cs1Data, cs2Data)
      }
    }

    case class WriteIo() extends Bundle with IMasterSlave {
      val cd = UInt(5 bits)
      val data = RegCapability()
      val write = Bool()

      override def asMaster(): Unit = {
        in(cd, data, write)
      }
    }

    val regFile = pipeline plug new Component {
      setDefinitionName("CapabilityRegisterFile")

      val readIo = master(ReadIo())
      val writeIo = master(WriteIo())
      val regs = Mem(RegCapability(), Seq.fill(config.numRegs) {RegCapability.Null})

      // Add a wire for each register with a readable name. This is to easily
      // view register values in a wave dump.
      for (i <- 0 until config.numRegs) {
        val regWire = RegCapability()
        regWire.setName(s"c$i")
        regWire := regs.readAsync(U(i).resized, writeFirst)
      }

      def readReg(addr: UInt) = regs.readAsync(addr, writeFirst)
      readIo.cs1Data := readReg(readIo.cs1)
      readIo.cs2Data := readReg(readIo.cs2)

      when (writeIo.write && writeIo.cd =/= 0) {
        regs.write(writeIo.cd, writeIo.data)
      }
    }

    val readArea = readStage plug new Area {
      import readStage._

      val regFileIo = slave(ReadIo())

      regFileIo.cs1 := value(pipeline.data.RS1)
      regFileIo.cs2 := value(pipeline.data.RS2)
      output(context.data.CS1_DATA) := regFileIo.cs1Data
      output(context.data.CS2_DATA) := regFileIo.cs2Data
    }

    val writeArea = writeStage plug new Area {
      import writeStage._

      val regFileIo = slave(WriteIo())

      regFileIo.cd := value(pipeline.data.RD)
      regFileIo.data := value(context.data.CD_DATA)

      val trapHandler = pipeline.getService[TrapService]
      val hasTrapped = trapHandler.hasTrapped(writeStage)
      regFileIo.write :=
        (value(pipeline.data.RD_TYPE) === RegisterType.CAP) &&
        arbitration.isDone &&
        !hasTrapped
    }

    pipeline plug new Area {
      regFile.readIo <> readArea.regFileIo
      regFile.writeIo <> writeArea.regFileIo

      externalReadIo.foreach {io =>
        io.csData.assignDontCare()

        when (io.valid) {
          regFile.readIo.cs1 := io.cs
          io.csData := regFile.readIo.cs1Data
        }
      }
    }
  }
}
