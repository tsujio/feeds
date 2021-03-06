# -*- coding: utf-8 -*-

require 'sinatra'
require 'sanitize'
require 'open-uri'
require 'nokogiri'
require 'rss'

module Helpers
  public

  # Increment and get serial number
  def get_serial(_sequences, name)
    doc = _sequences.find(name: name)
      .find_one_and_update(
        {'$inc' => {value: 1}},
        return_document: :after, upsert: true
      )
    doc[:value]
  end

  # Find feed urls for the target url
  def find_feed_urls(url, find_feed_language = nil)
    # Fetch content
    content_type, charset, data = open(
      url, "Accept-Language" => find_feed_language
    ) {|f| [f.content_type, f.charset, f.read] }

    # Parse content
    case content_type
    when 'application/xml', 'application/rss+xml', 'text/xml'
      [url]
    when 'text/html'
      # Parse html
      doc = Nokogiri::HTML.parse(data, nil, charset)

      # Handle meta-refresh
      meta_refresh = doc.at('meta[http-equiv="refresh"]')
      if meta_refresh
        redirect_url = meta_refresh['content'][/URL=(.+)/, 1].gsub(/['"]/, '')
        return find_feed_urls(redirect_url, find_feed_language)
      end

      # Find feed urls
      doc.xpath('/html/head/link[@type="application/rss+xml"]')
        .map {|n| URI::join(url, n.attribute('href')).to_s }
    else
      []
    end
  end

  # Retrieve feed
  def retrieve_feed(feed_url, validate = true)
    rss = nil
    begin
      rss = RSS::Parser.parse(feed_url, validate)
    rescue RSS::InvalidRSSError => e
      raise e unless validate
      return retrieve_feed(feed_url, false)
    end

    # Convert to rss object if got atom
    if rss.class == RSS::Atom::Feed
      rss = rss.to_rss('2.0')
    end

    {
      title: rss.channel.title,
      description: rss.channel.description,
      link: rss.channel.link,
      _feed_url: feed_url,
      items: rss.items.map {|item|
        {
          title: item.title,
          description: item.description,
          link: item.link,
          content_encoded: item.content_encoded,
          date: item.date || item.dc_date || item.pubDate,
        }
      }
    }
  end

  # Add channel
  def add_channel(feed_url, _channels, _sequences)
    feed = retrieve_feed(feed_url)
    if _channels.find(_feed_url: feed[:_feed_url]).count == 0
      _channels.insert_one(
        serial: get_serial(_sequences, 'channel'),
        title: feed[:title],
        description: feed[:description],
        link: feed[:link],
        _feed_url: feed[:_feed_url],
        last_checked: Time.at(0).utc,
      )
    end
  end

  # Fetch and store articles
  def update_channel(channel, _channels, _articles, _sequences,
    force = false, minimum_update_period = 900)

    logger.info("Begin updating channel: #{channel[:_feed_url]}")

    if !force &&
        Time.now - channel[:last_checked] < minimum_update_period
      logger.info("Skip updating channel (Too frequent)")
      return
    end

    begin
      feed = retrieve_feed(channel[:_feed_url])
    rescue RSS::Error => e
      logger.error(e)
      return
    end

    feed[:items].each do |item|
      next if _articles.find(
        link: item[:link],
        date: item[:date].utc,
        'channel.serial' => channel[:serial]
      ).count > 0

      _articles.insert_one(
        serial: get_serial(_sequences, 'article'),
        channel: {
          serial: channel[:serial],
          title: feed[:title],
          link: feed[:link],
        },
        title: item[:title],
        description: item[:description],
        link: item[:link],
        content_encoded: item[:content_encoded],
        date: item[:date].utc,
        read: false,
        saved: false,
      )
    end

    _channels.find(_id: channel[:_id])
      .update_one('$set' => {last_checked: Time.now.utc})

    logger.info("End updating channel")
  end

  # Convert object to boolean
  def to_b(obj, strict = false)
    obj = obj.downcase if obj.is_a?(String) || obj.is_a?(Symbol)
    return true if ['true', 'yes', :true, :yes, 1].include? obj
    return false if ['false', 'no', :false, :no, 0].include? obj
    raise RuntimeError.new("Cannot convert to boolean: #{obj}") if strict
    return false
  end

  # Extract only permitted params
  def extract_params(params, keys)
    _params = {}
    keys.each do |key, type|
      next unless params.has_key? key

      case type
      when :Boolean
        _params[key] = to_b(params[key])
      when :String
        _params[key] = params[key].to_s
      when :Integer
        _params[key] = params[key].to_i
      else
        _params[key] = params[key].to_s
      end
    end

    _params
  end

  # Sanitize string
  def san(s)
    Sanitize.clean(s, elements: [
        'p', 'br', 'ul', 'ol', 'li', 'dl', 'dt', 'dd', 'a', 'img', 'blockquote'
      ],
      attributes: {
        'a' => ['href'],
        'img' => ['src', 'alt', 'width', 'height'],
        'blockquote' => ['cite', 'title'],
      },
      protocols: {
        'a' => {'href' => ['http', 'https', 'mailto']},
        'img' => {'href' => ['http', 'https']},
        'blockquote' => {'cite' => ['http', 'https']},
      })
  end

  module_function :find_feed_urls, :retrieve_feed, :to_b, :san, :extract_params
end

helpers do
  include Helpers
end
