module SerializedParameters

  def serialized(parameter)
    define_method("serialized_#{parameter}=") do |json|
      self.send("#{parameter}=", JSON.parse(json))
    end
 
    define_method("serialized_#{parameter}") do
      send("#{parameter}").to_json
    end
  end
 
end
ActiveRecord::Base.extend(SerializedParameters)

