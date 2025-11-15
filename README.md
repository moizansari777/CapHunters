# Product Image Scraper Collection

A collection of Ruby-based web scrapers designed to extract product images from various tactical and military apparel suppliers. Each scraper is tailored to handle the specific website structure and requirements of different vendors.

## 🎯 Overview

This repository contains automated scrapers for the following vendors:
- **Rapid Dominance** - Tactical caps and headwear
- **Rothco** - Military and tactical gear
- **Eagle Crest** - Custom embroidered headwear
- **Eagle Emblem** - Emblems and patches
- **Riohio** - Promotional products

## 📋 Prerequisites

- Ruby (2.7 or higher recommended)
- Google Chrome browser
- ChromeDriver (for Selenium-based scrapers)

## 🔧 Installation

1. Clone this repository:
```bash
git clone <repository-url>
cd scripts
```

2. Install required gems:
```bash
gem install mechanize
gem install selenium-webdriver
gem install json
```

3. Ensure ChromeDriver is installed and in your PATH:
```bash
# On Ubuntu/Debian
sudo apt-get install chromium-chromedriver

# On macOS with Homebrew
brew install chromedriver
```

## 📁 Project Structure

```
scripts/
├── rapid.rb          # Rapid Dominance scraper (Selenium-based)
├── rothco.rb         # Rothco scraper (API-based)
├── eaglecrest.rb     # Eagle Crest scraper (Hybrid)
├── eagleemble.rb     # Eagle Emblem scraper
├── riohio.rb         # Riohio scraper
└── images/           # Downloaded product images
    ├── rapid/
    ├── rothco/
    ├── eaglecrest/
    └── ...
```

## 🚀 Usage

Each scraper can be run independently:

### Rapid Dominance Scraper
```bash
ruby rapid.rb
```
- Uses Selenium WebDriver for dynamic content
- Scrapes caps from search results
- Automatically scrolls through paginated results
- Downloads product images with SKU-based naming
- Skips already downloaded images

### Rothco Scraper
```bash
ruby rothco.rb
```
- Uses API endpoint for faster data retrieval
- Fetches up to 300 results per page
- Processes multiple pages automatically
- Downloads images with SKU identification

### Eagle Crest Scraper
```bash
ruby eaglecrest.rb
```
- Hybrid approach using Mechanize and Selenium
- Extracts category links
- Scrolls through dynamic content
- Downloads headwear product images

### Other Scrapers
```bash
ruby eagleemble.rb
ruby riohio.rb
```

## 🛠️ Features

### Common Features Across All Scrapers:
- ✅ Automatic image download and organization
- ✅ SKU-based file naming
- ✅ Duplicate detection (skips existing images)
- ✅ Error handling and recovery
- ✅ Progress logging
- ✅ Graceful interruption handling (Ctrl+C)

### Scraper-Specific Features:

**Rapid Dominance (`rapid.rb`)**
- Headless Chrome browser automation
- Smart scrolling for lazy-loaded content
- Card-based product extraction
- Automatic modal handling

**Rothco (`rothco.rb`)**
- Direct API integration
- High-speed bulk data retrieval
- JSON response parsing
- Pagination support

**Eagle Crest (`eaglecrest.rb`)**
- Category-based scraping
- Dynamic content handling
- Customizable scroll behavior

## 📝 Configuration

Each scraper has configurable options at the top of the file:

```ruby
# Example from rapid.rb
URL = 'https://www.rapiddominance.com/search-result?searchWord=caps&searchDesc=caps&searchType=undefined'
```

You can modify:
- Target URLs
- Search parameters
- Sleep/wait times
- Scroll behavior
- User agent strings

## 🖼️ Image Storage

Images are automatically organized in the `images/` directory:
- Each vendor has its own subdirectory
- Files are named using product SKUs
- Duplicate images are automatically skipped
- Directory structure is created automatically

## ⚠️ Important Notes

1. **Rate Limiting**: Be respectful of target websites. The scrapers include sleep timers to avoid overwhelming servers.

2. **Legal Compliance**: Ensure you have permission to scrape and use images from these websites. This tool is for educational purposes.

3. **Headless Mode**: Selenium scrapers run in headless mode by default for efficiency.

4. **Error Handling**: All scrapers include interrupt handling (Ctrl+C) for graceful shutdown.

## 🐛 Troubleshooting

### ChromeDriver Issues
```bash
# Check ChromeDriver version
chromedriver --version

# Update ChromeDriver to match Chrome version
# Download from: https://chromedriver.chromium.org/
```

### Selenium Errors
- Ensure Chrome browser is installed
- Verify ChromeDriver is in PATH
- Check that Chrome and ChromeDriver versions are compatible

### Network Issues
- Check internet connection
- Verify target websites are accessible
- Review firewall settings

## 📊 Output Example

```
Fetching page 1...
Processing SKU: RD-123456
Downloading image for SKU RD-123456-1
Image saved: images/rapid/rd-123456-1.jpg
Skipping SKU RD-789012: Image already exists
...
Scraping completed!
```

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is provided as-is for educational purposes.

## ⚡ Performance Tips

1. **Parallel Processing**: Run multiple scrapers simultaneously for different vendors
2. **Bandwidth**: Ensure stable internet connection for image downloads
3. **Storage**: Monitor disk space in the `images/` directory
4. **Memory**: Close other applications when running Selenium-based scrapers

## 🔄 Updates

To update the scrapers for website changes:
1. Inspect the target website's HTML structure
2. Update CSS selectors in the scraper
3. Test with a small dataset first
4. Adjust sleep timers if needed

---

**Note**: Always respect robots.txt and terms of service of the websites you're scraping.
