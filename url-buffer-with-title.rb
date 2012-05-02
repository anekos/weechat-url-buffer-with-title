#!/usr/bin/ruby
# vim: set fileencoding=utf-8 :


=begin DOC

URL-Buffer-With-Title
=====================

Make URL (with title) collection buffer.


Options
=======

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

require 'nokogiri'
require 'open-uri'
require 'thread'

Config = {
  'accept_url' => [nil, 'Regexp'],
  'ignore_url' => [nil, 'Regexp'],
  'format' => ["[<buffer_number>] <title>\n<url>", 'String'],
}

def weechat_init
  Weechat.register(
    'url-buffer-with-title',
    'anekos',
    '1.0.0',
    'GPL3',
    'URL collector',
    '',
    'utf-8'
  )

  Config.each do
    |name, (default, desc)|
    if Weechat.config_is_set_plugin(name) == 0
      default = '' unless default
      Weechat.config_set_plugin(name, default)
    end
    Weechat.config_set_desc_plugin(name, desc)
  end

  Weechat.hook_print('', 'notify_message', '', 1, 'urlbuf_print_cb', '')
  Weechat.hook_timer(1000, 0, 0, 'urlbuf_timer_cb', '')

  $queue = Queue.new

  return Weechat::WEECHAT_RC_OK
end

def get_config_regexp (name)
  return nil if Weechat.config_is_set_plugin(name) == 0
  result = Weechat.config_get_plugin(name)
  return nil if result.empty?
  Regexp.new(result)
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

    Thread.start do
      begin
        res = open(url)
        html = Nokogiri.HTML(res)
        title = html.search('//title').text
        title = 'No Title' if title.empty?
        title = title.gsub(/[\r\n]+/, ' ').strip
        $queue << Struct.new(:url, :title, :buffer_number).new(url, title, bnum)
      rescue => e
        puts("#{url} #{e}")
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

def urlbuf_timer_cb (data, remaining_calls)
  return Weechat::WEECHAT_RC_OK unless $queue

  url_buffer = get_url_buffer

  while it = ($queue.pop rescue nil)
    out = get_config_string('format').gsub(/<([^>]+)>/) {|m| it[m[1...-1]] rescue m }
    Weechat.print(url_buffer, out)
  end

  return Weechat::WEECHAT_RC_OK
end
