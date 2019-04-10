# Trio Search
class Trio < Search

  BIT_EFFECTS = ActiveSupport::OrderedHash[[
    [:frameshift,   0],
    [:stop_gain,    3],
    [:splice_site,  6],
    [:lof,          9],
    [:missense,     12],
    [:other,        15],
    [:reg_dec_exon, 18],
    [:reg_inc_exon, 21],
    [:utr,          24],
    [:non_coding,   27]
  ]]

  IMPACTS = ActiveSupport::OrderedHash[[
    [:high,   'High'],
    [:medium, 'Medium'],
    [:low,    'Low']
  ]]

  BIT_IMPACTS = ActiveSupport::OrderedHash[[
    [:high,   0],
    [:medium, 1],
    [:low,    2]
  ]]

  attr_accessor :variants
  attr_accessor :uploaded_gene_file
  attr_accessor :limited

  validate :subject_present
  validates :impacts, presence: true
  validates_numericality_of :frequency, allow_nil: false, greater_than_or_equal_to: 0

  before_validation :set_search, if: ->(trio){trio.new_record?}
  before_save :set_values, if: ->(trio){trio.valid?}

  store :parameters, accessors: [
:search,
:index_ids,
:gene_ids,
:passing,
:frequency,
:frequency_operator,
:zygosity,
:effects,
:impacts,
:paths,
]

  stringy :gene_ids, :index_ids

  def genes
    @genes ||= gene_ids.present? ? Gene.where(gene_id: gene_ids).map {|gene| {id: gene.id, name: gene.name}} : []
  end

  def subject
    @subject ||= begin
      subject = Subject.find(user, index_ids.first) if index_ids.present?
      @subject = {id: subject.id, name: subject.name} if subject
    end
  end

  def symbols
    @symbols ||= genes.map {|g| g[:name]}
  end

  def sql
    # limit the portal, but not spreadsheet downloads
    limit_clause = limited ? "LIMIT 501" : ""

    # frequency
    frequency_clause = frequency.present? ? "freq_max #{frequency_operator} #{frequency.to_f}" : ""
    # effect and impact
    effect_impact_clause = bitwise_effect_impact > 0 ? "effect_impact > 0 AND (effect_impact & #{bitwise_effect_impact.to_i} > 0)" : ""
    # zygosity
    if zygosity.present?
      genotype_clause = zygosity.eql?("homo/hemizygous") ? "genotype = '1,1'" : "genotype != '1,1'"
    else
      genotype_clause = ""
    end
    # path
    path_clause = paths.present? && paths.include?('c_path') ? "clinvar_sig not like 'non-pathogenic' AND clinvar_sig like 'pathogenic'" : ""
    # call_filter
    call_filter_clause = passing.present? ? "call_filter = 'PASS'" : ""
    # subjects
    subjects_clause = index_ids.present? ? "subject_id IN ('#{index_ids.join('\', \'')}')" : ""

    clauses_sql = [frequency_clause, effect_impact_clause, genotype_clause, path_clause, call_filter_clause, subjects_clause].reject {|c| c.blank?}.join(' AND ')
    sql  = <<EOL
WITH results AS (
    SELECT `#{AnnotatedVariant.attrs.join('`, `')}`
      FROM #{AnnotatedVariant.table}
      WHERE #{clauses_sql}
    )
SELECT ( SELECT COUNT(1) from results ) as results_count, *
  FROM results
  ORDER BY reference_name, start, `end`
  #{limit_clause}
EOL
    sql
  end

  def bitwise_effect_impact
    if @bitwise_effect_impact.nil?
      if effects.present? && effects.reject(&:blank?).present? && impacts.present? && impacts.reject(&:blank?).present?
        @bitwise_effect_impact = effects.reject(&:blank?).map {|e| BIT_EFFECTS[e.to_sym]}.map {|eb| impacts.reject(&:blank?).map {|i| BIT_IMPACTS[i.to_sym]}.map {|ib| eb + ib} }.flatten.map {|b| 2**b}.reduce(:+)
      elsif effects.present? && effects.reject(&:blank?).present?
        @bitwise_effect_impact = effects.reject(&:blank?).map {|e| BIT_EFFECTS[e.to_sym]}.map {|eb| BIT_IMPACTS.values.map {|ib| eb + ib} }.flatten.map {|b| 2**b}.reduce(:+)
      elsif impacts.present? && impacts.reject(&:blank?).present?
        @bitwise_effect_impact = impacts.reject(&:blank?).map {|i| BIT_IMPACTS[i.to_sym]}.map {|ib| BIT_EFFECTS.values.map {|eb| eb + ib} }.flatten.map {|b| 2**b}.reduce(:+)
      else
        @bitwise_effect_impact = 0
      end
    end
    @bitwise_effect_impact
  end

  def variants
    @variants ||= BigQuery.new(user.credentials).exec_query(sql).map {|record| AnnotatedVariant.new(record)}
  end

  private

  def valid_gene_file
    if !uploaded_gene_file.blank? && symbols_from_gene_file.empty?
      errors.add(:uploaded_gene_file, I18n.t('activerecord.errors.models.trio.attributes.uploaded_gene_file.valid_gene_file'))
    end
  end

  def symbols_from_gene_file
    s = []
    unless uploaded_gene_file.blank?
      File.open( uploaded_gene_file.path ) do |file|
        file.each_line do |line|
          line.chomp!
          next if line.start_with?('#')
          s << line.split("\t").first
        end
      end
    end
    s
  end

  def set_search
    if search.present?
      self.name = name || search.parameterize[0...8]
      s = Subject.find(user, search)
      self.index_ids = s ? [s.indexid] : []
      self.impacts = ["high", "medium"]
    end
  end

  def set_values
    self.gene_ids = Gene.where(symbol: symbols_from_gene_file).map {|g| g.gene_id} unless symbols_from_gene_file.empty?
  end

  def subject_present
    if index_ids.blank?
      errors.add(:stringy_index_ids, I18n.t('activerecord.errors.models.trio.attributes.index_ids.blank'))
    end
  end

end
