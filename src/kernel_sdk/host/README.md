Wrapper for the `mavryk_smart_rollup_core` host function definitions 
as a safe API.

The rollup make _host functions_ available to the kernel, as a set of **C-style APIs**.  The
`mavryk_smart_rollup_core` crate defines these as `extern "C"` functions
that are unsafe to call.

Using *mavryk_smart_rollup_host* allows a kernel to access these capabilites
without relying on `unsafe` code.
