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
  elsif @listing_url =~ /\?/
    @listing_url + "&page=#{page_number.to_s}"
  else
    @listing_url + "?page=#{page_number.to_s}"
  end
end

`open /tmp/listings.html`

first_page = agent.get page_url(1)

File.open("/tmp/listings.html", "w") do |f|
  f.write("<html><body>")


  page_count = first_page.search(".pagination a").map{|z| z.text.to_i }.max
  puts "#{page_count} pages available"
  (1..page_count).each { |page|
    sleep 0.5
    puts "getting #{page_url(page)}"
    page = agent.get page_url(page)

    urls = page.search("div.listings div.item").reject{|e| e.search("div.featured_tag").size > 0}.map{|e| e.search("div.photo a").attribute("href").to_s }.flatten.uniq.reject{|a| a =~ /featured=/ }

    urls.each {|url|
      sleep 0.5
      puts "getting url #{url}"
      page = agent.get url

      html = ''

      availability = page.search("div.vitals div.details_info").first.to_s.scan(/Available( on)?\s+([now\/0-9]+)/im).flatten.last || "unknown"

      if availability != 'unknown'
        page.search("div.vitals div.details_info h6").first.remove
        availability = page.search("div.vitals div.details_info").first.text.strip
      end

      if @available_date.nil? or @available_date.any? {|a| a == availability }
        images = page.search("#image-gallery li.photo img").map{|e| e.attribute("src").to_s }.flatten
        title = page.search("h1.building-title")
        price = page.search("div.price")
        html += "<h1>#{title.text} - #{price.text}</h1>"

        images.each do |image|
          html += "<a target='_blank' href='#{full_url(url)}'><img src='#{image}'/></a>"
        end
        #puts full_url(url)
        html += "<br><hr><br>"
      elsif availability
        # puts "available #{availability.first}"
      end
      #puts "#{availability.first.first} #{url}"

      f.write(html)
      f.flush
    }
  }

  f.write("</body></html>")
end
