class Gene < EntrezDbBase
  self.table_name = Rails.configuration.x.query['gene']

  has_one :condition, primary_key: "gene_id", foreign_key: "gene_id"
  has_many :phenotypes, primary_key: "gene_id", foreign_key: "gene_id"
  has_many :omims, primary_key: "gene_id", foreign_key: "gene_id"
  has_many :ref_genes, primary_key: "gene_id", foreign_key: "gene_id"
  has_many :gene_coordinates, primary_key: "gene_id", foreign_key: "gene_id"

  def self.search(user, name = nil)
    Gene.where("symbol like ?", "#{name.upcase}%").order(:symbol)
  end

  def id
    gene_id
  end

  def name
    symbol
  end

  # not sure if this is used
  def refseq_sequence
    "NC_0000" + chrom.sub(/X/, "23").sub(/Y/, "24")
  end

  # not sure if this is used
  def range
    @range ||= set_range
  end

private

  # not sure if this is used
  def set_range
    ref_gene = ref_genes.first
    [ref_gene.txStart, ref_gene.txEnd]
  end
end