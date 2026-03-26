module Uazapi
  class Client
    DEFAULT_TIMEOUT = 5
    DEFAULT_MEDIA_TIMEOUT = 30

    def initialize(base_url:, token:)
      @base_url = base_url.to_s.sub(%r{/+$}, '')
      @token = token
    end

    def edit_message(message_id:, text:)
      post('/message/edit', { id: message_id, text: text })
    end

    def send_text_message(recipient_id:, text:, quoted_message_id: nil, track_id: nil, forward: nil)
      payload = {
        number: recipient_id,
        text: text,
        replyid: quoted_message_id,
        async: true,
        forward: forward,
        track_source: 'chatwoot',
        track_id: track_id
      }

      post('/send/text', payload.compact)
    end

    def send_media_message(recipient_id:, media_type:, file_url:, text: nil, doc_name: nil, mime_type: nil, reply_id: nil,
                           track_id: nil, forward: nil)
      payload = {
        number: recipient_id,
        type: media_type,
        file: file_url,
        text: text,
        docName: doc_name,
        mimetype: mime_type,
        replyid: reply_id,
        async: true,
        forward: forward,
        track_source: 'chatwoot',
        track_id: track_id
      }

      post('/send/media', payload.compact, timeout: media_timeout)
    end

    def delete_message(message_id:)
      post('/message/delete', { id: message_id })
    end

    private

    attr_reader :base_url, :token

    def post(path, payload, timeout: request_timeout)
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

    def request_timeout
      raw_timeout = GlobalConfig.get_value('WEBHOOK_TIMEOUT')
      configured_timeout = raw_timeout.presence&.to_i

      configured_timeout&.positive? ? configured_timeout : DEFAULT_TIMEOUT
    end

    def media_timeout
      [request_timeout, DEFAULT_MEDIA_TIMEOUT].max
    end
  end
end
