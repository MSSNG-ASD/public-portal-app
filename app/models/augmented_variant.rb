module AugmentedVariant
  def searchable_on_beacon_network
    self.end.to_i - self.start.to_i == 1
  end

  def beacon_network_url
    # "rs" is not relying on the call read depth.
    "https://beacon-network.org/#/search?chrom=#{reference_name}&pos=#{start.to_i + 1}&ref=#{reference_bases}&allele=#{alternate_bases}&rs=GRCh37"
  end
end