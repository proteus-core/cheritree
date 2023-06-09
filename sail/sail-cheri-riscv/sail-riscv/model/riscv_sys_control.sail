/* Machine-mode and supervisor-mode functionality. */


/* CSR access control */

function csrAccess(csr : csreg) -> csrRW = csr[11..10]
function csrPriv(csr : csreg) -> priv_level = csr[9..8]

function is_CSR_defined (csr : csreg, p : Privilege) -> bool =
  match (csr) {
    /* machine mode: informational */
    0xf11 => p == Machine, // mvendorid
    0xf12 => p == Machine, // marchdid
    0xf13 => p == Machine, // mimpid
    0xf14 => p == Machine, // mhartid
    /* machine mode: trap setup */
    0x300 => p == Machine, // mstatus
    0x301 => p == Machine, // misa
    0x302 => p == Machine, // medeleg
    0x303 => p == Machine, // mideleg
    0x304 => p == Machine, // mie
    0x305 => p == Machine, // mtvec
    0x306 => p == Machine, // mcounteren
    /* machine mode: trap handling */
    0x340 => p == Machine, // mscratch
    0x341 => p == Machine, // mepc
    0x342 => p == Machine, // mcause
    0x343 => p == Machine, // mtval
    0x344 => p == Machine, // mip

    0x3A0 => p == Machine,                        // pmpcfg0
    0x3A1 => p == Machine & (sizeof(xlen) == 32), // pmpcfg1
    0x3A2 => p == Machine,                        // pmpcfg2
    0x3A3 => p == Machine & (sizeof(xlen) == 32), // pmpcfg3

    0x3B0 => p == Machine, // pmpaddr0
    0x3B1 => p == Machine, // pmpaddr1
    0x3B2 => p == Machine, // pmpaddr2
    0x3B3 => p == Machine, // pmpaddr3
    0x3B4 => p == Machine, // pmpaddr4
    0x3B5 => p == Machine, // pmpaddr5
    0x3B6 => p == Machine, // pmpaddr6
    0x3B7 => p == Machine, // pmpaddr7
    0x3B8 => p == Machine, // pmpaddr8
    0x3B9 => p == Machine, // pmpaddr9
    0x3BA => p == Machine, // pmpaddrA
    0x3BB => p == Machine, // pmpaddrB
    0x3BC => p == Machine, // pmpaddrC
    0x3BD => p == Machine, // pmpaddrD
    0x3BE => p == Machine, // pmpaddrE
    0x3BF => p == Machine, // pmpaddrF

    /* counters */
    0xB00 => p == Machine, // mcycle
    0xB02 => p == Machine, // minstret

    0xB80 => p == Machine & (sizeof(xlen) == 32), // mcycleh
    0xB82 => p == Machine & (sizeof(xlen) == 32), // minstreth

    /* disabled trigger/debug module */
    0x7a0 => p == Machine,

    /* supervisor mode: trap setup */
    0x100 => haveSupMode() & (p == Machine | p == Supervisor), // sstatus
    0x102 => haveSupMode() & (p == Machine | p == Supervisor), // sedeleg
    0x103 => haveSupMode() & (p == Machine | p == Supervisor), // sideleg
    0x104 => haveSupMode() & (p == Machine | p == Supervisor), // sie
    0x105 => haveSupMode() & (p == Machine | p == Supervisor), // stvec
    0x106 => haveSupMode() & (p == Machine | p == Supervisor), // scounteren

    /* supervisor mode: trap handling */
    0x140 => haveSupMode() & (p == Machine | p == Supervisor), // sscratch
    0x141 => haveSupMode() & (p == Machine | p == Supervisor), // sepc
    0x142 => haveSupMode() & (p == Machine | p == Supervisor), // scause
    0x143 => haveSupMode() & (p == Machine | p == Supervisor), // stval
    0x144 => haveSupMode() & (p == Machine | p == Supervisor), // sip

    /* supervisor mode: address translation */
    0x180 => haveSupMode() & (p == Machine | p == Supervisor), // satp

    /* user mode: counters */
    0xC00 => p == User,    // cycle
    0xC01 => p == User,    // time
    0xC02 => p == User,    // instret

    0xC80 => p == User & (sizeof(xlen) == 32),     // cycleh
    0xC81 => p == User & (sizeof(xlen) == 32),     // timeh
    0xC82 => p == User & (sizeof(xlen) == 32),     // instreth

    /* check extensions */
    _     => ext_is_CSR_defined(csr, p)
  }

