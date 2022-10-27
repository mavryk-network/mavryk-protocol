from os import path
import os
import subprocess
from typing import List, Optional
import pytest
from process.process_utils import format_command


def tezos_home() -> str:
    # we rely on a fixed directory structure of the tezos repo
    # TEZOS_HOME/tests_python/tools/paths.py
    cur_path = os.path.dirname(os.path.realpath(__file__))
    tezos_home = os.path.dirname(os.path.dirname(cur_path)) + '/'
    assert os.path.isfile(f'{tezos_home}/tests_python/tools/paths.py')
    return tezos_home


# Use environment variable if tests_python are put outside the tezos
# TEZOS_HOME = os.environ.get('TEZOS_HOME')
TEZOS_HOME = tezos_home()
TEZOS_BINARIES = os.environ.get('TEZOS_BINARIES')

ACCOUNT_PATH = path.join(TEZOS_HOME, 'tests_python', 'account')


MICHELSON_SCRIPT_DIRECTORIES_WELL_TYPED = [
    'attic',
    'entrypoints',
    'macros',
    'mini_scenarios',
    'non_regression',
    'opcodes',
]

MICHELSON_SCRIPT_DIRECTORIES = MICHELSON_SCRIPT_DIRECTORIES_WELL_TYPED + [
    'ill_typed',
    'legacy',
]

# The logical name is a list of path components where all but the the
# last denotes directories in the scripts path, and the last denotes
# the scripts basefile name with out the '.tz' suffix
LogicalName = List[str]

# LogicalNameStrTz is the string representation of a logical name with
# the '.tz' suffix added on
LogicalNameStrTz = str


class MichelsonScriptLocator:
    '''Wraps the Michelson script locator executable. This executable
    is a wrapper around [tezt/lib_tezos/michelson_scripts.ml] that
    locates and versions Michelson scripts'''

    MICHELSON_SCRIPT_LOCATOR_RELATIVE_PATH = (
        'tests_python/scripts/michelson_script_path.exe'
    )
    michelson_script_locator_build_path = (
        f'_build/default/{MICHELSON_SCRIPT_LOCATOR_RELATIVE_PATH}'
    )
    built = False

    def __init__(self, prefix: str, protocol_version: int):
        self.prefix = prefix
        self.protocol_version = protocol_version

    def run(
        self,
        action: str,
        directories: Optional[List[str]] = None,
        name: Optional[List[str]] = None,
    ) -> str:
        '''Runs the script locator with the given arguments. If the
        locator is not built, build it.
        '''
        if not self.built:
            cmd = ["dune", "build", self.MICHELSON_SCRIPT_LOCATOR_RELATIVE_PATH]
            print(format_command(cmd))
            try:
                subprocess.run(
                    cmd,
                    check=True,
                    cwd=TEZOS_HOME,
                )
                self.built = True
            except subprocess.CalledProcessError as exn:
                pytest.fail(
                    f'''Could not build
                {self.MICHELSON_SCRIPT_LOCATOR_RELATIVE_PATH} with
                command {cmd}. error output: {exn.stderr}, standard
                output: {exn.stdout}'''
                )

        def arg(name: str, value: str):
            return ["-a", name + "=" + value]

        args = (
            arg("prefix", self.prefix)
            + arg("protocol_version", str(self.protocol_version))
            + arg("action", action)
            + (
                arg("directories", ','.join(directories))
                if directories is not None
                else []
            )
            + (arg("name", '/'.join(name)) if name is not None else [])
        )

        cmd = [self.michelson_script_locator_build_path] + args
        print(format_command(cmd))
        try:
            proc = subprocess.run(
                cmd, check=True, cwd=TEZOS_HOME, text=True, capture_output=True
            )
        except subprocess.CalledProcessError as exn:
            pytest.fail(
                f'''{self.MICHELSON_SCRIPT_LOCATOR_RELATIVE_PATH}
        returned non-zero exit code with arguments {args}. error
        output: "{exn.stderr}", standard output: "{exn.stdout}"'''
            )
        return proc.stdout

    def find_script(self, name: LogicalName) -> str:
        '''Returns the path of a script [name] valid for
        [protocol_version] or fail if there is no such script.
        '''
        output = self.run(action="find", name=name)
        return output.strip()

    def find_script_by_name(self, logical_name_str_tz: LogicalNameStrTz) -> str:
        '''Like [find_script], but takes a [LogicalNameStrTz] instead.'''
        name = logical_name_str_tz.removesuffix('.tz').split('/')
        return self.find_script(name)

    def all_scripts(
        self,
        directories: Optional[List[str]] = None,
    ) -> List[LogicalNameStrTz]:
        '''Return all scripts in the version map valid for a protocol
        [protocol_number]. The searched directories is delimited to
        [directories], which defaults to
        [MICHELSON_SCRIPT_DIRECTORIES_WELL_TYPED]. Scripts are
        returned as LogicalNameStrTz, so [find_script] must
        be applied on the result to obtain paths.
        '''
        if directories is None:
            directories = MICHELSON_SCRIPT_DIRECTORIES_WELL_TYPED
        output = self.run(action="all", directories=directories)
        return [line + '.tz' for line in output.strip().split()]
