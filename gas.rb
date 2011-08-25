require 'httparty'
require 'nokogiri'
require 'datamapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, "sqlite:#{File.expand_path('..', __FILE__)}/db.sql")

module Gas

  Fuels = %w(petrol91 petrol95 petrol98 diesel)
  
  class CurrentPrice
    include HTTParty
    base_uri 'http://gasoline-germany.com/statistik.phtml'

    # Parse the response body however you like
    class Parser::Simple < HTTParty::Parser
      def parse
        Nokogiri.HTML(body)
      end
    end
    
    parser Parser::Simple
    
    HtmlMap = [[Fuels[0], 'Regular 91 OCT', 1],
               [Fuels[1], 'Super 95 OCT', 3],
               [Fuels[2], 'Super Premium 98 OCT', 5],
               [Fuels[3], 'Diesel', 7]]
    
    HtmlMap.each do |name, string, offset|
      define_method(name) do
        if price_fixing_table[offset].text == string
          price_to_number(price_fixing_table[offset + 1].text)
        else
          puts STDERR, "#{string} not found in:\n#{price_fixing_table.text}"
          0.0
        end
      end
    end
    
    def prices
      hash = {}
      Fuels.each do |fuel|
        hash[fuel] = self.send(fuel)
      end
      hash
    end
    
    private
    
    def price_fixing_table
      @price_fixing_table ||= self.class.get("/").css('.vorhersage td')
    end
    
    def price_to_number(string)
      string.gsub(',','.').to_f
    end
  end

  class Price
    include DataMapper::Resource

    property :id, Serial
    property :created_at, DateTime
    Fuels.each do |fuel|
      property fuel.to_sym, Float
    end
  end

  DataMapper.finalize
  DataMapper.auto_upgrade!
  def self.store_latest_price
    latest = Price.first(order: [ :created_at.desc ])
    # return if last save within about the last 30 minutes
    return if latest && (latest.created_at > (DateTime.now - 0.02))
    current = CurrentPrice.new
    Price.create(current.prices.merge(:created_at => Time.now))
  end
end
