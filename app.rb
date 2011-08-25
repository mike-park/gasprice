#!/usr/bin/env ruby

require 'sinatra'
require 'haml'
require ::File.expand_path('../gas',  __FILE__)

before do
  @gas = Gas::CurrentPrice.new
end

get '/' do
  @current_prices = @gas.prices
  Gas::Price.create(:diesel_price => @gas.diesel_price, :created_at => Time.now)
  @prices = Gas::Price.all(:order => [ :created_at.desc ])
  haml :index
end

__END__
@@ layout
!!!
%html
  %head
    %title Gas Prices
    %link{:rel => 'stylesheet', :href => 'http://www.blueprintcss.org/blueprint/screen.css', :type => 'text/css'}
  %body
    .container
      = yield

@@ index
%h2 Current Prices
%table
  %thead
    %tr
      - @current_prices.keys.each do |fuel|
        %th= fuel
    %tr
      - @current_prices.values.each do |price|
        %td= price

%h2 Historical Prices
%table
  %thead
    - @prices.each do |price|
      %tr
        %td= price.created_at
        %td= price.diesel_price
    
