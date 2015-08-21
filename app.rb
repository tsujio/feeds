# -*- coding: utf-8 -*-

require 'sinatra'
require 'sinatra/config_file'
require 'mongo'
require 'haml'

require './helpers'

config_file './config.yaml'

set :haml, escape_html: true

Mongo::Logger.logger.level = settings.log[:mongo]

db = Mongo::Client.new([settings.mongo[:host]], database: settings.mongo[:database])
_channels = db[:channels]
_articles = db[:articles]
_sequences = db[:sequences]

# Top
get '/' do
  _channels.find.each do |c|
    update_articles(c, _channels, _articles, _sequences)
  end

  @title = ''
  @articles = _articles.find(read: false).sort(date: -1)

  if params['format'] == 'json'
    json @articles
  else
    haml :index, layout: :layout
  end
end

# List channels
get '/channel' do
  @title = 'Channels'
  @channels = _channels.find.sort(_id: 1)
  haml :'channel/index', layout: :layout
end

# New channel
get '/channel/new' do
  @url = params[:feed_url].to_s
  unless @url.empty?
    @feed = retrieve_feed(@url)
  else
    @feed = nil
  end

  @title = 'New Channel'

  haml :'channel/new', layout: :layout
end

# Add channel
post '/channel' do
  url = params[:feed_url].to_s
  feed = retrieve_feed(url)
  if _channels.find(link: feed[:link]).count == 0
    _channels.insert_one(
      serial: get_serial(_sequences, 'channel'),
      title: feed[:title],
      description: feed[:description],
      link: feed[:link],
      last_checked: Time.at(0).utc,
    )
  end

  redirect to '/'
end

# List articles
get '/article' do
  query = {}
  query['read'] = to_b(params['read']) if params.has_key? 'read'
  query['saved'] = to_b(params['saved']) if params.has_key? 'saved'

  @title = 'Articles'
  @articles = _articles.find(query)
    .sort(date: -1)

  haml :'article/index', layout: :layout
end

# Update article
patch '/article/:id' do
  attrs = {}
  attrs['read'] = to_b(params['read']) if params.has_key? 'read'
  attrs['saved'] = to_b(params['saved']) if params.has_key? 'saved'

  _articles.find(serial: params[:id].to_i).update_one('$set' => attrs)

  200
end

# Update articles
post '/update_articles' do
  force = to_b(params[:force])
  _channels.find.each do |c|
    update_articles(c, _channels, _articles, _sequences, force)
  end

  200
end
