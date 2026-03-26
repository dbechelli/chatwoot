class Uazapi::Client
  DEFAULT_TIMEOUT = 5

  def initialize(base_url:, token:)
    @base_url = base_url.to_s.sub(%r{/+$}, '')
    @token = token
  end

  def edit_message(message_id:, text:)
    post('/message/edit', { id: message_id, text: text })
  end

  def delete_message(message_id:)
    post('/message/delete', { id: message_id })
  end

  private

  attr_reader :base_url, :token

  def post(path, payload)
    response = RestClient::Request.execute(
      method: :post,
      url: "#{base_url}#{path}",
      payload: payload.to_json,
      headers: {
        content_type: :json,
        accept: :json,
        token: token
      },
      timeout: timeout
    )

    parse_response(response.body)
  rescue RestClient::ExceptionWithResponse => e
    raise "UAZAPI request failed: #{error_message(e)}"
  end

  def parse_response(body)
    return {} if body.blank?

    JSON.parse(body)
  rescue JSON::ParserError
    {}
  end

  def error_message(error)
    body = error.response&.body
    return body if body.present?

    error.message
  end

  def timeout
    raw_timeout = GlobalConfig.get_value('WEBHOOK_TIMEOUT')
    configured_timeout = raw_timeout.presence&.to_i

    configured_timeout&.positive? ? configured_timeout : DEFAULT_TIMEOUT
  end
end