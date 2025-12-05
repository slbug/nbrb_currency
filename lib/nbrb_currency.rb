# frozen_string_literal: true

require 'open-uri'
require 'json'
require 'money'

require_relative 'nbrb_currency/version'
require_relative 'money/rates_store/nbrb_historical_store'

class InvalidCache < StandardError; end
class CurrencyUnavailable < StandardError; end

class NbrbCurrency < Money::Bank::VariableExchange # rubocop:disable Metrics/ClassLength
  include NbrbCurrencyVersion

  attr_accessor :last_updated, :rates_updated_at, :historical_last_updated, :historical_rates_updated_at

  SERIALIZER_DATE_SEPARATOR = '_AT_'
  DECIMAL_PRECISION = 5
  NBRB_RATES_URL = 'https://api.nbrb.by/exrates/rates?periodicity=0'
  NBRB_HISTORICAL_URL = 'https://api.nbrb.by/exrates/rates?ondate=%s&periodicity=0'

  # BYN redenomination date: July 1, 2016 (10000:1)
  REDENOMINATION_DATE = Date.new(2016, 7, 1)
  # Threshold to detect BYR vs BYN (BYR rates are typically > 1000, BYN < 100)
  BYR_THRESHOLD = 100

  CURRENCIES = %w(USD EUR RUB PLN UAH GBP JPY CNY CHF SEK NOK DKK CAD AUD NZD TRY KRW SGD HKD).freeze
  LEGACY_CURRENCIES = %w(BYR).freeze

  def initialize(store = Money::RatesStore::NbrbHistoricalStore.new, &)
    super
  end

  def update_rates(cache = nil)
    update_parsed_rates(doc(cache, NBRB_RATES_URL))
  end

  def update_historical_rates(cache = nil, date = nil)
    url = date ? (NBRB_HISTORICAL_URL % date.strftime('%Y-%m-%d')) : NBRB_RATES_URL
    update_parsed_historical_rates(doc(cache, url))
  end

  def save_rates(cache, url = NBRB_RATES_URL)
    raise InvalidCache unless cache

    File.open(cache, 'w') do |file|
      URI.parse(url).open { |io| io.each_line { |line| file.puts line } }
    end
  end

  def save_historical_rates(cache, date = nil)
    url = date ? (NBRB_HISTORICAL_URL % date.strftime('%Y-%m-%d')) : NBRB_RATES_URL
    save_rates(cache, url)
  end

  def exchange(cents, from_currency, to_currency, date = nil)
    exchange_with(Money.new(cents, from_currency), to_currency, date)
  end

  def exchange_with(from, to_currency, date = nil)
    base_currency = base_currency_for_date(date)
    rate = get_rate(from.currency, to_currency,
      date) || calculate_cross_rate(from.currency, to_currency, base_currency, date)

    calculate_exchange(from, to_currency, rate)
  end

  def get_rate(from, to, date = nil)
    return 1 if from == to

    check_currency_available(from, date)
    check_currency_available(to, date)

    date = date[:date] if date.is_a?(Hash)

    store.get_rate(::Money::Currency.wrap(from).iso_code, ::Money::Currency.wrap(to).iso_code, date)
  end

  def set_rate(from, to, rate, date = nil)
    date = date[:date] if date.is_a?(Hash)
    store.add_rate(::Money::Currency.wrap(from).iso_code, ::Money::Currency.wrap(to).iso_code, rate, date)
  end

  def rates
    store.each_rate.with_object({}) do |(from, to, rate, date), hash|
      key = [from, to].join(SERIALIZER_SEPARATOR)
      key = [key, date.to_s].join(SERIALIZER_DATE_SEPARATOR) if date
      hash[key] = rate
    end
  end

  def export_rates(format, file = nil, _opts = {})
    raise Money::Bank::UnknownRateFormat unless RATE_FORMATS.include? format

    store.transaction do
      s = case format
          when :json
            JSON.dump(rates)
          when :ruby
            Marshal.dump(rates)
          when :yaml
            YAML.dump(rates)
          end

      File.write(file, s) unless file.nil?
      s
    end
  end

  def import_rates(format, data, _opts = {})
    raise Money::Bank::UnknownRateFormat unless RATE_FORMATS.include? format

    store.transaction do
      parsed_data = parse_import_data(format, data)

      parsed_data.each do |key, rate|
        from, to = key.split(SERIALIZER_SEPARATOR)
        to, date = to.split(SERIALIZER_DATE_SEPARATOR)
        store.add_rate from, to, BigDecimal(rate, DECIMAL_PRECISION), date
      end
    end

    self
  end

  def check_currency_available(currency, date = nil)
    currency_string = currency.to_s
    base = base_currency_for_date(date)
    return true if currency_string == base
    return true if CURRENCIES.include?(currency_string)
    return true if LEGACY_CURRENCIES.include?(currency_string)

    raise CurrencyUnavailable, "No rates available for #{currency_string}"
  end

  protected

  def base_currency_for_date(date)
    (date && date < REDENOMINATION_DATE) ? 'BYR' : 'BYN'
  end

  def detect_base_currency_from_rate(usd_rate)
    (usd_rate.to_f > BYR_THRESHOLD) ? 'BYR' : 'BYN'
  end

  def doc(cache, url = NBRB_RATES_URL)
    json_data = cache ? File.read(cache) : URI.parse(url).open.read
    ::NbrbCurrency::RatesDocument.new(json_data)
  end

  def update_parsed_rates(rates_document)
    store.transaction do
      copy_rates_with_document_date(rates_document, false)
    end
    @rates_updated_at = rates_document.updated_at
    @last_updated = Time.now
  end

  def copy_rates_with_document_date(rates_document, with_date)
    rates_document.rates.each do |date, rates|
      usd_rate = rates.find { |curr, _, _| curr == 'USD' }
      base = usd_rate ? detect_base_currency_from_rate(usd_rate[1]) : base_currency_for_date(date)

      rates.each { |currency, rate, scale| process_currency_rate(currency, rate, scale, base, with_date ? date : nil) }
      set_rate(base, base, 1, with_date ? date : nil)
    end
  end

  def update_parsed_historical_rates(rates_document)
    store.transaction do
      copy_rates_with_document_date(rates_document, true)
    end
    @historical_rates_updated_at = rates_document.updated_at
    @historical_last_updated = Time.now
  end

  private

  def parse_import_data(format, data)
    case format
    when :json
      JSON.parse(data)
    when :ruby
      Marshal.load(data) # rubocop:disable Security/MarshalLoad
    when :yaml
      if Gem::Version.new(Psych::VERSION) >= Gem::Version.new('3.1.0')
        YAML.safe_load(data, permitted_classes: [BigDecimal])
      else
        YAML.safe_load(data, [BigDecimal], [], true)
      end
    end
  end

  def process_currency_rate(currency, rate, scale, base, date)
    return if currency == 'XDR'
    return unless currency_recognized?(currency)

    adjusted_rate = BigDecimal(rate, DECIMAL_PRECISION) / BigDecimal(scale, DECIMAL_PRECISION)
    set_rate(currency, base, adjusted_rate, date)
  end

  def currency_recognized?(currency)
    Money::Currency.wrap(currency)
    true
  rescue Money::Currency::UnknownCurrency
    false
  end

  def calculate_cross_rate(from_currency, to_currency, base_currency, date)
    from_base_rate = nil
    to_base_rate = nil

    store.transaction do
      from_base_rate = get_rate(from_currency.to_s, base_currency, date)
      to_base_rate = get_rate(to_currency, base_currency, date)
    end

    unless from_base_rate && to_base_rate
      message = "No conversion rate known for '#{from_currency.iso_code}' -> '#{to_currency}'"
      message << " on #{date}" if date
      raise Money::Bank::UnknownRate, message
    end

    from_base_rate / to_base_rate
  end

  def calculate_exchange(from, to_currency, rate)
    to_currency_money = Money::Currency.wrap(to_currency).subunit_to_unit
    from_currency_money = from.currency.subunit_to_unit
    decimal_money = BigDecimal(to_currency_money,
      DECIMAL_PRECISION) / BigDecimal(from_currency_money, DECIMAL_PRECISION)
    money = (decimal_money * from.cents * rate).round
    Money.new(money, to_currency)
  end
end

require_relative 'nbrb_currency/rates_document'
