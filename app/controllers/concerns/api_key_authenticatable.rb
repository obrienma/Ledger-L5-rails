module ApiKeyAuthenticatable
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_api_key!
  end

  private

  def authenticate_api_key!
    raw_token = request.headers["Authorization"].to_s.delete_prefix("Bearer ").strip
    api_key = ApiKey.authenticate(raw_token)

    if api_key
      @current_tenant = api_key.tenant
    else
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def current_tenant
    @current_tenant
  end
end
