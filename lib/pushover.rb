class Pushover
  def push(message)
    if ENV["PUSHOVER_TOKEN"].nil? || ENV["PUSHOVER_USER"].nil?
      return LOGGER.error "Pushover token or user not set"
    end

    uri = URI.parse("https://api.pushover.net/1/messages.json")
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      "token" => ENV["PUSHOVER_TOKEN"],
      "user" => ENV["PUSHOVER_USER"],
      "message" => message
    )
    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      LOGGER.error "Failed to send Pushover notification: #{response.body}"
    end
  end
end
