/* PTE attributes, permission checks and updates */

type pteAttribs = bits(8)

bitfield PTE_Bits : pteAttribs = {
  D : 7,
  A : 6,
  G : 5,
  U : 4,
  X : 3,
  W : 2,
  R : 1,
  V : 0
}

/*
 * Reserved PTE bits used by extensions on RV64.
 *
 * There are no such bits on RV32/SV32, so we hard-code both CapWrite=1
 * and CapRead=1 (i.e., there is no ability to disable capability loads
 * from or stores to pages in the SV32 MMU).
 */
type extPte = bits(10)

bitfield Ext_PTE_Bits : extPte = {
  CapWrite     : 9, /* Permit capability stores */
  CapRead      : 8, /* Permit capability loads */
}

/*
 * CapWrite     = 1,
 * CapRead      = 1,
 * bits 0 .. 7  = 0
 */
let default_sv32_ext_pte : extPte = 0b1100000000

function isPTEPtr(p : pteAttribs, ext : extPte) -> bool = {
  let a = Mk_PTE_Bits(p);
  a.R() == 0b0 & a.W() == 0b0 & a.X() == 0b0
}

function isInvalidPTE(p : pteAttribs, ext : extPte) -> bool = {
  let a = Mk_PTE_Bits(p);
  a.V() == 0b0 | (a.W() == 0b1 & a.R() == 0b0)
}

union PTE_Check = {
  PTE_Check_Success : ext_ptw,
  PTE_Check_Failure : (ext_ptw, ext_ptw_fail)
}

function checkPTEPermission(ac : AccessType(ext_access_type), priv : Privilege, mxr : bool, do_sum : bool, p : PTE_Bits, ext : extPte, ext_ptw : ext_ptw) -> PTE_Check = {
  /*
   * Although in many cases MXR doesn't make sense for capabilities, we honour
   * it for three reasons:
   *
   * 1. It provides uniformity rather than giving strange and surprising edge cases.
   *
   * 2. The tag-dependence of stores is achieved by passing Data in for untagged
   *    capabilities. Thus, not honouring MXR for capabilities would result in
   *    differences in whether MXR had an effect based on the tag.
   *
   * 3. It's simpler to implement yet still safe (LC is unaffected by MXR).
   */
  let base_succ : bool =
  match (ac, priv) {
    (Read(_),      User)       => p.U() == 0b1 & (p.R() == 0b1 | (p.X() == 0b1 & mxr)),
    (Write(_),     User)       => p.U() == 0b1 & p.W() == 0b1,
    (ReadWrite(_), User)       => p.U() == 0b1 & p.W() == 0b1 & (p.R() == 0b1 | (p.X() == 0b1 & mxr)),
    (Execute(),    User)       => p.U() == 0b1 & p.X() == 0b1,

    (Read(_),      Supervisor) => (p.U() == 0b0 | do_sum) & (p.R() == 0b1 | (p.X() == 0b1 & mxr)),
    (Write(_),     Supervisor) => (p.U() == 0b0 | do_sum) & p.W() == 0b1,
    (ReadWrite(_), Supervisor) => (p.U() == 0b0 | do_sum) & p.W() == 0b1 & (p.R() == 0b1 | (p.X() == 0b1 & mxr)),
    (Execute(),    Supervisor) => p.U() == 0b0 & p.X() == 0b1,

    (_,            Machine)    => internal_error("m-mode mem perm check")
  };

  let e = Mk_Ext_PTE_Bits(ext);
  let ptw_lc = if e.CapRead()  == 0b1 then PTW_LC_OK else PTW_LC_CLEAR;
  let ptw_sc = if e.CapWrite() == 0b1 then PTW_SC_OK else PTW_SC_TRAP;
  let (succ, ext_ptw') : (bool, ext_ptw) =
  match (base_succ, ac) {
    /* Base translation exceptions take priority over CHERI exceptions */
    (false, _)                     => (false, init_ext_ptw),

    (true,  Read(Cap))             => (true, ext_ptw_lc_join(ext_ptw, ptw_lc)),
    (true,  Write(Cap))            => (true, ext_ptw_sc_join(ext_ptw, ptw_sc)),
    (true,  ReadWrite(Data, Cap))  => (true, ext_ptw_sc_join(ext_ptw, ptw_sc)),
    (true,  ReadWrite(Cap, Data))  => (true, ext_ptw_lc_join(ext_ptw, ptw_lc)),
    (true,  ReadWrite(Cap, Cap))   => (true, ext_ptw_sc_join(ext_ptw_lc_join(ext_ptw, ptw_lc), ptw_sc)),

    (true,  Read(Data))            => (true, ext_ptw),
    (true,  Write(Data))           => (true, ext_ptw),
    (true,  ReadWrite(Data, Data)) => (true, ext_ptw),
    (true,  Execute())             => (true, ext_ptw)
  };

  if succ
  then PTE_Check_Success(ext_ptw')
  else PTE_Check_Failure(ext_ptw', if ext_ptw'.ptw_sc == PTW_SC_TRAP then EPTWF_CAP_ERR else EPTWF_NO_PERM)
}

function update_PTE_Bits(p : PTE_Bits, a : AccessType(ext_access_type), ext : extPte) -> option((PTE_Bits, extPte)) = {
  // dirty bit
  let update_d = p.D() == 0b0 & (match a {
                                  Execute()       => false,
                                  Read(_)         => false,
                                  Write(_)        => true,
                                  ReadWrite(_, _) => true
                                });

  // accessed bit
  let update_a = p.A() == 0b0;

  if update_d | update_a then {
    let np = update_A(p, 0b1);
    let np = if update_d then update_D(np, 0b1) else np;
    Some(np, ext)
  } else None()
}
