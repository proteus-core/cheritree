package riscv.plugins.capattest

import riscv._
import riscv.plugins.cheri._

import spinal.core._
import spinal.lib._
import spinal.lib.fsm._

private case class StoreIo(
  implicit context: Context,
  eidService: EnclaveIdService,
  hashService: HashService
)
  extends Bundle with IdentityStoreIo with IMasterSlave {
  // TODO replace these with an enum
  val init, getUnfinished, finish, getIdHash = Bool()
  val eid = eidService.hardType()
  val hash = Bits(hashService.hashWidth)
  val result = Flow(eidService.hardType())
  val hashResult = Flow(Optional(Bits(hashService.hashWidth)))

  override def initEntry(): Flow[EnclaveId] = {
    init := True
    result
  }

  override def getUnfinishedEntry(identOtype: UInt): Flow[EnclaveId] = {
    getUnfinished := True
    eid := eidService.hardType().assignFromOtype(identOtype)
    result
  }

  override def finishEntry(identOtype: UInt, hash: Bits): Flow[EnclaveId] = {
    finish := True
    eid := eidService.hardType().assignFromOtype(identOtype)
    this.hash := hash
    result
  }


  override def getHash(otype: UInt): Flow[Optional[Bits]] = {
    getIdHash := True
    eid := eidService.hardType().assignFromOtype(otype)
    hashResult
  }

  override def asMaster(): Unit = {
    out(init, getUnfinished, finish, getIdHash, eid, hash)
    in(result, hashResult)
  }
}

private case class Entry(
  implicit eidService: EnclaveIdService,
  hashService: HashService
) extends Bundle {
  val used, ready = Bool()
  val id = eidService.hardType()
  val hash = Bits(hashService.hashWidth)
}

private object Entry {
  def Empty(implicit eidService: EnclaveIdService, hashService: HashService): Entry = {
    val entry = Entry()
    entry.used := False
    entry.ready := False
    entry.id.setInvalid()
    entry.hash := 0
    entry
  }
}

class IdentityStore(numEntries: Int, idSize: BitCount)(implicit context: Context)
  extends Plugin[Pipeline] with IdentityStoreService {
  assert(numEntries > 0)

  private var componentIo: StoreIo = _
  private var stageIo: Option[StoreIo] = None

  override def build(): Unit = {
    val component = pipeline plug new Component {
      setDefinitionName("IdentityStore")

      implicit val eidService = pipeline.getService[EnclaveIdService]
      implicit val hashService = pipeline.getService[HashService]
      val idIo = eidService.createIo(this)

      val io = slave(StoreIo())
      io.result.valid := False
      io.result.payload.assignDontCare()
      io.hashResult.valid := False
      io.hashResult.payload.assignDontCare()

      val entries = Mem(Seq.fill(numEntries) { Entry.Empty })

      for (i <- 0 to numEntries) {
        val entry = Entry().setName(s"entry_$i")
        entry := entries.readAsync(U(i).resized, writeFirst)
      }

      val fsm = new StateMachine {
        val searchIdx = Counter(numEntries)

        val idle = new State with EntryPoint
        val initEntry = new State
        val getUnfinishedEntry = State()
        val finishEntry = State()
        val getHash = State()

        def fail() = {
          io.result.push(eidService.hardType().setInvalid())
        }

        idle
          .whenIsActive {
            when (io.init) {
              when (idIo.idAvailable) {
                goto(initEntry)
              } otherwise {
                fail()
              }
            } elsewhen (io.getUnfinished) {
              when (io.eid.valid) {
                goto(getUnfinishedEntry)
              } otherwise {
                fail()
              }
            } elsewhen (io.finish) {
              when (io.eid.valid) {
                goto(finishEntry)
              } otherwise {
                fail()
              }
            } elsewhen (io.getIdHash) {
              when (io.eid.valid) {
                goto(getHash)
              } otherwise {
                fail()
              }
            }
          }

        initEntry
          .onEntry {
            searchIdx.clear()
          }
          .whenIsActive {
            when (!entries(searchIdx).used) {
              val newEntry = Entry.Empty.allowOverride
              newEntry.used := True
              newEntry.id := idIo.generateEnclaveId()
              entries(searchIdx) := newEntry

              io.result.push(newEntry.id)
              goto(idle)
            } elsewhen (searchIdx.willOverflowIfInc) {
              fail()
              goto(idle)
            } otherwise {
              searchIdx.increment()
            }
          }

        getUnfinishedEntry
          .onEntry {
            searchIdx.clear()
          }
          .whenIsActive {
            val entry = entries(searchIdx)

            when (entry.used && !entry.ready && entry.id === io.eid) {
              io.result.push(entry.id)
              goto(idle)
            } elsewhen (searchIdx.willOverflowIfInc) {
              fail()
              goto(idle)
            } otherwise {
              searchIdx.increment()
            }
          }

        finishEntry
          .onEntry {
            searchIdx.clear()
          }
          .whenIsActive {
            val entry = entries(searchIdx)

            when (entry.id === io.eid) {
              when (entry.used && !entry.ready) {
                val newEntry = Entry.Empty.allowOverride
                newEntry := entry
                newEntry.hash := io.hash
                newEntry.ready := True
                entries(searchIdx) := newEntry
                io.result.push(io.eid)
                goto(idle)
              } otherwise {
                fail()
                goto(idle)
              }
            } elsewhen (searchIdx.willOverflowIfInc) {
              fail()
              goto(idle)
            } otherwise {
              searchIdx.increment()
            }
          }

        // TODO maybe combine searching with finishEntry
        getHash
          .onEntry {
            searchIdx.clear()
          }
          .whenIsActive {
            def fail() = {
              io.hashResult.valid := True
              io.hashResult.payload.assignNone()
            }

            val entry = entries(searchIdx)

            when (entry.id === io.eid) {
              when (entry.used && entry.ready) {
                io.hashResult.push(Optional.some(entry.hash))
                goto(idle)
              } otherwise {
                fail()
                goto(idle)
              }
            } elsewhen (searchIdx.willOverflowIfInc) {
              fail()
              goto(idle)
            } otherwise {
              searchIdx.increment()
            }
          }
      }
    }

    componentIo = component.io
  }


  override def finish(): Unit = {
    pipeline plug new Area {
      stageIo.foreach(io => componentIo <> io)
    }
  }

  override def getIo(stage: Stage): IdentityStoreIo = {
    assert(stageIo.isEmpty)

    val stageArea = stage plug new Area {
      implicit val eidService = pipeline.getService[EnclaveIdService]
      implicit val hashService = pipeline.getService[HashService]
      val io = master(StoreIo())
      io.init := False
      io.getUnfinished := False
      io.finish := False
      io.getIdHash := False
      io.eid.setInvalid()
      io.hash := 0
    }

    stageIo = Some(stageArea.io)
    stageArea.io
  }
}
