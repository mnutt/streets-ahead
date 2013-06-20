#!/usr/bin/env ruby

require 'mechanize'
require 'yaml'

unless ARGV[0] =~ /^http/ && ARGV[1] =~ /(now|[\d\/]+)/
  puts "Usage: scraper.rb [streeteasy search URL] [date(s)]"
  puts "   streeteasy search url: just perform a search on streeteasy.com"
  puts "   and grab the URL from the location bar"
  puts ""
  puts "   date(s): can either be now, unknown, or dates in the"
  puts "   format mm/dd/yyyy, and can be multiple separated a comma"
  puts ""
  exit 1
end

@listing_url = ARGV[0] # || "http://streeteasy.com/nyc/rentals/downtown-manhattan/rental_type:frbo,brokernofee,brokerfee%7Cprice:2500-3500%7Cbeds:1?page=1&sort_by=price_desc"
@available_date = ARGV[1].split(",") # || "08/01/2013,07/31/2013"
@available_date.shift if @available_date == ['']

agent = Mechanize.new

def full_url(path)
  if path =~ /^\//
    "http://streeteasy.com#{path}"
  else
    path
  end
end

def page_url(page_number)
  if @listing_url =~ /page=/
    @listing_url.gsub(/page=\d+/, "page=#{page_number.to_s}")
  else
    @listing_url + "&page=#{page_number.to_s}"
  end
end

html = ""

first_page = agent.get page_url(1)

page_count = first_page.search("div.pager_top").text.scan(/of (\d+)/).first.first.to_i
(1..page_count).each { |page|
  sleep 0.5
  #puts "getting page #{page}"
  page = agent.get page_url(page)

  urls = page.search("div.unsponsored div.item_inner div.photo a").map{|e| e.attribute("href").to_s }.flatten.uniq

  urls.each {|url|
    sleep 0.5
    page = agent.get url

    availability = page.search("div.price div.small").first.to_s.scan(/available( on)?\s+([now\/0-9]+)/m).flatten[1] || "unknown"

    if @available_date.nil? or @available_date.any? {|a| a == availability }
      images = page.search("a.shadowbox_badge").map{|e| e.attribute("href").to_s }.flatten
      title = page.search("h1")
      html += "<h1>#{title.to_html}</h1>"

      images.each do |image|
        html += "<a href='#{full_url(url)}'><img src='#{image}'/></a>"
      end
      puts full_url(url)
      html += "<br><hr><br>"
    elsif availability
      # puts "available #{availability.first}"
    end
    #puts "#{availability.first.first} #{url}"
  }
}

File.open("/tmp/listings.html", "w") do |f|
  f.write("<html><body>")
  f.write(html)
  f.write("</body></html>")
end

`open /tmp/listings.html`
