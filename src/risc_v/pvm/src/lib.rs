pub mod state;

use risc_v_interpreter::add;

#[no_mangle]
pub extern "C" fn mavkit_risc_v_add(left: usize, right: usize) -> usize {
    add(left, right)
}
