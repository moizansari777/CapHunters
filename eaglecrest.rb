require 'mechanize'
require 'json'
require 'selenium-webdriver'

class Eaglecrest
  URL = 'https://www.eaglecrest.com/headwear'

  def initialize
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Windows Chrome'
    @agent.robots = false
  rescue StandardError => e
    puts "Initialization failed: #{e.message}"
    raise
  end

  def chrome_driver
    options = Selenium::WebDriver::Chrome::Options.new

    options.add_argument("--headless=new")  
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-gpu")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-blink-features=AutomationControlled")
    options.add_argument("--window-size=1920,1080")

    @driver = Selenium::WebDriver.for(:chrome, options: options)
  end
    

  def scrape
    chrome_driver
    puts "Scraping categories from #{URL}"
    page = @agent.get(URL)
   	extract_category_links(page)
    @driver.quit
  rescue Mechanize::ResponseCodeError => e
    puts "HTTP error: #{e.message}"
    raise
  rescue StandardError => e
    puts "Unexpected error: #{e.message}"
    raise
  end

  private

  def extract_category_links(page)
    category_links = []
    page.css('a.category-link').each do |link|
      products_page = @agent.get(link.attr('href'))
      extract_products(products_page)
    end
  end

  def extract_products(page)
    products = []
    page = @driver.get(page.uri)
    sleep 2
    scroll_down_slowly(@driver)
    product_elements = @driver.find_elements(css: "li.product-title a")
    product_links = product_elements.map { |el| el.attribute("href") }
    product_links.each do |item|
      product_page = @agent.get(item)
      name = product_page.css('h1.product-title').text.strip
      sku = product_page.css('.product-details-code span').text.strip
      puts "Scraping product: #{name} (SKU: #{sku})"

      image_urls = product_page.css('.slides li a').map do |img|
        "https://www.eaglecrest.com" + img.attr('data-enlarge-image')
      end

      image_urls.each_with_index do |image_url, index|
        download_image(image_url, sku, index + 1)
      end
      if image_urls.empty?
        main_image_url = product_page.css('#product-detail-gallery-main-img').attr('src')
        download_image(main_image_url, sku)
      end
      products << { name: name, sku: sku, images: image_urls }
    end
    products
  end
end

def scroll_down_slowly(driver, step_fraction: 0.15, pause: 5, max_loops: 20)
  get_height = -> {
    driver.execute_script(
      "return Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);"
    ).to_f
  }

  puts "Scrolling down to bottom of page..."

  previous_total = get_height.call
  current_y = 0.0
  step = previous_total * step_fraction

  loops = 0
  while loops < max_loops
    step = [previous_total * step_fraction, 1.0].max
    target = [current_y + step, previous_total].min
    driver.execute_script("window.scrollTo(0, arguments[0]);", target)
    sleep pause

    total_after = get_height.call
    puts "Total after scroll: #{total_after}"
    if total_after > previous_total
      previous_total = total_after
    end

    current_y = target
    loops += 1

    break if (previous_total - current_y) <= 5.0
  end

  driver.execute_script("window.scrollTo(0, document.body.scrollHeight);")
end


def download_image(image_url, sku, index = "")
  return unless image_url && sku

  begin
    # Create eaglecrest folder inside images directory
    Dir.mkdir('images') unless Dir.exist?('images')
    Dir.mkdir('images/eaglecrest') unless Dir.exist?('images/eaglecrest')
    
    filename = "images/eaglecrest/#{sku.downcase}-#{index}.jpg"
    
    # Skip if image already exists
    if File.exist?(filename)
      puts "Skipping SKU #{sku}-#{index}: Image already exists"
      return
    end
    
    image_data = Mechanize.new.get(image_url).body
    File.open(filename, 'wb') do |file|
      file.write(image_data)
    end
    puts "Downloaded image #{index} for SKU #{sku}"
  rescue StandardError => e
    puts "Failed to download image for SKU #{sku}: #{e.message}"
  end
end

# Usage
if __FILE__ == $0
  begin
    scraper = Eaglecrest.new
    scraper.scrape
  rescue StandardError => e
    puts "Script failed: #{e.message}"
    exit 1
  end
end
