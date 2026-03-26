class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    import_uazapi_canned_responses
    render json: canned_responses
  end

  def create
    ActiveRecord::Base.transaction do
      @canned_response = Current.account.canned_responses.new(canned_response_params.except(:retained_attachment_ids, :retain_remote_media))
      @canned_response.save!
    end

    render json: serialized_canned_response(@canned_response)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def update
    ActiveRecord::Base.transaction do
      @canned_response.update!(canned_response_params.except(:retained_attachment_ids, :retain_remote_media))
      purge_removed_attachments!
      clear_remote_media! if retain_remote_media? == false
    end

    render json: serialized_canned_response(@canned_response.reload)
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    ActiveRecord::Base.transaction do
      @canned_response.destroy!
    end

    head :ok
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content, :retain_remote_media, attachments: [], retained_attachment_ids: [])
  end

  def canned_responses
    if params[:search]
      Current.account.canned_responses
             .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{params[:search]}%")
             .order_by_search(params[:search])
             .map { |canned_response| serialized_canned_response(canned_response) }
    else
      Current.account.canned_responses.map { |canned_response| serialized_canned_response(canned_response) }
    end
  end

  def serialized_canned_response(canned_response)
    canned_response.as_json(methods: [:file_urls, :canned_files])
  end

  def purge_removed_attachments!
    return unless params[:canned_response]&.key?(:retained_attachment_ids)

    retained_attachment_ids = canned_response_params[:retained_attachment_ids].map(&:to_s)

    @canned_response.attachments.each do |attachment|
      attachment.purge if retained_attachment_ids.exclude?(attachment.id.to_s)
    end
  end

  def clear_remote_media!
    attributes = normalized_additional_attributes_for(@canned_response).merge(
      'uazapi_remote_file_url' => nil,
      'uazapi_remote_doc_name' => nil,
      'uazapi_remote_content_type' => nil,
      'uazapi_message_type' => 'text'
    )

    @canned_response.update!(additional_attributes: attributes)
  end

  def retain_remote_media?
    return if params[:canned_response]&.key?(:retain_remote_media) == false

    ActiveModel::Type::Boolean.new.cast(canned_response_params[:retain_remote_media])
  end

  def import_uazapi_canned_responses
    CannedResponses::ImportFromUazapiService.new(account: Current.account).perform
  rescue StandardError
    nil
  end

  def normalized_additional_attributes_for(canned_response)
    value = canned_response[:additional_attributes]

    case value
    when Hash
      value.stringify_keys
    when ActionController::Parameters
      value.to_unsafe_h.stringify_keys
    when String
      JSON.parse(value).stringify_keys
    else
      {}
    end
  rescue JSON::ParserError
    {}
  end
end
