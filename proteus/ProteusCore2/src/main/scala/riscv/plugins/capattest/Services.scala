package riscv.plugins.capattest

import riscv._
import riscv.plugins.cheri._

import spinal.core._
import spinal.lib._
import spinal.crypto.hash.HashCoreIO

trait EnclaveIdService {
  def hardType: HardType[EnclaveId]
  def createIo(component: Component): EnclaveIdIo
}

trait EnclaveIdIo {
  def idAvailable: Bool
  def generateEnclaveId(): EnclaveId
}

trait IdentityStoreIo {
  def initEntry(): Flow[EnclaveId]
  def getUnfinishedEntry(identOtype: UInt): Flow[EnclaveId]
  def finishEntry(identOtype: UInt, hash: Bits): Flow[EnclaveId]
  def getHash(otype: UInt): Flow[Optional[Bits]]
}

trait IdentityStoreService {
  def getIo(stage: Stage): IdentityStoreIo
}

trait HashService {
  def hashWidth: BitCount
  def getIo(stage: Stage): HashCoreIO
}
