package riscv.plugins.capattest

import riscv._
import riscv.plugins.cheri


import spinal.core._
import spinal.lib._

private case class Io(idWidth: BitCount)(implicit cheriContext: cheri.Context)
  extends Bundle with EnclaveIdIo with IMasterSlave {
  val generate = Bool()
  val result = EnclaveId(idWidth)
  val available = Bool()


  override def idAvailable: Bool = available

  override def generateEnclaveId(): EnclaveId = {
    generate := True
    result
  }

  override def asMaster(): Unit = {
    out(generate)
    in(result, available)
  }
}

class EnclaveIdManager(otypes: Range)(implicit cheriContext: cheri.Context)
  extends Plugin[Pipeline] with EnclaveIdService {
  assert(
    otypes.start >= 0 && otypes.start < cheriContext.maxOtype &&
    otypes.end >= 0 && otypes.end < cheriContext.maxOtype &&
    otypes.end > otypes.start &&
    otypes.step == 1 &&
    otypes.start % 4 == 0
  )

  private val numEnclaveIds = (otypes.end - otypes.start) / 4
  private val enclaveIdWidth = log2Up(numEnclaveIds) bits

  private var pipelineIo: Io = _
  private var masterIo: Option[Io] = None

  override def build(): Unit = {
    val area = pipeline plug new Area {
      val nextId = Counter(numEnclaveIds + 1)
      val io = Io(enclaveIdWidth)
      val available = !nextId.willOverflowIfInc
      io.result.assignDontCare()
      io.available := available

      when (io.generate) {
        when (available) {
          io.result := EnclaveId(nextId.resize(enclaveIdWidth))
          nextId.increment()
        }
      }
    }

    pipelineIo = area.io
  }


  override def finish(): Unit = {
    pipeline plug new Area {
      masterIo.foreach { io => pipelineIo <> io }
    }
  }

  override def hardType: HardType[EnclaveId] = {
    EnclaveId(enclaveIdWidth)
  }

  override def createIo(component: Component): EnclaveIdIo = {
    assert(masterIo.isEmpty)

    val area = component plug new Area {
      val io = master(Io(enclaveIdWidth))
      io.generate := False
    }

    masterIo = Some(area.io)
    area.io
  }
}
