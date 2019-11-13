require 'json'

class AbstractAnnotatedVariantSearch < Search
  self.abstract_class = true

  class Field
    attr_reader :name, :alias, :ordinal_position

    def initialize(name, as: nil, ordinal_position: nil, fallback_placeholder: nil)
      @name = name
      @alias = as
      @ordinal_position = ordinal_position
    end
  end

  class Entity
    ANNOTATED_VARIANT = 'annotated_variant'
    ANNOTATION = 'annotation'
    VARIANT = 'variant'
    VARIANT_CALL = 'variant_call'
  end

  class AnnotationSource
    attr_reader :table_id, :select_scope

    def initialize(select_scope, table_id)
      @table_id = table_id
      @select_scope = select_scope
    end
  end

  class Criterion
    attr_reader :field, :present, :type, :value, :statement, :assertion, :entity

    ##
    # Criterion
    #
    # Each condition will contain:
    # - "field" - field name
    # - "present" - flag to use the criterion (optional, default to true),
    # - "type" - asserting value type (optional, default to String),
    # - "value" - asserting value,
    # - "assertion" - comparison method, and
    # - "statement" - the statement to use if present.
    #
    # "assertion" is optional where by default, it is "=" or "IN" corresponding
    # to the value.
    #
    # When "statement" is given, the query will be used exactly as it is. Beside
    # +present+, everything else will be ignored when the object is converted
    # to a string.

    def initialize(field: nil, present: nil, type: nil, value: nil, statement: nil, assertion: nil, entity: nil)
      @field = field
      @present = present.nil? ? true : present
      @type = type
      @value = value
      @statement = statement
      @assertion = assertion
      @entity = entity
    end

    def to_s
      known_reserved_keywoards = ['end']

      if !@present
        return nil
      end

      if !@statement.nil?
        return @statement
      end

      value = @value
      assertion_method = nil

      # Figure out how to do the comparison.
      if !@assertion.nil?
        assertion_method = @assertion
      else
        if [TrueClass, FalseClass, NilClass].include? value.class
          assertion_method = 'IS'
        elsif value.class == Array
          assertion_method = 'IN'
        elsif [Float, Integer, String].include? value.class
          assertion_method = '='
        end
      end

      # Prepare the value.
      if value.class == Array
        value = "(#{(value.map{ | item | JSON.generate(@type ? method(@type).call(item) : item) }).join(', ')})"
      elsif [Float, Integer, String].include? value.class
        value = JSON.generate(@type ? method(@type).call(value) : value)
      end

      # Prepare the field name
      field_name = @field

      if known_reserved_keywoards.include? field_name
        field_name = '`' + field_name + '`'
      end

      "#{field_name} #{assertion_method} #{value}"
    end
  end

  def primary_job
    @primary_job ||= begin
      # Make a pre-flight query to check if there is any result.
      #
      # This is designed to avoid an expensive table scan on all sorts of feature variants. The query result should only
      # return one row with the column "found" (boolean).
      #
      # If preflight_job is null (or nil for Ruby folks), it implies that the pre-flight check is not required.
      preflight_job = make_preflight_query

      if !preflight_job.nil? and !preflight_job.all.first[:found]
        return BigQuery::NoResult.new(preflight_job)
      end

      # Make an actual query.
      job = bigquery.exec_query(sql)

      save_job_stat(user.id, job.id, job)

      job
    end
  end

  def generate_sql(annotation_source_list, criteria)
    criteria << Criterion.new(
       statement: 'v.annotation_id IN (SELECT annotation_id FROM annotations)',
       entity: Entity::VARIANT,
    )

    source_config = Rails.configuration.x.query['db6']

    # Configure database and table names
    data_project_id = source_config["project_id"]
    base_table_map = source_config['tables']

    portal_variants_table = "#{data_project_id}.#{base_table_map[do_full_search ? 'portal_variants' : 'portal_rare_variants']}"
    measures_table = "#{data_project_id}.#{base_table_map['subject_measures']}"
    subjects_table = "#{data_project_id}.#{base_table_map['subjects']}"
    subject_samples_table = "#{data_project_id}.#{base_table_map['subject_samples']}"
    variants_sanger_table = "#{data_project_id}.#{base_table_map['sanger_variants']}"
    variants_de_novo_table = "#{data_project_id}.#{base_table_map['de_novo_variants']}"

    # Set the limit for web UI
    limit_clause = ''

    # NOTE: In Ruby, "cls_1 <= cls_2" means "cls_1 is either a subclass of or the same class as cls_2".
    if limited.class <= TrueClass
      limit_clause = 'LIMIT 501'
    elsif limited.class <= FalseClass
      limit_clause = ''  # This is to ensure that FALSE means no limit.
    elsif limited.class <= Fixnum
      limit_clause = "LIMIT #{limited}"
    end


    # Selected/grouped fields
    # NOTE: We are not selecting parental genotypes intentionally here and relies on a separate call to parental_genotypes.
    fields = [
      Field.new('source'),
      Field.new('annotation_id'),
      Field.new('reference_name',  ordinal_position: 1),
      Field.new('start',           ordinal_position: 2),
      Field.new('`end`',           ordinal_position: 3),
      Field.new('reference_bases', ordinal_position: 4),
      Field.new('alternate_bases', ordinal_position: 5),
      # TODO: Need to handle annotated_alternate_bases outside.
      Field.new('ARRAY_TO_STRING(associated_alternate_bases, ",")', as: 'associated_alternate_bases'),
      Field.new('gene_symbol'),
      Field.new('entrez_id'),
      Field.new('refseq_id'),
      Field.new('freq_max'),
      Field.new('a1000g_freq_max'),
      Field.new('exac_freq_max'),
      Field.new('cg_freq_max'),
      Field.new('gnomAD_exome_freq_max'),
      Field.new('gnomAD_genome_freq_max'),
      Field.new('max_int_freq'),
      Field.new('effect_impact'),
      Field.new('dbsnp'),
      Field.new('Clinvar_SIG'),
      Field.new('CGD_disease'),
      Field.new('CGD_inheritance'),
      Field.new('omim_phenotype'),
      Field.new("ARRAY_TO_STRING(ARRAY(SELECT CONCAT(CAST(i AS STRING)) FROM UNNEST(filter) AS i), ',')", as: 'call_filter'),
      Field.new('name', as: 'sample_id'),  # Subject's Sample ID
      Field.new('aggregated_ad', as: 'ad'),
      Field.new('dp', as: 'call_dp'),
      Field.new('gq', as: 'call_gq'),
      Field.new('effect_priority'),
      Field.new('typeseq_priority'),
      Field.new('aggregated_genotypes', as: 'genotype'),
      Field.new('subject_id'),
      Field.new('DNASOURCE'),
      Field.new('PLATFORM'),
      Field.new('sex'),
      Field.new('FAMILYID'),
      Field.new('FAMILYTYPE'),
      Field.new('father_SUBMITTEDID', as: 'fatherid'),  # Paternal Sample ID
      Field.new('mother_SUBMITTEDID', as: 'motherid'),  # Maternal Sample ID
      Field.new('AFFECTION'),
      Field.new('de_novo'),
      Field.new('phenotyped'),
      Field.new('aggregated_ehq'),
      Field.new('aggregated_hq'),
      Field.new('gnomad_oe_lof_upper'),
      Field.new('gnomad_oe_mis_upper'),
      Field.new('gnomad_pli'),
      Field.new('gnomad_prec'),
      Field.new('min_int_ref'),
      Field.new('clinvar_sig_simple'),
      Field.new('Sanger_validated'),
      Field.new('Sanger_inheritance'),
    ]

    selected_fields = fields.map{ | f | f.alias.nil? ? "#{f.name.downcase}" : "#{f.name.downcase} AS #{f.alias}" }
    grouped_fields  = fields.map{ | f | f.alias.nil? ? f.name.downcase : f.alias }
    ordering_fields = fields
      .select{ | f | !f.ordinal_position.nil? }
      .sort{ | x, y | x.ordinal_position <=> y.ordinal_position }
      .map{ | f | f.alias.nil? ? f.name.downcase : f.alias }

    annotation_queries = annotation_source_list.map do | annotation_source |
      generate_annotation_sql(
          annotation_source.select_scope,
          annotation_source.table_id,
          [
              'id AS annotation_id',
              'reference_name',
              'start',
              '`end`',
              'reference_bases',
              'alternate_bases',
              'gene_symbol',
              'entrez_id',
              'refseq_id',
              'freq_max',
              'a1000g_freq_max',
              'exac_freq_max',
              'cg_freq_max',
              'gnomAD_exome_freq_max',
              'gnomAD_genome_freq_max',
              'effect_impact',
              'dbsnp',
              'Clinvar_SIG',
              'CGD_disease',
              'CGD_inheritance',
              'omim_phenotype',
              'max_int_freq',
              'effect_priority',
              'typeseq_priority',
              'gnomAD_oe_lof_upper',
              'gnomAD_oe_mis_upper',
              'gnomAD_pLI',
              'gnomAD_pRec',
              annotation_source.select_scope.eql?('cg') ? "NULL AS min_int_ref" : 'min_int_ref',
              'clinvar_sig_simple'
          ],
          generate_sql_where_clause(criteria, [Entity::ANNOTATION])
      )
    end

    unionized_annotation_queries = annotation_queries.join("\n    ) UNION ALL (\n      ")

    variant_subquery_where_clause = generate_sql_where_clause(criteria, [Entity::VARIANT, Entity::VARIANT_CALL, Entity::ANNOTATED_VARIANT])

    <<EOL
