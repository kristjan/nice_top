#!/usr/bin/env ruby

require "rubygems"
require "httparty"
require "nokogiri"

require "optparse"
require "ostruct"
require "tempfile"

@options = OpenStruct.new
options_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} -s SOURCE [options]"

  opts.separator ""

  opts.on("-s SOURCE", "--source SOURCE", [:tumblr, :wallbase],
          "Select source (tumblr, wallbase)") do |source|
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

TUMBLR_API_ROOT = "https://api.tumblr.com/v2"

def get_from_tumblr(blog)
  blog += '.tumblr.com' unless blog.include?('.')
  posts = TUMBLR_API_ROOT + "/blog/#{blog}/posts"
  photos = HTTParty.get(posts, {
    :query => {
      :api_key => ENV["TUMBLR_API_KEY"],
      :limit => 1
    }
  })["response"]["posts"].first["photos"]

  photo_url = photos.first["original_size"]["url"]
  set_desktop_from_url(photo_url)
end

WALLBASE_ROOT = "http://wallbase.cc/search"

def get_random_from_wallbase
  results = HTTParty.post(WALLBASE_ROOT, {
    :body => {
      :orderby => :random,
      :res_opt => :gteq,
      :res => '2560x1600',
      :aspect => 1.6,
      :thpp => 20
    }
  })
  doc = Nokogiri::HTML(results.body)
  doc.css('.thumb a.thlink').first.attributes["href"]
end

WALLBASE_MIXER =
  "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/="
def decode_wallbase(encoded)
  result = []

  encoded.chars.each_slice(4) do |group|
    f, g, h, i = group.map{|char| WALLBASE_MIXER.index(char)}

    j = f << 18 | g << 12 | h << 6 | i
    c = j >> 16 & 255
    d = j >> 8 & 255
    e = j & 255

    if h == 64
      result.push c
    elsif i == 64
      result.push c, d
    else
      result.push c, d, e
    end
  end

  result.map(&:chr).join
end

def get_image_from_wallbase_detail(detail_url)
  detail = HTTParty.get(detail_url)
  doc = Nokogiri::HTML(detail)
  script = doc.css('#bigwall').to_s
  encoded = script.match(/B\('([^']+)'\)/)[1]
  decode_wallbase(encoded)
end

def get_from_wallbase
  detail_url = get_random_from_wallbase
  image_url = get_image_from_wallbase_detail(detail_url)
  set_desktop_from_url(image_url)
end

def get_from(source)
  case source
  when :tumblr
    raise OptionParser::MissingArgument.new("--blog") unless @options.blog
    get_from_tumblr(@options.blog)
  when :wallbase
    get_from_wallbase
  else
    puts "Unknown source: #{source}"
    exit
  end
end

get_from(@options.source)
