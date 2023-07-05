package riscv.plugins.capattest

import riscv.plugins.cheri._

import spinal.core._

class EnclaveId(idWidth: BitCount)(implicit context: Context) extends Bundle {
  val valid = Bool()
  val id = UInt(idWidth)

  // FIXME this would ideally be a val to not recreate the logic for every use. However, we also
  // don't want to add it as a member to the Bundle...
  private def otype = id << 2

  def setInvalid(): EnclaveId = {
    valid := False
    id.setAll()
    this
  }

  private def createSeal(id: UInt, numSeals: Int = 1): SealingCapability = {
    assert(id.getBitsWidth <= context.otypeLen)

    SealingCapability(id.resize(context.otypeLen), numSeals)
  }

  def signSeal = createSeal(otype)
  def encSeal = createSeal(otype + 1)
  def signEncSeal = createSeal(otype, 2)
  def identSeal = createSeal(otype + 2)

  def assignFromOtype(otype: UInt): this.type = {
    id := (otype >> 2).resized

    // TODO we should find a better validity check to ensure non-enclave seal
    // otypes cannot be mistaken for enclave IDs.
    valid := otype <= id.maxValue
    this
  }
}

object EnclaveId {
  def apply(idWidth: BitCount)(implicit context: Context): EnclaveId = {
    new EnclaveId(idWidth)
  }

  def apply(id: UInt)(implicit context: Context): EnclaveId = {
    val eid = new EnclaveId(id.getBitsWidth bits)
    eid.id := id
    eid.valid := True
    eid
  }
}
