module StringyAssociationIds

  def stringy(*associations)
  	associations.each do |association|
	    define_method("stringy_#{association}=") do |stringy|
	      self.send("#{association}=", stringy.to_s.split(","))
	    end
	    define_method("stringy_#{association}") do
	      send("#{association}").nil? ? "" : send("#{association}").join(",")
	    end
  	end
  end
end
ActiveRecord::Base.extend(StringyAssociationIds)

