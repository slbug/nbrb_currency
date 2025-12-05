# frozen_string_literal: true

class NbrbCurrency
  class RatesDocument
    attr_reader :rates, :updated_at

    def initialize(json_data)
      @rates = {}
      @updated_at = nil
      parse(json_data)
    end

    private

    def parse(json_data)
      data = JSON.parse(json_data)

      data.each { |rate_data| add_rate_entry(rate_data) }

      raise 'No rates parsed' if @rates.empty? || @updated_at.nil?
    end

    def add_rate_entry(rate_data)
      date = Date.parse(rate_data['Date'])
      @updated_at ||= date
      @rates[date] ||= []

      currency = rate_data['Cur_Abbreviation']
      rate = rate_data['Cur_OfficialRate'].to_s
      scale = rate_data['Cur_Scale'].to_s

      @rates[date] << [currency, rate, scale]
    end
  end
end
