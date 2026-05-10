Rails.application.routes.draw do
  root "articles#index"

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
    end
  end

  resources :kv_sessions, only: %i[index create destroy], param: :key do
    collection do
      get :inspect_key
    end
  end
end
