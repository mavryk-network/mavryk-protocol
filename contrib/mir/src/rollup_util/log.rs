/******************************************************************************/
/*                                                                            */
/* SPDX-License-Identifier: MIT                                               */
/* Copyright (c) [2023] Serokell <hi@serokell.io>                             */
/*                                                                            */
/******************************************************************************/

/// Log a text.
///
/// ```
/// log!(host, "My data: {}", dat)
/// ```
macro_rules! log {
  ($host:expr, $($args:tt)*) => {
    {
      use tezos_smart_rollup::prelude::*;

      debug_msg!($host, $($args)*);
      $host.write_debug("\n");
    }
  };
}
pub(crate) use log;

/// Synonym to [log] macro that is intended for temporary use just to debug
/// something and then should be removed.
#[deprecated(note = "debug printing remains in the code")]
#[allow(unused_macros)]
macro_rules! debug {
  ($($args: expr),*) => {
    log!($($args), *);
  };
}
#[allow(unused_imports)]
#[allow(deprecated)]
pub(crate) use debug;

#[cfg(test)]
mod test_log_fn {
    use tezos_smart_rollup_mock::MockHost;

    #[test]
    fn test_log() {
        let host = MockHost::default();
        log!(host, "Done");
        log!(host, "1 + 2 = {} and 2 * 2 = {}", 3, 4);
    }
}
