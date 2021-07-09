require 'redcarpet'
require 'time'
require 'yaml'

module ApplicationHelper
  def load_yaml where
    YAML.load(File.read(where))
  end

  def release_notes
    now = Time.now

    raw_note_file_path_list = Dir['data/change_logs/*.md'].sort.reverse

    note_list = []

    raw_note_file_path_list.each do | file_path |
      entry_id = file_path.gsub(/data\/change_logs\/([^\/]+)\.md$/, '\1')
      release_date = Time.parse(entry_id)

      note_list.push({
        entry_id: entry_id,
        file_path: file_path,
        release_date: release_date,
        elapsed_days: (now - release_date) / 60 / 60 / 24,
      })
    end

    note_list.sort{ |a, b| a[:entry_id] > b[:entry_id] ? 0 : 1 }
  end

  def latest_release_note
    if current_user.nil?
      return nil
    end

    release_note = release_notes.first

    receipt = ReleaseNoteReadReceipt.find_by user_id: current_user.id, entry_id: release_note[:entry_id]

    receipt.nil? ? release_note : nil
  end

  def render_md_to_html source_path
    if source_path.match? /\.\.\//
      raise UnknownChangeLog, source_path
    end

    md = Redcarpet::Markdown.new(Redcarpet::Render::HTML, autolink: true, tables: true)

    source_data = File.open(source_path) do | f |
      f.read
    end

    md.render source_data
  end

  def bq_sql(sql)
    table = sql.match(/SELECT\s+(\S+\:\S+\.\S+)\.\S+/)[1]
    sql.gsub(/(#{table}\.)/, "").gsub(/(#{table})/, '[\1]')
  end

  def shorten(string = "", length = 10)
    string.nil? ? nil : (string.length > length ? "#{string[0...length]}..." : string)
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
    if symbol.nil?
      return nil
    end
  	link_to symbol, "http://www.ncbi.nlm.nih.gov/gene/?term=#{symbol}[sym] AND human[ORGN] AND srcdb_refseq[PROP]", :target => "_blank"
  end

  def link_to_ucsc_postion(position)
    if position.nil?
      return nil
    end
    link_to position, "http://genome.ucsc.edu/cgi-bin/hgTracks?db=hg38&position=#{position}", :target => "_blank"
  end

  def link_to_dgv_postion(position)
    if position.nil?
      return nil
    end
    link_to position, "http://dgv.tcag.ca/gb2/gbrowse/dgv2_hg38/?name=#{position}", :target => "_blank"
  end

  def link_to_dbsnp(dbsnp)
    if dbsnp.nil?
      return nil
    end
    link_to dbsnp, "https://www.ncbi.nlm.nih.gov/projects/SNP/snp_ref.cgi?rs=#{dbsnp.match(/^rs(\d+)$/)[1]}"
  end

  def link_to_pubmed(reference)
    if reference.nil?
      return nil
    end
  	link_to reference, "http://www.ncbi.nlm.nih.gov/pubmed/#{reference}", :target => "_blank"
  end

  def link_to_omim(mim)
    if mim.nil?
      return nil
    end
  	link_to mim, "http://omim.org/entry/#{mim}", :target => "_blank"
  end

  def link_to_ncbi(accession)
    if accession.nil?
      return nil
    end
  	link_to accession, "http://www.ncbi.nlm.nih.gov/nuccore/#{accession}", :target => "_blank"
  end

  def link_to_xref(xref)
    if xref.nil?
      return nil
    end
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

  # Returns true if the given position is in one of the two pseudoautosomal regions of the X chromosome and false otherwise
  def _is_pseudoautosomal(pos)
    return (pos >= 10001 && pos <= 2781479) || (pos >= 155701383 && pos <= 156030895) # Coordinates are from https://www.ncbi.nlm.nih.gov/grc/human
  end

  # Given a valid inheritance, figure out the correct labeling
  def _valid_inheritance_str(order, child_gt)
    if child_gt[0] == "0" && child_gt[1] == "0"
      return "hom-ref"
    elsif child_gt[0] == child_gt[1]
      return "hom-alt"
    elsif child_gt[0] == "0"
      return "ref-alt|#{order}"
    elsif child_gt[1] == "0" # Should never happen where first allele is non-zero and second allele is zero, but including this just in case!
      return "alt-ref|#{order}"
    else
      return "alt-alt|#{order}"
    end
  end

  # Main function to determine the inheritance string
  # genotypes: string of the form "0,1:0,0:0,1"
  # reference name: string of the form "chrX"
  # pos: position of the variant; integer
  # sex: sex of child, either "M" or "F"
  # Example call: interpreted_inheritance("0,1:0,0:0,1", "chrX", 10000000, "F")
  def interpreted_inheritance(reference_name, sex, inheritance_string, pos)
    genotypes = inheritance_string.nil? ? '?' : inheritance_string.gsub(/[1-9]/, '1')

    mother_gt = genotypes.split(":")[0].split(",")
    father_gt = genotypes.split(":")[1].split(",")
    child_gt = genotypes.split(":")[2].split(",")

    if sex == "F" || reference_name != "chrX" || (reference_name == "chrX" && _is_pseudoautosomal(pos)) # Standard way of calculating - used for autosomes, X in females, and pseudoautosomal regions in X in males
      if mother_gt.include?(child_gt[0]) && father_gt.include?(child_gt[1]) && mother_gt.include?(child_gt[1]) && father_gt.include?(child_gt[0])
        return _valid_inheritance_str("inh", child_gt)
      elsif mother_gt.include?(child_gt[0]) && father_gt.include?(child_gt[1])
        return _valid_inheritance_str("mat-pat", child_gt)
      elsif mother_gt.include?(child_gt[1]) && father_gt.include?(child_gt[0])
        return _valid_inheritance_str("pat-mat", child_gt)
      elsif (mother_gt[0] == "0" && mother_gt[1] == "0" && father_gt[0] == "0" && father_gt[1] == "0" && child_gt.include?("0"))
        return "p_denovo"
      elsif mother_gt.include?("-1") || father_gt.include?("-1")
        return "unknown"
      else
        return "ME"
      end
    else # For non-pseudoautosomal regions on the X chromosome in males

      if child_gt[0] != "0"
        child_gt_forX = child_gt[0]
      elsif child_gt[1] != "0"
        child_gt_forX = child_gt[1]
      else
        child_gt_forX = "0"
      end

      if mother_gt.include?(child_gt_forX)
        if child_gt_forX == "0"
          return "ref|mat"
        else
          return "alt|mat"
        end
      elsif mother_gt[0] == "0" && mother_gt[1] == "0"
        return "p_denovo"
      elsif mother_gt.include?("-1")
        return "unknown"
      else
        return "ME"
      end
    end
  end
  def get_inheritance_string(search_object, variant)
    inheritance_string = search_object.inheritance[variant.sample_id][variant.annotation_id]

    "#{inheritance_string}:#{interpreted_inheritance(variant.reference_name, variant.sex, inheritance_string, variant.start)}"
  end

  class UnknownChangeLog < StandardError
  end

end
