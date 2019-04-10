# GeneSearch
class GeneSearch < Search

  store :parameters, accessors: [:search, :gene_ids, :go_ids, :hpo_ids, :mim_ids, :inheritances]
  stringy :gene_ids, :go_ids, :hpo_ids, :mim_ids

  before_validation :set_search, if: ->(gene_search){gene_search.new_record?}

# @return [ActiveRecord_Relation] the result of the search.
  def results
    @results ||= find_results
  end

  def genes
    gene_ids.present? ? Gene.where(gene_id: gene_ids).map {|gene| {id: gene.gene_id, name: gene.name}} : []
  end

  def phenotypes
    hpo_ids.present? ? Phenotype.where(hpo_id: hpo_ids).map {|hpo| {id: hpo.id, name: hpo.name}} : []
  end

  def mims
    mim_ids.present? ? Omim.where(mim_id: mim_ids).map {|mim| {id: mim.id, name: mim.name}} : []
  end

private

  def set_search
    if search.present?
      self.stringy_gene_ids = search
      self.name ||= Gene.where(:gene_id => stringy_gene_ids.split(",")).pluck(:symbol).join(";")
    end
  end

  def find_results
    ids = []
    ids = ids + gene_ids
    ids = ids + Phenotype.where(hpo_id: hpo_ids).map {|hpo| hpo.gene_id} if hpo_ids.present?
    ids = ids + Omim.where(mim_id: mim_ids.map {|mim| mim.to_i}).map {|mim| mim.gene_id} if mim_ids.present?
    Gene.where('gene_id' => ids.uniq)
  end

end
