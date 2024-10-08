//! Test of reveal preimage mechanism from [encoding::dac].

use mavryk_crypto_rs::hash::BlsSignature;
use mavryk_smart_rollup_encoding::dac::certificate::CertificateError;
use mavryk_smart_rollup_encoding::dac::certificate::*;
use mavryk_smart_rollup_encoding::dac::pages::*;
use mavryk_smart_rollup_host::path::RefPath;
use mavryk_smart_rollup_host::runtime::Runtime;

const MAX_DAC_ONE_SHOT_SIZE: usize = 10063860;

#[test]
fn certificate_reveal_to_store_small() {
    let data = vec![7];
    let mut host = mavryk_smart_rollup_mock::MockHost::default();
    let root_hash = prepare_preimages(&data, |_hash, page| {
        host.set_preimage(page);
    })
    .unwrap();

    let path = RefPath::assert_from(b"/dac/contents");
    host.store_write_all(&path, &[1, 2, 3, 4, 5]).unwrap();

    let cert = Certificate::V0(V0Certificate {
        root_hash,
        aggregated_signature: BlsSignature(Vec::new()),
        witnesses: mavryk_data_encoding::types::Zarith(0.into()),
    });

    let size = cert.reveal_to_store(&mut host, &path).unwrap();

    assert_eq!(size, data.len());
    assert_eq!(data, host.store_read_all(&path).unwrap());
}

#[test]
fn certificate_reveal_to_store_med() {
    // 4 MAX_PAGE_SIZEs
    let mut data = Vec::with_capacity(4 * MAX_PAGE_SIZE);
    (0u32..)
        .take(MAX_PAGE_SIZE)
        .map(u32::to_le_bytes)
        .for_each(|bytes| data.extend_from_slice(&bytes));

    let mut host = mavryk_smart_rollup_mock::MockHost::default();
    let root_hash = prepare_preimages(&data, |_hash, page| {
        host.set_preimage(page);
    })
    .unwrap();

    let path = RefPath::assert_from(b"/dac/contents");
    host.store_write_all(&path, &[1, 2, 3, 4, 5]).unwrap();

    let cert = Certificate::V0(V0Certificate {
        root_hash,
        aggregated_signature: BlsSignature(Vec::new()),
        witnesses: mavryk_data_encoding::types::Zarith(0.into()),
    });

    let size = cert.reveal_to_store(&mut host, &path).unwrap();

    assert_eq!(size, data.len());
    assert_eq!(data, host.store_read_all(&path).unwrap());
}

#[test]
fn certificate_reveal_to_store_max() {
    // MAX_DAC_ONE_SHOT_SIZE bytes
    let mut data = Vec::with_capacity(MAX_DAC_ONE_SHOT_SIZE);
    (0u32..)
        .take(MAX_DAC_ONE_SHOT_SIZE / 4)
        .map(u32::to_le_bytes)
        .for_each(|bytes| data.extend_from_slice(&bytes));
    let mut host = mavryk_smart_rollup_mock::MockHost::default();
    let root_hash = prepare_preimages(&data, |_hash, page| {
        host.set_preimage(page);
    })
    .unwrap();

    let path = RefPath::assert_from(b"/dac/contents");
    host.store_write_all(&path, &[1, 2, 3, 4, 5]).unwrap();

    let cert = Certificate::V0(V0Certificate {
        root_hash,
        aggregated_signature: BlsSignature(Vec::new()),
        witnesses: mavryk_data_encoding::types::Zarith(0.into()),
    });

    let size = cert.reveal_to_store(&mut host, &path).unwrap();

    assert_eq!(size, data.len());
    assert_eq!(data, host.store_read_all(&path).unwrap());
}

#[test]
fn certificate_reveal_to_store_too_large() {
    let data = vec![0; MAX_DAC_ONE_SHOT_SIZE + 1];
    let mut host = mavryk_smart_rollup_mock::MockHost::default();
    let root_hash = prepare_preimages(&data, |_hash, page| {
        host.set_preimage(page);
    })
    .unwrap();

    let path = RefPath::assert_from(b"/dac/contents");
    host.store_write_all(&path, &[1, 2, 3, 4, 5]).unwrap();

    let cert = Certificate::V0(V0Certificate {
        root_hash,
        aggregated_signature: BlsSignature(Vec::new()),
        witnesses: mavryk_data_encoding::types::Zarith(0.into()),
    });

    assert!(matches!(
        cert.reveal_to_store(&mut host, &path),
        Err(CertificateError::PayloadTooLarge)
    ));
}

#[test]
fn encode_decode_preimages() {
    // Arrange

    // produces almost 1000 hashes - forcing a tree 2 levels deep
    const TOTAL: usize = 500_000;

    let mut data = Vec::with_capacity(TOTAL * core::mem::size_of::<usize>());
    (0..TOTAL)
        .map(usize::to_le_bytes)
        .for_each(|b| data.extend_from_slice(&b));

    let mut host = mavryk_smart_rollup_mock::MockHost::default();
    let root_hash = prepare_preimages(&data, |_hash, page| {
        host.set_preimage(page);
    })
    .unwrap();

    let mut revealed = Vec::with_capacity(data.len());

    // Act
    let max_dac_levels = 4;
    let mut buffer = [0; MAX_PAGE_SIZE * 4];
    let mut save_revealed = save_content(&mut revealed);

    reveal_loop(
        &mut host,
        0,
        root_hash.as_ref(),
        &mut buffer,
        max_dac_levels,
        &mut save_revealed,
    )
    .unwrap();

    // Assert
    drop(save_revealed);
    assert_eq!(data, revealed, "Revealed different contents to original")
}

fn save_content<Host: Runtime>(
    buffer: &mut Vec<u8>,
) -> impl FnMut(&mut Host, V0SliceContentPage) -> Result<(), &'static str> + '_ {
    |_, page| {
        buffer.extend_from_slice(page.as_ref());
        Ok(())
    }
}
