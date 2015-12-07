require 'sul_bib/api'

Sulbib::Application.routes.draw do
  mount RailsDb::Engine => '/rails/db', :as => 'rails_db'

  get '/publications' => 'publications#index'
  get '/publications/sourcelookup' => 'publications#sourcelookup'

  root to: 'high_voltage/pages#show', id: 'api'

  mount SulBib::API, at: '', as: 'api'
  get '/*id' => 'high_voltage/pages#show', :as => :page, :format => false
end
