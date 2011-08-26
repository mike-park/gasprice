#!/usr/bin/env ruby

require 'sinatra'
require 'haml'
require ::File.expand_path('../gas',  __FILE__)

configure :production do
  ENV['APP_ROOT'] ||= File.dirname(__FILE__)
  $:.unshift "#{ENV['APP_ROOT']}/vendor/plugins/newrelic_rpm/lib"
  require 'newrelic_rpm'
end

before do
end

get '/' do
  Gas.store_latest_price
  @prices = Gas::Price.all(:order => [ :created_at.desc ], :limit => 10)
  haml :index
end

get '/chart' do
  @prices = Gas::Price.all(:order => [ :created_at.desc ])
  @chart_script = Gas::Chart.new(@prices).script
  @prices = @prices.slice(0..10)
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
%a{href: 'chart'}
  Show Chart
= haml :price_table

@@ price_table
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
%script{type:'text/javascript', src:'https://www.google.com/jsapi'}
%script{type:'text/javascript'}
  = @chart_script
%h2 Chart
%div{id:'chart_div', style:'width: 700px; height: 400px; margin-bottom: 10px;'}
%h3 Last 10 price fixes
= haml :price_table
