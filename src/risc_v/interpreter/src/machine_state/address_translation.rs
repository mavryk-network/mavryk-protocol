// SPDX-FileCopyrightText: 2024 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

use crate::{state_backend as backend, traps::Exception};

use super::{
    bus::{main_memory, Address, Addressable, Bus, OutOfBounds},
    csregisters::{
        fields::FieldValue,
        satp::{self, SvLength, TranslationAlgorithm},
        CSRValue, CSRegister,
    },
    mode::Mode,
    MachineState,
};

mod physical_address;
mod pte;
mod virtual_address;

/// Offset of the `page offset` field in virtual and physical addresses.
const PAGE_OFFSET_WIDTH: usize = 12;
const PAGE_SIZE: u64 = 1 << PAGE_OFFSET_WIDTH;

/// Access type that is used in the virtual address translation process.
/// Section 5.3.2
#[derive(Debug, PartialEq)]
pub enum AccessType {
    Instruction,
    Load,
    Store,
}

impl AccessType {
    fn exception(&self, addr: Address) -> Exception {
        match self {
            AccessType::Instruction => Exception::InstructionPageFault(addr),
            AccessType::Load => Exception::LoadPageFault(addr),
            AccessType::Store => Exception::StoreAMOPageFault(addr),
        }
    }
}

pub struct SvConstants {
    pub levels: usize,
    pub pte_size: u64,
}

impl SvLength {
    /// LEVELS and PTESIZE constants for each SvZZ algorithm variant.
    pub const fn algorithm_constants(&self) -> SvConstants {
        match self {
            SvLength::Sv39 => SvConstants {
                levels: 3,
                pte_size: 8,
            },
            SvLength::Sv48 => SvConstants {
                levels: 4,
                pte_size: 8,
            },
            SvLength::Sv57 => SvConstants {
                levels: 5,
                pte_size: 8,
            },
        }
    }
}