WITH
  annotations AS (
    (
      #{unionized_annotation_queries}
    )
  ),
  annotated_variants AS (
    SELECT
      -- [From Annotation]
      a.*,
      -- [From Variant]
      v.* EXCEPT(
        annotation_id,
        alternate_bases,
        filter,  # relies on call.filter instead
        call,
        no_call,
        hom_ref_call
      ),
      v.alternate_bases AS associated_alternate_bases,
      c.* EXCEPT(ad, genotype),
      -- [From Sample]
      ss.SUBMITTEDID AS sample_id,
      ss.INDEXID AS subject_id,
      ss.DNASOURCE,
      ss.PLATFORM,
      -- [From Subject]
      s.SEX AS sex,
      s.FAMILYID,
      s.FAMILYTYPE,
      ss.father_SUBMITTEDID,
      ss.mother_SUBMITTEDID,
      s.AFFECTION,
      -- [From other additional sources]
      (m.indexid IS NOT NULL) AS phenotyped,
      (v_de_novo.SUBMITTEDID IS NOT NULL) AS de_novo,
      v_sanger.Sanger_validated,
      v_sanger.Sanger_inheritance
    FROM
      `#{portal_variants_table}` v,
      UNNEST(v.call) AS c
    INNER JOIN `#{subject_samples_table}` AS ss
      ON (c.name = ss.SUBMITTEDID)
    INNER JOIN `#{subjects_table}` AS s
      USING (INDEXID)
    INNER JOIN annotations a
      USING (annotation_id, select_scope)
    LEFT JOIN `#{measures_table}` AS m
      USING (INDEXID)
    LEFT JOIN `#{variants_sanger_table}` AS v_sanger
      ON (
          (
            CONCAT('chr', v_sanger.id) = a.annotation_id
            OR v_sanger.id = a.annotation_id
          )
          AND v_sanger.SUBMITTEDID = c.name
      )
    LEFT JOIN `#{variants_de_novo_table}` AS v_de_novo
      ON (
          (
            CONCAT('chr', v_de_novo.id) = a.annotation_id
            OR v_de_novo.id = a.annotation_id
          )
          AND v_de_novo.SUBMITTEDID = c.name
      )
    #{variant_subquery_where_clause}
  ),
  final_aggregation AS (
    SELECT #{selected_fields.join(', ')}
    FROM annotated_variants
    GROUP BY #{grouped_fields.join(', ')}
    ORDER BY #{ordering_fields.join(', ')}
  )
