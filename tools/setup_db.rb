#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'mongo'
require 'optparse'

Mongo::Logger.logger.level = ::Logger::INFO

option = {}
_opt = OptionParser.new do |opt|
  opt.on('-s', '--server=VALUE', 'MongoDB server (host:port)') {|v| option[:server] = v }
  opt.on('-d', '--database=VALUE', 'Database name') {|v| option[:database] = v }  
  opt.parse!(ARGV)
end

unless option[:server] && option[:database]
  print _opt.help
  exit
end

db = Mongo::Client.new([option[:server]], database: option[:database])

# Set db version
raise RuntimeError.new("Database is already setup") if db[:config].find.count > 0
db[:config].insert_one(name: 'version', value: 1)

# Create indexes
db[:channels].indexes.create_many([
  {name: 'serial', key: {serial: 1}, unique: true},
  {name: 'link', key: {link: 1}, unique: true},
])
db[:articles].indexes.create_many([
  {name: 'serial', key: {serial: 1}, unique: true},
  {name: 'channel_date_link', key: {'channel.serial' => 1, date: -1, link: 1}, unique: true},
  {name: 'date', key: {date: -1}},
  {name: 'saved_date', key: {saved: 1, date: -1}},
  {name: 'read_date', key: {read: 1, date: -1}},
])
db[:sequences].indexes.create_many([
  {name: 'name', key: {name: 1}, unique: true},
])
