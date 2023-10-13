use rvemu::{cpu::BYTE, emulator::Emulator};
use std::{
    error::Error,
    io::{self, Write},
    ops::Range,
    process::exit,
};

// System calls
const WRITE: u64 = 64;
const EXIT: u64 = 93;

// Error codes
const EINVAL: u64 = (-22i64) as u64;
const EBADF: u64 = (-9i64) as u64;

// Known file descriptors
const STDIN: u64 = 0;
const STDOUT: u64 = 1;
const STDERR: u64 = 2;

/// Handle a system call originating from the user program.
pub fn handle(emu: &mut Emulator) -> Result<(), Box<dyn Error>> {
    let syscall_number = emu.cpu.xregs.read(17);
    match syscall_number {
        WRITE => {
            // Read the arguments from a0-a2.
            let fd = emu.cpu.xregs.read(10);
            let buf = emu.cpu.xregs.read(11);
            let count = emu.cpu.xregs.read(12);

            let data_range = buf..buf + count;

            /// Writes the message to a given FD target.
            fn write_data(
                mut target: impl Write,
                data_range: Range<u64>,
                emu: &mut Emulator,
            ) -> Result<u64, Box<dyn Error>> {
                let message: Vec<u8> = data_range
                    .map(|i| emu.cpu.bus.read(i, BYTE).map(|i| i as u8))
                    .collect::<Result<Vec<u8>, _>>()
                    .map_err(super::exception_to_error)?;

                let written = target.write(message.as_slice())?;
                Ok(written as u64)
            }

            let bytes_written = match fd {
                STDIN => EINVAL,
                STDOUT => write_data(io::stdout().lock(), data_range, emu)?,
                STDERR => write_data(io::stderr().lock(), data_range, emu)?,
                _ => EBADF,
            };

            // Write the result back to a0.
            emu.cpu.xregs.write(10, bytes_written);
        }

        EXIT => {
            let code = emu.cpu.xregs.read(10);
            println!("Received request to exit with code {}", code);
            exit(code as i32);
        }

        _ => panic!("Unimplemented system call {}", syscall_number),
    }

    Ok(())
}
