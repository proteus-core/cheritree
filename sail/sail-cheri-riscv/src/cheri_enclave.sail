/* This file contains bookkeeping functions used in the enclave instructions
 * and a number of types/constants.
 */

//SHA256-hash; fixed size independent of architectural size
type id_hash_size : Int = 256
type id_hash_size_bytes : Int = 32
/* Define number of iterations to write the hash */
type write_hash_iters : Int = 8
let write_hash_iters = sizeof(write_hash_iters)
let id_hash_size = sizeof(id_hash_size)
type hash = bits(id_hash_size)

type otype = bits(cap_otype_width)
type eid_type = bits(cap_otype_width - 2)

type table_size : Int = 128
let table_size = sizeof(table_size)

// One TCB entry
struct EMapping = {
    id : hash,
    eid : eid_type,
    is_temp: bool
}

// Count the amount of seals that have been used for generating keys
// Requires cap_otype_width - 1 bits, not -2, because of the extra 'overflow' state
register EidCounter : bits(cap_otype_width - 1)

// The table where TCB entries will be inserted
type ETable = vector(table_size, dec, option(EMapping))
register ETable : ETable

/* Helper function to get an id stored in the TCB, starting from index idx'. */
val getIdH : (eid_type, int, bool) -> option(EMapping) effect {rreg, wreg}
function getIdH(eid, idx', is_temp) = {
    if idx' >= table_size | idx' < 0 then None()
    else {
        let idx = idx';
        let option = ETable[idx];
        match option {
            Some(entry) => {
                if entry.eid == eid then
                   if is_temp & entry.is_temp then Some(entry)
                   else
                    if not(is_temp | entry.is_temp) then Some(entry)
                    else
                       None() //no need to look further; otypes are not reused
                else
                    getIdH(eid, idx + 1, is_temp)
                    
            },
            None() => getIdH(eid, idx + 1, is_temp)
        };
    }
}

/* Get an id stored in the TCB.
 * Returns an option type with None() in case
 * the given eid is not found in the table. If temp is true it will only look for
 * temporary entries. If temp is false it will only look for non-temporary entries.
 */
val getId : (eid_type, bool) -> option(EMapping) effect {rreg, wreg}
function getId(eid, is_temp) = {
    getIdH(eid, 0, is_temp)
}

/* Helper to add an entry to the TCB, starting search at idx'. */
val findFreeIdxH: int -> option(int) effect {rreg}
function findFreeIdxH(idx') = {
    if idx' >= table_size | idx' < 0 then None()
    else {
        let idx : range(0, table_size - 1) = idx';
        match ETable[idx] {
            Some(_) => findFreeIdxH(idx + 1),
            None() => Some(idx)
        }
    }
}

val findFreeIdx: unit -> option(int) effect {rreg}
function findFreeIdx() = {
    findFreeIdxH(0)
}

/* NOTE: assumes that findFreeIdx has been called before to check for a free index `idx` */
val addMappingH : (eid_type, hash, bool, int) -> unit effect {rreg, wreg}
function addMappingH(eid, id, is_temp, idx') = {
    assert(0 <= idx' & idx' < table_size, "invalid index fed");
    let idx : range(0, table_size - 1) = idx';
    let entry : EMapping = struct {
        id = id,
        eid = eid,
        is_temp = is_temp
    };
    ETable[idx] = Some(entry);
}

/* Functions to add either a permanent or temporary entry to the TCB, at index `idx`.
*/
val addTempMapping : (eid_type, int) -> unit effect {rreg, wreg}
function addTempMapping(eid, idx) = {
    addMappingH(eid, zeros(id_hash_size), true, idx)
}
val addPermMapping : (eid_type, hash, int) -> unit effect {rreg, wreg}
function addPermMapping(eid, id, idx) = {
    addMappingH(eid, id, false, idx)
}

/* Helper to remove an entry from the TCB, starting search at the provided index idx'. */
val removeMappingH : (eid_type, int) -> bool effect {rreg, wreg}
function removeMappingH(eid, idx') = {
    if idx' >= table_size | idx' < 0 then false else {
        let idx : range(0, table_size - 1) = idx';
        match ETable[idx] {
            Some(entry) => {
                if entry.eid == eid then {
                    ETable[idx] = None();
                    true
                } else
                    removeMappingH(eid, idx+1)
            },
            None() => removeMappingH(eid, idx+1)
        }
    }
}

/* Removes an entry from the TCB.
 * If the entry is found and removed, the function returns true, otherwise false.
 */
val removeMapping : (eid_type) -> bool effect {rreg, wreg}
function removeMapping(eid) = {
    removeMappingH(eid, 0)
}

/* Helper to only start upgrading from index `idx'` onwards. */
val makeMappingPermH : (eid_type, hash, int) -> bool effect {rreg, wreg}
function makeMappingPermH(eid, id, idx') = {
    if idx' >= table_size | idx' < 0 then false else {
        let idx : range(0, table_size - 1) = idx';
        match ETable[idx] {
            Some(entry) => {
                if entry.eid == eid then {
                  if entry.is_temp then {
                        ETable[idx] = Some({{entry with is_temp = false} with id = id });
                        true
                  } else false //Entry is already permanent
                } else makeMappingPermH(eid, id, idx + 1)
            },
            None() => makeMappingPermH(eid, id, idx + 1)
        }
    }
}

/* Upgrade a mapping in the TCB for the given *eid_type* from temporary to permanent. */
val makeMappingPerm : (eid_type, hash) -> bool effect {rreg, wreg}
function makeMappingPerm(eid, id) = {
    makeMappingPermH(eid, id,  0)
}


// Initializes the TCB with empty entries.
val initETable : unit -> unit effect {wreg}
function initETable() = {
    let t_end = table_size - 1;
    foreach (i from 0 to t_end)
        ETable[i] = None()
}
