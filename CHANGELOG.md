# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2025-12-05

### Breaking Changes
- Minimum Ruby version now 3.1.0
- Updated to money gem ~> 6.19
- Default base currency changed from BYR to BYN (with automatic date-based selection)

### Added
- Historical rates support with date-based exchange rates
- Dual currency support: BYR (pre-July 1, 2016) and BYN (post-July 1, 2016)
- `update_historical_rates(cache, date)` method for fetching historical rates
- `save_historical_rates(cache, date)` method for saving historical rates
- Date parameter support in `exchange()` and `exchange_with()` methods
- SAX parser for efficient XML parsing
- BigDecimal precision (5 decimal places) for accurate calculations
- `CurrencyUnavailable` exception for better error handling
- Export/import rates functionality (YAML, JSON, Ruby Marshal)
- Thread-safe transaction support via historical rates store
- Metadata in gemspec (changelog_uri, source_code_uri, bug_tracker_uri)

### Changed
- Refactored to match eu_central_bank architecture patterns
- Updated NBRB API URLs to use HTTPS
- Modernized gemspec to RubyGems 4.0 standards
- Updated specs to RSpec 3.x standards
- Converted README from RDoc to Markdown

### Removed
- Removed obsolete development dependencies (rr, shoulda, monetize)
- Removed support for Ruby < 3.1.0

## [Unreleased] - 2015-04-07

### Changed
- Updated for Money 6.x compatibility
- Fixed Money::Currency::TABLE removal in Money 5.0.0
- Fixed subunit conversion
- Updated RSpec should syntax
- Removed LVL and LTL (disappeared from NBRB XML)

### Added
- Monetize core extensions support

## [1.0.1] - 2011-11-02

### Fixed
- Money version bump
- JPY currency handling workaround

## [1.0.0] - 2011-10-26

### Initial Release
- Basic exchange rate functionality from NBRB
- BYR currency support
- Money gem compatibility
