// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
// SPDX-FileCopyrightText: 2024 Nomadic Labs <contact@nomadic-labs.com>
//
// SPDX-License-Identifier: MIT

use clap::{Parser, Subcommand, ValueEnum};

#[derive(Debug, Clone, Subcommand)]
pub enum Mode {
    /// Run a program using the RISC-V interpreter
    Run(Options),
    /// Launch a program in the debugger
    Debug(Options),
}

#[derive(Clone, ValueEnum, Debug)]
pub enum ExitMode {
    User,
    Supervisor,
    Machine,
}

#[derive(Debug, Clone, Parser)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Mode,
}

/// Structure that encodes the CLI options, flags and commands
#[derive(Debug, Clone, Parser)]
pub struct Options {
    /// Path to the input ELF executable
    #[arg(short, long)]
    pub input: String,

    #[arg(short = 'm', long, value_enum, default_value_t = ExitMode::User)]
    pub posix_exit_mode: ExitMode,
}

/// Parse the command-line arguments.
pub fn parse() -> Cli {
    Cli::parse()
}
