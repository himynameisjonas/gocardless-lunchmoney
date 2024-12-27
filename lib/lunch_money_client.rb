require "net/http"
require "json"

class LunchMoneyClient
  BASE_URL = "https://dev.lunchmoney.app/v1"

  def initialize(access_token:)
    @access_token = access_token
  end

  def create_transaction(date:, amount:, currency:, payee:, notes: nil, external_id: nil)
    post("/transactions", {
      transactions: [{
        date: date,
        amount: amount,
        currency: currency,
        payee: payee,
        notes: notes,
        external_id: external_id
      }]
    })
  end

  private

  def post(path, body)
    uri = URI("#{BASE_URL}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@access_token}"
    request["Content-Type"] = "application/json"
    request.body = body.to_json

    response = http.request(request)
    handle_response(response)
  end

  def handle_response(response)
    case response.code.to_i
    when 200, 201
      JSON.parse(response.body)
    when 401
      raise "Unauthorized: Invalid access token"
    when 409
      raise "Conflict: #{response.body}"
    else
      raise "API Error (#{response.code}): #{response.body}"
    end
  end
end
