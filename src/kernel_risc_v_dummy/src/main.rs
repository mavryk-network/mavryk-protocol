#![cfg_attr(target_os = "none", no_std)]
#![cfg_attr(target_os = "none", no_main)]

extern crate alloc;

#[cfg(not(target_os = "none"))]
extern crate std;

mod actual_main;
mod dumb_alloc;
mod syscalls;

#[cfg(target_os = "none")]
mod bare_metal {
    use crate::{
        dumb_alloc,
        syscalls::{exit, write},
    };

    // This code runs before the main.
    #[riscv_rt::pre_init]
    unsafe fn pre_init() {
        dumb_alloc::init();
    }

    // We need a custom panic handler to ensure fatal errors are visible to the
    // outside world.
    #[panic_handler]
    pub fn panic_handler(info: &core::panic::PanicInfo) -> ! {
        let d0 = alloc::format!(
            "tid = {:?} ({:?} / {:?} / {:?})\n",
            info.payload().type_id(),
            core::any::TypeId::of::<alloc::string::String>(),
            core::any::TypeId::of::<&str>(),
            core::any::TypeId::of::<u32>()
        );

        write(2, d0.as_ptr(), d0.len());

        write(2, "Panic at ".as_ptr(), 7);

        if let Some(loc) = info.location() {
            // let file = loc.file();
            let location = alloc::format!("{}: ", loc);
            write(2, location.as_ptr(), location.len());
            // write(2, file.as_ptr(), file.len());
            // write(2, ": ".as_ptr(), 2);
        } else {
            write(2, "<unknown>: ".as_ptr(), 11);
        }
        let message = if let Some(message) = info.payload().downcast_ref::<alloc::string::String>()
        {
            message.as_str()
        } else {
            let message = info.payload().downcast_ref::<&str>();
            message.unwrap_or(&"<unknown message>")
        };

        let d = alloc::format!("{:#x}+{}\n", message.as_ptr() as usize, message.len());
        write(2, d.as_ptr(), d.len());

        write(2, message.as_ptr(), message.len());
        write(2, "\n".as_ptr(), 1);

        exit(1)
    }

    // When targeting RISC-V bare-metal we need a custom entrypoint mechanism.
    // Fortunateky, riscv-rt provides this for us.
    #[allow(non_snake_case)]
    #[riscv_rt::entry]
    unsafe fn main() -> ! {
        crate::actual_main::main();
        exit(0)
    }
}

// We can re-use the default mechanism around entrypoints when we're not
// compiling to the bare-metal target.
#[cfg(not(target_os = "none"))]
fn main() {
    crate::actual_main::main()
}
