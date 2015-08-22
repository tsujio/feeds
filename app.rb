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
_config = db[:config]

# Top
get '/' do
  config = _config.find.first

  _channels.find.each do |c|
    update_articles(c, _channels, _articles, _sequences,
      false, config[:minimum_update_period], config[:find_feed_language])
  end

  @title = ''
  @articles = _articles.find(read: false).sort(date: config[:articles_order])

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
  config = _config.find.first

  @url = params[:feed_url].to_s
  unless @url.empty?
    @feed = retrieve_feed(@url, config[:find_feed_language])
  else
    @feed = nil
  end

  @title = 'New Channel'

  haml :'channel/new', layout: :layout
end

# Add channel
post '/channel' do
  config = _config.find.first

  url = params[:feed_url].to_s
  feed = retrieve_feed(url, config[:find_feed_language])
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
  config = _config.find.first

  query = {}
  query['read'] = to_b(params['read']) if params.has_key? 'read'
  query['saved'] = to_b(params['saved']) if params.has_key? 'saved'

  @title = 'Articles'
  @articles = _articles.find(query)
    .sort(date: config[:articles_order])

  haml :'article/index', layout: :layout
end

# Update all article
patch '/article' do
  attrs = extract_params(params, [['read', :Boolean], ['saved', :Boolean]])
  _articles.find.update_many('$set' => attrs)

  200
end

# Update article
patch '/article/:id' do
  attrs = extract_params(params, [['read', :Boolean], ['saved', :Boolean]])
  _articles.find(serial: params[:id].to_i).update_one('$set' => attrs)

  200
end

# Update articles
post '/update_articles' do
  config = _config.find.first

  force = to_b(params[:force])
  _channels.find.each do |c|
    update_articles(c, _channels, _articles, _sequences,
      force, config[:minimum_update_period], config[:find_feed_language])
  end

  200
end

# Settings
get '/setting' do
  @config = _config.find.first
  @title = 'Settings'
  haml :setting, layout: :layout
end

# Update settings
post '/setting' do
  attrs = extract_params(params, [
    ['minimum_update_period', :Integer],
    ['find_feed_language', :String],
  ])
  if params.has_key? 'articles_order'
    attrs['articles_order'] = params['articles_order'] == 'desc' ? -1 : 1
  end

  _config.find.update_one(attrs, upsert: true)

  redirect to '/setting'
end
