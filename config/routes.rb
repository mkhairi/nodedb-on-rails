Rails.application.routes.draw do
  root "articles#index"

  get "/server_info", to: "server_info#index", as: :server_info

  resources :articles do
    collection do
      get :search
    end
  end

  resources :posts do
    collection do
      get :search
    end
  end

  resources :locations, only: %i[index show new create destroy] do
    collection do
      get :map
      get :near
    end
  end

  resources :social_nodes, only: %i[index show new create destroy] do
    collection do
      post :edge
      get  :traverse
      get  :graph
      get  :recommend
    end
  end

  # Bitemporal demo (NodeDB v0.3.0). EXPERIMENTAL — see BUG-018: SELECT
  # over a bitemporal collection returns the raw `{data,id}` blob shape,
  # so the view does a JSON-unwrap before rendering.
  resources :audit_logs, only: %i[index create]

  resources :kv_sessions, only: %i[index create destroy], param: :key do
    collection do
      get :inspect_key
    end
  end

  # Timeseries engine demo (Metric model -> metrics collection).
  resources :metrics, only: %i[index create]

  # Vector engine demo (Embedding model -> embeddings collection + vector index).
  resources :embeddings, only: %i[index create] do
    collection do
      get :search
    end
  end
end
