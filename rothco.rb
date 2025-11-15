require 'mechanize'
require 'json'
require 'net/http'
require 'cgi'

class Rothco
  URL = 'https://www.rothco.com/search/keyword/caps'

  def initialize
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Windows Chrome'
    @agent.robots = false
  rescue StandardError => e
    puts "Initialization failed: #{e.message}"
    raise
  end

  def extract_all_products(page = 1)
    uri = URI("https://xxkp6b.a.searchspring.io/api/search/search.json?siteId=xxkp6b&resultsFormat=json&resultsPerPage=300&page=#{page}&q=caps&filter.b2b_product=false")
    req = Net::HTTP::Get.new(uri)
    req['accept'] = '*/*'
    req['accept-language'] = 'en-US,en;q=0.9'
    req['origin'] = 'https://www.rothco.com'
    req['priority'] = 'u=1, i'
    req['referer'] = 'https://www.rothco.com/'
    req['sec-ch-ua'] = '"Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"'
    req['sec-ch-ua-mobile'] = '?0'
    req['sec-ch-ua-platform'] = '"Linux"'
    req['sec-fetch-dest'] = 'empty'
    req['sec-fetch-mode'] = 'cors'
    req['sec-fetch-site'] = 'cross-site'
    req['user-agent'] = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

    req_options = {
    use_ssl: uri.scheme == 'https'
    }
    res = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
      http.request(req)
    end
    res
  end

  def scrape
    page = 1
    loop do
      puts "Fetching page #{page}..."
      response = extract_all_products(page)
      
      if response.code == '200'
        parsed_json = JSON.parse(response.body)
        results = parsed_json["results"]
        
        break if results.empty?
        
        results.each do |product|
          variants_raw = product["variants"]
          
          if variants_raw.nil? || variants_raw.empty?
            puts "Skipping product: No variants found"
            next
          end
          
          decoded = CGI.unescapeHTML(variants_raw)
          decoded = "[#{decoded}]" unless decoded.strip.start_with?('[')
          variants = JSON.parse(decoded)
          
          variants.each do |variant|
            name = variant["color"]
            sku = variant["sku_child"]
            image_url = variant["thumbnail_url"]&.gsub("/large","")
            download_image(image_url, sku) if image_url && sku
          end
        end
        
        total_results = parsed_json["pagination"]["totalResults"]
        results_per_page = 300
        total_pages = (total_results.to_f / results_per_page).ceil
        
        puts "Processed page #{page} of #{total_pages}"
        break if page >= total_pages
        
        page += 1
      else
        puts "Failed to fetch page #{page}: HTTP #{response.code}"
        break
      end
    end
    puts "Scraping completed!"
  rescue StandardError => e
    puts "Unexpected error: #{e.message}"
    raise
  end

  private

  def download_image(image_url, sku)
    return unless image_url && sku

    begin
      # Create rothco folder inside images directory
      Dir.mkdir('images') unless Dir.exist?('images')
      Dir.mkdir('images/rothco') unless Dir.exist?('images/rothco')
      
      filename = "images/rothco/#{sku.downcase}.jpg"
      
      # Skip if image already exists
      if File.exist?(filename)
        puts "Skipping SKU #{sku}: Image already exists"
        return
      end
      
      image_data = @agent.get(image_url).body
      File.open(filename, 'wb') do |file|
        file.write(image_data)
      end
      puts "Downloaded image for SKU #{sku}"
    rescue StandardError => e
      puts "Failed to download image for SKU #{sku}: #{e.message}"
    end
  end
end

# Usage
if __FILE__ == $0
  # begin
  scraper = Rothco.new
  scraper.scrape
  # rescue StandardError => e
  #   puts "Script failed: #{e.message}"
  #   exit 1
  # end
end
