require "bundler"
Bundler.require(:default)
require "logger"
require "dotenv/load"

DB = Sequel.connect("sqlite://db/bank_sync.db")
LOGGER = Logger.new($stdout)

PUSHOVER_CONFIG = {
  token: ENV.fetch("PUSHOVER_TOKEN"),
  user: ENV.fetch("PUSHOVER_USER")
}

NORDIGEN_CONFIG = {
  secret_id: ENV.fetch("NORDIGEN_SECRET_ID"),
  secret_key: ENV.fetch("NORDIGEN_SECRET_KEY")
}

# require all files in lib
Dir[File.join(__dir__, "lib", "*.rb")].each { |file| require file }
