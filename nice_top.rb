#!/usr/bin/env ruby

require "rubygems"
require "httparty"

TUMBLR_API_BASE = "https://api.tumblr.com/v2"
BLOG_NAME = "fuckyeahprettyplaces.tumblr.com"
POSTS_PATH = "/blog/#{BLOG_NAME}/posts"

photos = HTTParty.get(TUMBLR_API_BASE + POSTS_PATH, {
  :query => {
    :api_key => ENV["TUMBLR_API_KEY"],
    :limit => 1
  }
})["response"]["posts"].first["photos"]

photo_url = photos.first["original_size"]["url"]
name = photo_url.split('/').last
path = "/tmp/#{name}"

SET_DESKTOP = <<-SCRIPT
  on run argv
    tell application "Finder"
      set desktop picture to POSIX file (item 1 of argv)
    end tell
  end run
SCRIPT

if !File.exists?(path)
  `curl -s #{photo_url} > #{path}`
  args = SET_DESKTOP.split("\n").map{|l| "-e '#{l}'"}.join(' ')
  `osascript #{args} #{path}`
end

