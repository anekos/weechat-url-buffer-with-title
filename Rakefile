

require 'cgi'

task :default do
  File.open('url-buffer-with-title.rb') do
    |file|
    :do_noghing until /\A=begin DOC\Z/ === file.gets.chomp
    File.open('README.md', 'w') do
      |readme|
      readme.puts(CGI.escapeHTML($_)) until /\A=end\Z/ === file.gets.chomp
    end
  end
end
