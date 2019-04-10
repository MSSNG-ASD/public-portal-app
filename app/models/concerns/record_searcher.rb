# a simple class to generate search results, you can provide a block if you have different data attributes
 
class RecordSearcher
  attr_reader :records
 
  def initialize(records, user, params = {})
    unless records.respond_to? :search
      raise ArgumentError, "records must repond to .search"
    end
 
    default_params = {
      query: nil,
      page: nil,
      limit: nil
    }
 
    params.reverse_merge!(default_params)

    objects = records.search(user, params[:query])
    if objects.respond_to? :page
      @records = objects.page(params[:page]).per(params[:limit])
    else
      @records = Kaminari.paginate_array(objects).page(params[:page]).per(params[:limit])
    end
  end
 
  def call(&block)
    {
      total: records.total_count,
      records: records.map do |record|
        if block_given?
          block.call(record)
        else
          { name: record.name, id: record.id }
        end
      end
    }
  end
 
  def self.call(records, user, params = {}, &block)
    new(records, user, params).call(&block)
  end
 
end