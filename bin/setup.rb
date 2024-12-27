#!/usr/bin/env ruby

require "optparse"
require_relative "../config"
require_relative "../lib/bank_setup"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: setup.rb [options]"

  opts.on("-l", "--list-banks [COUNTRY]", "List available banks for country code (defaults to SE)") do |country|
    options[:list] = country || "SE"
  end

  opts.on("-c", "--create-requisition INSTITUTION_ID", "Create a new requisition for institution") do |id|
    options[:create] = id
  end

  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end.parse!

setup = BankSetup.new

if options[:list]
  country = options[:list].upcase
  puts "Fetching banks for country: #{country}"
  puts "-" * 50

  institutions = setup.list_institutions(country)
  if institutions.empty?
    puts "No banks found for country code: #{country}"
    exit 1
  end

  institutions.sort_by { |inst| inst[:name] }.each do |inst|
    puts "\e[1m#{inst[:name]}\e[0m"  # Bold name
    puts "ID: #{inst[:id]}"
    puts "Countries: #{inst[:countries]}"
    puts "-" * 50
  end

  puts "\nTo connect to a bank, run:"
  puts "#{$PROGRAM_NAME} --create-requisition BANK_ID"
elsif options[:create]
  puts "Creating requisition for institution: #{options[:create]}"
  begin
    link = setup.create_requisition(options[:create])
    puts "\n\e[32mSuccess!\e[0m Please visit this URL to authorize access to your bank:"
    puts "\e[1m#{link}\e[0m"
    puts "\nAfter authorization, the requisition will be automatically tracked and synced."
  rescue => e
    puts "\e[31mError:\e[0m #{e.message}"
    exit 1
  end
else
  puts "Please specify either --list-banks or --create-requisition"
  puts "Example usage:"
  puts "  #{$PROGRAM_NAME} --list-banks         # List Swedish banks"
  puts "  #{$PROGRAM_NAME} --list-banks NO      # List Norwegian banks"
  puts "  #{$PROGRAM_NAME} --create-requisition BANK_ID"
  exit 1
end