val check_CSR_access : (csrRW, priv_level, Privilege, bool) -> bool
function check_CSR_access(csrrw, csrpr, p, isWrite) =
    (~ (isWrite == true & csrrw == 0b11))  /* read/write */
  & (privLevel_to_bits(p) >=_u csrpr)      /* privilege */

function check_TVM_SATP(csr : csreg, p : Privilege) -> bool =
  ~ (csr == 0x180 & p == Supervisor & mstatus.TVM() == 0b1)

function check_Counteren(csr : csreg, p : Privilege) -> bool =
  match(csr, p) {
    (0xC00, Supervisor) => mcounteren.CY() == 0b1,
    (0xC01, Supervisor) => mcounteren.TM() == 0b1,
    (0xC02, Supervisor) => mcounteren.IR() == 0b1,

    (0xC00, User) => mcounteren.CY() == 0b1 & ((~ (haveSupMode())) | scounteren.CY() == 0b1),
    (0xC01, User) => mcounteren.TM() == 0b1 & ((~ (haveSupMode())) | scounteren.TM() == 0b1),
    (0xC02, User) => mcounteren.IR() == 0b1 & ((~ (haveSupMode())) | scounteren.IR() == 0b1),

    (_, _) => /* no HPM counters for now */
              if   0xC03 <=_u csr & csr <=_u 0xC1F
              then false
              else true
  }

function check_CSR(csr : csreg, p : Privilege, isWrite : bool) -> bool =
    is_CSR_defined(csr, p)
  & check_CSR_access(csrAccess(csr), csrPriv(csr), p, isWrite)
  & check_TVM_SATP(csr, p)
  & check_Counteren(csr, p)

/* Reservation handling for LR/SC.
 *
 * The reservation state is maintained external to the model since the
 * reservation behavior is platform-specific anyway and maintaining
 * this state outside the model simplifies the concurrency analysis.
 *
 * These are externs are defined here in the system module since
 * we currently perform reservation cancellation on privilege level
 * transition.  Ideally, the platform should get more visibility into
 * where cancellation can be performed.
 */

val speculate_conditional = {ocaml: "Platform.speculate_conditional", interpreter: "excl_res", c: "speculate_conditional", lem: "speculate_conditional_success"} : unit -> bool effect {exmem}

val load_reservation = {ocaml: "Platform.load_reservation", interpreter: "Platform.load_reservation", c: "load_reservation", lem: "load_reservation"} : xlenbits -> unit
val match_reservation = {ocaml: "Platform.match_reservation", interpreter: "Platform.match_reservation", lem: "match_reservation", c: "match_reservation"} : xlenbits -> bool
val cancel_reservation = {ocaml: "Platform.cancel_reservation", interpreter: "Platform.cancel_reservation", c: "cancel_reservation", lem: "cancel_reservation"} : unit -> unit

/* Exception delegation: given an exception and the privilege at which
 * it occured, returns the privilege at which it should be handled.
 */
function exception_delegatee(e : ExceptionType, p : Privilege) -> Privilege = {
  let idx   = num_of_ExceptionType(e);
  let super = bit_to_bool(medeleg.bits()[idx]);
  /* if S-mode is absent, medeleg delegates to U-mode if 'N' is supported. */
  let user  = if   haveSupMode()
              then super & haveNExt() & bit_to_bool(sedeleg.bits()[idx])
              else super & haveNExt();
  let deleg = if      haveUsrMode() & user  then User
              else if haveSupMode() & super then Supervisor
              else                               Machine;
  /* We cannot transition to a less-privileged mode. */
  if   privLevel_to_bits(deleg) <_u privLevel_to_bits(p)
  then p else deleg
}

/* Interrupts are prioritized in privilege order, and for each
 * privilege, in the order: external, software, timers.
 */
function findPendingInterrupt(ip : xlenbits) -> option(InterruptType) = {
  let ip = Mk_Minterrupts(ip);
  if      ip.MEI() == 0b1 then Some(I_M_External)
  else if ip.MSI() == 0b1 then Some(I_M_Software)
  else if ip.MTI() == 0b1 then Some(I_M_Timer)
  else if ip.SEI() == 0b1 then Some(I_S_External)
  else if ip.SSI() == 0b1 then Some(I_S_Software)
  else if ip.STI() == 0b1 then Some(I_S_Timer)
  else if ip.UEI() == 0b1 then Some(I_U_External)
  else if ip.USI() == 0b1 then Some(I_U_Software)
  else if ip.UTI() == 0b1 then Some(I_U_Timer)
  else                         None()
}

