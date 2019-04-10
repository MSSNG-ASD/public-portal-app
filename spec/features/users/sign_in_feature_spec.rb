
feature 'Sign In', :omniauth do

  scenario 'user can sign in with valid account' do
    signin
    expect(page).to have_content('Sign Out')
  end

  scenario 'user can sign in and the sign in link goes away' do
    signin
    expect(page).not_to have_content('Sign In')
  end

  scenario 'user without valid BQ access' do
    signin(false)
    expect(page).to have_content('Sign In')
    expect(page).to have_content('does not have valid access credentials')
  end

  scenario 'user cannot sign in with invalid account' do
    OmniAuth.config.mock_auth[:google_oauth2] = :invalid_credentials
    visit root_path
    expect(page).to have_content('Sign In')
    click_link 'Sign In'
    expect(page).to have_content('Authentication error')
  end
end