use clap::{Parser, Subcommand, ValueEnum};
use serde::{Deserialize, Serialize};
use std::io;
use tezos_crypto_rs::hash;
use tezos_crypto_rs::PublicKeyWithHash;
use tezos_data_encoding::enc::BinWriter;

#[derive(Parser)]
#[command(long_about = None)]
struct Cli {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(ValueEnum, Debug, Clone)]
enum Order {
    Ordered,
    Random,
}

#[derive(Subcommand)]
enum Commands {
    ToHex {
        #[arg(short, long)]
        address: String,
    },
    ToHexContract {
        #[arg(short, long)]
        address: String,
    },
    ToTz4 {
        #[arg(short, long)]
        address: String,
    },
    TicketHashes,
    GenerateAccountKeys {
        #[arg(short, long)]
        accounts_output_file: String,
    },
    AccountDiffsToTx {
        #[arg(short = None, long)]
        accounts_file: String,
        #[arg(short = None, long)]
        accounts_output_file: String,
        #[arg(short = None, long)]
        account_diff_file: String,
        #[arg(short = None, long)]
        tx_output_file: String,
        #[arg(value_enum)]
        order: Order,
    },
}

fn main() -> io::Result<()> {
    let cli = Cli::parse();

    match &cli.command {
        Some(Commands::ToHex { address }) => {
            let address = hash::SmartRollupHash::from_b58check(&address).unwrap();
            println!("{}", hex::encode(address.0));
        }
        Some(Commands::ToHexContract { address }) => {
            let address =
                tezos_smart_rollup_encoding::contract::Contract::from_b58check(address).unwrap();
            let mut bin = Vec::new();
            address.bin_write(&mut bin).unwrap();
            println!("{}", hex::encode(bin));
        }
        Some(Commands::ToTz4 { address }) => {
            let address = tezos_crypto_rs::hash::PublicKeyBls::from_base58_check(&address).unwrap();
            let tz4 = address.pk_hash().unwrap();
            println!("{tz4}");
            println!("tz4 bytes: {}", hex::encode(tz4.0));
            println!("{address}");
            println!("bls bytes: {}", hex::encode(address.0));
        }
        Some(Commands::TicketHashes) => {
            let red = make_ticket(Colour::Red, 1).hash().unwrap();
            let gre = make_ticket(Colour::Blue, 1).hash().unwrap();
            let blu = make_ticket(Colour::Green, 1).hash().unwrap();

            println!("R: {red}");
            println!("G: {gre}");
            println!("B: {blu}");
        }
        Some(Commands::GenerateAccountKeys {
            accounts_output_file,
        }) => generate_account_keys(&accounts_output_file)?,
        Some(Commands::AccountDiffsToTx {
            accounts_file,
            accounts_output_file,
            account_diff_file,
            tx_output_file,
            order,
        }) => generate_tx(
            tx_output_file,
            account_diff_file,
            accounts_file,
            accounts_output_file,
            order,
        )?,
        _ => (),
    }

    Ok(())
}

// --------------
// Key management
// --------------
#[derive(Serialize, Deserialize)]
struct Account {
    ikm: hash::SeedEd25519,
    tz1: hash::ContractTz1Hash, //crypto::hash::Layer2Tz4Hash,
    counter: i64,
}

impl Account {
    fn keypair(&self) -> (hash::PublicKeyEd25519, hash::SecretKeyEd25519) {
        self.ikm.clone().keypair().unwrap()
    }
}

#[derive(Serialize, Deserialize)]
struct Keys {
    no_pixel_account: Account,
    pixel_accounts: Vec<Account>,
}

fn save_keys(out_file: &str, keys: &Keys) -> io::Result<()> {
    let mut file = std::fs::File::create(out_file)?;

    serde_json::ser::to_writer(&mut file, keys).expect("serialization of keys failed");
    Ok(())
}

/// Generates & saves 5000 'pixel' accounts, and one 'no-pixel' account.
fn generate_account_keys(out_file: &str) -> io::Result<()> {
    use rand::RngCore;

    let mut rng = rand::thread_rng();

    let mut gen_key = || {
        let mut ikm = [0; 32];
        rng.fill_bytes(ikm.as_mut_slice());

        let ikm = hash::SeedEd25519(ikm.to_vec());
        Account {
            tz1: ikm.clone().keypair().unwrap().0.pk_hash().unwrap(),
            ikm,
            counter: 0,
        }
    };

    let keys = Keys {
        no_pixel_account: gen_key(),
        pixel_accounts: (0..5000).map(|_| gen_key()).collect(),
    };

    save_keys(out_file, &keys)?;

    Ok(())
}

/// Loads 5000 'pixel' accounts, and one 'no-pixel' account.
fn load_account_keys(file: &str) -> io::Result<Keys> {
    let file = std::fs::File::open(file)?;

    let keys: Keys = serde_json::de::from_reader(&file).expect("deserializing keys failed");

    assert_eq!(keys.pixel_accounts.len(), 5000);

    Ok(keys)
}

// -------------
// TX Generation
// -------------
#[derive(Copy, Clone)]
enum Colour {
    Green,
    Red,
    Blue,
}

use Colour::*;

impl Colour {
    fn to_string(&self) -> String {
        match self {
            Red => "R",
            Green => "G",
            Blue => "B",
        }
        .into()
    }

    fn to_index(&self) -> u64 {
        match self {
            Red => 0,
            Green => 1,
            Blue => 2,
        }
    }
}