/* Process the pending interrupts xip at a privilege according to
 * the enabled flags xie and the delegation in xideleg. Return
 * either the set of pending interrupts, or the set of interrupts
 * delegated to the next lower privilege.
 */
union interrupt_set = {
  Ints_Pending   : xlenbits,
  Ints_Delegated : xlenbits,
  Ints_Empty     : unit
}
function processPending(xip : Minterrupts, xie : Minterrupts, xideleg : xlenbits,
                        priv_enabled : bool) -> interrupt_set = {
  /* interrupts that are enabled but not delegated are pending */
  let  effective_pend = xip.bits() & xie.bits() & (~ (xideleg));
  /* the others are delegated */
  let  effective_delg = xip.bits() & xideleg;
  /* we have pending interrupts if this privilege is enabled */
  if      priv_enabled & (effective_pend != EXTZ(0b0))
  then    Ints_Pending(effective_pend)
  else if effective_delg != EXTZ(0b0)
  then    Ints_Delegated(effective_delg)
  else    Ints_Empty()
}

/* Given the current privilege level, iterate over privileges to get a
 * pending set for an enabled privilege. This is only called for M/U or
 * M/S/U systems.
 *
 * We don't use the lowered views of {xie,xip} here, since the spec
 * allows for example the M_Timer to be delegated to the U-mode.
 */
function getPendingSet(priv : Privilege) -> option((xlenbits, Privilege)) = {
  assert(haveUsrMode(), "no user mode: M/U or M/S/U system required");
  let effective_pending = mip.bits() & mie.bits();
  if  effective_pending == EXTZ(0b0) then None() /* fast path */
  else {
    /* Higher privileges than the current one are implicitly enabled,
     * while lower privileges are blocked.  An unsupported privilege is
     * considered blocked.
     */
    let mIE = priv != Machine | (priv == Machine & mstatus.MIE() == 0b1);
    let sIE = haveSupMode() & (priv == User | (priv == Supervisor & mstatus.SIE() == 0b1));
    let uIE = haveNExt() & (priv == User & mstatus.UIE() == 0b1);
    match processPending(mip, mie, mideleg.bits(), mIE) {
      Ints_Empty()      => None(),
      Ints_Pending(p)   => let r = (p, Machine) in Some(r),
      Ints_Delegated(d) =>
        if (~ (haveSupMode())) then {
          if uIE then let r = (d, User) in Some(r)
          else                             None()
        } else {
          /* the delegated bits are pending for S-mode */
          match processPending(Mk_Minterrupts(d), mie, sideleg.bits(), sIE) {
            Ints_Empty()      => None(),
            Ints_Pending(p)   => let r = (p, Supervisor) in Some(r),
            Ints_Delegated(d) => if   uIE
                                 then let r = (d, User) in Some(r)
                                 else None()
          }
        }
    }
  }
}

/* Examine the current interrupt state and return an interrupt to be *
 * handled (if any), and the privilege it should be handled at.
 */
function dispatchInterrupt(priv : Privilege) -> option((InterruptType, Privilege)) = {
  /* If we don't have different privilege levels, we don't need to check delegation.
   * Absence of U-mode implies absence of S-mode.
   */
  if (~ (haveUsrMode())) | ((~ (haveSupMode())) & (~ (haveNExt()))) then {
    assert(priv == Machine, "invalid current privilege");
    let enabled_pending = mip.bits() & mie.bits();
    match findPendingInterrupt(enabled_pending) {
      Some(i) => let r = (i, Machine) in Some(r),
      None()  => None()
    }
  } else {
    match getPendingSet(priv) {
      None()      => None(),
      Some(ip, p) => match findPendingInterrupt(ip) {
                       None()  => None(),
                       Some(i) => let r = (i, p) in Some(r)
                     }
    }
  }
}

/* types of privilege transitions */

union ctl_result = {
  CTL_TRAP : sync_exception,
  CTL_SRET : unit,
  CTL_MRET : unit,
  CTL_URET : unit
}

/* trap value */

function tval(excinfo : option(xlenbits)) -> xlenbits = {
  match (excinfo) {
    Some(e) => e,
    None()  => EXTZ(0b0)
  }
}

