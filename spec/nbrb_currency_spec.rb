require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'yaml'

describe "NbrbCurrency" do
  before(:each) do
    @bank = NbrbCurrency.new
    @cache_path = File.expand_path(File.dirname(__FILE__) + '/exchange_rates.xml')
    @yml_cache_path = File.expand_path(File.dirname(__FILE__) + '/exchange_rates.yml')
    @tmp_cache_path = File.expand_path(File.dirname(__FILE__) + '/tmp/exchange_rates.xml')
    @exchange_rates = YAML.load_file(@yml_cache_path)
  end

  after(:each) do
    if File.exists? @tmp_cache_path
      File.delete @tmp_cache_path
    end
  end

  it "should save the xml file from nbrb given a file path" do
    @bank.save_rates(@tmp_cache_path)
    File.exists?(@tmp_cache_path).should == true
  end

  it "should raise an error if an invalid path is given to save_rates" do
    lambda { @bank.save_rates(nil) }.should raise_exception
  end

  it "should update itself with exchange rates from nbrb website" do
    stub(OpenURI::OpenRead).open(NbrbCurrency::NBRB_RATES_URL) {@cache_path}
    @bank.update_rates
    NbrbCurrency::CURRENCIES.each do |currency|
      @bank.get_rate(currency, "BYR").should > 0
    end
  end

  it "should update itself with exchange rates from cache" do
    @bank.update_rates(@cache_path)
    NbrbCurrency::CURRENCIES.each do |currency|
      @bank.get_rate(currency, "BYR").should > 0
    end
  end

  it "should return the correct exchange rates using exchange" do
    @bank.update_rates(@cache_path)
    NbrbCurrency::CURRENCIES.reject{|c| %w{JPY ISK KWD}.include?(c) }.each do |currency|
      @bank.exchange(10000, currency, "BYR").cents.should == (@exchange_rates["currencies"][currency].to_f * 100).round
    end
    subunit = Money::Currency.wrap("KWD").subunit_to_unit.to_f
    expect(subunit).to eq(1000)

    #   1.000 KWD == 30996.47 BYR
    # 100.000 KWD == 3099647 BYR
    @bank.exchange(100000, "KWD", "BYR").cents.should == ((subunit / 1000) * @exchange_rates["currencies"]['KWD'].to_f * 100).round

    subunit = Money::Currency.wrap("JPY").subunit_to_unit.to_f
    expect(subunit).to eq(1)

    #    1 JPY == 111.943 BYR
    # 1000 JPY == 111943 BYR
    @bank.exchange(1000, "JPY", "BYR").cents.should == (@exchange_rates["currencies"]['JPY'].to_f * 1000).round
  end

  it "should return the correct exchange rates using exchange_with" do
    @bank.update_rates(@cache_path)
    NbrbCurrency::CURRENCIES.reject{|c| %w{JPY KWD ISK}.include?(c) }.each do |currency|
      expect(@bank.exchange_with(Money.new(10000, currency), "BYR").cents).to eq((@exchange_rates["currencies"][currency].to_f * 100).round)
      expect(@bank.exchange_with(100.to_money(currency), "BYR").cents).to eq((@exchange_rates["currencies"][currency].to_f * 100).round)
    end

    # No subunits in ISK and JPY.
    # Therefore 1 ISK is Money.new(1, "ISK"), not Money.new(100, "ISK")

    #  ISK  |    BYR    #
    #-------+-----------#
    #     1 |     74.54 #
    #   100 |   7454.00 #
    # 10000 | 745400.00 #

    expect(@bank.exchange_with(Money.new(10000, "ISK"), "BYR").cents).to eq(745400)
    expect(@bank.exchange_with(Money.new(1000, "JPY"), "BYR").cents).to eq(111943)
  end

  # in response to #4
  it "should exchange btc" do
    Money::Currency.register({
      :priority        => 1,
      :iso_code        => "BTC",
      :name            => "Bitcoin",
      :symbol          => "BTC",
      :subunit         => "Cent",
      :subunit_to_unit => 1000,
      :separator       => ".",
      :delimiter       => ","
    })
    @bank.add_rate("USD", "BTC", 1 / 13.7603)
    @bank.add_rate("BTC", "USD", 13.7603)
    @bank.exchange(100, "BTC", "USD").cents.should == 138
  end
end
