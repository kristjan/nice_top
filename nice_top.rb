#!/usr/bin/env ruby

require "rubygems"
require "httparty"

require "optparse"
require "ostruct"
require "tempfile"

@options = OpenStruct.new
options_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} -s SOURCE [options]"

  opts.separator ""

  opts.on("-s SOURCE", "--source SOURCE", [:tumblr],
          "Select source (tumblr)") do |source|
    @options.source = source
  end

  opts.on("-b BLOG", "--blog BLOG",
          "Tumblr blog URL when using --source tumblr") do |blog|
    @options.blog = blog
  end

  opts.on_tail("-h", "--help",
          "Print usage and options") do
    p opts
    exit
  end

  opts.parse!
end

p @options

raise OptionParser::MissingArgument.new("--source") unless @options.source

SET_DESKTOP = <<-SCRIPT
  on run argv
    tell application "Finder"
      set desktop picture to POSIX file (item 1 of argv)
    end tell
  end run
SCRIPT

def set_desktop(image_path)
  args = SET_DESKTOP.split("\n").map{|l| "-e '#{l}'"}.join(' ')
  `osascript #{args} #{image_path}`
end

def set_desktop_from_url(url)
  file = Tempfile.new('nice_top')
  `curl -s #{url} > #{file.path}`
  set_desktop(file.path)
end

TUMBLR_API_BASE = "https://api.tumblr.com/v2"

def get_from_tumblr(blog)
  blog += '.tumblr.com' unless blog.include?('.')
  posts = TUMBLR_API_BASE + "/blog/#{blog}/posts"
  photos = HTTParty.get(posts, {
    :query => {
      :api_key => ENV["TUMBLR_API_KEY"],
      :limit => 1
    }
  })["response"]["posts"].first["photos"]

  photo_url = photos.first["original_size"]["url"]
  set_desktop_from_url(photo_url)
end

def get_from(source)
  case source
  when :tumblr
    raise OptionParser::MissingArgument.new("--blog") unless @options.blog
    get_from_tumblr(@options.blog)
  else
    puts "Unknown source: #{source}"
    exit
  end
end

get_from(@options.source)
