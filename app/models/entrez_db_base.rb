class EntrezDbBase < ActiveRecord::Base  
  self.abstract_class = true
  establish_connection ENTREZ_DB
end 