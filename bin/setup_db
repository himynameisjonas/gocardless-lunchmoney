#!/usr/bin/env ruby

require_relative "../config"
require "fileutils"

# Ensure db directory exists
FileUtils.mkdir_p("db")

# Run migrations
Sequel.extension :migration
Sequel::Migrator.run(DB, File.expand_path("../db/migrations", __dir__))

puts "Database migrations completed successfully!"
puts "Database location: #{File.expand_path("../db/bank_sync.db", __dir__)}"