$ifdef RVFI_DII
val rvfi_trap : unit -> unit effect {wreg}
function rvfi_trap () =
  rvfi_exec->rvfi_trap() = 0x01
$else
val rvfi_trap : unit -> unit
function rvfi_trap () = ()
$endif

/* handle exceptional ctl flow by updating nextPC and operating privilege */

function trap_handler(del_priv : Privilege, intr : bool, c : exc_code, pc : xlenbits, info : option(xlenbits), ext : option(ext_exception))
                     -> xlenbits = {
  rvfi_trap();
  if   get_config_print_platform()
  then print_platform("handling " ^ (if intr then "int#" else "exc#")
                      ^ BitStr(c) ^ " at priv " ^ to_str(del_priv)
                      ^ " with tval " ^ BitStr(tval(info)));

  cancel_reservation();

  match (del_priv) {
    Machine => {
       mcause->IsInterrupt() = bool_to_bits(intr);
       mcause->Cause()       = EXTZ(c);

       mstatus->MPIE() = mstatus.MIE();
       mstatus->MIE()  = 0b0;
       mstatus->MPP()  = privLevel_to_bits(cur_privilege);
       mtval           = tval(info);
       mepc            = pc;

       cur_privilege   = del_priv;

       handle_trap_extension(del_priv, pc, ext);

       if   get_config_print_reg()
       then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits()));

       prepare_trap_vector(del_priv, mcause)
    },
    Supervisor => {
       assert (haveSupMode(), "no supervisor mode present for delegation");

       scause->IsInterrupt() = bool_to_bits(intr);
       scause->Cause()       = EXTZ(c);

       mstatus->SPIE() = mstatus.SIE();
       mstatus->SIE()  = 0b0;
       mstatus->SPP()  = match cur_privilege {
                           User => 0b0,
                           Supervisor => 0b1,
                           Machine => internal_error("invalid privilege for s-mode trap")
                         };
       stval           = tval(info);
       sepc            = pc;

       cur_privilege   = del_priv;

       handle_trap_extension(del_priv, pc, ext);

       if   get_config_print_reg()
       then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits()));

       prepare_trap_vector(del_priv, scause)
    },
    User => {
       assert(haveUsrMode(), "no user mode present for delegation");

       ucause->IsInterrupt() = bool_to_bits(intr);
       ucause->Cause()       = EXTZ(c);

       mstatus->UPIE() = mstatus.UIE();
       mstatus->UIE()  = 0b0;
       utval           = tval(info);
       uepc            = pc;

       cur_privilege   = del_priv;

       handle_trap_extension(del_priv, pc, ext);

       if   get_config_print_reg()
       then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits()));

       prepare_trap_vector(del_priv, ucause)
    }
  };
}

function exception_handler(cur_priv : Privilege, ctl : ctl_result,
                           pc: xlenbits) -> xlenbits = {
  match (cur_priv, ctl) {
    (_, CTL_TRAP(e)) => {
      let del_priv = exception_delegatee(e.trap, cur_priv);
      if   get_config_print_platform()
      then print_platform("trapping from " ^ to_str(cur_priv) ^ " to " ^ to_str(del_priv)
                          ^ " to handle " ^ to_str(e.trap));
      trap_handler(del_priv, false, exceptionType_to_bits(e.trap), pc, e.excinfo, e.ext)
    },
    (_, CTL_MRET())  => {
      let prev_priv   = cur_privilege;
      mstatus->MIE()  = mstatus.MPIE();
      mstatus->MPIE() = 0b1;
      cur_privilege   = privLevel_of_bits(mstatus.MPP());
      mstatus->MPP()  = privLevel_to_bits(if haveUsrMode() then User else Machine);
      if   cur_privilege != Machine
      then mstatus->MPRV() = 0b0;

      if   get_config_print_reg()
      then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits()));
      if   get_config_print_platform()
      then print_platform("ret-ing from " ^ to_str(prev_priv) ^ " to " ^ to_str(cur_privilege));

      cancel_reservation();
      prepare_xret_target(Machine) & pc_alignment_mask()
    },
    (_, CTL_SRET())  => {
      let prev_priv   = cur_privilege;
      mstatus->SIE()  = mstatus.SPIE();
      mstatus->SPIE() = 0b1;
      cur_privilege   = if mstatus.SPP() == 0b1 then Supervisor else User;
      mstatus->SPP()  = 0b0;
      if   cur_privilege != Machine
      then mstatus->MPRV() = 0b0;

      if   get_config_print_reg()
      then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits()));
      if   get_config_print_platform()
      then print_platform("ret-ing from " ^ to_str(prev_priv)
                          ^ " to " ^ to_str(cur_privilege));

      cancel_reservation();
      prepare_xret_target(Supervisor) & pc_alignment_mask()
    },
    (_, CTL_URET())  => {
      let prev_priv   = cur_privilege;
      mstatus->UIE()  = mstatus.UPIE();
      mstatus->UPIE() = 0b1;
      cur_privilege   = User;

      if   get_config_print_reg()
      then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits()));
      if   get_config_print_platform()
      then print_platform("ret-ing from " ^ to_str(prev_priv) ^ " to " ^ to_str(cur_privilege));

      cancel_reservation();
      prepare_xret_target(User) & pc_alignment_mask()
    }
  }
}

