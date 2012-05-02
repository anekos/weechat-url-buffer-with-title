# vim: set fileencoding=utf-8 :

require 'nokogiri'
require 'open-uri'
require 'thread'

def weechat_init
  Weechat.register(
    'url-and-title-buffer',
    'anekos',
    '1.0.0',
    'GPL3',
    'URL collector',
    '',
    'utf-8'
  )

  Weechat.hook_print('', 'notify_message', '', 1, 'urlbuf_print_cb', '')
  Weechat.hook_timer(1000, 0, 0, 'urlbuf_timer_cb', '')

  $queue = Queue.new

  return Weechat::WEECHAT_RC_OK
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
    Weechat.print(
      url_buffer,
      "[#{it.buffer_number}] #{it.title}\n#{it.url}"
    )
  end

  return Weechat::WEECHAT_RC_OK
end
