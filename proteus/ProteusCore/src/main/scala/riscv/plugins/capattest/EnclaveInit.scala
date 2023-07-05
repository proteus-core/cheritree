package riscv.plugins.capattest

import riscv._
import riscv.plugins.cheri
import riscv.plugins.cheri._

import spinal.core._
import spinal.lib._
import spinal.lib.fsm._

class EnclaveInit(memStage: Stage)(implicit cheriContext: Context) extends Plugin[Pipeline] {
  private object Data {
    object E_INIT_CODE extends PipelineData(Bool())
    object E_INIT_DATA extends PipelineData(Bool())
    object E_STORE_ID  extends PipelineData(Bool())
  }

  private var regReadIo: RegisterFileReadIo = _
  private var scrIo: ScrIo = _

  override def setup(): Unit = {
    pipeline.getService[DecoderService].configure {config =>
      config.addDefault(Map(
        Data.E_INIT_CODE -> False,
        Data.E_INIT_DATA -> False,
        Data.E_STORE_ID  -> False
      ))

      config.addDecoding(Opcodes.EInitCode, cheri.InstructionType.R_CxC, Map(
        Data.E_INIT_CODE -> True
      ))

      config.addDecoding(Opcodes.EInitData, cheri.InstructionType.R_CCC, Map(
        Data.E_INIT_DATA -> True
      ))

      config.addDecoding(Opcodes.EStoreId, cheri.InstructionType.R_RCR, Map(
        Data.E_STORE_ID -> True
      ))
    }

    regReadIo = pipeline.getService[RegisterFileService].addExternalReadIo(memStage)
    scrIo = pipeline.getService[ScrService].getIo(memStage)
  }

