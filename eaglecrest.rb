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
    page.css('a.category-link').each do |link|
      products_page = @agent.get(link.attr('href'))
      extract_products(products_page)
    end
  end

  def extract_products(page)
    products = []
    @driver.get(page.uri)
    sleep 2
    scroll_down_slowly(@driver)
    product_elements = @driver.find_elements(css: 'li.product-title a')
    product_links = product_elements.map { |el| el.attribute('href') }
    product_links.each do |item|
      product_page = @agent.get(item)
      name = product_page.css('h1.product-title').text.strip
      sku = product_page.css('.product-details-code span').text.strip
      puts "Scraping product: #{name} (SKU: #{sku})"

      image_urls = product_page.css('.slides li a').map do |img|
        'https://www.eaglecrest.com' + img.attr('data-zoom-image')
      end

      image_urls.each_with_index do |image_url, index|
        download_image(image_url, sku, index + 1)
      end
      if image_urls.empty?
        main_image_url = 'https://www.eaglecrest.com' + product_page.css('#product-detail-gallery-main-img').attr('data-zoom-image')
        download_image(main_image_url, sku, 1)
      end
      products << { name: name, sku: sku, images: image_urls }
    end
    products
  end
end

def scroll_down_slowly(driver, step_fraction: 0.05, pause: 3, max_loops: 50)
  get_height = lambda {
    driver.execute_script(
      'return Math.max(document.body.scrollHeight, document.documentElement.scrollHeight);'
    ).to_f
  }

  puts 'Scrolling until real bottom is reached...'

  previous_total = get_height.call
  current_y = 0.0

  loop_count = 0
  loop do
    break if loop_count >= max_loops

    # Recalculate scroll height each loop
    total_height = get_height.call
    step = [total_height * step_fraction, 50].max
    target = [current_y + step, total_height].min

    driver.execute_script('window.scrollTo(0, arguments[0]);', target)
    sleep pause

    new_total = get_height.call
    puts "Scroll height after scroll: #{new_total}"

    # If scroll height increased → new content loaded
    if new_total > previous_total
      previous_total = new_total
      puts 'New content loaded... updating height.'
    end

    # If target reached the end AND height did not change → bottom found
    if (previous_total - target).abs <= 5.0 && new_total == previous_total
      puts 'Bottom reached!'
      break
    end

    current_y = target
    loop_count += 1
  end

  # Force scroll to bottom again for safety
  driver.execute_script('window.scrollTo(0, document.body.scrollHeight);')
end

def download_image(image_url, sku, index = '')
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
