require 'httparty'
require 'nokogiri'
require 'datamapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite:#{File.expand_path('..', __FILE__)}/db.sql")

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

  class FixedChart
    BaseUrl = "http://chart.apis.google.com/chart?chs=440x220&cht=lc"

    def self.link(prices)
      self.new(prices).link
    end

    def initialize(prices)
      @prices = prices
    end

    def link
      BaseUrl + color + data_size + labels + data
    end

    def data_size
      "&chds=" +
        Fuels.map{|fuel| prices_of(fuel).max}.join(",")
    end

    def labels
      "&chdl=" + Fuels.join("|")
    end

    def color
      "&chco=0000FF,00FF00,00FFFF,FF0000" 
    end

    def data
      "&chd=t:" +
        Fuels.map{|fuel| prices_of(fuel).join(",")}.join("|")
    end

    def prices_of(fuel)
      @prices.map{|p| p.send(fuel)} 
    end
  end

  class Chart
    def initialize(prices)
      @prices = prices
    end

    def script
      result = <<END
      google.load('visualization', '1', {'packages':['annotatedtimeline']});
      google.setOnLoadCallback(drawChart);
      function drawChart() {
        var data = new google.visualization.DataTable(#{DataTable.new(@prices).to_json});
        var chart = new google.visualization.AnnotatedTimeLine(document.getElementById('chart_div'));
        chart.draw(data, {scaleType:'maximized'});
      }
END
    end

    class DataTable
      def initialize(prices)
        @prices = prices
      end

      def to_json
        "{" + labels + "," + rows + "}"
      end
      
      def labels
        "cols: [" +
          "{label:'Date', type:'datetime'}," +
          Fuels.map{|fuel| "{label:'#{fuel}', type:'number'}" }.join(",") +
          "]"
      end
      
      def rows
        "rows: [#{make_rows}]"
      end

      def make_rows
        @prices.map{|price| make_a_row(price)}.join(",")        
      end

      def make_a_row(price)
        "{c:[" +
          make_columns(["new Date('#{price.created_at.to_s}')"] +
                       Fuels.map{|fuel| price.send(fuel)}) +
          "]}"
      end

      def make_columns(ary)
        ary.map{|elem| "{v: #{elem}}"}.join(",")
      end
    end
  end
  
  class TestData
    def initialize
      @rand = Random.new
    end

    def create
      100.times do
        Price.create(random_data)
      end
    end

    private
    
    def rand(range)
      @rand.rand(range)
    end
    
    def random_data
      hash = { :created_at => random_date }
      Fuels.each do |fuel|
        hash[fuel] = random_price
      end
      hash
    end

    def random_price
      rand(100..160).to_f/100.0
    end
    
    def random_date
      Time.new(2011, 1, rand(1..31), rand(0..23), rand(0..59))
    end
  end

  def self.store_latest_price
    latest = Price.first(order: [ :created_at.desc ])
    # return if last save within about the last 30 minutes
    return if latest && (latest.created_at > (DateTime.now - 0.02))
    current = CurrentPrice.new
    Price.create(current.prices.merge(:created_at => Time.now))
  end
end
