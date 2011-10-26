require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'money'

class InvalidCache < StandardError ; end

class NbrbCurrency < Money::Bank::VariableExchange

  NBRB_RATES_URL = 'http://nbrb.by/Services/XmlExRates.aspx'
  CURRENCIES = %w(AUD BGN UAH DKK USD EUR PLN JPY IRR ISK CAD CNY KWD LVL LTL MDL NOK RUB SGD KGS KZT TRY GBP CZK SEK CHF)

  def update_rates(cache=nil)
    exchange_rates(cache).each do |exchange_rate|
      rate = exchange_rate.xpath("Rate").text
      currency = exchange_rate.xpath("CharCode").text
      scale = exchange_rate.xpath("Scale").text
      next if currency == "XDR"
      add_rate(currency, "BYR", (BigDecimal.new(rate) / BigDecimal.new(scale)).to_f)
    end
    add_rate("BYR", "BYR", 1)
  end

  def save_rates(cache)
    raise InvalidCache if !cache
    File.open(cache, "w") do |file|
      io = open(NBRB_RATES_URL) ;
      io.each_line {|line| file.puts line}
    end
  end

  def exchange(cents, from_currency, to_currency)
    exchange_with(Money.new(cents, from_currency), to_currency)
  end

  def exchange_with(from, to_currency)
    rate = get_rate(from.currency, to_currency)
    unless rate
      from_base_rate = get_rate(from.currency, "BYR")
      to_base_rate = get_rate(to_currency, "BYR")
      rate = (BigDecimal.new(from_base_rate, 8) / BigDecimal.new(to_base_rate, 8)).to_f
      raise "Rate #{from.currency} - #{to_currency} unknown!" unless rate
    end
    Money.new(((Money::Currency.wrap(to_currency).subunit_to_unit.to_f / from.currency.subunit_to_unit.to_f) * from.cents * rate).round, to_currency)
  end

  protected

  def exchange_rates(cache=nil)
    rates_source = !!cache ? cache : NBRB_RATES_URL
    doc = Nokogiri::XML(open(rates_source))
    doc.xpath('DailyExRates//Currency')
  end

end
