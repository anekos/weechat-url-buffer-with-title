#!/usr/bin/ruby
# vim: set fileencoding=utf-8 :


=begin DOC

URL-Buffer-With-Title
=====================

Make URL (with title) collection buffer.


Options
=======

> /set plugins.var.ruby.url-buffer-with-title.format '<buffer_number>! <title> - <url>'

## accept_url

If this option is set, this plugin collects only matched urls.

## ignore_url

If this option is set, this plugin collects only not matched urls.

## format

Display format.
Default is "[<buffer_number>] <title>\n<url>"


Author
======

anekos <anekos at snca dot net>


Licence
=======

GPL3

=end

# git repostitory: https://github.com/anekos/weechat-url-buffer-with-title

require 'nokogiri'
require 'open-uri'
require 'thread'
require 'json'

PLUGIN_NAME = 'url-buffer-with-title'

DEBUG = true

Config = {
  'accept_url' => [nil, 'Regexp'],
  'ignore_url' => [nil, 'Regexp'],
  'format' => ["[<buffer_number>] <title>\n<url>", 'String'],
}

def weechat_init
  Weechat.register(
    PLUGIN_NAME,
    'anekos',
    '1.0.2',
    'GPL3',
    'URL collector',
    '',
    'utf-8'
  )

  Config.each do
    |name, (default, desc)|
    Weechat.config_set_desc_plugin(name, desc)
  end

  Weechat.hook_print('', 'notify_message', '', 1, 'urlbuf_print_cb', '')
  Weechat.hook_signal(signal('fetched'), 'fetched_cb', '')

  return Weechat::WEECHAT_RC_OK
end

def signal (name)
  PLUGIN_NAME + '.' + name
end

def get_config_regexp (name)
  s = get_config_string(name, nil)
  return Regexp.new(s) if s
end

def get_config_string (name, default = Config[name].first)
  return default if Weechat.config_is_set_plugin(name) == 0
  result = Weechat.config_get_plugin(name)
  return default if result.empty?
  result
end

def get_url_buffer
  result = Weechat.buffer_search('ruby', 'urlbuf')

  if !result or result.empty?
    result = Weechat.buffer_new('urlbuf', 'urlbuf_input_cb', '', 'urlbuf_close_cb', '')
    Weechat.buffer_set(result, 'title', 'URL buffer')
    Weechat.buffer_set(result, 'notify', '0')
    Weechat.buffer_set(result, 'nicklist', '0')
  end

  return result
end

def urlbuf_print_cb (data, buffer, date, tags, displayed, highlight, prefix, message)
  tags = tags.split(',')

  return Weechat::WEECHAT_RC_OK unless tags.include?('notify_message')
  return Weechat::WEECHAT_RC_OK if tags.include?('irc_notice')
  return Weechat::WEECHAT_RC_OK unless buffer
  return Weechat::WEECHAT_RC_OK if get_url_buffer == buffer

  bnum = Weechat.buffer_get_integer(buffer, 'number')

  message.scan(%r<https?\://[-\w+$;?.%,!#~*/:@&\\=_]+>).each do
    |url|

    if accept_url = get_config_regexp('accept_url')
      next unless accept_url === url
    end

    if ignore_url = get_config_regexp('ignore_url')
      next if ignore_url === url
    end

    Weechat.print("", "\tfetching for #{url}") if DEBUG

    Thread.start do
      begin
        Weechat.print("", "\topening #{url}") if DEBUG
        res = open(url)
        Weechat.print("", "\tparsing #{url}") if DEBUG
        html = Nokogiri.HTML(res)
        title = html.search('//title').text
        title = 'No Title' if title.empty?
        title = title.gsub(/[\t\r\n]+/, ' ').strip
        Weechat.hook_signal_send(
          signal('fetched'),
          Weechat::WEECHAT_HOOK_SIGNAL_STRING,
          {:url => url, :title => title, :buffer_number => bnum}.to_json
        )
        Weechat.print("", "\tdone: #{url}") if DEBUG
      rescue => e
        Weechat.print("", "\t#{url} #{e}") if DEBUG
      end
    end
  end

  return Weechat::WEECHAT_RC_OK
end

def urlbuf_input_cb(data, buffer, input_data)
  return Weechat::WEECHAT_RC_OK
end

def urlbuf_close_cb(data, buffer)
  return Weechat::WEECHAT_RC_OK
end

def fetched_cb (data, signal, signal_data)
  data = JSON.parse(signal_data)

  url_buffer = get_url_buffer

  out = get_config_string('format').gsub(/<([^>]+)>/) {|m| data[m[1...-1]] rescue m }
  Weechat.print(url_buffer, out)

  return Weechat::WEECHAT_RC_OK
end
