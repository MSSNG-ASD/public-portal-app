
feature 'Home page' do

  scenario 'visit the home page' do
    visit root_path
    expect(page).to have_content 'MSSNG is a groundbreaking collaboration'
  end
end
