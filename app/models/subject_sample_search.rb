# SubjectSampleSearch
class SubjectSampleSearch < Search

  store :parameters, accessors: [
:search,
:submitted_ids,
:index_ids,
:dna_source,
:platform,
  ]

  stringy :index_ids, :submitted_ids

  validate :subject_or_sample
  before_validation :set_search, if: ->(subject_sample_search){subject_sample_search.new_record?}

# @return [ActiveRecord_Relation] the result of the search.
  def subjects
    @subjects ||= begin
      if index_ids.present?
        sql = "select #{Subject.attrs.join(', ')} from #{Subject.table} where #{Subject.primary_key} IN ('#{index_ids.join('\', \'')}')"
        records = BigQuery.new(user.credentials).exec_query(sql).map {|record| Subject.new(record)}
        @subjects = records.map {|subject| {id: subject.id, name: subject.name}}
      else
        @subjects = []
      end
    end
  end

  def samples
    @samples ||= begin
      if submitted_ids.present?
        sql = "select #{SubjectSample.attrs.join(', ')} from #{SubjectSample.table} where #{SubjectSample.primary_key} IN ('#{submitted_ids.join('\', \'')}')"
        records = BigQuery.new(user.credentials).exec_query(sql).map {|record| SubjectSample.new(record)}
        @samples = records.map {|sample| {id: sample.id, name: sample.name}}
      else
        @samples = []
      end
    end
  end

  def sql
    dna_source_clause = dna_source.present? ? "dnasource = '#{dna_source}'" : ""
    platform_clause = platform.present? ? "platform = '#{platform}'" : ""
    submitted_ids_clause = submitted_ids.present? ? "submittedid IN ('#{submitted_ids.join('\', \'')}')" : ""
    index_ids_clause = index_ids.present? ? "indexid IN ('#{index_ids.join('\', \'')}')" : ""
    clauses_sql = [dna_source_clause, platform_clause, submitted_ids_clause, index_ids_clause].reject {|c| c.blank?}.join(' AND ')
    "select #{SubjectSample.attrs.join(', ')} from #{SubjectSample.table} where #{clauses_sql}"
  end

  def results
    @results ||= BigQuery.new(user.credentials).exec_query(sql).map do |record|
      subject = SubjectSample.new(record)
      subject.sequence = SequencedSample.where(user, "call_call_set_name = '#{subject.submittedid}'").first
      subject
    end
  end

private

  def set_search
    if search.present?
      self.name = name || search
      both = []
      search.split(";").each do |sample_query|
        sample = SubjectSample.find(user, sample_query)
        if sample
          both << sample.submittedid
        end
      end
      self.submitted_ids = both.empty? ? [] : both.flatten.uniq.compact
    end

  end

  def subject_or_sample
    if submitted_ids.blank? && index_ids.blank?
      errors.add(:stringy_submitted_ids, I18n.t('activerecord.errors.models.subject_sample_search.attributes.submitted_ids.subject_or_sample'))
      errors.add(:stringy_index_ids, I18n.t('activerecord.errors.models.subject_sample_search.attributes.index_ids.subject_or_sample'))
    end
  end

end
