require 'mechanize'
require 'json'
require 'net/http'
require 'cgi'
require 'selenium-webdriver'

class Rothco
  URL = 'https://www.rothco.com/search/keyword/caps'

  def initialize
    options = Selenium::WebDriver::Chrome::Options.new
    # options.add_argument('--headless=new')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-gpu')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--disable-blink-features=AutomationControlled')
    options.add_argument('--window-size=1920,1080')

    @driver = Selenium::WebDriver.for(:chrome, options: options)

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
    req['referer'] = 'https://www.rothco.com/'
    req['user-agent'] =
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'

    max_retries = 5
    retries = 0

    begin
      Net::HTTP.start(
        uri.hostname,
        uri.port,
        use_ssl: true,
        open_timeout: 20,
        read_timeout: 40
      ) do |http|
        http.request(req)
      end
    rescue Net::ReadTimeout, Net::OpenTimeout => e
      retries += 1
      if retries <= max_retries
        puts "Timeout on page #{page}, retry #{retries}/#{max_retries}..."
        sleep 2
        retry
      else
        puts "Failed after #{max_retries} retries: #{e.message}"
        raise
      end
    end
  end

  def scrape
    page = 1
    loop do
      puts "Fetching page #{page}..."
      response = extract_all_products(page)

      if response.code == '200'
        parsed_json = JSON.parse(response.body)
        results = parsed_json['results']

        break if results.empty?

        results.each do |product|
          variants_raw = product['variants']

          if variants_raw.nil? || variants_raw.empty?
            sku = product['sku'].gsub('P', '')
            sub_url = product['url']
            url = "https://www.rothco.com/product/#{sub_url}?item=#{sku}"
            sleep 1
            @driver.get(url)
            sleep 1
            product_code = sku.split("-").first
            puts "Product Code #{product_code}"
            puts "Processing SKU #{sku} at URL #{url}"
            @driver.find_elements(css: '.pdp-image-gallery div.zoom-image-container img.iiz__img').each_with_index do |option, index|

              image_url = option.attribute('src')
              unless image_url.include?(product_code)
                  puts "Skipping non-matching image: #{image_url}"
                  next
                end
              puts "Main Image URL: #{image_url}"
              download_image(image_url, sku, index + 1) if image_url && sku
            end
            next
          end

          decoded = CGI.unescapeHTML(variants_raw)
          decoded = "[#{decoded}]" unless decoded.strip.start_with?('[')
          variants = JSON.parse(decoded)

          variants.each do |variant|
            variant['color']
            sku = variant['sku_child']
            sub_url = product['url']
            url = "https://www.rothco.com/product/#{sub_url}?item=#{sku}"
            sleep 1
            @driver.get(url)
            sleep 1
            puts "Processing SKU #{sku} at URL #{url}"
            @driver.find_elements(css: '.pdp-image-gallery div.zoom-image-container img.iiz__img').each_with_index do |option, index|
              image_url = option.attribute('src')
              product_code = sku.split("-").first
              unless image_url.include?(product_code)
                puts "Skipping non-matching image: #{image_url}"
                next
              end

              puts "Main Image URL: #{image_url}"
              download_image(image_url, sku, index + 1) if image_url && sku
            end
          end
        end

        total_results = parsed_json['pagination']['totalResults']
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
    # @driver.quit
    puts 'Scraping completed!'
  rescue StandardError => e
    puts "Unexpected error: #{e.message}"
    raise
  end

  private

  def download_image(image_url, sku, image_number)
    return unless image_url && sku

    begin
      # Create rothco folder inside images directory
      Dir.mkdir('images') unless Dir.exist?('images')
      Dir.mkdir('images/rothco') unless Dir.exist?('images/rothco')

      filename = "images/rothco/#{sku.downcase}-#{image_number}.jpg"

      # Skip if image already exists
      if File.exist?(filename)
        puts "Skipping SKU #{sku}: Image already exists"
        return 200
      end

      image_data = @agent.get(image_url).body
      File.open(filename, 'wb') do |file|
        file.write(image_data)
      end
      puts "Downloaded image for SKU #{sku}"
      200
    rescue StandardError => e
      puts "Failed to download image for SKU #{sku}: #{e.message}"
      404
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
