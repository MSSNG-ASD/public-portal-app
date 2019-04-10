class MockAuth
  attr_reader :credentials, :info, :uid, :provider

  def initialize(provider, uid, email, expires, expires_at, refresh_token, token)
    @credentials = MockCredential.new(expires, expires_at, refresh_token, token)
    @info = MockInfo.new(email)
    @uid = uid
    @provider = provider
  end
end


class MockCredential
  attr_reader :expires, :expires_at, :refresh_token, :token

  def initialize(expires, expires_at, refresh_token, token)
    @expires = expires
    @expires_at = expires_at
    @refresh_token = refresh_token
    @token = token
  end
end


class MockInfo
  attr_reader :email

  def initialize(email)
    @email = email
  end
end