#!/usr/bin/env ruby

require "rubygems"
require "httparty"

require "optparse"
require "ostruct"

options = OpenStruct.new
options_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} -s SOURCE [options]"

  opts.separator ""

  opts.on("-s SOURCE", "--source SOURCE", [:tumblr],
          "Select source (tumblr)") do |source|
    options.source = source
  end

  opts.on_tail("-h", "--help",
          "Print usage and options") do
    p opts
    exit
  end

  opts.parse!
end

p options

raise OptionParser::MissingArgument.new("--source") unless options.source

TUMBLR_API_BASE = "https://api.tumblr.com/v2"
BLOG_NAME = "fuckyeahprettyplaces.tumblr.com"
POSTS_PATH = "/blog/#{BLOG_NAME}/posts"

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

def get_from_tumblr(blogname)
  photos = HTTParty.get(TUMBLR_API_BASE + POSTS_PATH, {
    :query => {
      :api_key => ENV["TUMBLR_API_KEY"],
      :limit => 1
    }
  })["response"]["posts"].first["photos"]

  photo_url = photos.first["original_size"]["url"]
  name = photo_url.split('/').last
  path = "/tmp/#{name}"

  if !File.exists?(path)
    `curl -s #{photo_url} > #{path}`
    set_desktop(path)
  end
end

get_from_tumblr(BLOG_NAME)
