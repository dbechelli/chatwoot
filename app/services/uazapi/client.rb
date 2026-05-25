module Uazapi
  class Client
    DEFAULT_TIMEOUT = 5
    DEFAULT_MEDIA_TIMEOUT = 30
    ESCAPED_NEWLINE_PATTERN = /\\r\\n|\\n|\\r/

    def initialize(base_url:, token:)
      @base_url = base_url.to_s.sub(%r{/+$}, '')
      @token = token
    end

    def edit_message(message_id:, text:)
      post('/message/edit', { id: message_id, text: normalize_text(text) })
    end

    def send_text_message(recipient_id:, text:, quoted_message_id: nil, track_id: nil, forward: nil)
      payload = {
        number: recipient_id,
        text: normalize_text(text),
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
        text: normalize_text(text),
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

    def send_contact_message(recipient_id:, full_name:, phone_number:, organization: nil, email: nil, url: nil,
                             reply_id: nil, track_id: nil, forward: nil)
      payload = {
        number: recipient_id,
        fullName: full_name,
        phoneNumber: phone_number,
        organization: organization,
        email: email,
        url: url,
        replyid: reply_id,
        async: true,
        forward: forward,
        track_source: 'chatwoot',
        track_id: track_id
      }

      post('/send/contact', payload.compact)
    end

    def send_pix_button(recipient_id:, pix_type:, pix_key:, pix_name: nil, reply_id: nil, track_id: nil, forward: nil)
      payload = {
        number: recipient_id,
        pixType: pix_type,
        pixKey: pix_key,
        pixName: pix_name,
        replyid: reply_id,
        async: true,
        forward: forward,
        track_source: 'chatwoot',
        track_id: track_id
      }

      post('/send/pix-button', payload.compact)
    end

    def delete_message(message_id:)
      post('/message/delete', { id: message_id })
    end

    def list_quick_replies
      response = get('/quickreply/list')
      extract_collection(response)
    end

    def edit_quick_reply(id: nil, delete: nil, short_cut:, type:, text: nil, file: nil, doc_name: nil)
      payload = {
        id: id,
        delete: delete,
        shortCut: short_cut,
        type: type,
        text: normalize_text(text),
        file: file,
        docName: doc_name
      }

      timeout = file.present? ? media_timeout : request_timeout

      post('/quickreply/edit', payload.compact, timeout: timeout)
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

    def get(path, timeout: request_timeout)
      response = RestClient::Request.execute(
        method: :get,
        url: "#{base_url}#{path}",
        headers: {
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

    def extract_collection(response)
      collection = [
        response['data'],
        response['quickReplies'],
        response['quick_replies'],
        response['message'],
        response['result']
      ].find { |value| value.is_a?(Array) }

      return collection if collection.present?

      response.values.find { |value| value.is_a?(Array) } || []
    end

    def normalize_text(text)
      return text unless text.is_a?(String)

      text.gsub(/\r\n?/, "\n").gsub(ESCAPED_NEWLINE_PATTERN, "\n")
    end
  end
end
