require 'date'
require 'digest'
require 'jwt'
require 'securerandom'

class ProfileController < ApplicationController
  before_action :authenticate_user!

  respond_to :html

  def show
    @today = Date.today
    @last_month_date = @today.prev_month

    @user = current_user
    @ttl = 3600
    @jwt = get_jwt(@ttl)
    @numberOfUsageRecords = 50
    @usage = BigQueryJobStat.where(user_id: @user.id).order(:recorded_at).last(@numberOfUsageRecords).reverse
    @total_bytes_billed = BigQueryJobStat.connection.select_all("SELECT SUM(query_total_bytes_billed) AS total FROM BigQueryJobStats WHERE user_id = #{@user.id}").to_hash[0]['total']
    @total_terabytes_billed = @total_bytes_billed / 1024.0 / 1024 / 1024 / 1024
    @this_month_total_bytes_billed = BigQueryJobStat.connection.select_all("SELECT SUM(query_total_bytes_billed) AS total FROM BigQueryJobStats WHERE user_id = #{@user.id} AND DATE(recorded_at) <= DATE('#{@today}') AND DATE(recorded_at) >= DATE('#{@last_month_date}')").to_hash[0]['total']
    @this_month_total_terabytes_billed = @this_month_total_bytes_billed / 1024.0 / 1024 / 1024 / 1024

    @billing_rate_per_tb = 5
  end

  private

  def get_jwt(ttl)
    token_ttl = ttl

    # FIXME Make it configurable.
    jwt_signature_secret = 'w84tabl2n3wrx7gfh'  # ENV['API_JWT_SECRET']

    token_issue_time = Time.now.to_i
    token_expiration_time = token_issue_time + token_ttl  # This is designed for one-time use.

    # This is a dummy secret, designed to confuse whoever want to reconstruct the token.
    dummy_secret = Digest::SHA2.hexdigest SecureRandom.uuid

    claims = {
      sugar: dummy_secret,
      iat: token_issue_time,
      exp: token_expiration_time
    }

    JWT.encode claims, jwt_signature_secret, 'HS512'
  end
end
