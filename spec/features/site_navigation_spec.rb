require 'spec_helper'

feature "Site Navigation" do
  
  scenario "Anonymouse user goes to root url" do
    visit root_path
    page.should have_selector('h2', text: "Sign in")
  end

  scenario "Logged in user goes to root url" do
    user = FactoryGirl.create(:user)
    visit new_user_session_path
    fill_in 'user[email]', :with => user.email
    fill_in 'user[password]', :with => 'password'
    click_button 'Sign in'
    visit root_path
    page.should have_selector('h1', text: "All Badges")
  end

end
