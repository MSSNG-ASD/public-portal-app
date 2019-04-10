class SelectionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user

  def gene
    records = RecordSearcher.call(Gene, @user, params)
    render json: records.to_json, callback: params[:callback]
  end

  def sample
    records = RecordSearcher.call(SubjectSample, @user, params)
    render json: records.to_json, callback: params[:callback]
  end

  def subject
    records = RecordSearcher.call(Subject, @user, params)
    render json: records.to_json, callback: params[:callback]
  end

  def phenotype
    records = RecordSearcher.call(Phenotype, @user, params)
    render json: records.to_json, callback: params[:callback]
  end

  def mim
    records = RecordSearcher.call(Omim, @user, params)
    render json: records.to_json, callback: params[:callback]
  end

  private

    def set_user
      @user = current_user
    end

end
