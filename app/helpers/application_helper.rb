module ApplicationHelper

  def bq_sql(sql)
    table = sql.match(/SELECT\s+(\S+\:\S+\.\S+)\.\S+/)[1]
    sql.gsub(/(#{table}\.)/, "").gsub(/(#{table})/, '[\1]')
  end
  
  def shorten(string = "", length = 10)
    string.length > length ? "#{string[0...length]}..." : string
  end

  def comma_separated_links_for(list)
    raise TypeError, "parameter must be an array" unless list.is_a? Array 
    return if list.count == 0

    list.collect do |item| 
      raise TypeError, "items must respond to 'name'" unless item.respond_to? :name
      link_to(item.name, url_for(item)) 
    end.join(", ").html_safe
  end

  def link_to_ref_gene(symbol)
  	link_to symbol, "http://www.ncbi.nlm.nih.gov/gene/?term=#{symbol}[sym] AND human[ORGN] AND srcdb_refseq[PROP]", :target => "_blank"
  end

  def link_to_ucsc_postion(position)
  	link_to position, "http://genome.ucsc.edu/cgi-bin/hgTracks?db=hg19&position=#{position}", :target => "_blank"
  end

  def link_to_dgv_postion(position)
    link_to position, "http://dgv.tcag.ca/gb2/gbrowse/dgv2_hg19/?name=#{position}", :target => "_blank"
  end

  def link_to_dbsnp(dbsnp)
    link_to dbsnp, "https://www.ncbi.nlm.nih.gov/projects/SNP/snp_ref.cgi?rs=#{dbsnp.match(/^rs(\d+)$/)[1]}"
  end

  def link_to_pubmed(reference)
  	link_to reference, "http://www.ncbi.nlm.nih.gov/pubmed/#{reference}", :target => "_blank"
  end

  def link_to_omim(mim)
  	link_to mim, "http://omim.org/entry/#{mim}", :target => "_blank"
  end

  def link_to_ncbi(accession)
  	link_to accession, "http://www.ncbi.nlm.nih.gov/nuccore/#{accession}", :target => "_blank"
  end

  def link_to_xref(xref)
  	(db, id, rest) = xref.split(":")
  	case db
    when "MIM"
      link_to xref, "http://omim.org/entry/#{id}", :target => "_blank"
    when "OMIM"
      link_to xref, "http://omim.org/entry/#{id}", :target => "_blank"
  	when "HGNC"
  		link_to xref, "http://www.genenames.org/cgi-bin/gene_symbol_report?hgnc_id=#{id}:#{rest}", :target => "_blank"
  	when "Ensembl"
  		link_to xref, "http://useast.ensembl.org/Homo_sapiens/Gene/Summary?db=core;g=#{id}", :target => "_blank"
  	when "Vega"
  		link_to xref, "http://vega.sanger.ac.uk/Homo_sapiens/Gene/Summary?g=#{id}", :target => "_blank"
  	when "HP"
  		link_to xref, "http://www.human-phenotype-ontology.org/hpoweb/showterm?id=#{db}:#{id}", :target => "_blank"
  	when "GO"
  		link_to xref, "http://amigo.geneontology.org/amigo/term/#{db}:#{id}", :target => "_blank"
  	when "HPRD"
  		link_to xref, "http://www.hprd.org/protein/#{id}", :target => "_blank"
  	else
  		xref
  	end
  end

  def interpretted_inheritance(reference_name, sex, inheritance)
    if reference_name.eql?('X') && sex.eql?('M')
      case inheritance
      when "0,0:0,0:0,0"
        "Reference-correct: #{inheritance}"
      when "0,0:0,0:0,1"
        "Incorrect: #{inheritance}"
      # when "0,0:0,0:1,1"
      #   "value: #{inheritance}"
      when "0,0:0,1:0,0"
        "Reference-correct: #{inheritance}"
      when "0,0:0,1:0,1"
        "Incorrect: #{inheritance}"
      # when "0,0:0,1:1,1"
      #   "value: #{inheritance}"
      when "0,0:1,1:0,0"
        "Reference-correct: #{inheritance}"
      when "0,0:1,1:0,1"
        "Incorrect: #{inheritance}"
      # when "0,0:1,1:1,1"
      #   "value: #{inheritance}"
      when "0,1:0,0:0,0"
        "Reference-correct: #{inheritance}"
      when "0,1:0,0:0,1"
        "Incorrect: #{inheritance}"
      when "0,1:0,0:1,1"
        "Maternal-het: #{inheritance}"
      when "0,1:0,1:0,0"
        "Reference-correct: #{inheritance}"
      when "0,1:0,1:0,1"
        "Incorrect: #{inheritance}"
      when "0,1:0,1:1,1"
        "Maternal-het: #{inheritance}"
      when "0,1:1,1:0,0"
        "Reference-correct: #{inheritance}"
      when "0,1:1,1:0,1"
        "Incorrect: #{inheritance}"
      when "0,1:1,1:1,1"
        "Maternal-het: #{inheritance}"
      when "1,1:0,0:0,0"
        "Reference-incorrect: #{inheritance}"
      when "1,1:0,0:0,1"
        "Incorrect: #{inheritance}"
      when "1,1:0,0:1,1"
        "Maternal-hom: #{inheritance}"
      when "1,1:0,1:0,0"
        "Reference-incorrect: #{inheritance}"
      when "1,1:0,1:0,1"
        "Incorrect: #{inheritance}"
      when "1,1:0,1:1,1"
        "Maternal-hom: #{inheritance}"
      when "1,1:1,1:0,0"
        "Reference-incorrect: #{inheritance}"
      when "1,1:1,1:0,1"
        "Incorrect: #{inheritance}"
      when "1,1:1,1:1,1"
        "Maternal-hom: #{inheritance}"
      else
        "Not available: #{inheritance}"
      end
    else
      case inheritance
      when "0,0:0,0:0,0"
        "Reference-correct: #{inheritance}"
      when "0,0:0,0:0,1"
        "Incorrect/Denovo: #{inheritance}"
      when "0,0:0,0:1,1"
        "Incorrect: #{inheritance}"
      when "0,0:0,1:0,0"
        "Reference-correct: #{inheritance}"
      when "0,0:0,1:0,1"
        "Paternal-het: #{inheritance}"
      when "0,0:0,1:1,1"
        "Incorrect: #{inheritance}"
      when "0,0:1,1:0,0"
        "Reference-incorrect: #{inheritance}"
      when "0,0:1,1:0,1"
        "Paternal-hom: #{inheritance}"
      when "0,0:1,1:1,1"
        "Incorrect: #{inheritance}"
      when "0,1:0,0:0,0"
        "Reference-correct: #{inheritance}"
      when "0,1:0,0:0,1"
        "Maternal-het: #{inheritance}"
      when "0,1:0,0:1,1"
        "Incorrect: #{inheritance}"
      when "0,1:0,1:0,0"
        "Reference-correct: #{inheritance}"
      when "0,1:0,1:0,1"
        "Unresolved-het: #{inheritance}"
      when "0,1:0,1:1,1"
        "Maternal-het+Paternal-het: #{inheritance}"
      when "0,1:1,1:0,0"
        "Reference-incorrect: #{inheritance}"
      when "0,1:1,1:0,1"
        "Paternal-hom: #{inheritance}"
      when "0,1:1,1:1,1"
        "Maternal-het+Paternal-hom: #{inheritance}"
      when "1,1:0,0:0,0"
        "Reference-incorrect: #{inheritance}"
      when "1,1:0,0:0,1"
        "Maternal-hom: #{inheritance}"
      when "1,1:0,0:1,1"
        "Incorrect: #{inheritance}"
      when "1,1:0,1:0,0"
        "Reference-incorrect: #{inheritance}"
      when "1,1:0,1:0,1"
        "Maternal-hom: #{inheritance}"
      when "1,1:0,1:1,1"
        "Maternal-hom+Paternal-het: #{inheritance}"
      when "1,1:1,1:0,0"
        "Reference-incorrect: #{inheritance}"
      when "1,1:1,1:0,1"
        "Incorrect: #{inheritance}"
      when "1,1:1,1:1,1"
        "Maternal-hom+Paternal-hom: #{inheritance}"
      else
        "Not available: #{inheritance}"
      end
    end
  end

end
