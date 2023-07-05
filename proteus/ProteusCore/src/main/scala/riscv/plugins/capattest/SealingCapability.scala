package riscv.plugins.capattest

import riscv.plugins.cheri._

import spinal.core._

class SealingCapability(numSeals: Int = 1)
                       (implicit context: Context) extends Bundle with Capability {
  override val tag = Bool()
  val seal = UInt(context.otypeLen bits)

  private val xlen = context.config.xlen bits
  override def base = seal.resize(xlen)
  override def length = U(numSeals, xlen)
  override def offset = U(0, xlen)

  override def perms: Permissions = new Permissions {
    override def execute = False
    override def load = False
    override def store = False
    override def loadCapability = False
    override def storeCapability = False
    override def seal = True
    override def cinvoke = False
    override def unseal = True
    override def accessSystemRegisters = False
  }

  override def otype: ObjectType = {
    val otype = ObjectType()
    otype.unseal()
    otype
  }
}

object SealingCapability {
  def apply()(implicit context: Context): SealingCapability = new SealingCapability

  def apply(seal: UInt, numSeals: Int = 1)(implicit context: Context): SealingCapability = {
    val cap = new SealingCapability(numSeals)
    cap.seal := seal
    cap.tag := True
    cap
  }

  def Null(implicit context: Context): SealingCapability = {
    val cap = new SealingCapability
    cap.seal.assignDontCare()
    cap.tag := False
    cap
  }
}
