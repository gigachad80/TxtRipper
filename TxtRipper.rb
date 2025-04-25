#!/usr/bin/env ruby

require 'net/http'
require 'uri'
require 'optparse'
require 'openssl' # Required for OpenSSL::SSL::VERIFY_NONE

# Function to fetch the content of robots.txt from a given domain, following redirects
def fetch_robots_txt(domain, redirect_limit = 5)
  # Construct potential URLs for robots.txt (HTTPS first, then HTTP)
  # We try both schemes as the redirect might happen from http to https or vice versa
  urls_to_try = ["https://#{domain}/robots.txt", "http://#{domain}/robots.txt"]

  urls_to_try.each do |url_string|
    current_url = url_string
    redirect_count = 0

    loop do
      # Break loop if redirect limit is reached
      if redirect_count >= redirect_limit
        puts "Redirect limit (#{redirect_limit}) exceeded for #{url_string}"
        break # Exit the inner loop, try the next initial URL if available
      end

      begin
        # Parse the current URL string into a URI object
        uri = URI.parse(current_url)

        # Create an HTTP connection object
        # The port is correctly set here based on the URI (e.g., 80 for http, 443 for https)
        http = Net::HTTP.new(uri.host, uri.port)

        # Configure SSL if the scheme is HTTPS
        if uri.scheme == 'https'
          http.use_ssl = true
          # WARNING: Disabling SSL verification is a security risk and makes you vulnerable to MITM attacks.
          # Use this only if you understand the risks or are in a trusted environment.
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        # Set timeouts to prevent the script from hanging indefinitely
        http.open_timeout = 5 # seconds for connection establishment
        http.read_timeout = 5 # seconds for reading data

        # Create a GET request for the resource path
        request = Net::HTTP::Get.new(uri.request_uri)

        # Send the request and get the response
        print "Attempting to fetch from: #{current_url}..." # Indicate which URL is being tried
        response = http.request(request)
        puts " Status: #{response.code}" # Print the status code immediately

        # Check the HTTP response status code
        case response
        when Net::HTTPSuccess then
          # Status 2xx (e.g., 200 OK) - robots.txt found and fetched successfully
          puts "Successfully fetched robots.txt from final URL: #{current_url}"
          return response.body # Return the content of robots.txt

        when Net::HTTPRedirection then
          # Status 3xx (e.g., 301, 302) - handle redirect
          new_location = response['location']
          if new_location
            # Resolve relative redirects against the current URL
            new_url = URI.join(current_url, new_location).to_s
            puts "Redirected to: #{new_url}"
            current_url = new_url # Update current_url for the next request
            redirect_count += 1
            # Continue the loop to fetch from the new URL
          else
            puts "Redirect received without Location header for #{current_url}"
            break # Cannot follow redirect without location, exit inner loop
          end

        when Net::HTTPNotFound then
          # Status 404 Not Found - robots.txt does not exist at the final URL
          puts "No robots.txt found at final URL: #{current_url} (404 Not Found)."
          break # Exit the inner loop, try the next initial URL if available

        else
          # Handle other HTTP errors (e.g., 403 Forbidden, 500 Server Error) at the final URL
          puts "Received final HTTP status #{response.code} from #{current_url}. Trying next URL if available."
          break # Exit the inner loop, try the next initial URL if available
        end

      rescue URI::InvalidURIError
        # Catch error if the URL format is invalid
        puts "Error: Invalid URL format '#{current_url}'"
        break # Exit the inner loop, try the next initial URL if available
      rescue SocketError => e
        # Catch errors related to domain name resolution or network connection issues
        puts "Connection Error for #{current_url}: #{e.message}"
        break # Exit the inner loop, try the next initial URL if available
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        # Catch timeout errors during connection or reading
        puts "Timeout Error for #{current_url}: #{e.message}"
        break # Exit the inner loop, try the next initial URL if available
      rescue OpenSSL::SSL::SSLError => e
        # Catch specific SSL errors
        puts "SSL Error fetching #{current_url}: #{e.message}"
        break # Exit the inner loop, try the next initial URL if available
      rescue StandardError => e
        # Catch any other unexpected errors that might occur
        puts "An unexpected error occurred fetching #{current_url}: #{e.message}"
        break # Exit the inner loop, try the next initial URL if available
      end
    end # end of loop
  end # end of urls_to_try.each

  # If the loops finish without successfully fetching robots.txt from any URL
  return "Could not fetch robots.txt for domain/URL '#{domain}' after trying all schemes and redirects."
