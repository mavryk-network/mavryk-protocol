use crate::syscalls::write;

pub fn main() {
    write(1, "Hello World\n".as_ptr(), 12);
}
