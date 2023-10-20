use crate::syscalls::write;

fn debug(m: &str) {
    write(2, m.as_ptr(), m.len());
}

pub fn main() {
    panic!("Hellorw");
    // write(1, "Hello World\n".as_ptr(), 12);
}
