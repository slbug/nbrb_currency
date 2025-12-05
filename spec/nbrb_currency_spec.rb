# frozen_string_literal: true

require File.expand_path("#{File.dirname(__FILE__)}/spec_helper")

describe 'NbrbCurrency' do
  let(:bank) { NbrbCurrency.new }
  let(:tmp_cache_path) { File.expand_path("#{File.dirname(__FILE__)}/tmp/exchange_rates.json") }

  after do
    FileUtils.rm_f(tmp_cache_path)
  end

  describe 'current rates (BYN)' do
    it 'fetches and parse current rates', vcr: {cassette_name: 'current_rates'} do # rubocop:disable RSpec/MultipleExpectations
      bank.update_rates
      usd_rate = bank.get_rate('USD', 'BYN')

      expect(usd_rate).to be > 0
      expect(usd_rate).to be < 10
    end

    it 'saves rates to file', vcr: {cassette_name: 'current_rates'} do
      bank.save_rates(tmp_cache_path)
      expect(File.exist?(tmp_cache_path)).to be(true)
    end

    it 'raises error for invalid cache path' do
      expect { bank.save_rates(nil) }.to raise_exception(InvalidCache)
    end
  end

  describe 'historical rates - last month (BYN)' do
    it 'fetches rates from last month', vcr: {cassette_name: 'rates_2024_11'} do # rubocop:disable RSpec/MultipleExpectations
      date = Date.new(2024, 11, 1)
      bank.update_historical_rates(nil, date)
      usd_rate = bank.get_rate('USD', 'BYN', date)

      expect(usd_rate).to be > 0
      expect(usd_rate).to be < 10
    end
  end

  describe 'historical rates - before 2016 redenomination (BYR)' do
    it 'fetches and detect BYR rates', vcr: {cassette_name: 'rates_2015_01'} do # rubocop:disable RSpec/MultipleExpectations
      date = Date.new(2015, 1, 1)
      bank.update_historical_rates(nil, date)
      usd_rate = bank.get_rate('USD', 'BYR', date)

      expect(usd_rate).to be > 1000
      expect(usd_rate).to be < 100_000
    end

    it 'exchanges with BYR rates', vcr: {cassette_name: 'rates_2015_01'} do
      date = Date.new(2015, 1, 1)
      bank.update_historical_rates(nil, date)
      result = bank.exchange(100, 'USD', 'EUR', date)

      expect(result.cents).to be > 0
    end
  end

  describe 'historical rates - 2000 (BYR after first redenomination)' do
    it 'fetches BYR rates from 2000', vcr: {cassette_name: 'rates_2000_01'} do # rubocop:disable RSpec/MultipleExpectations
      date = Date.new(2000, 1, 1)
      bank.update_historical_rates(nil, date)
      usd_rate = bank.get_rate('USD', 'BYR', date)

      expect(usd_rate).to be > 100
      expect(usd_rate).to be < 10_000
    end
  end

  describe 'historical rates - 1996 (BYB - old Belarusian ruble)' do
    it 'fetches rates from 1996', vcr: {cassette_name: 'rates_1996_01'} do
      date = Date.new(1996, 1, 1)
      bank.update_historical_rates(nil, date)
      usd_rate = bank.get_rate('USD', 'BYR', date)

      expect(usd_rate).to be > 0
    end
  end

  describe 'currency detection' do
    it 'detects BYN for recent dates' do
      date = Date.new(2020, 1, 1)
      expect(bank.send(:base_currency_for_date, date)).to eq('BYN')
    end

    it 'detects BYR for old dates' do
      date = Date.new(2015, 1, 1)
      expect(bank.send(:base_currency_for_date, date)).to eq('BYR')
    end

    it 'detects currency from rate magnitude' do # rubocop:disable RSpec/MultipleExpectations
      expect(bank.send(:detect_base_currency_from_rate, 14_490)).to eq('BYR')
      expect(bank.send(:detect_base_currency_from_rate, 2.89)).to eq('BYN')
    end
  end

  describe 'exchange operations' do
    it 'exchanges between currencies', vcr: {cassette_name: 'current_rates'} do
      bank.update_rates
      result = bank.exchange(100_00, 'USD', 'EUR')

      expect(result.cents).to be > 0
    end

    it 'handles manual rate setting' do
      bank.set_rate('USD', 'BYN', 2.5)
      bank.set_rate('EUR', 'BYN', 2.8)
      result = bank.exchange(100, 'USD', 'EUR')

      expect(result.cents).to be > 0
    end
  end

  describe 'rate persistence' do
    it 'exports and import rates' do # rubocop:disable RSpec/MultipleExpectations, RSpec/ExampleLength
      bank.set_rate('USD', 'BYN', 2.5)
      bank.set_rate('EUR', 'BYN', 2.8)

      new_bank = NbrbCurrency.new
      new_bank.import_rates(:yaml, bank.export_rates(:yaml))

      expect(new_bank.get_rate('USD', 'BYN')).to eq(2.5)
      expect(new_bank.get_rate('EUR', 'BYN')).to eq(2.8)
    end
  end

  describe 'error handling' do
    it 'raises CurrencyUnavailable for unsupported currencies' do
      expect { bank.check_currency_available('XXX') }.to raise_exception(CurrencyUnavailable)
    end
  end

  describe 'metadata' do
    it 'sets last_updated when rates are downloaded', vcr: {cassette_name: 'current_rates'} do
      last_updated_before = bank.last_updated
      bank.update_rates
      last_updated_after = bank.last_updated

      expect(last_updated_before).not_to eq(last_updated_after)
    end

    it 'sets rates_updated_at when rates are downloaded', vcr: {cassette_name: 'current_rates'} do
      rates_updated_at_before = bank.rates_updated_at
      bank.update_rates
      rates_updated_at_after = bank.rates_updated_at

      expect(rates_updated_at_before).not_to eq(rates_updated_at_after)
    end
  end
end
