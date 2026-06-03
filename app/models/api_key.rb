class ApiKey < ApplicationRecord
  belongs_to :tenant

  validates :name, presence: true
  validates :token_digest, presence: true

  # Token format: "{id}.{secret}"
  # The UUID id serves as the public lookup key; only the BCrypt digest of
  # the secret is stored. The plaintext token is returned once on generation.
  def self.authenticate(raw_token)
    id, secret = raw_token.to_s.split(".", 2)
    return nil unless id.present? && secret.present?

    api_key = find_by(id: id, active: true)
    return nil unless api_key

    BCrypt::Password.new(api_key.token_digest) == secret ? api_key : nil
  end

  # Assigns id + token_digest; returns the plaintext token to show once.
  # Must be called before save.
  def generate_token
    self.id = SecureRandom.uuid
    secret = SecureRandom.urlsafe_base64(32)
    self.token_digest = BCrypt::Password.create(secret)
    "#{id}.#{secret}"
  end
end
