require "rails_helper"

RSpec.describe ApiKey, type: :model do
  describe ".authenticate" do
    let(:api_key) { create(:api_key) }
    let(:raw_token) { api_key.instance_variable_get(:@raw_token) }

    it "returns the api_key for a valid token" do
      expect(ApiKey.authenticate(raw_token)).to eq(api_key)
    end

    it "returns nil for an invalid secret" do
      id = raw_token.split(".").first
      expect(ApiKey.authenticate("#{id}.wrong_secret")).to be_nil
    end

    it "returns nil for a completely invalid token" do
      expect(ApiKey.authenticate("notavalidtoken")).to be_nil
    end

    it "returns nil for an inactive key" do
      api_key.update!(active: false)
      expect(ApiKey.authenticate(raw_token)).to be_nil
    end
  end

  describe "#generate_token" do
    it "sets id and token_digest and returns a non-nil token" do
      api_key = build(:api_key)
      token = api_key.instance_variable_get(:@raw_token)
      expect(token).to be_present
      expect(api_key.id).to be_present
      expect(api_key.token_digest).to be_present
    end

    it "returns a token in id.secret format" do
      api_key = build(:api_key)
      token = api_key.instance_variable_get(:@raw_token)
      id, secret = token.split(".", 2)
      expect(id).to eq(api_key.id)
      expect(secret).to be_present
    end
  end
end
