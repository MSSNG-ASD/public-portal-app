class Annotation < Variant

  def self.table
    @@table = "`#{Rails.configuration.x.query['dataset_id']}.#{Rails.configuration.x.query['annotations']}`"
  end

  def self.primary_key
    @@primary_key = "id"
  end

  def self.attrs
    Rails.configuration.x.query['annotation_attrs'].flatten
  end

  def self.find(user, id)
    sql = "select * from #{table} where #{primary_key} = '#{id}'"
    BigQuery.new(user.credentials).exec_query(sql).map {|record| Annotation.new(record)}.first
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

end
