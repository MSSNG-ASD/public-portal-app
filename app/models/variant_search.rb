# VariantSearch
class VariantSearch < Search

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
      if search.present?
        BigQuery.new(user.credentials).exec_query(onebox_sql).map {|record| AnnotatedVariant.new(record)}
      else
        BigQuery.new(user.credentials).exec_query(sql).map {|record| Variant.new(record)}
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

  # {subject_id => {annotation_id => genotype}}
  def parental_genotypes
    @parental_genotypes ||= begin

      # Dataset ID
      database = Rails.configuration.x.query['dataset_id']
      # passing_variants
      variants_table = Rails.configuration.x.query['variants']

      # collect parental subject_id(s) from variants
      # [sample_id, ...]
      parental_subject_ids = variants.map {|v| [v.motherid, v.fatherid]}.flatten.uniq
      call_set_names = "'" + parental_subject_ids.sort.uniq.join("','") + "'"

      # http://thirtysixthspan.com/posts/hash-tricks-in-ruby

      # index variants by chromosome
      # {chromosome => [annotation_id, ...], ...}
      variant_annotation_ids = Hash.new { |hash, key| hash[key] = [] }
      variants.each do |variant|
        variant_annotation_ids[variant.reference_name] << variant.annotation_id
      end

      # initialize SQL clauses
      clauses = []

      # FIXME In DB6, we will use the table with built-in partition. The following parts will be affected:
      #       - variant_annotation_ids.keys.each (construct query to each partition)
      #       - union_clause (join all partitions)

      # add clause for each chromosome
      variant_annotation_ids.keys.each do |chromosome|

        annotation_ids = "'" + variant_annotation_ids[chromosome].sort.uniq.join("','") + "'"

        variant_select_clause = <<EOL
