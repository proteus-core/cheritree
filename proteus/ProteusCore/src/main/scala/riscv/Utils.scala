package riscv

import spinal.core._
import spinal.lib._

object Utils {
  def signExtend[T <: BitVector](data: T, width: Int): T = {
    val dataWidth = data.getBitsWidth
    assert(dataWidth <= width && dataWidth > 0)

    (B((width - 1 - dataWidth downto 0) -> data(dataWidth - 1)) ## data).as(data.clone().setWidth(width))
  }

  def zeroExtend[T <: BitVector](data: T, width: Int): T = {
    val dataWidth = data.getBitsWidth
    assert(dataWidth <= width && dataWidth > 0)

    (B((width - 1 - dataWidth downto 0) -> False) ## data).as(data.clone().setWidth(width))
  }

  def twosComplement(data: UInt): UInt = ~data + 1

  def delay(cycles: Int)(logic: => Unit) = {
    assert(cycles >= 0)

    val delayCounter = Counter(cycles + 1)

    when (delayCounter.willOverflowIfInc) {
      logic
    }

    delayCounter.increment()
  }

  def outsideConditionScope[T](rtl: => T): T = {
    val body = Component.current.dslBody
    body.push()
    val swapContext = body.swap()
    val ret = rtl
    body.pop()
    swapContext.appendBack()
    ret
  }
}

case class Optional[T <: Data](hardType: HardType[T]) extends Bundle {
  val value = hardType()
  val isDefined = Bool()

  def assignNone(): this.type = {
    value.assignDontCare()
    isDefined := False
    this
  }

  def assignSome(value: T): this.type = {
    this.value := value
    isDefined := True
    this
  }
}

object Optional {
  def some[T <: Data](value: T): Optional[T] = {
    Optional(value).assignSome(value)
  }

  // TODO it would be nice to find a way to create a none value without having to specify
  // its HardType
  def none[T <: Data](hardType: HardType[T]): Optional[T] = {
    Optional(hardType).assignNone()
  }
}
