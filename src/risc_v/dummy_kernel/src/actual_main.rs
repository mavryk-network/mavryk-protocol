use mavryk_smart_rollup::prelude::*;

pub fn main(host: impl Runtime) {
    let msg = "Hello World\n";
    debug_msg!(host, "{}", msg);
    #[cfg(feature = "crypto")]
    {
        use mavryk_crypto_rs::blake2b::digest_256;
        let hash = digest_256(msg.as_bytes()).unwrap();
        debug_msg!(host, "{:02X?}\n", hash);
    }
}
