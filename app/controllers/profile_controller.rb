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
    @numberOfUsageRecords = 50
    @usage = BigQueryJobStat.where(user_id: @user.id).order(:recorded_at).last(@numberOfUsageRecords).reverse
    @total_bytes_billed = BigQueryJobStat.connection.select_all("SELECT SUM(query_total_bytes_billed) AS total FROM BigQueryJobStats WHERE user_id = #{@user.id}").to_hash[0]['total']
    @total_terabytes_billed = @total_bytes_billed / 1024.0 / 1024 / 1024 / 1024
    @this_month_total_bytes_billed = BigQueryJobStat.connection.select_all("SELECT SUM(query_total_bytes_billed) AS total FROM BigQueryJobStats WHERE user_id = #{@user.id} AND DATE(recorded_at) <= DATE('#{@today}') AND DATE(recorded_at) >= DATE('#{@last_month_date}')").to_hash[0]['total']
    @this_month_total_terabytes_billed = @this_month_total_bytes_billed / 1024.0 / 1024 / 1024 / 1024

    @billing_rate_per_tb = 5
  end
end
