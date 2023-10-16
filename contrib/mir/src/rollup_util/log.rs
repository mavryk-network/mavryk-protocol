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
  ($host: expr, $($args: expr),*) => {
    {
      use tezos_smart_rollup::prelude::*;

      debug_msg!($host, $($args), *);
      $host.write_debug("\n");
    }
  };
}
pub(crate) use log;

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
