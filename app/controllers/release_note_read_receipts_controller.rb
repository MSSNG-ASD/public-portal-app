require 'securerandom'

class ReleaseNoteReadReceiptsController < ApplicationController
  before_action :authenticate_user!
  skip_before_action :verify_authenticity_token

  def index
    receipts = ReleaseNoteReadReceipt.where user_id: current_user.id

    render json: receipts
  end

  def show
    receipt = ReleaseNoteReadReceipt.find_by user_id: current_user.id, entry_id: params[:id]

    render json: receipt
  end

  def update
    begin
      status = 200
      receipt = ReleaseNoteReadReceipt.create(
        id: SecureRandom.uuid,
        user_id: current_user.id,
        entry_id: params[:id],
        created_at: Time.now.utc
      )
    rescue ActiveRecord::RecordNotUnique
      status = 202
      receipt = ReleaseNoteReadReceipt.find_by user_id: current_user.id, entry_id: params[:id]
    end

    render json: receipt, status: status
  end
end