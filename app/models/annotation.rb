class Annotation < Variant

  def self.table
    search_config = Rails.configuration.x.query['db6']
    @@table = "#{search_config['project_id']}.#{search_config['tables']['annotations']}"  # DB6
  end

  def self.primary_key
    @@primary_key = "id"
  end

  def self.attrs
    Rails.configuration.x.query['annotation_attrs'].flatten
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
    Rails.configuration.x.query['annotation_attrs'].map do | field |
      if field.match(/(.+)\s+AS\s+(.+)$/i).nil?
        field
      else
        field.sub(/(.+)\s+AS\s+(.+)$/i, '\2')
      end
    end
  end

  def self.find(user, id, target_table: nil)
    actual_id = id

    if !actual_id.match? /^chr/
      actual_id = "chr#{actual_id}"  # Only for backward-compatible during the transition from DB5 to DB6
    end

    sql = generate_sql(
      target_table: target_table,
      where: "#{primary_key} = '#{actual_id}'",
      group: false,
      backward_compatible_mode: true
    )

    result = BigQuery.new(user.credentials).exec_query(sql).all.map {|record| Annotation.new(record)}.first
  end

  # Copied from AnnotatedVariant.generate_sql
  def self.generate_sql(target_table: nil, where: nil, group: false, backward_compatible_mode: false)
    sql = "SELECT `#{direct_fields.join('`, `')}` #{(backward_compatible_mode and aliased_fields.length > 0) ? (', ' + aliased_fields.join(', ')) : ''} FROM `#{target_table.nil? ? self.table : target_table}`"

    # raise RuntimeError, sql

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
