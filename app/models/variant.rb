class Variant

	# see: http://guides.rubyonrails.org/active_model_basics.html
  include ActiveModel::Model
  include AugmentedVariant

  def self.attrs
  	Rails.configuration.x.query['variant_attrs'].flatten
  end

  # getter/setter methods for result columns
	attr_accessor *attrs

	# example override(s)
  # def initialize(attributes={})
  #   super
  #   @sample_id ||= 'foo'
  #   @sample_id = @sample_id.to_s + 'foo'
  # end

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

  IMPACTS = ActiveSupport::OrderedHash[[
    [:high,   'High'],
    [:medium, 'Medium'],
    [:low,    'Low']
  ]]

  EFFECT_BITS = ActiveSupport::OrderedHash[[
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

  IMPACT_BITS = ActiveSupport::OrderedHash[[
    [:high,   0],
    [:medium, 1],
    [:low,    2]
  ]]

  # Computed, derived columns
  def effects_with_impacts
    effects_impacts = []
    bits = EFFECT_BITS.values.map {|eb| IMPACT_BITS.values.map {|ib| eb + ib} }.flatten
    values = EFFECT_BITS.keys.map {|ek| IMPACT_BITS.keys.map {|ik| "#{EFFECTS[ek]}-#{IMPACTS[ik]}"} }.flatten
    bits.each_index do |ix|
      if ((effect_impact.to_i & 2**bits[ix] > 0) && (values[ix] != "-High" && values[ix] != "-Medium" && values[ix] != "-Low"))
        effects_impacts.push(values[ix])
      end
    end
    effects_impacts.join(", ")
  end

  def letter_genotype
    allele0 = genotype.split(",")[0].eql?("0") ? reference_bases : alternate_bases
    allele1 = genotype.split(",")[1].eql?("0") ? reference_bases : alternate_bases
    [allele0, allele1].join(",")
  end

  def allele1
    letter_genotype.split(",").first
  end

  def allele2
    letter_genotype.split(",").last
  end

  def zygosity
    zygosity = (genotype.eql?("0,0") || genotype.eql?("1,1")) ? 'homo/hemizygous' : 'heterozygous'
  end

  def igv
    "igv"
  end

  def category(given_inheritance = nil)
    given_inheritance = given_inheritance || inheritance
    @category ||= begin
      @category = :inheritance_undetermined
      if de_novo
        @category = :de_novo
      elsif reference_name.eql?('X') && sex.eql?('M')
        if given_inheritance.match(/^0,1:\d:\d:1,1$/) or given_inheritance.match(/^1,1:\d:\d:1,1$/)
          @category = :inherited
        end
      else
        if ["0,0:0,1:0,1", # Paternal-het
          "0,0:1,1:0,1", # Paternal-hom
          "0,1:0,0:0,1", # Maternal-het
          "0,1:0,1:0,1", # Unresolved-het
          "0,1:0,1:1,1", # Maternal-het+Paternal-het
          "0,1:1,1:0,1", # Paternal-hom
          "0,1:1,1:1,1", # Maternal-het+Paternal-hom
          "1,1:0,0:0,1", # Maternal-hom
          "1,1:0,1:0,1", # Maternal-hom
          "1,1:0,1:1,1", # Maternal-hom+Paternal-het
          "1,1:1,1:1,1"].include?(given_inheritance) # Maternal-hom+Paternal-hom
          @category = :inherited
        end
      end
      @category
    end
  end

  def prioritizations(given_inheritance = nil)
    given_inheritance = given_inheritance || inheritance
    @prioritizations ||= begin
      @prioritizations = []
      @prioritizations << :homo_auto_rec if freq_max < 0.05 && !['X', 'Y'].include?(reference_name) && given_inheritance.match(/^0,1:0,1:1,1$/).present?
      @prioritizations << :comp_het_rec if comp_het_rec
      @prioritizations << :het_auto_dom if freq_max < 0.001 && !['X', 'Y'].include?(reference_name) && genotype.eql?('0,1') && ['AD', 'AD/AR', 'AR/AD'].include?(cgd_inheritance)
      @prioritizations << :het_risk if freq_max < 0.01 && genotype.eql?('0,1')
      @prioritizations << :het_denovo if genotype.eql?('0,1') && de_novo
      @prioritizations << :hemi_homo_x if freq_max < 0.01 && genotype.eql?('1,1') && reference_name.eql?('X')
      @prioritizations
    end
  end

  def interpretted_affection
    affection.eql?('2') ? 'affected' : 'unaffected'
  end

  def paths
    self.clinvar_sig.to_s.include?("pathogenic") && !self.clinvar_sig.to_s.include?("non-pathogenic") ? "ClinVar Pathogenic" : ""
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

  def plink_affection
    self.affection || '0'
  end

end
