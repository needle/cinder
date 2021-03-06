require 'rubygems'
require 'uri'
require 'mechanize'
require 'csv'
require 'colored'

Dir[File.join(File.dirname(__FILE__), 'cinder/**/*.rb')].sort.each { |lib| require lib }


module Cinder
  VERSION = '0.4.1'
  class Error < StandardError; end
end
