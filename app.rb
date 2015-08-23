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

  _channels.find
    .sort(last_checked: 1)
    .limit(config[:amount_of_channels_to_update_at_once]).each do |c|
    update_articles(c, _channels, _articles, _sequences,
      false, config[:minimum_update_period])
  end

  redirect to '/article?read=false&order=asc'
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
    feed_urls = find_feed_urls(@url, config[:find_feed_language])
    if feed_urls.size == 0
      raise RuntimeError.new("Cannot find feed url")
    end

    @feeds = feed_urls.map {|u| retrieve_feed(u) }
  else
    @feeds = nil
  end

  @title = 'New Channel'

  @existing_channels = _channels.find
    .sort(_id: 1)
    .map {|a| a[:_feed_url] }

  haml :'channel/new', layout: :layout
end

# Add channel
post '/channel' do
  config = _config.find.first

  if params.has_key? 'feed_url'
    feed_urls = [params[:feed_url].to_s]
  else
    feed_urls = params[:feed_urls].to_s
      .split("\n")
      .map {|u| u.strip }
  end

  feed_urls.each do |url|
    next if url.empty?
    add_channel(url, _channels, _sequences)
  end

  redirect to '/'
end

# Delete channel
delete '/channel/:id' do
  _channels.find(serial: params[:id].to_i).delete_one

  200
end

# List articles
get '/article' do
  config = _config.find.first

  query = {}
  query['read'] = to_b(params['read']) if params.has_key? 'read'
  query['saved'] = to_b(params['saved']) if params.has_key? 'saved'
  query['channel.serial'] = params['channel_id'].to_i if params.has_key? 'channel_id'

  if params['order']
    order = params['order'] == 'asc' ? 1 : -1
  else
    order = config[:articles_order]
  end

  if params.has_key? 'last_article_id'
    last_article_id = params[:last_article_id].to_i
    last_article = _articles.find(serial: last_article_id).first
    if last_article
      last_article_date = last_article[:date]
      gte_or_lte = order == 1 ? '$gte' : '$lte'
      query.merge!({
        date: {gte_or_lte => last_article_date},
        serial: {'$ne' => last_article_id},
      })
    end
  end

  @title = 'Articles'
  @articles = _articles.find(query)
    .sort(date: order)
    .limit(config[:amount_of_articles_at_once])

  if request.xhr?
    @articles.map {|a|
      haml(:'article/_article', locals: {article: a}, layout: false)
    }.join()
  else
    haml :'article/index', layout: :layout
  end
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
      force, config[:minimum_update_period])
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
    ['amount_of_articles_at_once', :Integer],
    ['amount_of_channels_to_update_at_once', :Integer],
  ])
  if params.has_key? 'articles_order'
    attrs['articles_order'] = params['articles_order'] == 'desc' ? -1 : 1
  end

  _config.find.update_one(attrs, upsert: true)

  redirect to '/setting'
end