end

# --- Command Line Argument Parsing ---
# Initialize an empty hash to store parsed options
options = {}

# Create a new OptionParser instance
OptionParser.new do |opts|
  # Define the banner for the help message
  opts.banner = "Usage: ruby #{File.basename(__FILE__)} [options]"

  # Define the -u or --url option for a single domain/URL
  # This is mutually exclusive with -l
  opts.on("-u URL", "--url URL", "Specify a single domain or URL to crawl robots.txt") do |url|
    options[:url] = url # Store the provided URL in the options hash
  end

  # Define the -l or --list option for a file containing a list of domains/URLs
  # This is mutually exclusive with -u
  opts.on("-l FILENAME", "--list FILENAME", "Specify a file containing a list of domains or URLs (one per line)") do |filename|
    options[:list] = filename # Store the provided filename in the options hash
  end

  # Define the -d or --disallow option to filter for Disallow lines
  # This flag does not take an argument
  opts.on("-d", "--disallow", "Show only Disallow lines from robots.txt content (use with -u or -l)") do
    options[:show_disallow_only] = true # Set a flag in the options hash
  end

  # Define the -h or --help option to print the help message
  opts.on("-h", "--help", "Prints this help message") do
    puts opts # Print the help message generated by OptionParser
    exit # Exit the program after printing help
  end

end.parse! # Parse the command-line arguments (ARGV) and modify ARGV in place

# --- Main Program Logic ---

# Check if the -u option was provided
if options[:url]
  # Handle fetching robots.txt for a single domain/URL
  domain = options[:url] # Use the provided URL as the domain for fetching
  puts "Processing domain/URL: #{domain}"
  content = fetch_robots_txt(domain) # Call the fetch function

  puts "--- robots.txt content for #{domain} ---"
  # Check if the -d flag is set and content was successfully fetched
  # Also ensure content is a String and not one of the error messages
  if options[:show_disallow_only] && content.is_a?(String) && !content.start_with?("Error:") && !content.start_with?("Could not fetch")
    # Filter for lines starting with "Disallow:" (case-insensitive strip), allowing space before colon
    disallow_lines = content.lines.grep(/^\s*disallow\s*:/i)
    if disallow_lines.empty?
        puts "No Disallow lines found in robots.txt."
    else
        puts disallow_lines.join
    end
  else
    # Otherwise, print the full content (or error message)
    puts content
  end
  puts "--------------------------"

# Check if the -l option was provided
elsif options[:list]
  # Handle fetching robots.txt for a list of domains/URLs from a file
  filename = options[:list]

  # Check if the specified file exists
  unless File.exist?(filename)
    puts "Error: File '#{filename}' not found."
    exit(1) # Exit with an error code if the file doesn't exist
  end

  puts "Fetching robots.txt for domains/URLs listed in: #{filename}"
  # Read the file line by line
  File.readlines(filename).each_with_index do |line, index|
    # Remove leading/trailing whitespace from the line
    domain = line.strip
    # Skip empty lines or lines starting with '#' (comments)
    next if domain.empty? || domain.start_with?('#')

    # Print which domain is currently being processed
    puts "\nProcessing domain/URL #{index + 1}: #{domain}"
    content = fetch_robots_txt(domain) # Call the fetch function for the domain

    puts "--- robots.txt content for #{domain} ---"
    # Check if the -d flag is set and content was successfully fetched
    # Also ensure content is a String and not one of the error messages
    if options[:show_disallow_only] && content.is_a?(String) && !content.start_with?("Error:") && !content.start_with?("Could not fetch")
      # Filter for lines starting with "Disallow:" (case-insensitive strip), allowing space before colon
      disallow_lines = content.lines.grep(/^\s*disallow\s*:/i)
       if disallow_lines.empty?
          puts "No Disallow lines found in robots.txt."
      else
          puts disallow_lines.join
      end
    else
      # Otherwise, print the full content (or error message)
      puts content
    end
    puts "============================" # Print a separator for list mode
  end

# If neither -u nor -l option was provided
else
  # Print an error message and usage instructions
  puts "Error: Please specify either -u or -l option."
  puts "Use -h for help."
  exit(1) # Exit with an error code
end
