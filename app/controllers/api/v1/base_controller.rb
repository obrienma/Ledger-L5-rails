module Api
  module V1
    class BaseController < ActionController::API
      include ApiKeyAuthenticatable
    end
  end
end
