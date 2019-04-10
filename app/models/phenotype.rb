class Phenotype < EntrezDbBase
  self.table_name = Rails.configuration.x.query['phenotype']

  belongs_to :gene, primary_key: "gene_id", foreign_key: "gene_id"

  def self.search(name = nil)
    Phenotype.where("LOWER(gene_term) like ?", "%#{name}%").order(:hpo_id)
  end

  def name
    gene_term
  end
end
