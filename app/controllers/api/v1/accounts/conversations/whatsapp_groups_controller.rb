# frozen_string_literal: true

class Api::V1::Accounts::Conversations::WhatsappGroupsController < Api::V1::Accounts::Conversations::BaseController
  before_action :ensure_whatsapp_group

  def show
    @group_info = {
      id: @conversation.whatsapp_group_id,
      name: @conversation.whatsapp_group_name,
      participant_count: @conversation.whatsapp_group_participants_count,
      members: @conversation.whatsapp_group_members.order(:name)
    }
  end

  def update_name
    group_service.update_name(params[:name])
    head :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def update_description
    group_service.update_description(params[:description])
    head :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def add_member
    group_service.add_member(params[:phone_number], name: params[:name])
    head :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def remove_member
    group_service.remove_member(params[:phone_number])
    head :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def promote_admin
    group_service.promote_admin(params[:phone_number])
    head :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def demote_admin
    group_service.demote_admin(params[:phone_number])
    head :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def sync_members
    group_service.sync_members
    head :ok
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    render json: { error: e.message }, status: :internal_server_error
  end

  private

  def ensure_whatsapp_group
    return if @conversation.whatsapp_group?

    render json: { error: 'Conversation is not a WhatsApp group' }, status: :unprocessable_entity
  end

  def group_service
    @group_service ||= WhatsappGroupService.new(conversation: @conversation)
  end
end
