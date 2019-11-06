class SubjectSample

  # see: http://guides.rubyonrails.org/active_model_basics.html
  include ActiveModel::Model
  include AugmentedVariant

  def self.table
    search_config = Rails.configuration.x.query['db6']
    @@table = "`#{search_config['project_id']}.#{search_config['tables']['subject_samples']}`"
  end

  def self.primary_key
    @@primary_key = self.attrs.first
  end

  def self.attrs
    Rails.configuration.x.query['subject_sample_attrs']
  end

  def self.search(user, name = nil)
    sql = "select #{attrs.join(', ')} from #{table} where #{primary_key} like '#{name}%' order by #{primary_key}"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| SubjectSample.new(record)}
  end

  def self.find(user, id)
    sql = "select #{attrs.join(', ')} from #{table} where #{primary_key} = '#{id}' ORDER BY #{self.attrs[1]}"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| SubjectSample.new(record)}
  end

  def self.find_one_by_sample_id(user, id)
    sql = "select #{attrs.join(', ')} from #{table} where submittedid = '#{id}' ORDER BY #{self.attrs[1]}"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| SubjectSample.new(record)}.first
  end

  def self.where(user, clause)
    sql = "select #{attrs.join(', ')} from #{table} where #{clause}"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| SubjectSample.new(record)}
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

  # getter/setter methods for measures
  attr_accessor :measures

  # Computed, derived columns
  def id
    self.send('submittedid')
  end

  def name
    self.send('submittedid')
  end

end
