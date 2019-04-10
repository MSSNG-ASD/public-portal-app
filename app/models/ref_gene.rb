class RefGene < EntrezDbBase
  self.table_name = Rails.configuration.x.query['ref_gene']
  belongs_to :gene, primary_key: "gene_id", foreign_key: "gene_id"
end