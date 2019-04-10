class SubjectSample

  # see: http://guides.rubyonrails.org/active_model_basics.html
  include ActiveModel::Model
  include AugmentedVariant

  def self.table
    @@table = "`#{Rails.configuration.x.query['dataset_id']}.#{Rails.configuration.x.query['subject_samples']}`"
  end

  def self.primary_key
    @@primary_key = Rails.configuration.x.query['subject_sample_attrs'].first
  end

  def self.attrs
    Rails.configuration.x.query['subject_sample_attrs']
  end

  def self.search(user, name = nil)
    sql = "select #{attrs.join(', ')} from #{table} where #{primary_key} like '#{name}%' order by #{primary_key} limit 10"
    BigQuery.new(user.credentials).exec_query(sql).map {|record| SubjectSample.new(record)}
  end

  def self.find(user, id)
    sql = "select #{attrs.join(', ')} from #{table} where #{primary_key} = '#{id}'"
    BigQuery.new(user.credentials).exec_query(sql).map {|record| SubjectSample.new(record)}.first
  end

  def self.where(user, clause)
    sql = "select #{attrs.join(', ')} from #{table} where #{clause}"
    BigQuery.new(user.credentials).exec_query(sql).map {|record| SubjectSample.new(record)}
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

  # getter/setter methods for measures
  attr_accessor :measures

  # getter/setter methods for sequence
  attr_accessor :sequence

  # Computed, derived columns
  def id
    self.send('submittedid')
  end

  def name
    self.send('submittedid')
  end

end
