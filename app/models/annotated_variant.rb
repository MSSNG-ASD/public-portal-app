# DEPRECATED
class AnnotatedVariant < Variant

  def self.table
    search_config = Rails.configuration.x.query['db6']
    @@table = "`#{search_config['project_id']}.#{search_config['tables']['annotated_variants']}`"
  end

  def self.primary_key
    @@primary_key = "annotation_id"
  end

  def self.attrs
    Rails.configuration.x.query['annotated_variant_attrs'].flatten
  end

  # Copied from AnnotatedVariant.generate_sql
  def self.direct_fields
    attrs.select { | field | field.match(/(.+)\s+AS\s+(.+)$/i).nil? }
  end

  # Copied from AnnotatedVariant.generate_sql
  def self.aliased_fields
    fields = attrs.reject { | field | field.match(/\s+AS\s+/i).nil? }

    fields.map do | field |
      field.sub(/(.+)\s+AS\s+(.+)$/i, '\1 AS `\2`')
    end
  end

  # Copied from AnnotatedVariant.generate_sql
  def self.object_attrs
    Rails.configuration.x.query['annotated_variant_attrs'].map do | field |
      if field.match(/(.+)\s+AS\s+(.+)$/i).nil?
        field
      else
        field.sub(/(.+)\s+AS\s+(.+)$/i, '\2')
      end
    end
  end

  def self.search(user, name = nil)
    sql = "SELECT `#{direct_fields.join('`, `')}` FROM #{table} WHERE #{primary_key} LIKE '#{name}%' ORDER BY #{primary_key} LIMIT 10"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| AnnotatedVariant.new(record)}
  end

  def self.find(user, id)
    sql = "SELECT `#{direct_fields.join('`, `')}` FROM #{table} WHERE #{primary_key} = '#{id}'"
    BigQuery.new(user.credentials).exec_query(sql).all.map {|record| AnnotatedVariant.new(record)}.first
  end

  def self.generate_sql(where: nil, group: false, backward_compatible_mode: false)
    sql = "SELECT `#{direct_fields.join('`, `')}` #{(backward_compatible_mode and aliased_fields.length > 0) ? (', ' + aliased_fields.join(', ')) : ''} FROM #{table}"

    if !(where.nil? or where.empty?)
      sql = "#{sql} WHERE #{where}"
    end

    if group
      sql = "#{sql} GROUP BY `#{object_attrs.join('`, `')}`"
    end

    sql
  end

  # getter/setter methods for result columns
  attr_accessor *object_attrs

end
