# frozen_string_literal: true

class Money
  module RatesStore
    class NbrbHistoricalStore < Money::RatesStore::Memory
      INDEX_DATE_SEPARATOR = '_AT_'

      def add_rate(currency_iso_from, currency_iso_to, rate, date = nil)
        transaction { rates[rate_key_for(currency_iso_from, currency_iso_to, date)] = rate }
      end

      def get_rate(currency_iso_from, currency_iso_to, date = nil)
        transaction { rates[rate_key_for(currency_iso_from, currency_iso_to, date)] }
      end

      def each_rate(&)
        enum = Enumerator.new do |yielder|
          rates.each do |key, rate|
            iso_from, iso_to = key.split(Memory::INDEX_KEY_SEPARATOR)
            iso_to, date = iso_to.split(INDEX_DATE_SEPARATOR)
            date = Date.parse(date) if date
            yielder.yield iso_from, iso_to, rate, date
          end
        end

        block_given? ? enum.each(&) : enum
      end

      private

      def rate_key_for(currency_iso_from, currency_iso_to, date = nil)
        key = [currency_iso_from, currency_iso_to].join(Memory::INDEX_KEY_SEPARATOR)
        key = [key, date.to_s].join(INDEX_DATE_SEPARATOR) if date
        key.upcase
      end
    end
  end
end
