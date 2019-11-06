class DbsnpCoordinate

  # see: http://guides.rubyonrails.org/active_model_basics.html
  include ActiveModel::Model

  def self.table
    search_config = Rails.configuration.x.query['db6']
    @@table = "`#{search_config['project_id']}.#{search_config['tables']['dbsnp_coordinates']}`"
  end

  def self.primary_key
    @@primary_key = "dbsnp"
  end

  def self.attrs
    Rails.configuration.x.query['dbsnp_coordinate_attrs'].flatten
  end

  def self.search(user, name = nil)
    sql = "select `#{attrs.join('`, `')}` from #{table} where #{primary_key} like '#{name}%' order by #{primary_key} limit 10"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| DbsnpCoordinate.new(record)}
  end

  def self.find(user, id)
    sql = "select `#{attrs.join('`, `')}` from #{table} where #{primary_key} = '#{id}'"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| DbsnpCoordinate.new(record)}.first
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

end