SELECT
  (SELECT COUNT(1) FROM final_aggregation) AS results_count,
  *
FROM final_aggregation
#{limit_clause}

EOL
  end

  def generate_annotation_sql(select_scope, table_id, selected_fields, where_clause)
    sql = <<EOL
      SELECT
        "#{table_id}" AS source,
        "#{select_scope}" AS select_scope,
        #{selected_fields.join(", ")}
      FROM `#{table_id}`
      #{where_clause}
EOL

    sql.strip
  end

  def generate_sql_where_clause(criteria, expected_entities)
    where_clause = criteria
      .select{ |criterion| expected_entities.include? criterion.entity }
      .map{ |criterion| criterion.to_s }
      .reject{ |clause| clause.nil? }
      .join(' AND ')
      .strip

    if where_clause.empty?
      return ''
    end

    "WHERE #{where_clause}"
  end

  def get_sample_ids_by_subject_ids(subject_ids)
    source_config = Rails.configuration.x.query['db6']

    # Configure database and table names
    data_project_id = source_config["project_id"]
    base_table_map = source_config['tables']

    query = "SELECT submittedid AS sample_id FROM `#{data_project_id}.#{base_table_map['subject_samples']}` WHERE indexid IN ('#{ subject_ids.uniq.sort.join("', '") }')"

    job = bigquery.exec_query(query)

    save_job_stat(user.id, job.id, job)

    job.all
      .map{ | row | row[:sample_id] }
      .select{ | sample_id | !sample_id.nil? }
      .uniq
      .sort
  end

  # {sample_id => {annotation_id => maternal_genotype:paternal_genotype:variant_genotype}
  def inheritance
    @inheritance ||= begin
      # http://thirtysixthspan.com/posts/hash-tricks-in-ruby
      inheritance = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }

      variants.each do |variant|
        variant_annotation_id = variant.annotation_id
        variant_sample_id     = variant.sample_id

        target_genotype = parental_genotypes[variant_annotation_id][variant_sample_id]

        if !target_genotype.nil?
          aggregated_parental_genotypes = target_genotype[:parent]

          # Rely on the additional information in each call if available.
          if !aggregated_parental_genotypes.nil?
            maternal_genotype = aggregated_parental_genotypes[:maternal]
            paternal_genotype = aggregated_parental_genotypes[:paternal]
          end
        end

        # raise RuntimeError, "variant.motherid = #{variant.motherid}, variant.fatherid = #{variant.fatherid}, variant_annotation_id = #{variant_annotation_id}"

        # Fall back to the original implementation
        if maternal_genotype.nil? or maternal_genotype.empty?
          maternal_genotype = retrieve_genotype_from_aggregated_table(variant.motherid, variant_annotation_id)
        end

        if paternal_genotype.nil? or paternal_genotype.empty?
          paternal_genotype = retrieve_genotype_from_aggregated_table(variant.fatherid, variant_annotation_id)
        end

        variant_genotype = variant.genotype

        inheritance[variant.sample_id][variant_annotation_id] = [
          maternal_genotype,
          paternal_genotype,
          variant_genotype
        ].join(":")
      end
      inheritance
    end
  end

  def parental_genotypes
    @parental_genotypes ||= retrieve_parental_genotypes
  end

  def retrieve_parental_genotypes
    source_config = Rails.configuration.x.query['db6']
    variant_table = "#{source_config['project_id']}.#{source_config['tables']['portal_variants']}"

    selected_sample_ids = variants.map {|v| [v.sample_id, v.motherid, v.fatherid]}.flatten.uniq.sort
    selected_annotation_ids = variants.map {|v| v.annotation_id}.uniq.sort

    # http://thirtysixthspan.com/posts/hash-tricks-in-ruby
    genotypes = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }

    if variants.empty?
      return genotypes
    end

    target_sample_ids = "'" + selected_sample_ids.join("','") + "'"
    target_annotation_ids = "'#{selected_annotation_ids.sort.uniq.join("', '")}'"

    sql = <<EOL
