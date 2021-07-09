# Trio Search
class Trio < AbstractAnnotatedVariantSearch

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
    puts "trio gene_ids: #{gene_ids}"
    puts "trio.genes: #{@genes}"
    @genes
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
    parameters = analyze_search_criteria

    generate_sql(parameters[:source_list], parameters[:criteria])
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
    @variants ||= begin
      primary_job.all.map do |record|
        AnnotatedVariant.new(record)
      end
    end
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
      self.name = name || search.parameterize[0...250]
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

  def do_full_search
    false
  end

  def make_preflight_query
    nil
  end

  def analyze_search_criteria
    source_config = Rails.configuration.x.query['db6']

    # Configure database and table names
    data_project_id = source_config["project_id"]
    base_table_map = source_config['tables']
    extended_complete_genomics_table_map = source_config['extended_tables']['complete_genomics']

    annotations_table = "#{data_project_id}.#{base_table_map['annotations']}"
    extended_complete_genomics_annotated_table = "#{data_project_id}.#{extended_complete_genomics_table_map['annotations']}"

    # Prepare some general filters
    filtered_by_c_path = paths.present? && paths.include?('c_path')

    # This is to control the scope of the search.
    source_list = [
        AnnotationSource.new('base', annotations_table),
        AnnotationSource.new('cg', extended_complete_genomics_annotated_table),
    ]

    # Prepare the filter on zygosity/genotype.
    filtered_by_genotype = zygosity.present? and !zygosity.empty?
    genotype_assertion_method = zygosity.eql?("homo/hemizygous") ? "=" : "!="  # the else case is for "heterozygous".

    # Prepare the filter on sample IDs.
    #
    # Please note that if the query needs to filter on subject ID, we will
    # translate subject IDs into corresponding sample IDs.
    filtered_by_sample_ids = false
    expected_sample_ids = []

    if index_ids.present?
      expected_sample_ids = expected_sample_ids + get_sample_ids_by_subject_ids(index_ids)
    end

    if expected_sample_ids.size > 0
      filtered_by_sample_ids = true
    end

    # On how the criteria are used, see AbstractAnnotatedVariantSearch::Criterion.
    criteria = [
        Criterion.new(
            statement: '"PASS" IN UNNEST(c.filter)',
            entity: Entity::VARIANT_CALL,
            ),
        Criterion.new(
            field: "name",
            present: filtered_by_sample_ids,
            value: expected_sample_ids.uniq.sort,
            entity: Entity::VARIANT_CALL,
            ),
        Criterion.new(
            field: "entrez_id",
            present: gene_ids.present?,
            type: :Integer,
            value: gene_ids,
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "freq_max",
            present: frequency.present?,
            type: :Float,
            assertion: frequency_operator,
            value: frequency,
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            present: bitwise_effect_impact > 0,
            statement: "effect_impact > 0 AND (effect_impact & #{bitwise_effect_impact} > 0)",
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "genotype[OFFSET(0)]",
            present: filtered_by_genotype,
            type: :Integer,
            assertion: genotype_assertion_method,
            value: 1,
            entity: Entity::VARIANT_CALL,
            ),
        Criterion.new(
            field: "genotype[OFFSET(1)]",
            present: filtered_by_genotype,
            type: :Integer,
            assertion: genotype_assertion_method,
            value: 1,
            entity: Entity::VARIANT_CALL,
            ),
        Criterion.new(
            field: "Clinvar_SIG",
            present: filtered_by_c_path,
            assertion: 'LIKE',
            value: '%pathogenic%',
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "Clinvar_SIG",
            present: filtered_by_c_path,
            assertion: 'LIKE',
            value: '%non-pathogenic%',
            entity: Entity::ANNOTATION,
            ),
    ]

    {
        criteria: criteria,
        source_list: source_list,
    }
  end

end
