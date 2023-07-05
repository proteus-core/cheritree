package riscv.plugins.cheri

import riscv._
import riscv.sim._
import riscv.soc._

import spinal.core._
import spinal.core.sim._

object createPipeline {
  def apply(memStart: BigInt, memSize: BigInt, build: Boolean = true)
           (implicit conf: Config, context: Context): ClassicRiscPipeline = {
    val pipeline = new ClassicRiscPipeline

    import riscv.{plugins => rvp}

    pipeline.addPlugins(Seq(
      new rvp.scheduling.static.Scheduler,
      new rvp.scheduling.static.DataHazardResolver(firstRsReadStage = pipeline.execute),
      new rvp.scheduling.static.TrapHandler(pipeline.writeback),
      new rvp.MemoryBackbone,
      new rvp.Fetcher(pipeline.fetch),
      new rvp.Decoder(pipeline.decode),
      new rvp.RegisterFile(pipeline.decode, pipeline.writeback),
      new rvp.IntAlu(pipeline.execute),
      new rvp.Shifter(pipeline.execute),
      new rvp.Lsu(pipeline.memory),
      new rvp.BranchUnit(pipeline.execute),
      new rvp.scheduling.static.PcManager(memStart),
      new rvp.CsrFile(pipeline.writeback),
      new rvp.Timers,
      new rvp.MachineMode(pipeline.execute, addMepc = false, addMtvec = false),
      new rvp.Interrupts(pipeline.writeback),
      new rvp.MulDiv(pipeline.execute)
    ))

    pipeline.addPlugins(Seq(
      new RegisterFile(pipeline.decode, pipeline.writeback),
      new Access(pipeline.execute),
      new ScrFile(pipeline.writeback),
      new Lsu(pipeline.memory),
      new ExceptionHandler,
      new Ccsr,
      new MemoryTagger(memStart, memSize),
      new PccManager(pipeline.execute),
      new Sealing(pipeline.execute),
      new MachineMode
    ))

    if (build) {
      pipeline.build()
    }

    pipeline
  }
}

object SoC {
  def static(ramType: RamType): SoC = {
    new SoC(ramType, config => {
      implicit val context = Context()(config)
      createPipeline(memStart = 0x80000000L, memSize = ramType.size)(config, context)
    })
  }
}

object Core {
  def main(args: Array[String]) {
    SpinalVerilog(SoC.static(RamType.OnChipRam(10 MiB, args.headOption)))
  }
}

object CoreSim {
  def main(args: Array[String]) {
    SimConfig.withWave.compile(SoC.static(RamType.OnChipRam(10 MiB, Some(args(0))))).doSim {dut =>
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
    SpinalVerilog(SoC.static(RamType.ExternalAxi4(10 MiB)))
  }
}
