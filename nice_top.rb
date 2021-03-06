#!/usr/bin/env ruby

require "rubygems"
require "httparty"
require "nokogiri"

require "optparse"
require "ostruct"
require "tempfile"

@options = OpenStruct.new(
  :wallbase_sketch_level => "100"
)
options_parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} -s SOURCE [options]"

  opts.on("-s SOURCE", "--source SOURCE", [:tumblr, :wallbase],
          "Select source (tumblr, wallbase)") do |source|
    @options.source = source
  end

  opts.on("-h", "--help",
          "Print usage and options") do
    p opts
    exit
  end

  opts.separator ""
  opts.separator "Tumblr options:"

  opts.on("-b BLOG", "--blog BLOG",
          "Tumblr blog URL") do |blog|
    @options.blog = blog
  end

  opts.separator ""
  opts.separator "Wallbase options:"


  opts.on("-q QUERY", "--query QUERY",
          "Specify search query") do |query|
    @options.query = query
  end

  opts.on("--allow-nsfw", "Allow NSFW images") do
    @options.wallbase_sketch_level = "110"
  end

  opts.on("--nsfw", "Get only NSFW images") do
    @options.wallbase_sketch_level = "010"
  end

  opts.parse!
end

unless @options.source
  p options_parser
  exit
end

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

WALLBASE_SEARCH = "http://wallbase.cc/search"

def get_random_from_wallbase(options)
  results = HTTParty.get(WALLBASE_SEARCH, {
    :query => {
      :q          => options.query,
      :section    => :wallpapers,
      :order      => :random,
      :res_opt    => :gteq,
      :res        => '1680x1050',
      :aspect     => 1.6,
      :purity     => options.wallbase_sketch_level,
    }
  })
  doc = Nokogiri::HTML(results.body)
  thumbnail = doc.css('.thumbnail img.file').first
  thumbnail.attributes["data-original"].value if thumbnail
end

WALLBASE_IMAGE_BASE   = 'http://wallpapers.wallbase.cc/rozne/wallpaper'
WALLBASE_THUMBNAIL_RE = %r[thumbs\.wallbase\.cc/+rozne/thumb-(\d+)\.jpg]

def get_from_wallbase(options)
  thumbnail_url = get_random_from_wallbase(options)
  image_id = thumbnail_url.match(WALLBASE_THUMBNAIL_RE)[1]
  image_url = "#{WALLBASE_IMAGE_BASE}-#{image_id}.jpg"
  set_desktop_from_url(image_url)
end

def get_from(source)
  case source
  when :tumblr
    raise OptionParser::MissingArgument.new("--blog") unless @options.blog
    get_from_tumblr(@options.blog)
  when :wallbase
    get_from_wallbase(@options)
  else
    puts "Unknown source: #{source}"
    exit
  end
end

get_from(@options.source)
