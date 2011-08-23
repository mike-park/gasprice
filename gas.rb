#!/usr/bin/env ruby

require 'sinatra'
require 'haml'
require ::File.expand_path('../data',  __FILE__)

before do
  @gas = Gas.new
end

get '/' do
  @prices = @gas.prices
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
      - @prices.keys.each do |fuel|
        %th= fuel
    %tr
      - @prices.values.each do |price|
        %td= price
