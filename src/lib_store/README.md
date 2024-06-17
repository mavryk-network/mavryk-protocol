# mavryk-store
Summary line: Storage library for storing chain data

## Overview
- `mavryk-store` provides an abstraction over the disk storage. It aims
   to handles the on-disk storage of static objects such as blocks,
   operations, block's metadata, protocols and chain data.

## Implementation Details
- `mavryk-store` is a virtual library comprising the following packages:
  - `mavryk-store` itself only contains a `store.mli` file describing the public interface
    that all implementations of the library must provide.
  - `mavryk-store.real` is the real implementation of `mavryk-store`, used in production.
    For technical reasons, this library is just a thin layer over `mavryk-store-unix`, where the bulk of the implementation resides
  - `mavryk-store.mocked` is a mocked, in-memory implementation of `mavryk-store`, used in tests and simulations.
  - `mavryk-store-shared` contains type definitions and endodings used by all implementations and referred to
    by the public interface `store.mli`
  - `mavryk-store-unix` is contains the actual implementation of the store
  - `mavryk-store-unix.reconstruction` implements the history reconstruction feature
  - `mavryk-store-unix.snapshots` implements facilities for exporting and importing snapshots
- The main module is `Store`. It provides the abstract view of the
storage.
- The main components are:
  - `Cemented_block_store`: persistent block store with linear history
  - `Floating_block_store`: persistent block store with arborescent
    history
  - `Block_store`: persistent and cached generic block store based on
    both cemented and floating blocks stores.
  - `Snapshots`: canonical storage representation for storage
    import/export
- A comprehensive view of the storage implementation is available at
  https://protocol.mavryk.org/shell/storage.html

## API Documentation

- http://protocol.mavryk.org/api/odoc/_html/mavryk-storage/index.html
