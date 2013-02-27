#!/usr/bin/env ruby
# encoding: UTF-8

require 'sinatra'
require 'rack/ssl'
require 'net/dns'
require 'thin'
require 'yajl'

use Rack::SSL if ENV['RACK_ENV'] == 'production'
set :show_exceptions, false
$stdout.sync = true

get "/:domain", provides:'json' do
  domain    = params[:domain]
  on_heroku = domain_on_heroku?(domain)
  Yajl::Encoder.encode("on-heroku" => on_heroku)
end

APEX_FACES         = %w[ 75.101.163.44
                         75.101.145.87
                         174.129.212.2 ]
HEROKU_CNAME_BASES = %w[ .heroku.com.
                         .herokuapp.com.
                         .herokussl.com. ]
RX_SSL_HOSTNAME    = /^appid\d+herokucom-.*\.elb\.amazonaws\.com\.$/

class Net::DNS::RR
  def on_heroku?
    false
  end
end

class Net::DNS::RR::A
  def on_heroku?
    APEX_FACES.include? address.to_s
  end
end

class Net::DNS::RR::CNAME
  def on_heroku?
    domain_on_heroku?(cname) || cname =~ RX_SSL_HOSTNAME
  end
end

class Net::DNS::Resolver
  def self.on_heroku?(domain)
    start(domain).answer.any? { |record| record.on_heroku? }
  end
end

def domain_on_heroku?(domain)
  domain = domain.sub(/\.?$/, ".")
  HEROKU_CNAME_BASES.any? { |s| domain.end_with? s } || Net::DNS::Resolver.on_heroku?(domain)
end
