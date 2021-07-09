require 'json'


class DatasetsController < ApplicationController
  before_action :authenticate_user!

  respond_to :html

  def index
    user = current_user

    dataset_list = Search.where(user_id: user.id, saved: true).map do | search |
      {
        id: url_for(controller: 'datasets', action: 'get', id: search.id),
        name: search.name,
        schema: {
          "$ref" => get_schema(search.type),
        }
      }
    end

    render :json => {datasets: dataset_list}
  end

  def get
    user = current_user
    search = Search.where(user_id: user.id, saved: true, id: params[:id]).first

    if search.nil?
      render :json => { message: 'Not Found' }, :status => 404

      return
    end

    render :json => {
        schema: {
            "$schema" => "http://json-schema.org/draft-07/schema",
            "$ref" => get_schema(search.type),
        },
        objects: fetch(search.type, search.id),
        pagination: {},
    }
  end

  private

  def fetch(search_class_name, search_id, limited: false)
    # limited can be true or false or number.
    cls = search_class_name.constantize
    query = cls.find(search_id)

    if cls <= AbstractAnnotatedVariantSearch
      query.limited = limited
      samples = query.variants
    elsif cls <= SubjectSampleSearch
      samples = query.samples
    elsif cls <= GeneSearch
      samples = query.genes
    else
      raise RuntimeError, "dataset_type_interpreter_not_implemented"
    end

    samples
  end

  def get_schema(search_class_name)
    cls = search_class_name.constantize

    # The reference URL is absolute as it has to be stable and constant, regardless to the deployment.

    # url_prefix = 'https://research.mss.ng/schema/datasets'
    # url_prefix = "#{request.scheme}://#{request.host}:#{request.port}/schema/datasets"
    url_prefix = 'https://mssng-asd.github.io/json-schemas'

    if cls <= AbstractAnnotatedVariantSearch
      return "#{url_prefix}/VariantCall.json"
    elsif cls <= SubjectSampleSearch
      return "#{url_prefix}/SubjectSample.json"
    elsif cls <= GeneSearch
      return "#{url_prefix}/Gene.json"
    end

    raise RuntimeError, "dataset_type_interpreter_not_implemented"
  end
end
