class Subject

  # see: http://guides.rubyonrails.org/active_model_basics.html
  include ActiveModel::Model

  def self.table
    search_config = Rails.configuration.x.query['db6']
    @@table = "`#{search_config['project_id']}.#{search_config['tables']['subjects']}`"
  end

  def self.primary_key
    @@primary_key = Rails.configuration.x.query['subject_attrs'].first
  end

  def self.attrs
    Rails.configuration.x.query['subject_attrs']
  end

  def self.search(user, name = nil)
    sql = "select #{attrs.join(', ')} from #{table} where #{primary_key} like '#{name}%' order by #{primary_key} limit 10"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| Subject.new(record)}
  end

  def self.find(user, id)
    sql = "select #{attrs.join(', ')} from #{table} where #{primary_key} = '#{id}'"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| Subject.new(record)}.first
  end

  def self.where(user, clause)
    sql = "select #{attrs.join(', ')} from #{table} where #{clause}"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| Subject.new(record)}
  end

  # getter/setter methods for result columns
  attr_accessor *attrs

  # Computed, derived columns
  def id
    self.send('indexid')
  end

  def name
    self.send('indexid')
  end

  def plink_family
    self.familyid || '0'
  end

  def plink_father
    self.fatherid || '0'
  end

  def plink_mother
    self.motherid || '0'
  end

  def plink_gender
    case self.sex
    when 'M'
      '1'
    when 'F'
      '2'
    else
      '0'
    end
  end

end