// diffs are between -255 and 255.
#[derive(Debug, Serialize, Deserialize, PartialEq, Ord, Eq)]
struct AccountDiff {
    id: usize,
    red: i32,
    green: i32,
    blue: i32,
}

impl std::cmp::PartialOrd for AccountDiff {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        self.id.partial_cmp(&other.id)
    }
}

fn load_account_diffs(file: &str) -> io::Result<Vec<AccountDiff>> {
    let diffs = csv::ReaderBuilder::new()
        .has_headers(false)
        .from_path(file)?
        .deserialize()
        .collect::<Result<_, _>>()
        .expect("deserialization should work");
    Ok(diffs)
}

use hash::{ContractKt1Hash, HashTrait};
use tezos_smart_rollup_encoding::contract::Contract;
use tezos_smart_rollup_encoding::michelson::ticket::StringTicket;

lazy_static::lazy_static! {
    static ref ORIGINATOR: Contract = Contract::Originated(
        ContractKt1Hash::from_b58check("KT1GFe2TjNNXmk7jx89unytgS7oEwcAGGMSo").unwrap()
    );
}

fn make_ticket(colour: Colour, amount: u64) -> StringTicket {
    StringTicket::new((*ORIGINATOR).clone(), colour.to_string(), amount).unwrap()
}

use kernel_core::inbox::v1::{Operation, OperationContent};
use kernel_core::inbox::Signer;
use kernel_core::inbox::v1::sendable::Batch;

// to start with just pks, can optimise later
fn generate_tx(
    output_file: &str,
    diff_file: &str,
    accounts_file: &str,
    output_accounts_file: &str,
    order: &Order,
) -> io::Result<()> {
    let mut accounts = load_account_keys(accounts_file)?;
    let mut diffs = load_account_diffs(diff_file)?;

    use rand::seq::SliceRandom;
    if let Order::Random = order {
        diffs.shuffle(&mut rand::thread_rng())
    } else {
        diffs.sort();
    }

    // Where positive diffs exist, transfer from the 'no pixel' account
    // Since these all come from the same account, we can append multiple
    // transfers all together into larger transactions, which saves signatures
    let mut operations: Vec<(Operation, hash::SecretKeyEd25519)> = Vec::with_capacity(15000);

    let make_op_from_np = |colour: Colour, amount, source_idx, accounts: &mut Keys| {
        let destination: &Account = accounts.pixel_accounts.get(source_idx).unwrap();

        let ticket_id = colour.to_index();
        let transfer =
            OperationContent::compressed_transfer(destination.tz1.clone(), ticket_id, amount)
                .unwrap();

        let key = accounts.no_pixel_account.keypair();

        let counter = accounts.no_pixel_account.counter;
        let signer = if counter > 0 {
            Signer::Tz1(accounts.no_pixel_account.tz1.clone())
        } else {
            Signer::PublicKey(key.0)
        };

        let op = Operation {
            contents: transfer,
            counter,
            signer,
        };

        accounts.no_pixel_account.counter += 1;
        (op, key.1)
    };

    // Where negative diffs exist, transfer to the 'no pixel' account
    // We add transfers out of the same account together into a single
    // transaction.
    let make_op_to_np = |colour: Colour, amount, source_idx, accounts: &mut Keys| {
        let account: &mut Account = accounts.pixel_accounts.get_mut(source_idx).unwrap();
        let key = account.keypair();

        let signer = if account.counter == 0 {
            Signer::PublicKey(key.0)
        } else {
            Signer::Tz1(account.tz1.clone())
        };

        let destination = &accounts.no_pixel_account.tz1;

        let ticket_id = colour.to_index();
        let content =
            OperationContent::compressed_transfer(destination.clone(), ticket_id, amount).unwrap();

        let op = Operation {
            signer,
            counter: account.counter,
            contents: content,
        };

        account.counter += 1;
        (op, key.1)
    };

    for diff in diffs.iter() {
        if diff.red >= 0 {
            operations.push(make_op_from_np(
                Red,
                diff.red as u64,
                diff.id,
                &mut accounts,
            ));
        } else {
            operations.push(make_op_to_np(Red, -diff.red as u64, diff.id, &mut accounts));
        }

        if diff.blue >= 0 {
            operations.push(make_op_from_np(
                Blue,
                diff.blue as u64,
                diff.id,
                &mut accounts,
            ));
        } else {
            operations.push(make_op_to_np(
                Blue,
                -diff.blue as u64,
                diff.id,
                &mut accounts,
            ));
        }

        if diff.green >= 0 {
            operations.push(make_op_from_np(
                Green,
                diff.green as u64,
                diff.id,
                &mut accounts,
            ));
        } else {
            operations.push(make_op_to_np(
                Green,
                -diff.green as u64,
                diff.id,
                &mut accounts,
            ));
        }
    }

    // So we now have a list of transfers from no_pixel to others
    // and a list of transactions from all accounts to no_pixel

    // So now we make a giant batch: all the transactions -> np, and a single
    // transaction from np to all accounts.
    // We will aggregate all signatures across all of this.
    // *NB* this is likely to be _very_ slow - but will give us our
    // approximate worst-case for TPS, which we can then try and improve over time.

    let op_list = Batch::new(operations);

    let mut bin_message = Vec::new();

    op_list.bin_write(&mut bin_message).unwrap();

    save_keys(output_accounts_file, &accounts).unwrap();

    // save message
    use std::io::Write;
    let mut f = std::fs::File::create(output_file).unwrap();
    f.write(&bin_message)?;

    Ok(())
}
