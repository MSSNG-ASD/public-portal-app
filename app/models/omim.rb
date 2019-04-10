class Omim < EntrezDbBase
  self.table_name = Rails.configuration.x.query['omim']
  belongs_to :gene, primary_key: "gene_id", foreign_key: "gene_id"

  def self.search(name = nil)
    Omim.where("cast(mim_id as char) like ?", "#{name}%").order(:mim_id)
  end

  def name
    mim_id
  end
end