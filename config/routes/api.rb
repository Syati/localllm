namespace :api do
  namespace :v1 do
    resource :chat, only: [] do
      scope module: :chat do
        resources :completions, only: [:create]
      end
    end
  end
end
