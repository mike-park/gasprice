require 'httparty'
require 'nokogiri'
require 'datamapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, "sqlite:#{File.expand_path('..', __FILE__)}/db.sql")

module Gas

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
    
    Fuels = [[:regular_price, 'Regular 91 OCT', 1],
             [:super_price, 'Super 95 OCT', 3],
             [:premium_price, 'Super Premium 98 OCT', 5],
             [:diesel_price, 'Diesel', 7]]
    
    Fuels.each do |name, string, offset|
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
      Fuels.map do |name, string, offset|
        hash[string] = self.send(name)
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
    property :diesel_price, Float
  end

  DataMapper.finalize
  DataMapper.auto_upgrade!
end