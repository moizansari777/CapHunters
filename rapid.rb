require 'mechanize'
require 'json'
require 'net/http'
require 'cgi'
require 'selenium-webdriver'

class Rapid
  URL = 'https://www.rapiddominance.com/search-result?searchWord=cap&searchDesc=cap&searchType=undefined'

  def initialize
    options = Selenium::WebDriver::Chrome::Options.new

    options.add_argument("--headless=new")  
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_argument("--window-size=1920,1080")

    @driver = Selenium::WebDriver.for(:chrome, options: options)

    @agent = Mechanize.new
    @agent.user_agent_alias = 'Windows Chrome'
    @agent.robots = false

  end



  def scrape
    @driver.get(URL)
    sleep 5
    card = @driver.find_elements(:css, ".card")[0]
    product_card_height = card.size[:height]
    scroll_down_slowly(product_card_height)

    @driver.find_elements(:css, ".card").each_with_index do |element, index|
      sku  = element.find_element(:css, "span.text-muted").text
      if Dir.glob("images/rapid/*").any? { |file| file.include?(sku.downcase) }
        puts "Skipping SKU #{sku}: Image already exists"
      else  
        button = element.find_element(:css, ".card-action button")
        button.click
        sleep 3
        parse_page
      end
      if (index+1)%8 == 0
        scroll_down_slowly(product_card_height*2)
      end
    end
    cleanup_driver
    puts "Scraping completed!"
  rescue Interrupt
    puts "\nScript interrupted by user. Cleaning up..."
    cleanup_driver
    exit 0
  rescue StandardError => e
    puts "Unexpected error: #{e.message}"
    puts e.backtrace.join("\n")
    cleanup_driver
    raise
  end

  private

  def scroll_down_slowly(product_card_height)
    # scroll down by the height of product card (relative scroll)
    @driver.execute_script("window.scrollBy(0, arguments[0]);", product_card_height)
    sleep 2
  end
  

  def parse_page
    begin
      # Find all slider elements
      sleep 2
      sliders = @driver.find_elements(:css, "div.slider-wrapper ul.slider")

      # Check if we have at least 2 sliders (index 1 exists)
      if sliders.length < 2
        puts "Warning: Expected at least 2 sliders, found #{sliders.length}. Skipping this item."
        close_modal
        return
      end
      
      # Get images from the second slider
      slider_items = sliders[-1].find_elements(:css, "li")[0..2]
      
      if slider_items.empty?
        puts "Warning: No images found in slider. Skipping this item."
        close_modal
        return
      end
      sku = @driver.find_element(:css, ".modal-content a.font-size-lg").text.strip
      slider_items.each_with_index do |li, index|
        src = li.find_element(:css, "img").attribute("src")
        download_image(src, sku, index+1)
      end

      close_modal
    rescue StandardError => e
      puts "Error parsing page: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      close_modal
    end
  end
  
  def close_modal
    begin
      wait = Selenium::WebDriver::Wait.new(timeout: 10)
      close_btn = wait.until {
        @driver.find_element(:css, "button.close")
      }
      close_btn.click
      sleep 3
    rescue StandardError => e
      puts "Warning: Could not close modal: #{e.message}"
    end
  end

  def download_image(image_url, sku, image_number)
    return unless image_url && sku
    
    begin
      Dir.mkdir('images') unless Dir.exist?('images')
      Dir.mkdir('images/rapid') unless Dir.exist?('images/rapid')
      filename = "images/rapid/#{sku.downcase}-#{image_number}.jpg"
      
      if File.exist?(filename)
        puts "Skipping SKU #{sku}-#{image_number}: Image already exists"
        return
      end
      
      puts "Downloading image #{image_url}..."
      image_data = @agent.get(image_url).body
      File.open(filename, 'wb') do |file|
        file.write(image_data)
      end
      puts "Downloaded image for SKU #{sku}-#{image_number}"
    rescue Interrupt
      puts "\nDownload interrupted by user"
      raise
    rescue StandardError => e
      puts "Failed to download image for SKU #{sku}: #{e.message}"
    end
  end

  def cleanup_driver
    if @driver
      @driver.quit
      puts "Browser driver closed"
    end
  rescue StandardError => e
    puts "Error closing driver: #{e.message}"
  end
end

# Usage
if __FILE__ == $0
  begin
    scraper = Rapid.new
    scraper.scrape
  rescue Interrupt
    puts "\nScript terminated by user"
    exit 0
  rescue StandardError => e
    puts "Script failed: #{e.message}"
    exit 1
  end
end
