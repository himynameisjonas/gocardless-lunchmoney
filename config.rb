require "bundler"
Bundler.require(:default)
require "logger"
require "dotenv/load"

DB = Sequel.connect("sqlite://db/bank_sync.db")
LOGGER = Logger.new($stdout)

begin
  PUSHOVER_CONFIG = {
    token: ENV["PUSHOVER_TOKEN"],
    user: ENV["PUSHOVER_USER"]
  }

  NORDIGEN_CONFIG = {
    secret_id: ENV.fetch("NORDIGEN_SECRET_ID"),
    secret_key: ENV.fetch("NORDIGEN_SECRET_KEY")
  }

  LUNCH_MONEY_CONFIG = {
    access_token: ENV.fetch("LUNCHMONEY_ACCESS_TOKEN")
  }
rescue KeyError => e
  LOGGER.error("Missing environment variable: #{e.message}")
  exit 1
end

# require all files in lib
Dir[File.join(__dir__, "lib", "*.rb")].each { |file| require file }
