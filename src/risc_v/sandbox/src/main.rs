// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
// SPDX-FileCopyrightText: 2024 Nomadic Labs <contact@nomadic-labs.com>
//
// SPDX-License-Identifier: MIT

use cli::Options;
use risc_v_interpreter::{
    machine_state::mode::Mode, traps::EnvironException, Interpreter, InterpreterResult::*,
};
use std::{error::Error, path::Path};

mod cli;
mod debugger;

/// Convert a RISC-V exception into an error.
pub fn exception_to_error(exc: EnvironException) -> Box<dyn Error> {
    format!("{:?}", exc).into()
}

fn run(opts: Options) -> Result<(), Box<dyn Error>> {
    let contents = std::fs::read(&opts.input)?;
    let mut backend = Interpreter::create_backend();
    let mut interpreter = Interpreter::new(&mut backend, &contents, None, posix_exit_mode(opts))?;

    const MAX_STEPS: usize = 1000000;

    match interpreter.run(MAX_STEPS) {
        Exit { code: 0, .. } => Ok(()),
        Exit { code, .. } => Err(format!("Failed with exit code {}", code).into()),
        Running(_) => Err("Timeout".into()),
        Exception(exc, _) => Err(exception_to_error(exc)),
    }
}

fn debug(opts: Options) -> Result<(), Box<dyn Error>> {
    let path = Path::new(&opts.input);
    let fname = path
        .file_name()
        .ok_or("Invalid program path")?
        .to_str()
        .ok_or("File name cannot be converted to string")?;
    let contents = std::fs::read(path)?;
    Ok(debugger::DebuggerApp::launch(
        fname,
        &contents,
        match opts.posix_exit_mode {
            cli::ExitMode::User => Mode::User,
            cli::ExitMode::Supervisor => Mode::Supervisor,
            cli::ExitMode::Machine => Mode::Machine,
        },
    )?)
}

fn posix_exit_mode(opts: Options) -> Mode {
    match opts.posix_exit_mode {
        cli::ExitMode::User => Mode::User,
        cli::ExitMode::Supervisor => Mode::Supervisor,
        cli::ExitMode::Machine => Mode::Machine,
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    let cli = cli::parse();
    match cli.command {
        cli::Mode::Run(opts) => run(opts),
        cli::Mode::Debug(opts) => debug(opts),
    }
}
