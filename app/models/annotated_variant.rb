class AnnotatedVariant < Variant

  def self.table
    @@table = "`#{Rails.configuration.x.query['dataset_id']}.#{Rails.configuration.x.query['annotated_variants']}`"
  end

  def self.primary_key
    @@primary_key = "id"
  end

  def self.attrs
    Rails.configuration.x.query['annotated_variant_attrs'].flatten
  end

  def self.search(user, name = nil)
    sql = "select #{attrs.join(', ')} from #{table} where #{primary_key} like '#{name}%' order by #{primary_key} limit 10"
    BigQuery.new(user.credentials).exec_query(sql).map {|record| AnnotatedVariant.new(record)}
  end

  def self.find(user, id)
    sql = "select #{attrs.join(', ')} from #{table} where #{primary_key} = '#{id}'"
    BigQuery.new(user.credentials).exec_query(sql).map {|record| AnnotatedVariant.new(record)}.first
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

end
