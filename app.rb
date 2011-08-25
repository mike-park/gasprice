#!/usr/bin/env ruby

require 'sinatra'
require 'haml'
require ::File.expand_path('../gas',  __FILE__)

before do
end

get '/' do
  Gas.store_latest_price
  @prices = Gas::Price.all(:order => [ :created_at.desc ])
  haml :index
end

get '/chart' do
  prices = Gas::Price.all(:order => [ :created_at.desc ], :limit => 10)
  @chart_url = Gas::Chart.link(prices)
  haml :chart
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
%h2 Prices
%table
  %thead
    %tr
      %th Date
      - Gas::Fuels.each do |fuel|
        %th= fuel
  %tbody
    - @prices.each do |price|
      %tr
        %td= price.created_at
        - Gas::Fuels.each do |fuel|
          %td= price.send(fuel)
    
@@ chart
%h2 Chart
%div
  = @chart_url
%img{:src => @chart_url}      