  override def build(): Unit = {
    memStage plug new Area {
      import memStage._

      val eidManager = pipeline.getService[EnclaveIdService]
      val idStoreIo = pipeline.getService[IdentityStoreService].getIo(memStage)
      val capScanIo = pipeline.getService[MemoryTagger].createCapScanIo(memStage)
      val capBus = pipeline.getService[MemoryTagger].createCapBus(memStage)
      val hashService = pipeline.getService[HashService]
      val hashIo = hashService.getIo(memStage)
      val dbusCtrl = pipeline.getService[MemoryService].createInternalDBus(memStage)

      val cs1 = value(cheriContext.data.CS1_DATA)
      val cs2 = value(cheriContext.data.CS2_DATA)

      val currentAddress = Reg(UInt(config.xlen bits)).init(0)
      val currentWord = Reg(UInt(config.xlen bits)).init(0)

      val initFsm = new StateMachine {
        val ident = Reg(SealingCapability()).init(SealingCapability.Null)

        def finish(cd: PackedCapability) = {
          output(cheriContext.data.CD_DATA).assignFrom(cd)
          output(pipeline.data.RD_VALID) := True
          arbitration.isReady := True
          goto(idle)
        }

        def fail(): Unit = {
          finish(PackedCapability.Null)
        }

        val idle = StateEntryPoint()
        val initEntry = State()

        idle
          .whenIsActive {
            when (arbitration.isValid && value(Data.E_INIT_CODE)) {
              arbitration.rs1Needed := True
              arbitration.isReady := False

              when (arbitration.isRunning) {
                goto(initEntry)
              }
            }
          }

        initEntry
          .whenIsActive {
            arbitration.isReady := False

            val result = idStoreIo.initEntry()

            when (result.valid) {
              when (result.payload.valid) {
                val cd = PackedCapability()
                cd.assignFrom(cs1)
                cd.otype.value.allowOverride
                cd.otype.value := result.payload.identSeal.seal
                finish(cd)
              } otherwise {
                fail()
              }
            }
          }
      }

      val initDataFsm = new StateMachine {
        val uniquenessFsm = new StateMachine {
          val unique = True
          val currentAddress = Reg(UInt(config.xlen bits))
          val currentReg = currentAddress(4 downto 0)

          val scheduleService = pipeline.getService[ScheduleService]
          val scrService = pipeline.getService[ScrService]

          val overlaps = new Area {
            private val cap = PackedCapability().assignDontCare()
            private val cs1Overlaps = overlaps(cs1)
            private val cs2Overlaps = overlaps(cs2)
            private val anyOverlaps = cs1Overlaps || cs2Overlaps

            private def overlaps(c: Capability): Bool = {
              cap.tag && !(c.top <= cap.base) && !(c.base >= cap.top)
            }

            def apply(cap: Capability): Bool = {
              this.cap.assignFrom(cap)
              anyOverlaps
            }
          }

          def fail() = {
            unique := False
            exitFsm()
          }

          def claimPipeline() = scheduleService.claimPipeline(memStage)

          val START = StateEntryPoint()
          val CLAIM_PIPELINE = State()
          val CHECK_REGS = State()
          val CHECK_DDC = State()
          val CHECK_PCC = State()
          val CHECK_SCRS = State()
          val GET_ADDRESS = State()
          val GET_CAP = State()

          START.whenIsActive {
            capScanIo.init()
            goto(CLAIM_PIPELINE)
          }

          CLAIM_PIPELINE.whenIsActive {
            when (scheduleService.claimPipeline(memStage)) {
              goto(CHECK_REGS)
            }
          }

          CHECK_REGS.onEntry {
            currentReg := 1
          }

          CHECK_REGS.whenIsActive {
            scheduleService.claimPipeline(memStage)

            val rs1 = value(pipeline.data.RS1)
            val rs2 = value(pipeline.data.RS2)

            when (currentReg =/= rs1 && currentReg =/= rs2) {
              val regCap = regReadIo.read(currentReg)

              when (overlaps(regCap)) {
                unique := False
                exitFsm()
              }
            }

            when (!wantExit) {
              when (currentReg === config.numRegs - 1) {
                goto(CHECK_DDC)
              } otherwise {
                currentReg := currentReg + 1
              }
            }
          }

          CHECK_DDC.whenIsActive {
            claimPipeline()

            when (overlaps(scrService.getDdc(memStage))) {
              fail()
            } otherwise {
              goto(CHECK_PCC)
            }
          }

          CHECK_PCC.whenIsActive {
            claimPipeline()

            when (overlaps(scrService.getPcc(memStage))) {
              fail()
            } otherwise {
              goto(CHECK_SCRS)
            }
          }

          CHECK_SCRS.onEntry {
            currentReg := 0
          }

          CHECK_SCRS.whenIsActive {
            // Lookup table for registered SCR IDs.
            val scrIds = Mem(scrService.getRegisteredScrs.map(U(_, 5 bits)))

            claimPipeline()
            scrIo.valid := True
            scrIo.write := False
            scrIo.id := scrIds(currentReg.resized)
            scrIo.hasAsr := True

            when (overlaps(scrIo.rdata)) {
              fail()
            } elsewhen (currentReg === scrIds.wordCount - 1) {
              goto(GET_ADDRESS)
            } otherwise {
              currentReg := currentReg + 1
            }
          }

          GET_ADDRESS.whenIsActive {
            val result = capScanIo.next()

            when (result.ready) {
              when (result.valid) {
                currentAddress := result.address
                goto(GET_CAP)
              } otherwise {
                exitFsm()
              }
            }
          }

          GET_CAP.whenIsActive {
            capBus.cmd.address := currentAddress
            capBus.cmd.payload.write := False
            capBus.cmd.valid := True

            when (capBus.rsp.valid) {
              val cap = capBus.rsp.rdata

              when (overlaps(cap)) {
                unique := False
                exitFsm()
              } otherwise {
                goto(GET_ADDRESS)
              }
            }
          }
        }

        val hashFsm = new StateMachine {
          val isLastWord = currentAddress === cs1.top

          val START = StateEntryPoint()
          val LOAD_WORD = State()
          val HASH_WORD = State()

          START.whenIsActive {
            hashIo.init := True
            currentAddress := cs1.base
            goto(LOAD_WORD)
          }

          LOAD_WORD.whenIsActive {
            val (ready, word) = dbusCtrl.read(currentAddress)

            when (ready) {
              currentWord := word
              currentAddress := currentAddress + config.xlen / 8
              goto(HASH_WORD)
            }
          }

          HASH_WORD.whenIsActive {
            hashIo.cmd.valid := True
            hashIo.cmd.payload.fragment.msg := EndiannessSwap(currentWord.asBits)
            hashIo.cmd.payload.fragment.size := U"11"
            hashIo.cmd.payload.last := isLastWord

            when (hashIo.cmd.ready) {
              when (isLastWord) {
                exitFsm()
              } otherwise {
                goto(LOAD_WORD)
              }
            }
          }
        }

        def finish(cd: Capability) = {
          output(cheriContext.data.CD_DATA).assignFrom(cd)
          output(pipeline.data.RD_VALID) := True
          arbitration.isReady := True
          goto(IDLE)
        }

        def fail(): Unit = {
          finish(PackedCapability.Null)
        }

        val IDLE = StateEntryPoint()
        val CHECK_CS1_VALID = State()
        val CHECK_UNIQUENESS = new StateFsm(uniquenessFsm)
        val HASH_ID = new StateFsm(hashFsm)
        val STORE_HASH = State()
        val STORE_SEAL = State()
        val DONE = State()

        val currentEid = Reg(eidManager.hardType()).init(eidManager.hardType().setInvalid())

        IDLE.whenIsActive {
          when (arbitration.isValid && value(Data.E_INIT_DATA)) {
            arbitration.rs1Needed := True
            arbitration.rs2Needed := True
            arbitration.isReady := False
            currentEid.setInvalid()

            when (arbitration.isRunning) {
              goto(CHECK_CS1_VALID)
            }
          }
        }

        CHECK_CS1_VALID.whenIsActive {
          arbitration.isReady := False
          val unfinishedEntry = idStoreIo.getUnfinishedEntry(cs1.otype.value)

          when (!cs1.tag || !cs1.isSealed) {
            fail()
          } elsewhen (unfinishedEntry.valid) {
            when (unfinishedEntry.payload.valid) {
              currentEid := unfinishedEntry.payload
              goto(CHECK_UNIQUENESS)
            } otherwise {
              fail()
            }
          }
        }

        CHECK_UNIQUENESS.whenIsActive {
          arbitration.isReady := False

          when (uniquenessFsm.wantExit) {
            when (uniquenessFsm.unique) {
              goto(HASH_ID)
            } otherwise {
              fail()
            }
          }
        }

        HASH_ID.whenIsActive {
          arbitration.isReady := False

          when (hashFsm.wantExit) {
            goto(STORE_HASH)
          }
        }

        STORE_HASH.whenIsActive {
          arbitration.isReady := False
          val result = idStoreIo.finishEntry(cs1.otype.value, hashIo.rsp.payload.digest)

          when (result.valid) {
            when (result.payload.valid) {
              goto(STORE_SEAL)
            } otherwise {
              fail()
            }
          }
        }

        STORE_SEAL.whenIsActive {
          arbitration.isReady := False

          capBus.cmd.payload.address := cs2.base // TODO base or address?
          capBus.cmd.payload.write := True
          capBus.cmd.payload.wdata.assignFrom(currentEid.signEncSeal)
          capBus.cmd.valid := True

          when (capBus.cmd.ready) {
            val cd = PackedCapability()
            cd.assignFrom(cs2)
            cd.otype.value.allowOverride
            cd.otype.value := currentEid.identSeal.seal
            finish(cd)
          }
        }

        DONE.whenIsActive {
          goto(IDLE)
        }
      }

      val storeIdFsm = new StateMachine {
        // TODO reuse hash storage in IdentityStore (i.e., keep the hashResult valid)
        val hash = Reg(Bits(hashService.hashWidth)).init(0)
        val numHashWords = hashService.hashWidth.value / config.xlen
        val hashIdx = Counter(numHashWords)

        val IDLE = StateEntryPoint()
        val GET_HASH = State()
        val STORE_HASH = State()

        def finish(result: UInt) = {
          output(pipeline.data.RD_DATA) := result
          output(pipeline.data.RD_VALID) := True
          arbitration.isReady := True
          goto(IDLE)
        }

        def succeed() = finish(1)
        def fail() = finish(0)

        IDLE.whenIsActive {
          when (arbitration.isValid && value(Data.E_STORE_ID)) {
            arbitration.rs1Needed := True
            arbitration.rs2Needed := True
            arbitration.isReady := False

            when (arbitration.isRunning) {
              // TODO check if we can use the existing permission checks for this
              when (!cs2.isSealed
                && cs2.perms.store
                && (cs2.length - cs2.offset) >= (hashService.hashWidth.value / 8)
              ) {
                goto(GET_HASH)
              } otherwise {
                // TODO we should probably raise an exception here
                fail()
              }
            }
          }
        }

        GET_HASH.whenIsActive {
          arbitration.isReady := False
          val hashResult = idStoreIo.getHash(value(pipeline.data.RS1_DATA))

          when (hashResult.valid) {
            when (hashResult.payload.isDefined) {
              hash := hashResult.payload.value
              hashIdx.clear()
              currentAddress := cs2.address
              goto(STORE_HASH)
            } otherwise {
              fail()
            }
          }
        }

        STORE_HASH.whenIsActive {
          arbitration.isReady := False
          val hashWords = hash.subdivideIn(config.xlen bits)
          val currentHashWord = hashWords(numHashWords - 1 - hashIdx.value).asUInt
          val ready = dbusCtrl.write(currentAddress, EndiannessSwap(currentHashWord), B"1111")

          when (ready) {
            when (hashIdx.willOverflowIfInc) {
              succeed()
            } otherwise {
              hashIdx.increment()
              currentAddress := currentAddress + config.xlen / 8
            }
          }
        }
      }
    }
  }
}
