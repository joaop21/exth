# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.3.0 - 2025-04-11

### Added

- Support for dynamic configuration through both inline options and application configuration
- examples directory with practical usage examples

[0.3.0]: https://github.com/joaop21/exth/releases/tag/v0.3.0

## 0.2.2 - 2025-04-07

### Changed

- Moved `Exth.Rpc.Encoding.encode_request/1` logic to `Exth.Rpc.Request.serialize/1`
- Moved `Exth.Rpc.Encoding.decode_response/1` logic to `Exth.Rpc.Response.deserialize/1`
- Removed `Exth.Rpc.Encoding` module
- Transport module does not receive an `encoder/1` and `decoder/1` option
  anymore. It's now direct to call `Exth.Rpc.Request.serialize/1` and
  `Exth.Rpc.Response.deserialize/1` functions.
- These changes aim to reduce the complexity of `Exth.Rpc` and `Exth.Transport`
  modules and make it easier to understand its internals.

[0.2.2]: https://github.com/joaop21/exth/releases/tag/v0.2.2

## 0.2.1 - 2025-04-05

### Changed

- `Exth.Provider` was refactored to reduce its complexity
- Fixed dialyzer warnings on `Exth.Provider` related to `has no local return`.
  Some types were fixed and the dialyzer warning does not appear anymore. No
  more warnings when defining providers.

[0.2.1]: https://github.com/joaop21/exth/releases/tag/v0.2.1

## 0.2.0 - 2025-04-04

### Added

- Documentation for `Exth.Rpc.Request` and `Exth.Rpc.Response` structs
- Allow inverting arguments order on `Exth.Rpc.send/2` and `Exth.Rpc.Client.send/2`
  - This change allows for more flexible usage patterns (pipes)
- Creation of request IDs on `Exth.Rpc.Client.send/2` when no pre-assigned IDs
  are provided
- Creation of requests with no pre-assigned IDs with `Exth.Rpc.request/2` and
  `Exth.Rpc.Client.request/2`

### Changed

- Replaced `Jason` with `JSON` for JSON encoding/decoding
- Updated `README.md` for documentation purposes
- Updated `Exth.Rpc.Client` documentation

[0.2.0]: https://github.com/joaop21/exth/releases/tag/v0.2.0

## [0.1.1] - 2025-03-27

### Changed

- `mint` dependency is now `:optional` instead of `only: :dev`;
- Updated `README.md` for documentation purposes, with more examples and better formatting;

[0.1.1]: https://github.com/joaop21/exth/releases/tag/v0.1.1

## [0.1.0] - 2025-03-25 🚀

### Added

- Initial release of Exth
- Core JSON-RPC functionality
  - Request/Response handling
  - Method generation
  - Parameter encoding
- Transport layer abstraction
  - HTTP Transport implementation using Tesla
  - Configurable middleware support
- Provider interface
  - Ethereum namespace support (`eth_*` methods)
  - Net namespace support (`net_*` methods)
  - Web3 namespace support (`web3_*` methods)
- Client caching mechanism
- Comprehensive documentation
- MIT License

[0.1.0]: https://github.com/joaop21/exth/releases/tag/v0.1.0
