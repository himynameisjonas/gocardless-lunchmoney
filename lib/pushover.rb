class Pushover
  def push(message)
    if PUSHOVER_CONFIG[:token].nil? || PUSHOVER_CONFIG[:user].nil?
      return LOGGER.error "Pushover token or user not set"
    end

    uri = URI.parse("https://api.pushover.net/1/messages.json")
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      "token" => PUSHOVER_CONFIG[:token],
      "user" => PUSHOVER_CONFIG[:user],
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
