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

  def range
    @range ||= set_range
  end

private

  def set_range
    if ref_genes.empty?
      return nil
    end

    start_positions = []
    end_positions = []

    ref_genes.each do |ref_gene|
      start_positions << ref_gene.txStart
      end_positions << ref_gene.txEnd
    end

    [start_positions.min, end_positions.max]
  end
end