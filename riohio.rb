require 'mechanize'
require 'json'

class Riohio
  URL = 'https://www.riohio.com/category/300/Headwear.html?sort=sku'

  def initialize
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Windows Chrome'
    @agent.robots = false
  rescue StandardError => e
    puts "Initialization failed: #{e.message}"
    raise
  end

  def scrape
    puts "Scraping categories from #{URL}"
    page = @agent.get(URL)
    extract_category_links(page)
  rescue Mechanize::ResponseCodeError => e
    puts "HTTP error: #{e.message}"
    raise
  rescue StandardError => e
    puts "Unexpected error: #{e.message}"
    raise
  end

  private

  def extract_category_links(page)
    page.css('a.sub_category_link').each_with_index do |link, index|
      next if [1, 5].include?(index)

      products_page = @agent.get(link.attr('href'))
      if index.zero?
        products_page.css('.category_wrapper a.sub_category_link').each do |link|
          products_page = @agent.get(link.attr('href'))
          extract_products(products_page)
        end
      else
        extract_products(products_page)
      end
    end
  end

  def extract_products(page)
    products = []
    page.css('div.product_name a').each do |item|
      product_page = @agent.get(item.attr('href'))
      name = product_page.css('#pro_name').text.strip
      sku = product_page.css('#pro_sku').text.strip
      puts "Scraping product: #{name} (SKU: #{sku})"

      first_ul = product_page.css('ul.clearfix').first
      image_urls = []

      if first_ul
        image_urls = first_ul.css('li img').map do |img|
          src = img['src']
          if src
            src.start_with?('http') ? src : "https://www.riohio.com#{src}"
          end
        end.compact.uniq
      end
      if image_urls.empty?
        src = product_page.css('.details_image_box img')[0]['src']
        main_image_url = "https://www.riohio.com#{src}"
        download_image(main_image_url, sku)
      else
        image_urls.each_with_index do |image_url, index|
          download_image(image_url, sku, index + 1)
        end
      end

      products << { name: name, sku: sku, images: image_urls }
    end
    handle_pagination(page)
    products
  end
end

def handle_pagination(page)
  next_page_link = page.css('a.pageNavNext').first['href'] rescue nil
  return if next_page_link == 'javascript:void(0);' || next_page_link.nil?

  next_page = next_page_link
  puts "Navigating to next page: #{next_page}"
  next_page_content = @agent.get(next_page)
  extract_products(next_page_content)
end

def download_image(image_url, sku, index = '')
  return unless image_url && sku
  image_url = image_url.gsub("thumb","detailsbig")
  begin
    # Create riohio folder inside images directory
    Dir.mkdir('images') unless Dir.exist?('images')
    Dir.mkdir('images/riohio') unless Dir.exist?('images/riohio')
    
    filename = "images/riohio/#{sku.downcase}-#{index}.jpg"
    
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
  # begin
  scraper = Riohio.new
  scraper.scrape
  # rescue StandardError => e
  #   puts "Script failed: #{e.message}"
  #   exit 1
  # end
end
