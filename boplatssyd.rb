require 'Nokogiri'
require 'HTTParty'
require 'mailjet'
require 'uri'

page_prefix = 'https://www.boplatssyd.se'
pages = [
    'https://www.boplatssyd.se/lagenheter?location[cities][0]=734&rooms[min]=4',
    'https://www.boplatssyd.se/lagenheter?location[cities][0]=776&rooms[min]=4',
]
filename = 'existing_apartments.txt'
email_from = { 'Email'=> 'sender-email@example.com', 'Name'=> 'Sender Name' }
email_to = [
	{ 'Email'=> 'youremail@example.com', 'Name'=> 'Recipient Name' },
]

Mailjet.configure do |config|
  config.api_key = 'api_key'
  config.secret_key = 'secret_api_key'
  config.api_version = 'v3.1'
end

def send_email(from, to, variables)
    variable = Mailjet::Send.create(messages: [{
        'From'=> from,
        'To'=> to,
        'TemplateID'=> 483407,
        'TemplateLanguage'=> true,
        'Subject'=> 'New apartments from Boplats Syd',
        'Variables'=> variables
    }])
    p variable.attributes['Messages']
end

def write_url_to_file(filename, list)
    File.open(filename, 'a') do |file|
        list.each { |item| file.write(item['url'] + "\n") }
    end
end

def fetch_apartments(pages, page_prefix)
    apartments = []
    
    pages.each do |page|
        response = HTTParty.get page
        document = Nokogiri::HTML response

        document.css('#apartment-search-results .object-teaser').each do |item|
            hash = {}

            hash['url'] = page_prefix + item.css('.object-details > a').first['href']
            hash['rooms'] = item.css('.rooms').first.text.strip
            hash['size'] = item.css('.size-kvm').first.text.strip
            hash['rent'] = item.css('.total-rent').first.text.strip
            hash['landlord'] = item.css('.landlord').first.text.strip
            hash['address'] = item.css('.address').first.text.strip
            hash['area'] = item.css('.area').first.text.strip
            hash['municipality'] = item.css('.municipality').first.text.strip

            apartment_response = HTTParty.get hash['url']
            apartment_document = Nokogiri::HTML apartment_response

            hash['image'] = apartment_document.css('.object-image').first['href']

            apartments.push hash
        end
    end

    apartments
end

if File.file? filename
    existing_apartments = File.readlines(filename).map { |item| item.strip }
    new_apartments = fetch_apartments(pages, page_prefix)
    diff_apartments = new_apartments.reject { |item| existing_apartments.include? item['url'] }

    write_url_to_file(filename, diff_apartments)

    if diff_apartments.length > 0
        send_email(email_from, email_to, { 'apartments' => diff_apartments })
    end
else
    new_apartments = fetch_apartments(pages, page_prefix)

    write_url_to_file(filename, new_apartments)

    send_email(email_from, email_to, { 'apartments' => new_apartments })
end
