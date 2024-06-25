// SPDX-FileCopyrightText: 2023 TriliTech <contact@trili.tech>
//
// SPDX-License-Identifier: MIT

// Allow dead code while this module contains stubs.
#![allow(dead_code)]

use risc_v_interpreter::{
    exec_env::{self, ExecutionEnvironment, ExecutionEnvironmentState},
    machine_state::{self, bus::main_memory, StepManyResult},
    state_backend,
    traps::EnvironException,
};

/// PVM state layout
pub type PvmLayout<EE, ML> = (
    state_backend::Atom<u64>,
    machine_state::MachineStateLayout<ML>,
    <EE as ExecutionEnvironment>::Layout,
);

/// Value for the initial version
const INITIAL_VERSION: u64 = 0;

/// Proof-generating virtual machine
pub struct Pvm<
    EE: ExecutionEnvironment,
    ML: main_memory::MainMemoryLayout,
    M: state_backend::Manager,
> {
    version: state_backend::Cell<u64, M>,
    pub(crate) machine_state: machine_state::MachineState<ML, M>,

    /// Execution environment state
    pub syscall_state: EE::State<M>,
}

impl<EE: ExecutionEnvironment, ML: main_memory::MainMemoryLayout, M: state_backend::Manager>
    Pvm<EE, ML, M>
{
    /// Bind the PVM to the given allocated region.
    pub fn bind(space: state_backend::AllocatedOf<PvmLayout<EE, ML>, M>) -> Self {
        // Ensure we're binding a version we can deal with
        assert_eq!(space.0.read(), INITIAL_VERSION);

        Self {
            version: space.0,
            machine_state: machine_state::MachineState::bind(space.1),
            syscall_state: EE::State::<M>::bind(space.2),
        }
    }

    /// Reset the PVM state.
    pub fn reset(&mut self) {
        self.version.write(INITIAL_VERSION);
        self.machine_state.reset();
        self.syscall_state.reset();
    }

    /// Provide input. Returns `false` if the machine state is not in
    /// `Status::Input` status.
    pub fn provide_input(&mut self, _level: u64, _counter: u64, _payload: &[u8]) -> bool {
        // TODO: https://gitlab.com/tezos/tezos/-/issues/6945
        // Implement input provider
        todo!("Input function is not implemented")
    }

    /// Get the current machine status.
    pub fn status(&self) -> Status {
        Status::Eval
    }

    /// Defines how to handle exceptions in the PVM execution environment.
    /// Returns `true` in case the PVM may continue evaluation afterwards.
    fn handle_exception(&mut self, exception: EnvironException) -> bool {
        match exception {
            EnvironException::EnvCallFromUMode
            | EnvironException::EnvCallFromSMode
            | EnvironException::EnvCallFromMMode => {
                match self
                    .syscall_state
                    .handle_call(&mut self.machine_state, exception)
                {
                    exec_env::EcallOutcome::Fatal => {
                        // TODO: https://app.asana.com/0/1206655199123740/1206682246825814/f
                        unimplemented!("Fatal exceptions aren't implemented yet")
                    }
                    exec_env::EcallOutcome::Handled { continue_eval } => continue_eval,
                }
            }
        }
    }

    /// Perform one step. Returns `false` if the PVM is not in [`Status::Eval`] status.
    pub fn step(&mut self) -> bool {
        if let Err(exc) = self.machine_state.step() {
            self.handle_exception(exc);
        }

        true
    }

    /// Perform at most `max_steps` steps. Returns the actual number of steps
    /// performed (retired instructions)
    ///
    /// If an environment trap is raised, handle it and
    /// return the number of retired instructions until the raised trap
    ///
    /// NOTE: instructions which raise exceptions / are interrupted are NOT retired
    ///       See section 3.3.1 for context on retired instructions.
    /// e.g: a load instruction raises an exception but the first instruction
    /// of the trap handler will be executed and retired,
    /// so in the end the load instruction which does not bubble it's exception up to
    /// the execution environment will still retire an instruction, just not itself.
    /// (a possible case: the privilege mode access violation is treated in EE,
    /// but a page fault is not)
    pub fn step_many(&mut self, max_steps: usize) -> usize {
        self.step_many_accum(max_steps, 0)
    }

    // Tail-recursive helper function for [step_many]
    fn step_many_accum(&mut self, max_steps: usize, accum: usize) -> usize {
        let StepManyResult {
            mut steps,
            exception,
        } = self.machine_state.step_many(max_steps, |_| true);

        // Total steps done
        let mut total_steps = accum.saturating_add(steps);

        if let Some(exc) = exception {
            // Raising the exception is not a completed step. Trying to handle it is.
            // We don't have to check against `max_steps` because running the
            // instruction that triggered the exception meant that `max_steps > 0`.
            total_steps = total_steps.saturating_add(1);
            steps = steps.saturating_add(1);

            // Exception was handled in a way that allows us to evaluate more.
            if self.handle_exception(exc) {
                let steps_left = max_steps.saturating_sub(steps);
                return self.step_many_accum(steps_left, total_steps);
            }
        }

        total_steps
    }
}

/// Machine status
pub enum Status {
    /// Evaluating normally
    Eval,

    /// Input has been requested by the PVM
    Input,
}
