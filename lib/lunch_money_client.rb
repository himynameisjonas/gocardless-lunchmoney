require "net/http"
require "json"

class LunchMoneyClient
  BASE_URL = "https://dev.lunchmoney.app/v1"

  def create_transactions(transactions:)
    post("/transactions", {
      transactions:,
      debit_as_negative: true,
      apply_rules: true,
      check_for_recurring: true
    })
  end

  private

  def post(path, body)
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{LUNCH_MONEY_CONFIG[:access_token]}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)
    puts "Response code: #{response.code}"
    puts "Body:"
    puts response.body

    handle_response(response)
  end

  def handle_response(response)
    case response.code.to_i
    when 200, 201
      json = JSON.parse(response.body)
      if json["error"]
        raise "API Error: #{json["error"]}"
      else
        json
      end
    when 401
      raise "Unauthorized: Invalid access token"
    when 409
      raise "Conflict: #{response.body}"
    else
      raise "API Error (#{response.code}): #{response.body}"
    end
  end
end
