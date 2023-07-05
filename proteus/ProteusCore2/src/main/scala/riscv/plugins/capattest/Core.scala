package riscv.plugins.capattest

import riscv._
import riscv.soc._
import riscv.soc.devices._
import riscv.plugins.cheri
import riscv.sim._

import spinal.core._
import spinal.core.sim._
import spinal.lib._

object createPipeline {
  def apply(memStart: BigInt, memSize: BigInt)(implicit config: Config): ClassicRiscPipeline = {
    implicit val cheriContext = cheri.Context()

    val pipeline = cheri.createPipeline(memStart = memStart, memSize = memSize, build = false)

    pipeline.addPlugins(Seq(
      new EnclaveInit(pipeline.memory),
      new EnclaveIdManager(0 to 1024),
      new IdentityStore(numEntries = 32, idSize = 128 bits),
      new Hash
    ))

    pipeline.build()
    pipeline
  }
}


object SoC {
  def static(ramType: RamType): SoC = {
    new SoC(ramType, config => {
      createPipeline(memStart = 0x80000000L, memSize = ramType.size)(config)
    })
  }
}

object Core {
  def main(args: Array[String]) {
    SpinalVerilog(SoC.static(RamType.OnChipRam(128 KiB, args.headOption)))
  }
}

object CoreSim {
  def main(args: Array[String]) {
    SimConfig.withWave.compile(SoC.static(RamType.OnChipRam(128 KiB, Some(args(0))))).doSim {dut =>
      dut.clockDomain.forkStimulus(10)

      val byteDevSim = new StdioByteDev(dut.io.byteDev)

      var done = false

      while (!done) {
        dut.clockDomain.waitSampling()

        if (dut.io.charOut.valid.toBoolean) {
          val char = dut.io.charOut.payload.toInt.toChar

          if (char == 4) {
            println("Simulation halted by software")
            done = true
          } else {
            print(char)
          }
        }

        byteDevSim.eval()
      }
    }
  }
}

object CoreExtMem {
  def main(args: Array[String]) {
    SpinalVerilog(SoC.static(RamType.ExternalAxi4(128 KiB)))
  }
}
