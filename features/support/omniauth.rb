Before('@omniauth_test') do
  OmniAuth.config.test_mode = true

  OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new({
      :provider => 'google_oauth2',
      :uid => ENV['E2E_MSSNG_UID'],
      :info => {
          :email => ENV['E2E_MSSNG_EMAIL']
      },
      :credentials => {
          :refresh_token => ENV['E2E_MSSNG_REFRESH_TOKEN']
      }
  })
end
 
After('@omniauth_test') do
  OmniAuth.config.test_mode = false
end