variants_#{chromosome} AS (
SELECT
CONCAT(reference_name,'-', CAST(start AS STRING),'-', CAST(`end` AS STRING),'-', reference_bases,'-', alternate_bases) AS id,
ARRAY(
SELECT AS STRUCT
call_set_name,
REGEXP_REPLACE((SELECT STRING_AGG(CAST(gt AS STRING)) from UNNEST(genotype) gt), r'1,0', '0,1') AS genotype
FROM UNNEST(call)
WHERE
call_set_name IN (#{call_set_names})) AS call
FROM
`#{database}.#{variants_table}_#{chromosome}` v, v.alternate_bases AS alternate_bases
WHERE
CONCAT(reference_name,'-', CAST(start AS STRING),'-', CAST(`end` AS STRING),'-', reference_bases,'-', alternate_bases) in (#{annotation_ids})
AND EXISTS (
SELECT
1
FROM UNNEST(call)
WHERE
call_set_name IN (#{call_set_names}))
)
EOL
        clauses << variant_select_clause
      end # variant_annotation_ids.keys.each

      union_clause = "  union_all AS (\n" + variant_annotation_ids.keys.map {|chr| "    SELECT * FROM variants_#{chr}\n" }.join("    UNION ALL\n") + "  )\n"
      clauses << union_clause

      clauses_sql = clauses.map {|c| c.chomp}.join(",\n")
      sql  = <<EOL
#standardSQL
WITH
#{clauses_sql},
parental_genotypes AS (
SELECT
union_all.* EXCEPT(call),
call.*
FROM
union_all, UNNEST(union_all.call) AS call
)
SELECT
parental_genotypes.id as annotation_id,
parental_genotypes.call_set_name as subject_id,
parental_genotypes.genotype
FROM
parental_genotypes
EOL

      # http://thirtysixthspan.com/posts/hash-tricks-in-ruby
      parental_genotypes = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
      BigQuery.new(user.credentials).exec_query(sql).each do |parental_genotype|
        parental_genotypes[parental_genotype[:subject_id]][parental_genotype[:annotation_id]] = parental_genotype[:genotype]
      end
      parental_genotypes
    end # begin
  end # parental_genotypes

  # [subject_id, ...]
  def sequenced_subjects
    @sequenced_subjects ||= begin
      sequenced_subjects = []
      # Dataset ID
      database = Rails.configuration.x.query['dataset_id']
      # sequenced_samples
      sequenced_table = Rails.configuration.x.query['sequenced_samples']
      sql = "SELECT call_call_set_name FROM `#{database}.#{sequenced_table}`"
      BigQuery.new(user.credentials).exec_query(sql).each do |subject|
        sequenced_subjects << subject[:call_call_set_name]
      end
      sequenced_subjects
    end
  end

  # {sample_id => {annotation_id => maternal_genotype:paternal_genotype:variant_genotype}
  def inheritance
    @inheritance ||= begin
      # http://thirtysixthspan.com/posts/hash-tricks-in-ruby
      inheritance = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }
      variants.each do |variant|
        if sequenced_subjects.include?(variant.motherid)
          if parental_genotypes.has_key?(variant.motherid)
            maternal_genotype = parental_genotypes[variant.motherid][variant.annotation_id]
          else
            maternal_genotype = '0,0'
          end
        else
          maternal_genotype = '-1,-1'
        end
        if sequenced_subjects.include?(variant.fatherid)
          if parental_genotypes.has_key?(variant.fatherid)
            paternal_genotype = parental_genotypes[variant.fatherid][variant.annotation_id]
          else
            paternal_genotype = '0,0'
          end
        else
          paternal_genotype = '-1,-1'
        end
        variant_genotype = variant_genotypes[variant.sample_id][variant.annotation_id]
        inheritance[variant.sample_id][variant.annotation_id] = [maternal_genotype, paternal_genotype, variant_genotype].join(":")
      end
      inheritance
    end
  end

  def onebox_sql
    # limit the portal, but not spreadsheet downloads
    limit_clause = limited ? "LIMIT 501" : ""

    # search
    self.variant = search if search.present? && search.match(/^(?i)(chr)*(\d+|M|X|Y)-(\d+)-(\d+)(-([ACGT]+)-([ACGT]+))*$/).present?

    # variant
    # assumes matching /(?i)(chr)*(\d+|M|X|Y)-(\d+)-(\d+)(-([ACGT]+)-([ACGT]+))*/
    if variant.present?
      if variant.split('-').count.eql?(5)
        variant_clause = "annotation_id = '#{variant.gsub(/^chr/i, '')}'"
      else
        (v_chromosome, v_start, v_end) = variant.gsub(/^chr/i, "").split('-')
        variant_clause = "reference_name = '#{v_chromosome}'"
        variant_clause << " AND start >= #{v_start.to_i}"
        variant_clause << " AND `end` <= #{v_end.to_i}"
      end
    # genomic location
    elsif chromosome.present? && start_position.present? && end_position.present?
      variant_clause = "reference_name = '#{chromosome}'"
      if !reference_allele.present? && !alternate_allele.present?
        variant_clause << " AND start >= #{start_position.to_i}"
        variant_clause << " AND `end` <= #{end_position.to_i}"
      else
        variant_clause << " AND start = #{start_position.to_i}"
        variant_clause << " AND `end` = #{end_position.to_i}"
      end
      variant_clause << " AND start = #{start_position.to_i}"
      variant_clause << reference_allele.present? ? " AND reference_bases = '#{reference_allele}'" : ""
      variant_clause << alternate_allele.present? ? " AND alternate_bases = '#{alternate_allele}'" : ""
    # bed_file
    elsif bed_file_regions.present?
      regions_clauses = []
      bed_file_regions.each do |region|
        regions_clauses << "(reference_name = '#{region[0]}' AND start >= #{region[1]} AND `end` <= region[2])"
      end
      regions_clause = regions_clauses.join(' OR ')
      regions_clause = !regions_clause.blank? ? "(#{regions_clause})" : ""
    # genes
    elsif gene_ids.present?
      gene_ids_clause = gene_ids.present? ? "entrez_id IN ('#{gene_ids.join('\', \'')}')" : ""
    # dbsnp
    elsif dbsnp.present?
      dbsnp_clause = dbsnp.present? ? "dbsnp = '#{dbsnp}'" : ""
    end

    # symbols
    symbols_clause = symbols.present? ? "gene_symbol IN ('#{symbols.join('\', \'')}')" : ""
    # frequency
    frequency_clause = frequency.present? ? "freq_max #{frequency_operator} #{frequency.to_f}" : ""
    # effect and impact
    effect_impact_clause = bitwise_effect_impact > 0 ? "effect_impact > 0 AND (effect_impact & #{bitwise_effect_impact.to_i} > 0)" : ""
    # # affection
    affection_clause = affection.eql?("affected") ? "affection = '2'" : ""
    # gender
    gender_clause = gender.present? ? "sex = '#{gender}'" : ""
    # denovo
    de_novo_clause = denovo.eql?("1") ? "de_novo IS true" : ""
    # call_filter
    call_filter_clause = passing.present? ? "call_filter = 'PASS'" : ""
    # dna_source
    dna_source_clause = dna_source.present? ? "dnasource = '#{dna_source}'" : ""
    # platform
    platform_clause = platform.present? ? "platform = '#{platform}'" : ""
    # samples
    samples_clause = submitted_ids.present? ? "sample_id IN ('#{submitted_ids.join('\', \'')}')" : ""
    # subjects
    subjects_clause = index_ids.present? ? "subject_id IN ('#{index_ids.join('\', \'')}')" : ""
    # paths
    c_path_clause = paths.present? && paths.include?('c_path') ? "(Clinvar_SIG LIKE '%pathogenic%' AND NOT Clinvar_SIG LIKE '%non-pathogenic%')" : ""
    paths_clauses = [c_path_clause].reject {|c| c.blank?}.join(' OR ')
    paths_clause = paths_clauses.empty? ? "" : "(#{paths_clauses})"
    # zygosity
    if zygosity.present?
      genotype_clause = zygosity.eql?("homo/hemizygous") ? "genotype = '1,1'" : "genotype != '1,1'"
    else
      genotype_clause = ""
    end
    # refseq_ids within one-box search
    if refseq_ids.present? && refseq_ids.keys.present?
      refseq_id_genes = []
      refseq_ids.keys.each do |symbol|
        refseq_id_changes = ["refseq_id LIKE '%#{symbol}%'"]
        refseq_id_changes << refseq_ids[symbol].map {|r| "refseq_id LIKE '%#{r}%'"}
        refseq_id_genes << refseq_id_changes.join(" AND ")
      end
      refseq_ids_clause = "(" + refseq_id_genes.join(") OR (") + ")"
    else
      refseq_ids_clause = ""
    end

    clauses_sql = [variant_clause, regions_clause, gene_ids_clause, dbsnp_clause, symbols_clause,
      frequency_clause, effect_impact_clause, affection_clause, gender_clause,
      de_novo_clause, call_filter_clause, dna_source_clause, platform_clause, samples_clause,
      subjects_clause, paths_clause, genotype_clause, refseq_ids_clause].reject {|c| c.blank?}.join(' AND ')
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

  def sql

    if search.present?
      return onebox_sql
    end

    # configured database and table names
    database = Rails.configuration.x.query['dataset_id']
    variants_table = Rails.configuration.x.query['variants']
    annotations_table = Rails.configuration.x.query['annotations']
    subject_sample_table = Rails.configuration.x.query['subject_samples']
    subject_table = Rails.configuration.x.query['subjects']
    de_novos_table = Rails.configuration.x.query['de_novo_variants']
    sangers_table = Rails.configuration.x.query['sanger_variants']
    measures_table = Rails.configuration.x.query['subject_measures']

    # limit the portal, but not spreadsheet downloads
    limit_clause = limited ? "LIMIT 501" : ""

    # genomic interval
    reference_clause = f_chromosome.present? ? "reference_name = '#{f_chromosome}'" : ""
    reference_allele_clause = f_reference_allele.present? ? "reference_bases = '#{f_reference_allele}'" : ""
    alternate_allele_clause = f_alternate_allele.present? ? "alternate_bases = '#{f_alternate_allele}'" : ""
    if !f_reference_allele.present? && !f_alternate_allele.present?
      start_clause = f_start_position.present? ? "start >= #{f_start_position}" : ""
      end_clause = f_end_position.present? ? "`end` <= #{f_end_position}" : ""
    else
      start_clause = f_start_position.present? ? "start = #{f_start_position}" : ""
      end_clause = f_end_position.present? ? "`end` = #{f_end_position}" : ""
    end

    # genes
    gene_ids_clause = gene_ids.present? ? "entrez_id IN (#{gene_ids.join(",")})" : ""

    # dbSNP
    dbsnp_clause = dbsnp.present? ? "dbsnp = '#{dbsnp}'" : ""

    # samples or subjects
    call_set_name_clause = (submitted_ids.present? || index_ids.present?) && call_set_names.present? ? "\n    WHERE\n      call_set_name IN (#{call_set_names})" : ""
    call_set_name_select_clause = (submitted_ids.present? || index_ids.present?) && call_set_names.present? ? "\n  AND EXISTS (\n    SELECT\n      1\n    FROM UNNEST(call)\n#{call_set_name_clause})" : ""

    # frequency
    frequency_clause = frequency.present? ? "freq_max #{frequency_operator} #{frequency}" : ""

    # zygosity
    if zygosity.present?
      genotype_clause = zygosity.eql?("homo/hemizygous") ? "genotype = '1,1'" : "genotype != '1,1'"
    else
      genotype_clause = ""
    end

    # effect and/or damage
    significance_clause = (bitwise_effect_impact > 0) ? "effect_impact > 0\n  AND (effect_impact & #{bitwise_effect_impact} > 0)" : ""

    # pathogenicity
    c_path_clause = paths.present? && paths.include?('c_path') ? "(Clinvar_SIG LIKE '%pathogenic%' AND NOT Clinvar_SIG LIKE '%non-pathogenic%')" : ""
    paths_clauses = [c_path_clause].reject {|c| c.blank?}.join(' OR ')
    paths_clause = paths_clauses.empty? ? "" : "(#{paths_clauses})"

    # affection
    if affection.present?
      affection_clause = affection.eql?("affected") ? "subject.affection = '2'" : "subject.affection = '1'"
    else
      affection_clause = ""
    end

    # dna_source
    dna_source_clause = dna_source.present? ? "subject_sample.dnasource = '#{dna_source}'" : ""

    # platform
    platform_clause = platform.present? ? "subject_sample.platform = '#{platform}'" : ""

    # gender
    gender_clause = gender.present? ? "subject.sex = '#{gender}'" : ""

    # de_novo
    de_novo_clause = denovo.eql?("1") ? "de_novo IS true" : ""

    # refseq_ids within one-box search
    if refseq_ids.present? && refseq_ids.keys.present?
      refseq_id_genes = []
      refseq_ids.keys.each do |symbol|
        refseq_id_changes = ["refseq_id LIKE '%#{symbol}%'"]
        refseq_id_changes << refseq_ids[symbol].map {|r| "refseq_id LIKE '%#{r}%'"}
        refseq_id_genes << refseq_id_changes.join(" AND ")
      end
      refseq_ids_clause = "(" + refseq_id_genes.join(") OR (") + ")"
    else
      refseq_ids_clause = ""
    end

    # accumulate where clause(s) for the annotation table(s)
    annotation_clauses = [paths_clause, frequency_clause, significance_clause, gene_ids_clause, refseq_ids_clause, dbsnp_clause].reject {|c| c.blank?}
    annotation_where_clause = annotation_clauses.empty? ? "" : "WHERE\n    #{annotation_clauses.join("\n    AND ")}"

    # accumulate where clause(s) for the subject and subject_samples table(s)
    subject_samples_clauses = [affection_clause, dna_source_clause, platform_clause, gender_clause].reject {|c| c.blank?}
    subject_samples_where_clause = subject_samples_clauses.empty? ? "" : "WHERE\n    #{subject_samples_clauses.join("\n    AND ")}"

    # acumulate where clause(s) for the joined results
    result_clauses = [genotype_clause, de_novo_clause].reject {|c| c.blank?}
    result_where_clause = result_clauses.empty? ? "" : "WHERE\n    #{result_clauses.join("\n    AND ")}"

    clauses = []

    # [[reference_name, start, end], ...] from genomic interval, genes, dbSNP, bed file
    # loop once for each reference_name (csome or shard)
    regions.each_with_index do |r, ix|
      # make sure these are right
      start_clause = "start >= #{r[1].to_i}"
      end_clause = "`end` <= #{r[2].to_i}"
      # accumulate where clause(s) for the variants table(s)
      variant_clauses = [reference_clause, reference_allele_clause, start_clause, end_clause, alternate_allele_clause].reject {|c| c.blank?}
      variant_where_clause = variant_clauses.empty? ? "" : "AND #{variant_clauses.join("\n    AND ")}"
      annotation_select_clause = <<EOL
  annotations_#{ix} AS (
  SELECT
    id
  FROM `#{database}.#{annotations_table}_#{r[0]}`
  #{annotation_where_clause})
EOL

      clauses << annotation_select_clause

      variant_select_clause = <<EOL
  variants_#{ix} AS (
  SELECT
    CONCAT(reference_name,'-', CAST(start AS STRING),'-', CAST(`end` AS STRING),'-', reference_bases,'-', alternate_bases) AS id,
    reference_name,
    start,
    `end`,
    reference_bases,
    alternate_bases,
    ARRAY(
      SELECT AS STRUCT
        call_set_name,
        call_set_id,
        DP,
        GQ,
        phaseset,
        REGEXP_REPLACE((SELECT STRING_AGG(CAST(gt AS STRING)) from UNNEST(genotype) gt), r'1,0', '0,1') AS genotype,
        (SELECT STRING_AGG(CAST(ad AS STRING)) from UNNEST(AD) ad) AS AD,
        (SELECT STRING_AGG(CAST(gl AS STRING)) from UNNEST(genotype_likelihood) gl) AS genotype_likelihood,
        (SELECT STRING_AGG(CAST(ft AS STRING)) from UNNEST(FILTER) ft) AS filter
      FROM UNNEST(call)#{call_set_name_clause}) AS call
  FROM
    `#{database}.#{variants_table}_#{r[0]}` v, v.alternate_bases AS alternate_bases
  WHERE
    CONCAT(reference_name,'-', CAST(start AS STRING),'-', CAST(`end` AS STRING),'-', reference_bases,'-', alternate_bases) in (SELECT id FROM annotations_#{ix})
    #{variant_where_clause}#{call_set_name_select_clause})
EOL

      clauses << variant_select_clause

      join_clause = <<EOL
  annotated_variants_#{ix} AS (
    SELECT
      annotations.id,
      gene_symbol,
      entrez_id,
      refseq_id,
      typeseq,
      freq_max,
      A1000g_freq_max,
      NHLBI_freq_max,
      ExAC_freq_max,
      cg_freq_max,
      gnomAD_exome_freq_max,
      gnomAD_genome_freq_max,
      mssng_freq_max,
      effect_impact,
      typeseq_priority,
      effect_priority,
      dbsnp,
      Clinvar_SIG,
      CGD_disease,
      CGD_inheritance,
      omim_phenotype,
      variants.reference_name,
      variants.start,
      variants.`end`,
      variants.reference_bases,
      variants.alternate_bases,
      ARRAY(
          SELECT AS STRUCT
            call_set_name,
            call_set_id,
            DP,
            GQ,
            phaseset,
            genotype,
            AD,
            genotype_likelihood,
            filter
          FROM UNNEST(call)) AS call
    FROM
      `#{database}.#{annotations_table}_#{r[0]}` annotations
    JOIN
      variants_#{ix} AS variants
    USING
      (id))
EOL
      clauses << join_clause
    end

      union_clause = "  union_all AS (\n" + regions.each_with_index.map {|r, ix| "    SELECT * FROM annotated_variants_#{ix}\n" }.join("    UNION ALL\n") + "  )\n"
      clauses << union_clause

      de_novo_clause = <<EOL
de_novos AS (
  SELECT
    id,
    submittedid,
    true AS de_novo
  FROM
    `#{database}.#{de_novos_table}` variants_de_novo
)
EOL
      clauses << de_novo_clause

      sanger_clause = <<EOL
sangers AS (
  SELECT
    id,
    submittedid,
    sanger_validated,
    sanger_inheritance
  FROM
    `#{database}.#{sangers_table}` variants_sanger
)
EOL
      clauses << sanger_clause

      measures_clause = <<EOL
measures AS (
  SELECT
    indexid,
    true AS phenotyped
  FROM
    `#{database}.#{measures_table}` measures GROUP BY INDEXID, phenotyped
)
EOL
      clauses << measures_clause

      annotated_variants_clause = <<EOL
annotated_variants AS (
  SELECT
    union_all.* EXCEPT(call),
    call.*
  FROM
  union_all, UNNEST(union_all.call) AS call
)
EOL
      clauses << annotated_variants_clause

      subject_samples_clause = <<EOL
subject_samples AS (
  SELECT
    subject.indexid,
    subject.motherid,
    subject.fatherid,
    subject.affection,
    subject.sex,
    subject.familyid,
    subject.familytype,
    subject_sample.submittedid,
    subject_sample.dnasource,
    subject_sample.platform
  FROM
    `#{database}.#{subject_sample_table}` subject_sample
  JOIN
    `#{database}.#{subject_table}` subject
  USING
    (indexid)
  #{subject_samples_where_clause}
)
EOL
      clauses << subject_samples_clause

      clauses_sql = clauses.map {|c| c.chomp}.join(",\n")

    sql  = <<EOL
#standardSQL
WITH
#{clauses_sql},
results AS (
SELECT
  annotated_variants.id as annotation_id,
  subject_samples.submittedid as sample_id,
  subject_samples.indexid as subject_id,
  annotated_variants.gene_symbol,
  annotated_variants.entrez_id,
  annotated_variants.refseq_id,
  annotated_variants.genotype,
  annotated_variants.genotype_likelihood,
  subject_samples.sex,
  subject_samples.fatherid,
  subject_samples.motherid,
  subject_samples.affection,
  subject_samples.familyid,
  subject_samples.familytype,
  annotated_variants.freq_max,
  annotated_variants.a1000g_freq_max,
  annotated_variants.nhlbi_freq_max,
  annotated_variants.exac_freq_max,
  annotated_variants.cg_freq_max,
  annotated_variants.gnomad_exome_freq_max,
  annotated_variants.gnomad_genome_freq_max,
  annotated_variants.mssng_freq_max,
  annotated_variants.effect_impact,
  annotated_variants.typeseq_priority,
  annotated_variants.effect_priority,
  annotated_variants.dbsnp,
  annotated_variants.clinvar_sig,
  annotated_variants.cgd_disease,
  annotated_variants.cgd_inheritance,
  annotated_variants.omim_phenotype,
  annotated_variants.ad,
  annotated_variants.call_set_id as call_call_set_id,
  annotated_variants.filter as call_filter,
  annotated_variants.DP as call_dp,
  annotated_variants.GQ as call_gq,
  annotated_variants.phaseset as call_phaseset,
  subject_samples.dnasource,
  subject_samples.platform,
  sangers.sanger_validated,
  sangers.sanger_inheritance,
  de_novos.de_novo,
  measures.phenotyped,
  annotated_variants.reference_name,
  annotated_variants.start,
  annotated_variants.end,
  annotated_variants.reference_bases,
  annotated_variants.alternate_bases
FROM
  annotated_variants
JOIN
  subject_samples
ON
  annotated_variants.call_set_name = subject_samples.submittedid
LEFT JOIN
  de_novos
ON
  annotated_variants.id = de_novos.id
  AND annotated_variants.call_set_name = de_novos.submittedid
LEFT JOIN
  sangers
ON
  annotated_variants.id = sangers.id
  AND annotated_variants.call_set_name = sangers.submittedid
LEFT JOIN
  measures
ON
  subject_samples.indexid = measures.indexid
#{result_where_clause})
SELECT
  ( SELECT COUNT(1) from results ) as results_count,
  *
FROM
  results
ORDER BY reference_name, start, `end`
#{limit_clause}
EOL

  end

  private

  def region_present
    # unless ((effects.present? && effects.reject(&:blank?).present?) || (impacts.present? && impacts.reject(&:blank?).present?)) && (submitted_ids.present? || index_ids.present?)
      unless (variant.present? || gene_ids.present? || uploaded_bed_file.present?  || uploaded_gene_file.present? || uploaded_plink_file.present? || dbsnp.present? || (chromosome.present? && start_position.present? && end_position.present?))
        errors.add(:variant, I18n.t('activerecord.errors.models.variant_search.attributes.variant.region_present'))
        errors.add(:chromosome, I18n.t('activerecord.errors.models.variant_search.attributes.chromosome.region_present'))
        errors.add(:stringy_gene_ids, I18n.t('activerecord.errors.models.variant_search.attributes.gene_id.region_present'))
        errors.add(:uploaded_bed_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_bed_file.region_present'))
        errors.add(:uploaded_gene_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_gene_file.region_present'))
        errors.add(:uploaded_plink_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_plink_file.region_present'))
        errors.add(:dbsnp, I18n.t('activerecord.errors.models.variant_search.attributes.dbsnp.region_present'))
      end
    # end
  end

  def xor_region
    # unless ((effects.present? && effects.reject(&:blank?).present?) || (impacts.present? && impacts.reject(&:blank?).present?)) && (submitted_ids.present? || index_ids.present?)
      unless (!variant.blank? ^ !gene_ids.blank? ^ !uploaded_bed_file.blank? ^ !uploaded_gene_file.blank? ^ !uploaded_plink_file.blank? ^ !dbsnp.blank? ^ !(chromosome.blank? && start_position.blank? && end_position.blank?))
        errors.add(:variant, I18n.t('activerecord.errors.models.variant_search.attributes.variant.xor_region'))
        errors.add(:chromosome, I18n.t('activerecord.errors.models.variant_search.attributes.chromosome.xor_region'))
        errors.add(:stringy_gene_ids, I18n.t('activerecord.errors.models.variant_search.attributes.gene_id.xor_region'))
        errors.add(:uploaded_bed_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_bed_file.xor_region'))
        errors.add(:uploaded_gene_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_gene_file.xor_region'))
        errors.add(:uploaded_plink_file, I18n.t('activerecord.errors.models.variant_search.attributes.uploaded_plink_file.xor_region'))
        errors.add(:dbsnp, I18n.t('activerecord.errors.models.variant_search.attributes.dbsnp.xor_region'))
      end
    # end
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
      self.name = name || search.parameterize[0...8]
      self.impacts = ["high"]
      self.affection = "affected"
      if search.match(/^(?i)(chr)*(\d+|M|X|Y)-(\d+)-(\d+)(-([ACGT]+)-([ACGT]+))*$/).present?
        self.variant = variant || search
      elsif search.match(/^rs\d+$/).present?
        self.dbsnp = dbsnp || search
      else
        self.submitted_ids = SubjectSample.where(user, "submittedid in ('#{search.split(';').join('\', \'')}')").map {|s| s.submittedid};
        self.refseq_ids = {}
        symbols = []
        search.split(";").each do |gene|
          changes = gene.split(":")
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

end
