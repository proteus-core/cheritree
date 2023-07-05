package riscv.plugins.capattest

import riscv._
import spinal.core._
import spinal.lib._
import spinal.crypto.hash._
import spinal.crypto.hash.sha2._

class Hash extends Plugin[Pipeline] with HashService {
  private val sha2Mode = SHA2_256

  // lazy because of access to config
  private lazy val hashConfig = HashCoreConfig(
    dataWidth      = config.xlen bits,
    hashWidth      = sha2Mode.hashWidth bits,
    hashBlockWidth = SHA2.blockWidth(sha2Mode) bits
  )

  private var pipelineIo: HashCoreIO = _
  private var stageIo: Option[HashCoreIO] = None

  override def build(): Unit = {
    pipeline plug new Area {
      val sha = new SHA2Core_Std(sha2Mode, hashConfig.dataWidth)
      pipelineIo = sha.io
    }
  }

  override def finish(): Unit = {
    pipeline plug {
      stageIo.map { io => pipelineIo <> io }
    }
  }

  override def hashWidth: BitCount = hashConfig.hashWidth

  override def getIo(stage: Stage): HashCoreIO = {
    assert(stageIo.isEmpty)

    val area = stage plug new Area {
      val io = master(HashCoreIO(hashConfig))
      io.init := False
      io.cmd.valid := False
      io.cmd.payload.assignDontCare()
    }

    stageIo = Some(area.io)
    area.io
  }
}