/// Implementation of the virtual address translation as explained in section 5.3.2.
fn sv_translate_impl<ML, M>(
    bus: &Bus<ML, M>,
    v_addr: Address,
    satp: CSRValue,
    sv_length: SvLength,
    access_type: &AccessType,
) -> Result<Address, Exception>
where
    ML: main_memory::MainMemoryLayout,
    M: backend::Manager,
{
    use physical_address as p_addr;
    use virtual_address as v_addr;

    let SvConstants { levels, pte_size } = sv_length.algorithm_constants();

    // 1. Let a be satp.ppn × PAGESIZE, and let i = LEVELS − 1.
    let mut i = levels.saturating_sub(1);
    let mut a: Address = satp::get_PPN(satp).value() * PAGE_SIZE;
    // For all translation algorithms the page table entry size is 8 bytes.
    let mut pte: u64;
    loop {
        // 2. Let pte be the value of the PTE at address a + va.vpn[i] × PTESIZE.
        // TODO: If accessing pte violates a PMA or PMP check, raise an access-fault exception corresponding
        // to the original access type.
        let vpn_i =
            v_addr::get_VPN_IDX(v_addr, &sv_length, i).ok_or(access_type.exception(v_addr))?;
        let addr = a + vpn_i * pte_size;
        pte = bus
            .read(addr)
            .map_err(|_: OutOfBounds| Exception::LoadAccessFault(addr))?;

        // 3. If pte.v = 0, or if pte.r = 0 and pte.w = 1, stop and raise a page-fault
        //    exception corresponding to the original access type.
        let pte_v = pte::get_FLAG_V(pte);
        let pte_r = pte::get_FLAG_R(pte);
        let pte_w = pte::get_FLAG_W(pte);
        if !pte_v || (!pte_r && pte_w) {
            return Err(access_type.exception(v_addr));
        }

        // 4. Otherwise, the PTE is valid. If pte.r = 1 or pte.x = 1, go to step 5.
        //    Otherwise, this PTE is a pointer to the next level of the page table.
        //    Let i = i − 1. If i < 0, stop and raise a page-fault exception
        //    corresponding to the original access type. Otherwise,
        //    let a = pte.ppn × PAGESIZE and go to step 2.
        let pte_x = pte::get_FLAG_X(pte);
        if pte_r || pte_x {
            break;
        }

        if i == 0 {
            return Err(access_type.exception(v_addr));
        }
        i -= 1;
        a = pte::get_PPN(pte).raw_bits() * PAGE_SIZE;
    }

    // TODO: implement step 5 (MXR & SUM aware translation)
    // 5. A leaf PTE has been found. Determine if the requested memory access is
    //    allowed by the pte.r, pte.w, pte.x, and pte.u bits, given the current
    //    privilege mode and the value of the SUM and MXR fields of the mstatus
    //    register. If not, stop and raise a page-fault exception corresponding
    //    to the original access type.

    // 6. If i > 0 and pte.ppn[i−1:0] != 0, this is a misaligned superpage; stop and
    //    raise a page-fault exception corresponding to the original access type.
    let pte_ppn = pte::get_PPN(pte);
    for idx in (0..i).rev() {
        if pte_ppn.get_ppn_i(&sv_length, idx) != Some(0) {
            return Err(access_type.exception(v_addr));
        }
    }

    // 7. If pte.a = 0, or if the memory access is a store and pte.d = 0, either raise
    //    a page-fault exception corresponding to the original access type, or:
    //    • Set pte.a to 1 and, if the memory access is a store, also set pte.d to 1.
    //    • If this access violates a PMA or PMP check, raise an access exception
    //    corresponding to the original access type.
    //    • Perform atomically:
    //      – Compare pte to the value of the PTE at address a + va.vpn[i] × PTESIZE.
    //      – If the values match, set pte.a to 1 and, if the original memory access is a store, also
    //      set pte.d to 1.
    //      – If the comparison fails, return to step 2
    let pte_a = pte::get_FLAG_A(pte);
    let pte_d = pte::get_FLAG_D(pte);
    if !pte_a || (*access_type == AccessType::Store && !pte_d) {
        // Trying first case for now
        return Err(access_type.exception(v_addr));
    }

    // 8. The translation is successful. The translated physical address is given as
    //    follows:
    //    • pa.pgoff = va.pgoff.
    //    • If i > 0, then this is a superpage translation and pa.ppn[i−1:0] =
    //    va.vpn[i−1:0].
    //    • pa.ppn[LEVELS−1:i] = pte.ppn[LEVELS−1:i].
    let va_page_offset = v_addr::get_PAGE_OFFSET(v_addr);
    let p_addr = (|| {
        let mut pa = p_addr::set_PAGE_OFFSET(0, va_page_offset);
        for idx in 0..i {
            let va_vpn_i = v_addr::get_VPN_IDX(v_addr, &sv_length, idx)?;
            pa = p_addr::set_PPN_IDX(pa, &sv_length, idx, va_vpn_i)?;
        }
        for idx in i..levels {
            let pte_ppn_i = pte_ppn.get_ppn_i(&sv_length, idx)?;
            pa = p_addr::set_PPN_IDX(pa, &sv_length, idx, pte_ppn_i)?;
        }
        Some(pa)
    })();

    p_addr.ok_or(access_type.exception(v_addr))
}

impl<ML: main_memory::MainMemoryLayout, M: backend::Manager> MachineState<ML, M> {
    /// Translate a virtual address to a physical address as described in section 5.3.2
    pub fn translate(
        &self,
        v_addr: Address,
        access_type: AccessType,
    ) -> Result<Address, Exception> {
        // 1. Let a be satp.ppn × PAGESIZE, and let i = LEVELS − 1.
        //    The satp register must be active, i.e.,
        //    the effective privilege mode must be S-mode or U-mode.
        match self.hart.mode.read() {
            Mode::User | Mode::Supervisor => (),
            Mode::Machine => return Ok(v_addr),
        };
        let satp = self.hart.csregisters.read(CSRegister::satp);
        let mode = satp::get_MODE(satp);

        match mode {
            // An invalid mode should not be writable, but it is treated as BARE
            None => Ok(v_addr),
            Some(TranslationAlgorithm::Bare) => Ok(v_addr),
            Some(TranslationAlgorithm::Sv(length)) => {
                sv_translate_impl(&self.bus, v_addr, satp, length, &access_type)
                    .map_err(|_e| access_type.exception(v_addr))
            }
        }
    }
}
