# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2024-03-27

### Changed

- `mint` dependency is now `:optional` instead of `only: :dev`;
- Updated `README.md` for documentation purposes, with more examples and better formatting;

[0.1.1]: https://github.com/joaop21/exth/releases/tag/v0.1.1

## [0.1.0] - 2024-03-25 🚀

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