function handle_mem_exception(addr : xlenbits, e : ExceptionType) -> unit = {
  let t : sync_exception = struct { trap    = e,
                                    excinfo = Some(addr),
                                    ext     = None() } in
  set_next_pc(exception_handler(cur_privilege, CTL_TRAP(t), PC))
}

function handle_exception(e: ExceptionType) -> unit = {
  let t : sync_exception = struct { trap    = e,
                                    excinfo = None(),
                                    ext     = None() } in
  set_next_pc(exception_handler(cur_privilege, CTL_TRAP(t), PC))
}

function handle_interrupt(i : InterruptType, del_priv : Privilege) -> unit =
  set_next_pc(trap_handler(del_priv, true, interruptType_to_bits(i), PC, None(), None()))

/* state state initialization */

function init_sys() -> unit = {
  cur_privilege = Machine;

  mhartid     = EXTZ(0b0);

  misa->MXL() = arch_to_bits(if sizeof(xlen) == 32 then RV32 else RV64);
  misa->A()   = 0b1;                            /* atomics */
  misa->C()   = bool_to_bits(sys_enable_rvc()); /* RVC */
  misa->I()   = 0b1;                            /* base integer ISA */
  misa->M()   = 0b1;                            /* integer multiply/divide */
  misa->U()   = 0b1;                            /* user-mode */
  misa->S()   = 0b1;                            /* supervisor-mode */

  /* On RV64, we currently support either both F and D, or neither.
   * On RV32, we currently only support F.
   */
  misa->F()   = bool_to_bits(sys_enable_fdext());      /* single-precision */
  misa->D()   = if   sizeof(xlen) == 64
                then bool_to_bits(sys_enable_fdext())  /* double-precision */
                else 0b0;

  mstatus = set_mstatus_SXL(mstatus, misa.MXL());
  mstatus = set_mstatus_UXL(mstatus, misa.MXL());
  mstatus->SD()   = 0b0;

  mip->bits()     = EXTZ(0b0);
  mie->bits()     = EXTZ(0b0);
  mideleg->bits() = EXTZ(0b0);
  medeleg->bits() = EXTZ(0b0);
  mtvec->bits()   = EXTZ(0b0);
  mcause->bits()  = EXTZ(0b0);
  mepc            = EXTZ(0b0);
  mtval           = EXTZ(0b0);
  mscratch        = EXTZ(0b0);

  mcycle          = EXTZ(0b0);
  mtime           = EXTZ(0b0);

  mcounteren->bits() = EXTZ(0b0);

  minstret           = EXTZ(0b0);
  minstret_written   = false;

  init_pmp();

  // log compatibility with spike
  if   get_config_print_reg()
  then print_reg("CSR mstatus <- " ^ BitStr(mstatus.bits()) ^ " (input: " ^ BitStr(EXTZ(0b0) : xlenbits) ^ ")")
}

/* memory access exceptions, defined here for use by the platform model. */

union MemoryOpResult ('a : Type) = {
  MemValue     : 'a,
  MemException : ExceptionType
}

val MemoryOpResult_add_meta : forall ('t : Type). (MemoryOpResult('t), mem_meta) -> MemoryOpResult(('t, mem_meta))
function MemoryOpResult_add_meta(r, m) = match r {
  MemValue(v)     => MemValue(v, m),
  MemException(e) => MemException(e)
}

val MemoryOpResult_drop_meta : forall ('t : Type). MemoryOpResult(('t, mem_meta)) -> MemoryOpResult('t)
function MemoryOpResult_drop_meta(r) = match r {
  MemValue(v, m)  => MemValue(v),
  MemException(e) => MemException(e)
}
