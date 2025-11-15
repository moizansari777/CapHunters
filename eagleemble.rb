require 'mechanize'
require 'logger'
require 'json'

class EagleEmblemsScraper
  URL = 'https://eagleemblemsinc.com/caps-hats.html?product_list_limit=all'

  def initialize
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Windows Chrome'
    @agent.robots = false
    setup_logger
  rescue => e
    @logger.error("Initialization failed: #{e.message}")
    raise
  end

  def scrape
    @logger.info("Starting scrape of #{URL}")
    page = @agent.get(URL)
    extract_products(page)
    @logger.info("Scraping completed. Found #{products.length} products")
  rescue Mechanize::ResponseCodeError => e
    @logger.error("HTTP error: #{e.message}")
    raise
  rescue => e
    @logger.error("Unexpected error: #{e.message}")
    raise
  end

  private

  def setup_logger
    @logger = Logger.new('eagle_emblems.log')
    @logger.level = Logger::INFO
  end

  def extract_products(page)
    products = []
    page.css('.product-item-info').each do |item|
      main_page = @agent.get(item.css('.product-item-link').first&.attr('href'))

      products << {
        name: main_page.css('h1.page-title').text.strip,
        sku: main_page.css('div.sku .value').text.split("(").first.strip
      }

    script_data = main_page.search('script[type="text/x-magento-init"]')[5]

    if script_data
      json_text = script_data.text.strip
      data = JSON.parse(json_text)

      gallery_data = data.dig("[data-gallery-role=gallery-placeholder]", "mage/gallery/gallery", "data")

      if gallery_data && gallery_data.any?

        full_image_url = gallery_data.first['full']
        puts "Downloading image from #{full_image_url} for SKU #{products.last[:sku]}"
        download_image(full_image_url, products.last[:sku])
      else
        puts "No gallery images found."
      end
    else
      puts "Magento script tag not found."
    end
    rescue => e
      @logger.warn("Failed to parse product: #{e.message}")
      next
    end
    products
  end

end

def download_image(image_url, sku)
  return unless image_url && sku

  begin
    # Create eagleemblems folder inside images directory
    Dir.mkdir("images") unless Dir.exist?("images")
    Dir.mkdir("images/eagleemblems") unless Dir.exist?("images/eagleemblems")
    
    filename = "images/eagleemblems/#{sku.downcase}.jpg"
    
    # Skip if image already exists
    if File.exist?(filename)
      puts "Skipping SKU #{sku}: Image already exists"
      return
    end
    
    image_data = Mechanize.new.get(image_url).body
    File.open(filename, 'wb') do |file|
      file.write(image_data)
    end
    puts "Downloaded image for SKU #{sku}"
  rescue => e
    puts "Failed to download image for SKU #{sku}: #{e.message}"
  end
end

# Usage
if __FILE__ == $0
  begin
    scraper = EagleEmblemsScraper.new
    products = scraper.scrape
    puts "Successfully scraped #{products.length} products"
  rescue => e
    puts "Script failed: #{e.message}"
    exit 1
  end
end
