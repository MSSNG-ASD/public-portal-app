class SequencedSample

  # see: http://guides.rubyonrails.org/active_model_basics.html
  include ActiveModel::Model

  def self.table
    @@table = "`#{Rails.configuration.x.query['dataset_id']}.#{Rails.configuration.x.query['sequenced_samples']}`"
  end

  def self.attrs
    Rails.configuration.x.query['sequenced_sample_attrs']
  end

  def self.where(user, clause)
    sql = "select #{attrs.join(', ')} from #{table} where #{clause}"
    BigQuery.new(user.credentials).exec_query(sql).map {|record| SequencedSample.new(record)}
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

end
