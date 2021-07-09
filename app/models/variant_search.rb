require 'json'

# VariantSearch
class VariantSearch < AbstractAnnotatedVariantSearch

  EFFECTS = ActiveSupport::OrderedHash[[
    [:frameshift,   'Frameshift'],
    [:stop_gain,    'Stop Gain'],
    [:splice_site,  'Splice Site'],
    # [:lof,          'LOF'],
    [:missense,     'Missense'],
    [:other,        'Other'],
    [:reg_dec_exon, 'Predicted Splicing'],
    # [:reg_inc_exon, 'Splicing Reg Pos'],
    [:utr,          'UTR'],
    [:non_coding,   'Non-coding RNA gene']
  ]]

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

  PATHS = ActiveSupport::OrderedHash[[
    [:c_path, 'ClinVar Pathogenic'],
    # [:c_prob, 'ClinVar Probable'],
    # [:h_path, 'HGMD Pathogenic'],
    # [:h_prob, 'HGMD Probable']
  ]]

  attr_accessor :uploaded_sample_file
  attr_accessor :uploaded_subject_file
  attr_accessor :uploaded_bed_file
  attr_accessor :uploaded_gene_file
  attr_accessor :uploaded_plink_file
  attr_accessor :limited

  validates_numericality_of :frequency, allow_nil: false, greater_than_or_equal_to: 0
  validates_numericality_of :upstream_bases, allow_nil: true, only_integer: true, greater_than_or_equal_to: 0
  validates_numericality_of :start_position, :end_position, allow_nil: true, only_integer: true, greater_than_or_equal_to: 0,
    if: ->(variant_search){variant_search.start_position.present? && variant_search.end_position.present?}
  validates :variant, format: {with: /(?i)(chr)*(\d+|M|X|Y)-(\d+)-(\d+)(-([ACGT]+)-([ACGT]+))*/, message: "Must match format: \d+|M|X|Y-\d+-\d+(-[ACGT]+-[ACGT]+)*"},
    if: ->(variant_search){variant_search.variant.present?}
  validates :dbsnp, format: {with: /\Ars\d+\z/, message: "Must match format: rs\d+"},
    if: ->(variant_search){variant_search.dbsnp.present?}
  validates :reference_allele, format: {with: /([ACGT]+)/, message: "Must match format: [ACGT]+"},
    if: ->(variant_search){variant_search.reference_allele.present?}
  validates :alternate_allele, format: {with: /([ACGT]+)/, message: "Must match format: [ACGT]+"},
    if: ->(variant_search){variant_search.alternate_allele.present?}

  validate :region_present
  validate :xor_region
  validate :sample_xor_subject
  validate :valid_variant
  validate :valid_bed_file
  validate :valid_gene_file
  before_validation :set_search, if: ->(variant_search){variant_search.new_record?}
  before_save :set_values, if: ->(variant_search){variant_search.valid?}

  store :parameters, accessors: [
    :search,
    :variant,
    :chromosome,
    :start_position,
    :end_position,
    :reference_allele,
    :alternate_allele,
    :gene_ids,
    :symbols,
    :refseq_ids,
    :dbsnp,
    :upstream_bases,
    :submitted_ids,
    :index_ids,
    :dna_source,
    :platform,
    :gender,
    :affection,
    :role,
    :passing,
    :denovo,
    :frequency,
    :frequency_operator,
    :zygosity,
    :effects,
    :impacts,
    :paths,
    :f_chromosome,
    :f_start_position,
    :f_end_position,
    :f_reference_allele,
    :f_alternate_allele,
    :call_set_names,
    :bed_file_regions,
    :gene_file_symbols,
  ]

  # for select2 form elements, consider changing
  stringy :gene_ids, :index_ids, :submitted_ids

  def sql
    parameters = analyze_search_criteria

    generate_sql(parameters[:source_list], parameters[:criteria])
  end

  def map_location
    @map_location ||= "chr#{f_chromosome}:#{f_start_position}-#{f_end_position}"
  end

  def genes
    @genes ||= gene_ids.present? ? Gene.where(gene_id: gene_ids).map {|gene| {id: gene.id, name: gene.name}} : []
  end

  def subjects
    @subjects ||= begin
      if index_ids.present?
        sql = "select #{Subject.attrs.join(', ')} from #{Subject.table} where #{Subject.primary_key} IN ('#{index_ids.join('\', \'')}')"
        records = BigQuery.new(user.credentials).exec_query(sql).all.map {|record| Subject.new(record)}
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
        records = BigQuery.new(user.credentials).exec_query(sql).all.map {|record| SubjectSample.new(record)}
        @samples = records.map {|sample| {id: sample.id, name: sample.name}}
      else
        @samples = []
      end
    end
  end

  def gene_coordinates
    @gene_coordinates ||= gene_ids.present? ? GeneCoordinate.where(gene_id: gene_ids).map {|g| [g.reference_name, g.start, g.end]} : []
  end

  def gene_ids_from_symbols
    @gene_ids_from_symbols ||= symbols_from_gene_file.present? ? Gene.where(symbol: symbols_from_gene_file).pluck('gene_id') : []
  end

  def dbsnp_coordinates
    @dbsnp_coordinates ||= begin
      @dbsnp_coordinates = []
      @dbsnp_coordinates = DbsnpCoordinate.search(user, dbsnp).map {|g| [g.reference_name, g.start, g.end]} if dbsnp.present?
    end
  end

  def symbols
    @symbols ||= genes.map {|g| g[:name]}
  end

  def variants
    @variants ||= begin
      primary_job.all.map do |record|
        Variant.new(record)
      end
    end
  end

  # {sample_id => {annotation_id => genotype}}
  def variant_genotypes
    @variant_genotypes ||= begin
      # http://thirtysixthspan.com/posts/hash-tricks-in-ruby
      variant_genotypes = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
      variants.each do |variant|
        variant_genotypes[variant.sample_id][variant.annotation_id] = variant.genotype
      end
      variant_genotypes
    end
  end

  private

  def region_present
    unless (variant.present? || gene_ids.present? || uploaded_bed_file.present?  || uploaded_gene_file.present? || uploaded_plink_file.present? || dbsnp.present? || (chromosome.present? && start_position.present? && end_position.present?))
      errors.add(:variant, I18n.t('activerecord.errors.models.variant_search.attributes.variant.region_present'))
      errors.add(:chromosome, I18n.t('activerecord.errors.models.variant_search.attributes.chromosome.region_present'))
      errors.add(:stringy_gene_ids, I18n.t('activerecord.errors.models.variant_search.attributes.gene_id.region_present'))
      errors.add(:uploaded_bed_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_bed_file.region_present'))
      errors.add(:uploaded_gene_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_gene_file.region_present'))
      errors.add(:uploaded_plink_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_plink_file.region_present'))
      errors.add(:dbsnp, I18n.t('activerecord.errors.models.variant_search.attributes.dbsnp.region_present'))
    end
  end

  def xor_region
    unless (!variant.blank? ^ !gene_ids.blank? ^ !uploaded_bed_file.blank? ^ !uploaded_gene_file.blank? ^ !uploaded_plink_file.blank? ^ !dbsnp.blank? ^ !(chromosome.blank? && start_position.blank? && end_position.blank?))
      errors.add(:variant, I18n.t('activerecord.errors.models.variant_search.attributes.variant.xor_region'))
      errors.add(:chromosome, I18n.t('activerecord.errors.models.variant_search.attributes.chromosome.xor_region'))
      errors.add(:stringy_gene_ids, I18n.t('activerecord.errors.models.variant_search.attributes.gene_id.xor_region'))
      errors.add(:uploaded_bed_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_bed_file.xor_region'))
      errors.add(:uploaded_gene_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_gene_file.xor_region'))
      errors.add(:uploaded_plink_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_plink_file.xor_region'))
      errors.add(:dbsnp, I18n.t('activerecord.errors.models.variant_search.attributes.dbsnp.xor_region'))
    end
  end

  def sample_xor_subject
    if submitted_ids.present? || index_ids.present?
      unless submitted_ids.blank? ^ (dna_source.blank? && platform.blank? && gender.blank? && index_ids.blank?)
        errors.add(:stringy_submitted_ids, I18n.t('activerecord.errors.models.variant_search.attributes.submitted_ids.sample_xor_subject'))
        errors.add(:stringy_index_ids, I18n.t('activerecord.errors.models.variant_search.attributes.index_ids.sample_xor_subject'))
      end
    end
  end

  def valid_variant
    if variant.present?
      (chromosome, start_position, end_position, reference_allele, alternate_allele) = variant.split('-')
      start_position = start_position.to_i
      end_position = end_position.to_i
      unless (start_position <= end_position)
        errors.add(:variant, "start must be <= end")
      end
      unless ((end_position - start_position) <= 500)
        errors.add(:variant, "Range (end-start) must be <= 500")
      end
    end
  end

  def valid_gene
    if gene_ids.present? && !(submitted_ids.present? || index_ids.present?)
      errors.add(:stringy_submitted_ids, I18n.t('activerecord.errors.models.variant_search.attributes.submitted_ids.valid_gene'))
      errors.add(:stringy_index_ids, I18n.t('activerecord.errors.models.variant_search.attributes.index_ids.valid_gene'))
    end
  end

  def valid_bed_file
    if !uploaded_bed_file.blank? && regions_from_bed_file.empty?
      errors.add(:uploaded_bed_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_bed_file.valid_bed_file'))
    end
  end

  def valid_gene_file
    if !uploaded_gene_file.blank? && gene_ids_from_symbols.empty?
      errors.add(:uploaded_gene_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_gene_file.valid_gene_file'))
    end
  end

  def set_search
    if search.present?
      self.name = name || search[0...250]
      self.impacts = ["high"]
      self.affection = "affected"
      if search.match(/^(?i)(chr)*(\d+|M|X|Y)-(\d+)-(\d+)(-([ACGT]+)-([ACGT]+))*$/).present?
        self.variant = variant || search
      elsif search.match(/^rs\d+$/).present?
        self.dbsnp = dbsnp || search
      else
        self.submitted_ids = SubjectSample.where(user, "indexid in ('#{search.split(/\s*;\s*/).join('\', \'')}')").map {|s| s.submittedid};
        self.refseq_ids = {}
        symbols = []
        search.split(/\s*;\s*/).each do |gene|
          changes = gene.split(/\s*:\s*/)
          symbol = changes.shift
          symbols << symbol
          self.refseq_ids[symbol.upcase] = [] unless changes.empty?
          changes.each do |change|
            (kind, place) = change.split(".")
            next if kind.nil? || place.nil?
            if place.match(/^\d+$/)
              self.refseq_ids[symbol.upcase] << "#{kind.downcase}._#{place}_"
            else
              self.refseq_ids[symbol.upcase] << "#{kind.downcase}.#{place.upcase}"
            end
          end
        end
        self.gene_ids = Gene.where(symbol: symbols.map(&:upcase)).pluck(:gene_id).map(&:to_s)
      end
    end
  end

  def set_values
    (self.f_chromosome, self.f_start_position, self.f_end_position, self.f_reference_allele, self.f_alternate_allele) = variant.gsub(/^chr/i, "").split('-') if variant.present?
    self.f_chromosome = chromosome if chromosome.present?
    self.f_start_position = start_position if start_position.present?
    self.f_end_position = end_position if end_position.present?
    self.f_reference_allele = reference_allele if reference_allele.present?
    self.f_alternate_allele = alternate_allele if alternate_allele.present?
    self.dbsnp = dbsnp if dbsnp.present?
    self.bed_file_regions = regions_from_bed_file unless uploaded_bed_file.blank?
    self.submitted_ids = samples_from_sample_file unless uploaded_sample_file.blank?
    self.index_ids = subjects_from_subject_file unless uploaded_subject_file.blank?

    unless uploaded_gene_file.blank?
      unless symbols_from_gene_file.empty?
        if gene_ids_from_symbols.present?
          self.gene_ids = gene_ids_from_symbols
        end
      end
    end

    if submitted_ids.present? || index_ids.present?
      samples = SubjectSample.where(user, "submittedid in ('#{submitted_ids.join('\', \'')}')") if submitted_ids.present?
      samples = SubjectSample.where(user, "indexid in ('#{index_ids.join('\', \'')}')") if index_ids.present?
      if samples.present?
        subject_ids = samples.map {|s| s.indexid}.uniq.compact
        subjects = Subject.where(user, "indexid in ('#{subject_ids.join('\', \'')}')")
        family_ids = subjects.map {|s| s.familyid}.uniq.compact
        subjects = Subject.where(user, "familyid in ('#{family_ids.join('\', \'')}')")
        subject_ids = subjects.map {|s| s.indexid}.uniq.compact
        samples = SubjectSample.where(user, "indexid in ('#{subject_ids.join('\', \'')}')")
        sample_ids = samples.map {|s| s.submittedid}.uniq.compact
        self.call_set_names = "'" + sample_ids.join("','") + "'" unless sample_ids.empty?
      end
    end

  end

  def samples_from_sample_file
    @samples_from_sample_file ||= begin
      @samples_from_sample_file = []
      unless uploaded_sample_file.blank?
        File.open( uploaded_sample_file.path ) do |file|
          file.each_line do |line|
            line.chomp!
            next if line.start_with?('#')
            @samples_from_sample_file << line
          end
        end
      end
      @samples_from_sample_file
    end
  end

  def subjects_from_subject_file
    @subjects_from_subject_file ||= begin
      @subjects_from_subject_file = []
      unless uploaded_subject_file.blank?
        File.open( uploaded_subject_file.path ) do |file|
          file.each_line do |line|
            line.chomp!
            next if line.start_with?('#')
            @subjects_from_subject_file << line
          end
        end
      end
      @subjects_from_subject_file
    end
  end

  def regions_from_bed_file
    @regions_from_bed_file ||= begin
      @regions_from_bed_file = []
      unless uploaded_bed_file.blank?
        File.open( uploaded_bed_file.path ) do |file|
          file.each_line do |line|
            line.chomp!
            next if line.start_with?('#')
            next unless region = line.match(/^(?i)(chr)*(\d+|M|X|Y)\s+(\d+)\s+(\d+)/)
            @regions_from_bed_file << [region[2], region[3].to_i, region[4].to_i]
          end
        end
      end
      @regions_from_bed_file
    end
  end

  def symbols_from_gene_file
    @symbols_from_gene_file ||= begin
      @symbols_from_gene_file = []
      unless uploaded_gene_file.blank?
        File.open( uploaded_gene_file.path ) do |file|
          file.each_line do |line|
            line.chomp!
            next if line.start_with?('#')
            next unless region = line.match(/^[a-zA-Z0-9_.-]*/)
            @symbols_from_gene_file << line
          end
        end
      end
      @symbols_from_gene_file
    end
  end

  # format regions from various sources [[reference_name, start, end], ...]
  def regions
    @regions ||= begin
      if gene_ids.present?
        @regions = gene_coordinates
      elsif bed_file_regions.present?
        @regions = bed_file_regions
      elsif dbsnp.present?
        @regions = dbsnp_coordinates
      elsif f_chromosome.present? && f_start_position.present? && f_end_position.present?
        @regions = [[f_chromosome, f_start_position, f_end_position]]
      else
        @regions = []
      end
      @regions
    end
  end

  # packs effects and impacts into an integer
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

  def do_full_search
    !search.present?
  end

  def make_preflight_query
    # This preflight query is designed to avoid the possibility of scanning the whole table if there is no hit on the annotation table.
    @make_preflight_query ||= begin
      parameters = analyze_search_criteria

      annotation_queries = parameters[:source_list].map do | annotation_source |
        generate_annotation_sql(
            annotation_source.select_scope,
            annotation_source.table_id,
            [
                'id',
            ],
            generate_sql_where_clause(parameters[:criteria], [Entity::ANNOTATION])
        )
      end

      unionized_annotation_queries = annotation_queries.join(") UNION ALL (")

      sql = "SELECT EXISTS((#{unionized_annotation_queries})) AS found"

      job = bigquery.exec_query(sql)

      save_job_stat(user.id, job.id, job)

      job
    end
  end

  def analyze_search_criteria
    source_config = Rails.configuration.x.query['db6']

    # Configure database and table names
    data_project_id = source_config["project_id"]
    base_table_map = source_config['tables']
    extended_complete_genomics_table_map = source_config['extended_tables']['complete_genomics']

    annotations_table = "#{data_project_id}.#{base_table_map['annotations']}"
    extended_complete_genomics_annotated_table = "#{data_project_id}.#{extended_complete_genomics_table_map['annotations']}"

    # Pre-generate conditions
    do_lookup_only_passing_variants = !passing.present? || passing.eql?("1")

    # Prepare some general filters
    filtered_by_c_path = paths.present? && paths.include?('c_path')
    # filtered_by_refseq_ids = false

    # Prepare the filter on refseq_id
    refseq_id_conditions = nil

    if refseq_ids.present? && refseq_ids.keys.present?
      # filtered_by_refseq_ids = true
      or_conditions = []

      refseq_ids.keys.map do | symbol |
        or_conditions << (([symbol] + refseq_ids[symbol]).map{ | refseq_id | "refseq_id LIKE '%#{refseq_id}%'" }).join(' AND ')
      end

      refseq_id_conditions = "(#{or_conditions.join(') OR (')})"
    end

    # Check if this is an interval search
    is_genomic_interval_search = (!f_reference_allele.present? && !f_alternate_allele.present?)

    # This is to control the scope of the search.
    source_list = []
    source_illumina = AnnotationSource.new('base', annotations_table)
    source_complete_genomics = AnnotationSource.new('cg', extended_complete_genomics_annotated_table)
    if platform.present?
      if platform.start_with? 'Illumina'
        source_list << source_illumina
      elsif platform.eql? 'Complete Genomics'
        source_list << source_complete_genomics
      end
    else
      source_list << source_illumina
      source_list << source_complete_genomics
    end

    # Prepare the filter on zygosity/genotype.
    filtered_by_genotype = zygosity.present? and !zygosity.empty?
    genotype_assertion_method = zygosity.eql?("homo/hemizygous") ? "=" : "!="  # the else case is for "heterozygous".

    # Prepare the filter on sample IDs.
    #
    # Please note that if the query needs to filter on subject ID, we will
    # translate subject IDs into corresponding sample IDs.
    filtered_by_sample_ids = false
    expected_sample_ids = []

    if submitted_ids.present?
      expected_sample_ids = expected_sample_ids + submitted_ids
    end

    if index_ids.present?
      expected_sample_ids = expected_sample_ids + get_sample_ids_by_subject_ids(index_ids)
    end

    if expected_sample_ids.size > 0
      filtered_by_sample_ids = true
    end

    # On how the criteria are used, see AbstractAnnotatedVariantSearch::Criterion.
    criteria = [
        Criterion.new(
            present: do_lookup_only_passing_variants,
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
            # Chromosome
            field: "reference_name",
            present: f_chromosome.present?,
            value: (f_chromosome.present? and f_chromosome.start_with?('chr')) ? f_chromosome.try(:upcase) : "chr#{f_chromosome.try(:upcase)}",
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "reference_bases",
            present: f_reference_allele.present?,
            value: f_reference_allele.try(:upcase),
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "alternate_bases",
            present: f_alternate_allele.present?,
            value: f_alternate_allele.try(:upcase),
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "start",
            present: f_start_position.present?,
            type: :Integer,
            assertion: is_genomic_interval_search ? '>=' : '=',
            value: f_start_position,
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "`end`",
            present: f_end_position.present?,
            type: :Integer,
            assertion: is_genomic_interval_search ? '<=' : '=',
            value: f_end_position,
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "entrez_id",
            present: gene_ids.present?,
            type: :Integer,
            value: gene_ids,
            entity: Entity::ANNOTATION,
            ),
        Criterion.new(
            field: "dbsnp",
            present: dbsnp.present?,
            value: dbsnp,
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
            present: bitwise_effect_impact > 0,
            statement: "effect_impact > 0 AND (effect_impact & #{bitwise_effect_impact} > 0)",
            entity: Entity::ANNOTATION,
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
        Criterion.new(
            field: "affection",
            present: !affection.empty?,
            value: affection.eql?("affected") ? '2' : '1',
            entity: Entity::VARIANT_CALL,
            ),
        Criterion.new(
            field: "dnasource",
            present: dna_source.present?,
            value: dna_source,
            entity: Entity::VARIANT_CALL,
            ),
        Criterion.new(
            field: "ss.platform",
            present: platform.present?,
            value: platform,
            entity: Entity::VARIANT_CALL,
            ),
        Criterion.new(
            field: "sex",
            present: gender.present?,
            value: gender,
            entity: Entity::VARIANT_CALL,
            ),
        Criterion.new(
            present: denovo.eql?("1"),
            statement: 'v_de_novo.SUBMITTEDID IS NOT NULL',
            entity: Entity::ANNOTATED_VARIANT,
            ),
        Criterion.new(
            present: refseq_ids.present? && refseq_ids.keys.present?,
            statement: refseq_id_conditions,
            entity: Entity::ANNOTATION,
            ),
    ]

    {
        criteria: criteria,
        source_list: source_list,
    }
  end
end
