# NBRB Currency

Exchange rates from the National Bank of the Republic of Belarus (NBRB). Compatible with the [money](https://github.com/RubyMoney/money) gem.

## Installation

```bash
gem install nbrb_currency
```

Or add to your Gemfile:

```ruby
gem 'nbrb_currency'
```

## Usage

```ruby
require 'nbrb_currency'

# Create bank instance
bank = NbrbCurrency.new

# Update rates from NBRB
bank.update_rates

# Exchange money
money = Money.new(100_00, "USD")
money.exchange_to("BYN")  # => Money.new(250_00, "BYN")
```

### Historical Rates

The gem supports both BYR (pre-2016) and BYN (post-2016) currencies with automatic date-based selection:

```ruby
# Fetch historical rates for a specific date
bank.update_historical_rates(nil, Date.new(2020, 1, 15))

# Exchange with historical rates
bank.exchange(100_00, "USD", "BYN", Date.new(2020, 1, 15))

# Pre-redenomination rates (before July 1, 2016)
bank.exchange(100_00, "USD", "BYR", Date.new(2015, 1, 1))
```

### Caching

```ruby
# Save rates to file
bank.save_rates('/tmp/nbrb_rates.xml')

# Load rates from cache
bank.update_rates('/tmp/nbrb_rates.xml')

# Save historical rates
bank.save_historical_rates('/tmp/nbrb_historical.xml', Date.new(2020, 1, 1))
```

### Export/Import Rates

```ruby
# Export rates
yaml_string = bank.export_rates(:yaml)
json_string = bank.export_rates(:json)

# Import rates
bank.import_rates(:yaml, yaml_string)
bank.import_rates(:json, json_string)
```

## Currency Support

Supports major currencies including: USD, EUR, RUB, PLN, UAH, GBP, JPY, CNY, CHF, SEK, NOK, DKK, CAD, AUD, NZD, TRY, KRW, SGD, HKD.

Legacy support for BYR (Belarusian Ruble before July 1, 2016 redenomination).

## Currency Detection

The gem automatically detects BYR vs BYN based on:
- **Date**: Before July 1, 2016 → BYR, after → BYN
- **Rate magnitude**: > 100 → BYR, < 100 → BYN (when date is ambiguous)

## Error Handling

```ruby
begin
  bank.exchange(100, 'USD', 'XXX')
rescue CurrencyUnavailable => e
  puts "Currency not supported: #{e.message}"
end
```

## Migrating from 1.x

### Breaking Changes
- Minimum Ruby version: 2.x → 3.4.7
- Default currency: BYR → BYN (automatic based on date)
- API changed from XML to JSON

### Code Changes
```ruby
# v1.x
bank.get_rate("USD", "BYR")

# v2.0
bank.get_rate("USD", "BYN")  # For current rates
bank.get_rate("USD", "BYR", Date.new(2015, 1, 1))  # For historical pre-2016
```

## Requirements

- Ruby >= 3.4.7
- money gem >= 6.19

## License

MIT License. See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Add tests for your changes
4. Commit your changes
5. Push to the branch
6. Create a Pull Request
