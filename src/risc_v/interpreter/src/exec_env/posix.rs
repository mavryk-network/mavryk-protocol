// SPDX-FileCopyrightText: 2024 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

use super::{EcallOutcome, ExecutionEnvironment, ExecutionEnvironmentState};
use crate::{
    machine_state::{
        bus::main_memory::MainMemoryLayout,
        mode::{Mode, ModeCell, ModeLayout},
        registers::{a0, a7},
        MachineState,
    },
    state_backend::{AllocatedOf, Atom, Cell, Manager},
    traps::EnvironException,
};

/// Posix execution environment
pub enum Posix {}

impl ExecutionEnvironment for Posix {
    type Layout = (Atom<u64>, Atom<u8>, ModeLayout);

    type State<M: Manager> = PosixState<M>;
}

/// Posix execution environment state
pub struct PosixState<M: Manager> {
    code: Cell<u64, M>,
    exited: Cell<u8, M>,
    exit_mode: ModeCell<M>,
}

impl<M: Manager> PosixState<M> {
    /// If an exit has been requested, return the exit code.
    #[allow(dead_code)]
    pub fn exit_code(&self) -> Option<u64> {
        self.exited().then(|| self.code.read())
    }

    /// Has an exit been requested?
    pub fn exited(&self) -> bool {
        self.exited.read() > 0
    }

    /// Configures the mode from which the test harness will exit.
    pub fn set_exit_mode(&mut self, mode: Mode) {
        self.exit_mode.write(mode);
    }
}

/// Implements a posix-ish environment for the RISC-V test suite.
impl<M> ExecutionEnvironmentState<M> for PosixState<M>
where
    M: Manager,
{
    type ExecutionEnvironment = Posix;

    fn bind(space: AllocatedOf<<Posix as ExecutionEnvironment>::Layout, M>) -> Self {
        Self {
            code: space.0,
            exited: space.1,
            exit_mode: ModeCell::bind(space.2),
        }
    }

    fn reset(&mut self) {
        self.exited.write(0);
        self.code.write(0);
        self.exit_mode.write(Mode::Machine);
    }

    fn handle_call<ML: MainMemoryLayout>(
        &mut self,
        machine: &mut MachineState<ML, M>,
        env_exception: EnvironException,
    ) -> EcallOutcome {
        if self.exited() {
            // Can't exit twice
            return EcallOutcome::Fatal;
        }

        let source_exception = env_exception.as_exception();
        let source_mode = match env_exception {
            EnvironException::EnvCallFromUMode => Mode::User,
            EnvironException::EnvCallFromSMode => Mode::Supervisor,
            EnvironException::EnvCallFromMMode => Mode::Machine,
        };
        let exit_mode = self.exit_mode.read();

        if source_mode != exit_mode {
            let return_pc = machine.hart.pc.read();
            let new_pc = machine.hart.take_trap(source_exception, return_pc);
            machine.hart.pc.write(new_pc);

            return EcallOutcome::Handled {
                continue_eval: true,
            };
        }

        let mut handle_exit = |code| {
            let exited = self.exited.read();
            self.exited.write(exited.saturating_add(1));
            self.code.write(code);

            EcallOutcome::Handled {
                continue_eval: false,
            }
        };

        // Successful physical memory tests set
        //   a7 = 93 & a0 = 0
        // Successful virtual memory tests set
        //   a7 = 0 (a7 never gets set) & a0 = 1
        // Failed physical memory tests set
        //   a7 = 93 & a0 = 1 | (TEST_FAILED << 1)
        // Failed virtual memory tests set
        //   a7 = 0 (a7 never gets set) & a0 = 1 | (TEST_FAILED << 1)
        let a7_val = machine.hart.xregisters.read(a7);
        let a0_val = machine.hart.xregisters.read(a0);
        match (a7_val, a0_val) {
            // Exit (test pass, physical | virtual)
            (93, 0) | (0, 1) => handle_exit(0),

            // Exit (test fail, physical | virtual)
            (93, code) | (0, code) => handle_exit(code),

            // Unimplemented
            _ => EcallOutcome::Fatal,
        }
    }
}
