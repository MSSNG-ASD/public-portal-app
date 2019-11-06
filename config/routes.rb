Rails.application.routes.draw do
  # devise signin, signout, and callbacks
  devise_for :users, path: '/', controllers: { omniauth_callbacks: "users/omniauth_callbacks" }
	devise_scope :user do
	  get 'signin', to: redirect('/auth/google_oauth2'), as: :signin
	  get 'signout', to: 'devise/sessions#destroy', as: :signout
	end
  resources :users, only: [:show, :index, :update]
  resources :variant_searches do
    match 'search', on: :collection, via: :get
    match 'saved', on: :collection, via: :get
    match 'delete_all', on: :collection, via: :delete
    match 'delete_multiple', on: :collection, via: :delete
  end
  resources :trios do
    match 'search', on: :collection, via: :get
    match 'saved', on: :collection, via: :get
    match 'delete_all', on: :collection, via: :delete
    match 'delete_multiple', on: :collection, via: :delete
    match 'foo', via: :get
  end
  resources :gene_searches do
    match 'search', on: :collection, via: :get
    match 'saved', on: :collection, via: :get
    match 'delete_all', on: :collection, via: :delete
    match 'delete_multiple', on: :collection, via: :delete
  end
  resources :subject_sample_searches do
    match 'search', on: :collection, via: :get
    match 'saved', on: :collection, via: :get
    match 'delete_all', on: :collection, via: :delete
    match 'delete_multiple', on: :collection, via: :delete
  end
  resources :subject_samples, only: [:show] do
    match 'igv', on: :member, via: :get
  end
  resources :genes, only: [:show]
  resources :annotations, only: [:show]
  resources :selections do
    match 'gene', on: :collection, via:  :get, defaults: { format: 'json' }
    match 'sample', on: :collection, via:  :get, defaults: { format: 'json' }
    match 'subject', on: :collection, via:  :get, defaults: { format: 'json' }
    match 'phenotype', on: :collection, via:  :get, defaults: { format: 'json' }
    match 'mim', on: :collection, via:  :get, defaults: { format: 'json' }
  end

  resources :release_note_read_receipts

  # match 'help/:controller_id/:action_id' => 'help#show', via: :get, as: 'help'
  match '(errors)/:status', to: 'errors#show', constraints: {status: /\d{3}/}, via: :all
  get '/auth/failure' => 'sessions#failure'
  # get 'pages/publications'
  get 'pages/acknowledgements'
  get 'visitors/about'
  # get 'visitors/publications'
  get '/publications' => 'visitors#publications'
  get '/release-notes' => 'visitors#change_logs'
  get '/release-notes/:entry_id' => 'visitors#change_logs'
  get '/me' => 'profile#show'

  get '/datasets' => 'datasets#index'
  get '/dataset/:id' => 'datasets#get'

  if ENV['RAILS_ENV'] == 'development'
    get '/dev/datasets' => 'datasets#index'
    get '/dev/dataset/:id' => 'datasets#get'
  end

  root to: 'visitors#index'

  ##############################################################################
  # FOR TESTING AND DEVELOPMENT ONLY                                           #
  ##############################################################################
  # TEST_RUNNER_HELPER_MAGIC_KEY is used for remote testing which enables the  #
  # set of privileged endpoints.                                               #
  ##############################################################################
  if !ENV['TEST_JWT_SECRET'].nil? and !ENV['TEST_JWT_SECRET'].empty?
    get '/test/ping', to: 'test#ping'
    post '/test/auth', to: 'test#auth'
    post '/test/data-reset', to: 'test#reset_data'
    get '/test/error', to: 'test#trigger_sample_error'
    get '/test/nuclear-error', to: 'test#trigger_nuclear_error'
  end
end
