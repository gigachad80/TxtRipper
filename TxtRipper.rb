#!/usr/bin/env ruby
require 'net/http'
require 'uri'
require 'optparse'
require 'openssl'

# Global variables for caching
@final_successful_url = nil
@last_domain_processed = nil
@cached_content = nil
@numbered_urls = []

# Function to normalize domain/URL input
def normalize_domain(input)
  # Remove any protocol prefix if present
  domain = input.gsub(/^https?:\/\//, '')
  # Remove trailing slash and path if present
  domain = domain.split('/').first
  return domain
end

# Enhanced function to clean URLs for bruteforcing
def clean_url_for_bruteforce(url_string)
  return nil if url_string.nil? || url_string.empty?
  
  # Remove wildcards and everything after them
  cleaned = url_string.gsub(/\*.*$/, '')
  
  # Remove query parameters
  cleaned = cleaned.gsub(/\?.*/, '')
  
  # Remove fragments
  cleaned = cleaned.gsub(/#.*/, '')
  
  # Handle specific patterns
  cleaned = cleaned.gsub(/&.*$/, '') # Remove everything after &
  
  # Remove trailing slashes for directory bruteforcing
  cleaned = cleaned.chomp('/')
  
  # If the cleaned URL is just the domain, return the base URL
  if cleaned.match?(/^https?:\/\/[^\/]+$/)
    return cleaned
  end
  
  # If we have a path, ensure it's valid for directory bruteforcing
  if cleaned.match?(/^https?:\/\/[^\/]+\/.+/)
    # For paths ending with specific file types or complete endpoints, 
    # extract the directory portion
    if cleaned.match?(/\.(html|php|asp|jsp|xml|json|txt|pdf)$/i) || 
       cleaned.include?('/complete') || 
       cleaned.include?('/api-docs')
      # Extract directory path
      uri = URI.parse(cleaned)
      path_parts = uri.path.split('/')
      path_parts.pop # Remove the file/endpoint
      new_path = path_parts.join('/')
      new_path = '/' if new_path.empty?
      return "#{uri.scheme}://#{uri.host}#{uri.port && uri.port != 80 && uri.port != 443 ? ":#{uri.port}" : ''}#{new_path}"
    end
    return cleaned
  end
  
  return nil # Return nil for invalid URLs
end

# Function to generate multiple bruteforce targets from a single disallow entry
def generate_bruteforce_targets(disallow_line, base_url)
  targets = []
  path = disallow_line.split(':', 2).last.strip
  
  return targets if path.empty?
  
  # Ensure path starts with /
  path = '/' + path unless path.start_with?('/')
  
  # Handle different wildcard patterns
  if path.include?('*')
    # Pattern 1: /path/* - bruteforce the directory
    if path.end_with?('/*')
      clean_path = path.chomp('/*')
      targets << base_url + clean_path
    # Pattern 2: /path* - bruteforce the parent directory
    elsif path.match?(/\/[^\/]*\*$/)
      parent_path = File.dirname(path.gsub(/\*.*$/, ''))
      parent_path = '/' if parent_path == '.'
      targets << base_url + parent_path
    # Pattern 3: Complex patterns with * in middle
    else
      # Extract the base path before the first *
      base_path = path.split('*').first
      parent_path = File.dirname(base_path)
      parent_path = '/' if parent_path == '.'
      targets << base_url + parent_path
      targets << base_url + base_path if base_path != parent_path
    end
  else
    # No wildcards, handle as regular path
    if path.match?(/\.(html|php|asp|jsp|xml|json|txt|pdf)$/i) ||
       path.include?('/complete') ||
       path.include?('/api-docs')
      # File or endpoint - bruteforce the directory
      parent_path = File.dirname(path)
      parent_path = '/' if parent_path == '.'
      targets << base_url + parent_path
    else
      # Directory path
      targets << base_url + path
    end
  end
  
  return targets.uniq
end

# Function to fetch the content of robots.txt from a given domain, following redirects
def fetch_robots_txt(domain_input, redirect_limit = 5)
  # Normalize the domain input
  domain = normalize_domain(domain_input)

  # Store the final successful URL for URL formatting
  @final_successful_url = nil

  # Construct potential URLs for robots.txt (HTTPS first, then HTTP)
  urls_to_try = ["https://#{domain}/robots.txt", "http://#{domain}/robots.txt"]

  urls_to_try.each do |url_string|
    current_url = url_string
    redirect_count = 0

    loop do
      if redirect_count >= redirect_limit
        puts "Redirect limit (#{redirect_limit}) exceeded for #{url_string}"
        break
      end

      begin
        # Parse the current URL string into a URI object
        uri = URI.parse(current_url)

        # Validate URI has host
        unless uri.host
          puts "Error: Invalid URL format '#{current_url}' - no host found"
          break
        end

        http = Net::HTTP.new(uri.host, uri.port)

        if uri.scheme == 'https'
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        end

        http.open_timeout = 10
        http.read_timeout = 10
        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = 'TxtRipper/1.0 (robots.txt fetcher)'

        print "Attempting to fetch from: #{current_url}..."
        response = http.request(request)
        puts " Status: #{response.code}"

        case response
        when Net::HTTPSuccess
          puts "Successfully fetched robots.txt from final URL: #{current_url}"
          @final_successful_url = current_url
          return response.body
        when Net::HTTPRedirection
          new_location = response['location']
          if new_location
            new_url = URI.join(current_url, new_location).to_s
            puts "Redirected to: #{new_url}"
            current_url = new_url
            redirect_count += 1
          else
            puts "Redirect received without Location header for #{current_url}"
            break
          end
        when Net::HTTPNotFound
          puts "No robots.txt found at final URL: #{current_url} (404 Not Found)."
          break
        else
          puts "Received final HTTP status #{response.code} from #{current_url}. Trying next URL if available."
          break
        end
      rescue URI::InvalidURIError => e
        puts "Error: Invalid URL format '#{current_url}': #{e.message}"
        break
      rescue SocketError => e
        puts "Connection Error for #{current_url}: #{e.message}"
        break
      rescue Net::OpenTimeout, Net::ReadTimeout => e
        puts "Timeout Error for #{current_url}: #{e.message}"
        break
      rescue OpenSSL::SSL::SSLError => e
        puts "SSL Error fetching #{current_url}: #{e.message}"
        break
      rescue Errno::ECONNREFUSED => e
        puts "Connection refused for #{current_url}: #{e.message}"
        break
      rescue StandardError => e
        puts "An unexpected error occurred fetching #{current_url}: #{e.message}"
        break
      end
    end
  end
  return "Could not fetch robots.txt for domain/URL '#{domain_input}' after trying all schemes and redirects."
end

# Enhanced function to filter and display disallow lines
def show_disallow_lines(content, domain = nil, format_urls = false, show_numbers = false)
  disallow_lines = content.lines.grep(/^\s*disallow\s*:/i)

  if disallow_lines.empty?
    puts "No Disallow lines found in robots.txt."
  else
    @numbered_urls.clear # Clear previous URLs before populating for the current domain/content

    if format_urls && domain
      if @final_successful_url
        uri = URI.parse(@final_successful_url)
        base_url = "#{uri.scheme}://#{uri.host}"
        base_url += ":#{uri.port}" if uri.port != 80 && uri.port != 443
      else
        normalized_domain = normalize_domain(domain)
        base_url = "https://#{normalized_domain}" # Default to https if final URL not known
      end

      puts "=== Formatted URLs (bruteforce targets) ==="
      counter = 1
      disallow_lines.each do |line|
        targets = generate_bruteforce_targets(line, base_url)
        
        targets.each do |target|
          if show_numbers
            puts "#{counter}. #{target} [from: #{line.strip}]"
            @numbered_urls << target
            counter += 1
          else
            puts "#{target} [from: #{line.strip}]"
          end
        end
      end
    else # Show raw disallow lines
      if show_numbers
        puts "=== Numbered Disallow Lines ==="
        counter = 1
        disallow_lines.each do |line|
          clean_line = line.strip
          puts "#{counter}. #{clean_line}"
          @numbered_urls << clean_line
          counter += 1
        end
      else
        puts disallow_lines.join
      end
    end
  end
end

# Enhanced function to handle bruteforce tool selection and execution
def handle_bruteforce_selection(selected_url)
  puts "\n=== Bruteforce Tool Selection ==="
  puts "Selected target: #{selected_url}"
  puts "\nSelect a tool for directory bruteforcing:"
  puts "1. Feroxbuster (Recommended for complex paths)"
  puts "2. Gobuster"
  puts "3. FFUF"
  puts "4. Dirsearch"
  print "Enter your choice (1-4): "

  choice = gets.chomp.to_i

  case choice
  when 1
    tool_name = "Feroxbuster"
    default_syntax = "feroxbuster -u #{selected_url} -w <wordlist> -d 3 -t 50 --auto-bail"
  when 2
    tool_name = "Gobuster"
    default_syntax = "gobuster dir -u #{selected_url} -w <wordlist> -t 50 -x php,html,txt,json"
  when 3
    tool_name = "FFUF"
    default_syntax = "ffuf -w <wordlist> -u #{selected_url}/FUZZ -mc 200,204,301,302,307,401,403 -t 50"
  when 4
    tool_name = "Dirsearch"
    default_syntax = "dirsearch -u #{selected_url} -w <wordlist> -t 50 -e php,html,txt,json"
  else
    puts "Invalid choice. Exiting."
    return
  end

  puts "\n[INFO] You've chosen #{tool_name}. Here's the recommended syntax:"
  puts "#{default_syntax}"
  print "Do you want to customize syntax? (y/n): "

  customize_choice = gets.chomp.downcase
  final_syntax = default_syntax

  if customize_choice == 'y' || customize_choice == 'yes'
    puts "\nType 'set <your custom syntax>' to set custom syntax:"
    print "> "
    custom_input = gets.chomp

    if custom_input.start_with?('set ')
      final_syntax = custom_input[4..-1].strip
      puts "Custom syntax set: #{final_syntax}"
    else
      puts "Invalid format. Using default syntax."
    end
  end

  puts "\nWordlist options:"
  puts "1. /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
  puts "2. /usr/share/wordlists/dirb/common.txt"
  puts "3. /usr/share/wordlists/dirbuster/directory-list-lowercase-2.3-medium.txt"
  puts "4. /usr/share/wordlists/wfuzz/general/admin-panels.txt"
  puts "5. /usr/share/seclists/Discovery/Web-Content/common.txt"
  puts "6. Custom wordlist path"
  print "Select wordlist (1-6): "

  wordlist_choice = gets.chomp.to_i
  wordlist = case wordlist_choice
  when 1
    "/usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt"
  when 2
    "/usr/share/wordlists/dirb/common.txt"
  when 3
    "/usr/share/wordlists/dirbuster/directory-list-lowercase-2.3-medium.txt"
  when 4
    "/usr/share/wordlists/wfuzz/general/admin-panels.txt"
  when 5
    "/usr/share/seclists/Discovery/Web-Content/common.txt"
  when 6
    print "Enter custom wordlist path: "
    gets.chomp
  else
    puts "Invalid wordlist choice. Defaulting to dirb common.txt"
    "/usr/share/wordlists/dirb/common.txt"
  end

  if final_syntax.include?('<wordlist>')
    final_syntax = final_syntax.gsub('<wordlist>', wordlist)
  else
    puts "Note: Adding wordlist parameter to the command."
    if tool_name == "Feroxbuster"
      final_syntax += " -w #{wordlist}" unless final_syntax.include?(' -w ')
    elsif tool_name == "Gobuster"
      final_syntax += " -w #{wordlist}" unless final_syntax.include?(' -w ')
    elsif tool_name == "Dirsearch"
      final_syntax += " -w #{wordlist}" unless final_syntax.include?(' -w ')
    end
  end

  puts "\nFinal command to execute:"
  puts "#{final_syntax}"
  puts "\nAdditional recommendations:"
  puts "- Consider using multiple wordlists for better coverage"
  puts "- Monitor for rate limiting and adjust threads (-t) accordingly"
  puts "- Check for interesting status codes beyond 200 (401, 403, etc.)"
  
  print "\nDo you want to run this command? (y/n): "

  run_choice = gets.chomp.downcase
  if run_choice == 'y' || run_choice == 'yes'
    puts "\n[EXECUTING] #{final_syntax}"
    puts "=" * 50
    system(final_syntax)
  else
    puts "Execution cancelled. You can copy and run the command manually:"
    puts final_syntax
  end
end

# Function to handle URL selection for bruteforcing
def handle_url_selection_for_bruteforce
  if @numbered_urls.empty?
    return
  end

  puts "\nSelect a URL to bruteforce from the numbered list above:"
  print "Enter the serial number (or 'all' to see analysis): "
  selection = gets.chomp

  if selection.downcase == 'all'
    puts "\n=== Target Analysis ==="
    @numbered_urls.each_with_index do |url, index|
      puts "#{index + 1}. #{url}"
      if url.include?('/api')
        puts "   -> API endpoint detected - good for finding API documentation"
      elsif url.include?('/admin')
        puts "   -> Admin panel path - high value target"
      elsif url.include?('/app')
        puts "   -> Application path - may contain sensitive files"
      elsif url.match?(/\/(m|mobile)\//)
        puts "   -> Mobile version path - different attack surface"
      end
    end
    print "\nNow select a number to bruteforce: "
    selection = gets.chomp
  end

  selection_num = selection.to_i
  if selection_num > 0 && selection_num <= @numbered_urls.length
    selected_url = @numbered_urls[selection_num - 1]
    puts "Selected URL for bruteforcing: #{selected_url}"
    handle_bruteforce_selection(selected_url)
  else
    puts "Invalid selection. Please choose a valid serial number from the list."
  end
end

# Function to process single domain
def process_single_domain(domain, show_disallow_only, format_urls = false, show_numbers = false)
  puts "Processing domain/URL: #{domain}"

  if @last_domain_processed == domain && @cached_content
    puts "Using cached content for #{domain}"
    content = @cached_content
  else
    content = fetch_robots_txt(domain)
    @last_domain_processed = domain
    @cached_content = content
  end

  puts "--- robots.txt content for #{domain} ---"
  if content.is_a?(String) && !content.start_with?("Error:") && !content.start_with?("Could not fetch")
    if show_disallow_only
      show_disallow_lines(content, domain, format_urls, show_numbers)
    else
      puts content
    end
  else
    puts content
  end
  puts "--------------------------"
end

# Function to process multiple domains from file
def process_domain_list(filename, show_disallow_only, format_urls = false, show_numbers = false)
  unless File.exist?(filename)
    puts "Error: File '#{filename}' not found."
    exit(1)
  end

  puts "Fetching robots.txt for domains/URLs listed in: #{filename}"
  File.readlines(filename).each_with_index do |line, index|
    domain_input = line.strip
    next if domain_input.empty? || domain_input.start_with?('#')

    puts "\nProcessing domain/URL #{index + 1}: #{domain_input}"
    content = fetch_robots_txt(domain_input)

    puts "--- robots.txt content for #{domain_input} ---"
    if content.is_a?(String) && !content.start_with?("Error:") && !content.start_with?("Could not fetch")
      if show_disallow_only
        show_disallow_lines(content, domain_input, format_urls, show_numbers)
      else
        puts content
      end
    else
      puts content
    end
    puts "============================"
  end
end

# --- Command Line Argument Parsing ---
options = {}

option_parser = OptionParser.new do |opts|
  opts.banner = "Usage: ruby #{File.basename(__FILE__)} [options]"

  opts.on("-u URL", "--url URL", "Specify a single domain or URL to crawl robots.txt") do |url|
    options[:url] = url
  end

  opts.on("-l FILENAME", "--list FILENAME", "Specify a file containing a list of domains or URLs") do |filename|
    options[:list] = filename
  end

  opts.on("-d", "--disallow", "Show only Disallow lines from robots.txt content") do
    options[:show_disallow_only] = true
  end

  opts.on("-f", "--format", "Format disallow paths as full clickable URLs (use with -d)") do
    options[:format_urls] = true
  end

  opts.on("-n", "--numbered", "Number the Disallow lines (used with -d for selection)") do
    options[:show_numbers] = true
  end

  opts.on("--brute", "Enable bruteforce mode for a selected URL from Disallow entries. Implies -d, -f, and -n.") do
    options[:bruteforce] = true
  end

  opts.on("-h", "--help", "Prints this help message") do
    puts opts
    exit
  end
end

begin
  option_parser.parse!
rescue OptionParser::InvalidOption => e
  puts "Error: #{e.message}"
  puts "Use -h for help."
  exit(1)
rescue OptionParser::MissingArgument => e
  puts "Error: #{e.message}"
  puts "Use -h for help."
  exit(1)
end

# --- Main Program Logic ---

# If bruteforce is enabled, set necessary flags for display to allow URL selection
if options[:bruteforce]
  options[:show_disallow_only] = true
  options[:format_urls] = true
  options[:show_numbers] = true
end

# Inform user if -f or -n are used without -d (and not part of --brute)
if (options[:format_urls] || options[:show_numbers]) && !options[:show_disallow_only]
    unless options[:bruteforce]
        puts "Info: -f (format) and -n (numbered) options are effective when -d (disallow) is also used."
    end
end

if options[:url]
  process_single_domain(options[:url], options[:show_disallow_only], options[:format_urls], options[:show_numbers])
elsif options[:list]
  if options[:bruteforce]
    puts "Warning: When using --brute with -l, bruteforce selection will be available for the *last* domain in the list"
    puts "         that has Disallow entries. Display options (-d, -f, -n) are enabled for all domains in the list."
  end
  process_domain_list(options[:list], options[:show_disallow_only], options[:format_urls], options[:show_numbers])
else
  puts "Error: Please specify either -u <URL> or -l <FILENAME>."
  puts option_parser.help
  exit(1)
end

# After processing, if bruteforce option is enabled and disallow lines were shown/numbered
if options[:bruteforce]
  if !@numbered_urls.empty?
    handle_url_selection_for_bruteforce
  else
    if (options[:url] || options[:list])
        puts "No Disallow entries were found or listed as selectable URLs, so bruteforce cannot proceed."
        puts "Ensure the robots.txt for the target(s) contains Disallow entries."
    end
  end
end