#standardSQL
WITH
  variables AS (
    SELECT
      [#{target_sample_ids}] AS target_sample_ids,
      [#{target_annotation_ids}] AS target_annotation_ids
  )
(
  SELECT
    v.select_scope AS select_scope,
    v.annotation_id,
    ARRAY(SELECT hc FROM unnest(v.hom_ref_call) hc where hc in unnest(target_sample_ids)) as hom_ref_call,
    ARRAY(
      SELECT AS STRUCT
        c.name AS sample_id,
        c.genotype,
        '' AS maternal_genotype, -- only for CG
        '' AS paternal_genotype -- appears on row for only for CG
      FROM UNNEST(v.call) c
      INNER JOIN variables ON (true)
      WHERE c.name IN UNNEST(target_sample_ids)
    )
      AS calls
  FROM `#{variant_table}` v
  INNER JOIN variables ON (true)
  WHERE
    v.annotation_id IN UNNEST(target_annotation_ids)
    AND v.select_scope = 'base'
)
UNION ALL
(
  SELECT
    v.select_scope AS select_scope,
    v.annotation_id,
    [] AS hom_ref_call,
    ARRAY(
      SELECT AS STRUCT
        c.name AS sample_id,
        c.genotype,
        REPLACE(REGEXP_REPLACE(c.maternal_genotype, r'.*;(.+)_(.+)', "\\\\1,\\\\2"), '.', '-1') AS maternal_genotype, -- only non-null for CG
        REPLACE(REGEXP_REPLACE(c.paternal_genotype, r'.*;(.+)_(.+)', "\\\\1,\\\\2"), '.', '-1') AS paternal_genotype -- only non-null for CG
      FROM UNNEST(v.call) c
      INNER JOIN variables ON (true)
      WHERE c.name IN UNNEST(target_sample_ids)
    )
      AS calls
  FROM `#{variant_table}` v
  INNER JOIN variables ON (true)
  WHERE
    v.annotation_id IN UNNEST(target_annotation_ids)
    AND v.select_scope = 'cg'
)
EOL

    job = bigquery.exec_query(sql)

    save_job_stat(user.id, job.id, job)

    job.all.each do | variant |
      variant[:calls].each do | call |
        genotypes[variant[:annotation_id]][call[:sample_id]] = {
          subject: call[:genotype],
          parent: variant[:select_scope] == "cg" ? { maternal: call[:maternal_genotype], paternal: call[:paternal_genotype] } : nil,
        }
      end

      variant[:hom_ref_call].each do | sample_id |
        genotypes[variant[:annotation_id]][sample_id] = {
            subject: "0,0",
            parent: nil,
        }
      end
    end

    genotypes
  end

  def retrieve_genotype_from_aggregated_table(sample_id, annotation_id)
    found_genotype = '-1,-1'

    if parental_genotypes.has_key?(annotation_id) and parental_genotypes[annotation_id].has_key?(sample_id)
      found_genotype = parental_genotypes[annotation_id][sample_id][:subject]
    end

    if found_genotype.class == Array
      return found_genotype.join(',')
    end

    found_genotype
  end

  def bigquery
    BigQuery.new(user.credentials)
  end

  def do_full_search
    raise RuntimeError, "Not yet implemented"
  end

  def make_preflight_query
    # This preflight query is designed to avoid the possibility of scanning the whole table if there is no hit on the annotation table.
    raise RuntimeError, "Not yet implemented"
  end

  def analyze_search_criteria
    raise RuntimeError, "Not yet implemented"
  end

  private

  def have_all_columns
    @have_all_columns ||= begin
      cache_key = 'AbstractAnnotatedVariantSearch.have_all_columns'

      previous_check = Rails.cache.read cache_key

      if !previous_check.nil?
        return previous_check
      end

      parameters = analyze_search_criteria

      annotation_queries = parameters[:source_list].map do | annotation_source |
        generate_annotation_sql(
            annotation_source.select_scope,
            annotation_source.table_id,
            [
                'min_int_ref',
            ],
            'LIMIT 1'
        )
      end

      unionized_annotation_queries = annotation_queries.join(") UNION ALL (")

      begin
        bigquery.exec_query(unionized_annotation_queries)
        Rails.cache.write cache_key, true
        return true
      rescue BigQuery::QueryError => e
        Rails.cache.write cache_key, false
        return false
      end
    end
  end
end