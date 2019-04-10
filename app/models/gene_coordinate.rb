class GeneCoordinate < EntrezDbBase
  self.table_name = Rails.configuration.x.query['gene_coordinate']
  belongs_to :gene, primary_key: "gene_id", foreign_key: "gene_id"
end